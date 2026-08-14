# AGENTS.md

## 仓库意图

`NetworkConsole Lite` 是独立的只读 macOS 网络体检应用，面向 Mac App Store。它是现有企业版 `NetworkConsole` 的产品化抽象，但不应继承企业工具、Shell 后端或特权能力。

## 硬性规则

- 只读诊断，不修改 DNS、路由、代理、VPN 或系统服务。
- 不安装 LaunchDaemon、LaunchAgent、特权 Helper，不申请管理员权限。
- 不调用 `Process`、`NSTask`、Shell、Rust 子进程或外部诊断脚本。
- 不硬编码企业域名、IP、证书指纹、固定端口或本机路径。
- 不使用 AOne、EasyConnect、Clash、SSH 和企业认证相关内容。
- 不复制现有 `NetworkConsole` 中 Shell、Rust、Helper 和认证代码。
- 测试必须无真实网络依赖，使用 mock 注入。
- 默认不上传诊断数据，不启用遥测。

## 构建与测试

```bash
swift build
swift test
```

## 工作流程

- 编码前先读取 `docs/PRD.md` 和 `docs/implementation-plan.md`。
- 按实施计划完成功能并补测试。
- 提交前运行 `swift build` 和 `swift test`。
- 完成后提交并推送到 `origin/main`。
