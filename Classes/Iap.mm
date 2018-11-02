#include "Iap.h"
#include "scripting/js-bindings/manual/cocos2d_specifics.hpp"
#include "scripting/js-bindings/manual/js_manual_conversions.h"
#include <sstream>
#include "base/CCDirector.h"
#include "base/CCScheduler.h"
#include "utils/PluginUtils.h"

static void cpp_requestResult(int callbackId, std::string errorStr, std::string resultStr);

static void printLog(const char* str) {
    CCLOG("%s", str);
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
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(3), args.get(2));
        std::vector<std::string> arg0;
        JS::RootedValue arg0Val(cx, args.get(0));
        bool ok = jsval_to_std_vector_string(cx, arg0Val, &arg0);
        bool arg1 = JS::ToBoolean(JS::RootedValue(cx, args.get(1)));
        /*
        if(callMethod3("init", arg0, arg1, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        */
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
        /*
        if(callMethod1("getPurchases", cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        */
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
        std::string arg0;
        JS::RootedValue arg0Val(cx, args.get(0));
        bool ok = jsval_to_std_string(cx, arg0Val, &arg0);
        std::string arg1;
        JS::RootedValue arg1Val(cx, args.get(1));
        ok &= jsval_to_std_string(cx, arg1Val, &arg1);
        /*
        if(callMethod3("buy", arg0, arg1, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        */
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
        std::string arg0;
        JS::RootedValue arg0Val(cx, args.get(0));
        bool ok = jsval_to_std_string(cx, arg0Val, &arg0);
        std::string arg1;
        JS::RootedValue arg1Val(cx, args.get(1));
        ok &= jsval_to_std_string(cx, arg1Val, &arg1);
        std::vector<std::string> arg2;
        JS::RootedValue arg2Val(cx, args.get(2));
        ok &= jsval_to_std_vector_string(cx, arg2Val, &arg2);
        /*
        if(callMethod4("subscribe", arg0, arg1, arg2, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        */
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
        std::string arg0;
        JS::RootedValue arg0Val(cx, args.get(0));
        bool ok = jsval_to_std_string(cx, arg0Val, &arg0);
        /*
        if(callMethod2("consumePurchase", arg0, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        */
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
        /*
        if(callMethod1("getAvailableProducts", cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        */
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
        std::vector<std::string> arg0;
        JS::RootedValue arg0Val(cx, args.get(0));
        bool ok = jsval_to_std_vector_string(cx, arg0Val, &arg0);
        /*
        if(callMethod2("getProductDetails", arg0, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        */
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool js_iap_restore(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_restore");
    return true;
}

static bool js_iap_debug(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("js_iap_debug");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 1) {
        bool debug = JS::ToBoolean(JS::RootedValue(cx, args.get(0)));
        /*
        if(callMethod1("setDebug", debug)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        */
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

