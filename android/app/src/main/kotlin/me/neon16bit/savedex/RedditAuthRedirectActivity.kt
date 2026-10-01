/*
 * Copyright 2026 neon16bit
 * https://github.com/neon16bit/savedex
 */

package me.neon16bit.savedex

import android.app.Activity
import android.content.Intent
import android.os.Bundle

class RedditAuthRedirectActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val data = intent?.data
        if (data != null) {
            val forwardIntent = Intent(this, RedditAuthActivity::class.java).apply {
                setData(data)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(forwardIntent)
        }

        finish()
    }
}
