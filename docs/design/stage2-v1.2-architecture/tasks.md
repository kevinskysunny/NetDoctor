# 阶段二「v1.2 架构加固与品牌规范」可执行任务清单（tasks.md）

> 配套方案文档：`docs/design/stage2-v1.2-architecture/design.md`（需求规格设计）、`implementation.md`（实现方案，1101 行，含每个任务的实现步骤、代码改动位置与片段、验证方式）。
> 需求来源：`docs/implementation-plan.md` M6.2；`docs/PRD.md` §8.1/§8.2/§8.5/§8.6/§8.8/§9 TC1~TC6。
> 决策基线：commit `23f0396`（阶段一结项）；`swift build` ✅ / `swift test` ✅（16 例全绿）。
> 约束红线：Bundle ID（`com.networkconsole.lite`）/ Apple ID（`6801707344`）/ SKU（`networkconsole-lite-0001`）/ Team ID（`J84LGFK7GY`）/ 上架显示名（`NetDoctor: Network Diagnostics`）**不可触碰**；不新增 entitlements；L10n zh/en 248 基线不增删（ja 补齐是新增 ja 字典 key）；支持包 SchemaVersion 维持 1；不新增数据收集类别；不调用 Process/NSTask/Shell；测试无真实网络依赖。
> 执行顺序：1（H3 类型化）→ 2（H1 ja+兜底链）→ 3（M1 品牌）→ 4（H4 测试）→ 5（验证）→ 6（提交）。其中 1.1→1.2→1.3 为编译依赖链不可乱序；2.1 必须先于 2.2（同一提交）；4 必须在 1~3 全部完成后执行。
> 评审对齐：本文档已整合 Google AI（Antigravity）复核 5 项微调建议（详见 design.md 第四节）：① VerdictCode 12 case + `notChecked` 归属厘清；② DiagnosticAdvice 保留 title/message 字段；③ CyberDiagnosisCardView.swift 联动；④ TimelineStore 二级文件粒度迁移保护；⑤ NetworkConsoleAppTests 不实例化视图层。

---

## 任务总览

| ID | 代号 | 任务组 | 子任务数 | 风险 | 涉及文件数 | 验证命令 |
|----|------|--------|---------|------|-----------|---------|
| 1 | H3 | 诊断结论语言中立化（类型化重构） | 3 | 中 | 5 | `swift build` + `swift test` |
| 2 | H1 | 日语本地化补齐与兜底链修正 | 2 | 低 | 1 | Python 脚本统计 + `swift build` |
| 3 | M1 | 品牌统一 NetDoctor | 2 | 中 | 7 | `grep` + `swift build` |
| 4 | H4 | App 层测试 target 建立 | 3 | 中 | 5 | `swift test --filter NetworkConsoleAppTests` |
| 5 | 验证 | 全量验证与红线核对 | 5 | — | — | 见各子任务验证命令 |
| 6 | 提交 | 提交与文档同步 | 2 | 低 | git | `git log` 核对 |

---

## 1. 诊断结论语言中立化（H3 类型化重构）

> 对应 implementation.md 第一章（T1）、第二章（T2）、第三章（T3）。
> 依赖链：1.1（新增枚举）→ 1.2（NetworkCore 改造）→ 1.3（App 层消费），编译依赖不可乱序。
> 预期效果：NetworkCore 诊断结论以语言中立枚举编码，App 层按编码映射 L10n，消除全部中文 switch 匹配。

### 1.1 新增 VerdictCode / AdviceCode 枚举（T1）

