# Flutter 应用构建指南

## 环境要求

- Flutter SDK 3.0+
- Android Studio（Android 开发）
- Xcode（iOS 开发，仅 macOS）
- JDK 11+

## 开发环境配置

### 1. 安装 Flutter SDK

```bash
# macOS / Linux
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Windows
# 下载 Flutter SDK：https://docs.flutter.dev/get-started/install/windows
```

### 2. 验证安装

```bash
flutter doctor
```

### 3. 获取依赖

```bash
cd flutter_app
flutter pub get
```

## 运行应用

### Android

```bash
# 连接设备或启动模拟器后
flutter run

# 指定设备
flutter run -d <device_id>
```

### iOS（仅 macOS）

```bash
cd ios
pod install
cd ..
flutter run -d iPhone
```

## 构建发布版

### Android APK

```bash
# Debug 版本
flutter build apk --debug

# Release 版本
flutter build apk --release

# 输出路径：build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle（Google Play）

```bash
flutter build appbundle --release

# 输出路径：build/app/outputs/bundle/release/app-release.aab
```

### iOS（仅 macOS）

```bash
flutter build ios --release

# 然后在 Xcode 中归档并上传到 App Store Connect
```

## 签名配置

### Android 签名

1. 生成密钥库：
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. 创建 `android/key.properties`：
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

3. 配置 `android/app/build.gradle`：
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## 应用图标

应用图标位于：
- Android: `android/app/src/main/res/`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

推荐使用 [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) 包自动生成。

## 版本管理

版本号在 `pubspec.yaml` 中定义：
```yaml
version: 1.0.0+1
# 格式：主版本.次版本.修订号+构建号
```

更新版本：
```bash
# 自动递增版本号
flutter build apk --build-name=1.0.1 --build-number=2
```

## 常见问题

### Gradle 构建失败

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### iOS Pod 安装失败

```bash
cd ios
pod deintegrate
pod install
cd ..
```

### 依赖冲突

```bash
flutter pub cache clean
flutter clean
flutter pub get
```
