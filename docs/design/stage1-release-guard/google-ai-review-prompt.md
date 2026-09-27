# Google AI 审核提示词 — 阶段一「即刻发版防线」实现方案

> 用途：将本提示词连同下方文档路径提供给 Google AI（Antigravity）进行方案复核。
> 生成时间：2026-09-27
> 审核对象提交基线：`02ccefd`（TC1~TC6 全数闭环，工作树干净）

---

## 提示词（可直接复制发给 Google AI）

```
你是一位资深的 Apple 平台架构审核专家，需要复核一个 macOS 网络诊断 App（NetDoctor，App Store v1.1 已上架，Bundle ID com.networkconsole.lite）的阶段一实现方案。请务必「实际读取」以下本仓库文件后再给出结论，不要仅凭摘要判断：

【必读文档（按优先级）】
1. docs/design/stage1-release-guard/design.md —— 阶段一实现方案设计（主审对象）
2. docs/design/stage1-release-guard/tasks.md —— 任务清单与验证步骤
3. docs/implementation-plan.md —— 重点看 M6 章节与 M6.1 阶段一
4. docs/PRD.md —— 重点看 §8.3、§8.4、§8.8、§8.9、§9
5. docs/project-review-2026-09-27.md —— 重点看第 6 节复核结论
6. docs/ai-review-handoff-summary.md —— 重点看第 7 节

【相关源码位置（供交叉核验）】
- Sources/NetworkConsoleApp/AppModel.swift:107-112（L3 score 冗余分支）
- Sources/NetworkConsoleApp/Localization.swift（zh:213 / en:464 附近，M4 文案）
- Sources/NetworkCore/SupportPackageExporter.swift:34-63（SSID 脱敏逻辑）
- Config/ExportOptions.plist（签名模板）与 Config/ExportOptions.local.plist（待移除的本地配置）
- .gitignore（T1 规则追加位置）

【本次方案覆盖的 3 项任务】
- T1 [M2]：git rm --cached 移除 ExportOptions.local.plist + .gitignore 追加 Config/*.local.plist
- T2/T3 [M4]：剔除设置页"物理 MAC 脱敏"虚假承诺；PRIVACY.md 明确 SSID 占位 + IP/DNS/网关作为诊断数据保留
- T4 [L3]：化简 AppModel.score 冗余双重分支

【硬性约束（评审时必须校验方案是否触碰红线）】
- 不可修改 Bundle ID / Apple ID / SKU / Team ID / 上架显示名
- 不新增 entitlements（尤其不得申请 com.apple.developer.networking.wifi-info）
- 不新增数据收集类别；不调用 Process/NSTask/Shell；测试无真实网络依赖
- 本地化 key 只允许改值、不允许增删 key（保持 zh/en 248 baseline；TC1 决议）

【请重点回答】
1. 三项任务的方案是否存在逻辑漏洞、遗漏文件或破坏性影响？
2. T1 移除本地签名配置后，是否会影响现有签名/导出流程？工程图（project.yml/xcodeproj）是否需要联动？
3. T2 文案改写是否与 PRIVACY.md、App Store「App 隐私」问答声明保持一致？
4. T4 化简后 score 语义是否与 Xcode 工程目标、测试断言、UI 渲染完全一致？
5. 方案是否违反上述任何硬性约束？
6. 是否存在需要补充进 tasks.md 的遗漏步骤或新风险？

【输出格式】
按上述 6 问逐条给出：结论（通过/需修改）+ 依据（引用你读取到的文件具体行号或证据）+ 修改建议（如适用）。末尾给出对你判断 T5 验证方式与 T6 提交拆分的意见。
```

---

## 使用说明

1. 复制上方【提示词】代码块全文，直接粘贴给 Google AI。
2. 确保 Google AI 具有本仓库的读取权限（该提示词假设其可访问仓库文件系统）。
3. 若 Google AI 无法读取仓库，改为将下述文件内容粘贴给它：`design.md`、`tasks.md`、`implementation-plan.md`、`PRD.md`（§8 相关段落）。