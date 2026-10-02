# App Store Review Notes — NetDoctor v1.2 (Build 6)

> 提交日期：2026-09-27
> 版本：1.2（构建 6）
> Bundle ID：com.networkconsole.lite
> 用途：复制下方内容到 App Store Connect → App 审核 → Review Notes

---

## English Version（推荐使用）

```
NetDoctor is a read-only network diagnostic app for macOS. It does not modify any system network settings (DNS, routing, proxies, VPN) and requires no special accounts or internal networks.

## What's New in v1.2

- Complete 8-language localization (zh/en/ja/ko/de/fr/es/pt) withGlish-only fallback chain (no Chinese leakage to non-Chinese users)
- Language-neutral diagnostic engine: verdicts and advice now use typed enum codes instead of hardcoded localized strings
- Brand unified to "NetDoctor" (support package filename prefix, User-Agent, storage directory); Bundle ID unchanged
- Privacy policy copy corrected: removed false claim about "hardware MAC redaction"; now accurately states SSID is masked while IP/DNS/gateway are retained as diagnostic data
- Added App-layer test target (NetworkConsoleAppTests) with 30 tests covering localization, fallback chain, brand consistency, and migration logic

## How to Test

1. Launch the app — a health check runs automatically
2. Overview tab shows network status (Healthy/Warning/Critical) with a score
3. Switch language in Settings (top-right gear icon) — all 8 languages display correctly with no mixed languages
4. Network Interfaces tab — shows active interfaces, IP addresses, DNS servers, default gateway
5. External Probes tab — shows connectivity results to 3 public endpoints (see below)
6. Timeline tab — shows recent diagnostic events
7. Settings tab — adjust check interval, timeout; export a support package (JSON, SSID redacted)
8. Export Support Package — saves a JSON file with SSID replaced by placeholder; IP/DNS/gateway retained

## Public Endpoints Used for Connectivity Checks

The app performs read-only HTTPS connectivity checks against these well-known public endpoints:
1. Apple — https://www.apple.com/library/test/success.html
2. Cloudflare — https://www.cloudflare.com/cdn-cgi/trace
3. Google — https://connectivitycheck.gstatic.com/generate_204

No custom or private endpoints are used. No enterprise domains, no internal networks required.

## Important Notes

- **Wi-Fi SSID**: In macOS sandbox, the app cannot read Wi-Fi SSID without a special entitlement. We intentionally do NOT request this entitlement. SSID shows "Not available" — this is expected behavior, not a bug.
- **No system modifications**: The app only reads network state via NWPathMonitor, getifaddrs, and SCDynamicStoreCopyValue. It does not call Process, NSTask, or any shell commands.
- **No telemetry**: All diagnostic data stays on the user's Mac. Nothing is uploaded automatically. PrivacyInfo.xcprivacy declares no data collection.
- **No admin privileges**: The app runs in App Sandbox with minimal entitlements (network.client, user-selected file read-write).

## Demo

A 3-minute review demo is available at: docs/media/review/index.html (in the source repository)
```

---

## 中文版（备用）

```
NetDoctor 是一款面向 macOS 的只读网络诊断应用，不会修改任何系统网络设置（DNS、路由、代理、VPN），无需特殊账号或内网环境。

## v1.2 更新内容

- 完成 8 语言本地化（zh/en/ja/ko/de/fr/es/pt），兜底链固定为英文（非中文用户不会看到中文残留）
- 诊断引擎语言中立化：诊断结论与建议改用类型化枚举编码，不再硬编码本地化字符串
- 品牌统一为 "NetDoctor"（支持包文件名前缀、User-Agent、存储目录），Bundle ID 不变
- 隐私文案修正：移除"物理 MAC 脱敏"的虚假承诺，准确声明 SSID 占位处理、IP/DNS/网关作为诊断数据保留
- 新增 App 层测试 target（NetworkConsoleAppTests），30 个测试覆盖本地化、兜底链、品牌一致性、迁移逻辑

## 测试方法

1. 启动应用 — 自动执行一次健康检查
2. 概览页显示网络状态（健康/警告/严重）与分数
3. 在设置中切换语言（右上角齿轮图标）— 8 种语言均正确显示，无混杂语言
4. 网络接口页 — 显示活动接口、IP 地址、DNS 服务器、默认网关
5. 外网探测页 — 显示对 3 个公开端点的连通性结果（见下）
6. 时间线页 — 显示最近诊断事件
7. 设置页 — 调整检查间隔、超时；导出支持包（JSON，SSID 已脱敏）
8. 导出支持包 — 保存 JSON 文件，SSID 替换为占位符，IP/DNS/网关保留

## 外网探测使用的公开端点

应用仅对以下知名公开端点执行只读 HTTPS 连通性检测：
1. Apple — https://www.apple.com/library/test/success.html
2. Cloudflare — https://www.cloudflare.com/cdn-cgi/trace
3. Google — https://connectivitycheck.gstatic.com/generate_204

不使用任何自定义或私有端点，无需企业域名或内网环境。

## 重要说明

- **Wi-Fi SSID**：macOS 沙盒下，应用无法读取 Wi-Fi SSID（需特殊权限）。我们有意不申请此权限。SSID 显示"未获取"——这是预期行为，非缺陷。
- **不修改系统**：应用仅通过 NWPathMonitor、getifaddrs、SCDynamicStoreCopyValue 读取网络状态，不调用 Process、NSTask 或任何 Shell 命令。
- **无遥测**：所有诊断数据仅保存在用户本机，不会自动上传。PrivacyInfo.xcprivacy 声明无数据收集。
- **无需管理员权限**：应用在 App 沙盒中运行，仅持有最小权限（network.client、用户选择的文件读写）。

## 演示

3 分钟审核演示见源码仓库：docs/media/review/index.html
```

---

## App Store Connect 填写指引

1. 打开 [App Store Connect](https://appstoreconnect.apple.com) → NetDoctor → macOS App
2. 选择版本 1.2 → 构建 6
3. 在「App 审核」→「Review Notes」中粘贴上方英文版内容
4. 确认「App 隐私」问答与 `docs/PRIVACY.md` 一致
5. 提交审核