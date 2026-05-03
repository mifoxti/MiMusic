package com.example.mimusic

import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.mimusic/api_config",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBaseUrl" -> result.success(resolveDevBaseUrl())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * URL из Gradle/local.properties; на эмуляторе 127.0.0.1 не ведёт на хост — подменяем на 10.0.2.2.
     * На физическом устройстве ожидается `adb reverse tcp:8080 tcp:8080` для loopback.
     */
    private fun resolveDevBaseUrl(): String {
        val fromGradle = BuildConfig.DEV_API_BASE_URL
        if (fromGradle.isBlank()) return defaultLoopbackUrl()
        if (isLoopbackUrl(fromGradle) && isProbablyEmulator()) {
            return fromGradle
                .replace("127.0.0.1", "10.0.2.2")
                .replace("localhost", "10.0.2.2")
        }
        return fromGradle
    }

    private fun defaultLoopbackUrl(): String =
        if (isProbablyEmulator()) "http://10.0.2.2:8080" else "http://127.0.0.1:8080"

    private fun isLoopbackUrl(url: String): Boolean =
        url.contains("127.0.0.1") || url.contains("localhost")

    private fun isProbablyEmulator(): Boolean {
        val fp = Build.FINGERPRINT
        return (fp != null && (fp.startsWith("generic") || fp.startsWith("unknown"))) ||
            Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for x86") ||
            Build.MANUFACTURER.contains("Genymotion") ||
            Build.PRODUCT == "google_sdk" ||
            (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
    }
}
