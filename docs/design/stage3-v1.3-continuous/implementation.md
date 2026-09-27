# 阶段三「v1.3 持续完善」实现方案（implementation.md）

> 配套文档：`design.md`（需求规格设计）、`tasks.md`（任务清单）。
> 需求来源：`docs/PRD.md` §8.1 / §8.8 / §8.9；`docs/implementation-plan.md` M6.3。
> 决策基线：commit `9609826`（阶段二结项）；`main` 分支，`swift build` ✅ / `swift test` ✅ 全绿。
> 本文用途：细化 tasks.md 中 T1~T7 每个任务的**实现步骤、代码改动位置与片段、验证方式、依赖顺序**，形成可执行方案。只产出方案，不开始编码。

## 变更红线（贯穿全部任务）

1. **不可触碰标识符**：Bundle ID `com.networkconsole.lite` / Apple ID `6801707344` / SKU `networkconsole-lite-0001` / Team ID `J84LGFK7GY` / 上架显示名 `NetDoctor: Network Diagnostics`。
2. **不新增 entitlements**（绝无 WiFi 信息权限）；不新增数据收集类别。
3. **L10n 基线不漂移**：zh/en/ja 各 248 key 不增删；阶段三仅新增 ko/de/fr/es/pt 的 117 key。
4. **不调用 Process/NSTask/Shell**；测试无真实网络依赖（mock 注入）。
5. **支持包 SchemaVersion 维持 1**（TC5）。
6. **L1 拆分纯重构**：不改变公开接口与行为；`DetailView` / `DetailTab` / `L10n` / `AppLanguage` 签名不变。
7. **L7 CI 不泄露密钥**：不引用 `APP_STORE_CONNECT_API_KEY_PATH` 等环境变量；仅执行构建/测试。

## 执行顺序与依赖关系

```
T1（H1-2 补齐 585 key）         ← 独立，可最先执行
    ↓
T2（L1 拆分 DetailView + Localization）  ← 依赖 T1 完成（拆分 Localization 时 ko/de/fr/es/pt 已 248 key）
    ↓
T3（L2 简化 detectProvider）    ← 依赖 T2 完成（detectProvider 已迁移至 DetailDNSRouteView.swift）
    ↓
T4（L5 TimelineStore 写序加固） ← 独立，可与 T1~T3 并行，但为降低合并冲突风险建议串行
    ↓
T5（L7 GitHub Actions CI）      ← 依赖 T1~T4 全部完成（CI 需验证最终代码状态）
    ↓
T6（全量验证）                  ← 依赖 T1~T5 全部完成
    ↓
T7（提交与文档同步）            ← 依赖 T6 通过
```

**关键依赖说明**：
- T2 依赖 T1：拆分 Localization.swift 时，ko/de/fr/es/pt 字典已补齐 248 key，拆分后各 `L10n_*.swift` 文件行数均衡（~250 行）。若先拆分再补 key，则补 key 需在 5 个分文件中操作，增加复杂度。
- T3 依赖 T2：`detectProvider` 在 T2 中从 `DetailView.swift:1120` 迁移至 `DetailDNSRouteView.swift`，T3 在新文件中改造。
- T4 独立：`TimelineStore.swift` 与 DetailView/Localization 无交集，可并行，但串行更安全。
- T5 依赖 T1~T4：CI 的 L10n 完整性检查断言 8 语言均 248 key，需 T1 已完成；CI 执行 `swift build && swift test`，需 T2~T4 已完成且全绿。

---

## T1 [H1-2] 补齐 ko/de/fr/es/pt 各 117 key（585 key-value）

> 对应 tasks.md T1；design.md §2.1.3 (1)。
> 风险：低。纯增量内容变更，不触碰代码逻辑。
> 预期效果：ko/de/fr/es/pt 各 248 key，8 语言缺口清零。

### 1.1 改动位置

**改动文件**（3 个）：
1. `Sources/NetworkConsoleApp/Localization.swift` — 5 种语言字典各新增 117 key
2. `Tests/NetworkConsoleAppTests/L10nFallbackTests.swift` — 改造依赖 ko/de 缺 key 的断言
3. `Tests/NetworkConsoleAppTests/AppModelLocalizationTests.swift` — 扩展 VerdictCode/AdviceCode 映射覆盖 8 语言

> ⚠️ **阻断隐患**：`L10nFallbackTests.swift:21-28` 的 `testNonChineseLanguageDoesNotFallbackToChinese()` 中 `XCTAssertEqual(koResult, enValue)` 依赖 ko 缺 `verdict.optimal`；`:30-35` 的 `testFallbackChainIsDictEnKey()` 中 `XCTAssertEqual(deResult, enValue)` 依赖 de 缺 `verdict.offline`。T1 补齐 117 key 后 ko/de 将有 248 key，这两个断言将直接报红。**必须在补齐 key 的同次提交中同步改造测试**。

5 个语言字典的起始行号（当前基线）：
| 字典 | 起始行 | 当前行数 | 补齐后行数 |
|------|--------|---------|-----------|
| `ko` | 859 | 134（131 key） | ~252（248 key） |
| `de` | 993 | 134（131 key） | ~252（248 key） |
| `fr` | 1127 | 134（131 key） | ~252（248 key） |
| `es` | 1261 | 134（131 key） | ~252（248 key） |
| `pt` | 1395 | 134（131 key） | ~252（248 key） |

> 注：行号在编辑过程中会随插入内容位移；实际操作时以 `private static let ko:` / `private static let de:` 等锚点定位。

### 1.2 117 key 完整清单（5 种语言缺口完全相同）

以下 117 key 在 ko/de/fr/es/pt 字典中均缺失，需各新增对应翻译。按前缀分组：

#### settings.*（29 key）
```
settings.attempts.hint
settings.auto.preset15m
settings.auto.preset1h
settings.auto.preset1m
settings.auto.preset5m
settings.auto.subtitle
settings.auto.title
settings.autoRefresh.hint
settings.ecosystem.title
settings.endpoints.title
settings.engine.subtitle
settings.engine.title
settings.presenterdeck.desc
settings.presenterdeck.title
settings.privacy.item1.desc
settings.privacy.item1.title
settings.privacy.item2.desc
settings.privacy.item2.title
settings.privacy.item3.desc
settings.privacy.item3.title
settings.privacy.item4.desc
settings.privacy.item4.title
settings.privacy.subtitle
settings.privacy.title
settings.timeout.hint
settings.timeout.presetBalanced
settings.timeout.presetDeep
settings.timeout.presetSpeedy
settings.timeout.value
```

#### dnsRoute.*（26 key）
```
dnsRoute.dns.domainChips
dnsRoute.dns.noSearchDomains
dnsRoute.dns.primary
dnsRoute.dns.provider.alibaba
dnsRoute.dns.provider.cloudflare
dnsRoute.dns.provider.google
dnsRoute.dns.provider.local
dnsRoute.dns.provider.onedns
dnsRoute.dns.provider.public
dnsRoute.dns.provider.quad9
dnsRoute.dns.secondary
dnsRoute.dns.telemetryDetail
dnsRoute.dns.telemetryTitle
dnsRoute.route.copied
dnsRoute.route.defaultHeroDesc
dnsRoute.route.defaultHeroTitle
dnsRoute.route.destination
dnsRoute.route.egressInterface
dnsRoute.route.filter.all
dnsRoute.route.filter.default
dnsRoute.route.filter.ipv4
dnsRoute.route.filter.ipv6
dnsRoute.route.nextHop
dnsRoute.route.telemetryDetail
dnsRoute.route.telemetryTitle
dnsRoute.routesCount
```

