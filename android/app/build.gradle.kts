import java.io.File
import java.io.ByteArrayOutputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter reads `dart-defines` (base64 "KEY=value" per entry, comma-separated for several).
// So Android Studio "Run" gets API_BASE_URL without typing --dart-define.
// Override in android/local.properties: flutter.apiBaseUrl=http://192.168.1.10:8080
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader(Charsets.UTF_8).use { localProperties.load(it) }
}
val flutterApiBaseUrl: String =
    localProperties.getProperty("flutter.apiBaseUrl")?.trim()?.takeIf { it.isNotEmpty() }
        ?: "http://127.0.0.1:8080"
extra["dart-defines"] =
    Base64.getEncoder().encodeToString(
        "API_BASE_URL=$flutterApiBaseUrl".toByteArray(Charsets.UTF_8),
    )

android {
    namespace = "com.example.mimusic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        val devApiEsc = flutterApiBaseUrl.replace("\\", "\\\\").replace("\"", "\\\"")
        buildConfigField("String", "DEV_API_BASE_URL", "\"$devApiEsc\"")
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mimusic"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

/** Проброс порта 8080 на ПК для `http://127.0.0.1:8080`. Не валит сборку, если adb нет в PATH. */
tasks.register("reverseTcp8080") {
    group = "development"
    description = "adb reverse tcp:8080 tcp:8080 (Ktor на хосте)."
    doLast {
        val sdkDir = localProperties.getProperty("sdk.dir")?.trim()
        val adbRel =
            if (System.getProperty("os.name").orEmpty().lowercase().contains("win")) {
                "platform-tools/adb.exe"
            } else {
                "platform-tools/adb"
            }
        val adbFromSdk = sdkDir?.let { File(it, adbRel) }
        val adbCmd =
            when {
                adbFromSdk != null && adbFromSdk.isFile -> adbFromSdk.absolutePath
                else -> "adb"
            }
        try {
            val out = ByteArrayOutputStream()
            project.exec {
                commandLine(adbCmd, "devices")
                standardOutput = out
                isIgnoreExitValue = true
            }
            val devices = out.toString()
                .lineSequence()
                .drop(1)
                .map { it.trim() }
                .filter { it.isNotEmpty() && it.endsWith("\tdevice") }
                .map { it.substringBefore('\t') }
                .toList()
            if (devices.isEmpty()) {
                project.exec {
                    commandLine(adbCmd, "reverse", "tcp:8080", "tcp:8080")
                    isIgnoreExitValue = true
                }
            } else {
                devices.forEach { serial ->
                    project.exec {
                        commandLine(adbCmd, "-s", serial, "reverse", "tcp:8080", "tcp:8080")
                        isIgnoreExitValue = true
                    }
                }
            }
        } catch (_: Exception) {
            logger.lifecycle("reverseTcp8080: adb недоступен ($adbCmd), пропуск — выполни вручную: adb reverse tcp:8080 tcp:8080")
        }
    }
}

afterEvaluate {
    tasks.named("preBuild").configure { dependsOn("reverseTcp8080") }
}
