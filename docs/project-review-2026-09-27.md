# NetworkConsole Lite / NetDoctor 项目系统检查报告

> 检查日期：2026-09-27
> 检查范围：全仓库源码、测试、配置、文档、构建产物
> 检查方法：静态代码审阅 + 合规性模式扫描 + `swift build`/`swift test` 实测 + xcodegen 漂移验证

## 1. 总体结论

项目质量整体良好，符合 AGENTS.md 硬性规则，构建与测试全部通过。主要风险集中在 **多语言覆盖不完整**、**i18n 架构脆弱**、**测试覆盖不足** 三个方面，另有若干品牌残留与发布配置问题，建议在提交 App Store 审核前处理。

## 2. 验证结果

| 项目 | 结果 |
|---|---|
| `swift build` | ✅ 通过（Build complete!） |
| `swift test` | ✅ 通过（16 个测试，0 失败，0.007s） |
| 测试网络依赖 | ✅ 全部使用 mock 注入，无真实网络 |
| `xcodegen generate` 漂移 | ✅ 无 diff，project.yml 与 xcodeproj 同步 |
| 硬性规则合规 | ✅ 见第 4 节 |

测试总耗时 0.007 秒，说明全部走 mock 分支，符合"测试必须无真实网络依赖"要求。

## 3. 问题清单

### 3.1 高优先级

#### H1. 除中英文外的 6 种语言本地化覆盖严重缺失

- **证据**：`Sources/NetworkConsoleApp/Localization.swift` 各语言 dict 的 key 数量对比：
  - `zh` = 248（完整基线），`en` = 248（完整）
  - `ja` = 164，缺失 84 个 key
  - `ko` / `de` / `fr` / `es` / `pt` = 各 131，缺失 117 个 key
- **缺失 key 示例**：`verdict.*`（11 个）、`settings.engine.*`、`settings.auto.*`、`settings.privacy.*`、`card.*`、`timeline.filter.*`、`dnsRoute.dns.*`、`interfaces.telemetry.*` 等 —— 即 UI Revamp 后新增的一批 key 未同步翻译。
- **影响**：日语、韩语、德语、法语、西语、葡语界面大面积回退英文（`L10n.string` 的 fallback 链是 dict → en → zh）。与最近提交 `fix(l10n): eliminate mixed English/Chinese` 的目标相矛盾。
- **建议**：补齐 6 种语言的全部 key；将 L10n key 完整性纳入单元测试（防止新增 key 时静默遗漏）；考虑迁移到 String Catalogs（`.xcstrings`），原生支持缺 key 告警与导出/翻译工作流。

#### H2. SSID 读取依赖未声明的 WiFi entitlement，沙盒下功能可能失效

- **证据**：
  - `Config/NetworkConsoleLite.entitlements` 只有 app-sandbox / files.user-selected.read-write / network.client，**没有** `com.apple.developer.networking.wifi-info`。
  - `SystemInterfaceCollector`（SystemCollectors.swift 第 23 行）调用 `CWWiFiClient.shared().interface()?.ssid()`。
- **影响**：macOS 沙盒进程内，未持有 WiFi 信息 entitlement 时 `ssid()` 会返回 `nil`。App Store 分发后"Wi-Fi SSID"展示与"支持包 SSID 脱敏"功能均可能静默失效（表现为永远无 SSID）。
- **建议**：在本地先以 sandbox 模式实测；如要保留 SSID 功能，需向 App Store 申请 WiFi entitlement 并纳入审核说明；否则应从界面与导出逻辑中移除 SSID 相关能力，避免"展示缺失"的体验。

#### H3. NetworkCore 的 i18n 架构脆弱：中文硬编码 + 字符串匹配二次翻译

- **证据**：
  - `HealthGrader.swift`：`verdict()` / `advice()` / `summary()` 全部硬编码中文（如"全链路畅通 · 状态极佳"、"丢包抖动（部分端点探测失败）"）。
  - `DiagnosticEngine.swift` 第 58/78/169 行：TimelineEvent 的 `message` 硬编码中文。
  - `AppModel.swift` 第 399-428 行（`localizedVerdict`）与 475-515 行（`localizedAdvice`）：用中文字符串做 `switch` 匹配，命中后映射到 L10n key。