- [ ] 在 `Sources/NetworkCore/Models.swift` 末尾（第 585 行之后）追加 `VerdictCode` 枚举：`String, Codable, Sendable, CaseIterable`，**12 case**（`checking`/`optimal`/`good`/`dnsSlow`/`constrained`/`jitterLoss`/`highLatency`/`warningDefault`/`offline`/`noInterface`/`allProbesFailed`/`criticalDefault`），提供 `var l10nKey: String` 计算属性返回 `"verdict.\(rawValue)"`
- [ ] 在 `Sources/NetworkCore/Models.swift` 追加 `AdviceCode` 枚举：`String, Codable, Sendable, CaseIterable`，**10 case**（9 种 advice + `.unknown` 解码兜底：`confirmConnection`/`enableInterface`/`checkDNS`/`checkRoute`/`constrained`/`unreachable`/`partialUnreachable`/`highLatency`/`healthy`/`unknown`），提供 `var titleKey: String` / `var messageKey: String` 计算属性
- [ ] 确认 `verdict.notChecked` 不纳入 `VerdictCode` 枚举（AG 建议一：该 key 为 AppModel 专属 UI 兜底状态，`AppModel.swift:116` 在 `report == nil` 时直接消费，不由 NetworkCore `verdict()` 生成；Localization.swift 13 个 `verdict.*` key 映射体系自洽）
- [ ] 验证：`swift build` 编译通过（新类型仅定义尚无引用）；`grep -n "VerdictCode\|AdviceCode" Sources/NetworkCore/Models.swift` 确认两个枚举定义存在
- [ ] 不改项：`HealthGrade` 枚举（`Models.swift:421-452`）保持不变，作为 VerdictCode 的设计范本

### 1.2 改造 NetworkCore 返回枚举与 Codable 容错（T2）

- [ ] **DiagnosisReport.verdict 类型变更**：`Sources/NetworkCore/Models.swift:486`（属性声明）与 `:501`（init 参数）将 `String` → `VerdictCode`，init 默认值 `.checking`
- [ ] **DiagnosisReport 自定义解码容错**：在 `DiagnosisReport` 结构体内追加 `init(from decoder:)`，旧 JSON 中文 verdict → `VerdictCode(rawValue:)` nil → 兜底 `.checking`（支持包 SchemaVersion 维持 1，TC5 决策）
- [ ] **DiagnosticAdvice 结构变更**（AG 建议二）：`Sources/NetworkCore/Models.swift:454-471` 新增 `code: AdviceCode` 字段，**保留** `title`/`message` 字段（避免 `QuickCheckView.swift:128,130` 与 `DetailView.swift:264,266` 编译中断）；NetworkCore 构造时 title/message 默认空串 `""`
- [ ] **DiagnosticAdvice 自定义解码容错**：追加 `init(from decoder:)`，旧 JSON 无 code 字段 → `.unknown`，有 title/message → 保留原值（100% 向后兼容）
- [ ] **HealthGrader.verdict() 返回类型变更**：`Sources/NetworkCore/HealthGrader.swift:112-161` 返回类型 `String` → `VerdictCode`，12 处 `return "中文"` → `return .enumCase`（对应关系：`"链路探测中…"` → `.checking`、`"链路中断…"` → `.offline`、`"物理断开…"` → `.noInterface`、`"出口受阻…"` → `.allProbesFailed`、`"严重异常…"` → `.criticalDefault`、`"解析异常…"` → `.dnsSlow`、`"带宽受限…"` → `.constrained`、`"丢包抖动…"` → `.jitterLoss`、`"延迟偏高…"` → `.highLatency`、`"局部异常…"` → `.warningDefault`、`"全链路畅通…"` → `.optimal`、`"连接稳定…"` → `.good`）
- [ ] **HealthGrader.advice() 改用 code 构造**：`Sources/NetworkCore/HealthGrader.swift:185-288` 9 处 `DiagnosticAdvice(title:message:severity:)` 改为 `DiagnosticAdvice(code:severity:)`，title/message 默认空串（对应关系：`"确认网络已连接"` → `.confirmConnection`、`"启用网络接口"` → `.enableInterface`、`"检查 DNS 设置"` → `.checkDNS`、`"检查默认路由或 VPN"` → `.checkRoute`、`"网络处于受限状态"` → `.constrained`、`"外网不可达"` → `.unreachable`、`"部分外网站点不可达"` → `.partialUnreachable`、`"延迟偏高"` → `.highLatency`、`"网络状态正常"` → `.healthy`）
- [ ] **HealthGrader.summary() 返回空串**：`Sources/NetworkCore/HealthGrader.swift:163-183` 改为 `return ""`（App 层 `localizedSummary` 已按 `HealthGrade` 重建）
- [ ] **移除 criticalReasons() / warningReasons()**：`Sources/NetworkCore/HealthGrader.swift:290-338` 移除（仅被 summary 调用，改造后 summary 返回空串，成为死代码）
- [ ] **DiagnosticEngine 3 处 message 改空串**：`Sources/NetworkCore/DiagnosticEngine.swift` 第 58 行（`.pathChanged`）、第 78 行（`.checkStarted`）、第 169 行（`.checkFinished`）message 改为 `""`，arguments 保持不变
- [ ] **displayName 改造**：`Sources/NetworkCore/Models.swift` 多处——`NetworkStatus.displayName`（8-17）、`InterfaceKind.displayName`（27-40）、`LinkState.displayName`（48-57）、`ProbeStatus.displayName`（297-308）、`TimelineEventKind.displayName`（538-551）、`HealthGrade.displayName`（427-438）改为 `return rawValue` 或移除（需逐一排查调用方；若仅被已移除的中文 message 使用可移除，否则改为 `return rawValue`）
- [ ] 验证：`swift build` NetworkCore 编译通过（App 层此步会报错，属预期，1.3 修复）；`grep -n '[\x{4e00}-\x{9fff}]' Sources/NetworkCore/HealthGrader.swift` 零命中或仅注释；`grep -n '[\x{4e00}-\x{9fff}]' Sources/NetworkCore/DiagnosticEngine.swift` 零命中或仅注释
- [ ] 不改项：`HealthGrader.grade()` / `score()` 逻辑不变；`TimelineEvent.arguments` 不变；`HealthGrade` 枚举不变

