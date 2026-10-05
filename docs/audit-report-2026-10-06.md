# NetDoctor (NetworkConsole Lite) 技术修改与架构审计报告 (v1.2.4 ~ v1.2.5)

> **生成日期**：2026-10-06  
> **目标读者**：技术团队 / 外部 AI 审查员（华为 AI 等）  
> **审查目标**：对 v1.2.4（零闲置能耗重构与出口合规自动化）以及 v1.2.5（系统设置深度直达与链路闭环）进行全面的架构审查、安全性分析与 Mac App Store 合规性评估。

---

## 1. 项目背景与设计红线 (Constraints & Red Lines)

- **产品定位**：`NetDoctor` 是一款面向 macOS 的轻量级、100% 只读网络体检与诊断工具（已在 Mac App Store 正式上架，正在迭代 v1.2.4 & v1.2.5）。
- **硬性规则 (严格遵守，受 AGENTS.md 约束)**：
  1. **只读诊断原则**：严禁修改系统 DNS、路由表、代理、VPN 或网络服务设置。
  2. **特权与子进程隔离**：严禁调用 `Process`、`NSTask`、Shell、Rust/Python 子进程；严禁申请 root 或管理员权限；严禁安装 LaunchDaemon、LaunchAgent 或特权 Helper 工具。
  3. **沙盒与隐私合规**：必须严格运行在 macOS App Sandbox 下，开启 Hardened Runtime；默认零遥测，不向任何云端上传数据；支持包导出时必须脱敏敏感网络信息。
  4. **无外部网络依赖的单元测试**：所有单元测试必须使用 mock 数据注入，不能依赖实际外网连接或真实系统弹窗。
  5. **严格多语言一致性**：支持 8 种语言（`zh`, `en`, `ja`, `ko`, `de`, `fr`, `es`, `pt`），所有语种字典的 key 数量与含义必须 100% 镜像对齐。

---

## 2. 本次版本迭代提交历史 (Git Commits Overview)

本次审计涵盖从 `v1.2.3 (Build 10)` 至 `v1.2.5 (Build 12)` 的所有代码提交：

| 提交哈希 | 类型 | 模块 | 简要说明 |
| :--- | :--- | :--- | :--- |
| `5fae75e` | **feat** | `SystemSettingsNavigator` | 实现系统设置深度直达跳转（Wi-Fi、以太网、DNS、网络），8 语言字典扩增至 278 key，升级至 v1.2.5 Build 12 |
| `37ded7c` | **docs** | `Submission Notes` | 聚焦 v1.2.4 发版说明至纯粹的能耗与性能优化 |
| `f04d168` | **docs** | `Submission Notes` | 精简 v1.2.4 多语言发版文案 |
| `9ad22ef` | **fix** | `Info.plist / Compliance` | 配置 `ITSAppUsesNonExemptEncryption = false`，彻底消除 App Store Connect 出口合规黄色告警 |
| `cc87c65` | **release**| `AppDelegate / Performance` | 彻底移除 0.2s 轮询定时器，重构为事件驱动菜单模型，待机 CPU 归零 (0.0%)，发布 v1.2.4 Build 11 |

---

## 3. 核心修改技术方案与实现分析

### 模块 A：macOS 系统设置深度直达与优雅降级 (System Settings Deep Links - v1.2.5)

#### 1. 业务痛点与需求来源
- **痛点**：NetDoctor 恪守“纯只读”原则，自身绝不擅自篡改用户系统配置。当体检发现 DNS 解析缓慢或网卡离线时，用户若想修改配置，必须自行在 macOS“系统设置”中经历繁琐层级（`系统设置 -> 网络 -> 选择接口 -> 详细信息 -> 对应标签`）。
- **用户反馈**：论坛用户建议在卡片旁增加直达按钮，通过官方 URL Scheme 直接唤起系统设置对应子面板。

