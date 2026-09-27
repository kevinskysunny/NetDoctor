# 阶段三「v1.3 持续完善」任务清单（tasks.md）

> 配套方案文档：`docs/design/stage3-v1.3-continuous/design.md`、`docs/design/stage3-v1.3-continuous/implementation.md`
> 需求来源：`docs/implementation-plan.md` M6.3；`docs/PRD.md` §8.1/§8.8/§8.9。
> 约束红线：Bundle ID `com.networkconsole.lite` / Apple ID `6801707344` / SKU `networkconsole-lite-0001` / Team ID `J84LGFK7GY` / 上架显示名 `NetDoctor: Network Diagnostics` **不可触碰**；不新增 entitlements（绝无 WiFi 信息权限）；不新增数据收集类别；支持包 SchemaVersion 维持 1；zh/en/ja 248 key 基线不漂移；不调用 Process/NSTask/Shell；测试无真实网络依赖（mock 注入）；L1 拆分纯重构不改公开接口与行为；L7 CI 不泄露密钥。
> 决策基线：commit `9609826`（阶段二结项）；ko/de/fr/es/pt 各 131 key 缺 117（已重新确认）。
> 执行顺序：T1（H1 补齐）→ T2（L1 拆分）→ T3（L2 简化）→ T4（L5 加固）→ T5（L7 CI）→ T6 验证 → T7 提交。
> 预期效果：8 语言缺口清零；超大文件拆分；私网判断简化；磁盘写序加固；CI 门禁就绪。

---

## 任务总览

| ID | 代号 | 任务 | 风险 | 涉及文件数 | 依赖 | 验证命令 |
|----|------|------|------|-----------|------|---------|
| T1 | H1-2 | 补齐 ko/de/fr/es/pt 各 117 key（585 key-value）+ 测试改造 | 低 | 3 | 无 | Python 脚本统计 + `swift test` |
| T2 | L1 | 拆分 DetailView.swift（1675行→6文件）+ Localization.swift（1529行→9文件） | 中 | 15（新增14+修改1） | T1 | `swift build` + `swift test` + `xcodegen` |
| T3 | L2 | 简化 detectProvider 私网判断（16前缀→范围） | 低 | 1 | T2 | `swift build` + `swift test` |
| T4 | L5 | TimelineStore.append 磁盘写移入锁内 | 低 | 1 | 无（建议串行） | `swift test` |
| T5 | L7 | 新增 GitHub Actions CI + L10n 完整性检查脚本 | 低 | 2~3 | T1~T4 | CI 触发执行 |
| T6 | 验证 | 全量验证（编译/测试/8语言覆盖/拆分/写序/CI/红线） | — | — | T1~T5 | 见 6.1 验证清单 |
| T7 | 提交 | 分事务提交 + 文档状态同步 | 低 | git | T6 | `git log` 核对 |

---

## 1. T1 [H1-2] 补齐 ko/de/fr/es/pt 各 117 key

> 改动文件：`Sources/NetworkConsoleApp/Localization.swift` + `Tests/NetworkConsoleAppTests/L10nFallbackTests.swift` + `Tests/NetworkConsoleAppTests/AppModelLocalizationTests.swift`
> ⚠️ **阻断隐患**：`L10nFallbackTests.swift:21-35` 中 `testNonChineseLanguageDoesNotFallbackToChinese()` 依赖 ko 缺 `verdict.optimal`、`testFallbackChainIsDictEnKey()` 依赖 de 缺 `verdict.offline`；T1 补齐后这两个断言将直接报红，必须同步改造测试。
> 117 key 按前缀分组：`settings.*`(29) + `dnsRoute.*`(26) + `card.*`(16) + `verdict.*`(13) + `interfaces.*`(8) + `timeline.*`(6) + `quick.*`(5) + `pipeline.*`(4) + `time.*`(4) + `reachability.*`(3) + `common.*`/`detail.*`/`gauge.*`(各1) = 117
> 翻译策略：品牌名保持不变（如 `dnsRoute.dns.provider.google` → "Google Public DNS"）；系统路径按各语言 macOS 实际名称翻译（如 ko: 시스템 설정 > 네트워크）；格式占位符（`%d`/`%@`）保留位置与数量；以 en 字典值为翻译基准确保语义一致。
> 不改项：zh/en/ja 字典不变（248 key 基线不漂移）；兜底链不变（已在阶段二修正为 `dict → en → key`）；`L10n.string()` 方法不变；`AppLanguage` 枚举不变。