#### card.*（16 key）
```
card.grid.avgLatency
card.grid.dns
card.grid.dns.missing
card.grid.dns.normal
card.grid.dns.notConfigured
card.grid.interfaces
card.grid.interfaces.count
card.grid.interfaces.none
card.grid.path
card.grid.path.constrained
card.grid.path.unconstrained
card.grid.reachability
card.header.badge
card.header.title
card.verdict.normal
card.verdict.title
```

#### verdict.*（13 key）
```
verdict.allProbesFailed
verdict.checking
verdict.constrained
verdict.criticalDefault
verdict.dnsSlow
verdict.good
verdict.highLatency
verdict.jitterLoss
verdict.noInterface
verdict.notChecked
verdict.offline
verdict.optimal
verdict.warningDefault
```

#### interfaces.*（8 key）
```
interfaces.copied
interfaces.telemetry.activeDetail
interfaces.telemetry.activeTitle
interfaces.telemetry.dualReady
interfaces.telemetry.dualStackTitle
interfaces.telemetry.none
interfaces.telemetry.primaryTitle
interfaces.telemetry.singleReady
```

#### timeline.*（6 key）
```
timeline.filter.all
timeline.filter.checks
timeline.filter.exports
timeline.filter.pathChanges
timeline.filterEmpty.message
timeline.filterEmpty.title
```

#### quick.*（5 key）
```
quick.bento.dns
quick.bento.interface
quick.bento.interfaces.count
quick.bento.latency
quick.bento.reachability
```

#### pipeline.*（4 key）
```
pipeline.node.dns
pipeline.node.gateway
pipeline.node.internet
pipeline.node.localMac
```

#### time.*（4 key）
```
time.hoursAgo
time.justNow
time.minutesAgo
time.yesterday
```

#### reachability.*（3 key）
```
reachability.chart.latency
reachability.chart.title
reachability.lossFormat
```

#### common.* / detail.* / gauge.*（各 1 key）
```
common.copyTarget
detail.copyCard
gauge.scoreSuffix
```

**合计：29 + 26 + 16 + 13 + 8 + 6 + 5 + 4 + 4 + 3 + 1 + 1 + 1 = 117 key**

### 1.3 翻译策略

1. **品牌名保持不变**：`dnsRoute.dns.provider.google` → "Google Public DNS"（所有语言相同）；`dnsRoute.dns.provider.cloudflare` → "Cloudflare DNS" 等。技术性 key 的品牌名不翻译。
2. **系统路径引用**：如 `settings.privacy.item1.desc` 中引用"系统设置 > 网络"等 macOS 系统设置路径，按各语言 macOS 实际名称翻译：
   - ko：시스템 설정 > 네트워크
   - de：Systemeinstellungen > Netzwerk
   - fr：Réglages Système > Réseau
   - es：Preferencias del Sistema > Red
   - pt：Ajustes do Sistema > Rede
3. **格式占位符保留**：含 `%d` / `%@` 等占位符的 key（如 `quick.successCount` = "%d/%d 成功"），翻译时保留占位符位置与数量。
4. **翻译质量保证**：可借助机器翻译初稿 + 人工校对；技术术语保持一致性（如 DNS / IP / IPv4 / IPv6 / RTT 等不翻译）。
5. **参考基准**：以 en 字典的英文值为翻译基准，确保语义一致。

### 1.4 改动示例（以 ko 为例，其余 4 种语言同理）

在 `Localization.swift` 的 `ko` 字典末尾（`]` 之前）追加 117 个 key-value：

```swift
private static let ko: [String: String] = [
    // ... 现有 131 key 保持不变 ...
    // ↓↓↓ 新增 117 key ↓↓↓
    "settings.auto.title": "자동 검사",
    "settings.auto.subtitle": "정기적으로 네트워크 상태를 확인합니다.",
    // ... 其余 116 key ...
    "verdict.optimal": "전 구간 정상 · 상태 최적",
    // ...
]
```

### 1.5 不改项

- zh/en/ja 字典不变（248 key 基线不漂移）。
- 兜底链不变（已在阶段二修正为 `dict[key] ?? en[key] ?? key`）。
- `L10n.string()` 方法不变。
- `AppLanguage` 枚举不变。

### 1.6 测试改造方案（阻断隐患修复）

> ⚠️ T1 补齐 key 后将破坏现有单测，必须同步改造。

#### 1.6.1 改造 `L10nFallbackTests.swift`

**问题断言 1**（:21-28 `testNonChineseLanguageDoesNotFallbackToChinese`）：
```swift
// 当前（依赖 ko 缺 verdict.optimal）
let koResult = L10n.string("verdict.optimal", language: .korean)
XCTAssertEqual(koResult, enValue, "ko 缺失 key 应回退 en 而非 zh")  // ← T1 后 ko 有此 key，断言报红
```

**改造后**：用临时未收录 key 验证兜底链，不受 T1 补齐影响：
```swift
func testNonChineseLanguageDoesNotFallbackToChinese() {
    let probeKey = "probe.test.untranslated"  // 真实未收录的临时 key
    let enValue = L10n.string(probeKey, language: .english)
    let zhValue = L10n.string(probeKey, language: .chinese)
    // probeKey 在所有语言 dict 中均缺失 → 回退 en → 回退 key
    XCTAssertEqual(enValue, probeKey, "en 缺失 key 应回退 key 本身")
    XCTAssertEqual(zhValue, probeKey, "zh 缺失 key 应回退 key 本身（不回退中文）")
    let koResult = L10n.string(probeKey, language: .korean)
    XCTAssertEqual(koResult, probeKey, "ko 缺失 key 应回退 key 本身（不回退 zh）")
}

func testFallbackChainIsDictEnKey() {
    let probeKey = "probe.test.untranslated"
    // 验证兜底链：dict 缺失 → en 缺失 → 返回 key 本身
    let result = L10n.string(probeKey, language: .german)
    XCTAssertEqual(result, probeKey, "de 缺失 key 且 en 缺失时返回 key 本身")
}
```

**新增全语言覆盖测试**：
```swift
func testAll8LanguagesHave248Keys() {
    let expectedCount = 248
    for lang in AppLanguage.allCases {
        let dict = L10n.dictionary(for: lang)  // 需暴露字典访问方法或通过反射
        XCTAssertEqual(dict.count, expectedCount, "\(lang.rawValue) 应有 \(expectedCount) key")
    }
}
```

#### 1.6.2 扩展 `AppModelLocalizationTests.swift`

**当前**（:9, :20 仅覆盖 zh/en/ja）：
```swift
for lang in [AppLanguage.chinese, .english, .japanese] { ... }
```

**改造后**（覆盖全部 8 语言）：
```swift
for lang in AppLanguage.allCases { ... }
// 或显式列举：
for lang in [.chinese, .english, .japanese, .korean, .german, .french, .spanish, .portuguese] { ... }
```

