# 阶段一「即刻发版防线」任务清单（tasks.md）

> 配套方案文档：`docs/design/stage1-release-guard/design.md`
> 需求来源：`docs/implementation-plan.md` M6.1；`docs/PRD.md` §8.3/§8.8/§8.9；Antigravity 复核共识。
> 评审状态：Google AI（Antigravity）复核结论【通过 (Approved)】（2026-09-27，输入见 `google-ai-review-prompt.md`）。其 3 条建议已合入本清单：① T3 同步 PRIVACY.md 日期戳（2026-09）；② T5 以 `git diff HEAD` 维度级校验 L10n key 不增删（替代人工清点）；③ 验证命令改用 `git check-ignore -v` 回显规则行号。
> 约束红线：Bundle ID / Apple ID / SKU / Team ID / 上架显示名**不可触碰**；不新增 entitlements；不新增数据收集类别。
> 执行顺序：T1 → T2/T3 → T4 → T5 验证 → T6 提交；T7 为可选项。
> 预期效果：全部完成后 `swift build` / `swift test` 全绿，`.gitignore` 拦截本地签名配置，运行时文案与隐私声明零虚假承诺。

---

## 任务总览

| ID | 代号 | 任务 | 风险 | 涉及文件数 | 验证命令 |
|----|------|------|------|-----------|---------|
| T1 | M2 | 移除 `ExportOptions.local.plist` 追踪并加入 ignore | 低 | 2 | `git ls-files` + `git check-ignore -v` |
| T2 | M4-a | 重写 zh/en `settings.privacy.item4.desc` 文案 | 低 | 1 | `grep` + `swift build` |
| T3 | M4-b | 增强 `docs/PRIVACY.md` 导出策略声明 + 日期戳同步（2026-09） | 低 | 1 | 人工核对 + `grep` 日期戳 |
| T4 | L3 | 化简 `AppModel.score` 冗余分支 | 低 | 1 | `swift build` + `swift test` |
| T5 | 验证 | 全量验证（编译/测试/git/文案/导出） | — | — | 见各任务验证方式 |
| T6 | 提交 | 分事务提交 + 文档状态同步 | 低 | git | `git log` 核对 |
| T7 | M3(可选) | 文档勾选状态同步（implementation-plan / appstore-checklist） | 低 | 3 | 人工核对 |

---

## T1 [M2] 签名配置移出版本控制

- **改动位置**：
  - git 索引：`Config/ExportOptions.local.plist`（追踪解除）
  - `.gitignore`（仓库根，追加规则）
- **改动内容**：
  1. 执行 `git rm --cached Config/ExportOptions.local.plist`（**保留工作树文件**，本地签名能力不受影响）。
  2. `.gitignore` 追加一行：`Config/*.local.plist`
- **验证方式**：
  ```bash
  git ls-files Config/                # 期望：不再输出 ExportOptions.local.plist
  git check-ignore -v Config/ExportOptions.local.plist   # 期望：命中且回显匹配规则与行号（如 .gitignore:26:Config/*.local.plist），确证 Config/*.local.plist 规则生效
  ls -la Config/ExportOptions.local.plist             # 期望：工作树文件仍在
  git status --short                  # 期望：该文件显示为已忽略，不产生 untracked 噪点
  ```
- **说明**：TC3 决议确认该文件从未打入 App 二进制，此变更为零审核风险；`Config/ExportOptions.plist`（模板）保持追踪不变。历史提交 `d7f7d9e` 中仍含敏感内容属私有库受控范围，清洗留待后续专项决策（见 design.md 风险登记）。

---

## T2 [M4-a] 重写 zh/en `settings.privacy.item4.desc` 文案

- **改动位置**：`Sources/NetworkConsoleApp/Localization.swift`
  - zh：行 213（`settings.privacy.item4.desc`）
  - en：行 464（`settings.privacy.item4.desc`）
