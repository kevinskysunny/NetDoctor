# 阶段二「v1.2 架构加固与品牌规范」实现方案（implementation.md）

> 配套文档：`docs/design/stage2-v1.2-architecture/design.md`（需求规格设计）、`tasks.md`（任务清单）。
> 本文档在 design.md / tasks.md 基础上进一步细化至可执行级别：每个任务的实现步骤、代码改动位置与片段、验证方式、依赖顺序。
> 决策基线：commit `23f0396`（阶段一结项）；`swift build` ✅ / `swift test` ✅（16 例全绿）。
> 行号验证：本文档所有行号均已通过读取实际源码核实，与 design.md / tasks.md 一致。

---

## 〇、概述

### 0.1 任务依赖图与执行顺序

```
T1 (H3-a 新增枚举类型)
 └─→ T2 (H3-b 改造 HealthGrader/DiagnosticEngine/Models)
      └─→ T3 (H3-c 改造 AppModel/CyberDiagnosisCardView)
           └─→ T4 (H1 ja 84 key + 兜底链)   ← 可与 T3 并行，但建议 T3 后执行（T3 改 Localization 风险隔离）
                └─→ T5 (M1 品牌统一)          ← 可与 T4 并行
                     └─→ T6 (H4 新增测试 target)  ← 依赖 T1~T5 全部完成（测试断言基于最终代码）
                          └─→ T7 (全量验证)
                               └─→ T8 (提交)
```

**严格顺序约束**：
- T1 → T2 → T3：类型引入 → NetworkCore 改造 → App 层消费，编译依赖链不可乱序。
- T4 内部：先补 ja 84 key 再改兜底链（同一提交），否则改兜底链后 ja 用户立即看到英文回退。
- T6 必须在 T1~T5 全部完成后执行（测试断言基于最终代码状态）。

**可并行项**：T4（Localization.swift）与 T5（品牌位点）改动文件不重叠，理论可并行；但为降低合并冲突风险，建议串行。

### 0.2 红线约束（不可触碰）

| 红线项 | 当前值 | 本阶段处理 |
|--------|--------|-----------|
| Bundle ID | `com.networkconsole.lite` | 不触碰 |
| Apple ID | `6801707344` | 不触碰 |
| SKU | `networkconsole-lite-0001` | 不触碰 |
| Team ID | `J84LGFK7GY` | 不触碰 |
| 上架显示名 | `NetDoctor: Network Diagnostics` | 不触碰（仅 App Store Connect 后台可改） |
| entitlements | 现有最小集 | 不新增（绝无 WiFi 信息权限） |
| L10n key 基线 | zh/en=248 | 不增删（ja 补齐是新增 ja 字典 key，非 zh/en） |
| 支持包 SchemaVersion | 1 | 维持 1（TC5 决议） |
| 数据收集类别 | 现有集 | 不新增（PRD §8.7） |

### 0.3 行号验证结论

已逐一读取源码核实，关键结论：
- `HealthGrader.verdict()` 位于 `HealthGrader.swift:112-161`，返回 `String`，**12 种**中文返回值（确认 12 case，非 11）。
- `HealthGrader.advice()` 位于 `HealthGrader.swift:185-288`，**9 种** advice，每条用 `DiagnosticAdvice(title:message:severity:)` 构造。
- `AppModel.localizedTimelineMessage()` 位于 `AppModel.swift:526-561`，**已有按 kind + arguments 重建本地化 message 的完整逻辑**——T2 中"App 层按 kind+arguments 重建"工作量比预期小，仅需确保 NetworkCore message 改空串后 fallback 安全。
- `NetworkCoreTests.swift` 中文断言位于第 172、225、251-253 行（共 3 处需改为枚举断言）。
- `CyberDiagnosisCardView.swift:71` 确认使用 `report.verdict.isEmpty`（VerdictCode 类型化后会编译中断，需联动修改）。

---

## 一、T1 [H3-a] 新增 VerdictCode / AdviceCode 枚举

### 1.1 实现步骤

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 在 `Sources/NetworkCore/Models.swift` 末尾追加 `VerdictCode` 枚举 | 12 case，语言中立 rawValue |
| 2 | 在 `Sources/NetworkCore/Models.swift` 追加 `AdviceCode` 枚举 | 10 case（9 种 advice + `.unknown` 解码兜底） |
| 3 | `swift build` 验证编译通过 | 新类型仅定义，尚无引用 |

### 1.2 代码改动位置与片段

**位置**：`Sources/NetworkCore/Models.swift`（末尾追加，第 585 行之后）

**新增 VerdictCode 枚举**：

```swift
public enum VerdictCode: String, Codable, Sendable, CaseIterable {
    case checking
    case optimal          // 全链路畅通 · 状态极佳
    case good             // 连接稳定 · 运行正常
    case dnsSlow          // 解析异常
    case constrained      // 带宽受限
    case jitterLoss       // 丢包抖动
    case highLatency      // 延迟偏高
    case warningDefault   // 局部异常
    case offline          // 链路中断
    case noInterface      // 物理断开
    case allProbesFailed  // 出口受阻
    case criticalDefault  // 严重异常

    public var l10nKey: String {
        "verdict.\(rawValue)"
    }
}
```

> **注（AG 建议一）**：`Localization.swift` 中有 13 个 `verdict.*` key，其中 `verdict.notChecked` 为 **AppModel 专属 UI 兜底状态**（`AppModel.swift:116` 在 `report == nil` 时直接消费），不由 NetworkCore `verdict()` 生成，不纳入 `VerdictCode` 枚举；13 key 映射体系自洽。

**新增 AdviceCode 枚举**：

```swift
public enum AdviceCode: String, Codable, Sendable, CaseIterable {
    case confirmConnection
    case enableInterface
    case checkDNS
    case checkRoute
    case constrained
    case unreachable
    case partialUnreachable
    case highLatency
    case healthy
    case unknown          // 解码兜底（旧 JSON 无 code 字段时回退）

    public var titleKey: String {
        "advice.\(rawValue).title"
    }

    public var messageKey: String {
        "advice.\(rawValue).message"
    }
}
```

### 1.3 不改项

- `HealthGrade` 枚举（`Models.swift:421-452`）保持不变，作为 VerdictCode 的设计范本。
- 现有所有类型定义不变，仅追加两个新枚举。

### 1.4 验证方式

```bash
swift build   # 期望：Build complete，无 warning
grep -n "VerdictCode\|AdviceCode" Sources/NetworkCore/Models.swift  # 期望：两个枚举定义存在
```

---

## 二、T2 [H3-b] 改造 HealthGrader + DiagnosticEngine + Models

### 2.1 实现步骤

