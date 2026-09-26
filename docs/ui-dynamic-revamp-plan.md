# NetDoctor UI & 动效趣味化改造完整实施计划

> **文档定位**：面向 NetDoctor（`networkconsole-lite`）macOS 客户端的下一代 UI/UX 焕新规划。  
> **核心目标**：在不破坏现有只读安全架构、零第三方依赖的前提下，将“静态网络参数控制台”升级为具有**极客美学、动感流光、心电波形与趣味诊断反馈**的“赛博网络体检室”。

---

## 1. 改造愿景与设计哲学

### 1.1 现状诊断
- **痛点**：目前 `QuickCheckView` 和 `DetailView` 大量采用系统级原生 `List`、文本键值对和灰底卡片，缺乏“医生诊断”的视觉隐喻与情绪价值，交互静态无反馈。
- **机会**：网络状态（RTT 波动、丢包、路由跳步、接口上下线）本质上是**高频且充满生命力的数据流**，天然契合动态波形与物理链路可视化。

### 1.2 改造原则
1. **纯原生与零额外开销**：全部基于 SwiftUI、Swift Charts、SF Symbols 5（`symbolEffect`）及 `Canvas` 自绘，不引入重量级第三方动画库，保证 CPU/内存极低开销。
2. **恪守只读与沙盒边界**：改造仅限 `NetworkConsoleApp` 表现层与 `NetworkCore` 的只读算法扩展，严禁触碰任何系统配置写入或特权命令。
3. **分层渐进演进**：组件化解耦，每个视觉模块（心电图、拓扑管线、评分环）均可独立测试与插拔。

---

## 2. 核心模块与功能设计

```text
┌─────────────────────────────────────────────────────────────┐
│                      NetDoctor App UI                       │
├──────────────────────────────┬──────────────────────────────┤
│       QuickCheckView         │          DetailView          │
│  (380px MenuBar Popover)     │   (Modern Sidebar & Bento)   │
├──────────────────────────────┼──────────────────────────────┤
│ • 0~100 健康分仪表盘         │ • 动态拓扑链路流光图         │
│ • 网络心电图 (ECG Waveform)   │ • 延迟与抖动分布图 (Charts)  │
│ • 声呐脉冲体检动效           │ • 赛博病历卡导出 (ImageRender│
│ • SF Symbols 5 状态呼吸      │ • 触感与清脆完成音效         │
└──────────────────────────────┴──────────────────────────────┘
```

### 模块 A：赛博心电波形组件 (`ECGWaveformView`)
* **定位**：实时感知网络生命力的核心视觉锚点。
* **展现逻辑**：
  * **体检中**：随着 `ReachabilityProber` 发出并发采样，波形随 RTT 毫秒数产生高低起伏的脉冲跳动。
  * **健康（Healthy）**：呈现平稳且富有弹性的呼吸绿色波纹（60~80bpm 节奏感）。
  * **警告（Warning）**：波峰出现微弱毛刺与抖动，色相转为琥珀金。
  * **断网/严重（Critical）**：波形骤降为一条红色心跳停顿直线（Flatline），并伴随微弱警示呼吸。
* **实现方式**：采用 `TimelineView` + `Canvas` 自绘路径，配合 `.phaseAnimator` 驱动微位移。

### 模块 B：拓扑链路流光管线 (`NetworkPipelineView`)
* **定位**：替代割裂的“接口/DNS/路由”列表，用一眼可见的物理拓扑呈现。
* **链路节点**：
  ```text
  [ 💻 本机 Mac ] ━━(1)━━> [ 🛰️ 本地网关 ] ━━(2)━━> [ 🧬 DNS 解析 ] ━━(3)━━> [ 🌐 互联网服务 ]
  ```
* **动效机制**：
  * **正常流转**：节点连接线上有微弱发光的能量粒子顺次穿梭（Particle Flow）。
  * **断点预警**：若哪一段受阻（如局域网通但 DNS 无响应），对应连接线断开闪烁，故障节点变为红/橙并伴随轻度晃动动画（Shake Animation），排查直觉性达 100%。

### 模块 C：0~100 健康评分仪表 (`HealthScoreGaugeView`)
* **算法升级**（扩展 `HealthGrader`）：
  * 满分 100 分 = 基础路径可用（30分）+ DNS 正常与解析低延迟（25分）+ 网关路由通畅（20分）+ 公网探测零丢包与低 RTT（25分）。
  * 扣分项：P90 > 500ms（扣5~10分）、丢包率（按比例扣除）、受限网络（扣15分）。
* **UI 交互**：
  * 环形渐变发光进度条（Radial Glow Gauge）。
  * 数字平滑翻牌滚轮（Odometer Transition）。
  * 拟人化诊断定性评语：“经络畅通 · 战力全开”、“轻微咽喉炎（DNS响应迟钝）”、“心律不齐（Wi-Fi抖动丢包）”。

