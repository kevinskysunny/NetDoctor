# NetDoctor 1.2.5 (Build 12) App Store 提审资料 / Submission Information

---

## 1. 版本更新说明 (What's New in This Version)

### 简体中文 (zh-Hans)
- 新增直达系统设置：在 Wi-Fi、以太网与 DNS 诊断卡片中新增快捷跳转按钮，诊断后一键直达原生系统设置进行配置。
- 快捷操作优化：菜单栏面板与主菜单新增系统网络设置直达入口。
- 界面细节与交互体验优化。

---

### English (en-US)
- Quick System Settings Shortcuts: Added direct deep-link buttons to Wi-Fi, Ethernet, and DNS settings across diagnostic cards.
- Menu Bar Shortcuts: Access macOS System Network Settings directly from the menu bar popup and application menu.
- Minor UI improvements and interaction refinements.

---

### 繁體中文 (zh-Hant)
- 新增直達系統設定：於 Wi-Fi、以太網路與 DNS 診斷資訊卡新增快捷跳轉按鈕，一鍵直達原生系統設定調整配置。
- 選單列捷徑最佳化：選單列浮動視窗與應用程式選單新增系統網路設定直達入口。
- 介面細節與體驗微調。

---

### 日本語 (ja)
- システム設定への直接ショートカット: Wi-Fi、Ethernet、DNSの各診断カードから、macOSのシステム設定へワンクリックでアクセスできるボタンを追加しました。
- メニューバー操作の強化: メニューバーパネルおよびアプリアイコンメニューからシステムネットワーク設定へ即座に移動できます。
- 全体的なUIの改善と最適化。

---

## 2. App 审核备注 (App Review Notes)

### 英文 (en-US)
Dear Apple App Review Team,

Thank you for reviewing NetDoctor (v1.2.5, Build 12).

NetDoctor is a lightweight, strictly read-only macOS network diagnostic utility designed to help users inspect local network interfaces, gateway connectivity, DNS status, and Internet probe latency.

Key technical and compliance notes regarding this update:
1. **System Settings Deep Linking**:
   - Version 1.2.5 introduces convenient deep-link buttons (`x-apple.systempreferences:com.apple.preference.network?...`) allowing users to easily open native macOS System Settings (Wi-Fi, Ethernet, DNS) to configure their network.
   - All settings modifications are performed solely by the user inside Apple's native System Settings application. NetDoctor remains strictly read-only.
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