| 步骤 | 操作 | 文件 | 说明 |
|------|------|------|------|
| 1 | `DiagnosisReport.verdict` 类型变更 | `Models.swift:486,501` | `String` → `VerdictCode`，init 默认值 `.checking` |
| 2 | `DiagnosisReport` 自定义解码容错 | `Models.swift` | 旧 JSON 中文 verdict → nil → `.checking` 兜底 |
| 3 | `DiagnosticAdvice` 新增 code 字段 | `Models.swift:454-471` | 保留 title/message（AG 建议二），新增 `code: AdviceCode` |
| 4 | `DiagnosticAdvice` 自定义解码容错 | `Models.swift` | 旧 JSON 无 code → `.unknown`，有 title/message → 保留 |
| 5 | `HealthGrader.verdict()` 返回类型变更 | `HealthGrader.swift:112-161` | `String` → `VerdictCode`，12 处 `return "中文"` → `return .enumCase` |
| 6 | `HealthGrader.advice()` 改用 code 构造 | `HealthGrader.swift:185-288` | 9 处改为 `DiagnosticAdvice(code:severity:)`，title/message 默认空串 |
| 7 | `HealthGrader.summary()` 返回空串 | `HealthGrader.swift:163-183` | App 层 `localizedSummary` 已按 HealthGrade 重建 |
| 8 | 移除 `criticalReasons` / `warningReasons` | `HealthGrader.swift:290-338` | 仅被 summary 调用，改造后 summary 返回空串 |
| 9 | `DiagnosticEngine` 3 处 message 改空串 | `DiagnosticEngine.swift:58,78,169` | arguments 保持不变 |
| 10 | displayName 改造 | `Models.swift` 多处 | TimelineEventKind/NetworkStatus/InterfaceKind/LinkState/ProbeStatus 的 displayName 改为 `rawValue` 或移除 |
| 11 | `swift build` 验证 | — | 编译通过（此步尚不涉及 App 层，App 层会在 T3 报错，属预期） |

### 2.2 代码改动位置与片段

#### 2.2.1 `Models.swift` — DiagnosisReport.verdict 类型变更

**位置**：`Sources/NetworkCore/Models.swift:486`（属性声明）与 `:501`（init 参数）

```swift
// 改造前（第 486 行）
public let verdict: String

// 改造后
public let verdict: VerdictCode
```

```swift
// 改造前（第 501 行）
verdict: String = ""

// 改造后
verdict: VerdictCode = .checking
```

**自定义解码容错**（在 `DiagnosisReport` 结构体内追加）：

```swift
public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    timestamp = try container.decode(Date.self, forKey: .timestamp)
    path = try container.decode(NetworkPathInfo.self, forKey: .path)
    interfaces = try container.decode([InterfaceInfo].self, forKey: .interfaces)
    dns = try container.decode(DNSSummary.self, forKey: .dns)
    routes = try container.decode(RouteSummary.self, forKey: .routes)
    reachability = try container.decode([ReachabilityProbe].self, forKey: .reachability)
    latency = try container.decode([LatencySample].self, forKey: .latency)
    advice = try container.decode([DiagnosticAdvice].self, forKey: .advice)
    health = try container.decode(HealthGrade.self, forKey: .health)
    summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
    score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 100
    // 容错旧 JSON：中文 verdict → VerdictCode(rawValue:) nil → .checking 兜底
    let rawVerdict = try container.decode(String.self, forKey: .verdict)
    verdict = VerdictCode(rawValue: rawVerdict) ?? .checking
}
```

> **Codable 兼容性**：`VerdictCode` 为 `String` rawValue，新 JSON 存储枚举名（如 `"optimal"`）；旧 JSON 存储中文（如 `"全链路畅通 · 状态极佳"`），解码时 `VerdictCode(rawValue:)` 返回 nil → 兜底 `.checking`。支持包 `schemaVersion` 维持 1（TC5 决策）。

#### 2.2.2 `Models.swift` — DiagnosticAdvice 结构变更

**位置**：`Sources/NetworkCore/Models.swift:454-471`

```swift
// 改造后（保留 title/message，新增 code —— AG 建议二）
public struct DiagnosticAdvice: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let code: AdviceCode        // 新增
    public let title: String           // 保留（避免 UI 层编译中断）
    public let message: String         // 保留
    public let severity: HealthGrade

    public init(
        id: UUID = UUID(),
        code: AdviceCode,
        title: String = "",
        message: String = "",
        severity: HealthGrade
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.message = message
        self.severity = severity
    }

    // 自定义解码容错旧 JSON（无 code 字段 → .unknown，有 title/message → 保留原值）
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let rawCode = try container.decodeIfPresent(String.self, forKey: .code) ?? AdviceCode.unknown.rawValue
        code = AdviceCode(rawValue: rawCode) ?? .unknown
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        severity = try container.decode(HealthGrade.self, forKey: .severity)
    }
}
```

> **向后兼容**：旧 JSON（有 title/message 无 code）解码 → code=`.unknown`，title/message 保留原值，100% 向后兼容。UI 视图（`QuickCheckView.swift:128,130` / `DetailView.swift:264,266`）直接读 `advice.title`/`advice.message`，零改动。

#### 2.2.3 `HealthGrader.swift` — verdict() 返回 VerdictCode

**位置**：`Sources/NetworkCore/HealthGrader.swift:112-161`

```swift
// 改造前（第 120 行）
) -> String {
    switch grade {
    case .checking:
        return "链路探测中（网络诊断中…）"
    case .critical:
        if path.status != .available {
            return "链路中断（网络已彻底断开）"
        }
        // ... 12 处中文 return
    }
}

// 改造后
) -> VerdictCode {
    switch grade {
    case .checking:
        return .checking
    case .critical:
        if path.status != .available {
            return .offline
        }
        let active = interfaces.filter { $0.isActive && $0.kind != .loopback }
        if active.isEmpty {
            return .noInterface
        }
        if !reachability.isEmpty && reachability.filter({ $0.status == .success }).isEmpty {
            return .allProbesFailed
        }
        return .criticalDefault
    case .warning:
        if dns.servers.isEmpty || !path.supportsDNS {
            return .dnsSlow
        }
        if path.isConstrained {
            return .constrained
        }
        if !reachability.isEmpty {
            let successCount = reachability.filter { $0.status == .success }.count
            if successCount < reachability.count {
                return .jitterLoss
            }
            let samples = reachability.compactMap(\.durationMilliseconds)
            if let p90 = LatencyPercentiles(samples: samples).p90, p90 > 500 {
                return .highLatency
            }
        }
        return .warningDefault
    case .healthy:
        if score >= 95 {
            return .optimal
        } else {
            return .good
        }
    }
}
```

**中文 → 枚举 case 对应表**：

