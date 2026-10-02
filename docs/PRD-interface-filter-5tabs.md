# 需求规范：网络接口 5 档分类筛选器与标签 Key 修复 (v1.2.3)

> **文档状态**：待实施
> **目标版本**：v1.2.3
> **涉及模块**：`NetworkConsoleApp`
> **红线原则**（严格遵守 AGENTS.md）：只读诊断、无特权 Helper、无子进程、测试零真实网络、8 语言完整对齐。

---

## 1. 任务一：修复物理网卡胶囊标签 Key 笔误（Bugfix）

### 问题现象
在「网络接口」页面的物理网卡卡片上，胶囊标签显示为未翻译的 Key 原始字符：`kind.wifi`、`kind.wired`、`kind.cellular`，未能正确翻译为「Wi-Fi / 有线 / 蜂窝」。

### 根因与修复要求
修改 `Sources/NetworkConsoleApp/InterfaceCategory.swift` 中的 `InterfaceCategoryStyle.style(for:)`：
将既有分类的 l10nKey 前缀由 `kind.*` 修正为项目中标准的 `interface.*`：
- `.wifi` -> `l10nKey: "interface.wifi"`
- `.wired` -> `l10nKey: "interface.wired"`
- `.cellular` -> `l10nKey: "interface.cellular"`
- `.loopback` -> `l10nKey: "interface.loopback"`
- `.systemTunnel` -> `l10nKey: "interface.other"`
- `.other` -> `l10nKey: "interface.other"`
（`.tunnel`、`.appleP2P`、`.bridge`、`.hardwareBus` 保持 `interfaces.category.*` 不变）

---

## 2. 任务二：网络接口筛选器扩充为 5 档（方案 B）

### 目标与分类划分
将 `DetailInterfacesView.swift` 顶部的分段控制器（Segmented Picker）从 3 档扩充为 5 档，实现 100% 覆盖全部 28 个接口，无一遗漏：

| 筛选选项 (Filter) | 覆盖接口特征 | 用户场景与预期接口数 |
| :--- | :--- | :--- |
| **仅物理网卡** (`.physical`) | `kind in [.wifi, .wired, .cellular]`（en0~en8, ap1） | 日常上网连接排障（默认选中，约 9 个） |
| **虚拟隧道** (`.tunnels`) | 名称前缀 `utun`、`ipsec`、`ppp` | 科学上网 / Clash / Surge / VPN 检查（约 9 个） |
| **隔空投送/互联** (`.appleP2P`) | 名称前缀 `awdl`、`llw`、`nan` | AirDrop、随航、近场设备互联排障（约 3 个） |
| **系统底层** (`.system`) | 名称前缀 `bridge`、`anpi`、`gif`、`stf` 或 `kind == .loopback` | 雷雳网桥、M芯片硬件总线、回环通信（约 7 个） |
| **全部接口** (`.all`) | 无过滤 | 查看系统底层完整 28 个网络接口 |

### 代码改动点
1. **`InterfaceFilter.swift`**：
   - 枚举扩充为 5 值：`case physical, tunnels, appleP2P, system, all`
   - `l10nKey` 映射增加：
     - `.appleP2P` -> `"interfaces.filter.appleP2P"`
     - `.system` -> `"interfaces.filter.system"`
   - `InterfaceFilterApplier.apply` 增加对应两档的过滤逻辑。
2. **`DetailInterfacesView.swift`**：
   - Segmented Picker 自动遍历 `InterfaceFilter.allCases`，适配 5 档渲染。

---

## 3. 本地化（8 语言）硬性规范（新增 2 个 key，基线 255 -> 257）

在 `Sources/NetworkConsoleApp/L10n_*.swift` 8 种语言文件中完整补齐以下 2 个新 key：

### 1. `interfaces.filter.appleP2P`
- zh: `"隔空投送/互联"`
- en: `"AirDrop / P2P"`
- ja: `"AirDrop / P2P"`
- ko: `"AirDrop / P2P"`
- de: `"AirDrop / P2P"`
- fr: `"AirDrop / P2P"`
- es: `"AirDrop / P2P"`
- pt: `"AirDrop / P2P"`

### 2. `interfaces.filter.system`
- zh: `"系统底层"`
- en: `"System & Hardware"`
- ja: `"システム・ハード"`
- ko: `"시스템 및 하드웨어"`
- de: `"System & Hardware"`
- fr: `"Système et matériel"`
- es: `"Sistema y hardware"`
- pt: `"Sistema e hardware"`

### 护栏基线同步提升：
1. 修改 `Scripts/check_l10n_completeness.py` 中的 `EXPECTED_KEY_COUNT = 257`。
2. 修改 `Tests/NetworkConsoleAppTests/L10nFallbackTests.swift` 中的 255 硬断言为 257。

---

## 4. 自动化测试与质量要求

1. 在 `Tests/NetworkConsoleAppTests/InterfaceCategoryTests.swift` 中为 `.appleP2P` 与 `.system` 补充筛选测试断言。
2. 确保运行以下命令全部通过：
   - `swift build`（0 错误 0 警告）
   - `swift test`（全部测试 0 failure）
   - `python3 Scripts/check_l10n_completeness.py`（退出码 0，8 语言全部 257 key）
3. 验证通过后提交并推送到 origin/main。
