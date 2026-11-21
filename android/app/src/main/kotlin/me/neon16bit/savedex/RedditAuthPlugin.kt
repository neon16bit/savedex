/*
 * Copyright 2026 neon16bit
 * https://github.com/neon16bit/savedex
 */

package me.neon16bit.savedex

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class RedditAuthPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    companion object {
        const val CHANNEL = "me.neon16bit.savedex/reddit_auth"
        private const val REQUEST_CODE_AUTH = 9001
    }

    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(flutterBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterBinding.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler(this@RedditAuthPlugin)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        pendingResult = null
    }

    override fun onAttachedToActivity(activityBinding: ActivityPluginBinding) =
        attach(activityBinding)

    override fun onReattachedToActivityForConfigChanges(activityBinding: ActivityPluginBinding) =
        attach(activityBinding)

    override fun onDetachedFromActivityForConfigChanges() = detach(cancelPending = false)
    override fun onDetachedFromActivity() = detach(cancelPending = true)

    private fun attach(activityBinding: ActivityPluginBinding) {
        binding = activityBinding
        activityBinding.addActivityResultListener(this)
    }

    private fun detach(cancelPending: Boolean) {
        binding?.removeActivityResultListener(this)
        binding = null
        if (cancelPending) {
            val pending = pendingResult
            pendingResult = null
            if (pending != null) {
                try {
                    pending.error("CANCELED", "Activity detached before authorization completed", null)
                } catch (_: Exception) {}
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "startCustomTabAuth") {
            result.notImplemented()
            return
        }

        val authUrl = call.argument<String>("authUrl")
        val redirectUri = call.argument<String>("redirectUri")
        val callbackScheme = call.argument<String>("callbackScheme")

        if (authUrl == null || redirectUri == null || callbackScheme == null) {
            result.error("INVALID_ARGS", "Missing required auth parameters", null)
            return
        }

        val currentActivity = binding?.activity ?: run {
            result.error("NO_ACTIVITY", "Plugin is not attached to an Activity", null)
            return
        }

        if (pendingResult != null) {
            result.error("ALREADY_ACTIVE", "An authentication request is already in progress", null)
            return
        }

        pendingResult = result
        val intent = Intent(currentActivity, RedditAuthActivity::class.java).apply {
            putExtra("authUrl", authUrl)
            putExtra("redirectUri", redirectUri)
            putExtra("callbackScheme", callbackScheme)
        }
        try {
            currentActivity.startActivityForResult(intent, REQUEST_CODE_AUTH)
        } catch (e: Exception) {
            pendingResult = null
            result.error("LAUNCH_FAILED", e.message ?: "Failed to start authorization activity", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_AUTH) return false

        val result = pendingResult ?: return true
        pendingResult = null

        when (resultCode) {
            Activity.RESULT_OK -> {
                val callbackUrl = data?.getStringExtra("callbackUrl")
                if (callbackUrl != null) {
                    result.success(callbackUrl)
                } else {
                    result.error("NO_CALLBACK", "No callback URL received", null)
                }
            }
            Activity.RESULT_CANCELED -> {
                val code = data?.getStringExtra("errorCode") ?: "CANCELED"
                val message = data?.getStringExtra("errorMessage") ?: "User canceled authorization"
                result.error(code, message, null)
            }
            else -> result.error("UNKNOWN", "Unknown result code: $resultCode", null)
        }

        return true
    }
}