| 原中文返回值 | VerdictCode case | l10nKey |
|-------------|-----------------|---------|
| 链路探测中（网络诊断中…） | `.checking` | `verdict.checking` |
| 链路中断（网络已彻底断开） | `.offline` | `verdict.offline` |
| 物理断开（无活动网络接口） | `.noInterface` | `verdict.noInterface` |
| 出口受阻（公网全线探测失败） | `.allProbesFailed` | `verdict.allProbesFailed` |
| 严重异常（网络服务中断） | `.criticalDefault` | `verdict.criticalDefault` |
| 解析异常（DNS响应超时或未配置） | `.dnsSlow` | `verdict.dnsSlow` |
| 带宽受限（低数据模式或策略受限） | `.constrained` | `verdict.constrained` |
| 丢包抖动（部分端点探测失败） | `.jitterLoss` | `verdict.jitterLoss` |
| 延迟偏高（响应时间较长） | `.highLatency` | `verdict.highLatency` |
| 局部异常（需关注网络配置） | `.warningDefault` | `verdict.warningDefault` |
| 全链路畅通 · 状态极佳 | `.optimal` | `verdict.optimal` |
| 连接稳定 · 运行正常 | `.good` | `verdict.good` |

#### 2.2.4 `HealthGrader.swift` — advice() 改用 code 构造

**位置**：`Sources/NetworkCore/HealthGrader.swift:185-288`

9 处 `DiagnosticAdvice(title:message:severity:)` 改为 `DiagnosticAdvice(code:severity:)`，title/message 默认空串。示例（第 195-201 行）：

```swift
// 改造前
result.append(
    DiagnosticAdvice(
        title: "确认网络已连接",
        message: "先检查菜单栏 Wi-Fi 图标或网线连接。若已连接，可尝试关闭再打开 Wi-Fi，或切换到手机热点确认是否为本机网络问题。",
        severity: .critical
    )
)

// 改造后
result.append(
    DiagnosticAdvice(
        code: .confirmConnection,
        severity: .critical
    )
)
```

**9 种 advice → AdviceCode case 对应表**：

| 原中文 title | AdviceCode case | titleKey / messageKey |
|-------------|----------------|----------------------|
| 确认网络已连接 | `.confirmConnection` | `advice.confirmConnection.title` / `.message` |
| 启用网络接口 | `.enableInterface` | `advice.enableInterface.title` / `.message` |
| 检查 DNS 设置 | `.checkDNS` | `advice.checkDNS.title` / `.message` |
| 检查默认路由或 VPN | `.checkRoute` | `advice.checkRoute.title` / `.message` |
| 网络处于受限状态 | `.constrained` | `advice.constrained.title` / `.message` |
| 外网不可达 | `.unreachable` | `advice.unreachable.title` / `.message` |
| 部分外网站点不可达 | `.partialUnreachable` | `advice.partialUnreachable.title` / `.message` |
| 延迟偏高 | `.highLatency` | `advice.highLatency.title` / `.message` |
| 网络状态正常 | `.healthy` | `advice.healthy.title` / `.message` |

#### 2.2.5 `HealthGrader.swift` — summary() 返回空串 + 移除 reasons

**位置**：`Sources/NetworkCore/HealthGrader.swift:163-183`（summary）与 `:290-338`（criticalReasons/warningReasons）

```swift
// 改造后（summary 返回空串，App 层 localizedSummary 已按 HealthGrade 重建）
public func summary(
    grade: HealthGrade,
    path: NetworkPathInfo,
    interfaces: [InterfaceInfo],
    dns: DNSSummary,
    routes: RouteSummary,
    reachability: [ReachabilityProbe]
) -> String {
    ""
}
```

移除 `criticalReasons()`（第 290-310 行）与 `warningReasons()`（第 312-338 行）——仅被 summary 调用，改造后 summary 返回空串，这两个私有方法成为死代码。

#### 2.2.6 `DiagnosticEngine.swift` — 3 处 message 改空串

**位置**：`Sources/NetworkCore/DiagnosticEngine.swift`

| 行号 | 改造前 | 改造后 | kind |
|------|--------|--------|------|
| 58 | `message: "网络路径变化：\(path.status.displayName)"` | `message: ""` | `.pathChanged` |
| 78 | `message: "开始网络诊断（\(endpoints.count) 个端点）"` | `message: ""` | `.checkStarted` |
| 169 | `message: "检查完成：\(grade.displayName)，\(successCount)/\(probes.count) 可达，平均延迟 \(latencyText)"` | `message: ""` | `.checkFinished` |

> **arguments 保持不变**。App 层 `localizedTimelineMessage`（`AppModel.swift:526-561`）已有按 kind + arguments 重建本地化 message 的完整逻辑，message 改空串后 fallback 安全（解析失败时返回空串而非中文）。

#### 2.2.7 `Models.swift` — displayName 改造

**位置**：`Sources/NetworkCore/Models.swift` 多处

| 枚举 | 行号 | 改造方式 |
|------|------|---------|
| `NetworkStatus.displayName` | 8-17 | 改为 `return rawValue`（或移除，需排查调用方） |
| `InterfaceKind.displayName` | 27-40 | 改为 `return rawValue`（Wi-Fi 保留 `"Wi-Fi"` 特例或统一 rawValue） |
| `LinkState.displayName` | 48-57 | 改为 `return rawValue` |
| `ProbeStatus.displayName` | 297-308 | 改为 `return rawValue` |
| `TimelineEventKind.displayName` | 538-551 | 改为 `return rawValue`（App 层 `text(for: TimelineEventKind)` 已有 L10n 映射） |
| `HealthGrade.displayName` | 427-438 | 改为 `return rawValue`（App 层 `text(for: HealthGrade)` 已有 L10n 映射） |

> **排查要点**：displayName 的调用方需逐一排查。H3 改造后 TimelineEvent message 不再插值 displayName，但 displayName 可能被其他地方使用（如 Debug 输出）。若仅被已移除的中文 message 使用，可直接移除；若有其他调用方，改为 `return rawValue` 并由 App 层本地化。

### 2.3 不改项

- `HealthGrader.grade()` / `score()` 逻辑不变。
- `TimelineEvent.arguments` 不变。
- `HealthGrade` 枚举不变（`symbolName` 保留，仅 `displayName` 改造）。
- `DiagnosticEngine` 的 `performCheck` 整体流程不变，仅 3 处 message 字面改空串。

### 2.4 验证方式

```bash
swift build   # 期望：NetworkCore 编译通过（App 层此步会报错，属预期，T3 修复）
# NetworkCore 中文残留检查（排除注释）
grep -n '[\x{4e00}-\x{9fff}]' Sources/NetworkCore/HealthGrader.swift  # 期望：零命中或仅注释
grep -n '[\x{4e00}-\x{9fff}]' Sources/NetworkCore/DiagnosticEngine.swift  # 期望：零命中或仅注释
```
---

## 三、T3 [H3-c] 改造 AppModel + CyberDiagnosisCardView

### 3.1 实现步骤

