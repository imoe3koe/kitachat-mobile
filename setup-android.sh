#!/bin/bash

set -e

echo "🔧 [Setup Android] Memulai setup Android SDK untuk Codespaces..."
echo ""

# ===== 1. Deteksi HOME directory =====
echo "📍 Home directory: $HOME"
echo "📍 Working directory: $(pwd)"
echo ""

# ===== 2. Setup ANDROID_HOME dengan benar =====
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

echo "✅ [Paths] ANDROID_HOME set ke: $ANDROID_HOME"
echo ""

# ===== 3. Cek apakah SDK sudah ada =====
if [ -d "$ANDROID_HOME/platforms/android-35" ]; then
    echo "✅ [SDK] Android SDK 35 sudah installed"
else
    echo "⚠️  [SDK] Android SDK 35 belum terinstall, akan install sekarang..."
fi

# ===== 4. Setup Flutter config =====
echo "🔧 [Flutter] Mengkonfigurasi Flutter..."
flutter config --android-sdk="$ANDROID_HOME"
echo "✅ [Flutter] Config selesai"
echo ""

# ===== 5. Buat local.properties dengan path yang benar =====
echo "📝 [Gradle] Membuat android/local.properties..."
cat > /workspaces/kitachat-mobile/android/local.properties << EOF
flutter.sdk=/workspaces/kitachat-mobile/flutter
android.useAndroidX=true
android.enableJetifier=false
android.builtInKotlin=true
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G
EOF

echo "✅ [Gradle] local.properties created"
echo ""

# ===== 6. Verifikasi SDK =====
echo "🔍 [Verification] Memeriksa Android SDK..."
if [ ! -d "$ANDROID_HOME/platforms" ]; then
    echo "❌ [Error] Android SDK tidak ditemukan di $ANDROID_HOME"
    echo ""
    echo "   Coba jalankan command ini:"
    echo "   mkdir -p $ANDROID_HOME"
    echo "   cd $ANDROID_HOME"
    echo "   wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    echo "   unzip commandlinetools-linux-11076708_latest.zip"
    echo "   mkdir -p cmdline-tools/latest"
    echo "   mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true"
    echo "   yes | ./cmdline-tools/latest/bin/sdkmanager --licenses"
    echo ""
    exit 1
fi

echo "✅ [Verification] Android SDK found"
echo ""

# ===== 7. Export ke bash profile =====
echo "📝 [Shell] Menambahkan ANDROID_HOME ke ~/.bashrc..."
if ! grep -q "export ANDROID_HOME" ~/.bashrc; then
    cat >> ~/.bashrc << 'BASHEOF'
# Android SDK Configuration (Added by setup-android.sh)
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
BASHEOF
    echo "✅ [Shell] Ditambahkan ke ~/.bashrc"
else
    echo "✅ [Shell] Sudah ada di ~/.bashrc"
fi

echo ""

# ===== 8. Final check =====
echo "🔍 [Final Check] Running flutter doctor -v..."
echo ""
flutter doctor -v

echo ""
echo "✅ [Setup Complete] Selesai!"
echo ""
echo "📝 Next steps:"
echo "   1. source ~/.bashrc  (untuk refresh environment)"
echo "   2. flutter doctor -v (verifikasi)"
echo "   3. flutter pub get"
echo "   4. flutter build apk --verbose"
echo ""
