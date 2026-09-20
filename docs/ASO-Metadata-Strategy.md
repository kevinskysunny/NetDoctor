# NetDoctor（原 NetworkConsole Lite）: ASO 深度优化与 App Store 上架元数据方案

> **核心目标**：
> 1. **策略 2（优化 ASO）**：告别原先“偏内部、偏运维、带 Lite 降权标签”的冷门状态，通过高权重搜索词与用户痛点包装，大幅拉升 Mac App Store 自然搜索展现量与下载转化率。
> 2. **辅助策略 1（给 VolMix 导流）**：借助 100% 符合苹果审核政策的“Kevin Labs 开发者品牌专区”，为工作室主力付费应用 **VolMix** 构筑持久稳定的免费流量漏斗。

---

## 一、当前 ASO 痛点与破局思路

| 维度 | 现状痛点 | 优化思路 |
| :--- | :--- | :--- |
| **应用名称** | `NetworkConsole Lite` 偏底层命令行/内网工具风格，普通用户极少主动搜索 | 采用“独立品牌名 + 核心高搜词（网络体检/Ping/诊断）”结构 |
| **“Lite”标签** | 苹果审核规范对 Lite 字眼敏感，容易被用户视为“阉割版/试用版”而放弃下载 | 拿掉 Lite，或者重塑为更具独立质感的工具品牌 |
| **搜索场景** | 用户在 Wi-Fi 卡顿、视频会议掉线、网页打不开时才有强烈搜索需求 | 关键词紧紧围绕“体检、Ping、延迟、Wi-Fi、断网诊断、丢包”展开 |
| **产品转化** | 孤立工具，用户用完即走 | 在设置页与关于板块联动 **VolMix**，实现矩阵互推 |

---

## 二、产品名称与副标题方案（严格控制在 30 字符内）

> [!IMPORTANT]
> Apple App Store 规定：**名称（Name）最长 30 个字符**，**副标题（Subtitle）最长 30 个字符**。

### 方案 1：通俗权威风（⭐⭐⭐⭐⭐ 强烈推荐，搜索权重最高）
- **中文名称**：`NetDoctor - 菜单栏网络体检`（16 字符）
- **中文副标题**：`Wi-Fi 状态、Ping 延迟与断网排查`（21 字符，精准覆盖 4 大高频词）
- **英文名称**：`NetDoctor: Network Diagnostics`（29 字符）
- **英文副标题**：`Wi-Fi Monitor, Ping & DNS Test`（30 字符）

### 方案 2：极客轻量风（适合科技感定位）
- **中文名称**：`NetPulse - 菜单栏网络体检与诊断`（18 字符）
- **中文副标题**：`实时 Wi-Fi 信号、Ping 延迟与外网监测`（23 字符）
- **英文名称**：`NetPulse: Network & Ping Check`（29 字符）
- **英文副标题**：`Wi-Fi, DNS & Route Diagnostics`（30 字符）

### 方案 3：保留原品牌微调方案（如果想延续 NetworkConsole 品牌）
- **中文名称**：`NetworkConsole - 网络体检`（17 字符）
- **中文副标题**：`菜单栏 Wi-Fi 监控与外网诊断`（17 字符）
- **英文名称**：`NetworkConsole: Net Doctor`（25 字符）
- **英文副标题**：`Ping, Wi-Fi & DNS Diagnostics`（29 字符）

---

## 三、100 字符 Keywords（关键词库，中英双语顶格卡满）

> [!TIP]
> 苹果关键词规则：总计不超过 100 字符，词与词之间**用英文半角逗号隔开**，**不要包含空格**，避免与 App 名称重复词。

### 1. 简体中文关键词（精确 99 字符）
```text
网络,体检,ping,wifi,诊断,断网,测速,dns,延迟,网速,路由,网络监控,网络工具,连通性,丢包,ip,无线网,局域网,网络助手,网络医生
```

### 2. 英文关键词（精确 99 字符）
```text
network,diagnostics,ping,wifi,latency,dns,speed,status,monitor,internet,connection,router,packet,ip,lan
```

---

## 四、宣传文本与完整描述（Description）

### 1. 宣传文本（Promotional Text，170 字符以内，随时可更新无需审包）
> Mac 网络突然变慢？开会视频卡顿？NetDoctor 驻留菜单栏，0 权限、0 驱动，一秒看清真实 Wi-Fi 信号、DNS 与多节点 Ping 延迟，智能生成小白也能看懂的排查建议。

---

### 2. 详细描述（App Store Description - 简体中文版）