| 步骤 | 操作 | 文件 | 说明 |
|------|------|------|------|
| 1 | `localizedVerdict` 改为按枚举映射 | `AppModel.swift:396-425` | 入参 `String` → `VerdictCode`，消除 12 个中文 switch |
| 2 | `localizedAdvice` 改为按 code 填充 | `AppModel.swift:472-512` | 消除 9 对中英文 switch，按 `advice.code` 填充 title/message |
| 3 | `displayReport` 简化 verdict 透传 | `AppModel.swift:392` | `verdict: localizedVerdict(report.verdict)` → `verdict: report.verdict`（AG 建议三） |
| 4 | `CyberDiagnosisCardView` verdict 联动 | `CyberDiagnosisCardView.swift:71` | `report.verdict.isEmpty` → `text(report.verdict.l10nKey)`（AG 建议三） |
| 5 | `NetworkCoreTests` 中文断言改枚举断言 | `NetworkCoreTests.swift:172,225,251-253` | 3 处断言同步改为枚举 |
| 6 | `swift build && swift test` 验证 | — | 编译通过 + 测试全绿 |

### 3.2 代码改动位置与片段

#### 3.2.1 `AppModel.swift` — localizedVerdict 改造

**位置**：`Sources/NetworkConsoleApp/AppModel.swift:396-425`

```swift
// 改造前（12 个中文 switch）
func localizedVerdict(_ rawVerdict: String) -> String {
    switch rawVerdict {
    case "全链路畅通 · 状态极佳":
        return text("verdict.optimal")
    case "连接稳定 · 运行正常":
        return text("verdict.good")
    // ... 12 个 case
    default:
        return rawVerdict
    }
}

// 改造后（直接按枚举映射）
func localizedVerdict(_ verdict: VerdictCode) -> String {
    text(verdict.l10nKey)
}
```

> **`verdictText` 计算属性**（`AppModel.swift:111-119`）无需改动——第 118 行 `return localizedVerdict(report.verdict)` 在 `report.verdict` 类型变为 `VerdictCode` 后自动匹配新签名。第 116 行 `return text("verdict.notChecked")` 保持不变（AppModel 专属 UI 兜底，AG 建议一）。

#### 3.2.2 `AppModel.swift` — localizedAdvice 改造

**位置**：`Sources/NetworkConsoleApp/AppModel.swift:472-512`

```swift
// 改造前（9 对中英文 switch）
private func localizedAdvice(_ advice: DiagnosticAdvice) -> DiagnosticAdvice {
    let titleKey: String
    let messageKey: String
    switch advice.title {
    case "确认网络已连接", "Confirm your network connection":
        titleKey = "advice.confirmConnection.title"
        messageKey = "advice.confirmConnection.message"
    // ... 9 对 case
    default:
        return advice
    }
    return DiagnosticAdvice(id: advice.id, title: text(titleKey), message: text(messageKey), severity: advice.severity)
}

// 改造后（按 code 填充 —— AG 建议二：保留 title/message 字段，UI 视图零改动）
private func localizedAdvice(_ advice: DiagnosticAdvice) -> DiagnosticAdvice {
    DiagnosticAdvice(
        id: advice.id,
        code: advice.code,
        title: text(advice.code.titleKey),
        message: text(advice.code.messageKey),
        severity: advice.severity
    )
}
```

> **`.unknown` code 处理**：旧支持包解码出 `code = .unknown` 时，`text("advice.unknown.title")` / `text("advice.unknown.message")` 若 L10n 无此 key 则回退 key 字符串本身。可在 L10n 中补充 `advice.unknown.title`/`advice.unknown.message` 兜底文案，或在 `localizedAdvice` 中对 `.unknown` 特判保留原 title/message。

#### 3.2.3 `AppModel.swift` — displayReport 简化 verdict 透传

**位置**：`Sources/NetworkConsoleApp/AppModel.swift:369-394`（localizedReport 方法），第 392 行

```swift
// 改造前（第 392 行）
verdict: localizedVerdict(report.verdict)

// 改造后（直接透传 VerdictCode，本地化职责归于视图层 —— AG 建议三）
verdict: report.verdict
```

> **影响**：`localizedReport` 返回的 `DiagnosisReport.verdict` 现为 `VerdictCode` 类型（未本地化的枚举）。视图层通过 `text(report.verdict.l10nKey)` 或 `model.verdictText` 获取本地化文本。`verdictText` 计算属性（第 111-119 行）已调用 `localizedVerdict(report.verdict)`，改造后自动匹配新签名。

#### 3.2.4 `CyberDiagnosisCardView.swift` — verdict 联动

**位置**：`Sources/NetworkConsoleApp/CyberDiagnosisCardView.swift:71`

```swift
// 改造前（VerdictCode 无 isEmpty 属性，会编译中断）
Text(report.verdict.isEmpty ? text("card.verdict.normal") : report.verdict)

// 改造后（AG 建议三）
Text(text(report.verdict.l10nKey))
```

> **`CyberDiagnosisCardView` 的 `text` 方法**（第 12-16 行）使用 `L10n.string(key, language: language)`，与 `AppModel.text` 一致，可直接渲染 `verdict.l10nKey`。

#### 3.2.5 `NetworkCoreTests.swift` — 中文断言改枚举断言

**位置**：`Tests/NetworkCoreTests/NetworkCoreTests.swift`，3 处

```swift
// 第 172 行（改造前）
XCTAssertEqual(verdict, "全链路畅通 · 状态极佳")
// 改造后
XCTAssertEqual(verdict, .optimal)

// 第 225 行（改造前）
XCTAssertEqual(verdict, "丢包抖动（部分端点探测失败）")
// 改造后
XCTAssertEqual(verdict, .jitterLoss)

// 第 251-253 行（改造前 —— advice.title 中文匹配）
XCTAssertTrue(advice.contains { $0.title == "检查 DNS 设置" })
XCTAssertTrue(advice.contains { $0.title == "检查默认路由或 VPN" })
XCTAssertTrue(advice.contains { $0.title == "外网不可达" })
// 改造后（按 code 匹配）
XCTAssertTrue(advice.contains { $0.code == .checkDNS })
XCTAssertTrue(advice.contains { $0.code == .checkRoute })
XCTAssertTrue(advice.contains { $0.code == .unreachable })
```

### 3.3 不改项

- `localizedSummary`（`AppModel.swift:427-438`）：已按 `HealthGrade` 枚举映射 L10n，不依赖中文，无需改动。
- `localizedTimelineMessage`（`AppModel.swift:526-561`）：已有按 kind + arguments 重建逻辑，T2 将 message 改空串后自动生效，无需改动。
- `localizedProbe`（`AppModel.swift:440-463`）：按 errorDescription 字符串映射，本轮不改造（属阶段三范围）。
- `localizedResolverSource`（`AppModel.swift:465-470`）：不依赖中文匹配，无需改动。
- `QuickCheckView.swift` / `DetailView.swift`：直接读 `advice.title`/`advice.message`，因 `DiagnosticAdvice` 保留 title/message 字段（AG 建议二），UI 视图零改动。