- **影响**：NetworkCore 文案一旦微调，App 层匹配失配，多语言用户直接看到原始中文（`default` 分支回退）。当前测试 `XCTAssertEqual(verdict, "全链路畅通 · 状态极佳")` 等于把中文文案"焊死"在测试里。
- **建议**：NetworkCore 返回**类型化枚举**（verdict code、advice code）而非本地化文案；App 层按 code 查 L10n；TimelineEvent 的 message 仅作日志/降级用，本地化一律基于 `arguments` 重建（当前 timeline.detail.* 已是此模式，可推广到 verdict/advice）。

#### H4. 测试覆盖不足：核心本地化与脱敏逻辑无回归保护

- **证据**：
  - 唯一测试 target 为 `NetworkCoreTests`，共 16 个用例，全部针对 NetworkCore。
  - **无** App 层测试：`AppModel`、`L10n`、`AppLanguage` 解析、`localizedVerdict/localizedAdvice` 均无测试。
  - `SupportPackageExporterTests` 只验证 SSID 脱敏，未验证 IP 地址、DNS 服务器、路由网关、Timeline 的导出行为。
- **影响**：H1/H3 所述问题没有任何回归防线；后续新增语言、新增 UI key、改动 core 文案都可能无声引入混合语言界面。
- **建议**：
  - 新增 `NetworkConsoleAppTests` target，测 `L10n` key 完整性（zh 为基线，其余语言缺失即失败）、`AppLanguage.resolveEffective`、`AppModel` 的本地化映射（用 mock engine）。
  - 为 SupportPackageExporter 的脱敏边界补测试（明确"哪些字段脱敏、哪些保留"的策略文档化）。

### 3.2 中优先级

#### M1. NetDoctor Rebrand 不彻底，NetworkConsole Lite 残留

- **证据**：
  - `docs/PRD.md` 全篇仍为 `NetworkConsole Lite`，第一行标题未更新。
  - `Package.swift` 产品/可执行 target 名为 `NetworkConsoleApp`；`project.yml` / Info.plist 的 `PRODUCT_NAME` 与 `CFBundleDisplayName` 已改为 `NetDoctor`。
  - `ReachabilityProber`（第 85 行）User-Agent 硬编码 `NetworkConsoleLite/1.0`。
  - `TimelineStore.defaultFileURL()` 使用 `Application Support/NetworkConsoleLite/timeline.jsonl`。
  - `SupportPackageExporter.suggestedFilename()` 使用 `NetworkConsoleLite-Support-*.json` 前缀。
  - `AppSettings` / `AppModel` 的 UserDefaults key 为 `networkConsoleLite.settings` / `networkConsoleLite.language`。
- **影响**：支持包文件、时间线目录、HTTP 请求头与商店名称不一致；PRD 与实现脱节。
- **建议**：统一为 `NetDoctor`（保留 `NetworkConsoleLite` 作为文件迁移兼容处理，读旧目录、写新目录或维持现状但明确记录）；更新 PRD；User-Agent 改为从 Bundle 读取版本号。

#### M2. `Config/ExportOptions.local.plist` 含开发者实名与 Team ID 且已提交

- **证据**：文件包含 `teamID = J84LGFK7GY`、`signingCertificate = 3rd Party Mac Developer Application: xukuo huang (J84LGFK7GY)`、`installerSigningCertificate`、provisioning profile 名 `NetworkConsole Lite App Store`。该文件在 git 工作树中且未被 .gitignore 排除。
- **影响**：仓库一旦公开（或误发），将泄漏开发者实名、Team ID、证书与 profile 名称。
- **建议**：将 `.local` 变体移入 `.gitignore`（仅保留 `ExportOptions.plist` 模板）；本地私密配置不入库。

#### M3. 文档状态滞后

