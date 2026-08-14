# App Store 检查清单

## 身份与签名

- [ ] 使用独立 Bundle ID，不用 `local.kevin.*` 或任何企业内部标识。
- [ ] 配置正式 App 名称、副标题和版权信息。
- [ ] 使用 App Store 分发签名，不能只做 ad-hoc 验证。

## 沙盒与安全

- [ ] 启用 App Sandbox。
- [ ] 只申请最小网络权限，不申请任意文件读写。
- [ ] 启用 Hardened Runtime。
- [ ] 确认代码中没有 `Process`、`NSTask`、Shell 或特权操作。
- [ ] 确认没有 LaunchDaemon、LaunchAgent、Helper、root 权限。
- [ ] 确认没有硬编码企业域名、IP、证书指纹或固定端口。

## 隐私

- [ ] 生成 `PrivacyInfo.xcprivacy`。
- [ ] 明确说明诊断数据仅保存在本机。
- [ ] 准备隐私政策 URL。
- [ ] 导出支持包时脱敏，不包含系统用户名、账号、Cookie、密钥。

## 审核素材

- [ ] App 图标和多尺寸截图。
- [ ] Review Notes：说明这是只读诊断工具，不需要企业账号或内网。
- [ ] 提供审核演示路径：无网络、Wi-Fi、有线、VPN 场景。
- [ ] 说明外网探测使用的公开端点。

## 发布前自检

- [ ] `swift build` 通过。
- [ ] `swift test` 通过。
- [ ] 归档后验证签名、沙盒和隐私清单。
- [ ] 在干净 macOS 环境完成安装和首次启动验证。
