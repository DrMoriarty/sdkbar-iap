/**
 * In App Billing Plugin
 * @author DrMoriarty - TapClap
 * @modifications 
 *
 */
package com.tapclap.inappbilling;

import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONException;

import java.util.Arrays;
import java.util.List;
import java.util.ArrayList;

import com.tapclap.util.Purchase;
import com.tapclap.util.IabHelper;
import com.tapclap.util.IabResult;
import com.tapclap.util.Inventory;
import com.tapclap.util.SkuDetails;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;
import android.preference.PreferenceManager.OnActivityResultListener;
import org.cocos2dx.lib.Cocos2dxHelper;

public class InAppBillingPlugin {
	private static final Boolean ENABLE_DEBUG_LOGGING = true;
	private static final String TAG = "Iap";
    public static Activity appActivity;

    // (arbitrary) request code for the purchase flow
    static final int RC_REQUEST = 10001;

    // The helper object
    private static IabHelper mHelper = null;

    // A quite up to date inventory of available items and purchase items
    private static Inventory myInventory;

    /////////////////////////
    //
    // Public API
    //

    public static boolean init(final String[] skus, final boolean internalValidation, final int callbackId) {
        // Initialize
		Log.d(TAG, "init start");
        appActivity = Cocos2dxHelper.getActivity();
		// Some sanity checks to see if the developer (that's you!) really followed the
        // instructions to run this plugin
        String base64EncodedPublicKey = null;
        if(internalValidation) {
            base64EncodedPublicKey = getPublicKey();

            if (base64EncodedPublicKey.contains("CONSTRUCT_YOUR"))
                throw new RuntimeException("Please configure your app's public key.");
            Log.d(TAG, "Purchase verification enabled");
        } else {
            Log.w(TAG, "Purchase verification disabled");
        }

	 	// Create the helper, passing it our context and the public key to verify signatures with
        Log.d(TAG, "Creating IAB helper.");
        mHelper = new IabHelper(appActivity.getApplicationContext(), base64EncodedPublicKey);

        // enable debug logging (for a production application, you should set this to false).
        mHelper.enableDebugLogging(ENABLE_DEBUG_LOGGING);

        // Start setup. This is asynchronous and the specified listener
        // will be called once setup completes.
        Log.d(TAG, "Starting setup.");

        // Listener that's called when we finish querying the items and subscriptions we own
        final IabHelper.QueryInventoryFinishedListener mGotInventoryListener = new IabHelper.QueryInventoryFinishedListener() {
                public void onQueryInventoryFinished(IabResult result, Inventory inventory) {
                    Log.d(TAG, "Inside mGotInventoryListener");
                    if (hasErrorsAndUpdateInventory(result, inventory, callbackId))
                        return;

                    Log.d(TAG, "Query inventory was successful.");
                    callRequestResult(callbackId, null, "{}");
                }
            };

        mHelper.startSetup(new IabHelper.OnIabSetupFinishedListener() {
            public void onIabSetupFinished(IabResult result) {
                Log.d(TAG, "Setup finished.");

                if (!result.isSuccess()) {
                    // Oh no, there was a problem.
                    callRequestResult(callbackId, "Problem setting up in-app billing: " + result, null);
                    return;
                }

                // Have we been disposed of in the meantime? If so, quit.
                if (mHelper == null || !mHelper.IsInited()) {
                    callRequestResult(callbackId, "The billing helper has been disposed", null);
                    return;
                }

                // Hooray, IAB is fully set up. Now, let's get an inventory of stuff we own.
                if(skus.length <= 0) {
					Log.d(TAG, "Setup successful. Querying inventory.");
                	mHelper.queryInventoryAsync(mGotInventoryListener);
				} else {
					Log.d(TAG, "Setup successful. Querying inventory w/ SKUs.");
                    try {
                        mHelper.queryInventoryAsync(true, Arrays.asList(skus), mGotInventoryListener);
                    } catch(IllegalStateException ex) {
                        Log.d("Catch IllegalStateException", ex.getMessage());
                    }
				}
            }
        });
        Cocos2dxHelper.addOnActivityResultListener(new OnActivityResultListener() {
                @Override
                public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
                    Log.i(TAG, "onActivityResult listener called");
                    InAppBillingPlugin.onActivityResult(requestCode, resultCode, data);
                    return true;
                }
            });
        return true;
    }

    public static boolean setDebug(final boolean debug) {
        if(mHelper != null) {
            mHelper.enableDebugLogging(debug);
            return true;
        } else {
            return false;
        }
    }

	// Get the list of purchases
	public static boolean getPurchases(final int callbackId) {
		// Get the list of owned items
        try {
            if(myInventory == null) {
                callRequestResult(callbackId, "Billing plugin was not initialized", null);
                return false;
            }
            List<Purchase>purchaseList = myInventory.getAllPurchases();

            // Convert the java list to json
            JSONArray jsonPurchaseList = new JSONArray();
            for (Purchase p : purchaseList) {
                // jsonPurchaseList.put(new JSONObject(p.getOriginalJson()));
                JSONObject purchaseJsonObject = new JSONObject(p.getOriginalJson());
                purchaseJsonObject.put("signature", p.getSignature());
                purchaseJsonObject.put("receipt", p.getOriginalJson().toString());
                jsonPurchaseList.put(purchaseJsonObject);
            }

            callRequestResult(callbackId, null, jsonPurchaseList.toString());
            return true;
        } catch (JSONException e) {
            return false;
        }
	}

	// Buy an item
	public static boolean buy(final String sku, final String developerPayload, final int callbackId) {
        // Buy an item

		if (mHelper == null || !mHelper.IsInited()) {
            callRequestResult(callbackId, "Billing plugin was not initialized", null);
			return false;
		}
        if(mHelper.AsyncInProgress()) {
            callRequestResult(callbackId, "Another async operation in progress!", null);
            return false;
        }

        // Callback for when a purchase is finished
        IabHelper.OnIabPurchaseFinishedListener mPurchaseFinishedListener = new IabHelper.OnIabPurchaseFinishedListener() {
                public void onIabPurchaseFinished(IabResult result, Purchase purchase) {
                    purchaseFinished(result, purchase, callbackId);
                }
            };

		mHelper.launchPurchaseFlow(appActivity, sku, RC_REQUEST, mPurchaseFinishedListener, developerPayload);
        return true;
	}

	// Buy an item
	public static boolean subscribe(final String sku, final String developerPayload, final String[] oldPurchasedSkus, final int callbackId) {
        // Subscribe to an item
		if (mHelper == null || !mHelper.IsInited()) {
            callRequestResult(callbackId, "Billing plugin was not initialized", null);
			return false;
		}
		if (!mHelper.subscriptionsSupported()) {
            callRequestResult(callbackId, "Subscriptions not supported on your device yet. Sorry!", null);
            return false;
        }

        Log.d(TAG, "Launching purchase flow for subscription.");

        // Callback for when a purchase is finished
        IabHelper.OnIabPurchaseFinishedListener mPurchaseFinishedListener = new IabHelper.OnIabPurchaseFinishedListener() {
                public void onIabPurchaseFinished(IabResult result, Purchase purchase) {
                    purchaseFinished(result, purchase, callbackId);
                }
            };

		mHelper.launchPurchaseFlow(appActivity, sku, IabHelper.ITEM_TYPE_SUBS, Arrays.asList(oldPurchasedSkus), RC_REQUEST, mPurchaseFinishedListener, developerPayload);
        return true;
	}

	// Consume a purchase
	public static boolean consumePurchase(final String sku, final int callbackId) {

		if (mHelper == null || !mHelper.IsInited()) {
            callRequestResult(callbackId, "Did you forget to initialize the plugin?", null);
			return false;
		}
        if(mHelper.AsyncInProgress()) {
            callRequestResult(callbackId, "Another async operation in progress!", null);
            return false;
        }

        // Called when consumption is complete
        final IabHelper.OnConsumeFinishedListener mConsumeFinishedListener = new IabHelper.OnConsumeFinishedListener() {
                public void onConsumeFinished(Purchase purchase, IabResult result) {
                    Log.d(TAG, "Consumption finished. Purchase: " + purchase + ", result: " + result);

                    // We know this is the "gas" sku because it's the only one we consume,
                    // so we don't check which sku was consumed. If you have more than one
                    // sku, you probably should check...
                    if (result.isSuccess()) {
                        // successfully consumed, so we apply the effects of the item in our
                        // game world's logic

                        // remove the item from the inventory
                        myInventory.erasePurchase(purchase.getSku());
                        Log.d(TAG, "Consumption successful. .");

                        callRequestResult(callbackId, null, purchase.getOriginalJson().toString());
                    } else {
                        callRequestResult(callbackId, result.getResponse() + "|Error while consuming: " + result, null);
                    }
                }
            };

		// Get the purchase from the inventory
		final Purchase purchase = myInventory.getPurchase(sku);
		if (purchase != null) {
			// Consume it
            appActivity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        mHelper.consumeAsync(purchase, mConsumeFinishedListener);
                    }
                });
            return true;
		} else {
            callRequestResult(callbackId, "" + sku + " is not owned so it cannot be consumed", null);
            return false;
        }
	}

	// Get the list of available products
	public static boolean getAvailableProducts(final int callbackId) {
		// Get the list of owned items
		if(myInventory == null) {
            callRequestResult(callbackId, "Billing plugin was not initialized", null);
			return false;
		}
        List<SkuDetails>skuList = myInventory.getAllProducts();

		// Convert the java list to json
	    JSONArray jsonSkuList = new JSONArray();
		try {
	        for (SkuDetails sku : skuList) {
				Log.d(TAG, "SKUDetails: Title: "+sku.getTitle());
	        	jsonSkuList.put(sku.toJson());
	        }
            callRequestResult(callbackId, null, jsonSkuList.toString());
            return true;
		} catch (JSONException e){
            callRequestResult(callbackId, e.getMessage(), null);
            return false;
		}
	}

	//Get SkuDetails for skus
	public static boolean getProductDetails(final String[] skus, final int callbackId) {
		if (mHelper == null || !mHelper.IsInited()) {
            callRequestResult(callbackId, "Billing plugin was not initialized", null);
			return false;
		}
        if(mHelper.AsyncInProgress()) {
            callRequestResult(callbackId, "Another async operation in progress!", null);
            return false;
        }

		Log.d(TAG, "Beginning Sku(s) Query!");

        // Listener that's called when we finish querying the details
        final IabHelper.QueryInventoryFinishedListener mGotDetailsListener = new IabHelper.QueryInventoryFinishedListener() {
                public void onQueryInventoryFinished(IabResult result, Inventory inventory) {
                    Log.d(TAG, "Inside mGotDetailsListener");
                    if (hasErrorsAndUpdateInventory(result, inventory, callbackId)) 
                        return;

                    Log.d(TAG, "Query details was successful.");

                    List<SkuDetails>skuList = inventory.getAllProducts();

                    // Convert the java list to json
                    JSONArray jsonSkuList = new JSONArray();
                    try {
                        for (SkuDetails sku : skuList) {
                            Log.d(TAG, "SKUDetails: Title: "+sku.getTitle());
                            jsonSkuList.put(sku.toJson());
                        }
                    } catch (JSONException e) {
                        callRequestResult(callbackId, e.getMessage(), null);
                        return;
                    }
                    callRequestResult(callbackId, null, jsonSkuList.toString());
                }
            };

        appActivity.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    mHelper.queryInventoryAsync(true, Arrays.asList(skus), mGotDetailsListener);
                }
            });
        return true;
	}

    /////////////////////////
    //
    // Private methods
    //

    private static String getPublicKey() {
        int billingKeyFromParam = appActivity.getResources().getIdentifier("billing_key_param", "string", appActivity.getPackageName());
        String ret = "";

        if (billingKeyFromParam > 0) {
            ret = appActivity.getString(billingKeyFromParam);
            if (ret.length() > 0) {
                return ret;
            }
        }

        int billingKey = appActivity.getResources().getIdentifier("billing_key", "string", appActivity.getPackageName());
        return appActivity.getString(billingKey);
    }

    // Check if there is any errors in the iabResult and update the inventory
    private static boolean hasErrorsAndUpdateInventory(IabResult result, Inventory inventory, int callbackId) {
    	if (result.isFailure()) {
            callRequestResult(callbackId, result.getResponse() + "|Failed to query inventory: " + result, null);
        	return true;
        }

        // Have we been disposed of in the meantime? If so, quit.
        if (mHelper == null || !mHelper.IsInited()) {
            callRequestResult(callbackId, "The billing helper has been disposed", null);
        	return true;
        }

        // Update the inventory
        myInventory = inventory;

        return false;
    }
    
    private static boolean purchaseFinished(IabResult result, Purchase purchase, int callbackId) {
        Log.d(TAG, "Purchase finished: " + result + ", purchase: " + purchase);

        // Have we been disposed of in the meantime? If so, quit.
        if (mHelper == null || !mHelper.IsInited()) {
            callRequestResult(callbackId, "The billing helper has been disposed", null);
            return false;
        }

        if (result.isFailure()) {
            callRequestResult(callbackId, result.getResponse() + "|Error purchasing: " + result, null);
            return false;
        }

        if (!verifyDeveloperPayload(purchase)) {
            callRequestResult(callbackId, "Error purchasing. Authenticity verification failed.", null);
            return false;
        }

        Log.d(TAG, "Purchase successful.");

        // add the purchase to the inventory
        myInventory.addPurchase(purchase);

        // append the purchase signature & receipt to the json
        try {
            JSONObject purchaseJsonObject = new JSONObject(purchase.getOriginalJson());
            purchaseJsonObject.put("signature", purchase.getSignature());
            purchaseJsonObject.put("receipt", purchase.getOriginalJson().toString());
            callRequestResult(callbackId, null, purchaseJsonObject.toString());
            return true;
        } catch (JSONException e) {
            callRequestResult(callbackId, "Could not create JSON object from purchase object", null);
            return false;
        }
    }

	private static void onActivityResult(int requestCode, int resultCode, Intent data) {
        Log.d(TAG, "onActivityResult(" + requestCode + "," + resultCode + "," + data);

        // Pass on the activity result to the helper for handling
        if (!mHelper.handleActivityResult(requestCode, resultCode, data)) {
            // not handled, so handle it ourselves (here's where you'd
            // perform any handling of activity results not related to in-app
            // billing...
        }
        else {
            Log.d(TAG, "onActivityResult handled by IABUtil.");
        }
    }

    /** Verifies the developer payload of a purchase. */
    static boolean verifyDeveloperPayload(Purchase p) {
        @SuppressWarnings("unused")
		String payload = p.getDeveloperPayload();

        /*
         * TODO: verify that the developer payload of the purchase is correct. It will be
         * the same one that you sent when initiating the purchase.
         *
         * WARNING: Locally generating a random string when starting a purchase and
         * verifying it here might seem like a good approach, but this will fail in the
         * case where the user purchases an item on one device and then uses your app on
         * a different device, because on the other device you will not have access to the
         * random string you originally generated.
         *
         * So a good developer payload has these characteristics:
         *
         * 1. If two different users purchase an item, the payload is different between them,
         *    so that one user's purchase can't be replayed to another user.
         *
         * 2. The payload must be such that you can verify it even when the app wasn't the
         *    one who initiated the purchase flow (so that items purchased by the user on
         *    one device work on other devices owned by the user).
         *
         * Using your own server to store and verify developer payloads across app
         * installations is recommended.
         */

        return true;
    }

    // We're being destroyed. It's important to dispose of the helper here!
    /*
    @Override
    public void onDestroy() {
    	super.onDestroy();

    	// very important:
    	Log.d(TAG, "Destroying helper.");
    	if (mHelper != null) {
    		mHelper.dispose();
    		mHelper = null;
    	}
    }
    */

    // JNI methods

    static private void callRequestResult(final int callbackId, final String error, final String result) {
        appActivity.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    requestResult(callbackId, error, result);
                }
            });
    }

    public static native void requestResult(int callbackId, String err, String result);
}
