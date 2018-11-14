#import "InAppPurchase.h"
#include <stdio.h>
#include <stdlib.h>

/*
 * Plugin state variables
 */
static BOOL g_initialized = NO;
static BOOL g_debugEnabled = NO;
static BOOL g_autoFinishEnabled = NO;

/*
 * Helpers
 */

// Help create NSNull objects for nil items (since neither NSArray nor NSDictionary can store nil values).
#define NILABLE(obj) ((obj) != nil ? (NSObject *)(obj) : (NSObject *)[NSNull null])

// Log messages to NSLog if g_debugEnabled is set
#define DLog(fmt, ...) { \
    if (g_debugEnabled) \
        NSLog((@"InAppPurchase[objc]: " fmt), ##__VA_ARGS__); \
    else if (!g_initialized) \
        NSLog((@"InAppPurchase[objc] (before init): " fmt), ##__VA_ARGS__); \
}

#define ERROR_CODES_BASE 6777000
#define ERR_SETUP         (ERROR_CODES_BASE + 1)
#define ERR_LOAD          (ERROR_CODES_BASE + 2)
#define ERR_PURCHASE      (ERROR_CODES_BASE + 3)
#define ERR_LOAD_RECEIPTS (ERROR_CODES_BASE + 4)

#define ERR_CLIENT_INVALID    (ERROR_CODES_BASE + 5)
#define ERR_PAYMENT_CANCELLED (ERROR_CODES_BASE + 6)
#define ERR_PAYMENT_INVALID   (ERROR_CODES_BASE + 7)
#define ERR_PAYMENT_NOT_ALLOWED (ERROR_CODES_BASE + 8)
#define ERR_UNKNOWN (ERROR_CODES_BASE + 10)
#define ERR_REFRESH_RECEIPTS (ERROR_CODES_BASE + 11)

static NSInteger jsErrorCode(NSInteger storeKitErrorCode) {
    switch (storeKitErrorCode) {
        case SKErrorUnknown:
            return ERR_UNKNOWN;
        case SKErrorClientInvalid:
            return ERR_CLIENT_INVALID;
        case SKErrorPaymentCancelled:
            return ERR_PAYMENT_CANCELLED;
        case SKErrorPaymentInvalid:
            return ERR_PAYMENT_INVALID;
        case SKErrorPaymentNotAllowed:
            return ERR_PAYMENT_NOT_ALLOWED;
    }
    return ERR_UNKNOWN;
}

static NSString *jsErrorCodeAsString(NSInteger code) {
    switch (code) {
        case ERR_SETUP: return @"ERR_SETUP";
        case ERR_LOAD: return @"ERR_LOAD";
        case ERR_PURCHASE: return @"ERR_PURCHASE";
        case ERR_LOAD_RECEIPTS: return @"ERR_LOAD_RECEIPTS";
        case ERR_REFRESH_RECEIPTS: return @"ERR_REFRESH_RECEIPTS";
        case ERR_CLIENT_INVALID: return @"ERR_CLIENT_INVALID";
        case ERR_PAYMENT_CANCELLED: return @"ERR_PAYMENT_CANCELLED";
        case ERR_PAYMENT_INVALID: return @"ERR_PAYMENT_INVALID";
        case ERR_PAYMENT_NOT_ALLOWED: return @"ERR_PAYMENT_NOT_ALLOWED";
        case ERR_UNKNOWN: return @"ERR_UNKNOWN";
    }
    return @"ERR_NONE";
}

@implementation NSArray (JSONSerialize)
- (NSString *)JSONSerialize {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}
@end

@interface NSData (Base64)
- (NSString*)convertToBase64;
@end

@implementation NSData (Base64)
- (NSString*)convertToBase64 {
    const uint8_t* input = (const uint8_t*)[self bytes];
    NSInteger length = [self length];

    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;

    NSInteger i;
    for (i=0; i < length; i += 3) {
        NSInteger value = 0;
        NSInteger j;
        for (j = i; j < (i + 3); j++) {
            value <<= 8;

            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }

        NSInteger theIndex = (i / 3) * 4;
        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }

    NSString *ret = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    return ret;
}
@end

@implementation InAppPurchase

@synthesize products;
@synthesize currentDownloads;
@synthesize unfinishedTransactions;
@synthesize pendingTransactionUpdates;
@synthesize productsRequest, productsRequestDelegate, receiptRefreshRequest, refreshReceiptDelegate;

// Initialize the plugin state
-(BOOL) setup {
    self.products = [[NSMutableDictionary alloc] init];
    self.currentDownloads = [[NSMutableDictionary alloc] init];
    self.pendingTransactionUpdates = [[NSMutableArray alloc] init];
    self.unfinishedTransactions = [[NSMutableDictionary alloc] init];

    if (![SKPaymentQueue canMakePayments]) {
        DLog(@"setup: Cant make payments, plugin disabled.");
        return NO;
    } else {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        DLog(@"setup: OK");
    }
    return YES;
}

+(void) debug:(BOOL)debug
{
    g_debugEnabled = debug;
}

+(void) autoFinish:(BOOL)autoFinish
{
    g_autoFinishEnabled = autoFinish;
}

/**
 * Request product data for the given productIds.
 * See js for further documentation.
 */
- (void) load:(NSArray*)inArray withCallback:(void(^)(NSArray* result, NSError* err))callback {

    DLog(@"load: Getting products data");

    if (inArray == nil || inArray.count == 0) {
        DLog(@"load: Empty array");
        NSArray *callbackArgs = [NSArray arrayWithObjects: [NSNull null], [NSNull null], nil];
        if(callback) callback(callbackArgs, nil);
        return;
    }

    if (![[inArray objectAtIndex:0] isKindOfClass:[NSString class]]) {
        DLog(@"load: Not an array of NSString");
        if(callback) callback(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSKeyValueValidationError userInfo:nil]);
        return;
    }
    
    NSSet *productIdentifiers = [NSSet setWithArray:inArray];
    DLog(@"load: Set has %li elements", (unsigned long)[productIdentifiers count]);
    for (NSString *item in productIdentifiers) {
      DLog(@"load:  - %@", item);
    }
    productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];

    productsRequestDelegate = [[BatchProductsRequestDelegate alloc] init];
    productsRequest.delegate = productsRequestDelegate;
    productsRequestDelegate.plugin  = self;
    productsRequestDelegate.callback = callback;

    DLog(@"load: Starting product request...");
    [productsRequest start];
    DLog(@"load: Product request started");
}

