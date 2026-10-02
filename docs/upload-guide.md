# NetDoctor App Store Connect 上传指南

> 供 Google AI 或自动化脚本使用。所有信息均已在本机验证通过。

## 0. 环境信息（已验证）

| 项目 | 值 |
|------|-----|
| Xcode | 27.0 (Build 27A266a) |
| Scheme | `NetworkConsoleApp` |
| Bundle ID | `com.networkconsole.lite` |
| Team ID | `J84LGFK7GY` |
| 版本号 | 1.2.3 (build 10) |
| App Store Connect API Key ID | `L8KUV7H76N` |
| API Key 文件路径 | `~/.appstoreconnect/private_keys/AuthKey_L8KUV7H76N.p8` |
| App 签名证书 | `3rd Party Mac Developer Application: xukuo huang (J84LGFK7GY)` |
| Installer 签名证书 | `3rd Party Mac Developer Installer: xukuo huang (J84LGFK7GY)` |
| Provisioning Profile | `NetworkConsole Lite App Store`（已安装） |
| ExportOptions 配置 | `Config/ExportOptions.local.plist`（已配置 manual signing） |

## 1. 前置条件

### 1.1 App Store Connect API Issuer ID

**唯一缺失的信息**是 API Issuer ID。获取方式：

1. 登录 https://appstoreconnect.apple.com
2. 进入「用户和访问」→「密钥」→「App Store Connect API」
3. 复制 Issuer ID（格式类似 `a1b2c3d4-xxxx-xxxx-xxxx-xxxxxxxxxxxx`）

设置环境变量：

```bash
export APP_STORE_CONNECT_API_KEY_ID="L8KUV7H76N"
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_L8KUV7H76N.p8"
export APP_STORE_CONNECT_ISSUER_ID="<从 App Store Connect 获取的 Issuer ID>"
```

### 1.2 验证签名证书

```bash
# 应看到以下两个证书（可能显示 Missing required extension 警告，不影响使用）：
security find-identity -v -p macappstore
```

期望输出包含：
- `3rd Party Mac Developer Application: xukuo huang (J84LGFK7GY)`
- `3rd Party Mac Developer Installer: xukuo huang (J84LGFK7GY)`

### 1.3 验证 Provisioning Profile

```bash
# 应看到 "NetworkConsole Lite App Store" profile
for f in ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.provisionprofile; do
  security cms -D -i "$f" 2>/dev/null | grep -A1 "<key>Name</key>" | tail -1
done
```

## 2. 上传流程（推荐：分步执行）

### Step 1: 生成 Xcode 项目

```bash
cd /Users/kevinsmith/Person/project/07-apps-experiments/networkconsole-lite
xcodegen generate
```

### Step 2: Archive

```bash
xcodebuild archive \
  -project NetworkConsoleLite.xcodeproj \
  -scheme NetworkConsoleApp \
  -configuration Release \
  -archivePath build/NetDoctor.xcarchive \
  -destination "generic/platform=macOS" \
  CODE_SIGN_STYLE=Manual
```

验证 archive 创建成功：

```bash
ls -la build/NetDoctor.xcarchive/Products/Applications/NetDoctor.app
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
  build/NetDoctor.xcarchive/Products/Applications/NetDoctor.app/Contents/Info.plist
# 应输出: 1.2.3
```

### Step 3: 导出 .pkg（不上传）

创建一个不含 `destination: upload` 的 ExportOptions plist，仅用于本地导出 .pkg：

```bash
cat > /tmp/ExportOptions-export-only.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>J84LGFK7GY</string>
	<key>uploadSymbols</key>
	<true/>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>3rd Party Mac Developer Application: xukuo huang (J84LGFK7GY)</string>
	<key>installerSigningCertificate</key>
	<string>3rd Party Mac Developer Installer: xukuo huang (J84LGFK7GY)</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.networkconsole.lite</key>
		<string>NetworkConsole Lite App Store</string>
	</dict>
</dict>
</plist>
EOF
```

执行导出：

```bash
xcodebuild -exportArchive \
  -archivePath build/NetDoctor.xcarchive \
  -exportOptionsPlist /tmp/ExportOptions-export-only.plist \
  -exportPath build/export
```

验证 .pkg 生成：

```bash
ls -la build/export/*.pkg
# 应看到类似: NetDoctor-1.2.3-10.pkg 或 NetDoctor.pkg
```

