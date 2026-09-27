# NetDoctor（Network Console Lite）实施计划

> v1.2 起产品名统一为 `NetDoctor`；M0~M5 的历史任务沿用原项目名。
> 计划状态同步依据：`docs/project-review-2026-09-27.md`（2026-09-27）与上架事实复核（2026-09-27）。
>
> **上架基线（v1.1 已上架，可分发）**：App 显示名 `NetDoctor: Network Diagnostics`；Bundle ID `com.networkconsole.lite`；Apple ID `6801707344`；SKU `networkconsole-lite-0001`；Team ID `J84LGFK7GY`；构建 5。以上标识符**禁止修改**（见 PRD §8.7）。

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
- [x] 根据诊断结果生成面向普通用户的排查建议。
- [x] 网络变化防抖，周期巡检可配置。
- [x] 本地 JSONL 时间线和脱敏支持包导出。

## M3：SwiftUI 界面

- [x] 菜单栏状态图标：健康、警告、严重、检查中。
- [x] 菜单栏快速窗口：当前状态、最近检查、立即检查、打开详情。
- [x] 点击 Dock 图标可直接打开详情窗口。
- [x] 详情窗口：概览、网络接口、DNS 与路由、外网探测、时间线、设置、导出。
- [x] 中文优先界面，关键状态有图标和简短说明。
- [x] 多语言界面切换（8 语言本地化框架：zh/en 完整覆盖，ja/ko/de/fr/es/pt 启动兜底英文），并显示当前版本信息。
- [x] 无真实网络时所有模块仍可用，不阻塞主界面。

## M4：App Store 发布准备

- [x] 独立 Bundle ID、正式 App 名称（上架显示名 `NetDoctor: Network Diagnostics`）。
- [x] App 图标。
- [x] App Store 多尺寸截图（产物：`docs/media/appstore/v1.1/en`、`docs/media/appstore/v1.1/zh`）。
- [x] App Sandbox 与最小 entitlements。
- [x] Hardened Runtime。
- [x] `PrivacyInfo.xcprivacy` 隐私清单。
- [x] App Store 签名归档并通过签名校验（提交 `d7f7d9e`，手动签名 + App Store profile）。
- [x] v1.1 已提交 App Store Connect 并审核通过、可分发。
- [ ] 准备 v1.2 Review Notes（草稿位置：`docs/appstore-checklist.md`）。
- [x] 审核演示路径（产物：`docs/media/review/index.html`）。

## M5：验收与发布

- [ ] 手动验证无网络、Wi-Fi、有线、VPN 场景（v1.2 回归）。
- [ ] 验证诊断数据不包含个人和企业敏感信息。
- [ ] 验证支持包导出可读、可脱敏、无日志泄漏。
- [ ] 完成 App Store Connect v1.2 元数据与版本提交（保留上架标识符，构建号 ≥ 6）。

## M6：v1.2 质量加固（依据 2026-09-27 系统检查）

> 对应 `docs/PRD.md` §8 需求。**优先级已按"项目已上架 v1.1"事实重新评估**：凡涉及签名/权限/商店元数据变更的项一律降级或取消；编号沿用审查报告（H1~H4、M1~M4、L1~L8）。凡涉及不可变标识符的修改项由 M6.0 红线约束。

### M6.0 上架基线确认（先行，任何修改前完成）

- [ ] **[红线]** 在 `Config/` 与工程配置中核对不可变标识符一致：Bundle ID、Apple ID、SKU、Team ID（见 PRD §8.7），不在任何代码/配置变更中触碰。
- [ ] **[版本]** 规划 v1.2 版本号递增：`MARKETING_VERSION = 1.2`、`CURRENT_PROJECT_VERSION = 6`（高于已上架构建 5），并在提交前校验。
- [ ] **[隐私]** 预演 App Store Connect「App 隐私」问答与 `PrivacyInfo.xcprivacy` 一致性；确认 v1.2 未新增数据收集类别。

### M6.1 发布前修复（高优先级，无审核风险）

- [ ] **[M1] 品牌统一 NetDoctor（仅代码内部标识与导出内容）**：
  - 支持包文件名前缀改为 `NetDoctor-Support-*`。
  - 探测请求 User-Agent 从 Bundle 读取产品名与版本号，去除硬编码 `NetworkConsoleLite/1.0`。
  - 时间线存储目录/userDefaults 键名改用新标识（兼容读取旧目录后切换新目录）。
  - **边界**：不改 Bundle ID / Apple ID / SKU；应用内显示名保持短名 `NetDoctor`，不改为商店全名。
- [ ] **[M2] 移除本地签名配置泄漏**：将 `Config/ExportOptions.local.plist` 加入 `.gitignore` 并从 git 移除（含实名/Team ID/证书名），仅保留不含个人信息的模板 `Config/ExportOptions.plist`。本地签名能力不受影响（文件仅从版本库移除）。
- [ ] **[M3] 文档状态同步**：核对 `docs/appstore-checklist.md` 勾选状态与 M4/M5 实际产出一致。

### M6.2 本地化与 i18n（目标：8 语言全覆盖，不因已上架降级）

