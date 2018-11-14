#import "Iap.h"
#include "scripting/js-bindings/manual/cocos2d_specifics.hpp"
#include "scripting/js-bindings/manual/js_manual_conversions.h"
#include <sstream>
#include "base/CCDirector.h"
#include "base/CCScheduler.h"
#include "utils/PluginUtils.h"
#import "../proj.ios_mac/ios/InAppPurchase.h"
#include "jsapi.h"


static InAppPurchase *inAppPurchase = nil;
static void cpp_requestResult(int callbackId, std::string errorStr, std::string resultStr);

static void printLog(const char* str) {
    CCLOG("%s", str);
}

// FROM JS VAL

static NSArray<NSString*>* jsval_to_array(JSContext* cx, JS::HandleValue v) {
    JS::RootedObject jsobj(cx);
    bool ok = JS_ValueToObject( cx, v, &jsobj );
    JSB_PRECONDITION2( ok, cx, nil, "Error converting value to object");
    JSB_PRECONDITION2( jsobj && JS_IsArrayObject( cx, jsobj),  cx, nil, "Object must be an array");

    uint32_t len = 0;
    JS_GetArrayLength(cx, jsobj, &len);

    NSMutableArray *result = [NSMutableArray new];
    for (uint32_t i=0; i < len; i++) {
        JS::RootedValue elt(cx);
        if (JS_GetElement(cx, jsobj, i, &elt)) {

            if (elt.isString()) {
                JSStringWrapper str(elt.toString(), cx);
                [result addObject:[NSString stringWithUTF8String:str.get()]];
            }
        }
    }

    return result;
}

static NSString* jsval_to_string(JSContext* cx, JS::HandleValue v)
{
    if (v.isNullOrUndefined())
    {
        return nil;
    }
    if (v.isString()) {
        JSStringWrapper valueWrapper(v.toString(), cx);
        return [NSString stringWithUTF8String:valueWrapper.get()];
    } else {
        return nil;
    }
}

static NSDictionary* jsval_to_dictionary(JSContext* cx, JS::HandleValue v)
{
    if (v.isNullOrUndefined())
    {
        return nil;
    }
    
    JS::RootedObject tmp(cx, v.toObjectOrNull());
    if (!tmp)
    {
        CCLOG("%s", "jsval_to_dictionary: the jsval is not an object.");
        return nil;
    }
    NSMutableDictionary *result = [NSMutableDictionary new];
    
    JS::RootedObject it(cx, JS_NewPropertyIterator(cx, tmp));
    
    while (true)
    {
        JS::RootedId idp(cx);
        JS::RootedValue key(cx);
        if (! JS_NextProperty(cx, it, idp.address()) || ! JS_IdToValue(cx, idp, &key))
        {
            return nil; // error
        }
        
        if (key.isNullOrUndefined())
        {
            break; // end of iteration
        }
        
        if (!key.isString())
        {
            continue; // only take account of string key
        }
        
        JSStringWrapper keyWrapper(key.toString(), cx);
        
        JS::RootedValue value(cx);
        JS_GetPropertyById(cx, tmp, idp, &value);
        NSString *keyString = [NSString stringWithUTF8String:keyWrapper.get()];
        if (value.isString()) {
            JSStringWrapper valueWrapper(value.toString(), cx);
            result[keyString] = [NSString stringWithUTF8String:valueWrapper.get()];
        } else if(value.isBoolean()) {
            result[keyString] = [NSNumber numberWithBool:value.get().toBoolean()];
        } else if(value.isDouble()) {
            result[keyString] = [NSNumber numberWithDouble:value.get().toDouble()];
        } else if(value.isInt32()) {
            result[keyString] = [NSNumber numberWithInteger:value.get().toInt32()];
        } else {
            CCASSERT(false, "jsval_to_dictionary: not supported map type");
        }
    }
    
    return result;
}

// TO JS VAL

static jsval object_to_jsval(JSContext *cx, id object);

static jsval string_to_jsval(JSContext *cx, NSString* string)
{
    return std_string_to_jsval(cx, std::string([string UTF8String]));
}

static jsval number_to_jsval(JSContext *cx, NSNumber* number)
{
    return DOUBLE_TO_JSVAL(number.doubleValue);
}

