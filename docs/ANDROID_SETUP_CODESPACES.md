# 🚀 Android SDK Setup di GitHub Codespaces

## ✅ Status Saat Ini

```
✓ Flutter 3.47.6
✓ Dart 3.13.5
✓ Java 17 (via Codespaces)
✗ Android SDK - perlu setup
```

## 🔧 Solusi Cepat

### Langkah 1: Jalankan Setup Script

```bash
cd /workspaces/kitachat-mobile
bash setup-android.sh
```

Script ini akan:
- ✅ Setup `ANDROID_HOME` ke path yang benar
- ✅ Configure Flutter dengan Android SDK path
- ✅ Buat `android/local.properties`
- ✅ Update `~/.bashrc` dengan environment variables
- ✅ Verifikasi dengan `flutter doctor -v`

### Langkah 2: Refresh Terminal

```bash
source ~/.bashrc
```

### Langkah 3: Verifikasi

```bash
flutter doctor -v
```

Harus ada ✓ di Android toolchain.

---

## 📦 Android SDK Components Terinstal

```
✓ platforms;android-35       (Android 15)
✓ build-tools;35.0.0
✓ platform-tools
✓ ndk;26.1.10909125
✓ cmake;3.22.1
```

---

## 🎯 Build APK

Setelah setup berhasil:

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build APK
flutter build apk --verbose
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

---

## ❌ Troubleshooting

### Error: "Android SDK not found"

```bash
# Cek path yang digunakan Flutter
flutter config

# Pastikan dirnya ada
ls -la $ANDROID_HOME/platforms/

# Reset dan setup ulang
flutter config --android-sdk=~/Android/Sdk
source ~/.bashrc
flutter doctor -v
```

### Error: "ANDROID_HOME not set"

```bash
# Lihat environment saat ini
echo $ANDROID_HOME

# Set manual (temporary)
export ANDROID_HOME=$HOME/Android/Sdk

# Permanent (di ~/.bashrc)
echo 'export ANDROID_HOME="$HOME/Android/Sdk"' >> ~/.bashrc
source ~/.bashrc
```

### Error: "Gradle sync failed"

```bash
cd /workspaces/kitachat-mobile

# Clean everything
flutter clean
rm -rf build/
rm -rf android/.gradle/

# Get fresh dependencies
flutter pub get

# Try build again
flutter build apk --verbose
```

---

## 📋 File Penting

| File | Purpose |
|------|----------|
| `setup-android.sh` | Script setup otomatis |
| `android/local.properties` | Path configuration |
| `android/build.gradle.kts` | Root gradle config |
| `android/app/build.gradle.kts` | App gradle config |
| `pubspec.yaml` | Flutter dependencies |

---

## 🔗 Referensi

- [Flutter Android Setup](https://flutter.dev/docs/get-started/install/linux#android-setup)
- [Gradle Documentation](https://docs.gradle.org/)
- [Android SDK Documentation](https://developer.android.com/studio/command-line)

---

**Last Updated:** 2026-10-02  
**Maintained By:** imoe3koe