- **改动内容**（**key 不变，仅修改 value**，保持 zh/en=248 key 基线不漂移，对齐 TC1）：

  | 语言 | 现值 | 目标值 |
  |------|------|--------|
  | zh | 支持包自动对 Wi-Fi SSID 与物理 MAC 脱敏 | 支持包导出对 SSID 做占位处理，IP、DNS 与网关等诊断字段按需保留 |
  | en | Support bundles automatically redact Wi-Fi SSIDs and hardware MAC addresses | Support export masks Wi-Fi SSIDs while keeping diagnostic fields such as IP addresses, DNS servers, and gateways |

- **不改项**（与事实一致，勿误改）：`settings.privacy.item4.title`（zh:212 / en:463）、`settings.privacy.redacted`（zh:238 / en:489）、`overview.notAvailable` 等。
- **验证方式**：
  ```bash
  grep -n "物理 MAC\|hardware MAC\|physical MAC" Sources/   # 期望：零命中
  grep -n "settings.privacy.item4.desc" Sources/NetworkConsoleApp/Localization.swift  # 期望：仅 zh/en 2 处，均为新文案
  swift build                                                 # 期望：通过
  ```
- **运行验证**（可选，人工）：启动 App → 设置 → 切换 zh/en → 第 4 柱「智能脱敏导出」显示新文案。

---

## T3 [M4-b] 增强 `docs/PRIVACY.md` 导出策略声明

- **改动位置**：`docs/PRIVACY.md`
  - 英文段「Support Package Export」：当前仅第 19 行一句，需扩展为三段式清单
  - 中文段「支持包导出」：当前仅第 49 行一句，同样扩展
- **改动内容**：追加/改写为明确的策略清单：
  1. **占位字段**：Wi-Fi SSID（无法获取时显示「未获取 / Not available」）。
  2. **保留字段**：接口 IP（IPv4/IPv6）、DNS 服务器、默认网关、连通性探测结果 —— 作为网络诊断的必要数据保留。
  3. **排除字段**（维持现值）：用户名、Cookie、密码、私钥、本地路径。
  4. **同步更新文档头部日期戳**（AG 建议①）：EN 段首行第 3 行 `Last updated: August 15, 2026` → `Last updated: September 27, 2026`；中文段首行第 32 行 `更新日期：2026年8月15日` → `更新日期：2026年9月27日`（对齐当前修订日期 2026-09-27）。注意：日期戳位于**文档开头**（两段各自头部），并非文档末尾。
- **不改项**：不新增任何“采集”数据类目表述（对齐 PRD §8.7 不新增数据收集类别）。
- **验证方式**：人工审读中英双语段落，确认「物理 MAC」字样不存在、SSID/保留字段表述与 `SupportPackageExporter.redact` 实际行为一致；`grep -c "MAC" docs/PRIVACY.md` 期望 0；日期戳同步验证：`grep -n "Last updated\|更新日期" docs/PRIVACY.md` 期望两处分别显示 `September 27, 2026` 与 `2026年9月27日`。

---

## T4 [L3] 化简 `AppModel.score` 冗余分支

- **改动位置**：`Sources/NetworkConsoleApp/AppModel.swift:107-112`
- **改动内容**：删除两个完全相同分支外围的 `if isChecking` 判断与多余 `else` 返回，简化为单一表达式（行为零变化）：
  ```swift
  var score: Int {
      report?.score ?? 100
  }
  ```
- **不改项**：`score` 属性签名、`isChecking` 枚举属性（仍被 `statusTitle` / `summaryText` / `updateStatusSymbol` 消费）、所有调用方。
- **验证方式**：
  ```bash
  swift build   # 期望：通过，无新增警告
  swift test    # 期望：16 例全绿（NetworkCoreTests 无断言 AppModel，不应有任何测试改动）
  ```
- **运行验证**（可选，人工）：启动 App → 快捷窗口/详情仪表盘分数显示与重构前一致。

---

## T5 全量验证（收口检查）

逐项执行以下检查，全部通过后进入 T6：