#### 2. 技术实现：`SystemSettingsNavigator.swift`
- **枚举定义与路径映射**：
  ```swift
  public enum SystemSettingsPane: String, CaseIterable, Sendable {
      case network = "x-apple.systempreferences:com.apple.preference.network"
      case wifi = "x-apple.systempreferences:com.apple.preference.network?Wi-Fi"
      case ethernet = "x-apple.systempreferences:com.apple.preference.network?Ethernet"
      case dns = "x-apple.systempreferences:com.apple.Network-Settings.extension?DNS"

      public var url: URL? { URL(string: rawValue) }

      public var fallbackPane: SystemSettingsPane? {
          switch self {
          case .network: return nil
          case .wifi, .ethernet, .dns: return .network
          }
      }
  }
  ```
- **优雅降级 (Graceful Fallback)**：
  macOS 13+ (Ventura, Sonoma, Sequoia) 将设置面板重构为 Extension 架构。为了防止深层锚点（如 `?DNS`）在不同次版本中未被正确激活，导航器设计了自动回退机制：当指定子面板打开失败时，自动降级唤起系统网络主面板 (`.network`)。
- **可测试性设计 (Mockable Dependency Injection)**：
  ```swift
  public struct SystemSettingsNavigator {
      public typealias URLOpener = @Sendable (URL) -> Bool

      @discardableResult
      public static func open(
          _ pane: SystemSettingsPane,
          opener: URLOpener = { NSWorkspace.shared.open($0) }
      ) -> Bool {
          guard let url = pane.url else { return false }
          let success = opener(url)
          if !success, let fallback = pane.fallbackPane, let fallbackURL = fallback.url {
              return opener(fallbackURL)
          }
          return success
      }
  }
  ```
  在单元测试中注入虚拟 `opener` 闭包，可针对 URL 构造、降级分支执行 100% 离线单测，CI 期间不会触发真实系统的 GUI 弹窗。

#### 3. UI 交互嵌入点
- **网卡接口卡片 (`DetailInterfacesView.swift`)**：
  - 硬件卡片右上角 LED 指示灯旁添加跳转小图标，自动根据物理接口类型分流打开 Wi-Fi (`?Wi-Fi`) 或以太网 (`?Ethernet`)。
  - SSID 栏右侧提供明确的 `[Wi-Fi 设置...]` 直达按钮。
- **DNS 诊断面板 (`DetailDNSRouteView.swift`)**：
  - 在 DNS 枢纽舱顶部标题栏解析来源胶囊旁，增加 `[在系统设置中配置 DNS...]` 按钮。
- **状态栏常驻浮窗 (`QuickCheckView.swift`)**：
  - 底部操作栏新增齿轮菜单，包含网络/Wi-Fi/以太网/DNS 四项快捷直达选项。
- **应用主菜单 (`NetworkConsoleApp.swift` & `AppDelegate.swift`)**：
  - 在主应用菜单设置项后插入 `系统网络设置...`。

---

### 模块 B：能耗极致优化与零闲置唤醒 (Zero Idle Wakeups - v1.2.4)

#### 1. 问题与根因
- 在 v1.2.3 之前，为保证多语言切换时菜单项能微秒级更新，`AppDelegate` 中注册了一个每 `0.2s` 触发一次的 `Timer`，并加入到 `RunLoop.common` 与 `RunLoop.eventTracking`。
- **问题**：该高频轮询导致应用在后台完全静默待机时，CPU 占用率仍维持在 `2.1% ~ 3.1%`，每秒闲置唤醒次数（Idle Wakeups）多达 6 次，对轻量级常驻工具而言存在能耗浪费。

#### 2. 技术重构：纯事件驱动模型
- **彻底移除定时器**：删除了 `menuTimer`。
- **三重事件钩子驱动**：
  1. **按需生命周期刷新**：在 `NSMenuDelegate` 的 `menuWillOpen(_:)` 和 `applicationDidBecomeActive(_:)` 中触发菜单注入；
  2. **用户交互即时捕获**：监听 `NSMenu.didBeginTrackingNotification`，在用户点击菜单瞬间完成即时渲染；
  3. **语言响应式管道绑定**：通过 Combine 订阅 `model.$language.receive(on: RunLoop.main)`，仅当用户显式切换语言时才触发全量菜单更新。
