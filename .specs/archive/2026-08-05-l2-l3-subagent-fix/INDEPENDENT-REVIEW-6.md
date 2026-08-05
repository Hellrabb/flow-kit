# 独立审查 · 阶段 6

## L2 盲审

### 结论
Verdict: pass（4×🟡 Important 入 fix loop，无 🔴 Critical）

### 独立验证记录

| # | 命令 | 实测输出摘要 |
|---|---|---|
| V1 | `bash -n flow-kit-bundle/hooks/stop/lib/l2-detect.sh` | SYNTAX_OK |
| V2 | env 探测（变量名+set/unset，值未读） | `ANTHROPIC_AUTH_TOKEN=unset / ANTHROPIC_API_KEY=unset / OPENCODE_BIN=unset`；`command -v opencode` → 命中（`/home/hellrabbit/.opencode/bin/opencode`） |
| V3 | 实际调用 `l2_dispatch_agent 6 ...`（source lib，沙箱目录） | opencode 分支：输出 `no API credentials` + `opencode 检测到：…category=…` → rc=1；PATH 隐藏 opencode 后：claude code 分支提示 → rc=1。两分支行为与工件描述一致 |
| V4 | AC-1/2/3 锚点独立 grep ROOT-CAUSE.md | 五段 `^##` = 5（≥5 ✓）；四环节锚点 = 8（≥4 ✓）；`实测` = 3（≥2 ✓）；`risk: (low\|high)` = 7（≥1 ✓）；5 份 EVIDENCE 全部非空（47/71/58/60/58 行） |
| V5 | `npx bats test/`（AC-5 全量） | **exit 0 · 692 ok · 0 not ok · plan 1..692**（与工件声明一致，本盲审独立实测确认，非采信） |
| V6 | 修复落点检查 | `.flow-active.goal` = `{"l2_model":"deepseek-v4-flash","l3_model":"deepseek-v4-flash"}` ✓；`~/.config/opencode/agents/qa-expert.md` `model: inherit` ✓；`git diff --stat` = 仅 l2-detect.sh +10 / CONTEXT.md +6，无禁动清单文件命中 ✓ |
| V7 | 调用链/可达性核查 | `l2_dispatch_agent` 生产调用点仅 `gate-checks-basic.sh:53,63`（PreToolUse 链）；Stop 29 号仅调 `l2_dispatch_prompt`（29:161）；本仓库 `.claude/settings.local.json` = `{"hooks":{}}`、无 `.opencode/hooks/`、无 opencode.json 插件 → opencode 下 PreToolUse 不触发 |
| V8 | 提示知识传播核查 | `grep category\|unspecified-high` 于 `prompts/independent/L2-blind-review.md`、`OPENCODE-INSTALL.md` → **0 命中**；阶段 prompt 仍写 `subagent_type: qa-expert/code-reviewer`（1-requirement.md:85 / 5-test.md:52 / 6-review.md:105） |
| V9 | 新提示测试覆盖核查 | `grep 'opencode 检测到\|claude code 检测到\|no API credentials' test/*.bats` → **0 命中**；AC-5b 仅断言 rc=1，未断言提示输出；`test/` ↔ `flow-kit-bundle/test/` 双源同步 ✓ |
| V10 | 凭证脱敏扫描（AC-2 NFR） | 全 artifacts grep `sk-`/Bearer/x-api-key 值 → 0 真命中（唯一命中为 "task-capability" 假阳性）✓ |
| V11 | 证据内部一致性 | EVIDENCE-5 结论2 称「model: inherit 可正常拉起 + D5② 修复后阶段1/5 可拉起」；EVIDENCE-3 步骤3 + DEV-SUMMARY 鉴别实验称 `task(subagent_type=architect-reviewer)`（inherit，阶段2/3 用过）→ **30min 超时、agent=undefined、与 model 值无关**，且阶段 2/3 成功实为 category=unspecified-high 路径 → **EVIDENCE-5 结论2 被其姊妹证据证伪，未修订** |

### 发现