### 3.4 验证方式

```bash
swift build   # 期望：全量编译通过
# App 层中文 switch 匹配消除
grep -n 'case ".*[\x{4e00}-\x{9fff}]' Sources/NetworkConsoleApp/AppModel.swift  # 期望：零命中
swift test --filter NetworkCoreTests  # 期望：全绿（断言已同步改为枚举）
```

---

## 四、T4 [H1] 补齐 ja 84 key + 修正兜底链

### 4.1 实现步骤

| 步骤 | 操作 | 文件 | 说明 |
|------|------|------|------|
| 1 | 统计 ja 当前 key 数量 | `Localization.swift` | 确认基线 ja=164（缺 84） |
| 2 | 在 ja 字典中新增 84 个 key-value 对 | `Localization.swift` ja 字典 | value 为日语翻译 |
| 3 | 修正兜底链 | `Localization.swift:102` | 移除 zh 兜底 |
| 4 | 统计 ja key 数量验证 | — | 确认 ja=248 |
| 5 | `swift build && swift test` 验证 | — | 编译通过 + 测试全绿 |

> **顺序约束**：步骤 2（补 key）必须在步骤 3（改兜底链）之前完成，且同一提交。否则改兜底链后 ja 用户立即看到英文回退。

### 4.2 代码改动位置与片段

#### 4.2.1 `Localization.swift` — ja 84 key 补齐

**位置**：`Sources/NetworkConsoleApp/Localization.swift` ja 字典（约第 607 行起）

在 ja 字典中新增 84 个 key-value 对。84 key 清单（已由工具核实，按模块分组）：

| 模块 | key 数量 | key 前缀 | 示例 |
|------|---------|---------|------|
| 诊断结论 | 13 | `verdict.*` | `verdict.checking`/`verdict.optimal`/.../`verdict.notChecked` |
| 排查建议 | 18 | `advice.*.title` + `advice.*.message` | 9 种 advice 的标题与消息 |
| 隐私堡垒 | 8 | `settings.privacy.*` | `title`/`subtitle`/`item1~item4` 的 `title`+`desc` |
| 设置页 | 14 | `settings.engine.*`/`settings.auto.*`/`settings.timeout.*`/`settings.endpoints.*`/`settings.ecosystem.*`/`settings.presenterdeck.*` | 引擎/自动刷新/超时/端点/生态/演示 |
| DNS 与路由 | 19 | `dnsRoute.dns.*`/`dnsRoute.route.*` | DNS 服务器/路由条目 |
| 网络接口 | 8 | `interfaces.telemetry.*`/`interfaces.copied` | 接口遥测/复制 |
| 快捷窗口 | 4 | `quick.bento.*` | Bento 指标卡 |
| 连通性图表 | 2 | `reachability.chart.*` | 图表标签 |
| 时间线 | 6 | `timeline.filter.*`/`timeline.filterEmpty.*` | 筛选/空态 |
| 详情页 | 1 | `detail.copyCard` | 复制卡片 |
| **合计** | **84** | | |

**日语翻译示例**（节选，完整 84 key 需逐一翻译）：

```swift
// 在 ja 字典中追加（示例）
"verdict.checking": "リンク確認中（ネットワーク診断中…）",
"verdict.optimal": "全リンク正常 · 状態最高",
"verdict.good": "接続安定 · 正常動作",
"verdict.dnsSlow": "DNS異常（応答遅延または未設定）",
"verdict.constrained": "帯域制限（低データモードまたは制限）",
// ... 其余 80 key
```

> **翻译质量要求**：84 key 日语翻译需人工审读；可借助机器翻译初稿 + 人工校对。翻译需符合日语表达习惯，技术术语保持一致性（如「ネットワーク」「DNS」「ルーティング」等）。

#### 4.2.2 `Localization.swift` — 兜底链修正

**位置**：`Sources/NetworkConsoleApp/Localization.swift:102`

```swift
// 改造前
return dict[key] ?? en[key] ?? zh[key] ?? key

// 改造后（移除 zh 兜底，所有语言最终兜底一律为 en）
return dict[key] ?? en[key] ?? key
```

> **影响分析**：改后非中文语言在 key 缺失时回退英文而非中文。ja 已补齐 84 key（248 全覆盖），不受影响；ko/de/fr/es/pt 仍缺 117 key，改后将回退英文（而非中文）——符合 PRD §8.1 需求 3「非中文用户不得回退中文」。

### 4.3 不改项

- zh/en 字典不变（248 key 基线不漂移）。
- ko/de/fr/es/pt 字典不变（阶段三补齐）。
- `AppLanguage` 枚举不变。
- L10n key 不增删（ja 补齐是新增 ja 字典 key，非 zh/en key）。

### 4.4 验证方式

```bash
# ja key 数量统计（期望 248）
python3 -c "
import re
with open('Sources/NetworkConsoleApp/Localization.swift') as f:
    content = f.read()
# 提取 ja 字典并统计 key 数
ja_section = content.split('private static let ja')[1].split('private static let')[0]
keys = re.findall(r'\"([^\"]+)\":', ja_section)
print(f'ja key count: {len(keys)}')
"   # 期望：ja key count: 248

# 兜底链修正验证
grep -n "zh\[key\]" Sources/NetworkConsoleApp/Localization.swift  # 期望：零命中

swift build   # 期望：通过
```
---

## 五、T5 [M1] 品牌统一 NetDoctor

### 5.1 实现步骤

| 步骤 | 操作 | 文件 | 行号 | 说明 |
|------|------|------|------|------|
| 1 | User-Agent 改 NetDoctor | `ReachabilityProber.swift` | 85 | `"NetworkConsoleLite/1.0"` → `"NetDoctor/1.2"` |
| 2 | 支持包文件名前缀改 NetDoctor | `SupportPackageExporter.swift` | 114 | `"NetworkConsoleLite-Support-"` → `"NetDoctor-Support-"` |
| 3 | 存储目录改 NetDoctor + 迁移逻辑 | `TimelineStore.swift` | 54-58 | 目录名改 + 新增 `migrateLegacyDirectoryIfNeeded()` |
| 4 | AppSettings UserDefaults key 改 + 迁移 | `AppSettings.swift` | 22,32 | key 改 + 新增 `migrateLegacySettingsIfNeeded()` |
| 5 | AppModel UserDefaults key 改 + 迁移 | `AppModel.swift` | 211,568 | language key 改，复用迁移逻辑 |
| 6 | App struct 名改 NetDoctorApp | `NetworkConsoleApp.swift` | 5 | `NetworkConsoleLiteApp` → `NetDoctorApp` |
| 7 | SCDynamicStore name 改 NetDoctor | `SystemCollectors.swift` | 140,165 | `"NetworkConsoleLite"` → `"NetDoctor"` |
| 8 | Package name 改 NetDoctor | `Package.swift` | 5 | `name: "NetworkConsoleLite"` → `name: "NetDoctor"` |
| 9 | `swift build` 验证 | — | — | 编译通过 |