- **证据**：
  - `docs/implementation-plan.md`：M4「App Store 多尺寸截图」仍为未勾选，但 `docs/media/appstore/v1.1/en|zh/` 已存在截图；M5 多项未勾选但已有发布/上传提交（`d7f7d9e`）。
  - `docs/appstore-checklist.md`：「隐私政策 URL」「App Store 多尺寸截图」「Review Notes」「3 分钟复现演示路径」仍为未完成，与 `docs/media/review/index.html`、`PRIVACY.md` 等已有产物不一致。
- **影响**：里程碑可追溯性差，容易遗漏审核材料。
- **建议**：同步勾选状态并引用实际产物路径。

#### M4. 支持包脱敏深度与 UI 宣传不一致

- **证据**：
  - `SupportPackageExporter.redact()` 仅将 `ssid` 替换为 `<redacted>`；接口 IP 地址（IPv4/IPv6）、DNS 服务器列表、路由网关均**完整保留**；Timeline 事件原样导出（message 为中文原始文案）。
  - UI/文案（`settings.privacy.item4.desc`）宣称"自动对 Wi-Fi SSID 与物理 MAC 脱敏"。
- **影响**：沙盒内 SSID 已可能为 nil 时脱敏退化为空；IP/DNS/网关从未脱敏却未在文案中说明，审核时若被追问"哪些字段脱敏"需谨慎回答。
- **建议**：将脱敏策略文档化（哪些字段保留是产品决策，保留 IP/网关对诊断有价值）；文案改为准确表述；Timeline message 建议语言中立化（同 H3）。

### 3.3 低优先级 / 工程建议

- **L1**：`DetailView.swift`（1675 行）、`Localization.swift`（1444 行）为超大文件，建议按模块拆分。
- **L2**：`DetailView.detectProvider`（第 1131 行）判断私有网段时一条条罗列 `172.16.`~`172.31.`，可用位运算或 `NSRegularExpression`/掩码判断简化。
- **L3**：`AppModel.score`（第 107-112 行）两个分支完全相同，冗余可删。
- **L4**：`SystemInterfaceCollector.collect()` 中 `getifaddrs` 失败直接返回 `[]`，即使 pathProvider 已有接口信息；建议降级返回 path 中的接口摘要。
- **L5**：`TimelineStore.append` 在 `NSLock` 外执行磁盘追加写，多线程下 JSONL 行序可能乱序（读取时按时间戳排序缓解），如需严格顺序可把文件写移入锁内或串行队列。
- **L6**：版本号多来源：`MARKETING_VERSION=1.1` / `CURRENT_PROJECT_VERSION=5`，但 User-Agent 硬编码 `1.0`（与 M1 合并处理）。
- **L7**：仓库无 CI 配置（如 GitHub Actions），构建/测试仅靠本地手动执行，建议加 `swift build && swift test` 流水线。
- **L8**：`docs/` 下存在 `new-session-prompt.md`、`ui-dynamic-revamp-plan.md`、`ASO-Metadata-Strategy.md` 等过程性文档，建议归档或标记为历史记录。

## 4. 硬性规则合规核查

| AGENTS.md 规则 | 结果 | 说明 |
|---|---|---|
| 只读诊断，不改 DNS/路由/代理/VPN | ✅ | 仅使用 `NWPathMonitor` / `getifaddrs` / `SCDynamicStoreCopyValue` 等只读接口 |
| 不装 LaunchDaemon / Helper / 不取管理员权限 | ✅ | entitlements 最小化，无特权声明 |
| 不调用 `Process` / `NSTask` / Shell / 脚本 | ✅ | 源码仅本地化文案中出现 `LaunchDaemon` 字样，无实际调用 |
| 不硬编码企业域名 / IP / 证书 / 端口 | ✅ | 已扫描；IP 仅用于公开 DNS 提供商识别与 `0.0.0.0/0` 默认路由展示，无企业信息 |
| 不使用 AOne/EasyConnect/Clash/SSH | ✅ | 无相关引用 |
| 测试无真实网络依赖 | ✅ | 16 个测试全部走 mock，0.007s 全绿 |
| 默认不上传 / 无遥测 | ✅ | `PrivacyInfo.xcprivacy` 声明无数据收集、无 tracking domains |

