# NetDoctor（Network Console Lite）实施计划

> v1.2 起产品名统一为 `NetDoctor`；M0~M5 的历史任务沿用原项目名。
> 计划状态同步依据：`docs/project-review-2026-09-27.md`（§6 Antigravity 复核结论）、`docs/ai-review-handoff-summary.md`（§7）、`docs/PRD.md`（§8.8~§8.9 与 §9）。
>
> **上架基线（v1.1 已上架，可分发）**：App 显示名 `NetDoctor: Network Diagnostics`；Bundle ID `com.networkconsole.lite`；Apple ID `6801707344`；SKU `networkconsole-lite-0001`；Team ID `J84LGFK7GY`；构建 5。以上标识符为**不可触碰合规红线**（见 PRD §8.7）。

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

## M6：v1.2 质量加固与三阶段排期（对齐 Antigravity 复核共识）

> 对应 `docs/PRD.md` §8.1~§8.7 需求与 §9 待确认事项。**排期与复核共识完全对齐**（`docs/project-review-2026-09-27.md` §6.4 三阶段路线图）。
> 待确认项（TC1~TC6）明确列入 M6.4 前置管理，不阻塞排期开端。

### M6.1 阶段一：即刻发版防线（无审核风险，先行处置）

- [ ] **[M2] 移除本地签名配置泄漏**：将 `Config/ExportOptions.local.plist` 加入 `.gitignore` 并从 git 索引移除（`git rm --cached`；含实名 xukuo huang / Team ID J84LGFK7GY / 证书与 profile 名），仅保留不含个人信息的模板 `Config/ExportOptions.plist`。本地签名能力不受影响。
- [ ] **[M4] 修正隐私与脱敏文案**：剔除"物理 MAC 脱敏"虚假承诺；明确"SSID 优雅占位 + IP/DNS/网关作为诊断字段保留"策略；同步 `docs/PRIVACY.md`、设置页 `settings.privacy.*` 文案与支持包导出说明（见 PRD §8.3）。
- [ ] **[L3] 清理 `AppModel.score` 冗余分支**：两分支完全相同的冗余代码删除；无行为变更，`swift build && swift test` 通过即完成。
- [ ] **[M3] 文档状态同步**：同步各文档完成状态（对齐 PRD §9 TC4 决议）。
- [x] **[TC3·决议] 阶段一合并入 v1.2 发布**：阶段一任务不独立发 hotfix，随 v1.2（构建号 6）统一打包提交，避免版本碎片化。

### M6.2 阶段二：v1.2 架构加固与品牌规范

- [ ] **[H3] 诊断文案类型化重构**：`HealthGrader.verdict/advice/summary` 与 `DiagnosticEngine` 时间线消息改用语言中立枚举编码（`VerdictCode` / `AdviceCode`）；App 层按编码映射 L10n，删除 `AppModel.localizedVerdict / localizedAdvice` 的字符串 switch 匹配；支持包导出 timeline SchemaVersion 维持 1，无破坏性变更（对齐 PRD §9 TC5 决议）。
- [ ] **[H3] 测试去文案耦合**：调整 `NetworkCoreTests` 依赖中文字面断言的用例（如 `XCTAssertEqual(verdict, "全链路畅通 · 状态极佳")`）改为断言枚举编码。
- [ ] **[H4] 新增 `NetworkConsoleAppTests` target**：
  - L10n key 完整性（zh ↔ en 一致，CI 硬门禁；其余语言缺口清单）。
  - `AppLanguage.resolveEffective` / `from(stored:)` 解析。
  - `AppModel` 本地化映射（verdict/advice/status/timeline，mock engine）。
  - 脱敏边界测试（SSID 占位、IP/DNS/网关保留、时间线导出），对齐 PRD §8.3 策略。
- [ ] **[M1 & L6] 品牌统一 NetDoctor**（保持 Bundle ID / SKU / Apple ID 不可变红线）：
  - 支持包文件名前缀 `NetDoctor-Support-*`。
  - 探测请求 User-Agent 从 `Bundle.main` 读取产品名与版本号，去除硬编码 `1.0`（解决 L6）。
  - 时间线存储目录采用“启动时一次性安全搬迁”迁至 `Application Support/NetDoctor`（对齐 PRD §9 TC6 决议）。
  - 应用内显示名保持短名 `NetDoctor`。
- [ ] **[H1 第一批] 补齐 ja（日语）缺失 84 个 key + 兜底链修正**：
  - 兜底链固定为 dict → **en**（严禁非中文用户回退中文）。
  - 基线缺口数经核实确认仍为准确的 84 个 key（对齐 PRD §9 TC1 决议）。
- [ ] **[H1] L10n 完整性框架与测试**：zh/en 与基线完全一致（CI 硬门禁）；其余语言输出缺口清单进 CI 报告，随版本收敛。

### M6.3 阶段三：v1.3 持续完善（不阻塞 v1.2）

- [ ] **[H1 第二批] 补齐 ko/de/fr/es/pt 缺失 key**：各 117 个 key，8 语言缺口收敛清零。
- [ ] **[L1] 拆分超大文件**：`DetailView.swift`（1675 行）与 `Localization.swift`（1444 行）按模块拆分。
- [ ] **[L2] 简化 `DetailView.detectProvider`**：合并 172.16.0.0/12 私有网段判断（位运算/掩码）。
- [ ] **[L4] `SystemInterfaceCollector` 容错降级**：`getifaddrs` 失败时降级返回 path 接口摘要（对齐 PRD §9 TC4 决议）。
- [ ] **[L5] `TimelineStore` 写序加固**：文件追加写移入锁内或串行队列。
- [ ] **[L7] 接入 CI**：GitHub Actions 执行 `swift build && swift test`，zh/en 完整性测试作为门禁。
- [ ] **[L8] 过程文档归档**：历史过程文档归档至 `docs/archive/`（对齐 PRD §9 TC4 决议）。
- [ ] **[后续可选] 迁移 String Catalogs（`.xcstrings`）**：改善翻译工作流与缺 key 告警。

### M6.4 Antigravity 确认事项全数结项归档（TC1~TC6）

- [x] **[TC1] H1 缺口统计**：已核实 100% 精确（zh 248, en 248, ja 缺 84, 其余 5 语各缺 117）。
- [x] **[TC2] L3 阶段归属**：确认保留在阶段一顺手处置。
- [x] **[TC3] 阶段一发布形态**：确认合并入 v1.2 统一发布，避免版本号碎片化。
- [x] **[TC4] 未排期项归位**：M3 并入阶段一；L6 并入 M1（阶段二）；L4 与 L8 归入阶段三。
- [x] **[TC5] 支持包 SchemaVersion**：确认无破坏性结构变更，SchemaVersion 维持 1。
- [x] **[TC6] 时间线目录迁移策略**：确认采用“启动时一次性安全搬迁（One-time Move）”。

## 每步完成定义

- 代码通过 `swift build` 和 `swift test`。
- 新行为/新文案有对应测试，不依赖真实网络；本地化变更必须通过 zh/en 完整性测试。
- 阶段一任务完成后：`Config/ExportOptions.local.plist` 不在 git 索引中；`swift build && swift test` 通过。
- 归档前校验：构建号 ≥ 6、Bundle ID 与上架记录一致、**无新增 entitlements**（尤其绝无 WiFi 信息权限）。
- README 同步更新。
- 变更提交并推送到 `origin/main`。