- (void) purchase: (NSString*)identifier withCallback:(void(^)(NSArray* result, NSError* err))callback {

    DLog(@"purchase: About to do IAP");
    _transactionCallback = callback;
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:[self.products objectForKey:identifier]];
    payment.quantity = 1;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

//Check if user/device is allowed to make in-app purchases
- (BOOL) canMakePayments {

  if (![SKPaymentQueue canMakePayments]) {
      DLog(@"canMakePayments: Device can't make payments.");
      return NO;
  }
  else {
      DLog(@"canMakePayments: Device can make payments.");
      return YES;
  }
}

- (void) restoreCompletedTransactionsWithCallback:(void(^)(NSArray* result, NSError* err))callback {
    //_purchaseRestorationCallback = callback;
    _transactionCallback = callback;
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void) pauseDownloads {

    NSArray *dls = [self.currentDownloads allValues];
    DLog(@"pause: Pausing %d active downloads...",[dls count]);
    
    [[SKPaymentQueue defaultQueue] pauseDownloads:dls];
}

- (void) resumeDownloads {

    NSArray *dls = [self.currentDownloads allValues];
    DLog(@"resume: Resuming %d active downloads...",[dls count]);
    [[SKPaymentQueue defaultQueue] resumeDownloads:[self.currentDownloads allValues]];
}

- (void) cancelDownloads {

    NSArray *dls = [self.currentDownloads allValues];
    DLog(@"cancel: Cancelling %d active downloads...",[dls count]);
    [[SKPaymentQueue defaultQueue] cancelDownloads:[self.currentDownloads allValues]];
}

