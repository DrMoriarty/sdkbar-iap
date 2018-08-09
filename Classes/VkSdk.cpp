//
//  VkSdk.m
//
//  Created by Vasiliy on 17.04.17.
//
//

#include "VkSdk.hpp"
#include "scripting/js-bindings/manual/cocos2d_specifics.hpp"
#include "scripting/js-bindings/manual/js_manual_conversions.h"
#include "platform/android/jni/JniHelper.h"
#include <jni.h>
#include <sstream>
#include "base/CCDirector.h"
#include "base/CCScheduler.h"
#include "utils/PluginUtils.h"

static void cpp_loginResult(int callbackId, std::string tokenStr);
static void cpp_requestResult(int callbackId, std::string errorStr, std::string resultStr);

static void printLog(const char* str) {
    CCLOG("%s", str);
    /*
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "org/cocos2dx/javascript/AppActivity", "printLog", "(Ljava/lang/String;)V")) {
        return;
    }
    jstring s = methodInfo.env->NewStringUTF(str);
    methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID, s);
    methodInfo.env->DeleteLocalRef(s);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    */
}

static bool vkMethod0(const char* method) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "org/cocos2dx/javascript/VkPlugin", method, "()Z")) {
        return false;
    }
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return res;
}

static bool vkMethod1(const char* method, const char* param) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "org/cocos2dx/javascript/VkPlugin", method, "(Ljava/lang/String;)Z")) {
        return false;
    }
    jstring s = methodInfo.env->NewStringUTF(param);
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, s);
    methodInfo.env->DeleteLocalRef(s);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
}

static bool vkMethod1(const char* method, std::vector<std::string> &param) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "org/cocos2dx/javascript/VkPlugin", method, "([Ljava/lang/String;)Z")) {
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


static bool vkMethod2(const char* method, const char* param, int callbackId) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "org/cocos2dx/javascript/VkPlugin", method, "(Ljava/lang/String;I)Z")) {
        return false;
    }
    jstring s = methodInfo.env->NewStringUTF(param);
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, s, callbackId);
    methodInfo.env->DeleteLocalRef(s);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
}

static bool vkMethod2(const char* method, std::vector<std::string> &param, int callbackId) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "org/cocos2dx/javascript/VkPlugin", method, "([Ljava/lang/String;I)Z")) {
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

static bool vkMethod3(const char* method, const char* param1, const char* param2, int callbackId) {
    cocos2d::JniMethodInfo methodInfo;

    if (! cocos2d::JniHelper::getStaticMethodInfo(methodInfo, "org/cocos2dx/javascript/VkPlugin", method, "(Ljava/lang/String;Ljava/lang/String;I)Z")) {
        return false;
    }
    jstring s1 = methodInfo.env->NewStringUTF(param1);
    jstring s2 = methodInfo.env->NewStringUTF(param2);
    bool res = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, s1, s2, callbackId);
    methodInfo.env->DeleteLocalRef(s2);
    methodInfo.env->DeleteLocalRef(s1);
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    return true;
}