### 1.3 改造 App 层消除中文 switch 匹配（T3）

- [ ] **localizedVerdict 改造**：`Sources/NetworkConsoleApp/AppModel.swift:396-425` 入参类型 `String` → `VerdictCode`，12 个 `case "中文":` switch 改为直接 `text(verdict.l10nKey)`（`verdictText` 计算属性第 111-119 行无需改动，自动匹配新签名；第 116 行 `return text("verdict.notChecked")` 保持不变）
- [ ] **localizedAdvice 改造**（AG 建议二）：`Sources/NetworkConsoleApp/AppModel.swift:472-512` 9 对 `case "中文", "English":` switch 改为直接通过 `advice.code` 获取 `text(advice.code.titleKey)` / `text(advice.code.messageKey)` 填充 title/message（保留 title/message 字段，UI 视图零改动）
- [ ] **displayReport 简化 verdict 透传**（AG 建议三）：`Sources/NetworkConsoleApp/AppModel.swift:392` 改为 `verdict: report.verdict`（直接透传 VerdictCode，本地化职责归于视图层）
- [ ] **CyberDiagnosisCardView verdict 联动**（AG 建议三）：`Sources/NetworkConsoleApp/CyberDiagnosisCardView.swift:71` 将 `Text(report.verdict.isEmpty ? text("card.verdict.normal") : report.verdict)` 改为 `Text(text(report.verdict.l10nKey))`（VerdictCode 无 isEmpty 属性，需联动修改避免编译中断）
- [ ] **NetworkCoreTests 中文断言改枚举断言**：`Tests/NetworkCoreTests/NetworkCoreTests.swift` 第 172 行 `XCTAssertEqual(verdict, "全链路畅通 · 状态极佳")` → `XCTAssertEqual(verdict, .optimal)`；第 225 行 `XCTAssertEqual(verdict, "丢包抖动（部分端点探测失败）")` → `XCTAssertEqual(verdict, .jitterLoss)`；第 251-253 行 advice.title 中文匹配 → 按 `advice.code` 匹配（`.checkDNS` / `.checkRoute` / `.unreachable`）
- [ ] 验证：`swift build` 全量编译通过；`grep -n 'case ".*[\x{4e00}-\x{9fff}]' Sources/NetworkConsoleApp/AppModel.swift` 零命中；`swift test --filter NetworkCoreTests` 全绿（断言已同步改为枚举）
- [ ] 不改项：`localizedSummary`（已按 HealthGrade 枚举映射，不依赖中文）；`localizedTimelineMessage`（已有按 kind+arguments 重建逻辑，message 改空串后自动生效）；`localizedProbe`（属阶段三范围）；`QuickCheckView.swift` / `DetailView.swift`（因 DiagnosticAdvice 保留 title/message 字段，UI 视图零改动）

---

## 2. 日语本地化补齐与兜底链修正（H1 第一批）