- [ ] **1.1 补齐 ko（韩语）字典 117 key**：在 `Localization.swift` 的 `private static let ko:` 字典末尾（`]` 之前）追加 117 个 key-value，value 为韩语翻译，使 ko 从 131 key 达 248 key
- [ ] **1.2 补齐 de（德语）字典 117 key**：在 `private static let de:` 字典末尾追加 117 个 key-value，value 为德语翻译，使 de 从 131 key 达 248 key
- [ ] **1.3 补齐 fr（法语）字典 117 key**：在 `private static let fr:` 字典末尾追加 117 个 key-value，value 为法语翻译，使 fr 从 131 key 达 248 key
- [ ] **1.4 补齐 es（西班牙语）字典 117 key**：在 `private static let es:` 字典末尾追加 117 个 key-value，value 为西班牙语翻译，使 es 从 131 key 达 248 key
- [ ] **1.5 补齐 pt（葡萄牙语）字典 117 key**：在 `private static let pt:` 字典末尾追加 117 个 key-value，value 为葡萄牙语翻译，使 pt 从 131 key 达 248 key
- [ ] **1.6 改造 `L10nFallbackTests.swift` 适应 8 语言全覆盖**：将 `testNonChineseLanguageDoesNotFallbackToChinese()`（:21-28）中依赖 ko 缺 `verdict.optimal` 的断言改为用临时未收录 key（如 `"probe.test.untranslated"`）验证兜底链 dict→en→key；将 `testFallbackChainIsDictEnKey()`（:30-35）中依赖 de 缺 `verdict.offline` 的断言同理改造；新增 `testAll8LanguagesHave248Keys()` 遍历 8 语言断言均 248 key
- [ ] **1.7 扩展 `AppModelLocalizationTests.swift` 覆盖 8 语言**：将 `testVerdictCodeMapsToCorrectL10nKeyInAllLanguages()`（:9）和 `testAdviceCodeMapsToCorrectL10nKeyInAllLanguages()`（:20）中的 `[AppLanguage.chinese, .english, .japanese]` 扩展为全部 8 种语言 `[.chinese, .english, .japanese, .korean, .german, .french, .spanish, .portuguese]`
- [ ] **1.8 验证 8 语言 key 数量与编译测试**：执行 Python 统计脚本确认 zh/en/ja/ko/de/fr/es/pt 均 248 key；执行 `swift build` 通过；执行 `swift test --filter NetworkConsoleAppTests` 全绿（含改造后的兜底链/全覆盖/品牌一致性测试）；确认 zh/en/ja 字典内容不变（基线不漂移）

---

## 2. T2 [L1] 拆分 DetailView.swift + Localization.swift（纯重构）

> 依赖：T1 已完成（拆分 Localization 时 ko/de/fr/es/pt 已 248 key，各分文件行数均衡 ~255 行；若先拆分再补 key，补 key 需在 5 个分文件中操作，增加复杂度）
> 约束：纯重构，不改变公开接口与行为；`DetailView` / `DetailTab` / `L10n` / `AppLanguage` 签名不变；不新增/删除任何 L10n key；不改动 `project.yml`（xcodegen 自动包含新文件）；不改动 `Package.swift`。
> 可见性变更：`private struct` → `struct`（internal，同 module 内可见，executable target 不对外暴露）；`private static let` → `static let`（internal）

### 2.1 拆分 DetailView.swift（1675 行 → 6 文件）

> 拆分后文件清单：`DetailView.swift`(~160) + `DetailOverviewView.swift`(~160) + `DetailReachabilityView.swift`(~120) + `DetailInterfacesView.swift`(~345) + `DetailDNSRouteView.swift`(~600) + `DetailTimelineView.swift`(~310)
> import 依赖：`import SwiftUI`（所有 View struct 必需）、`import Charts`（OverviewView/ReachabilityView/TimelineView 使用）、`import NetworkCore`（引用 AppModel/DiagnosisReport 等模型类型）