补充说明：`Scripts/asc_token.py` 的 App Store Connect 密钥从环境变量读取（`APP_STORE_CONNECT_API_KEY_PATH` 等），无硬编码密钥，合规。

## 5. 建议处理顺序

1. **发布前必做**：H2（SSID entitlement 实测与决策）、M2（移出本地配置文件）、M1（品牌统一，至少更新 PRD）。
2. **1.2 版本建议**：H1（补齐 6 语言 key + L10n 完整性测试）、H3（文案改类型化枚举）、H4（补 App 层测试）。
3. **持续改进**：L1~L8 工程债清理、CI 接入。

## 6. Antigravity 针对审查意见的复核结论与对齐说明 (2026-09-27)

### 6.1 总体评价

华为 AI（CodeArt）所出具的系统检查报告质量极高，事实命中率在 90% 以上。报告不仅完成静态代码与构建/测试实测，还精准定位到了高危安全隐患（M2 签名凭证泄露）、架构脆弱点（H3 字符串匹配反查多语言）以及多项深层工程坏味道（L2、L3、L5、M4），对项目工程质量提升具有重要价值。

### 6.2 完全认同并全盘采纳的事实项

1. **[H1 字典 Key 缺口统计精确]**：实测 `zh` 248 / `en` 248，`ja` 164（缺 84），`ko/de/fr/es/pt` 各 131（缺 117）。数据完全吻合，UI 重构新增 key 确实未能覆盖到其余 6 种语言，采纳为 v1.2 质量加固目标。
2. **[M2 开发者实名配置泄露（高危，立即执行）]**：`Config/ExportOptions.local.plist` 包含个人姓名 `xukuo huang` 与 Team ID `J84LGFK7GY` 且未被 `.gitignore` 忽略，存在严重公开泄露风险，必须立刻移出版本控制。
3. **[H3 i18n 字符串二次反查架构脆弱（采纳重构）]**：NetworkCore 输出中文结论文案，App 层依靠中文字符串 `switch` 匹配映射字典，测试强行断言中文字面量。该架构确实脆弱，采纳建议：改由 Core 输出类型化枚举（如 `VerdictCode` / `AdviceCode`），App 层直接按枚举映射 L10n。
4. **[M4 隐私描述与代码真实能力脱节（采纳修正）]**：界面宣称“自动对 Wi-Fi SSID 与物理 MAC 脱敏”，但底层代码根本未采集过物理 MAC 地址，纯属文案过度承诺；且 IP/DNS/网关按设计完整保留用于诊断。应直接修正界面文案与 PRIVACY 文档，准确说明脱敏策略，彻底剔除“物理 MAC”字样。
5. **[L2/L3/L5 工程技术债（采纳优化）]**：
   - **L2**：`DetailView.swift` 中逐条罗列 16 个私网 IP 前缀，采纳简化重构。
   - **L3**：`AppModel.swift` 第 107-112 行 `var score: Int` 两个分支完全相同，确认冗余。
   - **L5**：`TimelineStore.append` 释放锁后执行磁盘追加写，确实存在极端并发下的日志行乱序隐患，采纳移入串行化保证。

### 6.3 需修正与对齐的关键出入（策略与事实纠偏）

#### 1. 关于“中英文界面混杂残留”的进度差（时间切片差异）
- **报告观点**：认为英文模式下仍有多处残留中文，与“消除中英文混杂”的目标矛盾。
- **事实纠偏**：此问题在本次审查报告生成后的提交 `747ddef` 中已彻底根治。当前最新代码已将设置页（重试次数提示、超时描述与动态单位、自愈检查字样、系统语言选项）、仪表盘（`pts` / 分数）、拓扑链路管线（Local Mac / Gateway / DNS / Internet）、Bento 指标卡的所有写死中文和伪医学隐喻全部消除，`zh` 和 `en` 均已达成 100% 完整覆盖。