### 1.7 验证方式

```bash
# 1) 各语言 key 数量统计（期望均 248）
python3 -c "
import re
with open('Sources/NetworkConsoleApp/Localization.swift') as f:
    content = f.read()
def count_keys(name):
    m = re.search(rf'private static let {name}: \[String: String\] = \[(.*?)\n    \]', content, re.DOTALL)
    return len(re.findall(r'\"[^\"]+\"\s*:', m.group(1))) if m else 0
for lang in ['zh','en','ja','ko','de','fr','es','pt']:
    print(f'{lang}: {count_keys(lang)}')
"
# 期望输出：zh: 248, en: 248, ja: 248, ko: 248, de: 248, fr: 248, es: 248, pt: 248

# 2) 编译通过
swift build

# 3) 测试全绿（含 L10n 完整性测试）
swift test
```

---

## T2 [L1] 拆分 DetailView.swift + Localization.swift（纯重构）

> 对应 tasks.md T2；design.md §2.1.3 (2)(3)。
> 风险：中。涉及 15 个文件（新增 14 + 修改 1），但纯重构不改公开接口与行为。
> 预期效果：DetailView.swift 1675 行 → 6 文件（每文件 < 600 行）；Localization.swift 1529 行 → 9 文件（每文件 < 260 行）。

### 2.1 DetailView.swift 拆分方案（6 文件）

#### 当前结构（1675 行，14 个类型定义）

| 类型 | 访问级别 | 起始行 | 行数 | 拆分目标文件 |
|------|---------|--------|------|-------------|
| `DetailTab`（enum） | internal | 5 | 21 | `DetailView.swift`（保留） |
| `DetailView`（struct） | internal | 27 | 132 | `DetailView.swift`（保留） |
| `OverviewView` | private | 159 | 142 | `DetailOverviewView.swift`（新增） |
| `ReachabilityView` | private | 301 | 119 | `DetailReachabilityView.swift`（新增） |
| `MetricLine` | private | 420 | 17 | `DetailOverviewView.swift`（新增） |
| `InterfacesView` | private | 437 | 36 | `DetailInterfacesView.swift`（新增） |
| `InterfaceTelemetryPod` | private | 473 | 89 | `DetailInterfacesView.swift`（新增） |
| `InterfaceBladeCard` | private | 562 | 216 | `DetailInterfacesView.swift`（新增） |
| `DNSRouteView` | private | 778 | 244 | `DetailDNSRouteView.swift`（新增） |
| `DNSServerCard` | private | 1022 | 115 | `DetailDNSRouteView.swift`（新增，含 `detectProvider`） |
| `DefaultRouteHeroCard` | private | 1139 | 120 | `DetailDNSRouteView.swift`（新增） |
| `RouteExpresswayCard` | private | 1259 | 112 | `DetailDNSRouteView.swift`（新增） |
| `TimelineView` | private | 1371 | 160 | `DetailTimelineView.swift`（新增） |
| `TimelineRailwayItem` | private | 1531 | 145 | `DetailTimelineView.swift`（新增） |

#### 拆分后文件清单

| 文件 | 内容 | 预计行数 |
|------|------|---------|
| `DetailView.swift` | `DetailTab` enum + `DetailView` struct（主框架） | ~160 |
| `DetailOverviewView.swift` | `OverviewView` + `MetricLine` | ~160 |
| `DetailReachabilityView.swift` | `ReachabilityView` | ~120 |
| `DetailInterfacesView.swift` | `InterfacesView` + `InterfaceTelemetryPod` + `InterfaceBladeCard` | ~345 |
| `DetailDNSRouteView.swift` | `DNSRouteView` + `DNSServerCard` + `DefaultRouteHeroCard` + `RouteExpresswayCard`（含 `detectProvider`） | ~600 |
| `DetailTimelineView.swift` | `TimelineView` + `TimelineRailwayItem` | ~310 |

#### 可见性变更策略

Swift 中 `private` 为文件私有。拆分到不同文件后，`DetailView.swift` 中的 `DetailView` 无法引用 `private` 的子 struct。需将子 struct 的 `private` 改为 `internal`（默认级别，同 module 内可见）。

**决策**：将所有 `private struct` 改为 `struct`（即 `internal`，Swift 默认访问级别）。
- **理由**：`NetworkConsoleApp` 是 `.executableTarget`，不对外暴露公开 API；`internal` 仅同 module 内可见，不影响公开接口。
- **影响**：无。同 module 内 `internal` 与 `private` 的唯一区别是跨文件可见性，拆分后正好需要跨文件可见。

**改动示例**：
```swift
// 改造前（DetailView.swift:159）
private struct OverviewView: View {

// 改造后（DetailOverviewView.swift）
struct OverviewView: View {
```

#### 实现步骤

1. **新建 `DetailOverviewView.swift`**：从 `DetailView.swift` 剪切 `OverviewView`（159-300）+ `MetricLine`（420-436），粘贴到新文件；`private struct` → `struct`；文件头添加 `import Charts` / `import NetworkCore` / `import SwiftUI`（按需）。
2. **新建 `DetailReachabilityView.swift`**：剪切 `ReachabilityView`（301-419）；同上处理。
3. **新建 `DetailInterfacesView.swift`**：剪切 `InterfacesView`（437-472）+ `InterfaceTelemetryPod`（473-561）+ `InterfaceBladeCard`（562-777）；同上。
4. **新建 `DetailDNSRouteView.swift`**：剪切 `DNSRouteView`（778-1021）+ `DNSServerCard`（1022-1136，含 `detectProvider`）+ `DefaultRouteHeroCard`（1139-1258）+ `RouteExpresswayCard`（1259-1370）；同上。**同时将 `detectProvider` 从 `private func` 实例方法改为 `static func detectProvider(_ ip: String) -> (l10nKey: String, icon: String, color: Color)`**（internal，返回 l10nKey 而非已本地化文本，调用方 `DNSServerCard` 改用 `let p = Self.detectProvider(ip); model.text(p.l10nKey)` 本地化），便于 T3 纯逻辑单测。
5. **新建 `DetailTimelineView.swift`**：剪切 `TimelineView`（1371-1530）+ `TimelineRailwayItem`（1531-1675）；同上。
6. **保留 `DetailView.swift`**：仅保留 `DetailTab`（5-25）+ `DetailView`（27-158）+ 文件头 import；删除已迁出的所有 struct。
7. **逐文件编译验证**：每新建一个文件后执行 `swift build`，确保编译通过后再处理下一个。

#### import 依赖确认

各子文件需的 import（按实际引用确认）：
- `import SwiftUI`：所有 View struct 必需。
- `import Charts`：`OverviewView` / `ReachabilityView` / `TimelineView` 使用 Charts 框架。
- `import NetworkCore`：引用 `AppModel` / `DiagnosisReport` 等模型类型。

### 2.2 Localization.swift 拆分方案（9 文件）

#### 当前结构（1529 行）

