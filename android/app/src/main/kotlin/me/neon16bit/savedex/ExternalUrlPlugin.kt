/*
 * Copyright 2026 neon16bit
 * https://github.com/neon16bit/savedex
 */

package me.neon16bit.savedex

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ExternalUrlPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    companion object {
        const val CHANNEL = "me.neon16bit.savedex/external_url"
    }

    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(flutterBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterBinding.applicationContext
        channel = MethodChannel(flutterBinding.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler(this@ExternalUrlPlugin)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "openUrlInNewTask") {
            result.notImplemented()
            return
        }

        val rawUrl = call.argument<String>("url")?.trim()
        if (rawUrl.isNullOrEmpty()) {
            result.success(false)
            return
        }

        val uri = Uri.parse(rawUrl)
        if (uri.scheme.isNullOrBlank()) {
            result.success(false)
            return
        }

        val context = activityBinding?.activity ?: applicationContext
        if (context == null) {
            result.success(false)
            return
        }

        val launchIntent = Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            context.startActivity(launchIntent)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }
}