### 5.2 代码改动位置与片段

#### 5.2.1 `ReachabilityProber.swift:85` — User-Agent

```swift
// 改造前
request.setValue("NetworkConsoleLite/1.0", forHTTPHeaderField: "User-Agent")

// 改造后
request.setValue("NetDoctor/1.2", forHTTPHeaderField: "User-Agent")
```

> **L6 决策**：理想方案是从 `Bundle.main` 读取版本号（`CFBundleShortVersionString`），去除硬编码。但 `ReachabilityProber` 位于 NetworkCore（无 AppKit 依赖），`Bundle.main` 在 Swift Package 测试环境下为测试 runner bundle。**本阶段采用硬编码 `"NetDoctor/1.2"`**，版本号来源统一留待阶段三 L6 完整处理（从 App 层注入版本号）。

#### 5.2.2 `SupportPackageExporter.swift:114` — 文件名前缀

```swift
// 改造前
return "NetworkConsoleLite-Support-\(formatter.string(from: now)).json"

// 改造后
return "NetDoctor-Support-\(formatter.string(from: now)).json"
```

#### 5.2.3 `TimelineStore.swift:54-58` — 存储目录 + 迁移逻辑

```swift
// 改造前（第 54-58 行）
public static func defaultFileURL() -> URL? {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    return base?.appendingPathComponent("NetworkConsoleLite", isDirectory: true)
        .appendingPathComponent("timeline.jsonl")
}

// 改造后
public static func defaultFileURL() -> URL? {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    return base?.appendingPathComponent("NetDoctor", isDirectory: true)
        .appendingPathComponent("timeline.jsonl")
}
```

**新增迁移逻辑**（AG 建议四：二级文件粒度迁移保护）——在 `TimelineStore.init` 中调用，或在 `defaultFileURL()` 调用前执行：

```swift
public static func migrateLegacyDirectoryIfNeeded() {
    let fm = FileManager.default
    guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
    let oldDir = appSupport.appendingPathComponent("NetworkConsoleLite")
    let newDir = appSupport.appendingPathComponent("NetDoctor")
    guard fm.fileExists(atPath: oldDir.path) else { return }      // 旧目录不存在 → 不迁移
    if !fm.fileExists(atPath: newDir.path) {
        try? fm.moveItem(at: oldDir, to: newDir)                   // 新目录不存在 → 整目录搬迁
    } else {
        // 新目录已存在 → 二级文件粒度迁移保护（AG 建议四）
        let oldFile = oldDir.appendingPathComponent("timeline.jsonl")
        let newFile = newDir.appendingPathComponent("timeline.jsonl")
        if fm.fileExists(atPath: oldFile.path) && !fm.fileExists(atPath: newFile.path) {
            try? fm.moveItem(at: oldFile, to: newFile)             // 单独搬迁 timeline.jsonl，避免旧数据永久抛弃
        }
    }
}
```

> **迁移安全性**：(a) 旧目录不存在时直接 return；(b) 迁移失败用 `try?` 不阻断启动；(c) 迁移后旧目录不自动删除（留给用户）。在 `TimelineStore.init` 的 `load()` 之前调用 `migrateLegacyDirectoryIfNeeded()`。

#### 5.2.4 `AppSettings.swift:22,32` — UserDefaults key + 迁移

```swift
// 改造前（第 22 行）
let data = UserDefaults.standard.data(forKey: "networkConsoleLite.settings"),
// 改造后
let data = UserDefaults.standard.data(forKey: "netdoctor.settings"),

// 改造前（第 32 行）
UserDefaults.standard.set(data, forKey: "networkConsoleLite.settings")
// 改造后
UserDefaults.standard.set(data, forKey: "netdoctor.settings")
```

**新增迁移逻辑**：

```swift
static func migrateLegacySettingsIfNeeded() {
    let defaults = UserDefaults.standard
    let oldKey = "networkConsoleLite.settings"
    let newKey = "netdoctor.settings"
    if let oldValue = defaults.object(forKey: oldKey), defaults.object(forKey: newKey) == nil {
        defaults.set(oldValue, forKey: newKey)
    }
}
```

> **迁移安全性**：仅在旧 key 有值且新 key 无值时迁移（一次性）；不删除旧 key（降级兼容）。在 `AppSettings.load()` 首行调用 `migrateLegacySettingsIfNeeded()`。

#### 5.2.5 `AppModel.swift:211,568` — language key + 迁移

```swift
// 改造前（第 211 行）
UserDefaults.standard.set(value.rawValue, forKey: "networkConsoleLite.language")
// 改造后
UserDefaults.standard.set(value.rawValue, forKey: "netdoctor.language")

// 改造前（第 568 行）
let stored = UserDefaults.standard.string(forKey: "networkConsoleLite.language")
// 改造后
let stored = UserDefaults.standard.string(forKey: "netdoctor.language")
```

**language key 迁移**（复用 AppSettings 模式）：

```swift
private static func migrateLegacyLanguageIfNeeded() {
    let defaults = UserDefaults.standard
    let oldKey = "networkConsoleLite.language"
    let newKey = "netdoctor.language"
    if let oldValue = defaults.string(forKey: oldKey), defaults.string(forKey: newKey) == nil {
        defaults.set(oldValue, forKey: newKey)
    }
}
```

> 在 `loadLanguage()` 首行调用 `migrateLegacyLanguageIfNeeded()`。

#### 5.2.6 `NetworkConsoleApp.swift:5` — struct 名

```swift
// 改造前
struct NetworkConsoleLiteApp: App {

// 改造后
struct NetDoctorApp: App {
```

> **不影响 Bundle ID**：Bundle ID 由 `project.yml` / Info.plist 决定，与 Swift struct 名无关。

#### 5.2.7 `SystemCollectors.swift:140,165` — SCDynamicStore name

```swift
// 改造前（第 140 行 / 第 165 行）
public init(store: SCDynamicStore? = SCDynamicStoreCreate(nil, "NetworkConsoleLite" as CFString, nil, nil)) {

// 改造后
public init(store: SCDynamicStore? = SCDynamicStoreCreate(nil, "NetDoctor" as CFString, nil, nil)) {
```

#### 5.2.8 `Package.swift:5` — package name

```swift
// 改造前（第 5 行）
name: "NetworkConsoleLite",

// 改造后
name: "NetDoctor",
```

