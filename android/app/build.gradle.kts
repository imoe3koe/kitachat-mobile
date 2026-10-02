plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.kitachat_mobile"
    
    compileSdk = 35  // API 35 (Android 15) - Versi terbaru 2024
    ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17  // ✅ Java LTS 17 (OpenJDK 17 / Eclipse Temurin 17)
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"  // 🔧 Kotlin target untuk Java 17
    }

    defaultConfig {
        applicationId = "com.example.kitachat_mobile"
        
        // Minimum SDK 21 (Android 5.0) - Kompatibel dengan Flutter 3.24.x
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ✅ Tambahkan dukungan MultiDex untuk library yang banyak (WebRTC, Socket.io, dll)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // ✅ PENTING: Gunakan signing config yang proper di production
            // signingConfig = signingConfigs.getByName("debug") // Debug hanya untuk development
            
            // Aktifkan minification untuk production
            minifyEnabled = false  // Set ke true jika pakai ProGuard/R8
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
        
        debug {
            minifyEnabled = false
        }
    }

    // ✅ Konfigurasi lint options untuk Dart 3.5.x compatibility
    lintOptions {
        disable 'MissingDimensionAndroidResources'
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."  // Path ke Flutter SDK
}

dependencies {
    // ✅ AndroidX - Wajib untuk Flutter 3.24.x
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.core:core:1.12.0'
    
    // ✅ Multidex untuk app dengan banyak dependencies
    implementation 'androidx.multidex:multidex:2.0.1'
}