#### 2. 关于 H2（SSID 权限）的重大策略纠偏：绝不可盲目向 Apple 申请 WiFi Entitlement
- **报告建议**：*“如要保留 SSID 功能，需向 App Store 申请 WiFi entitlement 并纳入审核说明”*。
- **策略纠偏**：
  - `com.apple.developer.networking.wifi-info` 属于苹果官方高风险敏感特权，通常仅签发给硬件级路由器配置管理 App。对于只读网络体检工具，申请此权限不仅极大概率被拒，还会导致审核团队对沙盒合规性进行深入连带盘问，严重增加拒审与下架风险。
  - **既定对齐决策（PRD §8.4）**：**维持当前沙盒权限不变，不申请任何新 Entitlement**。当前沙盒环境下返回 `nil` 是已知且符合预期的现状。针对 UI 与导出，做“未获取 / Not available”的优雅占位降级，并修改文案去掉对 SSID 读取能力的夸大承诺即可。

#### 3. 关于 H1（6 种小语种缺失）的严重级别纠偏：不阻断当前 App Store 升级
- **报告观点**：将 6 种语言缺失定性为“提交审核前必须处理的高优先级阻断项”。
- **事实与规则纠偏**：
  - 本 App 在 App Store Connect 后台配置的元数据主要语言仅为 **English (US)**，并未在后台勾选支持其余 6 种语言的商店独立页面。
  - 应用内的多语言属于纯内嵌增量特性。在当前的 fallback 机制下，小语种缺失 key 会优雅回退至完整的英文（`en`），**不会违反 App Store 审核准则，更不会触发拒审**。
  - 因此：8 语言 100% 补齐应作为 **v1.2 质量加固目标**稳步推进，而非卡死 v1.2 发布的“发版前阻断项”。

#### 4. 关于 M1（品牌更名 NetDoctor）不可触碰的「合规红线」
- **报告建议**：*“统一为 NetDoctor，更新 PRD、User-Agent、时间线目录等”*。
- **合规红线明确**：
  - **绝对禁止改动**：**Bundle ID（`com.networkconsole.lite`）、Apple ID（`6801707344`）、SKU（`networkconsole-lite-0001`）、Team ID**。v1.1 已经以此标识上架可分发，任何对上述标识符的变动都会导致苹果识别为全新 App，导致存量用户彻底断联、无法升级。
  - **允许并采纳的改动**：支持包文件名前缀（`NetDoctor-Support-*`）、网络探测 User-Agent（读取 Bundle 版本号）、UserDefaults 读取新 key（保留旧 key 兼容迁移）、PRD 与架构文档名称对齐。

### 6.4 最终对齐的实施排期与分工

根据双方充分探讨与复核，最终实施路线图统一对齐如下：

| 阶段 | 任务项 | 负责范围 |
| :--- | :--- | :--- |
| **阶段一：即刻发版防线（无审核风险）** | **M2** 将 `ExportOptions.local.plist` 移入 `.gitignore` 并从 Git 历史跟踪中剔除 | 安全脱敏 |
| | **M4** 修正隐私说明文案（剔除“物理 MAC”，明确 SSID 优雅占位与诊断字段保留策略） | 文案一致性 |
| | **L3** 清理 `AppModel.score` 冗余分支 | 代码清理 |
| **阶段二：v1.2 架构加固与品牌规范** | **H3** NetworkCore 诊断结论与建议改用类型化枚举编码（`VerdictCode` / `AdviceCode`），彻底解除中文 switch 匹配 | 架构解耦 |
| | **H4** 新增 `NetworkConsoleAppTests` 测试 Target（断言 zh/en key 完整性、语言解析与脱敏边界） | 测试覆盖 |
| | **M1** 统一支持包前缀与 User-Agent 为 `NetDoctor`（保持 Bundle ID 等不可变标识不变） | 品牌统一 |
| | **H1（第一批）** 补齐 `ja`（日语）缺失的 84 个 key 并修正兜底链（非中文语言只回退 en） | 体验提升 |
| **阶段三：v1.3 持续完善** | **H1（第二批）** 补齐 `ko/de/fr/es/pt` 缺失 key，实现 8 语言缺口清零 | 国际化完整 |
| | **L1/L2/L5/L7** 超大文件拆分、私网判断简化、磁盘写序加固、接入 GitHub Actions CI | 工程技术债 |