- (BOOL) finishTransaction:(NSString*)identifier {

    DLog(@"finishTransaction: %@", identifier);
    SKPaymentTransaction *transaction = nil;

    if (identifier) {
        transaction = (SKPaymentTransaction*)[self.unfinishedTransactions objectForKey:identifier];
    }

    if (transaction) {
        DLog(@"finishTransaction: Transaction %@ finished.", identifier);
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        [self.unfinishedTransactions removeObjectForKey:identifier];
        [self transactionFinished:transaction];
        return YES;
    }
    else {
        DLog(@"finishTransaction: Cannot finish transaction %@.", identifier);
        return NO;
    }
}

- (NSArray<NSString*>*) getUnfinishedTransactions
{
    DLog(@"getUnfinishedTransactions");
    NSMutableArray *result = [NSMutableArray new];
    for(SKPaymentTransaction *transaction in self.unfinishedTransactions) {
        [result addObject:transaction.transactionIdentifier];
    }
    return result;
}

- (NSData *)appStoreReceiptData {
    NSURL *receiptURL = nil;
    NSBundle *bundle = [NSBundle mainBundle];
    if ([bundle respondsToSelector:@selector(appStoreReceiptURL)]) {
        // The general best practice of weak linking using the respondsToSelector: method
        // cannot be used here. Prior to iOS 7, the method was implemented as private SPI,
        // but that implementation called the doesNotRecognizeSelector: method.
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
            receiptURL = [bundle performSelector:@selector(appStoreReceiptURL)];
        }
    }

    if (receiptURL != nil) {
        NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
        return receiptData;
    }
    else {
        return nil;
    }
}

- (NSString*) appStoreReceipt {

    DLog(@"appStoreRefresh:");
    NSString *base64 = nil;
    NSData *receiptData = [self appStoreReceiptData];
    if (receiptData != nil) {
        base64 = [receiptData convertToBase64];
    }
    return base64;
}

- (void) appStoreRefreshReceipt:(void(^)(NSArray* result, NSError* err))callback {

    DLog(@"appStoreRefreshReceipt: Request to refresh app receipt");
    refreshReceiptDelegate = [[RefreshReceiptDelegate alloc] init];
    receiptRefreshRequest = [[SKReceiptRefreshRequest alloc] init];
    receiptRefreshRequest.delegate = refreshReceiptDelegate;
    refreshReceiptDelegate.plugin  = self;
    refreshReceiptDelegate.callback = callback;
    
    DLog(@"appStoreRefreshReceipt: Starting receipt refresh request...");
    [receiptRefreshRequest start];
    DLog(@"appStoreRefreshReceipt: Receipt refresh request started");
}

- (void) dispose {
    g_initialized = NO;
    g_debugEnabled = NO;
    g_autoFinishEnabled = NO;
    [self cancelDownloads];
    self.products = nil;
    self.currentDownloads = nil;
    self.unfinishedTransactions = nil;
    self.pendingTransactionUpdates = nil;
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    [super dispose];
}



#pragma mark - SKPaymentTransactionObserver

