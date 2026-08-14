# App Store 构建配置

`swift build` 和 `swift test` 用于持续验证 Swift Package。发布到 Mac App Store 时，请在 Xcode 中使用同一份 `Sources`，并应用：

- `NetworkConsoleLite.entitlements`：App Sandbox、出站网络、用户主动导出文件。
- `NetworkConsoleLite.xcconfig`：Hardened Runtime、Bundle ID、版本号。
- `Info.plist`：App 名称、类别、版权和最低系统版本。
- `Sources/NetworkConsoleApp/Resources/PrivacyInfo.xcprivacy`：隐私清单。
- `Assets.xcassets/AppIcon.appiconset`：macOS 多尺寸 App 图标。

仓库根目录的 `project.yml` 可用 `xcodegen generate` 生成 `NetworkConsoleLite.xcodeproj`。本地验证签名时，先以 `CODE_SIGNING_ALLOWED=NO` 构建，再对 `NetworkCore.framework` 和主 App 分别执行 `codesign`。

签名时不使用 ad-hoc，选择 App Store Connect 对应的 Distribution 证书，并启用 Hardened Runtime。
