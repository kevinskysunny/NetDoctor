# NetworkConsole Lite（网络体检）

一个面向 Mac App Store 的只读网络体检应用。当前仓库已完成产品规划与交接准备，尚未开始代码施工。

## 产品定位

- 普通 Mac 用户和轻度运维用户快速了解网络是否正常。
- 覆盖 Wi-Fi、有线、VPN、DNS、默认路由、外网可达性、延迟和丢包。
- 只读诊断，不修改任何网络配置。

## 硬性边界

- 不使用 SSH、Clash、企业内网认证。
- 不修改 DNS、路由、代理、VPN 或系统服务。
- 不安装 LaunchDaemon，不申请管理员权限，不安装特权 Helper。
- 不调用 Shell、Rust 子进程或外部诊断脚本。

## 目标架构

- Swift Package，macOS 14+，SwiftUI。
- `NetworkCore`：模型、采集、诊断、导出。
- `NetworkConsoleApp`：菜单栏状态和详情窗口。
- 使用 `Network.framework`、`NWPathMonitor`、`NWConnection`、`URLSession` 和只读系统接口。

## 构建与测试

```bash
swift build
swift test
```

## 规划文档

- [PRD](./docs/PRD.md)
- [实施计划](./docs/implementation-plan.md)
- [App Store 检查清单](./docs/appstore-checklist.md)
- [新会话施工提示词](./docs/new-session-prompt.md)
