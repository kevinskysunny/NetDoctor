# PRD: 网络接口丰富分类、列表多维筛选与诊断卡片口径统一

> **文档状态**：待评审 / 实施就绪
> **目标版本**：v1.2.2
> **涉及模块**：`NetworkConsoleApp`、`NetworkCore`（保持只读与零公共 API 破坏）
> **红线原则**（严格遵守 AGENTS.md）：只读诊断、无特权 Helper、无子进程、测试零真实网络、8 语言完整对齐。

---

## 1. 背景与用户痛点

1. **接口数量庞大且缺乏辨识度**：
   在现代 Mac（尤其是 Apple Silicon + 外接扩展坞 + 安装代理软件）上，系统底层 `getifaddrs` 会吐出多达 20~30 个网络接口。当前全部非物理接口均被粗暴标记为「其他」，用户面对一屏幕的 `utun0~1024`、`awdl0`、`anpi*`、`bridge0` 无法理解其真实用途，产生严重的认知负担。
2. **缺乏快速定位能力**：
   日常网络排查中，用户 90% 的场景只关心「我的 Wi-Fi 或有线网卡连上了没」；而在排查代理或 VPN 故障时，又只想看「虚拟网卡状态」。当前缺少筛选手段，必须在一长串 28 个卡片中上下翻滚寻找。
3. **诊断卡片与概览页口径冲突（已确认 Bug）**：
   App 概览页已修正为物理优先口径（显示「活动接口：1 个（en0）」），但「复制网络诊断卡片」导出的图片中仍写着「活动网络接口：16 个（en0）」，存在明显的口径割裂与误导。

---

## 2. 核心需求目标

### 需求 A：诊断卡片与轻检活动接口口径统一（Bugfix）
* **涉及文件**：
  - `Sources/NetworkConsoleApp/CyberDiagnosisCardView.swift`
  - `Sources/NetworkConsoleApp/QuickCheckView.swift`
* **改动点**：
  将 `report.interfaces.filter { $0.isActive }.count` 替换为复用 `OverviewActivity.compute(report.interfaces)` 的计算结果：
  - `value`: 格式化展示物理活动网卡计数（如 `1 个`）；
  - `sub`: 展示对应的首选物理网卡名称（如 `en0`）；
  - 若物理活动网卡为 0 但有活跃虚拟网卡（degraded 降级态），展示虚拟活动接口；
  - **验收**：复制出来的图片与概览页 2x2 Bento Box 的活动接口卡片数值、名称 100% 保持一致。

---

### 需求 B：网络接口丰富细化分类（Presentation-Layer Classification）
在不破坏底层 `InterfaceKind` 枚举（保持 `schemaVersion=1` 持久化兼容）的前提下，在表现层引入细化的子类别识别（基于接口名称前缀与特征）：

| 接口特征 | 细分类型（中文） | 英文展示 | 图标 (SF Symbol) | 对应业务场景 |
| :--- | :--- | :--- | :--- | :--- |
| `kind == .wifi` | **Wi-Fi** | Wi-Fi | `wifi` | 本机无线局域网卡（如 en0） |
| `kind == .wired` | **有线** | Wired | `cable.connector` | 物理网口 / 雷雳以太网（如 en1~en8） |
| `kind == .cellular` | **蜂窝** | Cellular | `antenna.radiowaves.left.and.right` | 蜂窝数据 / 个人热点（如 ap1） |
| `kind == .loopback` | **本地回环** | Loopback | `arrow.triangle.2.circlepath` | 本机进程通信（lo0，127.0.0.1） |
| `utun*` / `ipsec*` / `ppp*` | **虚拟隧道** | Tunnel | `lock.shield` | 代理软件（Clash/Surge）、VPN、iCloud 私网 |
| `awdl*` / `llw*` / `nan*` | **隔空投送** | Apple P2P | `airplayaudio` | 隔空投送、随航、AirPlay 专用无线通道 |
| `bridge*` | **雷雳网桥** | Bridge | `point.3.connected.trianglepath.dotted` | 雷雳直连高速网桥 |
| `anpi*` | **硬件总线** | Hardware Bus | `cpu` | Apple Silicon 芯片内部 PCIe 通道 |
| `gif*` / `stf*` | **系统隧道** | System Tunnel | `arrow.left.arrow.right` | IPv4/IPv6 系统过渡通道 |
| 其他未知 | **其他** | Other | `network` | 兜底未识别类型 |

* **改动点**：
  在 `DetailInterfacesView.swift` 中的 `InterfaceBladeCard` 上：
  - 接口类型胶囊替换为上述语义化标签及对应小图标；
  - 彻底终结满屏皆是「其他」的单调展示。

---

### 需求 C：网络接口页面多维分类筛选器（Tabs / Filter）
* **涉及文件**：`Sources/NetworkConsoleApp/DetailInterfacesView.swift`
* **交互设计**：
  在顶部指标舱（`InterfaceTelemetryPod`）与网格卡片之间增加 `Picker`（样式为 `.segmented`，居中或靠左排列）：
  1. **「仅物理网卡」**（Physical Only，**默认选中**）：
     - 筛选条件：`kind in [.wifi, .wired, .cellular]`
     - 效果：界面仅展示 en0~en8、ap1 等硬件网卡（约 8~9 个），清爽干净。
  2. **「虚拟隧道」**（Tunnels / VPN）：
     - 筛选条件：名称以 `utun`、`ipsec`、`ppp` 开头；
     - 效果：专门供用户检查代理隧道（Clash/Surge/VPN）的 IP 与活跃状态。
  3. **「全部接口」**（All Interfaces）：
     - 筛选条件：无过滤（全量展示所有 28 个接口）。