| 内容 | 起始行 | 行数 | 拆分目标文件 |
|------|--------|------|-------------|
| `AppLanguage` enum | 3 | 84 | `Localization.swift`（保留） |
| `L10n` enum 骨架 + `string()` | 87 | 17 | `Localization.swift`（保留） |
| `zh` 字典 | 105 | 251 | `L10n_zh.swift`（新增） |
| `en` 字典 | 356 | 251 | `L10n_en.swift`（新增） |
| `ja` 字典 | 607 | 252 | `L10n_ja.swift`（新增） |
| `ko` 字典 | 859 | ~252（T1 补齐后） | `L10n_ko.swift`（新增） |
| `de` 字典 | ~1111 | ~252（T1 补齐后） | `L10n_de.swift`（新增） |
| `fr` 字典 | ~1363 | ~252（T1 补齐后） | `L10n_fr.swift`（新增） |
| `es` 字典 | ~1615 | ~252（T1 补齐后） | `L10n_es.swift`（新增） |
| `pt` 字典 | ~1867 | ~252（T1 补齐后） | `L10n_pt.swift`（新增） |

> 注：T1 补齐后 Localization.swift 总行数约 2119 行（1529 + 585）；行号以实际为准。

#### 拆分后文件清单

| 文件 | 内容 | 预计行数 |
|------|------|---------|
| `Localization.swift` | `AppLanguage` enum + `L10n` enum 骨架 + `string()` 方法 | ~105 |
| `L10n_zh.swift` | `extension L10n { static let zh: [String: String] = [...] }` | ~255 |
| `L10n_en.swift` | `extension L10n { static let en: [String: String] = [...] }` | ~255 |
| `L10n_ja.swift` | `extension L10n { static let ja: [String: String] = [...] }` | ~255 |
| `L10n_ko.swift` | `extension L10n { static let ko: [String: String] = [...] }` | ~255 |
| `L10n_de.swift` | `extension L10n { static let de: [String: String] = [...] }` | ~255 |
| `L10n_fr.swift` | `extension L10n { static let fr: [String: String] = [...] }` | ~255 |
| `L10n_es.swift` | `extension L10n { static let es: [String: String] = [...] }` | ~255 |
| `L10n_pt.swift` | `extension L10n { static let pt: [String: String] = [...] }` | ~255 |

#### 可见性变更策略

字典声明为 `private static let`，拆分到 `extension L10n` 后，`private` 在 extension 中定义的成员仅在该文件内可见，`Localization.swift` 中的 `string()` 方法无法访问。

**决策**：将字典的 `private static let` 改为 `static let`（即 `internal static`，同 module 内可见）。
- **理由**：同 DetailView 拆分，`internal` 仅同 module 内可见，不影响公开接口。
- **影响**：无。`L10n` enum 本身为 `internal`（无 `public` 前缀），其 `static` 成员默认 `internal`。

**改动示例**：
```swift
// 改造前（Localization.swift:105）
private static let zh: [String: String] = [
    "app.name": "NetDoctor",
    // ...
]

// 改造后（L10n_zh.swift）
extension L10n {
    static let zh: [String: String] = [
        "app.name": "NetDoctor",
        // ...
    ]
}
```

#### 实现步骤

1. **新建 `L10n_zh.swift`**：从 `Localization.swift` 剪切 `zh` 字典（105-355），包裹在 `extension L10n { }` 中，`private static let` → `static let`。
2. **新建 `L10n_en.swift`**：同上，剪切 `en` 字典。
3. **新建 `L10n_ja.swift`**：同上，剪切 `ja` 字典。
4. **新建 `L10n_ko.swift`**：同上，剪切 `ko` 字典（T1 已补齐 248 key）。
5. **新建 `L10n_de.swift`**：同上，剪切 `de` 字典。
6. **新建 `L10n_fr.swift`**：同上，剪切 `fr` 字典。
7. **新建 `L10n_es.swift`**：同上，剪切 `es` 字典。
8. **新建 `L10n_pt.swift`**：同上，剪切 `pt` 字典。
9. **保留 `Localization.swift`**：仅保留 `AppLanguage` enum + `L10n` enum 骨架 + `string()` 方法；删除已迁出的字典。
10. **逐文件编译验证**：每新建一个文件后执行 `swift build`。

### 2.3 xcodegen 工程兼容性

`project.yml` 中 `NetworkConsoleApp` target 的 `sources` 配置为：
```yaml
sources:
  - path: Sources/NetworkConsoleApp
    excludes:
      - Resources
```
xcodegen 以目录路径为源，**自动包含** `Sources/NetworkConsoleApp/` 下所有 `.swift` 文件。新增的 14 个文件无需手动注册，执行 `xcodegen generate` 后自动纳入工程。

**验证**：`xcodegen generate 2>&1 | tail -1` 无 diff 输出（工程无漂移）。

### 2.4 不改项

- `DetailView` / `DetailTab` 公开接口不变。
- `L10n.string()` / `AppLanguage` 公开接口不变。
- 所有行为不变（纯重构）。
- 不新增/删除任何 L10n key（T1 已完成补齐）。
- 不改动 `project.yml`（xcodegen 自动包含新文件）。
- 不改动 `Package.swift`（SwiftPM 自动包含 Sources 目录下所有文件）。
- **`detectProvider` 签名微调**：从 `private func detectProvider(_ ip: String) -> (name: String, icon: String, color: Color)` 改为 `static func detectProvider(_ ip: String) -> (l10nKey: String, icon: String, color: Color)`（返回 l10nKey 而非已本地化文本）。此为 private 方法内部实现变更，非公开接口变更；调用方 `DNSServerCard` 需同步适配（`model.text(result.l10nKey)`）。

### 2.5 验证方式

```bash
# 1) 编译通过
swift build

# 2) 测试全绿（行为不变）
swift test

# 3) 拆分后文件行数（每文件 < 600 行）
wc -l Sources/NetworkConsoleApp/DetailView.swift \
     Sources/NetworkConsoleApp/DetailOverviewView.swift \
     Sources/NetworkConsoleApp/DetailReachabilityView.swift \
     Sources/NetworkConsoleApp/DetailInterfacesView.swift \
     Sources/NetworkConsoleApp/DetailDNSRouteView.swift \
     Sources/NetworkConsoleApp/DetailTimelineView.swift \
     Sources/NetworkConsoleApp/Localization.swift \
     Sources/NetworkConsoleApp/L10n_*.swift
# 期望：DetailView.swift ~160, Localization.swift ~105, 其余各 < 600

# 4) xcodegen 工程无漂移
xcodegen generate 2>&1 | tail -1
# 期望：无 diff 输出

# 5) 可见性变更检查（private struct 已改为 struct）
grep -n "private struct" Sources/NetworkConsoleApp/Detail*.swift
# 期望：零命中（所有子 struct 已改为 internal）

# 6) 字典可见性检查（private static let 已改为 static let）
grep -n "private static let" Sources/NetworkConsoleApp/L10n_*.swift
# 期望：零命中
```
---

## T3 [L2] 简化 detectProvider 私网判断

> 对应 tasks.md T3；design.md §2.1.3 (4)。
> 依赖：T2 已完成（`detectProvider` 已从 `DetailView.swift:1120` 迁移至 `DetailDNSRouteView.swift`）。
> 风险：低。仅改私网判断逻辑，公网判断不变。
> 预期效果：16 个 `starts(with: "172.XX.")` → 前缀 + 二级 octet 范围判断。

### 3.1 改动位置