static bool jsb_vksdk_init(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("jsb_vksdk_init");
    JSAutoRequest rq(cx);
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    js_proxy_t *proxy = jsb_get_js_proxy(obj);
    //PluginProtocol* cobj = (PluginProtocol *)(proxy ? proxy->ptr : NULL);
    //JSB_PRECONDITION2( cobj, cx, false, "Invalid Native Object");
    CCLOG("init, param count:%d.\n", argc);
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    bool ok = true;
    if(argc == 1) {
        std::string arg0;
        JS::RootedValue arg0Val(cx, args.get(0));
        ok &= jsval_to_std_string(cx, arg0Val, &arg0);
        CCLOG("arg0: %s\n", arg0.c_str());
        /*
        if(vkMethod1("initPlugin", arg0.c_str())) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        */
        //cobj->callFuncWithParam(arg0.c_str(), NULL);
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool jsb_vksdk_login(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("jsb_vksdk_login");
    JSAutoRequest rq(cx);
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    CCLOG("init, param count:%d.\n", argc);
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    bool ok = true;
    if(argc == 3) {
        // permissions, callback, this
        //JS::RootedObject targetObj(cx);
        //targetObj.set(args.get(2).toObjectOrNull());
        CallbackFrame *loginCallback = new CallbackFrame(cx, obj, args.get(2), args.get(1));
        std::vector<std::string> arg0;
        JS::RootedValue arg0Val(cx, args.get(0));
        ok &= jsval_to_std_vector_string(cx, arg0Val, &arg0);
        if(arg0.size() == 0) {
            arg0.push_back("wall");
            arg0.push_back("offline");
        }
        if(vkMethod2("login", arg0, loginCallback->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        CCLOG("permissions size: %d\n", (int)arg0.size());
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
    return true;
}

static bool jsb_vksdk_logout(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("jsb_vksdk_logout");
    JSAutoRequest rq(cx);
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 0) {
        if(vkMethod0("logout")) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool jsb_vksdk_loggedin(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("jsb_vksdk_loggedin");
    JSAutoRequest rq(cx);
    if(argc == 0) {
        JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
        
        // Access to the callee must occur before accessing/setting
        // the return value.
        JSObject &callee = rec.callee();
        rec.rval().set(JS::ObjectValue(callee));

        if(vkMethod0("isLoggedIn")) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool jsb_vksdk_users_get(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("jsb_vksdk_users_get");
    JSAutoRequest rq(cx);
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 3) {
        //JS::RootedObject targetObj(cx);
        //targetObj.set(args.get(2).toObjectOrNull());
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(2), args.get(1));
        JS::RootedValue arg0Val(cx, args.get(0));
        std::string res = Stringify(cx, arg0Val);
        if(vkMethod2("usersGet", res.c_str(), cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool jsb_vksdk_friends_get(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("jsb_vksdk_friends_get");
    JSAutoRequest rq(cx);
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 2) {
        //JS::RootedObject targetObj(cx);
        //targetObj.set(args.get(1).toObjectOrNull());
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(1), args.get(0));
        if(vkMethod2("friendsGet", "{}", cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        return true;
    } else if(argc == 3) {
        // params, callback function & this
        //JS::RootedObject targetObj(cx);
        //targetObj.set(args.get(2).toObjectOrNull());
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(2), args.get(1));
        JS::RootedValue arg0Val(cx, args.get(0));
        std::string res = Stringify(cx, arg0Val);
        if(vkMethod2("friendsGet", res.c_str(), cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool jsb_vksdk_wall_post(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("jsb_vksdk_wall_post");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    //VKRequest *req = nil;
    if(argc == 3) {
        // params, callback function & this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(2), args.get(1));
        JS::RootedValue arg0Val(cx, args.get(0));
        std::string res = Stringify(cx, arg0Val);
        if(vkMethod2("wallPost", res.c_str(), cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

static bool jsb_vksdk_call_api(JSContext *cx, uint32_t argc, jsval *vp)
{
    printLog("jsb_vksdk_call_api");
    JS::CallArgs args = JS::CallArgsFromVp(argc, vp);
    JS::RootedObject obj(cx, args.thisv().toObjectOrNull());
    JS::CallReceiver rec = JS::CallReceiverFromVp(vp);
    if(argc == 4) {
        // method, params, callback, this
        CallbackFrame *cb = new CallbackFrame(cx, obj, args.get(3), args.get(2));
        bool ok = true;
        std::string method;
        JS::RootedValue arg0Val(cx, args.get(0));
        ok &= jsval_to_std_string(cx, arg0Val, &method);

        JS::RootedValue arg1Val(cx, args.get(1));
        std::string params = Stringify(cx, arg1Val);
        if(vkMethod3("callApiMethod", method.c_str(), params.c_str(), cb->callbackId)) {
            rec.rval().set(JSVAL_TRUE);
        } else {
            rec.rval().set(JSVAL_FALSE);
        }
        return true;
    } else {
        JS_ReportError(cx, "Invalid number of arguments");
        return false;
    }
}

void register_all_vksdk_framework(JSContext* cx, JS::HandleObject obj)
{
    printLog("register_all_vksdk_framework");
    JS::RootedObject ns(cx);
    get_or_create_js_obj(cx, obj, "vksdk", &ns);

	// JS_DefineFunction(cx, ns, "init", jsb_vksdk_init, 1, JSPROP_ENUMERATE | JSPROP_PERMANENT);
    JS_DefineFunction(cx, ns, "login", jsb_vksdk_login, 3, JSPROP_ENUMERATE | JSPROP_PERMANENT);
    JS_DefineFunction(cx, ns, "logout", jsb_vksdk_logout, 0, JSPROP_ENUMERATE | JSPROP_PERMANENT);
    JS_DefineFunction(cx, ns, "loggedin", jsb_vksdk_loggedin, 0, JSPROP_ENUMERATE | JSPROP_PERMANENT);
    JS_DefineFunction(cx, ns, "users_get", jsb_vksdk_users_get, 3, JSPROP_ENUMERATE | JSPROP_PERMANENT);
    JS_DefineFunction(cx, ns, "friends_get", jsb_vksdk_friends_get, 3, JSPROP_ENUMERATE | JSPROP_PERMANENT);
    JS_DefineFunction(cx, ns, "wall_post", jsb_vksdk_wall_post, 3, JSPROP_ENUMERATE | JSPROP_PERMANENT);
    JS_DefineFunction(cx, ns, "call_api", jsb_vksdk_call_api, 4, JSPROP_ENUMERATE | JSPROP_PERMANENT);

}

static void cpp_loginResult(int callbackId, std::string tokenStr)
{
    cocos2d::Director::getInstance()->getScheduler()->performFunctionInCocosThread([callbackId, tokenStr] {
            CallbackFrame *loginCallback = CallbackFrame::getById(callbackId);
            if(!loginCallback) {
                printLog("requestResult: callbackId not found!");
                return;
            }
            JSAutoRequest rq(loginCallback->cx);
            JSAutoCompartment ac(loginCallback->cx, loginCallback->_ctxObject.ref());

            JS::AutoValueVector valArr(loginCallback->cx);
            jsval tkn = std_string_to_jsval(loginCallback->cx, tokenStr);
            valArr.append(tkn);
            JS::HandleValueArray funcArgs = JS::HandleValueArray::fromMarkedLocation(1, valArr.begin());
            loginCallback->call(funcArgs);
            //loginCallback->call(1, &tkn);

            delete loginCallback;
        });
}

void Java_org_cocos2dx_javascript_VkPlugin_loginResult(JNIEnv* env, jobject thiz, jint callbackId, jstring token)
{
    printLog("Get loginResult");
    if(token == NULL) {
        cpp_loginResult(callbackId, "");
    } else {
        const char* tokenStr = env->GetStringUTFChars(token, NULL);
        cpp_loginResult(callbackId, tokenStr);
        env->ReleaseStringUTFChars(token, tokenStr);
    }
}

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

void Java_org_cocos2dx_javascript_VkPlugin_requestResult(JNIEnv* env, jobject thiz, jint callbackId, jstring err, jstring result)
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