> **不影响 xcodegen**：xcodegen `project.yml` 引用 target name（`NetworkCore` / `NetworkConsoleApp`）而非 package name。`swift build` 验证确认无影响。

### 5.3 不改项

- Bundle ID（`com.networkconsole.lite`）/ Apple ID / SKU / Team ID / 上架显示名。
- `project.yml` 中 target name（保持 `NetworkConsoleApp`）。
- entitlements / Info.plist / xcconfig。
- `AppModel.swift:343` 中 `appName: "NetDoctor"`（已是 NetDoctor，无需改）。
- `CyberDiagnosisCardView.swift:120` 中 `"NetDoctor v\(appVersion)..."`（已是 NetDoctor）。

### 5.4 验证方式

```bash
# 品牌残留检查（代码层，排除 docs/ 审计文档）
grep -rn "NetworkConsoleLite\|networkConsoleLite" Sources/ Package.swift  # 期望：零命中
# 品牌统一验证
grep -rn "NetDoctor\|netdoctor" Sources/ Package.swift  # 期望：多处命中
swift build   # 期望：通过
```

---

## 六、T6 [H4] 新增 NetworkConsoleAppTests target + 编写测试

### 6.1 实现步骤

| 步骤 | 操作 | 文件 | 说明 |
|------|------|------|------|
| 1 | Package.swift 新增 testTarget | `Package.swift` | 注册 `NetworkConsoleAppTests` |
| 2 | 创建测试目录 | `Tests/NetworkConsoleAppTests/` | 新建目录 |
| 3 | 编写 AppModelLocalizationTests | `AppModelLocalizationTests.swift` | VerdictCode/AdviceCode 映射测试 |
| 4 | 编写 L10nFallbackTests | `L10nFallbackTests.swift` | 兜底链 + ja 全覆盖测试 |
| 5 | 编写 BrandConsistencyTests | `BrandConsistencyTests.swift` | 品牌一致性测试 |
| 6 | 编写 MigrationTests（可选） | `MigrationTests.swift` | 迁移逻辑测试 |
| 7 | `swift test --filter NetworkConsoleAppTests` 验证 | — | 全绿 |

### 6.2 代码改动位置与片段

#### 6.2.1 `Package.swift` — 新增 testTarget

**位置**：`Package.swift:34-37`（在现有 `NetworkCoreTests` testTarget 之后追加）

```swift
// 改造后（在第 37 行 `)` 之后追加）
.testTarget(
    name: "NetworkConsoleAppTests",
    dependencies: ["NetworkConsoleApp", "NetworkCore"]
),
```

> **依赖说明**：`NetworkConsoleApp` 为 `.executableTarget`，Swift Package 允许 testTarget 依赖 executableTarget（用于 `@testable import`）。但需注意 AG 建议五：**不实例化 AppKit/SwiftUI 视图层**。

#### 6.2.2 `Tests/NetworkConsoleAppTests/L10nFallbackTests.swift`

```swift
import XCTest
@testable import NetworkConsoleApp

final class L10nFallbackTests: XCTestCase {
    func testKeyExistsInDictReturnsDictValue() {
        // zh 字典中 "app.name" = "NetDoctor"
        let result = L10n.string("app.name", language: .chinese)
        XCTAssertEqual(result, "NetDoctor")
    }

    func testKeyMissingInDictButExistsInEnReturnsEnValue() {
        // ko 字典缺 key → 回退 en（非 zh）
        let result = L10n.string("app.name", language: .korean)
        XCTAssertEqual(result, "NetDoctor")  // en 值
    }

    func testKeyMissingInDictAndEnReturnsKeyItself() {
        let result = L10n.string("nonexistent.key.xyz", language: .chinese)
        XCTAssertEqual(result, "nonexistent.key.xyz")
    }

    func testNonChineseLanguageDoesNotFallbackToChinese() {
        // 关键断言：非中文语言 key 缺失 → 回退 en，不回退 zh
        // 取一个 ko 缺失但 en/zh 均有的 key，验证返回 en 值而非 zh 值
        // （需选取 en 与 zh value 不同的 key 作为探针）
    }

    func testJaDictionaryFullCoverage() {
        // ja 字典所有 key 在 en 中均存在（无孤儿 key）
        // 通过反射或正则提取 ja 字典 key 集合，逐一验证 en 中存在
    }
}
```

#### 6.2.3 `Tests/NetworkConsoleAppTests/BrandConsistencyTests.swift`

```swift
import XCTest
@testable import NetworkConsoleApp
@testable import NetworkCore

final class BrandConsistencyTests: XCTestCase {
    func testSupportPackageFilenameUsesNetDoctorPrefix() {
        let exporter = SupportPackageExporter()
        let filename = exporter.suggestedFilename(now: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(filename.hasPrefix("NetDoctor-Support-"))
        XCTAssertFalse(filename.contains("NetworkConsoleLite"))
    }

    func testTimelineStoreDirectoryUsesNetDoctor() {
        let url = TimelineStore.defaultFileURL()
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.path.contains("NetDoctor") == true)
        XCTAssertFalse(url?.path.contains("NetworkConsoleLite") == true)
    }

    func testAppSettingsKeyUsesNetDoctorPrefix() {
        // 验证 AppSettings 读写使用 "netdoctor.settings" 而非 "networkConsoleLite.settings"
        // 通过写入测试值并读取验证
    }
}
```

#### 6.2.4 `Tests/NetworkConsoleAppTests/AppModelLocalizationTests.swift`

```swift
import XCTest
@testable import NetworkConsoleApp
@testable import NetworkCore

final class AppModelLocalizationTests: XCTestCase {
    func testVerdictCodeMapsToCorrectL10nKey() {
        // 验证每种 VerdictCode 的 l10nKey 在所有语言中均有对应文案
        for code in VerdictCode.allCases {
            let key = code.l10nKey
            for lang in [AppLanguage.chinese, .english, .japanese] {
                let value = L10n.string(key, language: lang)
                XCTAssertNotEqual(value, key, "VerdictCode \(code) 缺失 \(lang) 文案")
            }
        }
    }

    func testAdviceCodeMapsToCorrectL10nKey() {
        // 验证每种 AdviceCode（除 .unknown）的 titleKey/messageKey 均有文案
        for code in AdviceCode.allCases where code != .unknown {
            let titleKey = code.titleKey
            let messageKey = code.messageKey
            for lang in [AppLanguage.chinese, .english, .japanese] {
                XCTAssertNotEqual(L10n.string(titleKey, language: lang), titleKey)
                XCTAssertNotEqual(L10n.string(messageKey, language: lang), messageKey)
            }
        }
    }
}
```

### 6.3 测试约束（AG 建议五）

