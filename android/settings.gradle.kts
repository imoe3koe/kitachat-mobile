pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Compatible dengan Flutter 3.47.5
    id("com.android.application") version "9.1.0" apply false
    // Kotlin sudah built-in di AGP 9+, tapi bisa tetap define di sini
    id("org.jetbrains.kotlin.android") version "2.0.10" apply false
}

include(":app")