// SKPaymentTransactionObserver methods
// called when the transaction status is updated
//
- (void) paymentQueue:(SKPaymentQueue*)queue updatedTransactions:(NSArray*)transactions {

    NSString *state, *error, *transactionIdentifier, *transactionReceipt, *productId;
    NSInteger errorCode;

    for (SKPaymentTransaction *transaction in transactions) {

        error = state = transactionIdentifier = transactionReceipt = productId = @"";
        errorCode = 0;
        DLog(@"paymentQueue:updatedTransactions: %@", transaction.payment.productIdentifier);

        switch (transaction.transactionState) {

            case SKPaymentTransactionStatePurchasing:
                DLog(@"paymentQueue:updatedTransactions: Purchasing...");
                state = @"PaymentTransactionStatePurchasing";
                productId = transaction.payment.productIdentifier;
                break;

            case SKPaymentTransactionStatePurchased:
                state = @"PaymentTransactionStatePurchased";
                transactionIdentifier = transaction.transactionIdentifier;
                transactionReceipt = [[transaction transactionReceipt] base64EncodedStringWithOptions:0];
                productId = transaction.payment.productIdentifier;
                break;

            case SKPaymentTransactionStateFailed:
                state = @"PaymentTransactionStateFailed";
                error = transaction.error.localizedDescription;
                errorCode = jsErrorCode(transaction.error.code);
                productId = transaction.payment.productIdentifier;
                DLog(@"paymentQueue:updatedTransactions: Error %@ - %@", jsErrorCodeAsString(errorCode), error);

                // Finish failed transactions, when autoFinish is off
                if (!g_autoFinishEnabled) {
                    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                    [self transactionFinished:transaction];
                }
                break;

            case SKPaymentTransactionStateRestored:
                state = @"PaymentTransactionStateRestored";
                transactionIdentifier = transaction.transactionIdentifier;
                if (!transactionIdentifier)
                    transactionIdentifier = transaction.originalTransaction.transactionIdentifier;
                transactionReceipt = [[transaction transactionReceipt] base64EncodedStringWithOptions:0];
                // TH 08/03/2016: default to transaction.payment.productIdentifier and use transaction.originalTransaction.payment.productIdentifier as a fallback.
                // Previously only used transaction.originalTransaction.payment.productIdentifier.
                // When restoring transactions when there are unfinished transactions, I encountered transactions for which originalTransaction is nil, leading to a nil productId.
                productId = transaction.payment.productIdentifier;
                if (!productId)
                    productId = transaction.originalTransaction.payment.productIdentifier;
                break;

            default:
                DLog(@"paymentQueue:updatedTransactions: Invalid state");
                continue;
        }

        DLog(@"paymentQueue:updatedTransactions: State: %@", state);
#define PT_INDEX_STATE 0
#define PT_INDEX_ERROR_CODE 1
#define PT_INDEX_ERROR 2
#define PT_INDEX_TRANSACTION_IDENTIFIER 3
#define PT_INDEX_PRODUCT_IDENTIFIER 4
#define PT_INDEX_TRANSACTION_RECEIPT 5
        NSArray *callbackArgs = [NSArray arrayWithObjects:
            NILABLE(state),
            [NSNumber numberWithInteger:errorCode],
            NILABLE(error),
            NILABLE(transactionIdentifier),
            NILABLE(productId),
            NILABLE(transactionReceipt),
            nil];

        if (g_initialized) {
            [self processTransactionUpdate:transaction withArgs:callbackArgs];
        }
        else {
            [pendingTransactionUpdates addObject:@[transaction,callbackArgs]];
        }
    }
}

- (void) paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {

    DLog(@"paymentQueue:restoreCompletedTransactionsFailedWithError:");
    //if(_purchaseRestorationCallback) _purchaseRestorationCallback(error);
    if(_transactionCallback) _transactionCallback(nil, error);
}

- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {

    DLog(@"paymentQueueRestoreCompletedTransactionsFinished:");
    //if(_purchaseRestorationCallback) _purchaseRestorationCallback(nil);
    if(_transactionCallback) _transactionCallback(nil, nil);
}

/****************************************************************************************************************
 * Downloads
 ****************************************************************************************************************/