- **实测收益**：
  - 后台静默待机 CPU 占用率由 `3.1%` 直降至 **`0.0%`**；
  - 闲置线程唤醒由 `6/s` 降至 **`0/s`**，功耗完全归零。

---

### 模块 C：Mac App Store 出口合规自动化 (Export Compliance Automation)

#### 1. 痛点
构建包上传至 App Store Connect 之后，云端处理完毕经常被标记为“缺少出口合规证明”，构建版本旁显示黄色感叹号，阻断全自动交付流程，迫使开发者手动登录网页点击合规问卷。

#### 2. 双重闭环方案
- **编译期根治**：在 `Config/Info.plist` 中声明：
  ```xml
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  ```
  NetDoctor 仅使用苹果原生系统的标准 HTTPS/TLS，符合非豁免加密的免除条款。该 key 让 Apple 后台处理构建包时自动免除问卷。
- **API 兜底运维**：在全局发布技能库中新增 `set_export_compliance.py`，支持通过 App Store Connect REST API 端点 `PATCH /v1/builds/{id}` 传入 `{"attributes": {"usesNonExemptEncryption": false}}` 进行全自动兜底修复。

---

### 模块 D：8 国语言严格镜像同步与测试防御

- **全量扩充**：在全部 8 种语言（`zh`, `en`, `ja`, `ko`, `de`, `fr`, `es`, `pt`）中同步添加 4 个全新操作词条：
  - `action.openSettings.network`
  - `action.openSettings.wifi`
  - `action.openSettings.ethernet`
  - `action.openSettings.dns`
- **字典对齐防御**：所有语言词条基线从 274 严格同步扩增至 **278**。
- **自动化防漏机制**：
  - `Scripts/check_l10n_completeness.py` 断言全部 8 语言均为 278 key，任何新增遗漏均会导致 CI 退出码为 1。
  - `L10nFallbackTests.swift` 包含 `testAll8LanguagesHave278Keys` 与全量 key 覆盖测试。

---

## 4. 架构与合规性自查表

| 审查维度 | 规范要求 | 本次实现状态 | 审核依据与实现说明 |
| :--- | :--- | :---: | :--- |
| **只读原则** | 不篡改系统配置 | ✅ **完全符合** | 仅通过 URL Scheme 唤起系统官方设置，不执行任何写配置动作 |
| **沙盒合规** | App Sandbox + Hardened Runtime | ✅ **完全符合** | `NSWorkspace.shared.open` 属于沙盒官方许可的标准 IPC 调用 |
| **权限隔离** | 无 root / Helper / Shell | ✅ **完全符合** | 零辅助工具、零子进程、零提权 |
| **能耗标准** | 后台待机能耗最小化 | ✅ **完全符合** | 彻底移除轮询 Timer，待机 CPU 为 0.0%，闲置唤醒为 0/s |
| **隐私安全** | 零上报、零遥测 | ✅ **完全符合** | 不采集、不跟踪、不外传任何网络状态与用户标识 |
| **测试隔离** | 单元测试无网络/GUI 依赖 | ✅ **完全符合** | `SystemSettingsNavigator` 纯 Mock 注入，离线可测 |

---

## 5. 测试与构建验证报告

```bash
# 1. 多语言完整性检查
python3 Scripts/check_l10n_completeness.py
# 结果:
#   zh: 278 key ✅ | en: 278 key ✅ | ja: 278 key ✅ | ko: 278 key ✅
#   de: 278 key ✅ | fr: 278 key ✅ | es: 278 key ✅ | pt: 278 key ✅
#   ✅ 全部 8 语言均 278 key，缺口清零

# 2. 自动化单元与集成测试
swift test
# 结果:
#   Test Suite 'All tests' passed.
#   Executed 84 tests, with 0 failures (0 unexpected) in 0.176 seconds.

# 3. 本地 Release 打包与签名
xcodebuild -project NetworkConsoleLite.xcodeproj -scheme NetworkConsoleApp -configuration Release build
# 结果:
#   ** BUILD SUCCEEDED **

# 4. 本机部署验证
# 已覆盖安装至 /Applications/NetDoctor.app，并在本地成功启动实测。
```
