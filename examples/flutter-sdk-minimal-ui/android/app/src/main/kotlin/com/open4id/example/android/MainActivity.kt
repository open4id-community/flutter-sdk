package com.open4id.example.android

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Open4ID redirect-URI deep link (?code&state) handling for
        // GitHub / Apple Custom Tab callbacks.
        if (intent.data != null) {
            com.open4id.sdk.flutter.SocialAuthClient.completeDeepLink(intent.data)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Google sign-in intent result delivery.
        if (data != null) {
            com.open4id.sdk.flutter.SocialAuthClient.completeGoogleSignIn(requestCode, data)
        }
    }
}
