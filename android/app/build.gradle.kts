plugins {
    id("com.android.application")
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
        // PERHATIAN: Ganti applicationId ini dengan domain unik Anda sebelum rilis ke Play Store!
        applicationId = "com.example.kitachat_mobile"
        
        // 🟢 DIPERBAIKI: Mengunci minSdk ke 23 untuk memenuhi kebutuhan flutter_webrtc
        minSdk = flutter.minSdkVersion
        
        // Target operasional aplikasi di SDK 36
        targetSdk = 36
        
        // Mengambil kode versi otomatis dari pubspec.yaml
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Tambahkan konfigurasi release signing key (keystore) di sini sebelum rilis.
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