- [ ] **2.1.1 新建 `DetailOverviewView.swift`**：从 `DetailView.swift` 剪切 `OverviewView`（159-300）+ `MetricLine`（420-436）粘贴到新文件，`private struct` → `struct`，文件头添加 `import SwiftUI` / `import Charts` / `import NetworkCore`（按需），执行 `swift build` 验证编译通过
- [ ] **2.1.2 新建 `DetailReachabilityView.swift`**：剪切 `ReachabilityView`（301-419）粘贴到新文件，`private struct` → `struct`，添加所需 import，执行 `swift build` 验证
- [ ] **2.1.3 新建 `DetailInterfacesView.swift`**：剪切 `InterfacesView`（437-472）+ `InterfaceTelemetryPod`（473-561）+ `InterfaceBladeCard`（562-777）粘贴到新文件，`private struct` → `struct`，添加所需 import，执行 `swift build` 验证
- [ ] **2.1.4 新建 `DetailDNSRouteView.swift`**：剪切 `DNSRouteView`（778-1021）+ `DNSServerCard`（1022-1136，含 `detectProvider`）+ `DefaultRouteHeroCard`（1139-1258）+ `RouteExpresswayCard`（1259-1370）粘贴到新文件，`private struct` → `struct`，添加所需 import；同时将 `detectProvider` 从 `private func` 实例方法改为 `static func detectProvider(_ ip: String) -> (l10nKey: String, icon: String, color: Color)`（internal，返回 l10nKey 而非已本地化文本，调用方用 `model.text(result.l10nKey)` 本地化），便于 T3 纯逻辑单测；执行 `swift build` 验证
- [ ] **2.1.5 新建 `DetailTimelineView.swift`**：剪切 `TimelineView`（1371-1530）+ `TimelineRailwayItem`（1531-1675）粘贴到新文件，`private struct` → `struct`，添加所需 import，执行 `swift build` 验证
- [ ] **2.1.6 保留 `DetailView.swift` 主框架**：仅保留 `DetailTab`（5-25）+ `DetailView`（27-158）+ 文件头 import，删除已迁出的所有 struct，执行 `swift build` 验证

### 2.2 拆分 Localization.swift（1529 行 → 9 文件）

> 拆分后文件清单：`Localization.swift`(~105) + `L10n_zh.swift` / `L10n_en.swift` / `L10n_ja.swift` / `L10n_ko.swift` / `L10n_de.swift` / `L10n_fr.swift` / `L10n_es.swift` / `L10n_pt.swift`（各 ~255）
> 实现方式：字典声明为 `L10n` 的 `static` 属性，分文件用 `extension L10n` 提供

- [ ] **2.2.1 新建 `L10n_zh.swift`**：从 `Localization.swift` 剪切 `zh` 字典（105-355），包裹在 `extension L10n { }` 中，`private static let` → `static let`，执行 `swift build` 验证
- [ ] **2.2.2 新建 `L10n_en.swift`**：同上，剪切 `en` 字典（356-606），执行 `swift build` 验证
- [ ] **2.2.3 新建 `L10n_ja.swift`**：同上，剪切 `ja` 字典（607-858），执行 `swift build` 验证
- [ ] **2.2.4 新建 `L10n_ko.swift`**：同上，剪切 `ko` 字典（859-~1110，T1 已补齐 248 key），执行 `swift build` 验证
- [ ] **2.2.5 新建 `L10n_de.swift`**：同上，剪切 `de` 字典，执行 `swift build` 验证
- [ ] **2.2.6 新建 `L10n_fr.swift`**：同上，剪切 `fr` 字典，执行 `swift build` 验证
- [ ] **2.2.7 新建 `L10n_es.swift`**：同上，剪切 `es` 字典，执行 `swift build` 验证
- [ ] **2.2.8 新建 `L10n_pt.swift`**：同上，剪切 `pt` 字典，执行 `swift build` 验证
- [ ] **2.2.9 保留 `Localization.swift` 主框架**：仅保留 `AppLanguage` enum + `L10n` enum 骨架 + `string()` 方法，删除已迁出的字典，执行 `swift build` 验证

### 2.3 验证拆分结果

- [ ] **2.3.1 验证编译与测试**：执行 `swift build` 通过 + `swift test` 全绿（行为不变）
- [ ] **2.3.2 验证文件行数**：执行 `wc -l Sources/NetworkConsoleApp/DetailView*.swift Sources/NetworkConsoleApp/L10n_*.swift` 检查各文件 < 600 行（DetailView.swift ~160, Localization.swift ~105, 其余各 < 600）
- [ ] **2.3.3 验证 xcodegen 工程无漂移**：执行 `xcodegen generate 2>&1 | tail -1` 无 diff 输出
- [ ] **2.3.4 验证可见性变更**：执行 `grep -n "private struct" Sources/NetworkConsoleApp/Detail*.swift` 零命中；`grep -n "private static let" Sources/NetworkConsoleApp/L10n_*.swift` 零命中

---

## 3. T3 [L2] 简化 detectProvider 私网判断