static jsval array_to_jsval(JSContext *cx, NSArray* array)
{
    JS::RootedObject jsretArr(cx, JS_NewArrayObject(cx, array.count));
    
    int i = 0;
    for(id val in array) {
        JS::RootedValue arrElement(cx);
        arrElement = object_to_jsval(cx, val);
        if (!JS_SetElement(cx, jsretArr, i, arrElement)) {
            break;
        }
        ++i;
    }
    return OBJECT_TO_JSVAL(jsretArr);
}

static jsval dictionary_to_jsval(JSContext* cx, NSDictionary *dict)
{
    JS::RootedObject proto(cx);
    JS::RootedObject parent(cx);
    JS::RootedObject jsRet(cx, JS_NewObject(cx, NULL, proto, parent));

    for(NSString* key in dict.allKeys) {
        JS::RootedValue element(cx);
        
        id obj = dict[key];
        element = object_to_jsval(cx, obj);
        JS_SetProperty(cx, jsRet, [key UTF8String], element);
    }
    return OBJECT_TO_JSVAL(jsRet);
}

static jsval object_to_jsval(JSContext *cx, id object)
{
    if([object isKindOfClass:NSString.class]) {
        return string_to_jsval(cx, object);
    } else if([object isKindOfClass:NSDictionary.class]) {
        return dictionary_to_jsval(cx, object);
    } else if([object isKindOfClass:NSArray.class]) {
        return array_to_jsval(cx, object);
    } else if([object isKindOfClass:NSNumber.class]) {
        return number_to_jsval(cx, object);
    } else if([object isKindOfClass:NSNull.class]) {
        return JSVAL_NULL;
    } else {
        NSLog(@"Error: unknown value class %@", object);
        return JSVAL_NULL;
    }
}

static void callback(int callbackId, id result, NSString* errorStr)
{
    CallbackFrame *cb = CallbackFrame::getById(callbackId);
    if(!cb) {
        printLog("requestResult: callbackId not found!");
        return;
    }

    JSAutoRequest rq(cb->cx);
    JSAutoCompartment ac(cb->cx, cb->_ctxObject.ref());

    JS::AutoValueVector valArr(cb->cx);
    if(errorStr != nil && errorStr.length > 0) {
        valArr.append(string_to_jsval(cb->cx, errorStr));
        valArr.append(JSVAL_NULL);
    } else {
        valArr.append(JSVAL_NULL);
        jsval js_result = object_to_jsval(cb->cx, result);
        valArr.append(js_result);
    };

    JS::HandleValueArray funcArgs = JS::HandleValueArray::fromMarkedLocation(2, valArr.begin());
    cb->call(funcArgs);
    printLog("requestResult finished");
    delete cb;
}

///////////////////////////////////////
//
//  JS API
//
///////////////////////////////////////