- **无真实网络依赖**（mock 注入）。
- **不实例化 AppKit/SwiftUI 视图层**：`NetworkConsoleApp` 为 `.executableTarget`，基于 `@main` 实现，实例化视图层会因主运行循环缺失引发偶发断言。
- **仅测无状态纯逻辑与模型层**：L10n 兜底链、VerdictCode/AdviceCode 映射、品牌常量、AppSettings 迁移。
- **无文件系统真实写入**：使用临时目录或 mock。

### 6.4 验证方式

```bash
swift test --filter NetworkConsoleAppTests  # 期望：全绿
swift test   # 期望：全绿（NetworkCoreTests + NetworkConsoleAppTests）
```

---

## 七、T7 全量验证（收口检查）

逐项执行以下检查，全部通过后进入 T8：

```bash
# 1) 编译与测试
swift build && swift test

# 2) H3 中文 switch 消除（App 层）
grep -n 'case ".*[\x{4e00}-\x{9fff}]' Sources/NetworkConsoleApp/AppModel.swift  # 期望：零命中

# 3) H3 NetworkCore 中文残留（排除注释）
grep -n '[\x{4e00}-\x{9fff}]' Sources/NetworkCore/HealthGrader.swift   # 期望：零命中或仅注释
grep -n '[\x{4e00}-\x{9fff}]' Sources/NetworkCore/DiagnosticEngine.swift  # 期望：零命中或仅注释

# 4) H1 ja key 基线（期望 248）
python3 -c "
import re
with open('Sources/NetworkConsoleApp/Localization.swift') as f:
    content = f.read()
ja_section = content.split('private static let ja')[1].split('private static let')[0]
keys = re.findall(r'\"([^\"]+)\":', ja_section)
print(f'ja key count: {len(keys)}')
"   # 期望：ja key count: 248

# 5) H1 兜底链修正
grep -n "zh\[key\]" Sources/NetworkConsoleApp/Localization.swift  # 期望：零命中

# 6) M1 品牌残留（代码层）
grep -rn "NetworkConsoleLite\|networkConsoleLite" Sources/ Package.swift  # 期望：零命中

# 7) 工程漂移
xcodegen generate 2>&1 | tail -1   # 期望：无 diff 输出

# 8) 红线核对
grep -n "com.networkconsole.lite" Config/ project.yml  # 期望：Bundle ID 不变
grep -n "6801707344" docs/appstore-checklist.md  # 期望：Apple ID 不变
grep -n "networkconsole-lite-0001" docs/appstore-checklist.md  # 期望：SKU 不变
```

---

## 八、T8 提交与记录

### 8.1 提交流程

建议按改动语义分 4 个提交（便于回溯）：

| 提交序 | 提交信息 | 包含任务 | 涉及文件 |
|--------|---------|---------|---------|
| 1 | `refactor(core): introduce VerdictCode and AdviceCode enums for language-neutral diagnostics` | T1 + T2 | `Models.swift` / `HealthGrader.swift` / `DiagnosticEngine.swift` / `NetworkCoreTests.swift` |
| 2 | `refactor(app): eliminate Chinese switch matching in AppModel via typed verdict/advice codes` | T3 | `AppModel.swift` / `CyberDiagnosisCardView.swift` |
| 3 | `fix(l10n): complete ja dictionary (84 keys) and correct fallback chain to en-only` | T4 | `Localization.swift` |
| 4 | `chore(brand): unify brand to NetDoctor and add NetworkConsoleAppTests target` | T5 + T6 | `ReachabilityProber.swift` / `SupportPackageExporter.swift` / `TimelineStore.swift` / `AppSettings.swift` / `AppModel.swift` / `NetworkConsoleApp.swift` / `SystemCollectors.swift` / `Package.swift` / `Tests/NetworkConsoleAppTests/*` |

完成后推送 `origin/main`。

### 8.2 文档同步

- 更新 `docs/implementation-plan.md` M6.2 四项勾选为 `[x]`。
- 更新 `docs/appstore-checklist.md`「阶段二：架构加固与品牌规范」勾选状态。

### 8.3 验证方式

```bash
git log --oneline -5  # 核对提交信息与文件集合
```

---

## 九、风险与缓解

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| **Codable 破坏性变更**（DiagnosisReport.verdict: String → VerdictCode） | 中 | 自定义 `init(from decoder:)` 容错旧支持包（中文 verdict → nil → `.checking`）；`schemaVersion` 维持 1（TC5）。`DiagnosticAdvice` 保留 title/message（AG 建议二），旧 JSON 向后兼容。 |
| **H3 改造涉及 NetworkCore 公开接口变更** | 中 | 需同步改 `NetworkCoreTests` 3 处中文断言（第 172/225/251-253 行）为枚举断言，T3 步骤 5 已纳入。 |
| **CyberDiagnosisCardView 编译中断** | 中 | `report.verdict.isEmpty` 在 VerdictCode 类型化后无 `isEmpty` 属性（AG 建议三），T3 步骤 4 联动修改为 `text(report.verdict.l10nKey)`。 |
| **存储目录迁移失败** | 低 | 不阻断启动（`try?`）；仅在旧目录存在 + 新目录不存在时迁移；二级文件粒度保护（AG 建议四）。 |
| **UserDefaults key 迁移后旧 key 拆留** | 低 | 不删除旧 key（降级兼容），仅在旧 key 有值且新 key 无值时迁移（一次性）。 |
| **ja 翻译质量** | 低 | 84 key 日语翻译需人工审读；可借助机器翻译初稿 + 人工校对。 |
| **Package.swift package name 变更** | 低 | 确认不影响 xcodegen `project.yml` 引用（xcodegen 引用 target name 而非 package name）；`swift build` 验证。 |
| **displayName 移移除后其他调用方断裂** | 低 | T2 步骤 10 需逐一排查 displayName 调用方；若有其他调用方，改为 `return rawValue` 而非直接移除。 |
| **误触碰上架标识** | 低 | 全部任务不含 Bundle ID / Apple ID / SKU / Team ID / entitlements / Info.plist 改动，T7 红线核对。 |

---

## 十、预计工作量

| 任务 | 预计耗时 | 说明 |
|------|---------|------|
| T1 | 15 min | 新增两个枚举定义 |
| T2 | 60 min | HealthGrader 12+9 处改造 + DiagnosticEngine 3 处 + Models Codable 容错 + displayName 排查 |
| T3 | 45 min | AppModel 2 处 switch 消除 + CyberDiagnosisCardView 联动 + 测试断言改 |
| T4 | 90 min | ja 84 key 翻译（核心工作量）+ 兜底链 1 行改 |
| T5 | 45 min | 8 处品牌位点 + 2 处迁移逻辑 |
| T6 | 60 min | Package.swift + 4 个测试文件编写 |
| T7 | 15 min | 全量验证脚本执行 |
| T8 | 15 min | 4 个提交 + 文档同步 |
| **合计** | **约 5.5 小时** | H3 类型化改造 + ja 翻译为核心工作量 |