> 依赖：T2 已完成（`detectProvider` 已从 `DetailView.swift:1120` 迁移至 `DetailDNSRouteView.swift`）
> 改动文件：`Sources/NetworkConsoleApp/DetailDNSRouteView.swift` + `Tests/NetworkConsoleAppTests/DetectProviderTests.swift`（新增）
> 约束：公网 DNS 提供商判断（8.8.8.8 / 8.8.4.4 / 1.1.1.1 / 1.0.0.1 / 223.5.5.5 / 223.6.6.6 / 114.114.114.114 / 114.114.115.115 / 9.9.9.9 / 149.112.112.112 及 IPv6 前缀 `2001:4860:` / `2606:4700:` / `2400:3200:`）不变；`detectProvider` 返回类型 `(name: String, icon: String, color: Color)` 不变；调用方（`DNSServerCard`）不变；`fe80:` 链路本地判断不变。

- [ ] **3.1 提取 `isPrivateIPv4` 辅助方法**：在 `DetailDNSRouteView.swift` 中新增 `private func isPrivateIPv4(_ ip: String) -> Bool`，实现 RFC 1918 私有网段判断：`192.168.` / `10.` 前缀直接返回 true；`172.` 前缀解析二级 octet，`16...31 ~= second` 时返回 true；其余返回 false
- [ ] **3.2 替换 detectProvider 中的 16 个 `starts(with: "172.XX.")`**：将 `ip.starts(with: "172.16.") || ip.starts(with: "172.17.") || ... || ip.starts(with: "172.31.")` 替换为 `isPrivateIPv4(ip)`，保留 `ip.starts(with: "fe80:")` 判断不变
- [ ] **3.3 新增 `DetectProviderTests.swift` 并验证私网判断行为等价性**：新增 `Tests/NetworkConsoleAppTests/DetectProviderTests.swift`，因 T2 已将 `detectProvider` 改为 `static func` 可直接单测（无需实例化 View）；断言公网提供商（8.8.8.8 → google / 1.1.1.1 → cloudflare 等）+ 私网边界（172.15.x → public，172.32.x → public，172.16.0.1 → local，172.31.255.255 → local，192.168.x → local，10.x → local）+ fe80: → local；执行 `swift build` 通过 + `swift test` 全绿

---

## 4. T4 [L5] TimelineStore.append 磁盘写移入锁内

> 依赖：独立（`TimelineStore.swift` 与 DetailView/Localization 无交集，可与 T1~T3 并行，但为降低合并冲突风险建议串行）
> 改动文件：`Sources/NetworkCore/TimelineStore.swift:19-31`
> 约束：`append` 公开签名 `public func append(_ event: TimelineEvent)` 不变；`allEvents(limit:)` / `load()` / `migrateLegacyDirectoryIfNeeded()` / `defaultFileURL()` 不变；`encoder` / `decoder` 不变；`TimelineEvent` 数据模型不变。

- [ ] **4.1 重构 `append` 方法将磁盘写移入锁内**：将 `appendLine` 从 `lock.unlock()` 之后移入锁内，使用 `defer { lock.unlock() }` 确保异常路径释放锁；改造后顺序为 `lock.lock()` → `defer { lock.unlock() }` → `events.append` → trim → `if let fileURL` → 编码 → `appendLine`（锁内）
- [ ] **4.2 验证写序一致性**：执行 `swift build` 通过 + `swift test` 全绿；可选新增并发写序测试 `Tests/NetworkCoreTests/TimelineStoreConcurrencyTests.swift`，使用 `DispatchQueue.concurrentPerform(iterations: 200)` 并发 append 后验证 `allEvents()` 返回顺序与 append 调用顺序一致（arguments 严格递增）

---

## 5. T5 [L7] 新增 GitHub Actions CI + L10n 完整性检查脚本

> 依赖：T1~T4 全部完成（CI 的 L10n 完整性检查断言 8 语言均 248 key，需 T1 已完成；CI 执行 `swift build && swift test`，需 T2~T4 已完成且全绿）
> 约束：不泄露密钥（不引用 `APP_STORE_CONNECT_API_KEY_PATH` / `APP_STORE_CONNECT_API_KEY_ID` / `APP_STORE_CONNECT_API_KEY_ISSUER_ID` 及任何证书/profile/Team ID 相关变量）；仅执行构建/测试，不执行签名/上传；运行环境 `macos-latest`（SwiftPM 需 macOS SDK）。