> 对应 implementation.md 第四章（T4）。
> 顺序约束：2.1（补 key）必须先于 2.2（改兜底链）完成，且同一提交（否则改兜底链后 ja 用户立即看到英文回退）。
> 预期效果：ja 字典 248 key 全覆盖；兜底链修正为 dict → en → key，非中文用户不再回退中文。

### 2.1 补齐 ja 字典 84 个 key

- [ ] 在 `Sources/NetworkConsoleApp/Localization.swift` ja 字典（约第 607 行起）新增 84 个 key-value 对，value 为日语翻译。84 key 清单（已由工具核实，按模块分组）：
  - `verdict.*`（13 key）：`verdict.checking`/`verdict.optimal`/`verdict.good`/`verdict.dnsSlow`/`verdict.constrained`/`verdict.jitterLoss`/`verdict.highLatency`/`verdict.warningDefault`/`verdict.offline`/`verdict.noInterface`/`verdict.allProbesFailed`/`verdict.criticalDefault`/`verdict.notChecked`
  - `advice.*.title` + `advice.*.message`（18 key）：9 种 advice 的标题与消息
  - `settings.privacy.*`（8 key）：`title`/`subtitle`/`item1~item4` 的 `title`+`desc`
  - `settings.engine.*`/`settings.auto.*`/`settings.timeout.*`/`settings.endpoints.*`/`settings.ecosystem.*`/`settings.presenterdeck.*`（14 key）
  - `dnsRoute.dns.*`/`dnsRoute.route.*`（19 key）
  - `interfaces.telemetry.*`/`interfaces.copied`（8 key）
  - `quick.bento.*`（4 key）
  - `reachability.chart.*`（2 key）
  - `timeline.filter.*`/`timeline.filterEmpty.*`（6 key）
  - `detail.copyCard`（1 key）
- [ ] 日语翻译需符合表达习惯，技术术语保持一致性（如「ネットワーク」「DNS」「ルーティング」等）；可借助机器翻译初稿 + 人工校对
- [ ] 验证：`python3 -c "import re; ..."`（见 implementation.md §4.4 脚本）统计 ja key 数量，期望 `ja key count: 248`
- [ ] 不改项：zh/en 字典不变（248 key 基线不漂移）；ko/de/fr/es/pt 字典不变（阶段三补齐）；L10n key 不增删（ja 补齐是新增 ja 字典 key，非 zh/en key）

### 2.2 修正兜底链移除 zh 回退

- [ ] **兜底链修正**：`Sources/NetworkConsoleApp/Localization.swift:102` 将 `return dict[key] ?? en[key] ?? zh[key] ?? key` 改为 `return dict[key] ?? en[key] ?? key`（移除 zh 兜底，所有语言最终兜底一律为 en）
- [ ] 验证：`grep -n "zh\[key\]" Sources/NetworkConsoleApp/Localization.swift` 零命中；`swift build` 通过
- [ ] 影响分析：改后非中文语言在 key 缺失时回退英文而非中文。ja 已补齐 84 key（248 全覆盖），不受影响；ko/de/fr/es/pt 仍缺 117 key，改后将回退英文（而非中文）——符合 PRD §8.1 需求 3

---

## 3. 品牌统一 NetDoctor（M1）

> 对应 implementation.md 第五章（T5）。
> 可与任务 2 并行（改动文件不重叠），但为降低合并冲突风险建议串行。
> 预期效果：代码层品牌残留彻底净化，存储目录与 UserDefaults key 安全迁移。

### 3.1 代码层品牌位点统一（8 处）

- [ ] `Sources/NetworkCore/ReachabilityProber.swift:85`：`"NetworkConsoleLite/1.0"` → `"NetDoctor/1.2"`（User-Agent；L6 决策：本阶段硬编码，版本号来源统一留待阶段三从 App 层注入）
- [ ] `Sources/NetworkCore/SupportPackageExporter.swift:114`：`"NetworkConsoleLite-Support-"` → `"NetDoctor-Support-"`（支持包文件名前缀）
- [ ] `Sources/NetworkConsoleApp/NetworkConsoleApp.swift:5`：`struct NetworkConsoleLiteApp` → `struct NetDoctorApp`（不影响 Bundle ID，Bundle ID 由 project.yml / Info.plist 决定）
- [ ] `Sources/NetworkCore/SystemCollectors.swift:140,165`：`"NetworkConsoleLite"` → `"NetDoctor"`（SCDynamicStore name，两处）
- [ ] `Package.swift:5`：`name: "NetworkConsoleLite"` → `name: "NetDoctor"`（不影响 xcodegen，xcodegen 引用 target name 而非 package name）
- [ ] 验证：`grep -rn "NetworkConsoleLite\|networkConsoleLite" Sources/ Package.swift` 零命中（代码层品牌残留检查）；`swift build` 通过
- [ ] 不改项：Bundle ID / Apple ID / SKU / Team ID / 上架显示名 / `project.yml` 中 target name（保持 `NetworkConsoleApp`）/ entitlements / Info.plist / xcconfig

