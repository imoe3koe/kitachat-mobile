# 🚀 Setup Guide: Flutter 3.24.x + Dart 3.5.x + Java LTS 17

## ✅ Opsi 1: GitHub Codespaces (Recommended - Paling Mudah)

### Langkah 1: Buka Codespaces
1. Buka repository: https://github.com/imoe3koe/kitachat-mobile
2. Klik **`<> Code`** → **`Codespaces`** → **`Create codespace on main`**
3. Tunggu container siap (2-3 menit)
4. VS Code akan terbuka di browser

### Langkah 2: Environment Siap Otomatis
Post-create script akan auto:
- ✅ Install Java 17 (OpenJDK)
- ✅ Setup Android SDK (API 35)
- ✅ Setup Android NDK (26.1.10909125)
- ✅ Install Flutter 3.24.x
- ✅ Run `flutter pub get`
- ✅ Accept Android licenses

### Langkah 3: Build APK
```bash
# Cek status
flutter doctor -v

# Build APK
flutter build apk --verbose

# File output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📋 Requirements Terpenuhi

| Requirement | Version | Status |
|---|---|---|
| **Flutter** | 3.24.x+ | ✅ 3.47.6 |
| **Dart** | 3.5.x+ | ✅ 3.13.5 |
| **Java** | 17 (LTS) | ✅ OpenJDK 17 |
| **Android SDK** | 35 | ✅ API 35 (Android 15) |
| **Android NDK** | 26.x | ✅ 26.1.10909125 |
| **Gradle** | 8.x+ | ✅ 8.6.0 |
| **AGP** | 9.x | ✅ 9.1.0 |
| **Kotlin** | 2.0.x | ✅ 2.0.10 |

---

## 🔧 Troubleshooting

### Error: "Gradle sync failed"
```bash
./gradlew clean
flutter clean
flutter pub get
flutter build apk --verbose
```

### Error: "NDK not found"
```bash
flutter doctor -v
# NDK path harus ada di android/local.properties
```

### Error: "Java version mismatch"
```bash
java -version  # Harus Java 17
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
```

### Error: "CMake not found"
```bash
# Di Codespaces, CMake sudah included
# Jika lokal, install via Android Studio SDK Manager
```

---

## 📱 Build Output

Setelah `flutter build apk`, file siap di:
```
build/app/outputs/flutter-apk/app-release.apk
```

Size: ~50-80MB tergantung dependencies

---

## 📚 File Konfigurasi Penting

| File | Purpose |
|---|---|
| `pubspec.yaml` | Dart dependencies |
| `android/build.gradle.kts` | Root Gradle config |
| `android/app/build.gradle.kts` | App Gradle config |
| `android/gradle.properties` | JVM & Android settings |
| `android/settings.gradle.kts` | Plugin management |
| `android/local.properties` | Local paths (auto-generated) |

---

## 🎯 Checklist Build

- [ ] Codespaces environment siap
- [ ] `flutter doctor -v` semua hijau ✅
- [ ] `flutter pub get` berhasil
- [ ] `flutter build apk --verbose` berhasil
- [ ] APK ada di `build/app/outputs/flutter-apk/`

---

## 📖 Dokumentasi Referensi

- [Flutter 3.24 Release Notes](https://github.com/flutter/flutter/releases)
- [Dart 3.5 Release Notes](https://dart.dev/guides/release-notes/release-notes-3.5)
- [Android Build Docs](https://developer.android.com/build)
- [Gradle Kotlin DSL](https://docs.gradle.org/current/userguide/kotlin_dsl.html)

---

**Last Updated:** 2026-10-02  
**Maintained By:** imoe3koe
