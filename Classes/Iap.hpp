#ifndef Iap_h
#define Iap_h

#include "base/ccConfig.h"
#include "jsapi.h"
#include "jsfriendapi.h"
#include "platform/android/jni/JniHelper.h"
#include <jni.h>
#include "firebase/admob/types.h"

void register_all_iap_framework(JSContext* cx, JS::HandleObject obj);

extern "C"
{
    void Java_com_tapclap_inappbilling_InAppBillingPlugin_requestResult(JNIEnv* env, jobject thiz, jint callbackId, jstring err, jstring result);
};

#endif /* Iap_h */