- [🟡 Important] R6 · 平台身份探测不可靠：`command -v opencode` 只证明「机器装了 opencode」，不证明「当前运行时是 opencode」。本机 opencode 在 PATH 上（V2），claude code 会话在此机同样命中 opencode 分支 → claude code 用户拿到 category= 指引（对 CC 的 Agent 工具无意义）。else 分支在本机是死分支。且代码首判 `OPENCODE_BIN`（视为可靠信号）在本机 opencode 运行时实为 unset（V2），探测实际靠 PATH 兜底——两个信号源对一个布尔量，信号语义与实现错位。 · `flow-kit-bundle/hooks/stop/lib/l2-detect.sh:176`
- [🟡 Important] R3/R2 · 知识重复且已漂移：提示声称「opencode 下拉起走 category 路由」——但主 agent 实际遵循的阶段 prompt 派发指令仍是 `subagent_type: qa-expert/code-reviewer`（1-requirement.md:85 / 5-test.md:52 / 6-review.md:105），即 ROOT-CAUSE 根因 #2 判定的挂起路径。该工作路径知识仅存在于本提示字符串，未传播到 L2-blind-review.md（l2-detect.sh:119 SYNC-POINT 标注的对齐目标，0 命中）与 OPENCODE-INSTALL.md（V8）。v1 后 opencode 主 agent 照 prompt 派发仍 30min 挂起；「拉得起」依赖 agent 恰好读到 hook stderr。同时「/flow model l2=<model> 兜底」句在同文件重复 3 处（L177/L179/L230）。 · `flow-kit-bundle/hooks/stop/lib/l2-detect.sh:177` + `flow-kit-bundle/flow-kit/prompts/6-review.md:105`
- [🟡 Important] R5/实效性 · 目标平台不可达：新提示的唯一生产触发点是 PreToolUse gate 链（gate-checks-basic.sh:53,63），而 opencode 下 PreToolUse 结构性不触发（本仓库 settings.local.json hooks={}、无桥接插件，V7；ROOT-CAUSE 根因 #1 自证）。DEV-SUMMARY/TEST.md 的「实测输出」为手动 shell 调用（V3 复现同一路径），非真实 opencode 失败路径触发。即：该变更在它要服务的平台（opencode 凭证缺失）上不会发出提示，「非静默失败」目标未达成；实际受益者只剩 claude code 侧（且受 R6 误判影响）。无功能回归，属实效性缺口。 · `flow-kit-bundle/hooks/stop/lib/l2-detect.sh:174-184` ← 调用点 `flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh:53`
- [🟡 Important] 证据链内部矛盾（AC-2 完整性）：EVIDENCE-5 结论2 断言「qa-expert model 分歧为唯一分歧点 → sonnet→inherit 修复后阶段 1/5 可正常拉起（对照 architect-reviewer 已验证）」；同一证据库的 EVIDENCE-3 步骤3 鉴别实验与 DEV-SUMMARY 却实测 `subagent_type=architect-reviewer`（inherit）30min 超时、`agent=undefined`，且阶段 2/3 成功实为 category 路由——EVIDENCE-5 将 category 路由的成功误归因于「inherit 可拉起 subagent_type」，与鉴别实验直接互斥且未修订。ROOT-CAUSE 合成正确（根因 #2 = 与 model 值无关），但证据语料自相矛盾，后续读者单看 EVIDENCE-5 会得到错误结论，违反 AC-2「禁止无证据猜测」的证据真实性精神。 · `.specs/l2-l3-subagent-fix/EVIDENCE-5-claude-code.md`（结论2）vs `EVIDENCE-3-opencode-prompt-dispatch.md`（步骤3）
- [🟢 Minor] R4 · 平台探测为纯 env 凭证检查引入 PATH 状态依赖；OPENCODE_BIN 与 command -v 双信号源语义不清（见 R6）。新增 4 行赋值+分支本身可读，无认知过载。 · `flow-kit-bundle/hooks/stop/lib/l2-detect.sh:175-180`
- [🟢 Minor] CONTEXT.md 追加块嵌套：l2-l3-subagent-fix 术语块（L557-562）位于 td072-lib-split-2026-08 块的 ↓/↑ 标记对内部（L555-563）。按 ID 匹配的工具无碍，但泛化 ↓/↑ 配对扫描工具会把 l2-l3 条目误归 td072 范围（如清理 td072 块时连带删除）。 · `.specs/CONTEXT.md:557-562`

### Spec 合规判定（对照 REQUIREMENT.md）

