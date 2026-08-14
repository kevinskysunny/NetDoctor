# 新会话施工提示词

复制以下内容到新会话：

```text
请在 /Users/kevinsmith/Person/project/07-apps-experiments/networkconsole-lite 中施工。

先完整读取 AGENTS.md、docs/PRD.md、docs/implementation-plan.md 和 docs/appstore-checklist.md，再开始实现。

目标：实现一个只读的 macOS 网络体检 App，面向 Mac App Store。

必须覆盖：Wi-Fi、有线、VPN、DNS、默认路由、外网可达性、延迟和丢包近似。
界面：菜单栏状态图标、快速检查窗口、详情窗口、设置、本地时间线、支持包导出。
技术：Swift Package、SwiftUI、macOS 14+，优先使用 Network.framework、NWPathMonitor、NWConnection、URLSession 和只读系统接口。

硬性边界：
1. 不碰 SSH、Clash、AOne、EasyConnect、企业内网认证。
2. 不修改 DNS、路由、代理、VPN 或系统服务。
3. 不安装 LaunchDaemon、LaunchAgent、特权 Helper，不申请管理员权限。
4. 不使用 Shell、Rust 子进程、外部诊断脚本或 Process/NSTask。
5. 不硬编码企业域名、IP、证书指纹或固定端口。
6. 测试必须无真实网络依赖，使用 mock。

完成标准：
- swift build 通过。
- swift test 通过。
- 菜单栏和详情页可运行，诊断在无网络状态下也能显示明确状态。
- App Sandbox、Hardened Runtime、PrivacyInfo.xcprivacy 已配置。
- README 更新，提交并推送到 origin/main。

实现过程中如发现计划无法满足的需求，先按 PRD 的最小范围收敛，不要扩大权限或引入企业能力。
```
