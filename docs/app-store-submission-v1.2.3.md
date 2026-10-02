# NetDoctor 1.2.3 (Build 10) App Store 提审资料 / Submission Information

---

## 1. 版本更新说明 (What's New in This Version)

### 简体中文 (zh-Hans)
- 【多语言支持优化】修复了从日文、法文、德文等语言切换回简体中文时，部分系统菜单项（如全屏幕、移动和调整大小、平铺等）保留为上一语言的显示问题，现已实现 8 种语言的双向精准回溯翻译。
- 【界面布局精简】去除了“显示”菜单中冗余的设置项，菜单结构更加清晰精简。
- 【诊断稳定性提升】增强了网络物理链路载波状态与虚拟接口检测的判定逻辑，体检结果展示更精准。

---

### 繁體中文 (zh-Hant)
- 【多語言支援最佳化】修正了由日文、法文、德文等切換回繁體中文時，部分系統選單項目（如全螢幕、移動與調整大小、並排等）顯示異常的問題，現已全面支援 8 種語言雙向即時對應。
- 【介面選單簡化】移除了「顯示」選單中的重複設定選項，提升操作便利性。
- 【診斷精確度提升】完善了實體線路與虛擬網路介面的判定邏輯，讓網路狀態檢測更加即時準確。

---

### 英文 (en-US)
- **Multi-language Localization Enhancements**: Resolved an issue where switching back to Chinese/English from Japanese, French, or German left certain system menu items (e.g., Full Screen, Move & Resize, Tile) in the prior language. Full bidirectional reverse mapping across all 8 supported languages is now active.
- **Streamlined Menu Structure**: Removed redundant settings menu entry under the View menu for a cleaner interface.
- **Diagnostic Stability Improvements**: Refined physical carrier link detection and virtual interface identification for even higher accuracy.

---

### 日文 (ja)
- **多言語ローカライズの改善**: 日本語、フランス語、ドイツ語などの言語から他の言語に切り替えた際に、一部のシステムメニュー項目（フルスクリーン、移動とサイズ変更、タイルなど）の表示が正常に更新されない問題を修正しました。サポートされている8つの言語すべてで双方向の正確なマッピングに対応しました。
- **メニュー構造の整理**: 「表示」メニュー内の冗長な設定項目を整理し、操作性を向上させました。
- **診断精度の向上**: 物理リンクおよび仮想インターフェースの認識ロジックを最適化し、より正確な診断結果を提供します。

---

## 2. App 审核备注 (App Review Notes)

### 简体中文 (zh-Hans)
尊敬的 App 审核团队：

感谢您审阅 NetDoctor (v1.2.3, Build 10)。

本应用是一款轻量、只读的 macOS 网络状态体检工具，旨在帮助普通用户和网络管理员快速了解本机的网络连通性、物理接口状态、DNS 配置及外网探测延迟。

有关本次评审的关键技术与合规说明如下：
1. **只读诊断与安全沙盒**：
   - 应用完全运行在 macOS App Sandbox 沙盒保护机制下，并已开启 Hardened Runtime。
   - 应用绝不修改系统的 DNS、路由表、代理配置、网络设置或系统服务。
   - 应用不包含、不安裝任何 LaunchDaemon、LaunchAgent、特权 Helper 工具，不需要也不会向用户申请 Administrator/Root 提权。
2. **纯原生系统 API 诊断**：
   - 所有网络状态诊断均通过 Apple 官方原生框架实现，包括 `Network.framework` (`NWPathMonitor`, `NWConnection`)、`SystemConfiguration` 及 `CoreWLAN`。
   - 应用不调用任何外部 Shell 脚本、子进程（`Process`/`NSTask`）或命令行特权工具。
3. **连通性探测合规与透明性**：
   - 外网连通性探测默认使用公共标准连通性检测端点（如 Apple 官方标准端点 `http://captive.apple.com/hotspot-detect.html`），不包含任何企业私有端点或商业数据收集。
   - 用户亦可在“偏好设置”中根据自身网络环境自定义探测端点。
4. **隐私与遥测**：
   - 应用完全离线可用，默认不采集、不存储、不上传任何用户隐私数据或设备网络拓扑数据，无任何第三方追踪/埋点 SDK。
5. **测试账号与支持**：
   - 本应用无需注册或登录账号，启动即可直接使用全部诊断功能。
   - 技术支持与使用文档请参阅：https://support.kevinlabs.app/netdoctor/

如有任何疑问，请随时通过 App Store Connect 与我们联系，感谢您的审核！

---

### 英文 (en-US)
Dear Apple App Review Team,

Thank you for reviewing NetDoctor (v1.2.3, Build 10).

NetDoctor is a lightweight, strictly read-only macOS network diagnostic utility designed to help users inspect their local network interfaces, gateway connectivity, DNS status, and Internet probe latency.

Key technical and compliance notes regarding this submission:
1. **Read-Only Diagnostics & App Sandbox**:
   - The application strictly operates within the macOS App Sandbox with Hardened Runtime enabled.
   - It NEVER modifies any system settings, DNS configurations, routing tables, proxy configurations, VPNs, or system daemons.
   - It does NOT require, request, or install any root/administrator privileges, LaunchDaemons, LaunchAgents, or privileged helper tools.
2. **Native Apple Frameworks Only**:
   - All network state queries are performed exclusively via official Apple APIs (`Network.framework` including `NWPathMonitor` and `NWConnection`, `SystemConfiguration`, and `CoreWLAN`).
   - No `Process`, `NSTask`, shell scripts, or external command-line utilities are executed.
3. **Transparent Reachability Probes**:
   - Public reachability verification uses standard endpoints (such as Apple's standard captive portal probe `http://captive.apple.com/hotspot-detect.html`).
   - Users can optionally specify custom probe endpoints in the app's Preferences window.
4. **Privacy & Telemetry**:
   - The app respects user privacy: it does NOT collect, track, log, or upload any user data, telemetry, or network traffic. No third-party analytics SDKs are included.
5. **Review Credentials & Support**:
   - No login credentials or account registration is required to use all features of the application.
   - Documentation & support: https://support.kevinlabs.app/netdoctor/

Please do not hesitate to contact us through App Store Connect should you have any questions. Thank you for your time and assistance!
