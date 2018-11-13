#ifndef Iap_h
#define Iap_h

#include "base/ccConfig.h"
#include "jsapi.h"
#include "jsfriendapi.h"

void register_all_iap_framework(JSContext* cx, JS::HandleObject obj);

#endif /* Iap_h */