// Download Queue
- (void) paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads {
    DLog(@"paymentQueue:updatedDownloads:");
    
    for (SKDownload *download in downloads) {
        NSString *state = @"";
        NSString *error = @"";
        NSInteger errorCode = 0;
        NSString *progress_s = 0;
        NSString *timeRemaining_s = 0;
        
        SKPaymentTransaction *transaction = download.transaction;
        NSString *transactionId = transaction.transactionIdentifier;
        NSString *transactionReceipt = [[transaction transactionReceipt] base64EncodedStringWithOptions:0];
        SKPayment *payment = transaction.payment;
        NSString *productId = payment.productIdentifier;
        
        NSArray *callbackArgs;
        
        switch (download.downloadState) {

            case SKDownloadStateActive: {
                // Add to current downloads
                [self.currentDownloads setObject:download forKey:productId];
                
                state = @"DownloadStateActive";
                
                DLog(@"paymentQueue:updatedDownloads: Progress: %f", download.progress);
                DLog(@"paymentQueue:updatedDownloads: Time remaining: %f", download.timeRemaining);
                
                progress_s = [NSString stringWithFormat:@"%d", (int) (download.progress*100)];
                timeRemaining_s = [NSString stringWithFormat:@"%d", (int) download.timeRemaining];
                
                break;
            }
                
            case SKDownloadStateCancelled: {
                // Remove from current downloads
                [self.currentDownloads removeObjectForKey:productId];
                
                state = @"DownloadStateCancelled";
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
                [self transactionFinished:download.transaction];
                
                break;
            }

            case SKDownloadStateFailed: {
                // Remove from current downloads
                [self.currentDownloads removeObjectForKey:productId];
                
                state = @"DownloadStateFailed";
                error = transaction.error.localizedDescription;
                errorCode = transaction.error.code;
                DLog(@"paymentQueue:updatedDownloads: Download error %d %@", errorCode, error);
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
                [self transactionFinished:download.transaction];
                
                break;
            }
                
            case SKDownloadStateFinished: {
                // Remove from current downloads
                [self.currentDownloads removeObjectForKey:productId];
                
                state = @"DownloadStateFinished";
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
                [self transactionFinished:download.transaction];
                
                [self copyDownloadToDocuments:download]; // Copy download content to Documnents folder
                
                break;
            }
                
            case SKDownloadStatePaused: {
                // Add to current downloads
                [self.currentDownloads setObject:download forKey:productId];
                
                state = @"DownloadStatePaused";
                
                break;
            }
                
            case SKDownloadStateWaiting: {
                // Add to current downloads
                [self.currentDownloads setObject:download forKey:productId];
                state = @"DownloadStateWaiting";
                
                break;
            }
                
            default: {
                DLog(@"paymentQueue:updatedDownloads: Invalid Download State");
                return;
            }
        }
        
        DLog(@"paymentQueue:updatedDownloads: Number of currentDownloads: %d",[self.currentDownloads count]);
        DLog(@"paymentQueue:updatedDownloads: Product %@ in download state: %@", productId, state);
        
        
        callbackArgs = [NSArray arrayWithObjects:
            NILABLE(state),
            [NSNumber numberWithInt:errorCode],
            NILABLE(error),
            NILABLE(transactionId),
            NILABLE(productId),
            NILABLE(transactionReceipt),
            NILABLE(progress_s),
            NILABLE(timeRemaining_s),
            nil];

        if(_updatedDownloadsCallback) _updatedDownloadsCallback(callbackArgs);
    }
}

//
// paymentQueue:shouldAddStorePayment:forProduct:
// ----------------------------------------------
// Tells the observer that a user initiated an in-app purchase from the App Store.
//
// Return true to continue the transaction in your app.
// Return false to defer or cancel the transaction.
//        If you return false, you can continue the transaction later by manually adding the SKPayment
//        payment to the SKPaymentQueue queue.
//
// Discussion:
// -----------
// This delegate method is called when the user starts an in-app purchase in the App Store, and the
// transaction continues in your app. Specifically, if your app is already installed, the method is
// called automatically.
// If your app is not yet installed when the user starts the in-app purchase in the App Store, the
// user gets a notification when the app installation is complete. This method is called when the
// user taps the notification. Otherwise, if the user opens the app manually, this method is called
// only if the app is opened soon after the purchase was started.
//
- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product {

    // Here, I though I have to check for the existance of the product in the list of known products
    // and only do the processing if it is known.
    // The problem is: this call will most likely always happen before products have been loaded.
    // Since the "fix/ios-early-observer" change, transaction update events are queued for processing
    // till JS is ready to process them, so initiating the payment in all cases shouldn't be an issue.
    //
    // Only thing is: the developper needs to be sure to handle all types of IAP defines on the AppStore.
    // Which should be OK...
    //
    
    // Let's check if we already loaded this product informations.
    // Since it's provided to us generously, let's store them here.
    NSString *productId = payment.productIdentifier;
    if (self.products && product && ![self.products objectForKey:productId]) {
        [self.products setObject:product forKey:[NSString stringWithFormat:@"%@", productId]];
    }

    return YES;
}


#pragma mark - Utils