- [ ] **5.1 新建 `.github/workflows/ci.yml`**：配置 CI 流水线，触发条件为 push 到 main 或 PR 到 main；运行环境 `macos-latest`；步骤为 `actions/checkout@v4` → `sudo xcode-select -s /Applications/Xcode.app || true` → `swift build` → `swift test` → `python3 Scripts/check_l10n_completeness.py`
- [ ] **5.2 新建 `Scripts/check_l10n_completeness.py`**：实现 L10n 完整性检查脚本，统计 8 种语言（zh/en/ja/ko/de/fr/es/pt）各 key 数量，兼容拆分前后（优先查找 `L10n_<lang>.swift` 分文件，回退 `Localization.swift` 单文件），断言均 248，输出缺口/多余 key 报告，退出码 0 通过 / 1 有缺口
- [ ] **5.3 验证密钥安全与本地 CI 模拟**：执行 `grep -rn "API_KEY\|APP_STORE\|J84LGFK7GY\|6801707344" .github/` 零命中；执行 `swift build && swift test && python3 Scripts/check_l10n_completeness.py` 全通过，输出 "✅ 全部 8 语言均 248 key，缺口清零"

---

## 6. T6 全量验证（收口检查）

> 依赖：T1~T5 全部完成

- [ ] **6.1 执行全量验证清单**：逐项执行以下 9 项检查并全部通过：
  1. `swift build && swift test`（编译 + 全量测试通过，NetworkCoreTests + NetworkConsoleAppTests）
  2. `python3 Scripts/check_l10n_completeness.py`（8 语言均 248 key，缺口清零）
  3. `wc -l Sources/NetworkConsoleApp/DetailView*.swift Sources/NetworkConsoleApp/L10n_*.swift`（各拆分文件 < 600 行）
  4. `xcodegen generate 2>&1 | tail -1`（工程无漂移）
  5. `grep -c "starts(with: \"172\." Sources/NetworkConsoleApp/DetailDNSRouteView.swift` = 1 且 `grep -n "isPrivateIPv4" Sources/NetworkConsoleApp/DetailDNSRouteView.swift` 命中（L2 简化完成）
  6. `grep -A2 "public func append" Sources/NetworkCore/TimelineStore.swift | grep "defer"` 命中（L5 写序加固完成）
  7. `grep -rn "API_KEY\|APP_STORE\|J84LGFK7GY\|6801707344" .github/` 零命中（CI 密钥安全）
  8. `python3 Scripts/check_l10n_completeness.py` 通过（L10n 完整性脚本）
  9. 红线核对（见 6.2）
- [ ] **6.2 红线核对**：确认以下标识符与约束不变：
  - `grep -n "com.networkconsole.lite" project.yml`（Bundle ID 不变）
  - `grep -n "6801707344" docs/appstore-checklist.md`（Apple ID 不变）
  - `grep -n "networkconsole-lite-0001" docs/appstore-checklist.md`（SKU 不变）
  - `grep -n "wifi-info" Config/*.entitlements` 零命中（无 WiFi 信息权限，不新增 entitlements）
  - zh/en/ja 字典 248 key 基线不漂移（T1 仅新增 ko/de/fr/es/pt 的 117 key）
  - 支持包 SchemaVersion 维持 1（TC5）
  - 不调用 Process/NSTask/Shell；测试无真实网络依赖

---

## 7. T7 提交与文档同步

> 依赖：T6 全部通过
> 建议按改动语义分 4 个提交（便于回溯），完成后推送 `origin/main`。

