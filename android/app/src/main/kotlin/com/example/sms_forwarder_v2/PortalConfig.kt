package com.example.sms_forwarder_v2

object PortalConfig {
    const val baseUrl = "https://your-portal-domain"

    fun ingestUrl(): String {
        return baseUrl.trimEnd('/') + "/api/messages/ingest"
    }
}
