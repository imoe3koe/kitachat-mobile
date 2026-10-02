#!/bin/bash

set -e

echo "🔧 [Post-Create] Memulai setup Flutter environment di Codespaces..."
echo ""

# ===== 1. Setup ANDROID_HOME dengan path yang benar =====
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

echo "📍 [Paths]"
echo "   HOME: $HOME"
echo "   ANDROID_HOME: $ANDROID_HOME"
echo "   Working Dir: $(pwd)"
echo ""

# ===== 2. Cek Java =====
echo "☕ [Java]"
java -version
echo ""

# ===== 3. Setup Flutter =====
echo "📦 [Flutter] Mengkonfigurasi Flutter..."
flutter config --android-sdk="$ANDROID_HOME"
echo ""

# ===== 4. Buat local.properties =====
echo "📝 [Gradle] Membuat android/local.properties..."
cat > /workspaces/kitachat-mobile/android/local.properties << EOF
flutter.sdk=/workspaces/kitachat-mobile/flutter
android.useAndroidX=true
android.enableJetifier=false
android.builtInKotlin=true
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G
EOF
echo "✅ [Gradle] Selesai"
echo ""

# ===== 5. Export ke bash =====
if ! grep -q "export ANDROID_HOME" ~/.bashrc; then
    cat >> ~/.bashrc << 'BASHEOF'
# Android SDK Configuration (Codespaces)
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
BASHEOF
fi

echo "📚 [Dependencies] Running flutter pub get..."
cd /workspaces/kitachat-mobile
flutter pub get
echo ""

# ===== 6. Flutter doctor =====
echo "🔍 [Flutter Doctor]"
flutter doctor -v
echo ""

echo "✅ [Post-Create] Setup Selesai!"
echo ""
echo "📝 Jalankan untuk build Android:"
echo "   flutter build apk --verbose"
echo ""
