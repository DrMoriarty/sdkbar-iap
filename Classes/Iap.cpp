#include "Iap.hpp"
#include "scripting/js-bindings/manual/cocos2d_specifics.hpp"
#include "scripting/js-bindings/manual/js_manual_conversions.h"
#include "platform/android/jni/JniHelper.h"
#include <jni.h>
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
//  JNI Utils
//
///////////////////////////////////////

// call: boolean javaMethod()
static bool callMethod0(const char* method) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "com/tapclap/inappbilling/InAppBillingPlugin", method, "()Z")) {
        return false;
    }
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return res;
}

// call: boolean javaMethod(final int param)
static bool callMethod1(const char* method, int callbackId) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "com/tapclap/inappbilling/InAppBillingPlugin", method, "(I)Z")) {
        return false;
    }
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, callbackId);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
}

// call: boolean javaMethod(final String param))
static bool callMethod1(const char* method, const std::string &param) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "com/tapclap/inappbilling/InAppBillingPlugin", method, "(Ljava/lang/String;)Z")) {
        return false;
    }
    jstring s = methodInfo.env->NewStringUTF(param.c_str());
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, s);
    methodInfo.env->DeleteLocalRef(s);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
}

// call: boolean javaMethod(final String[] param)
static bool callMethod1(const char* method, const std::vector<std::string> &param) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "com/tapclap/inappbilling/InAppBillingPlugin", method, "([Ljava/lang/String;)Z")) {
        return false;
    }
    jobjectArray args = 0;
    args = methodInfo.env->NewObjectArray(param.size(), methodInfo.env->FindClass("java/lang/String"), 0);
    for(int i=0; i<param.size(); i++) {
        jstring s = methodInfo.env->NewStringUTF(param[i].c_str());
        methodInfo.env->SetObjectArrayElement(args, i, s);
    }
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, args);
    methodInfo.env->DeleteLocalRef(args);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
}

// call: boolean javaMethod(final String param1, final int param2)
static bool callMethod2(const char* method, const std::string &param, int callbackId) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "com/tapclap/inappbilling/InAppBillingPlugin", method, "(Ljava/lang/String;I)Z")) {
        return false;
    }
    jstring s = methodInfo.env->NewStringUTF(param.c_str());
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, s, callbackId);
    methodInfo.env->DeleteLocalRef(s);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
}

// call: boolean javaMethod(final String[] param1, final int param2)
static bool callMethod2(const char* method, const std::vector<std::string> &param, int callbackId) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "com/tapclap/inappbilling/InAppBillingPlugin", method, "([Ljava/lang/String;I)Z")) {
        return false;
    }
    jobjectArray args = 0;
    args = methodInfo.env->NewObjectArray(param.size(), methodInfo.env->FindClass("java/lang/String"), 0);
    for(int i=0; i<param.size(); i++) {
        jstring s = methodInfo.env->NewStringUTF(param[i].c_str());
        methodInfo.env->SetObjectArrayElement(args, i, s);
    }
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, args, callbackId);
    methodInfo.env->DeleteLocalRef(args);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
}

// call: boolean javaMethod(final String param1, final String param2, final int param3)
static bool callMethod3(const char* method, const std::string &param1, const std::string &param2, int callbackId) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "com/tapclap/inappbilling/InAppBillingPlugin", method, "(Ljava/lang/String;Ljava/lang/String;I)Z")) {
        return false;
    }
    jstring s1 = methodInfo.env->NewStringUTF(param1.c_str());
    jstring s2 = methodInfo.env->NewStringUTF(param2.c_str());
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, s1, s2, callbackId);
    methodInfo.env->DeleteLocalRef(s2);
    methodInfo.env->DeleteLocalRef(s1);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
}