### 模块 D：菜单栏 `QuickCheckView` Bento Box 现代化
* **网格化便当盒布局**：放弃多行垂直文本，改用 2x2 精致小卡片（延迟 P50、接口速率、DNS 服务器、丢包率）。
* **材质与边缘**：背景 `.ultraThinMaterial`，配合 1px 半透明亮白描边（`StrokeBorder(Color.white.opacity(0.12))`），悬停带微微上浮微交互。
* **声呐涟漪（Sonar Wave）**：点击“立即检查”按钮，按钮背景向外辐射三道淡蓝光圈，仪式感拉满。
* **SF Symbols 5 深度应用**：
  ```swift
  Image(systemName: model.statusSymbolName)
      .symbolEffect(.variableColor.iterative.reversing, isActive: model.isChecking)
  ```

### 模块 E：端点延迟可视化与 Swift Charts
* **现状**：表格纯数字显示 `P50: 32ms, P90: 85ms`。
* **改造**：使用原生 `Swift Charts`（`BarMark` + `RuleMark`）：
  * 直观展示各大公开端点（Cloudflare, Apple, Google, Baidu 等）的延迟柱状图与抖动极差范围，直观感知延迟差异。

### 模块 F：赛博体检病历单（Cyber Diagnosis Card）
* **定位**：满足用户的求助与分享欲望（“我的网络到底怎么了”）。
* **形态**：精美的极客风票据/卡片设计，包含条形码装饰、检查时间戳、Mac 型号标识、关键指标与体检评语。
* **技术方案**：SwiftUI View 配合 `ImageRenderer` 直接将视图转成 `NSImage`，快捷键 `Cmd+Shift+C` 一键拷入系统剪贴板。

---

## 3. 落地实施路线图（Milestones）

### Phase 1: 数据层升级（NetworkCore）
- [ ] 在 `HealthGrader.swift` 中新增 `score(...) -> Int` 计算方法。
- [ ] 丰富趣味化体检评语（支持中英双语扩展 `Localization.swift`）。
- [ ] 为健康分补充单元测试，确保边界值（断网=0分，极佳=100分）。

### Phase 2: 动效与组件库研发（NetworkConsoleApp/Components）
- [ ] 新建 `ECGWaveformView.swift`：实现自绘网络心电波形。
- [ ] 新建 `NetworkPipelineView.swift`：实现 4 节点拓扑链路与流动光粒子。
- [ ] 新建 `HealthScoreGaugeView.swift`：实现 0~100 环形刻度与翻牌器动画。
- [ ] 在 `Components.swift` 中升级 `MetricCard` 为 Bento 风格并支持微光边框与 Hover 态。

### Phase 3: 菜单栏 `QuickCheckView` 重构
- [ ] 嵌入 `ECGWaveformView` 作为顶部背景或状态指示条。
- [ ] 重构中间指标卡片为 Bento Grid。
- [ ] 接入 SF Symbols 5 原生动态图标效果。
- [ ] 改造“立即检查”按钮动效（声呐水波纹反馈）。

### Phase 4: 详情页 `DetailView` 架构改造
- [ ] 将传统顶部 TabView 重塑为现代分段导航（Segmented Pill）或极简左侧边栏。
- [ ] Overview 页顶部首屏：放置 **拓扑链路图 + 健康评分仪表**。
- [ ] Reachability 标签页接入 `Swift Charts` 延迟对比图表。
- [ ] 增加触觉反馈（`.sensoryFeedback(.success, trigger: ...)`）与可选柔和音效。

### Phase 5: 病历卡片导出与收尾
- [ ] 实现 `CyberDiagnosisCardView.swift` 及 `ImageRenderer` 拷贝图片功能。
- [ ] 检查并验证 Release 构建：`swift build`、`swift test`、`xcodegen generate`。
- [ ] 截图更新并在本地运行验证。

---

## 4. 新会话施工指令（直接复制使用）

当切换到新会话准备开工时，请直接发送以下指令给 Agent：

```text
请在 /Users/kevinsmith/Person/project/07-apps-experiments/networkconsole-lite 中施工。

请先完整阅读 docs/ui-dynamic-revamp-plan.md 和 AGENTS.md。

本次施工任务：按照 docs/ui-dynamic-revamp-plan.md 执行 NetDoctor 的 UI 动效趣味化改造。

重点执行阶段：
1. 扩展 HealthGrader 提供 0~100 健康分与趣味诊断评语。
2. 编写核心视觉组件：ECGWaveformView（心电波形）、NetworkPipelineView（拓扑流光管线）、HealthScoreGaugeView（评分环）。
3. 改造 QuickCheckView 与 DetailView，融入 Bento 卡片与 SF Symbols 5 动效。
4. 保证 swift build 和 swift test 100% 通过，绝不破坏 App Sandbox 与只读安全边界。
```
