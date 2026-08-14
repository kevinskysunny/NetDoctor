# NetworkConsole Lite 实施计划

## M0：项目准备

- [x] 创建独立本地项目目录。
- [x] 创建 GitHub 私有仓库并推送。
- [x] 输出 PRD、实施计划、App Store 检查清单和施工提示词。

## M1：Package 骨架与数据模型

- [x] 创建 Swift Package，`swift-tools-version` 6.0，macOS 14+。
- [x] 建立 `NetworkCore` 和 `NetworkConsoleApp` 两个 target。
- [x] 定义 `NetworkSnapshot`、`InterfaceInfo`、`DNSSummary`、`RouteSummary`、`ReachabilityProbe`、`LatencySample`、`DiagnosisReport`。
- [x] 建立 mock 友好协议：`NetworkPathProviding`、`InterfaceCollecting`、`ReachabilityProbing`。
- [x] 为模型解析、分类逻辑补齐单元测试。

## M2：只读采集与诊断

- [x] 使用 `NWPathMonitor` 观察路径和接口类型。
- [x] 使用只读系统接口采集活动接口、IPv4/IPv6、SSID、网关。
- [x] 采集 DNS resolver 摘要。
- [x] 使用 `URLSession` 和 `NWConnection` 探测公开端点。
- [x] 实现 RTT 分位数、超时比例和失败比例。
- [x] 实现健康分级：健康、警告、严重。
- [x] 网络变化防抖，周期巡检可配置。
- [x] 本地 JSONL 时间线和脱敏支持包导出。

## M3：SwiftUI 界面

- [x] 菜单栏状态图标：健康、警告、严重、检查中。
- [x] 菜单栏快速窗口：当前状态、最近检查、立即检查、打开详情。
- [x] 详情窗口：概览、网络接口、DNS 与路由、外网探测、时间线、设置、导出。
- [x] 中文优先界面，关键状态有图标和简短说明。
- [x] 无真实网络时所有模块仍可用，不阻塞主界面。

## M4：App Store 发布准备

- [x] 独立 Bundle ID、正式 App 名称。
- [ ] App 图标和多尺寸截图。
- [x] App Sandbox 与最小 entitlements。
- [x] Hardened Runtime。
- [x] `PrivacyInfo.xcprivacy` 隐私清单。
- [ ] 公证或 App Store 签名校验通过。
- [ ] 准备 Review Notes、截图和演示路径。

## M5：验收与发布

- [ ] 手动验证无网络、Wi-Fi、有线、VPN 场景。
- [ ] 验证诊断数据不包含个人和企业敏感信息。
- [ ] 验证支持包导出可读、可脱敏、无日志泄漏。
- [ ] 完成 App Store Connect 元数据并提交审核。

## 每步完成定义

- 代码通过 `swift build` 和 `swift test`。
- 新行为有对应测试，不依赖真实网络。
- README 同步更新。
- 变更提交并推送到 `origin/main`。