**文件**（2 个）：
1. `Sources/NetworkConsoleApp/DetailDNSRouteView.swift`（T2 拆分后 `detectProvider` 所在文件，已为 `static func`）
2. `Tests/NetworkConsoleAppTests/DetectProviderTests.swift`（新增，单测 `detectProvider` 纯逻辑）

**当前实现**（原 `DetailView.swift:1120-1135`，拆分后行号变更）：

```swift
private func detectProvider(_ ip: String) -> (name: String, icon: String, color: Color) {
    if ip == "8.8.8.8" || ip == "8.8.4.4" || ip.starts(with: "2001:4860:") {
        return (model.text("dnsRoute.dns.provider.google"), "globe", .blue)
    } else if ip == "1.1.1.1" || ip == "1.0.0.1" || ip.starts(with: "2606:4700:") {
        return (model.text("dnsRoute.dns.provider.cloudflare"), "bolt.shield", .orange)
    } else if ip == "223.5.5.5" || ip == "223.6.6.6" || ip.starts(with: "2400:3200:") {
        return (model.text("dnsRoute.dns.provider.alibaba"), "cloud", .cyan)
    } else if ip == "114.114.114.114" || ip == "114.114.115.115" {
        return (model.text("dnsRoute.dns.provider.onedns"), "network", .purple)
    } else if ip == "9.9.9.9" || ip == "149.112.112.112" {
        return (model.text("dnsRoute.dns.provider.quad9"), "checkmark.shield", .mint)
    } else if ip.starts(with: "192.168.") || ip.starts(with: "10.") || ip.starts(with: "172.16.") || ip.starts(with: "172.17.") || ip.starts(with: "172.18.") || ip.starts(with: "172.19.") || ip.starts(with: "172.20.") || ip.starts(with: "172.21.") || ip.starts(with: "172.22.") || ip.starts(with: "172.23.") || ip.starts(with: "172.24.") || ip.starts(with: "172.25.") || ip.starts(with: "172.26.") || ip.starts(with: "172.27.") || ip.starts(with: "172.28.") || ip.starts(with: "172.29.") || ip.starts(with: "172.30.") || ip.starts(with: "172.31.") || ip.starts(with: "fe80:") {
        return (model.text("dnsRoute.dns.provider.local"), "house.fill", .green)
    }
    return (model.text("dnsRoute.dns.provider.public"), "server.rack", .secondary)
}
```

### 3.2 改造方案

**策略**：提取 `isPrivateIPv4` 辅助方法，将 172.16.~172.31. 的 16 个 `starts(with:)` 合并为前缀 + 二级 octet 范围判断。

**改造后**：

```swift
private func detectProvider(_ ip: String) -> (name: String, icon: String, color: Color) {
    if ip == "8.8.8.8" || ip == "8.8.4.4" || ip.starts(with: "2001:4860:") {
        return (model.text("dnsRoute.dns.provider.google"), "globe", .blue)
    } else if ip == "1.1.1.1" || ip == "1.0.0.1" || ip.starts(with: "2606:4700:") {
        return (model.text("dnsRoute.dns.provider.cloudflare"), "bolt.shield", .orange)
    } else if ip == "223.5.5.5" || ip == "223.6.6.6" || ip.starts(with: "2400:3200:") {
        return (model.text("dnsRoute.dns.provider.alibaba"), "cloud", .cyan)
    } else if ip == "114.114.114.114" || ip == "114.114.115.115" {
        return (model.text("dnsRoute.dns.provider.onedns"), "network", .purple)
    } else if ip == "9.9.9.9" || ip == "149.112.112.112" {
        return (model.text("dnsRoute.dns.provider.quad9"), "checkmark.shield", .mint)
    } else if isPrivateIPv4(ip) || ip.starts(with: "fe80:") {
        return (model.text("dnsRoute.dns.provider.local"), "house.fill", .green)
    }
    return (model.text("dnsRoute.dns.provider.public"), "server.rack", .secondary)
}

/// 判断 IPv4 地址是否属于 RFC 1918 私有网段（10.0.0.0/8、172.16.0.0/12、192.168.0.0/16）
private func isPrivateIPv4(_ ip: String) -> Bool {
    if ip.starts(with: "192.168.") || ip.starts(with: "10.") {
        return true
    }
    if ip.starts(with: "172.") {
        let octets = ip.split(separator: ".")
        if octets.count >= 2, let second = Int(octets[1]), 16...31 ~= second {
            return true
        }
    }
    return false
}
```

### 3.3 行为等价性证明

| 网段 | 改造前判断 | 改造后判断 | 等价 |
|------|-----------|-----------|------|
| 192.168.0.0/16 | `starts(with: "192.168.")` | `isPrivateIPv4`: `starts(with: "192.168.")` → true | ✅ |
| 10.0.0.0/8 | `starts(with: "10.")` | `isPrivateIPv4`: `starts(with: "10.")` → true | ✅ |
| 172.16.0.0/12 | 16 个 `starts(with: "172.16.")` ~ `starts(with: "172.31.")` | `isPrivateIPv4`: `starts(with: "172.")` + `octets[1]` ∈ 16...31 | ✅ |
| fe80::/10（链路本地） | `starts(with: "fe80:")` | `starts(with: "fe80:")`（保持不变） | ✅ |
| 公网 IP | 以上均不匹配 → fallthrough | 以上均不匹配 → fallthrough | ✅ |

**边界验证**：
- `172.15.x.x`：改造前 16 个前缀均不匹配 → 公网；改造后 `octets[1]=15` ∉ 16...31 → false → 公网 ✅
- `172.32.x.x`：改造前不匹配 → 公网；改造后 `octets[1]=32` ∉ 16...31 → false → 公网 ✅
- `172.16.0.1`：改造前匹配 → 私网；改造后 `octets[1]=16` ∈ 16...31 → true → 私网 ✅
- `172.31.255.255`：改造前匹配 → 私网；改造后 `octets[1]=31` ∈ 16...31 → true → 私网 ✅

### 3.4 不改项

- 公网 DNS 提供商判断（8.8.8.8 / 1.1.1.1 / 223.5.5.5 / 114.114.114.114 / 9.9.9.9 及其 IPv6 前缀）不变。
- `detectProvider` 返回类型 `(name: String, icon: String, color: Color)` 不变。
- `detectProvider` 调用方（`DNSServerCard`）不变。
- `fe80:` 链路本地地址判断不变。

### 3.5 验证方式

```bash
# 1) 编译通过
swift build

# 2) 测试全绿
swift test

# 3) 私网判断逻辑验证（新增单元测试，detectProvider 已为 static 可直接单测）
# 在 Tests/NetworkConsoleAppTests/ 新增 DetectProviderTests.swift
# 因 T2 已将 detectProvider 改为 static func，可直接调用 Self.detectProvider(ip) 单测
# 断言公网提供商（8.8.8.8 → google / 1.1.1.1 → cloudflare 等）
# 断言私网边界（172.16~31 为私网，172.15/172.32 为公网，192.168/10 为私网，fe80: 为 local）
```

---

## T4 [L5] TimelineStore.append 磁盘写移入锁内

> 对应 tasks.md T4；design.md §2.1.3 (5)。
> 风险：低。仅改 `append` 内部实现，公开接口不变。
> 预期效果：磁盘 JSONL 写序与内存 `events` 数组一致，多线程并发 `append` 不会导致行序乱序。