- [ ] **7.1 提交 1：H1 第二批（ko/de/fr/es/pt 补齐 585 key + 测试改造）**：`git add Sources/NetworkConsoleApp/Localization.swift Tests/NetworkConsoleAppTests/L10nFallbackTests.swift Tests/NetworkConsoleAppTests/AppModelLocalizationTests.swift` 并提交，message 为 `feat(l10n): complete ko/de/fr/es/pt dictionaries (585 keys) for 8-language full coverage`，body 注明 8 语言均 248 key、zh/en/ja 基线不变、兜底链不变、同步改造 L10nFallbackTests 与 AppModelLocalizationTests 适应全覆盖
- [ ] **7.2 提交 2：L1 拆分（DetailView + Localization）**：`git add` 所有 `DetailView*.swift` 和 `L10n_*.swift` 文件并提交，message 为 `refactor: split DetailView.swift and Localization.swift into modular files`，body 注明纯重构、private → internal、无行为变更
- [ ] **7.3 提交 3：L2 简化 + L5 加固 + detectProvider 单测**：`git add Sources/NetworkConsoleApp/DetailDNSRouteView.swift Sources/NetworkCore/TimelineStore.swift Tests/NetworkConsoleAppTests/DetectProviderTests.swift` 并提交，message 为 `refactor: simplify detectProvider private IP check and move disk write into lock`，body 注明 isPrivateIPv4 辅助方法 + 磁盘写移入锁内 + detectProvider static 化 + 新增 DetectProviderTests
- [ ] **7.4 提交 4：L7 CI**：`git add .github/workflows/ci.yml Scripts/check_l10n_completeness.py` 并提交，message 为 `ci: add GitHub Actions workflow with build, test, and L10n completeness check`，body 注明无密钥引用、无签名/上传
- [ ] **7.5 文档状态同步**：更新 `docs/implementation-plan.md` M6.3 将 `[H1 第二批]` / `[L1]` / `[L2]` / `[L5]` / `[L7]` 5 项 `[ ]` → `[x]`；更新 `docs/appstore-checklist.md`「v1.3 后续自检」勾选状态（若存在该章节）
- [ ] **7.6 推送与核对**：`git push origin main`；执行 `git log --oneline -5` 核对 4 个提交顺序与文件集合；执行 `grep -n "\[x\].*H1 第二批" docs/implementation-plan.md` 等核对文档勾选状态

---

## 预计工作量与风险提示

| 任务 | 预计耗时 | 说明 |
|------|---------|------|
| T1（H1-2 补齐 585 key + 测试改造） | 约 200 min | 5 语言 × 117 key 翻译为核心工作量 + L10nFallbackTests/AppModelLocalizationTests 改造 |
| T2（L1 拆分） | 约 90 min | DetailView 6 文件 + Localization 9 文件，剪切粘贴 + 可见性变更 |
| T3（L2 简化 + 单测） | 约 25 min | 提取 isPrivateIPv4 + 替换 16 个 starts(with:) + 新增 DetectProviderTests |
| T4（L5 加固） | 约 10 min | append 方法重构（磁盘写移入锁内） |
| T5（L7 CI） | 约 30 min | ci.yml + check_l10n_completeness.py |
| T6（验证） | 约 15 min | 全量验证脚本执行 |
| T7（提交） | 约 20 min | 4 个提交 + 文档同步 + 推送 |
| **合计** | **约 6.5 小时** | T1 翻译为核心工作量 |

### 关键风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| L1 拆分后 `private` → `internal` 可见性变更 | 同 module 内不影响公开 API（executable target 不对外暴露）；需确认 xcodegen 包含新文件 | T6 第 4 步验证 `xcodegen generate` 无漂移 |
| L5 磁盘写移入锁内增加锁持有时间 | `append` 调用频率低（诊断事件），单次写入微秒级，可接受 | 若性能问题改用串行 `DispatchQueue` 替代 `NSLock` |
| H1 翻译质量 | 585 key-value 翻译需人工审读 | 机器翻译初稿 + 人工校对；技术术语保持一致；品牌名不翻译 |
| L7 CI 运行环境 | `macos-latest` runner 分钟数有限（GitHub Actions 免费额度） | 关注构建时间；必要时缓存 SwiftPM 依赖 |
| L7 L10n 检查脚本与测试双重维护 | 脚本逻辑需与 `NetworkConsoleAppTests` L10n 测试一致 | 脚本兼容拆分前后文件结构；CI 中脚本与 `swift test` 双重门禁 |
| 误触碰上架标识 | 全部任务不含 Bundle ID / Apple ID / SKU / Team ID / entitlements / Info.plist 改动 | T6 第 9 步红线核对 |
| T2 拆分过程中编译中断 | 剪切粘贴时可能遗漏 import 或可见性变更 | 逐文件编译验证（每新建一个文件后 `swift build`） |
| **T1 补齐 key 后破坏现有单测** | `L10nFallbackTests:21-35` 依赖 ko/de 缺 key 的断言将报红 | T1 同步改造测试（子任务 1.6/1.7），用临时未收录 key 验证兜底链 |
| **detectProvider 改为 static 后调用方需适配** | 返回 l10nKey 而非已本地化文本，调用方需加 `model.text()` | T2 拆分时同步改造调用方；T3 新增 DetectProviderTests 验证 |

### 回滚策略

若任一任务验证失败，可按提交粒度回滚：`git revert HEAD` 或 `git revert <commit-hash>`。T1~T4 为独立改动（不相互依赖编译）可单独回滚；T5（CI）依赖 T1~T4 最终状态，回滚 T1~T4 后需同步回滚 T5。