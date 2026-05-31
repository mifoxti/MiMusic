package com.example.mimusic

import android.content.Intent
import android.os.Build
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.mimusic/app_update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("ARG", "path required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        installApk(path)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INSTALL", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.isFile) {
            throw IllegalArgumentException("APK not found: $path")
        }
        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
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
