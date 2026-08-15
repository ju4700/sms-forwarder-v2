package com.example.sms_forwarder_v2

import android.app.Service
import android.content.Intent
import android.os.IBinder

class HeadlessSmsSendService : Service() {
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Required for Default SMS App compliance.
        // We don't implement direct replies via this service.
        return START_NOT_STICKY
    }
}
