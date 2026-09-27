# App Store 检查清单

> 製品名称自 v1.2 起为 `NetDoctor`。
> 状态同步依据：`docs/project-review-2026-09-27.md`（§6 Antigravity 复核结论）、`docs/implementation-plan.md` M4/M5/M6、`docs/PRD.md` §8.8~§8.9。

## 身份与签名

- [x] 使用独立 Bundle ID（`com.networkconsole.lite`），不用 `local.kevin.*` 或任何企业内部标识。
- [x] 配置正式 App 名称（NetDoctor）、副标题和版权信息。
- [x] 使用 App Store 分发签名（提交 `d7f7d9e` 已通过 manual signing + App Store profile 完成归档）。
- [x] v1.1 已上架可分发（App Store Connect：显示名 `NetDoctor: Network Diagnostics`，主要语言英语·美国，类别工具）。

## 不可变标识符（合规红线，任何版本禁止修改）

- [x] Bundle ID `com.networkconsole.lite`（变更将被苹果视为全新 App，存量用户断联）。
- [x] Apple ID `6801707344` / SKU `networkconsole-lite-0001` / Team ID `J84LGFK7GY`（后端标识，不可变）。
- [ ] 归档前自动校验上述标识与 v1.1 上架记录一致（进入每步完成定义）。

## 沙盒与安全

- [x] 启用 App Sandbox。
- [x] 只申请最小网络权限，不申请任意文件读写。
- [x] 启用 Hardened Runtime。
- [x] 确认代码中没有 `Process`、`NSTask`、Shell 或特权操作。
- [x] 确认没有 LaunchDaemon、LaunchAgent、Helper、root 权限。
- [x] 确认没有硬编码企业域名、IP、证书指纹或固定端口。
- [x] **SSID 决策为刚性结论（Antigravity 复核）**：绝不申请 `com.apple.developer.networking.wifi-info`（高风险敏感特权，只读工具申请极大概率被拒并引发连带盘问）；维持沙盒现状，SSID 空值优雅降级为"未获取 / Not available"。

## 隐私

- [x] 生成 `PrivacyInfo.xcprivacy`。
- [x] 明确说明诊断数据仅保存在本机。
- [ ] 在 App Store Connect 填写隐私政策 URL（内容产物：`docs/PRIVACY.md`，尚无线上域名）。
- [x] 导出支持包时脱敏，不包含系统用户名、账号、Cookie、密钥。
- [ ] **[M4] 按 PRD §8.3 修正脱敏文案**：剔除"物理 MAC 脱敏"虚假承诺；明确 IP/DNS/网关作为诊断字段保留、SSID 优雅占位；同步 `docs/PRIVACY.md` 与设置页文案。

## 审核素材

- [x] App 图标。
- [x] App Store 多尺寸截图（产物：`docs/media/appstore/v1.1/en`、`docs/media/appstore/v1.1/zh`）。
- [ ] Review Notes：说明这是只读诊断工具，不需要企业账号或内网（草稿待补；v1.2 变更说明见实施计划 M6.2）。
- [x] 提供审核演示路径：`docs/media/review/index.html`。
- [ ] Review Notes 中说明外网探测使用的公开端点。

## 发布前自检

- [x] `swift build` 通过。
- [x] `swift test` 通过。
- [x] 归档后验证签名、沙盒和隐私清单（提交 `d7f7d9e` 完成）。
- [ ] 在干净 macOS 环境完成安装和首次启动验证。

## 三阶段发布防线（对齐 Antigravity 复核排期）

### 阶段一：即刻发版防线（先于任何版本归档）

- [x] **[M2]** `Config/ExportOptions.local.plist` 已从 git 索引移除并加入 `.gitignore`。
- [x] **[M4]** 脱敏/隐私文案已修正（无"物理 MAC"表述，SSID 占位一致）。
- [x] **[L3]** `AppModel.score` 冗余分支已清理，`swift build && swift test` 通过。
- [x] **[TC3]** 阶段一是否独立 hotfix（v1.1.1，构建 6）或并入 v1.2 已确认。

### v1.2 发布前附加自检（阶段二交付物）

- [x] **[H3]** 诊断文案类型化枚举完成，无中文 switch 匹配残留；测试不再断言中文字面。
- [x] **[H4]** `NetworkConsoleAppTests` 通过（zh/en key 完整性、语言解析、本地化映射、脱敏边界）。
- [x] **[M1]** 支持包前缀、User-Agent、存储目录/key 与 NetDoctor 品牌一致（Bundle ID 等红线未动）。
- [x] **[H1 第一批]** ja 缺口已补齐（以 TC1 重新核实的缺口清单为准），兜底链固定为 dict → en。
- [x] 界面切换任一语言无中文残留；缺失 key 只回退英文，永不回退中文。

### v1.3 后续自检（阶段三，不阻塞 v1.2）

- [x] **[H1 第二批]** ko/de/fr/es/pt 缺口清零，8 语言 100% 覆盖。
- [x] **[L1/L2/L5/L7]** 文件拆分、私网判断简化、写序加固、CI 门禁完成。

## 待 Antigravity 确认事项（全数复核结项，见 PRD §9 / 实施计划 M6.4）

- [x] TC1：H1 缺口统计已核实 100% 精确（zh 248, en 248, ja 缺 84, 其余 5 语各缺 117）。
- [x] TC2：L3 阶段归属确认（保留在阶段一顺手清理）。
- [x] TC3：阶段一合并入 v1.2 发布（构建号 6），不独立发 hotfix。
- [x] TC4：M3 并入阶段一；L6 并入 M1（阶段二）；L4/L8 归入阶段三。
- [x] TC5：H3 改造后支持包 SchemaVersion 维持 1，无破坏性结构变更。
- [x] TC6：M1 时间线目录采用“启动时一次性安全搬迁（One-time Move）”。