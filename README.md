# 临场记

临场记是一款基于地理围栏的位置提醒应用。你可以提前设置一个目标地点，当手机进入该地点范围时，应用会通过通知或强提醒提醒你处理对应事项，适合到店、到站、到公司、到家等场景。

## 下载

- [下载最新版 Android APK](https://github.com/xingmu833/geofence_reminder/releases/latest)

如果链接中暂时没有安装包，请在 GitHub 仓库的 Releases 页面新建一个 Release，并把构建好的 APK 上传到该 Release 的 Assets 中。

## Release 说明模板

发布 APK 时，可以在 GitHub Release 描述中写入：

```text
临场记是一个个人开发的位置提醒工具，目前免费提供给个人学习、体验和日常非商业使用。

本版本使用百度地图开放平台能力提供地图、定位和地点搜索相关功能。项目暂按个人开发和非商业用途使用百度地图 AK；如后续用于商业场景、收费分发、广告变现、企业内部业务或其他营利用途，请以百度地图开放平台最新服务条款和授权要求为准。

安装说明：
- 首次安装请授予定位、后台定位和通知权限。
- 如已安装旧版本，直接安装本 APK 会覆盖升级，不会新增第二个 App。
- 若系统提示“签名不一致”或无法覆盖安装，说明旧版本和新版本不是同一个签名构建，需要先卸载旧版本后再安装。
```

## 主要功能

- 位置提醒：选择目标地点和围栏半径，到达地点后自动触发提醒。
- 两种提醒方式：支持普通通知提醒和强提醒。
- 提醒次数控制：支持每次进入、仅此一次、每天指定次数。
- 防误触发：创建提醒时如果已经在目标地点内，不会立刻触发；离开后再次进入才会提醒。
- 后台地理围栏：支持后台定位与地理围栏监听，应用不在前台时也可判断是否到达。
- 自定义闹钟铃声：内置多种简单铃声，也支持选择本地音频作为强提醒铃声。
- 回收站：删除的提醒会先进入回收站，可查看详情、还原或永久删除。
- 个人与设置页：支持通知测试、强提醒测试、定位权限、电池优化和国产 Android 后台设置引导。

## 使用方式

1. 首次打开应用后，按提示授予定位、后台定位和通知权限。
2. 在首页点击新增提醒，搜索或定位到目标地点。
3. 设置围栏半径、提醒内容、提醒方式和提醒次数。
4. 保存提醒后，应用会在你从目标地点外进入目标地点范围时触发提醒。
5. 如需提高后台触发稳定性，请在系统设置中允许自启动、后台定位、通知和省电无限制。

## 权限说明

应用会请求以下权限，用于完成位置提醒能力：

- 定位权限：用于获取当前位置和判断是否进入目标地点范围。
- 后台定位权限：用于应用退到后台或锁屏后继续监听地理围栏。
- 通知权限：用于展示到达提醒。
- 电池优化白名单：用于减少系统省电策略对后台监听的影响。
- 唤醒与前台服务权限：用于强提醒和后台定位服务。

位置数据仅用于本机提醒逻辑，当前项目不包含账号同步或云端上传功能。

## 百度地图 AK 说明

本项目使用百度地图开放平台能力。当前 APK 暂按个人开发、免费体验和非商业用途使用百度地图 AK。

为了减少 AK 被滥用的风险，建议在百度地图开放平台后台限制：

- 应用类型：Android SDK
- 包名：`com.example.geofence_reminder`
- SHA1：发布 APK 所使用 keystore 的 SHA1

Android APK 中的 AK 无法做到完全隐藏，因此不要把这个 AK 用于其他项目，也不要把未限制包名和 SHA1 的 AK 用于公开发布。若项目后续用于商业场景、收费分发、广告变现、企业业务或其他营利用途，请按百度地图开放平台最新服务条款申请对应授权。

## 版本更新与覆盖安装

Android 能否覆盖安装旧版本，取决于两个条件：

- `applicationId` 必须保持一致，当前为 `com.example.geofence_reminder`。
- 每次发布 APK 必须使用同一个 release 签名证书。

后续发版时，只需要在 `pubspec.yaml` 中递增版本号，例如：

```yaml
version: 1.0.1+2
```

其中 `1.0.1` 是展示给用户看的版本名，`+2` 是 Android 的 `versionCode`，每次发布都必须递增。只要 `applicationId` 不变、签名证书不变、`versionCode` 递增，用户直接安装新版 APK 就会覆盖升级原有 App，不会多出一个 App。

如果你更改了 `applicationId`，手机会把它当成另一个 App。如果你更换了签名证书，系统会拒绝覆盖安装，并提示签名不一致。

## Release 签名配置

首次正式发布前，建议生成并长期保存一个 release keystore。不要把 keystore 和密码提交到 GitHub。

生成 keystore 示例：

```bash
keytool -genkey -v -keystore android/app/geofence-reminder-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias geofence_reminder
```

复制示例配置：

```bash
copy android\key.properties.example android\key.properties
```

然后在 `android/key.properties` 中填写真实密码：

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=geofence_reminder
storeFile=app/geofence-reminder-release.jks
```

`android/key.properties` 和 `*.jks` 已被 `.gitignore` 忽略，请只在本机保存。后续所有正式 APK 都应使用同一个 keystore 构建。

查看 release keystore 的 SHA1：

```bash
keytool -list -v -keystore android/app/geofence-reminder-release.jks -alias geofence_reminder
```

把输出中的 SHA1 配置到百度地图开放平台 Android AK 的安全校验中。

## 开发运行

本项目基于 Flutter 开发。

```bash
flutter pub get
flutter run
```

Android 地图和定位能力依赖百度地图相关 SDK。运行前需要在 Android 构建配置中提供可用的百度地图 API Key：

```properties
baidu.apiKey=your_baidu_android_ak
```

也可以通过构建参数传入：

```bash
flutter run --dart-define=BAIDU_ANDROID_KEY=your_baidu_android_ak
```

## 构建发布

构建 Android APK：

```bash
flutter build apk --release
```

构建完成后，将 APK 上传到 GitHub Releases。README 中的下载链接会自动指向最新 Release。

## 技术栈

- Flutter
- flutter_background_geolocation
- flutter_local_notifications
- 百度地图 Flutter SDK
- shared_preferences

## 注意事项

不同 Android 厂商对后台定位、通知和自启动的限制不同。小米、红米、OPPO、vivo、华为等机型建议手动开启后台定位、自启动、通知权限和省电无限制，以提高锁屏状态下的触发稳定性。
