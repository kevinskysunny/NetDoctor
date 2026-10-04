# NetDoctor 1.2.4 (Build 11) App Store 提审资料 / Submission Information

---

## 1. 版本更新说明 (What's New in This Version)

### 简体中文 (zh-Hans)
- 【极致性能与零功耗优化】重构了菜单栏本地化调度机制，彻底移除高频轮询定时器，全面转向纯事件驱动模型。应用在后台静默待机时 CPU 占用率直降至 0.0%，闲置唤醒完全归零，大幅延长 Mac 电池续航。
- 【菜单动态响应提速】基于原生系统菜单生命周期回调（`menuWillOpen` 与跟踪通知）实现微秒级本地化即时注入，多语言切换更丝滑无感。
- 【端点管理稳定性】优化了自定义探测端点输入控件的生命周期与内存管理。

---

### English (en-US)
- **Ultra-Low Power & Zero Idle Wakeups**: Overhauled the menu bar localization architecture by replacing continuous polling with a 100% event-driven model. Background idle CPU consumption drops to 0.0% with zero unnecessary wakeups, maximizing Mac battery life.
- **Instant Menu Responsiveness**: Switched to native system menu lifecycle callbacks (`menuWillOpen` and tracking notifications) for microsecond-level localized title injection across all 8 languages.
- **Custom Probe Endpoint Stability**: Improved memory management and lifecycle cleanup around custom network probe inputs.

---

### 繁體中文 (zh-Hant)
- 【極致效能與零功耗最佳化】重構了選單列多語言更新機制，徹底移除高頻輪詢定時器，全面改採事件驅動模式。背景待機時 CPU 佔用率降至 0.0%，完全杜絕多餘閒置喚醒，大幅節省電力。
- 【選單動態反應加速】運用原生選單生命週期回呼機制，在點擊瞬間微秒級載入本地化文字，多語言切換更流暢。
- 【自訂端點穩定性提升】最佳化了自訂網路探測端點輸入介面的記憶體管理與穩定度。

---

### 日本語 (ja)
- **極めて低いCPU負荷と省電力化**: メニューバーのローカライズ同期をイベント駆動型に再構築し、定期ポーリングタイマーを完全に撤廃しました。バックグラウンド待機時のCPU使用率は0.0%に低減され、アイドリング復帰もゼロになり、バッテリー持続時間を最大化します。
- **メニュー応答の高速化**: システムネイティブのメニュー表示コールバック（`menuWillOpen`）と連動し、クリック瞬間に8言語の翻訳を即座に適用します。
- **カスタム診断エンドポイントの安定性向上**: エンドポイント入力画面のライフサイクルとメモリ管理を最適化しました。

---

## 2. App 审核备注 (App Review Notes)

### 英文 (en-US)
Dear Apple App Review Team,

Thank you for reviewing NetDoctor (v1.2.4, Build 11).

NetDoctor is a lightweight, strictly read-only macOS network diagnostic utility designed to help users inspect local network interfaces, gateway connectivity, DNS status, and Internet probe latency.

Key technical and compliance notes regarding this update:
1. **Performance & Energy Efficiency Update**:
   - Version 1.2.4 refactors our menu localization mechanism to be purely event-driven, reducing background CPU usage to 0.0% with 0 idle wakeups.
2. **Read-Only Diagnostics & App Sandbox**:
   - The application strictly operates within the macOS App Sandbox with Hardened Runtime enabled.
   - It NEVER modifies system settings, DNS configurations, routing tables, proxy configurations, VPNs, or system daemons.
   - It does NOT require, request, or install any root/administrator privileges, LaunchDaemons, LaunchAgents, or privileged helper tools.
3. **Native Apple Frameworks Only**:
   - All network state queries are performed exclusively via official Apple APIs (`Network.framework` including `NWPathMonitor` and `NWConnection`, `SystemConfiguration`, and `CoreWLAN`).
   - No `Process`, `NSTask`, shell scripts, or external command-line utilities are executed.
4. **Transparent Reachability Probes**:
   - Reachability verification defaults to Apple's standard captive portal probe (`http://captive.apple.com/hotspot-detect.html`).
   - Users can optionally specify custom probe endpoints in the app's Preferences window.
5. **Privacy & Telemetry**:
   - The app respects user privacy: it does NOT collect, track, log, or upload any user data, telemetry, or network traffic. No third-party analytics SDKs are included.
6. **Review Credentials & Support**:
   - No login credentials or account registration is required to use all features of the application.
   - Documentation & support: https://support.kevinlabs.app/netdoctor/

Please do not hesitate to contact us through App Store Connect should you have any questions. Thank you for your time and assistance!
