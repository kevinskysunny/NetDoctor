# NetDoctor 1.2.6 (Build 13) App Store 提审资料 / Submission Information

---

## 1. 版本更新说明 (What's New in This Version)

### 简体中文 (zh-Hans)
- 修复快捷键退出问题：支持使用 ⌘Q 即时退出应用，多语言切换下快捷键保持稳定有效。
- 优化排查建议交互：在“排查建议”卡片中直接提供以太网、Wi-Fi 及 DNS 设置等原生直达按钮，异常时一键跳转系统设置。
- 改进界面自适应与细节交互体验。

---

### English (en-US)
- Fixed Keyboard Shortcut: Restored the ⌘Q shortcut to smoothly quit the application across all languages.
- Actionable Troubleshooting Advice: Added direct shortcut buttons (Wi-Fi, Ethernet, and DNS settings) directly within the "What to Check Next" cards to quickly navigate to macOS System Settings when issues arise.
- Improved responsive layout and UI refinements.

---

### 繁體中文 (zh-Hant)
- 修復快捷鍵結束問題：支援使用 ⌘Q 即時結束應用程式，多語言切換下快捷鍵保持穩定有效。
- 最佳化排除建議互動：於「排除建議」資訊卡直接提供以太網路、Wi-Fi 與 DNS 設定等原生直達按鈕，異常時一鍵跳轉系統設定。
- 改善介面自適應與體驗細節。

---

### 日本語 (ja)
- ショートカットキー終了の修正: ⌘Qキーによる即時終了に対応し、言語切替後もショートカットキーが安定して動作します。
- トラブルシューティングの操作性向上: 「次の確認事項」カードから直接、Wi-Fi、Ethernet、DNS設定などのシステム設定を開くボタンを追加しました。
- 画面レイアウトの自動調整とUIの最適化。

---

## 2. App 审核备注 (App Review Notes)

### 英文 (en-US)
Dear Apple App Review Team,

Thank you for reviewing NetDoctor (v1.2.6, Build 13).

NetDoctor is a lightweight, strictly read-only macOS network diagnostic utility designed to help users inspect local network interfaces, gateway connectivity, DNS status, and Internet probe latency.

Key technical and compliance notes regarding this update:
1. **Interactive Guidance & System Settings Deep Linking**:
   - Version 1.2.6 adds direct quick-access buttons directly inside diagnostic advice cards ("What to Check Next"), enabling users to quickly open native macOS System Settings (Wi-Fi, Ethernet, DNS) with a single click.
   - All configuration adjustments remain strictly within Apple's native System Settings application. NetDoctor remains purely read-only.
2. **Keyboard Shortcut Refinement**:
   - Fixed an issue where Command+Q was not properly bound to quit the app, ensuring standard macOS HIG compliance across all 8 supported languages.
3. **Read-Only Diagnostics & App Sandbox**:
   - The application strictly operates within the macOS App Sandbox with Hardened Runtime enabled.
   - It NEVER modifies system settings, DNS configurations, routing tables, proxy configurations, VPNs, or system daemons.
   - It does NOT require, request, or install any root/administrator privileges, LaunchDaemons, LaunchAgents, or privileged helper tools.
4. **Native Apple Frameworks Only**:
   - All network state queries are performed exclusively via official Apple APIs (`Network.framework` including `NWPathMonitor` and `NWConnection`, `SystemConfiguration`, and `CoreWLAN`).
   - No `Process`, `NSTask`, shell scripts, or external command-line utilities are executed.
5. **Transparent Reachability Probes**:
   - Reachability verification defaults to Apple's standard captive portal probe (`http://captive.apple.com/hotspot-detect.html`).
   - Users can optionally specify custom probe endpoints in the app's Preferences window.
6. **Privacy & Telemetry**:
   - The app respects user privacy: it does NOT collect, track, log, or upload any user data, telemetry, or network traffic. No third-party analytics SDKs are included.
7. **Review Credentials & Support**:
   - No login credentials or account registration is required to use all features of the application.
   - Documentation & support: https://support.kevinlabs.app/netdoctor/

Please do not hesitate to contact us through App Store Connect should you have any questions. Thank you for your time and assistance!