### 4.1 改动位置

**文件**：`Sources/NetworkCore/TimelineStore.swift:19-31`

**当前实现**：

```swift
public func append(_ event: TimelineEvent) {
    lock.lock()
    events.append(event)
    if events.count > maximumStoredEvents {
        events.removeFirst(events.count - maximumStoredEvents)
    }
    let line = try? Self.encoder.encode(event)
    lock.unlock()                    // ← 锁在这里释放

    if let line, let fileURL {       // ← 磁盘写在锁外
        Self.appendLine(line, to: fileURL)
    }
}
```

### 4.2 问题分析

线程 A 和 B 同时调用 `append`：
1. A 获锁 → `events.append(A)` → 编码 lineA → 释放锁
2. B 获锁 → `events.append(B)` → 编码 lineB → 释放锁
3. A 执行 `appendLine(lineA)`（锁外，无保护）
4. B 执行 `appendLine(lineB)`（锁外，无保护）

步骤 3 和 4 无锁保护，可能 B 先写入 → JSONL 文件中 lineB 在 lineA 之前，但内存 `events` 中 A 在 B 之前 → **行序不一致**。

### 4.3 改造方案

**策略**：将磁盘写 `appendLine` 移入锁内，使用 `defer { lock.unlock() }` 确保异常路径也释放锁。

**改造后**：

```swift
public func append(_ event: TimelineEvent) {
    lock.lock()
    defer { lock.unlock() }
    events.append(event)
    if events.count > maximumStoredEvents {
        events.removeFirst(events.count - maximumStoredEvents)
    }
    if let fileURL {
        let line = try? Self.encoder.encode(event)
        if let line {
            Self.appendLine(line, to: fileURL)  // ← 磁盘写在锁内
        }
    }
}
```

### 4.4 改造后行为分析

线程 A 和 B 同时调用 `append`：
1. A 获锁 → `events.append(A)` → 编码 lineA → `appendLine(lineA)` → 释放锁
2. B 获锁 → `events.append(B)` → 编码 lineB → `appendLine(lineB)` → 释放锁

磁盘写在锁内，A 的 `appendLine` 先于 B 的 `appendLine` → JSONL 文件中 lineA 在 lineB 之前，与内存 `events` 一致 → **行序一致** ✅

**锁持有时间影响**：改造后锁持有时间增加（含磁盘 I/O）。但 `append` 调用频率低（诊断事件，非高频路径），且 `appendLine` 使用 `FileHandle.seekToEnd()` + `write()`，单次写入耗时微秒级，可接受。

### 4.5 不改项

- `append` 公开签名不变：`public func append(_ event: TimelineEvent)`。
- `allEvents(limit:)` 不变。
- `load()` 不变。
- `migrateLegacyDirectoryIfNeeded()` 不变（阶段二已实现）。
- `defaultFileURL()` 不变。
- `encoder` / `decoder` 不变。
- `TimelineEvent` 数据模型不变。

### 4.6 验证方式

```bash
# 1) 编译通过
swift build

# 2) 测试全绿
swift test

# 3) 并发写序测试（可选：新增单元测试）
# 在 Tests/NetworkCoreTests/ 新增 TimelineStoreConcurrencyTests.swift
# 使用 DispatchQueue.concurrentPerform(iterations: 100) 并发 append
# 验证 allEvents() 返回顺序与 append 调用顺序一致
```

**并发写序测试示例**（可选新增）：

```swift
func testAppendPreservesOrderUnderConcurrency() {
    let store = TimelineStore(fileURL: nil, maximumStoredEvents: 500)
    let count = 200
    DispatchQueue.concurrentPerform(iterations: count) { i in
        store.append(TimelineEvent(
            kind: .checkStarted,
            timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
            message: "",
            arguments: [String(i)]
        ))
    }
    let events = store.allEvents(limit: count)
    let arguments = events.map { $0.arguments.first ?? "" }
    // 验证 arguments 严格递增（行序与时间戳一致）
    for i in 1..<arguments.count {
        XCTAssertLessThan(Int(arguments[i-1])!, Int(arguments[i])!)
    }
}
```

---

## T5 [L7] 新增 GitHub Actions CI + L10n 完整性检查脚本

> 对应 tasks.md T5；design.md §2.1.3 (6)。
> 依赖：T1~T4 全部完成（CI 需验证最终代码状态）。
> 风险：低。纯新增配置文件，不改动现有代码。
> 预期效果：PR/push 到 main 时自动执行 `swift build` + `swift test` + L10n 完整性检查。

### 5.1 改动位置

| 文件 | 操作 | 说明 |
|------|------|------|
| `.github/workflows/ci.yml` | 新建 | GitHub Actions CI 流水线配置 |
| `Scripts/check_l10n_completeness.py` | 新建 | L10n 完整性检查脚本 |

> 注：`.github/` 目录当前不存在，需新建。`Scripts/` 目录已存在（含其他脚本）。

### 5.2 ci.yml 配置内容

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app || true

      - name: Build
        run: swift build

      - name: Test
        run: swift test

      - name: L10n completeness check
        run: python3 Scripts/check_l10n_completeness.py
```

**配置说明**：
- **触发条件**：push 到 main 或创建/更新 PR 到 main。
- **运行环境**：`macos-latest`（SwiftPM 需 macOS SDK；GitHub Actions 免费额度对 macOS runner 有限，需关注构建时间）。
- **步骤**：checkout → 选择 Xcode → build → test → L10n 完整性检查。
- **不执行签名/上传**：CI 仅质量门禁，不触碰 App Store Connect。

### 5.3 check_l10n_completeness.py 脚本内容

```python
#!/usr/bin/env python3
"""L10n 完整性检查脚本。

统计 Localization.swift 中 8 种语言各 key 数量，断言均 248。
若 T2 已完成拆分，则扫描 L10n_*.swift 分文件；否则扫描 Localization.swift 单文件。

退出码：
  0 — 全部通过
  1 — 有语言缺口
"""

import re
import sys
from pathlib import Path

EXPECTED_KEY_COUNT = 248
LANGUAGES = ["zh", "en", "ja", "ko", "de", "fr", "es", "pt"]

# Localization.swift 或拆分后的 L10n_*.swift 所在目录
L10N_DIR = Path("Sources/NetworkConsoleApp")


def extract_keys_from_file(filepath: Path, dict_name: str) -> set:
    """从指定文件中提取指定字典的 key 集合。"""
    content = filepath.read_text(encoding="utf-8")
    # 匹配 static let <dict_name>: [String: String] = [ ... ]
    pattern = rf"static let {dict_name}:\s*\[String:\s*String\]\s*=\s*\[(.*?)\n\s*\]"
    m = re.search(pattern, content, re.DOTALL)
    if not m:
        return set()
    block = m.group(1)
    return set(re.findall(r'"([^"]+)"\s*:', block))


def get_l10n_file(lang: str) -> Path:
    """获取指定语言的字典所在文件（拆分后 L10n_<lang>.swift 或未拆分 Localization.swift）。"""
    split_file = L10N_DIR / f"L10n_{lang}.swift"
    if split_file.exists():
        return split_file
    return L10N_DIR / "Localization.swift"


