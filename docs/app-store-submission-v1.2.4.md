# NetDoctor 1.2.4 (Build 11) App Store 提审资料 / Submission Information

---

## 1. 版本更新说明 (What's New in This Version)

### 简体中文 (zh-Hans)
- 【功耗与性能大幅优化】重构后台调度机制，待机 CPU 占用降至 0%，更加省电护航。
- 【菜单响应更流畅】优化多语言菜单动态加载，点击即刻丝滑呈现。
- 【体验细节提升】优化自定义探测端点的输入与稳定性。

---

### English (en-US)
- **Ultra-Low Power Usage**: Overhauled background scheduling to achieve 0% idle CPU usage, maximizing battery life.
- **Smoother Menu Experience**: Optimized menu localization for instant and fluid responsiveness.
- **Stability Improvements**: Enhanced custom network probe settings and overall reliability.

---

### 繁體中文 (zh-Hant)
- 【功耗與效能大幅最佳化】重構背景調度機制，待機 CPU 佔用降至 0%，更加省電耐用。
- 【選單回應更流暢】最佳化多語言選單載入速度，點擊即刻順暢呈現。
- 【穩定性與細節提升】改善自訂網路探測端點設定與體驗。

---

### 日本語 (ja)
- **省電力とパフォーマンスの大幅改善**: バックグラウンド待機時のCPU使用率を0%に削減し、バッテリー消費を最小限に抑えました。
- **メニュー応答の向上**: 多言語メニューの切り替えと表示レスポンスをさらに滑らかに最適化しました。
- **安定性の向上**: カスタム診断エンドポイント設定の安定性を改善しました。

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
