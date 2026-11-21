/*
 * Copyright 2026 neon16bit
 * https://github.com/neon16bit/savedex
 */

package me.neon16bit.savedex

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsService

class RedditAuthActivity : Activity() {

    companion object {
        private const val TAG = "RedditAuth"
        private const val REQUEST_CODE_BROWSER = 9002
        private const val RESUME_FALLBACK_DELAY_MS = 15000L
        private val FIREFOX_PREFIXES = listOf(
            "org.mozilla.firefox",
            "org.mozilla.fenix",
            "org.mozilla.focus",
            "org.mozilla.klar",
            "org.mozilla.fennec"
        )
    }

    private var hasLaunched = false
    private var isFirstResume = true
    private var isCompleted = false
    private var browserResultReceived = false
    private var backInvokedCallback: Any? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var cancelRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val data = intent.data
        if (data != null) {
            finishWithCallback(data.toString())
            return
        }

        val authUrl = intent.getStringExtra("authUrl")
        val redirectUri = intent.getStringExtra("redirectUri")
        val callbackScheme = intent.getStringExtra("callbackScheme")

        if (authUrl == null || redirectUri == null || callbackScheme == null) {
            finishWithError("INVALID_ARGS", "Missing authUrl, redirectUri, or callbackScheme")
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val callback = OnBackInvokedCallback {
                if (!isCompleted) {
                    finishWithError("CANCELED", "User canceled authorization")
                }
            }
            backInvokedCallback = callback
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                callback
            )
        }

        if (savedInstanceState != null) {
            hasLaunched = savedInstanceState.getBoolean("hasLaunched", false)
            isFirstResume = savedInstanceState.getBoolean("isFirstResume", false)
            browserResultReceived =
                savedInstanceState.getBoolean("browserResultReceived", false)
        }

        if (!hasLaunched) {
            hasLaunched = true
            openBrowser(Uri.parse(authUrl))
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean("hasLaunched", hasLaunched)
        outState.putBoolean("isFirstResume", isFirstResume)
        outState.putBoolean("browserResultReceived", browserResultReceived)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = intent.data
        if (uri != null) {
            finishWithCallback(uri.toString())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_BROWSER) {
            browserResultReceived = true
            cancelPendingCancel()
            val runnable = Runnable {
                if (!isFinishing && !isCompleted) {
                    finishWithError("CANCELED", "User canceled authorization")
                }
            }
            cancelRunnable = runnable
            mainHandler.postDelayed(runnable, 1000L)
        }
    }

    override fun onResume() {
        super.onResume()
        if (isFirstResume) {
            isFirstResume = false
            return
        }

        if (hasLaunched && !isCompleted && intent?.data == null) {
            if (cancelRunnable != null) {
                return
            }
            val delayMs = if (browserResultReceived) 1000L else RESUME_FALLBACK_DELAY_MS
            val message = if (browserResultReceived) {
                "User canceled authorization"
            } else {
                "Browser closed without authorization"
            }
            val runnable = Runnable {
                if (!isFinishing && !isCompleted) {
                    finishWithError("CANCELED", message)
                }
            }
            cancelRunnable = runnable
            mainHandler.postDelayed(runnable, delayMs)
        }
    }

    override fun onPause() {
        super.onPause()
        cancelPendingCancel()
    }

    @Deprecated("Deprecated in Java")
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        if (!isCompleted) {
            finishWithError("CANCELED", "User canceled authorization")
        }
        super.onBackPressed()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val callback = backInvokedCallback as? OnBackInvokedCallback
            if (callback != null) {
                onBackInvokedDispatcher.unregisterOnBackInvokedCallback(callback)
            }
            backInvokedCallback = null
        }
        cancelPendingCancel()
    }

    private fun cancelPendingCancel() {
        cancelRunnable?.let { mainHandler.removeCallbacks(it) }
        cancelRunnable = null
    }

    private fun openBrowser(uri: Uri) {
        val browserPackage = findCustomTabsBrowser()

        if (browserPackage != null && !isFirefox(browserPackage)) {
            try {
                val customTabsIntent = CustomTabsIntent.Builder()
                    .setShareState(CustomTabsIntent.SHARE_STATE_ON)
                    .build()
                customTabsIntent.intent.apply {
                    setPackage(browserPackage)
                    data = uri
                }
                startActivityForResult(
                    customTabsIntent.intent,
                    REQUEST_CODE_BROWSER,
                    customTabsIntent.startAnimationBundle
                )
                return
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "Custom tab failed, falling back: ${e.message}")
            }
        }

        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            browserPackage?.let { setPackage(it) }
        }
        try {
            startActivityForResult(intent, REQUEST_CODE_BROWSER)
        } catch (e: ActivityNotFoundException) {
            finishWithError("NO_BROWSER", "No suitable browser found on device")
        }
    }

    private fun findCustomTabsBrowser(): String? {
        val activityIntent = Intent(Intent.ACTION_VIEW).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
            data = Uri.fromParts("http", "", null)
        }

        val defaultResolve = packageManager.resolveActivity(
            activityIntent, PackageManager.MATCH_DEFAULT_ONLY
        )
        val defaultPkg = defaultResolve?.activityInfo?.packageName
        if (defaultPkg != null && hasCustomTabsService(defaultPkg)) {
            return defaultPkg
        }

        val resolvedActivities = packageManager.queryIntentActivities(activityIntent, 0)
        for (info in resolvedActivities) {
            val pkg = info.activityInfo.packageName
            if (hasCustomTabsService(pkg)) {
                return pkg
            }
        }

        val fallbackPackages = listOf(
            "com.android.chrome",
            "com.chrome.beta",
            "com.chrome.dev",
            "com.google.android.apps.chrome",
            "org.chromium.chrome"
        )
        for (pkg in fallbackPackages) {
            if (hasCustomTabsService(pkg)) {
                return pkg
            }
        }

        return null
    }

    private fun hasCustomTabsService(packageName: String): Boolean {
        val serviceIntent = Intent(CustomTabsService.ACTION_CUSTOM_TABS_CONNECTION).apply {
            setPackage(packageName)
        }
        return packageManager.resolveService(serviceIntent, 0) != null
    }

    private fun isFirefox(pkg: String): Boolean =
        FIREFOX_PREFIXES.any { pkg.startsWith(it) }

    private fun finishWithCallback(callbackUrl: String) {
        if (isCompleted) return
        isCompleted = true
        cancelPendingCancel()
        Log.d(TAG, "Auth callback received")
        setResult(RESULT_OK, Intent().putExtra("callbackUrl", callbackUrl))
        finish()
    }

    private fun finishWithError(errorCode: String, errorMessage: String) {
        if (isCompleted) return
        isCompleted = true
        cancelPendingCancel()
        Log.d(TAG, "Auth error: $errorCode - $errorMessage")
        setResult(RESULT_CANCELED, Intent().apply {
            putExtra("errorCode", errorCode)
            putExtra("errorMessage", errorMessage)
        })
        finish()
    }
}
