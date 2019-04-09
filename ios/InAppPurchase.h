#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>


#import "SKProduct+LocalizedPrice.h"
#import "FileUtility.h"

@class BatchProductsRequestDelegate;
@class RefreshReceiptDelegate;

@interface InAppPurchase : NSObject <SKPaymentTransactionObserver> {
    NSMutableDictionary *products;
    NSMutableDictionary *unfinishedTransactions;
    NSMutableDictionary *currentDownloads;
    NSMutableArray *pendingTransactionUpdates;
}
@property (nonatomic,retain) NSMutableDictionary *products;
@property (nonatomic, retain) NSMutableDictionary *currentDownloads;
@property (nonatomic, retain) NSMutableDictionary *unfinishedTransactions;
@property (nonatomic, retain) NSMutableArray *pendingTransactionUpdates;
@property (nonatomic, strong) SKProductsRequest* productsRequest;
@property (nonatomic, strong) BatchProductsRequestDelegate* productsRequestDelegate;
@property (nonatomic, strong) SKReceiptRefreshRequest* receiptRefreshRequest;
@property (nonatomic, strong) RefreshReceiptDelegate* refreshReceiptDelegate;

@property (nonatomic, strong) void(^updatedDownloadsCallback)(SKDownload* download);
//@property (nonatomic, strong) void(^purchaseRestorationCallback)(NSError* err);
@property (nonatomic, strong) void(^transactionCallback)(SKPaymentTransaction* transaction, NSError* err);

- (BOOL) canMakePayments;

- (BOOL) setup;
- (void) load:(NSArray*)inArray withCallback:(void(^)(NSArray* result, NSError* err))callback;
- (void) purchase: (NSString*)identifier withCallback:(void(^)(SKPaymentTransaction* transaction, NSError* err))callback;
- (NSString*) appStoreReceipt;
- (void) appStoreRefreshReceipt:(void(^)(NSArray* result, NSError* err))callback;
- (void) restoreCompletedTransactionsWithCallback:(void(^)(SKPaymentTransaction* transaction, NSError* err))callback;

- (void) pauseDownloads;
- (void) resumeDownloads;
- (void) cancelDownloads;

+ (void) debug:(BOOL)debug;
+ (void) autoFinish:(BOOL)autoFinish;
- (BOOL) finishTransaction:(NSString*)identifier;
- (NSArray<NSString*>*) getUnfinishedTransactions;

#pragma mark - SKPaymentTransactionObserver

- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;
- (void) paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;
- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue;
- (void) paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads;

#pragma mark - Utils

- (void) processPendingTransactionUpdates;
- (void) processTransactionUpdate:(SKPaymentTransaction*)transaction;

@end

@interface BatchProductsRequestDelegate : NSObject <SKProductsRequestDelegate> {
}

@property (nonatomic, retain) InAppPurchase* plugin;
@property (nonatomic, copy) void(^callback)(NSArray* result, NSError* err);
@end;

@interface RefreshReceiptDelegate : NSObject <SKRequestDelegate> {
}

@property (nonatomic, retain) InAppPurchase* plugin;
@property (nonatomic, copy) void(^callback)(NSArray* result, NSError* err);
@end