def main() -> int:
    all_pass = True
    print("=" * 60)
    print("L10n 完整性检查")
    print("=" * 60)

    for lang in LANGUAGES:
        filepath = get_l10n_file(lang)
        keys = extract_keys_from_file(filepath, lang)
        count = len(keys)
        status = "✅" if count == EXPECTED_KEY_COUNT else "❌"
        print(f"  {lang}: {count} key {status}")
        if count != EXPECTED_KEY_COUNT:
            all_pass = False
            # 输出缺口（与 en 对比）
            en_keys = extract_keys_from_file(get_l10n_file("en"), "en")
            missing = en_keys - keys
            extra = keys - en_keys
            if missing:
                print(f"    缺失 {len(missing)} key: {sorted(missing)[:10]}...")
            if extra:
                print(f"    多余 {len(extra)} key: {sorted(extra)[:10]}...")

    print("=" * 60)
    if all_pass:
        print(f"✅ 全部 {len(LANGUAGES)} 语言均 {EXPECTED_KEY_COUNT} key，缺口清零")
        return 0
    else:
        print("❌ 存在语言缺口，请补齐")
        return 1


if __name__ == "__main__":
    sys.exit(main())
```

**脚本说明**：
- 兼容 T2 拆分前后：优先查找 `L10n_<lang>.swift` 分文件，若不存在则回退到 `Localization.swift` 单文件。
- 以 en 字典（248 key）为基准，输出各语言缺口/多余 key。
- 退出码 0 表示全部通过，1 表示有缺口（CI 会因非零退出码失败）。

### 5.4 密钥安全约束

CI 配置**不得**引用以下环境变量：
- `APP_STORE_CONNECT_API_KEY_PATH`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- 任何证书 / profile / Team ID 相关变量

**验证**：`grep -rn "API_KEY\|APP_STORE\|J84LGFK7GY\|6801707344" .github/` 零命中。

### 5.5 不改项

- 不改动任何现有代码文件。
- 不改动 `project.yml` / `Package.swift`。
- 不触碰 Bundle ID / Apple ID / SKU / Team ID / entitlements。

### 5.6 验证方式

```bash
# 1) 密钥安全检查（零命中）
grep -rn "API_KEY\|APP_STORE\|J84LGFK7GY\|6801707344" .github/
# 期望：无输出

# 2) 本地模拟 CI 执行
swift build && swift test && python3 Scripts/check_l10n_completeness.py
# 期望：全部通过，输出 "✅ 全部 8 语言均 248 key，缺口清零"

# 3) CI 触发验证
# push 到 main 或创建 PR 后，在 GitHub Actions 页面确认 CI 通过
# 或使用 act 本地模拟：act -j build-and-test（需安装 act）
```
---

## T6 全量验证（收口检查）

> 对应 tasks.md T6。
> 依赖：T1~T5 全部完成。
> 逐项执行以下检查，全部通过后进入 T7。

### 6.1 验证清单

```bash
echo "=== T6 全量验证 ==="

# 1) 编译与测试
echo "--- 1) swift build && swift test ---"
swift build && swift test
# 期望：Build complete + 全量测试通过（NetworkCoreTests + NetworkConsoleAppTests）

# 2) H1 8 语言全覆盖（期望均 248）
echo "--- 2) L10n 8 语言 key 统计 ---"
python3 Scripts/check_l10n_completeness.py
# 期望：✅ 全部 8 语言均 248 key，缺口清零

# 3) L1 拆分后文件行数（每文件 < 600 行）
echo "--- 3) 拆分后文件行数 ---"
wc -l Sources/NetworkConsoleApp/DetailView.swift \
     Sources/NetworkConsoleApp/DetailOverviewView.swift \
     Sources/NetworkConsoleApp/DetailReachabilityView.swift \
     Sources/NetworkConsoleApp/DetailInterfacesView.swift \
     Sources/NetworkConsoleApp/DetailDNSRouteView.swift \
     Sources/NetworkConsoleApp/DetailTimelineView.swift \
     Sources/NetworkConsoleApp/Localization.swift \
     Sources/NetworkConsoleApp/L10n_*.swift
# 期望：DetailView.swift ~160, Localization.swift ~105, 其余各 < 600

# 4) L1 工程漂移
echo "--- 4) xcodegen 工程漂移 ---"
xcodegen generate 2>&1 | tail -1
# 期望：无 diff 输出

# 5) L2 私网判断简化验证
echo "--- 5) detectProvider 私网判断 ---"
grep -c "starts(with: \"172\." Sources/NetworkConsoleApp/DetailDNSRouteView.swift
# 期望：1（仅 "172." 前缀判断，不再有 172.16.~172.31. 逐条）
grep -n "isPrivateIPv4" Sources/NetworkConsoleApp/DetailDNSRouteView.swift
# 期望：命中（isPrivateIPv4 辅助方法已定义且被调用）

# 6) L5 写序加固验证
echo "--- 6) TimelineStore 写序 ---"
grep -A2 "public func append" Sources/NetworkCore/TimelineStore.swift | grep "defer"
# 期望：命中 defer { lock.unlock() }（磁盘写已在锁内）

# 7) L7 密钥安全
echo "--- 7) CI 密钥安全 ---"
grep -rn "API_KEY\|APP_STORE\|J84LGFK7GY\|6801707344" .github/
# 期望：零命中

# 8) L7 L10n 完整性脚本
echo "--- 8) L10n 完整性脚本 ---"
python3 Scripts/check_l10n_completeness.py
# 期望：8 语言均 248，无缺口