### 3.2 存储目录与 UserDefaults key 迁移逻辑

- [ ] **TimelineStore 存储目录改 NetDoctor + 迁移逻辑**：`Sources/NetworkCore/TimelineStore.swift:54-58` 目录名 `NetworkConsoleLite` → `NetDoctor`；新增 `migrateLegacyDirectoryIfNeeded()` 静态方法，在 `TimelineStore.init` 的 `load()` 之前调用
- [ ] **TimelineStore 二级文件粒度迁移保护**（AG 建议四）：迁移逻辑实现——旧目录不存在 → return；新目录不存在 → 整目录搬迁 `try? fm.moveItem(at: oldDir, to: newDir)`；新目录已存在但无 `timeline.jsonl` → 单独搬迁旧 `timeline.jsonl`（避免旧数据永久抛弃）；迁移失败用 `try?` 不阻断启动；迁移后旧目录不自动删除（留给用户）
- [ ] **AppSettings UserDefaults key 改 + 迁移**：`Sources/NetworkConsoleApp/AppSettings.swift:22,32` key `"networkConsoleLite.settings"` → `"netdoctor.settings"`；新增 `migrateLegacySettingsIfNeeded()`（旧 key 有值 + 新 key 无值 → 迁移；不删旧 key，降级兼容），在 `AppSettings.load()` 首行调用
- [ ] **AppModel language key 改 + 迁移**：`Sources/NetworkConsoleApp/AppModel.swift:211,568` key `"networkConsoleLite.language"` → `"netdoctor.language"`；新增 `migrateLegacyLanguageIfNeeded()`（复用 AppSettings 模式），在 `loadLanguage()` 首行调用
- [ ] 验证：`grep -rn "NetDoctor\|netdoctor" Sources/ Package.swift` 多处命中；`swift build` 通过
- [ ] 不改项：`AppModel.swift:343` 中 `appName: "NetDoctor"`（已是 NetDoctor）；`CyberDiagnosisCardView.swift:120` 中 `"NetDoctor v\(appVersion)..."`（已是 NetDoctor）

---

## 4. App 层测试 target 建立（H4）

> 对应 implementation.md 第六章（T6）。
> 依赖：必须在任务 1~3 全部完成后执行（测试断言基于最终代码状态）。
> 预期效果：App 层逻辑测试覆盖建立，L10n 兜底链 / VerdictCode 映射 / 品牌一致性 / 迁移逻辑均有回归保护。

### 4.1 注册 NetworkConsoleAppTests target

- [ ] `Package.swift:34-37`（在现有 `NetworkCoreTests` testTarget 之后）追加 `.testTarget(name: "NetworkConsoleAppTests", dependencies: ["NetworkConsoleApp", "NetworkCore"])`
- [ ] 创建测试目录 `Tests/NetworkConsoleAppTests/`
- [ ] 验证：`swift build` 通过（target 注册成功）

### 4.2 编写本地化映射与兜底链测试

- [ ] **AppModelLocalizationTests.swift**：测试 `localizedVerdict` 每种 `VerdictCode`（12 case）映射到正确 L10n key（zh/en/ja 三语言均有对应文案）；`localizedAdvice` 每种 `AdviceCode`（除 `.unknown`，9 case）的 titleKey/messageKey 均有文案
- [ ] **L10nFallbackTests.swift**：
  - key 存在于 dict → 返回 dict 值
  - key 不存在于 dict 但存在于 en → 返回 en 值
  - key 不存在于 dict 和 en → 返回 key 本身
  - **不回退 zh**（关键断言：非中文语言 key 缺失 → 回退 en，不回退 zh；需选取 en 与 zh value 不同的 key 作为探针）
  - ja 全覆盖：ja 字典所有 key 在 en 中均存在（无孤儿 key）