- (void) transactionFinished: (SKPaymentTransaction*) transaction {
    DLog(@"transactionFinished: %@", transaction.transactionIdentifier);

    NSArray *callbackArgs = [NSArray arrayWithObjects:
        NILABLE(@"PaymentTransactionStateFinished"),
        [NSNumber numberWithInt:transaction.error.code],
        NILABLE(transaction.error),
        NILABLE(transaction.transactionIdentifier),
        NILABLE(transaction.payment.productIdentifier),
        NILABLE(nil),
        nil];
    if(_transactionCallback) _transactionCallback(callbackArgs, transaction.error);
}

- (void) processPendingTransactionUpdates {

    DLog(@"processPendingTransactionUpdates");
    for (NSArray *ta in pendingTransactionUpdates) {
        [self processTransactionUpdate:ta[0] withArgs:ta[1]];
    }
    [pendingTransactionUpdates removeAllObjects];
}

- (void) processTransactionUpdate:(SKPaymentTransaction*)transaction withArgs:(NSArray*)callbackArgs {

    DLog(@"processTransactionUpdate:withArgs: transactionIdentifier=%@", callbackArgs[PT_INDEX_TRANSACTION_IDENTIFIER]);
    if(_transactionCallback) _transactionCallback(callbackArgs, nil);

    NSArray *downloads = nil;
    SKPaymentTransactionState state = transaction.transactionState;
    if (state == SKPaymentTransactionStateRestored || state == SKPaymentTransactionStatePurchased) {
        downloads = transaction.downloads;
    }

    BOOL canFinish = state == SKPaymentTransactionStateRestored
        || state == SKPaymentTransactionStateFailed
        || state == SKPaymentTransactionStatePurchased;

    if (downloads && [downloads count] > 0) {
        [[SKPaymentQueue defaultQueue] startDownloads:downloads];
    }
    else if (g_autoFinishEnabled && canFinish) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        [self transactionFinished:transaction];
    }
    else {
        [self.unfinishedTransactions setObject:transaction forKey:callbackArgs[PT_INDEX_TRANSACTION_IDENTIFIER]];
    }
}

/*
 * Download handlers
 */

- (void)copyDownloadToDocuments:(SKDownload *)download {

    DLog(@"copyDownloadToDocuments: Copying downloaded content to Documents...");
    
    NSString *source = [download.contentURL relativePath];
    NSDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:[source stringByAppendingPathComponent:@"ContentInfo.plist"]];
    NSString *targetFolder = [FileUtility getDocumentPath];
    NSString *content = [source stringByAppendingPathComponent:@"Contents"];
    NSArray *files;
    
    // Use folder if specified in .plist
    if ([dict objectForKey:@"Folder"]) {
        targetFolder = [targetFolder stringByAppendingPathComponent:[dict objectForKey:@"Folder"]];
        if(![FileUtility isFolderExist:targetFolder]){
            DLog(@"copyDownloadToDocuments: Creating Documents subfolder: %@", targetFolder);
            NSAssert([FileUtility createFolder:targetFolder], @"Failed to create Documents subfolder: %@", targetFolder);
        }
    }
    
    if ([dict objectForKey:@"Files"]) {
        DLog(@"copyDownloadToDocuments: Found Files key in .plist");
        files =  [dict objectForKey:@"Files"];
    }
    else {
        DLog(@"copyDownloadToDocuments: No Files key found in .plist - copy all files in Content folder");
        files = [FileUtility listFiles:content extension:nil];
    }
    
    for (NSString *file in files) {
        NSString *fcontent = [content stringByAppendingPathComponent:file];
        NSString *targetFile = [targetFolder stringByAppendingPathComponent:[file lastPathComponent]];
        
        DLog(@"copyDownloadToDocuments: Content path: %@", fcontent);
        
        NSAssert([FileUtility isFileExist:fcontent], @"Content path MUST be valid");
        
        // Copy the content to the documents folder
        NSAssert([FileUtility copyFile:fcontent dst:targetFile], @"Failed to copy the content");
        DLog(@"copyDownloadToDocuments: Copied %@ to %@", fcontent, targetFile);
        
        // Set flag so we don't backup on iCloud
        NSURL* url = [NSURL fileURLWithPath:targetFile];
        [url setResourceValue: [NSNumber numberWithBool: YES] forKey: NSURLIsExcludedFromBackupKey error: Nil];
    }
    
}