# 9) 红线核对
echo "--- 9) 红线核对 ---"
grep -n "com.networkconsole.lite" project.yml
# 期望：Bundle ID 不变
grep -n "6801707344" docs/appstore-checklist.md
# 期望：Apple ID 不变
grep -n "networkconsole-lite-0001" docs/appstore-checklist.md
# 期望：SKU 不变
grep -n "wifi-info" Config/*.entitlements
# 期望：零命中（无 WiFi 信息权限）

echo "=== T6 验证完成 ==="
```

### 6.2 通过标准

| 检查项 | 通过标准 |
|--------|---------|
| 编译 | `swift build` Build complete，无 warning 增量 |
| 测试 | `swift test` 全绿（NetworkCoreTests + NetworkConsoleAppTests） |
| H1 8 语言 | zh/en/ja/ko/de/fr/es/pt 均 248 key |
| L1 拆分 | 每文件 < 600 行；xcodegen 无漂移 |
| L2 私网判断 | `isPrivateIPv4` 已定义；`starts(with: "172.")` 仅 1 处 |
| L5 写序 | `append` 内 `defer { lock.unlock() }`；磁盘写在锁内 |
| L7 CI | 密钥零命中；L10n 脚本通过 |
| 红线 | Bundle ID / Apple ID / SKU / Team ID / entitlements 不变 |

---

## T7 提交与文档同步

> 对应 tasks.md T7。
> 依赖：T6 全部通过。
> 建议按改动语义分 4 个提交（便于回溯），完成后推送 `origin/main`。

### 7.1 分事务提交

```bash
# 提交 1：H1 第二批（ko/de/fr/es/pt 补齐 585 key + 测试改造）
git add Sources/NetworkConsoleApp/Localization.swift \
        Tests/NetworkConsoleAppTests/L10nFallbackTests.swift \
        Tests/NetworkConsoleAppTests/AppModelLocalizationTests.swift
git commit -m "feat(l10n): complete ko/de/fr/es/pt dictionaries (585 keys) for 8-language full coverage

- Add 117 key-value pairs for each of ko/de/fr/es/pt (585 total)
- All 8 languages now have 248 keys (gap reduced to zero)
- zh/en/ja baselines unchanged (248 keys each)
- Fallback chain unchanged (dict → en → key)
- Refactor L10nFallbackTests: use probe key for fallback chain test, add 8-lang coverage test
- Extend AppModelLocalizationTests: VerdictCode/AdviceCode mapping covers all 8 languages
- Closes M6.3 [H1 第二批]"

# 提交 2：L1 拆分（DetailView + Localization）
git add Sources/NetworkConsoleApp/DetailView.swift \
        Sources/NetworkConsoleApp/DetailOverviewView.swift \
        Sources/NetworkConsoleApp/DetailReachabilityView.swift \
        Sources/NetworkConsoleApp/DetailInterfacesView.swift \
        Sources/NetworkConsoleApp/DetailDNSRouteView.swift \
        Sources/NetworkConsoleApp/DetailTimelineView.swift \
        Sources/NetworkConsoleApp/Localization.swift \
        Sources/NetworkConsoleApp/L10n_zh.swift \
        Sources/NetworkConsoleApp/L10n_en.swift \
        Sources/NetworkConsoleApp/L10n_ja.swift \
        Sources/NetworkConsoleApp/L10n_ko.swift \
        Sources/NetworkConsoleApp/L10n_de.swift \
        Sources/NetworkConsoleApp/L10n_fr.swift \
        Sources/NetworkConsoleApp/L10n_es.swift \
        Sources/NetworkConsoleApp/L10n_pt.swift
git commit -m "refactor: split DetailView.swift and Localization.swift into modular files

- DetailView.swift (1675 lines) → 6 files (DetailView + 5 module files)
- Localization.swift (1529 lines) → 9 files (Localization + 8 L10n_* files)
- Private structs changed to internal (same module visibility, no public API impact)
- Pure refactor: no behavior change, no public interface change
- Closes M6.3 [L1]"

# 提交 3：L2 简化 + L5 加固 + detectProvider 单测
git add Sources/NetworkConsoleApp/DetailDNSRouteView.swift \
        Sources/NetworkCore/TimelineStore.swift \
        Tests/NetworkConsoleAppTests/DetectProviderTests.swift
git commit -m "refactor: simplify detectProvider private IP check and move disk write into lock

- L2: Replace 16 starts(with: \"172.XX.\") with isPrivateIPv4 helper (prefix + octet range)
- L5: Move TimelineStore.append disk write into lock scope for JSONL line order consistency
- Add DetectProviderTests: unit test for static detectProvider (public/private IP boundaries)
- No public interface change
- Closes M6.3 [L2] and [L5]"

# 提交 4：L7 CI
git add .github/workflows/ci.yml Scripts/check_l10n_completeness.py
git commit -m "ci: add GitHub Actions workflow with build, test, and L10n completeness check

- Add .github/workflows/ci.yml (macos-latest, swift build + swift test + L10n check)
- Add Scripts/check_l10n_completeness.py (asserts 8 languages × 248 keys)
- No secrets referenced; no signing/upload steps
- Closes M6.3 [L7]"

# 推送
git push origin main
```

### 7.2 文档状态同步

更新以下文档的勾选状态：

1. **`docs/implementation-plan.md` M6.3**：将以下 4 项 `[ ]` → `[x]`：
   - `[H1 第二批] 补齐 ko/de/fr/es/pt 缺失 key`
   - `[L1] 拆分超大文件`
   - `[L2] 简化 DetailView.detectProvider`
   - `[L5] TimelineStore 写序加固`
   - `[L7] 接入 CI`

2. **`docs/appstore-checklist.md`**：更新「v1.3 后续自检」勾选状态（若存在该章节）。

### 7.3 验证方式

```bash
# 核对提交信息与文件集合
git log --oneline -5
# 期望：4 个提交，按 T7.1 顺序排列

# 核对文档状态
grep -n "\[x\].*H1 第二批" docs/implementation-plan.md
grep -n "\[x\].*L1.*拆分" docs/implementation-plan.md
grep -n "\[x\].*L2.*简化" docs/implementation-plan.md
grep -n "\[x\].*L5.*写序" docs/implementation-plan.md
grep -n "\[x\].*L7.*CI" docs/implementation-plan.md
# 期望：均命中（已勾选）
```

---

## 预计工作量与风险提示

### 工作量估算

| 任务 | 预计耗时 | 说明 |
|------|---------|------|
| T1（H1-2 补齐 585 key + 测试改造） | 约 200 min | 5 语言 × 117 key 翻译 + L10nFallbackTests/AppModelLocalizationTests 改造 |
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
| **L1 拆分后 `private` → `internal` 可见性变更** | 同 module 内不影响公开 API（executable target 不对外暴露）；但需确认 xcodegen 正确包含新文件 | T6 第 4 步验证 `xcodegen generate` 无漂移 |
| **L5 磁盘写移入锁内增加锁持有时间** | `append` 调用频率低（诊断事件），单次写入微秒级，可接受 | 若性能问题可改用串行 `DispatchQueue` 替代 `NSLock` |
| **H1 翻译质量** | 585 key-value 翻译需人工审读 | 机器翻译初稿 + 人工校对；技术术语保持一致；品牌名不翻译 |
| **L7 CI 运行环境** | `macos-latest` runner 分钟数有限（GitHub Actions 免费额度） | 关注构建时间；必要时缓存 SwiftPM 依赖 |
| **L7 L10n 检查脚本与测试双重维护** | 脚本逻辑需与 `NetworkConsoleAppTests` 中的 L10n 测试保持一致 | 脚本兼容拆分前后文件结构；CI 中脚本与 `swift test` 双重门禁 |
| **误触碰上架标识** | 全部任务不含 Bundle ID / Apple ID / SKU / Team ID / entitlements / Info.plist 改动 | T6 第 9 步红线核对 |
| **T2 拆分过程中编译中断** | 剪切粘贴时可能遗漏 import 或可见性变更 | 逐文件编译验证（每新建一个文件后 `swift build`） |
| **T1 补齐 key 后破坏现有单测** | `L10nFallbackTests:21-35` 依赖 ko/de 缺 key 的断言将报红 | T1 同步改造测试（§1.6），用临时未收录 key 验证兜底链 |
| **detectProvider 改为 static 后调用方需适配** | 返回 l10nKey 而非已本地化文本，调用方需加 `model.text()` | T2 拆分时同步改造调用方；T3 新增 DetectProviderTests 验证 |

### 回滚策略

若任一任务验证失败，可按提交粒度回滚：
```bash
# 回滚最近 1 个提交
git revert HEAD

# 回滚到指定提交
git revert <commit-hash>
```

因 T1~T4 为独立改动（不相互依赖编译），可单独回滚任一提交而不影响其他。T5（CI）依赖 T1~T4 的最终状态，回滚 T1~T4 后需同步回滚 T5。