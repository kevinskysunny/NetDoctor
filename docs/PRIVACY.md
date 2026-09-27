# NetDoctor Privacy Policy

Last updated: September 27, 2026

NetDoctor is a read-only network diagnostic app for macOS.

## Data Collection

NetDoctor does not collect, transmit, or sell personal data. Diagnostic data stays on your Mac.

The app may read local network state such as active interfaces, DNS resolver settings, default route information, Wi-Fi SSID, and connectivity results to public endpoints. This information is used only to show results inside the app.

## Data Storage

Diagnostic events are stored locally on your Mac in the app's local data directory. Nothing is uploaded automatically.

## Support Package Export

When you choose to export a support package, a JSON file is written to the location you select. The export applies the following redaction policy:

- **Masked fields**: Wi-Fi SSID is replaced with a placeholder. When the SSID cannot be read in the sandbox, it is shown as "Not available".
- **Retained fields**: interface IP addresses (IPv4/IPv6), DNS servers, default gateway, and connectivity probe results are kept as diagnostic data.
- **Excluded fields**: usernames, cookies, passwords, private keys, and local file paths are never included.

## Internet Connectivity Checks

The app performs read-only HTTPS and TCP connectivity checks against public endpoints. It does not modify DNS, routing, proxies, VPN, or system network settings.

## Contact

For privacy questions, contact kevinskysunny@gmail.com.

---

# NetDoctor 隐私政策

更新日期：2026年9月27日

NetDoctor 是一款面向 macOS 的只读网络诊断应用。

## 数据收集

NetDoctor 不会收集、上传或出售个人数据。诊断数据仅保存在你的 Mac 上。

应用可能读取本地网络状态，包括活动接口、DNS 解析器、默认路由、Wi-Fi SSID 以及对公开端点的连通性结果。这些信息仅用于在应用内展示结果。

## 数据存储

诊断事件仅保存在本机应用数据目录中，不会自动上传。

## 支持包导出

当你主动选择导出支持包时，JSON 文件会写入你选择的位置。导出遵循以下脱敏策略：

- **占位字段**：Wi-Fi SSID 替换为占位符。沙盒下无法读取 SSID 时显示「未获取」。
- **保留字段**：接口 IP 地址（IPv4/IPv6）、DNS 服务器、默认网关、连通性探测结果作为网络诊断的必要数据保留。
- **排除字段**：用户名、Cookie、密码、私钥、本地文件路径一律不包含。

## 互联网连通性检测

应用仅对公开端点执行只读 HTTPS/TCP 连通性检测，不会修改 DNS、路由、代理、VPN 或系统网络设置。

## 联系

隐私问题请联系 kevinskysunny@gmail.com。