- [ ] 验证：`swift test --filter NetworkConsoleAppTests` 全绿

### 4.3 编写品牌一致性与迁移测试

- [ ] **BrandConsistencyTests.swift**：验证支持包文件名前缀为 `NetDoctor-Support-`（不含 `NetworkConsoleLite`）；`TimelineStore.defaultFileURL()` 路径含 `NetDoctor`（不含 `NetworkConsoleLite`）；AppSettings 读写使用 `netdoctor.settings` 而非 `networkConsoleLite.settings`
- [ ] **MigrationTests.swift**（可选）：存储目录迁移测试（旧目录存在 → 迁移；新目录已存在 → 不迁移；迁移失败 → 不崩溃）；UserDefaults key 迁移测试（旧 key 有值 + 新 key 无值 → 迁移；不删旧 key）
- [ ] **测试约束**（AG 建议五）：无真实网络依赖（mock 注入）；**不实例化 AppKit/SwiftUI 视图层**（`NetworkConsoleApp` 为 `.executableTarget`，基于 `@main` 实现，实例化视图层会因主运行循环缺失引发偶发断言）；仅测无状态纯逻辑与模型层；无文件系统真实写入（使用临时目录或 mock）
- [ ] 验证：`swift test --filter NetworkConsoleAppTests` 全绿；`swift test` 全绿（NetworkCoreTests + NetworkConsoleAppTests）

---

## 5. 全量验证与红线核对（T7 收口检查）

> 对应 implementation.md 第七章（T7）。
> 逐项执行以下检查，全部通过后进入任务 6。

### 5.1 编译与测试验证

- [ ] 执行 `swift build && swift test`，期望：Build complete + 全量测试通过（NetworkCoreTests + NetworkConsoleAppTests）

### 5.2 H3 中文残留检查

- [ ] 执行 `grep -n 'case ".*[\x{4e00}-\x{9fff}]' Sources/NetworkConsoleApp/AppModel.swift`，期望：零命中（App 层中文 switch 匹配消除）
- [ ] 执行 `grep -n '[\x{4e00}-\x{9fff}]' Sources/NetworkCore/HealthGrader.swift`，期望：零命中或仅注释
- [ ] 执行 `grep -n '[\x{4e00}-\x{9fff}]' Sources/NetworkCore/DiagnosticEngine.swift`，期望：零命中或仅注释

### 5.3 H1 L10n 基线与兜底链验证

- [ ] 执行 ja key 数量统计脚本（见 implementation.md §4.4），期望：`ja key count: 248`
- [ ] 执行 `grep -n "zh\[key\]" Sources/NetworkConsoleApp/Localization.swift`，期望：零命中（兜底链已移除 zh 回退）

### 5.4 M1 品牌残留检查

- [ ] 执行 `grep -rn "NetworkConsoleLite\|networkConsoleLite" Sources/ Package.swift`，期望：零命中（代码层品牌残留彻底净化）
- [ ] 执行 `xcodegen generate 2>&1 | tail -1`，期望：无 diff 输出（工程无漂移）

### 5.5 红线核对

- [ ] 执行 `grep -n "com.networkconsole.lite" Config/ project.yml`，期望：Bundle ID 不变
- [ ] 执行 `grep -n "6801707344" docs/appstore-checklist.md`，期望：Apple ID 不变
- [ ] 执行 `grep -n "networkconsole-lite-0001" docs/appstore-checklist.md`，期望：SKU 不变
- [ ] 确认 entitlements 未新增（绝无 WiFi 信息权限）；确认支持包 SchemaVersion 维持 1；确认 L10n zh/en 248 基线不漂移

---

## 6. 提交与文档同步（T8）

> 对应 implementation.md 第八章（T8）。
> 按改动语义分 4 个提交（便于回溯），完成后推送 `origin/main`。

### 6.1 分事务提交

