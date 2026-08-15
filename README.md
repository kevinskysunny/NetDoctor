# NetworkConsole Lite（网络体检）

一个面向 Mac App Store 的只读 macOS 网络体检应用。它帮助普通 Mac 用户和轻度运维用户快速判断网络是否正常，不会修改 DNS、路由、代理、VPN 或任何系统服务。

## 产品能力

- 菜单栏状态图标：健康、警告、严重、检查中。
- 点击 Dock 图标可直接打开详情窗口。
- 快速检查窗口：当前状态、最近检查、立即检查、打开详情、导出支持包。
- 详情窗口：概览、网络接口、DNS 与路由、互联网连通性、本地时间线和设置。
- 中英文界面切换，设置页显示当前版本。
- 只读采集：`NWPathMonitor`、`Network.framework`、`SystemConfiguration`、`CoreWLAN`。
- 互联网连通性检测：对公开 HTTPS/TCP 端点并发采样，输出 RTT 分位数和失败比例近似。
- 排查建议：根据路径、DNS、路由和互联网连通性结果，为普通用户给出下一步检查建议。
- 本地支持包：脱敏 JSON，主动选择保存位置，不自动上传。

## 技术架构

```text
NetworkCore
  Models
  Protocols
  NWPathMonitorProvider
  SystemInterfaceCollector / SystemDNSCollector / SystemRouteCollector
  URLSessionReachabilityProber
  HealthGrader
  TimelineStore
  SupportPackageExporter
  DiagnosticEngine

NetworkConsoleApp
  MenuBarExtra
  QuickCheckView
  DetailView
  SettingsView
  AppModel
```

目标平台为 macOS 14+，SwiftUI + Swift Package。核心依赖通过协议注入，测试不访问真实网络。

仓库同时提供可由 `xcodegen` 生成的 macOS App 工程，用于本地签名、归档和 App Store 发布。

## 构建与测试

```bash
swift build
swift test
```

运行菜单栏应用：

```bash
swift run NetworkConsoleApp
```

生成并验证 macOS App：

```bash
xcodegen generate
swift build
swift test
xcodebuild -project NetworkConsoleLite.xcodeproj \
  -scheme NetworkConsoleApp \
  -configuration Release \
  -derivedDataPath .build/DerivedData \
CODE_SIGNING_ALLOWED=NO build
```

重新生成 App 图标：

```bash
swift Scripts/generate_app_icon.swift
```

## App Store 配置

发布配置位于 `Config/`：

- [App Sandbox entitlements](./Config/NetworkConsoleLite.entitlements)
- [Hardened Runtime 与版本设置](./Config/NetworkConsoleLite.xcconfig)
- [Info.plist](./Config/Info.plist)
- [隐私清单](./Sources/NetworkConsoleApp/Resources/PrivacyInfo.xcprivacy)
- [App 图标资源](./Assets.xcassets/AppIcon.appiconset)
- [XcodeGen 工程配置](./project.yml)

## 硬性边界

- 只读诊断，不修改网络配置。
- 不使用 SSH、Clash、AOne、EasyConnect 或企业内网认证。
- 不安装 LaunchDaemon、LaunchAgent、特权 Helper，不申请管理员权限。
- 不调用 Shell、Rust 子进程、外部诊断脚本、`Process` 或 `NSTask`。
- 不硬编码企业域名、IP、证书指纹或本机路径。
- 默认不上传诊断数据，不启用遥测。

## 规划文档

- [PRD](./docs/PRD.md)
- [实施计划](./docs/implementation-plan.md)
- [App Store 检查清单](./docs/appstore-checklist.md)
