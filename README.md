# Description

In-app purchase plugin for sdkbar.

# Installation

`sdkbar -i https://github.com/OrangeAppsRu/sdkbar-iap`

# Dependencies

- sdkbar-utils (https://github.com/OrangeAppsRu/sdkbar-utils)

# Plugin JS interface

- `iap.init(skus_array, internal_validation_flag, callback_function, callback_this)`
- `iap.get_purchases(callback_function, callback_this)`
- `iap.buy(sku, payload, callback_function, callback_this)`
- `iap.subscribe(sku, payload, old_purchased_skus_array, callback_function, callback_this)`
- `iap.consume(sku, callback_function, callback_this)`
- `iap.available_products(callback_function, callback_this)`
- `iap.product_details(skus_array, callback_function, callback_this)`
- `iap.restore(callback_function, callback_this)`
- `iap.set_debug(debug_flag)`