- [ ] **提交 1**：`refactor(core): introduce VerdictCode and AdviceCode enums for language-neutral diagnostics`（包含任务 1.1 + 1.2，涉及 `Models.swift` / `HealthGrader.swift` / `DiagnosticEngine.swift` / `NetworkCoreTests.swift`）
- [ ] **提交 2**：`refactor(app): eliminate Chinese switch matching in AppModel via typed verdict/advice codes`（包含任务 1.3，涉及 `AppModel.swift` / `CyberDiagnosisCardView.swift`）
- [ ] **提交 3**：`fix(l10n): complete ja dictionary (84 keys) and correct fallback chain to en-only`（包含任务 2，涉及 `Localization.swift`）
- [ ] **提交 4**：`chore(brand): unify brand to NetDoctor and add NetworkConsoleAppTests target`（包含任务 3 + 4，涉及 `ReachabilityProber.swift` / `SupportPackageExporter.swift` / `TimelineStore.swift` / `AppSettings.swift` / `AppModel.swift` / `NetworkConsoleApp.swift` / `SystemCollectors.swift` / `Package.swift` / `Tests/NetworkConsoleAppTests/*`）
- [ ] 推送 `origin/main`
- [ ] 验证：`git log --oneline -5` 核对提交信息与文件集合

### 6.2 文档状态同步

- [ ] 更新 `docs/implementation-plan.md` M6.2 四项勾选为 `[x]`（H3 诊断文案类型化重构 / H3 测试去文案耦合 / H4 新增 NetworkConsoleAppTests target / M1&L6 品牌统一 NetDoctor / H1 第一批 ja 补齐 + 兜底链修正 / H1 L10n 完整性框架与测试）
- [ ] 更新 `docs/appstore-checklist.md`「阶段二：架构加固与品牌规范」勾选状态
- [ ] 验证：文档状态与代码实现一致

---

## 预计工作量与风险提示

| 任务组 | 预计耗时 | 说明 |
|--------|---------|------|
| 1（H3 类型化） | 约 120 min | 1.1 新增枚举 15 min + 1.2 NetworkCore 改造 60 min + 1.3 App 层改造 45 min |
| 2（H1 ja+兜底链） | 约 90 min | ja 84 key 翻译为核心工作量 + 兜底链 1 行改 |
| 3（M1 品牌） | 约 45 min | 8 处品牌位点 + 2 处迁移逻辑 |
| 4（H4 测试） | 约 60 min | Package.swift + 4 个测试文件编写 |
| 5（验证） | 约 15 min | 全量验证脚本执行 |
| 6（提交） | 约 15 min | 4 个提交 + 文档同步 |
| **合计** | **约 5.5 小时** | H3 类型化改造 + ja 翻译为核心工作量 |

**关键风险与缓解**：

1. **Codable 破坏性变更**（DiagnosisReport.verdict: String → VerdictCode）→ 自定义 `init(from decoder:)` 容错旧支持包（中文 verdict → nil → `.checking`）；`schemaVersion` 维持 1（TC5）；`DiagnosticAdvice` 保留 title/message（AG 建议二），旧 JSON 向后兼容
2. **H3 改造涉及 NetworkCore 公开接口变更** → 需同步改 `NetworkCoreTests` 3 处中文断言为枚举断言（任务 1.3 已纳入）
3. **CyberDiagnosisCardView 编译中断** → `report.verdict.isEmpty` 在 VerdictCode 类型化后无 `isEmpty` 属性（AG 建议三），任务 1.3 联动修改为 `text(report.verdict.l10nKey)`
4. **存储目录迁移失败** → 不阻断启动（`try?`）；二级文件粒度保护（AG 建议四）
5. **UserDefaults key 迁移后旧 key 拆留** → 不删除旧 key（降级兼容），仅在旧 key 有值且新 key 无值时迁移（一次性）
6. **ja 翻译质量** → 84 key 日语翻译需人工审读；可借助机器翻译初稿 + 人工校对
7. **Package.swift package name 变更** → 确认不影响 xcodegen `project.yml` 引用（xcodegen 引用 target name 而非 package name）；`swift build` 验证
8. **displayName 移移除后其他调用方断裂** → 任务 1.2 需逐一排查 displayName 调用方；若有其他调用方，改为 `return rawValue` 而非直接移除
9. **误触碰上架标识** → 全部任务不含 Bundle ID / Apple ID / SKU / Team ID / entitlements / Info.plist 改动，任务 5.5 红线核对