@end
/**
 * Receive refreshed app receipt
 */
@implementation RefreshReceiptDelegate

@synthesize plugin;

- (void) requestDidFinish:(SKRequest *)request {

    DLog(@"RefreshReceiptDelegate.requestDidFinish: Got refreshed receipt");
    NSString *base64 = nil;
    NSData *receiptData = [self.plugin appStoreReceiptData];
    if (receiptData != nil) {
        base64 = [receiptData convertToBase64];
        // DLog(@"base64 receipt: %@", base64);
    }
    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *callbackArgs = [NSArray arrayWithObjects:
        NILABLE(base64),
        NILABLE([bundle.infoDictionary objectForKey:@"CFBundleIdentifier"]),
        NILABLE([bundle.infoDictionary objectForKey:@"CFBundleShortVersionString"]),
        NILABLE([bundle.infoDictionary objectForKey:@"CFBundleNumericVersion"]),
        NILABLE([bundle.infoDictionary objectForKey:@"CFBundleSignature"]),
        nil];
    DLog(@"RefreshReceiptDelegate.requestDidFinish: Send new receipt data");
    if(_callback) _callback(callbackArgs, nil);
}

- (void):(SKRequest *)request didFailWithError:(NSError*) error {
    DLog(@"RefreshReceiptDelegate.request didFailWithError: In-App Store unavailable (ERROR %li)", (unsigned long)error.code);
    DLog(@"RefreshReceiptDelegate.request didFailWithError: %@", [error localizedDescription]);
    if(_callback) _callback(nil, error);
}

@end

/**
 * Receives product data for multiple productIds and passes arrays of
 * js objects containing these data to a single callback method.
 */
@implementation BatchProductsRequestDelegate

@synthesize plugin;

- (void)productsRequest:(SKProductsRequest*)request didReceiveResponse:(SKProductsResponse*)response {

    DLog(@"BatchProductsRequestDelegate.productsRequest:didReceiveResponse:");
    NSMutableArray *validProducts = [NSMutableArray array];
    DLog(@"BatchProductsRequestDelegate.productsRequest:didReceiveResponse: Has %li validProducts", (unsigned long)[response.products count]);
    for (SKProduct *product in response.products) {
        // Get the currency code from the NSLocale object
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [numberFormatter setLocale:product.priceLocale];
        NSString *currencyCode = [numberFormatter currencyCode];
        
        DLog(@"BatchProductsRequestDelegate.productsRequest:didReceiveResponse:  - %@: %@", product.productIdentifier, product.localizedTitle);
        [validProducts addObject:
            [NSDictionary dictionaryWithObjectsAndKeys:
                NILABLE(product.productIdentifier),    @"id",
                NILABLE(product.localizedTitle),       @"title",
                NILABLE(product.localizedDescription), @"description",
                NILABLE(product.localizedPrice),       @"price",
                NILABLE(currencyCode),                 @"currency",
                nil]];
        [self.plugin.products setObject:product forKey:[NSString stringWithFormat:@"%@", product.productIdentifier]];
    }

    NSArray *callbackArgs = [NSArray arrayWithObjects:
        NILABLE(validProducts),
        NILABLE(response.invalidProductIdentifiers),
        nil];

    if(_callback) _callback(callbackArgs, nil);
    DLog(@"BatchProductsRequestDelegate.productsRequest:didReceiveResponse: sendPluginResult: %@", callbackArgs);

    // Now that we have loaded product informations, we can safely process pending transactions.
    g_initialized = YES;
    [self.plugin processPendingTransactionUpdates];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    DLog(@"BatchProductsRequestDelegate.request:didFailWithError: AppStore unavailable (ERROR %li)", (unsigned long)error.code);

    NSString *localizedDescription = [error localizedDescription];
    if (!localizedDescription)
        localizedDescription = @"AppStore unavailable";
    else
        DLog(@"BatchProductsRequestDelegate.request:didFailWithError: %@", localizedDescription);
    if(_callback) _callback(nil, error);
}

@end

