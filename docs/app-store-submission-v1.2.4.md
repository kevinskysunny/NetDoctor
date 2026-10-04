# NetDoctor 1.2.4 (Build 11) App Store 提审资料 / Submission Information

---

## 1. 版本更新说明 (What's New in This Version)

### 简体中文 (zh-Hans)
- 性能与功耗优化：优化后台调度与待机机制，CPU 占用直降至 0%，更加省电护航。
- 提升菜单栏响应速度与交互流畅度。

---

### English (en-US)
- Performance & battery optimization: streamlined background scheduling to achieve 0% idle CPU usage.
- Improved menu responsiveness and overall smoothness.

---

### 繁體中文 (zh-Hant)
- 效能與功耗最佳化：重構背景調度機制，待機 CPU 佔用降至 0%，大幅節省電力。
- 提升選單列回應速度與互動流暢度。

---

### 日本語 (ja)
- パフォーマンスと省電力の最適化: バックグラウンドの処理を最適化し、待機時のCPU使用率を0%に削減しました。
- メニューの応答性と操作性を向上しました。

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