```bash
# 1) 编译与测试
swift build && swift test

# 2) git 泄漏面检查
git ls-files Config/ | grep -c "local"              # 期望：0
git check-ignore -v Config/ExportOptions.local.plist    # 期望：命中并回显规则与行号（证明是 Config/*.local.plist 生效）

# 3) 虚假承诺清零（限定运行时与隐私声明，审计文档 docs/ 保留）
grep -rn "物理 MAC\|hardware MAC\|physical MAC" Sources/ docs/PRIVACY.md  # 期望：零命中
grep -rn "MAC" docs/SUPPORT.md docs/PRIVACY.md       # 期望：零命中或仅中性表述

# 4) L10n key 基线（zh/en 不增删，AG 建议②）—— 提交前执行（尚未 git add / commit 时），以 git diff 对比工作树与 HEAD
git diff HEAD --stat Sources/NetworkConsoleApp/Localization.swift
#    期望：1 file changed, 2 insertions(+), 2 deletions(-)
#    （恰好 zh/en 各 1 行 value 修改；若增删行数超过 2/2 即存在意外的 key 增删）
git diff -U0 HEAD -- Sources/NetworkConsoleApp/Localization.swift | grep -E '^[+-][[:space:]]*"[a-z]'
#    期望：恰好 2 对 "+/−" 行；逐一核对每对行的 key 名完全一致、仅 value 不同（key 零增删的强证明）
git diff HEAD Sources/NetworkConsoleApp/Localization.swift
#    人工扫读：diff 仅含 settings.privacy.item4.desc（zh:213 / en:464）两处 value 变更

# 5) 隐私声明日期戳（AG 建议①，随 T3 一并核对）
grep -n "Last updated\|更新日期" docs/PRIVACY.md      # 期望：September 27, 2026 / 2026年9月27日

# 6) 工程漂移
xcodegen generate 2>&1 | tail -1                     # 期望：无 diff 输出
git status --short                                   # 期望：仅预期文件变更
```

---

## T6 提交与记录

- **提交流程**：建议按改动语义分 2 个提交（便于回溯）：
  1. `chore(security): untrack ExportOptions.local.plist and ignore *.local.plist variants`（含 `.gitignore`）
  2. `fix(privacy): align redaction copy and privacy policy with actual SSID-masking scope`（含 `Localization.swift` + `docs/PRIVACY.md` + `AppModel.swift`；git 记录若需合并由提交者决断）
  3. 推送 `origin/main`。
- **文档同步（含 T7）**：更新 `docs/implementation-plan.md` M6.1 三项勾选、`docs/appstore-checklist.md`「阶段一：即刻发版防线」三项勾选。
- **验证方式**：`git log --oneline -3` 核对提交信息与文件集合。

---

## T7 [M3·可选] 文档状态同步

- **说明**：M3 已按 TC4 决议归入阶段一，属“随文档一并完结”的收尾项；用户本次未将其列入三项目标，故标为可选，由 T6 顺带执行。
- **改动位置**：`docs/implementation-plan.md`（M6.1 三项）、`docs/appstore-checklist.md`（阶段一小节）、`docs/design/stage1-release-guard/design.md`（完成后核对）。
- **改动内容**：将完成项勾选为 `[x]`；「每步完成定义」阶段一子项如已达成可标注。
- **验证方式**：人工审读；`grep -n "阶段一" docs/appstore-checklist.md` 核对勾选状态。

---

## 预计工作量与风险提示

- 预计工作量：T1~T6 合计约 30 分钟级（纯手工核对量为主），全部为低风险单点改动。
- 关键风险与缓解：
  1. git 历史残留敏感文件（`d7f7d9e`）→ 私有仓库受控，登记在案，不做历史重写。
  2. 误增删 L10n key 导致 TC1 基线漂移 → T2/T4 均明文“key 不变”，T5 第 4 步以 `git diff HEAD` 维度级校验（期望 2/2 增删行）确证。
  3. 误改 `settings.privacy.item4.title` / `settings.privacy.redacted` 等本已准确文案 → T2 列出“不改项”清单。
  4. 误触碰上架标识 → 全部任务不含 project.yml / entitlements / Info.plist / xcconfig 改动，T5 红线核对。