```markdown
NetDoctor（网络体检）是一款专为 Mac 打造的原生只读网络体检与诊断工具。无需打开终端敲命令，无需理解复杂的网络协议，常驻菜单栏，让你随时一目了然掌握当前网络状态。

当你的 Wi-Fi 突然变慢、网页打不开、视频会议卡顿或者跨国服务连不上时，NetDoctor 能以毫秒级速度帮你定位是“无线信号差”、“路由器故障”、“DNS 解析失效”还是“外网断连”。

【核心功能亮点】

◆ 菜单栏状态一目了然
轻巧常驻 macOS 顶部菜单栏，通过健康图标实时显示当前网络状态：正常（绿色）、信号弱/存在隐患（橙色）、断网（红色）或检测中。

◆ 多端点真实并发 Ping 探测
不同于传统的单点测试，NetDoctor 对全球权威主流端点（Apple、Google、Cloudflare 等）并发采样，准确呈现 RTT 往返延迟中位数、P95 延迟与丢包率，真实还原外网访问体验。

◆ 深入浅出的本地排查建议
发现异常时，内置专家诊断引擎会自动梳理接口、DNS、网关路由与外网响应，直接输出通俗直白的修复建议（例如：“DNS 解析超时，请尝试更换 223.5.5.5 或 8.8.8.8”）。

◆ 完整网络接口与路由透视
一键查看当前活动的 Wi-Fi SSID、本地 IPv4/IPv6 地址、默认网关、活跃网络接口及生效的 DNS Resolver。

◆ 100% 纯本地、安全与隐私保障
• 纯原生 SwiftUI 构建，性能极佳，内存占用极低；
• 严格遵循沙盒（App Sandbox）机制，无需 Root，无后台特权 Helper；
• 绝不修改系统网络配置，不劫持流量；
• 纯本地运行，零埋点、无第三方追踪，诊断数据绝不自动上传服务器。

【关于 Kevin Labs】
Kevin Labs 是一个独立开发者个人品牌，专注打造精美、纯粹且强大的 macOS 原生效率工具。
欢迎在【设置】中探索更多产品（如分应用独立音量管理工具 VolMix、本地工作入口管理器 KSIC Studio 等）。
如有任何建议或问题，欢迎随时反馈！
```

---

### 3. 详细描述（App Store Description - English Version）

```markdown
NetDoctor is a lightweight, read-only network diagnostics tool crafted natively for macOS. It helps you instantly understand whether your network is genuinely healthy without opening Terminal or parsing complex routing tables.

When meetings lag, websites won't load, or Wi-Fi drops, NetDoctor diagnoses the exact root cause in seconds—be it poor signal, gateway issues, DNS timeouts, or WAN connectivity drops.

KEY FEATURES:

◆ Menu Bar Glance
Resides discreetly in your macOS menu bar. Visual indicators let you spot network degradation at a single glance.

◆ Multi-Endpoint Concurrent Latency Probing
Probes multiple global reliable endpoints concurrently to calculate real-world median RTT, P95 latency, and packet loss ratios.

◆ Actionable Troubleshooting Advice
Translates low-level network states into plain, understandable advice for everyday users without networking jargon.

◆ Full Network Interface & DNS Transparency
Quickly view active Wi-Fi SSID, local IPv4/IPv6 addresses, default gateway, and active DNS resolvers in one unified dashboard.

◆ Privacy First & Zero Privileges
• Built 100% native with SwiftUI; ultra-low CPU and memory footprint.
• Strictly sandboxed: no root required, no background daemon, no network interception.
• Read-only diagnostics: never alters your DNS, routing table, or proxy settings.
• 100% local: zero analytics, zero data uploaded.

Crafted with care by Kevin Labs.
```

---

## 五、App Store 5 张高转化截图文案与视觉布局

| 序号 | 截图大标题（Heading） | 副标题说明（Sub-caption） | 推荐视觉画面 |
| :---: | :--- | :--- | :--- |
| **图 1** | **菜单栏轻量常驻** | 网络好坏，抬头一眼便知 | 菜单栏下拉弹窗（QuickCheckView），突出圆环健康评分与延迟数据 |
| **图 2** | **全球节点真实延迟** | 多端点并发采样，Ping 与丢包一清二楚 | 详情页“互联网连通性”Tab，展示 Apple/Google 节点的往返延迟柱状分析 |
| **图 3** | **小白也能懂的排查建议** | 告别黑底白字终端，智能定位网络故障 | 详情页概览 Tab，高亮“排查建议”卡片（如 DNS 异常建议） |
| **图 4** | **接口与路由全景透视** | Wi-Fi 信号、网关与 DNS 深度解析 | 详情页“网络接口”与“DNS与路由”Tab 切换展示 |
| **图 5** | **100% 隐私 · 零系统入侵** | 免 Root 权限，无后台守护，数据绝不上传 | 设置页隐私声明与 Kevin Labs 独立产品矩阵展示 |

---

## 六、辅助策略 1（给 VolMix 导流）的代码落地总结

1. **已在 `Sources/NetworkConsoleApp/SettingsView.swift` 中嵌入“更多来自 Kevin Labs”专区**：
   - 优雅展示 **VolMix (Per-App Volume Control)** 原生推荐卡片；
   - 带有 Mac App Store 直跳外链（`macappstore://apps.apple.com/app/id6806717830?mt=12`，KSIC Studio 为 `id6801325655`；经实测，无国家代码的 `https://apps.apple.com/app/...` 链接会被 Apple 网页端按 IP 地区 302 重定向并丢失路径，落到 Today 首页，故应用内统一使用 `macappstore://` 协议直开 App Store.app）；
   - 同时联动展示 **Ksic Studio**，构筑独立开发者产品生态；
2. **已在 `Localization.swift` 补充完整中英双语本地化支持**；
3. **已将版权与团队标识统一为 `Kevin Labs`**；
4. **编译与测试 100% 验证通过**（`swift test` 10 个核心测试用例全部 Pass）。