- **AC-1 ✅**：五段 + 四环节锚点独立验证通过（V4），每环节均有证据引用。
- **AC-2 ⚠️**：结构满足（≥2 实测、脱敏干净 V10），但证据语料存在 EVIDENCE-5 与 EVIDENCE-3/DEV-SUMMARY 的互斥结论（发现 #4），完整性受损。
- **AC-3 ✅**：7 方案全 risk 标注，high 项（D5-③/④/⑤）正确归 v2 未实施。
- **AC-4 ⚠️**：三项 low 修复落点独立核实（V6）；「opencode 实测拉起 L2」经 category 路由真实运行时达成（4s + 阶段 2/3/5 产物回写），mock 边界合规。但代码层修复在 opencode 不可达（发现 #3），「拉起不断裂」实际依赖预存在的 category 路径而非本次 diff。
- **AC-5 ✅**：独立实测 692 ok / 0 not ok / exit 0（V5）。
- **范围**：diff 仅 l2-detect.sh + CONTEXT.md（均在 v1 范围），无 out of scope 内容；禁动清单零命中（V6）。新提示输出仅失败路径且遵循 `[l2-dispatch]` 前缀契约，性能影响可忽略（command -v 仅在凭证缺失分支执行）。

**盲审说明**：无 🔴 → 放行；4 项 🟡 建议进入 fix loop（优先级：证据矛盾修订 > 提示可达性/平台身份 > prompt 派发指令同步）。

## 主 agent 响应（修代码优先协议 · 2026-08-05）

| 发现 | 级别 | 处置 | 证据 |
|---|---|---|---|
| #1 R6 平台身份探测不可靠 | 🟡 | **Fixed in**: `l2-detect.sh:176` 移除 `\|\| command -v opencode`；仅 `OPENCODE_BIN` 显式信号走 opencode 分支；默认分支=claude code（生产可达主路径）+ opencode 备选指引覆盖两平台场景 | `bash -n` SYNTAX_OK；默认分支（`OPENCODE_BIN=`）输出「claude code 检测到」+rc=1；显式信号（`OPENCODE_BIN=/x`）输出「opencode 检测到」+rc=1 |
| #2 R3/R2 知识重复且漂移 | 🟡 | **Partial Fixed + Tech-debt**: 代码侧 `_model_hint` 抽取消除 L177/L179 逐字重复（l2-detect.sh）；prompt 层漂移（1/5/6-*.md subagent_type + L2-blind-review.md SYNC-POINT 未同步 category 知识）→ **Tech-debt**：本次 `write_files` 不含 prompt 文件，属 D5-⑦ 范畴，归 v2 | l2-detect.sh edit；v2 计划：D5-⑦ 落地时同步 prompts/{1,5,6}-*.md + L2-blind-review.md |
| #3 R5/实效性 目标平台不可达 | 🟡 | **Tech-debt**: 结构性限制（opencode 无 PreToolUse hook 事件，根因 #1 自证），非代码层可修复。**修复③价值重新定位**：生产可达场景=claude code 凭证缺失（hook 链触发）+ opencode 手动调用/未来桥接（D5-③ v2）；「opencode 非静默失败」完整达成依赖 v2 桥接插件 | DEV-SUMMARY.md「阶段 6 L2 盲审发现处置」表登记；v2 路径=D5-③ gate 桥接插件 |
| #4 证据链内部矛盾（AC-2） | 🟡 | **Fixed in**: EVIDENCE-5-claude-code.md 结论2 + 现象段修订——明确 `inherit` 非 subagent_type 拉起机制；阶段 2/3 成功实为 category 路由（交叉引用 EVIDENCE-3 步骤3 + DEV-SUMMARY 鉴别实验段） | EVIDENCE-5-claude-code.md L44-45 + L52-62 |
| 🟢 R4 平台探测 PATH 状态依赖 | 🟢 | **Fixed**: 随 #1 修复消除（command -v 探测已移除） | 同 #1 |
| 🟢 CONTEXT.md 追加块嵌套（L557-562） | 🟢 | **Deferred**: 登记阶段 6 MINOR-DEFERRED.md；泛化扫描工具误归风险低（ID 匹配工具无碍），7-integration 归档时重排标记 | MINOR-DEFERRED.md 阶段 6 分区 |

**修代码优先协议合规**：3/4 🟡 对应代码/证据修复（#1/#4 Fixed，#2 部分Fixed）；1/4（#3）为结构性限制 Tech-debt（含明确 v2 路径 + 价值重新定位，非「仅文档了事」）。源码级发现 3 条中 2 Fixed / 1 Tech-debt（33%）< 50% 阈值。范围约束：未越界改 prompt 文件（write_files 边界遵守）。

**verify 复跑**：`bash -n` SYNTAX_OK；两分支（默认/OPENCODE_BIN）行为符合预期；`npx bats test/` 692 ok / 0 not ok（修复无损基线，AC-5b 等 l2 相关测试全绿）。