static bool js_iap_init(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_init");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 4) {
        // skus, internalValidation, callback, this
        inAppPurchase = [InAppPurchase new];

        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(3), args.get(2));
        JS::RootedValue arg0Val(cx, args.get(0));
        NSArray *skus = jsval_to_array(cx, arg0Val);
        //bool arg1 = JS::ToBoolean(JS::RootedValue(cx, args.get(1)));
        if([inAppPurchase setup]) {
            rec.rval().set(JSVAL_TRUE);
            [inAppPurchase load:skus withCallback:^(NSArray* result, NSError* err) {
                    callback(cb->callbackId, result, err.localizedDescription);
                }];
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool js_iap_get_purchases(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_get_purchases");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 2) {
        // callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(1), args.get(0));
        NSArray<NSString*>* ids = [inAppPurchase getUnfinishedTransactions];
        callback(cb->callbackId, ids, nil);
        rec.rval().set(JSVAL_TRUE);
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool js_iap_buy(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_buy");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 4) {
        // sku, payload, callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(3), args.get(2));
        NSString *sku = jsval_to_string(cx, args.get(0));
        [inAppPurchase purchase:sku withCallback:^(NSArray* result, NSError* err) {
            callback(cb->callbackId, result, err.localizedDescription);
        }];
        rec.rval().set(JSVAL_TRUE);
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool js_iap_subscribe(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_subscribe");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 5) {
        // sku, payload, oldPurchasedSkus, callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(4), args.get(3));
        NSString *sku = jsval_to_string(cx, args.get(0));
        [inAppPurchase purchase:sku withCallback:^(NSArray* result, NSError* err) {
            callback(cb->callbackId, result, err.localizedDescription);
        }];
        rec.rval().set(JSVAL_TRUE);
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool js_iap_consume(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_consume");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 3) {
        // sku, callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(2), args.get(1));
        NSString *sku = jsval_to_string(cx, args.get(0));
        inAppPurchase.transactionCallback = ^(NSArray* result, NSError* err)
            {
             callback(cb->callbackId, result, err.localizedDescription);
            };
        [inAppPurchase finishTransaction:sku];
        rec.rval().set(JSVAL_TRUE);
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool js_iap_available_products(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_available_products");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 2) {
        // callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(1), args.get(0));
        NSMutableArray *result = [NSMutableArray new];
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        for(SKProduct *product in inAppPurchase.products) {
            [numberFormatter setLocale:product.priceLocale];
            [result addObject:@{
                    @"productId": product.productIdentifier,
                    @"type": @"",
                    @"price": [numberFormatter stringFromNumber:product.price],
                    @"title": product.localizedTitle,
                    @"name": product.localizedTitle,
                    @"description": product.localizedDescription,
                    @"price_currency_code": product.priceLocale.languageCode
            }];
        }
        callback(cb->callbackId, result, nil);
        rec.rval().set(JSVAL_TRUE);
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool js_iap_product_details(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_product_details");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 3) {
        // skus, callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(2), args.get(1));
        NSArray *skus = jsval_to_array(cx, args.get(0));
        [inAppPurchase load:skus withCallback:^(NSArray* result, NSError* err) {
                callback(cb->callbackId, result, err.localizedDescription);
            }];
        rec.rval().set(JSVAL_TRUE);
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool js_iap_restore(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_restore");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 2) {
        // callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(1), args.get(0));
        [inAppPurchase appStoreRefreshReceipt:^(NSArray* result, NSError* err){
                callback(cb->callbackId, result, err.localizedDescription);
            }];
        rec.rval().set(JSVAL_TRUE);
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool js_iap_debug(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_debug");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 1) {
        bool debug = JS::ToBoolean(JS::RootedValue(cx, args.get(0)));
        [InAppPurchase debug:debug];
        rec.rval().set(JSVAL_TRUE);
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

///////////////////////////////////////
//
//  Register JS API
//
///////////////////////////////////////

void register_all_iap_framework(JSContext* cx, JS::HandleObject obj) {
    printLog("[Iap] register js interface");
    JS::RootedObject ns(cx);
    get_or_create_js_obj(cx, obj, "iap", &ns);

    // initialize plugin, args: array of skus, internal validation flag (bool), callback func, this pointer
    JS_DefineFunction(cx, ns, "init", js_iap_init, 4, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    
    // get purchased items, args: callback func, this pointer
    JS_DefineFunction(cx, ns, "get_purchases", js_iap_get_purchases, 2, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    
    // purchase an item, args: sku, payload, callback func, this pointer
    JS_DefineFunction(cx, ns, "buy", js_iap_buy, 4, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    
    // subscribe, args: sku, payload, oldPurchasedSkus (array of strings), callback func, this pointer
    JS_DefineFunction(cx, ns, "subscribe", js_iap_subscribe, 5, JSPROP_PERMANENT | JSPROP_ENUMERATE);

    // consume purchased item, args: sku, callback func, this pointer
    JS_DefineFunction(cx, ns, "consume", js_iap_consume, 3, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    
    // return available products for purchasing, args: callback func, this pointer
    JS_DefineFunction(cx, ns, "available_products", js_iap_available_products, 2, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    
    // return product details, args: sku, callback func, this pointer
    JS_DefineFunction(cx, ns, "product_details", js_iap_product_details, 3, JSPROP_PERMANENT | JSPROP_ENUMERATE);

    // stub for restore purchasings (will be implemented for iOS)
    JS_DefineFunction(cx, ns, "restore", js_iap_restore, 0, JSPROP_PERMANENT | JSPROP_ENUMERATE);

    // enable/disable debugging logs
    JS_DefineFunction(cx, ns, "set_debug", js_iap_debug, 1, JSPROP_PERMANENT | JSPROP_ENUMERATE);
}