// call: boolean javaMethod(final String param1, final String param2, final String[] param3, final int param4)
static bool callMethod4(const char* method, const std::string &param1, const std::string &param2, const std::vector<std::string> &param3, int callbackId) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "com/tapclap/inappbilling/InAppBillingPlugin", method, "(Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;I)Z")) {
        return false;
    }
    jstring s1 = methodInfo.env->NewStringUTF(param1.c_str());
    jstring s2 = methodInfo.env->NewStringUTF(param2.c_str());
    jobjectArray arr = 0;
    arr = methodInfo.env->NewObjectArray(param3.size(), methodInfo.env->FindClass("java/lang/String"), 0);
    for(int i=0; i<param3.size(); i++) {
        jstring s = methodInfo.env->NewStringUTF(param3[i].c_str());
        methodInfo.env->SetObjectArrayElement(arr, i, s);
    }
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, s1, s2, arr, callbackId);
    methodInfo.env->DeleteLocalRef(arr);
    methodInfo.env->DeleteLocalRef(s2);
    methodInfo.env->DeleteLocalRef(s1);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
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
    if(argc == 3) {
        // skus, callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(2), args.get(1));
        std::vector<std::string> arg0;
        JS::RootedValue arg0Val(cx, args.get(0));
        bool ok = jsval_to_std_vector_string(cx, arg0Val, &arg0);
        if(callMethod2("init", arg0, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
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
        if(callMethod1("getPurchases", cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
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
        if(callMethod3("buy", arg0, arg1, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
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
        if(callMethod4("subscribe", arg0, arg1, arg2, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
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
        if(callMethod2("consumePurchase", arg0, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
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
        if(callMethod1("getAvailableProducts", cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
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
    if(argc == 2) {
        // skus, callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(2), args.get(1));
        std::vector<std::string> arg0;
        JS::RootedValue arg0Val(cx, args.get(0));
        bool ok = jsval_to_std_vector_string(cx, arg0Val, &arg0);
        if(callMethod2("getProductDetails", arg0, cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
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

    JS_DefineFunction(cx, ns, "init", js_iap_init, 3, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    JS_DefineFunction(cx, ns, "get_purchases", js_iap_get_purchases, 2, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    JS_DefineFunction(cx, ns, "buy", js_iap_buy, 4, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    JS_DefineFunction(cx, ns, "subscribe", js_iap_subscribe, 5, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    JS_DefineFunction(cx, ns, "consume", js_iap_consume, 3, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    JS_DefineFunction(cx, ns, "available_products", js_iap_available_products, 2, JSPROP_PERMANENT | JSPROP_ENUMERATE);
    JS_DefineFunction(cx, ns, "product_details", js_iap_product_details, 3, JSPROP_PERMANENT | JSPROP_ENUMERATE);
}

///////////////////////////////////////
//
//  JNI to CPP tools
//
///////////////////////////////////////

static void cpp_requestResult(int callbackId, std::string errorStr, std::string resultStr)
{
    cocos2d::Director::getInstance()->getScheduler()->performFunctionInCocosThread([callbackId, errorStr, resultStr] {
            CallbackFrame *cb = CallbackFrame::getById(callbackId);
            if(!cb) {
                printLog("requestResult: callbackId not found!");
                return;
            }

            JSAutoRequest rq(cb->cx);
            JSAutoCompartment ac(cb->cx, cb->_ctxObject.ref());

            JS::AutoValueVector valArr(cb->cx);
            if(resultStr.size() > 0) {
                valArr.append(JSVAL_NULL);
                Status err;
                JS::RootedValue rval(cb->cx);
                std::wstring attrsW = wstring_from_utf8(std::string(resultStr), &err);
                utf16string string(attrsW.begin(), attrsW.end());
                if(!JS_ParseJSON(cb->cx, reinterpret_cast<const char16_t*>(string.c_str()), (uint32_t)string.size(), &rval))
                    printLog("JSON Error");
                valArr.append(rval);
            } else {
                valArr.append(std_string_to_jsval(cb->cx, errorStr));
                valArr.append(JSVAL_NULL);
            };
            JS::HandleValueArray funcArgs = JS::HandleValueArray::fromMarkedLocation(2, valArr.begin());
            cb->call(funcArgs);
            printLog("requestResult finished");
            delete cb;
        });
}

void Java_com_tapclap_inappbilling_InAppBillingPlugin_requestResult(JNIEnv* env, jobject thiz, jint callbackId, jstring err, jstring result)
{
    printLog("Get requestResult");
    std::string s_err;
    std::string s_res;
    if(result != NULL) {
        const char* ch = env->GetStringUTFChars(result, NULL);
        s_res = ch;
        env->ReleaseStringUTFChars(result, ch);
    }
    if(err != NULL) {
        const char* ch = env->GetStringUTFChars(err, NULL);
        s_err = ch;
        env->ReleaseStringUTFChars(err, ch);
    }

    cpp_requestResult(callbackId, s_err, s_res);
}