* **状态持久化**：
  使用 `@State private var selectedFilter: InterfaceFilter = .physical`，轻量且不增加复杂状态。

---

## 3. 本地化（8 语言）硬性规范

由于新增分类与筛选器文案，按项目规约必须在 `Sources/NetworkConsoleApp/L10n_*.swift` 8 个语言文件中同步补齐，并更新完整性脚本断言。

### 新增 L10n Key 字典清单（共新增 7 个 key）

#### 1. `interfaces.filter.physical`
- zh: `"仅物理网卡"`
- en: `"Physical Only"`
- ja: `"物理のみ"`
- ko: `"물리 인터페이스만"`
- de: `"Nur physische"`
- fr: `"Physiques uniquement"`
- es: `"Solo físicos"`
- pt: `"Apenas físicos"`

#### 2. `interfaces.filter.tunnels`
- zh: `"虚拟隧道"`
- en: `"Tunnels & VPN"`
- ja: `"仮想トンネル"`
- ko: `"가상 터널"`
- de: `"Tunnel & VPN"`
- fr: `"Tunnels et VPN"`
- es: `"Túneles y VPN"`
- pt: `"Túneis e VPN"`

#### 3. `interfaces.filter.all`
- zh: `"全部接口"`
- en: `"All Interfaces"`
- ja: `"すべてのインターフェース"`
- ko: `"모든 인터페이스"`
- de: `"Alle Schnittstellen"`
- fr: `"Toutes les interfaces"`
- es: `"Todas las interfaces"`
- pt: `"Todas as interfaces"`

#### 4. `interfaces.category.tunnel`
- zh: `"虚拟隧道"`
- en: `"Virtual Tunnel"`
- ja: `"仮想トンネル"`
- ko: `"가상 터널"`
- de: `"Virtueller Tunnel"`
- fr: `"Tunnel virtuel"`
- es: `"Túnel virtual"`
- pt: `"Túnel virtual"`

#### 5. `interfaces.category.appleP2P`
- zh: `"隔空投送/互联"`
- en: `"AirDrop / P2P"`
- ja: `"AirDrop / P2P"`
- ko: `"AirDrop / P2P"`
- de: `"AirDrop / P2P"`
- fr: `"AirDrop / P2P"`
- es: `"AirDrop / P2P"`
- pt: `"AirDrop / P2P"`

#### 6. `interfaces.category.bridge`
- zh: `"雷雳网桥"`
- en: `"Thunderbolt Bridge"`
- ja: `"Thunderbolt ブリッジ"`
- ko: `"Thunderbolt 브리지"`
- de: `"Thunderbolt-Brücke"`
- fr: `"Pont Thunderbolt"`
- es: `"Puente Thunderbolt"`
- pt: `"Ponte Thunderbolt"`

#### 7. `interfaces.category.hardwareBus`
- zh: `"硬件总线"`
- en: `"Hardware Bus"`
- ja: `"ハードウェアバス"`
- ko: `"하드웨어 버스"`
- de: `"Hardware-Bus"`
- fr: `"Bus matériel"`
- es: `"Bus de hardware"`
- pt: `"Barramento de hardware"`

---

## 4. 自动化测试与护栏基线

1. **L10n 基线变更**：
   - 既有 key 数量：`248`
   - 新增 key 数量：`7`
   - **新目标 key 数量**：`255`
   - 修改 `Scripts/check_l10n_completeness.py`：`EXPECTED_KEY_COUNT = 255`。
   - 修改 `Tests/NetworkConsoleAppTests/L10nFallbackTests.swift` 中关于 248 的硬断言为 255。
2. **新增测试用例**：
   - 增加卡片视图（`CyberDiagnosisCardView`）与轻检视图（`QuickCheckView`）活动接口计数的物理口径断言（断言为 1 个 en0，而非 16 个）。
   - 增加接口分类器与筛选逻辑的单元测试（验证 `en0` 属于 physical、`utun0` 属于 tunnel、`awdl0` 属于 appleP2P，以及三种筛选模式下的输出结果）。

---

## 5. 验收标准

1. `swift build`：0 错误，0 警告。
2. `swift test`：既有 66 例 + 本次新增用例全部 100% 通过（0 失败）。
3. `python3 Scripts/check_l10n_completeness.py`：8 语言全部显示 `255 key ✅`，退出码为 0。
4. 真实运行 App：
   - 点击「复制网络诊断卡片」，导出的卡片上显示「活动网络接口：1 个（en0）」，与概览页完全一致。
   - 「网络接口」页面默认仅显示物理网卡（约 8~9 个），切换到「虚拟隧道」可清晰查看 Clash/VPN 隧道，切换到「全部接口」可查看 28 个全貌。
   - 卡片上的胶囊标签清晰呈现「Wi-Fi / 有线 / 虚拟隧道 / 隔空投送 / 雷雳网桥 / 硬件总线」，不再是一片「其他」。
