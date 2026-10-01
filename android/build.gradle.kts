plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // 🟢 WAJIB ADA DI SINI
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.kitachat_mobile"

    // Target kompilasi menggunakan SDK 36 (Android 16)
    compileSdk = 36
    ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.kitachat_mobile"

        // Mengunci minSdk ke 23 untuk memenuhi kebutuhan flutter_webrtc
        minSdk = 23

        // Target operasional aplikasi di SDK 36
        targetSdk = 36

        // Mengambil kode versi otomatis dari pubspec.yaml
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}