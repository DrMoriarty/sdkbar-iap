//
//  InAppPurchase.h
//  beetight
//
//  Created by Matt Kane on 20/02/2011.
//  Copyright 2011 Matt Kane. All rights reserved.
//

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

- (BOOL) canMakePayments;

- (BOOL) setup;
- (void) load:(^(void)(NSArray* result))callback;
- (void) purchase: (NSString*)identifier;
- (void) appStoreReceipt;
- (void) appStoreRefreshReceipt;

- (void) pause;
- (void) resume;
- (void) cancel;

- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;
- (void) paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;
- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue;
- (void) paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads;

- (void) debug;
- (void) autoFinish;
- (BOOL) finishTransaction;

- (void) onReset;
- (void) processPendingTransactionUpdates;
- (void) processTransactionUpdate:(SKPaymentTransaction*)transaction withArgs:(NSArray*)callbackArgs;
@end

@interface BatchProductsRequestDelegate : NSObject <SKProductsRequestDelegate> {
}

@property (nonatomic,retain) InAppPurchase* plugin;
//@property (nonatomic,retain) CDVInvokedUrlCommand* command;
@end;

@interface RefreshReceiptDelegate : NSObject <SKRequestDelegate> {
}

@property (nonatomic,retain) InAppPurchase* plugin;
//@property (nonatomic,retain) CDVInvokedUrlCommand* command;
@end
