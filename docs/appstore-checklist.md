# App Store 检查清单

> 製品名称自 v1.2 起为 `NetDoctor`。
> 状态同步依据：`docs/project-review-2026-09-27.md`（M3 文档滞后问题）与 `docs/implementation-plan.md` M4/M5。

## 身份与签名

- [x] 使用独立 Bundle ID（`com.networkconsole.lite`），不用 `local.kevin.*` 或任何企业内部标识。
- [x] 配置正式 App 名称（NetDoctor）、副标题和版权信息。
- [x] 使用 App Store 分发签名（提交 `d7f7d9e` 已通过 manual signing + App Store profile 完成归档）。
- [ ] 从 git 仓库移除含实名/Team ID 的 `Config/ExportOptions.local.plist`（见实施计划 M6.1，M2）。

## 沙盒与安全

- [x] 启用 App Sandbox。
- [x] 只申请最小网络权限，不申请任意文件读写。
- [x] 启用 Hardened Runtime。
- [x] 确认代码中没有 `Process`、`NSTask`、Shell 或特权操作。
- [x] 确认没有 LaunchDaemon、LaunchAgent、Helper、root 权限。
- [x] 确认没有硬编码企业域名、IP、证书指纹或固定端口。
- [ ] 完成 SSID 沙盒实测并决策（保留需申请 WiFi entitlement，见实施计划 M6.1，H2 / PRD §8.4）。

## 隐私

- [x] 生成 `PrivacyInfo.xcprivacy`。
- [x] 明确说明诊断数据仅保存在本机。
- [ ] 在 App Store Connect 填写隐私政策 URL（内容产物：`docs/PRIVACY.md`，尚无线上域名）。
- [x] 导出支持包时脱敏，不包含系统用户名、账号、Cookie、密钥。
- [ ] 按 PRD §8.3 文档化脱敏策略（保留 IP/DNS/网关为诊断信息，SSID 必脱敏）并同步界面文案。

## 审核素材

- [x] App 图标。
- [x] App Store 多尺寸截图（产物：`docs/media/appstore/v1.1/en`、`docs/media/appstore/v1.1/zh`）。
- [ ] Review Notes：说明这是只读诊断工具，不需要企业账号或内网（草稿待补）。
- [x] 提供审核演示路径：`docs/media/review/index.html`。
- [ ] Review Notes 中说明外网探测使用的公开端点。

## 发布前自检

- [x] `swift build` 通过。
- [x] `swift test` 通过。
- [x] 归档后验证签名、沙盒和隐私清单（提交 `d7f7d9e` 完成）。
- [ ] 在干净 macOS 环境完成安装和首次启动验证。

## v1.2 发布前附加自检（源自 2026-09-27 系统检查）

- [ ] 8 种语言本地化 key 与中文基线 100% 一致为目标（v1.2 门槛：zh/en 全一致；其余语言回退英文、缺口清单可见并收敛）。
- [ ] 界面切换任一语言无中文残留；缺失 key 只回退英文，永不回退中文。
- [ ] 支持包文件名、时间线目录、User-Agent 与 NetDoctor 品牌一致。
- [ ] `NetworkConsoleAppTests` 本地化与脱敏测试通过。