### Step 4: 上传到 App Store Connect

使用 API Key 认证上传：

```bash
PKG_PATH=$(ls build/export/*.pkg | head -1)

xcrun altool --upload-app \
  --type mac \
  --file "$PKG_PATH" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --upload-package
```

> **注意**：`xcrun altool` 会自动在 `~/.appstoreconnect/private_keys/` 和 `~/private_keys/` 查找 `AuthKey_<key_id>.p8` 文件。

### Step 5: 验证上传状态

```bash
xcrun altool --list-apps \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --type mac 2>&1 | grep -i "networkconsole\|netdoctor"
```

## 3. 一键上传脚本（可选）

如果分步验证全部通过后需要一键执行：

```bash
#!/bin/bash
set -euo pipefail

cd /Users/kevinsmith/Person/project/07-apps-experiments/networkconsole-lite

echo "=== Step 1: xcodegen ==="
xcodegen generate

echo "=== Step 2: Archive ==="
xcodebuild archive \
  -project NetworkConsoleLite.xcodeproj \
  -scheme NetworkConsoleApp \
  -configuration Release \
  -archivePath build/NetDoctor.xcarchive \
  -destination "generic/platform=macOS" \
  CODE_SIGN_STYLE=Manual

echo "=== Step 3: Export .pkg ==="
xcodebuild -exportArchive \
  -archivePath build/NetDoctor.xcarchive \
  -exportOptionsPlist Config/ExportOptions.local.plist \
  -exportPath build/export

echo "=== Step 4: Upload ==="
PKG_PATH=$(ls build/export/*.pkg | head -1)
xcrun altool --upload-app \
  --type mac \
  --file "$PKG_PATH" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --upload-package

echo "=== Done ==="
```

> **注意**：一键脚本使用 `Config/ExportOptions.local.plist`，其中包含 `destination: upload`，会在导出时直接上传。如果使用此方式，Step 4 的 altool 上传可省略。

## 4. 常见问题

### 4.1 "Missing required extension" 警告

`security find-identity` 显示证书有 `(Missing required extension)` 警告是正常的，不影响 App Store 上传。这是 macOS Keychain 对 3rd Party 证书的已知显示问题。

### 4.2 上传失败：认证错误

```
*** Error: You are not allowed to perform this operation.
```

检查：
- API Key 是否有效（未过期、未撤销）
- API Key 是否有「App Manager」或「Admin」权限
- Issuer ID 是否正确

### 4.3 上传失败：版本号冲突

```
*** Error: The build version 10 already exists.
```

解决：在 `project.yml` 中递增 `CURRENT_PROJECT_VERSION`（如 10→11），重新 archive + export + upload。

### 4.4 导出失败：签名错误

```
Error: code signing failed
```

检查：
- Provisioning Profile 是否已安装且未过期
- 签名证书是否在 Keychain 中且信任状态正常
- `Config/ExportOptions.local.plist` 中的证书名称是否匹配

### 4.5 xcrun altool 找不到 API Key

确保 key 文件路径正确：

```bash
# 方式1: 标准路径
cp AuthKey_L8KUV7H76N.p8 ~/.appstoreconnect/private_keys/

# 方式2: 备用路径
cp AuthKey_L8KUV7H76N.p8 ~/private_keys/
```

## 5. 上传后操作

上传成功后，需要在 App Store Connect 中：

1. 登录 https://appstoreconnect.apple.com
2. 进入「我的 App」→「NetDoctor」
3. 在「macOS」标签页中选择新上传的构建版本
4. 添加「新增内容」说明（如：菜单本地化修复、自定义探测端点）
5. 提交审核

### 本次版本 1.2.3 (build 10) 变更说明（供填写审核备注）

```
新增功能:
- 菜单栏全量动态本地化（中/英/日/韩/德/法/西/葡 8 语言）
- 自定义探测端点（添加/删除/重置，含输入清洗与底线保护）
- 原生 .lproj 资源包支持
- View 菜单新增"显示 NetDoctor 窗口"项
- Help 菜单新增在线文档、隐私政策、官网、联系支持链接

修复:
- 菜单栏语言不随 App 语言切换的问题
- View 菜单点击无反应的问题
- Help 菜单点击报错的问题
- Edit 菜单冗余项清理
```