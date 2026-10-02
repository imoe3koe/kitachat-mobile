// Settings untuk multi-project build
pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("\$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// ✅ Plugin management untuk Flutter 3.24.x + Kotlin 2.0.10 + AGP 9.1.0
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false  // AGP 9.1.0 - Versi terbaru 2024
    id("org.jetbrains.kotlin.android") version "2.0.10" apply false  // Kotlin 2.0.10
}

include(":app")

// ✅ Additional configurations untuk project
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)  // Prefer settings.gradle for resolution
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io")  // Untuk custom packages jika diperlukan
    }
}
