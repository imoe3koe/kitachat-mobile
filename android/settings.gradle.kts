// Settings untuk multi-project build
pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    // 🟢 DIPERBAIKI: Hapus backslash (\) agar variabel terbaca dengan benar
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// ✅ Plugin management untuk Flutter 3.x + Kotlin + AGP
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false  // Menggunakan AGP versi stabil
    id("org.jetbrains.kotlin.android") version "2.0.10" apply false 
}

include(":app")

// ✅ Additional configurations untuk project
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS) 
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io") 
    }
}