> 说明：应用内语言与 App Store Connect 元数据语言是两套独立体系；补齐翻译为纯增量变更，不影响升级审核（详见 PRD §8.1）。

- [ ] **[H1] 8 语言全覆盖（目标）**：以中文 key 基线（248）为基准，补齐 ja（缺 84）、ko/de/fr/es/pt（各缺 117）的全部缺失 key，目标为缺口清零。按语言分批推进：第一批 zh/en（已齐，补测试兜底），第二批 ja，第三批 ko/de/fr/es/pt。
  - **v1.2 发布门槛（过渡态）**：zh/en 与基线 100% 一致；其余语言缺失 key 回退英文、**严禁回退中文**；无中文泄漏。
  - **目标态（v1.2 或延续 v1.3）**：8 语言缺口收敛至零。
- [ ] **[H1] L10n 完整性框架与测试**：新增测试断言 zh/en 与中文基线完全一致（CI 硬门禁）；其余语言输出缺口清单进 CI 报告，随版本收敛。
- [ ] **[H1] 兜底链修正**：固定非中文语言缺失 key 时的回退目标为英文（当前 fallback 链为 dict → en → zh，需调整为绝对英文兜底，杜绝中文泄漏）。
- [ ] **[H3] 诊断文案类型化**（内部重构，行为一致，无审核影响）：`HealthGrader.verdict/advice/summary` 与 `DiagnosticEngine` 时间线消息改为语言中立枚举编码；App 层按编码走 L10n，移除中文字符串 switch 匹配（`AppModel.localizedVerdict / localizedAdvice`）。**目的：杜绝任何语言界面泄漏中文原文（§8.1 验收）**。
- [ ] **[H3] 测试去文案耦合**：调整 `NetworkCoreTests` 中依赖中文字面断言的用例（如 `XCTAssertEqual(verdict, "全链路畅通 · 状态极佳")`），改为断言枚举编码。

### M6.3 测试加固（高优先级，纯质量项）

- [ ] **[H4] 新增 App 层测试 target**（`NetworkConsoleAppTests`）：
  - L10n key 完整性（zh ↔ en 一致；其余语言缺口清单）。
  - `AppLanguage.resolveEffective` / `from(stored:)` 解析。
  - `AppModel` 本地化映射（verdict/advice/status/timeline，使用 mock engine）。
- [ ] **[H4] 脱敏边界测试**：按 PRD §8.3 策略文档化支持包保留/脱敏字段，并补充 SSID、IP、DNS、网关、时间线导出测试。

### M6.4 体验与文档一致性（中优先级）

- [ ] **[SSID 体验] 空值文案优化**（替代原 H2 方案 A）：不新增 entitlement；界面与导出中 "SSID" 为空时显示"未获取"占位，清理伪空白与误导性文案（见 PRD §8.4）。
- [ ] **[M4] 脱敏策略文档化并核对**：`docs/PRIVACY.md` 与界面文案按 PRD §8.3 精确表述（保留 IP/DNS/网关为诊断信息，SSID 不可用时不承诺能力）；核对 App Store「App 隐私」问答一致性。

### M6.5 工程债清理（低优先级，不阻塞 v1.2）

- [ ] **[L1] 拆分超大文件**：`DetailView.swift`（1675 行）与 `Localization.swift`（1444 行）按模块拆分。
- [ ] **[L2] 简化 `DetailView.detectProvider`**：合并 172.16.0.0/12 私有网段判断。
- [ ] **[L3] 清理 `AppModel.score` 冗余分支**。
- [ ] **[L4] `SystemInterfaceCollector` 降级**：`getifaddrs` 失败时返回 path 接口摘要，而非空列表。
- [ ] **[L5] `TimelineStore` 写序加固**：文件追加写移入锁内或串行队列。
- [ ] **[L7] 接入 CI**：GitHub Actions 执行 `swift build && swift test`，zh/en 本地化测试作为门禁。
- [ ] **[L8] 文档归档**：`docs/new-session-prompt.md`、`docs/ui-dynamic-revamp-plan.md` 等过程性文档归档或标注历史。

### M6.6 v1.3+ 增强候选（明确不阻塞 v1.2）

> 注：8 语言全覆盖目标已纳入 M6.2 主线；若 v1.2 未清零缺口，以下为延续项。

- [ ] **[H1·延续]** v1.2 未完成的剩余语言翻译持续补齐（目标不变，仅排期延后）。
- [ ] **[H2·候选]** 评估申请 `com.apple.developer.networking.wifi-info` entitlement 的产品价值（需单独版本发布并评估签名/审核影响）。
- [ ] **[技术] 迁移 String Catalogs（`.xcstrings`）**，改善翻译工作流与缺 key 告警。
- [ ] **[L6] 版本号来源统一**（User-Agent/支持包自描述与构建配置对齐）。

## 每步完成定义

- 代码通过 `swift build` 和 `swift test`。
- 新行为/新文案有对应测试，不依赖真实网络；本地化变更必须通过 zh/en 完整性测试。
- 归档前校验：构建号 ≥ 6、Bundle ID 与上架记录一致、无新增 entitlements。
- README 同步更新。
- 变更提交并推送到 `origin/main`。