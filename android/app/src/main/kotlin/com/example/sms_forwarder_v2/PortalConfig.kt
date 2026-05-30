package com.example.sms_forwarder_v2

object PortalConfig {
    const val baseUrl = "https://sms-portal-five-roan.vercel.app"

    fun ingestUrl(): String {
        return baseUrl.trimEnd('/') + "/api/messages/ingest"
    }
}
