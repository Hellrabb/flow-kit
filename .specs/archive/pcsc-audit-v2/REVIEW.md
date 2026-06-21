# REVIEW: PCSC/PG 双层防护全面审计

- **Change ID**: pcsc-audit-v2
- **审计日期**: 2026-06-22
- **审计范围**: 7 prompt + GO.md + test + install 脚本

---

## A · Prompt 指令逻辑漏洞

### A1 · 🔴 Critical — 0-change 没有 PCSC 段

- **位置**: `flow-kit/prompts/0-change.md`
- **问题**: Phase 0（变更提案）有 Pipeline Toll-Gate（0→1）但没有 Phase Completion Self-Check 段。AI 可以直接跳到 toll-gate 执行 transition jq，无需自检 CHANGE.md 是否真的写入了。
- **影响**: `--from 0` pipeline 的第一个阶段就没有防护。
- **修复**: 在 0-change.md 的 toll-gate 之前插入 PCSC 段，产物清单：`CHANGE.md` 已写入 + Why/What/影响面/排除/验收线 五个必填段齐全。

### A2 · 🟡 Major — 阶段 1/2/3 的 toll-gate 没有 auto_advance 引用

- **位置**: `1-requirement.md:66`, `2-design.md:216`, `3-task.md:139`
- **问题**: PCSC 的 auto_advance 分支说"全 ✅ → 自动 transition"，但下方的 toll-gate 段仍然写"**停下来。必须等待用户回复。禁止自动继续。**"，且没有像 5-test/6-review 那样的"若 `true` → 已在 PCSC 处理"分支。
- **影响**: auto_advance=true 时，AI 面对两个矛盾的指令：PCSC 说"自动 transition"，toll-gate 说"停下来"。AI 可能选择停下来，破坏全自动流程。
- **修复**: 在 1/2/3 的 toll-gate 段开头加上与 5-test/6-review 一致的 auto_advance 分支检查。

### A3 · 🟢 Minor — 4-dev toll-gate 选项 4 与 PCSC auto_advance 冗余

- **位置**: `4-dev.md:~102`
- **问题**: toll-gate 仍提供选项 4 "💨 全自动推进 → auto_advance=true"。但 PCSC 的 auto_advance 分支已经在该选项被选中后生效。两者共存不矛盾，但选项 4 的说明（"后续 toll-gate 不再暂停"）已不准确——PCSC 仍会在 auto_advance=true 时跑自检。
- **修复**: 更新选项 4 的说明为"后续 toll-gate 自动推进（PCSC 自检仍执行，全 ✅ 自动过，有 ❌ 暂停）"。

---

## B · PCSC 检查项覆盖

### B1 · 🟡 Major — 7-integration 缺少 Sub-goal 汇总（AC-12）

- **位置**: `7-integration.md:38` PCSC 表
- **问题**: Prompt 中有"### Sub-goal 汇总（AC-12）"强制段，但 PCSC 表格未列入。AI 可能跳过 sub-goal 汇总直接执行 pipeline 完成。
- **修复**: PCSC 表格新增第 8 项："Sub-goal 汇总已完成（AC-12，若 phase_sub_goals 非空）"。

### B2 · 🟢 Minor — 7-integration 缺少"出 PR"步骤

- **位置**: `7-integration.md:38` PCSC 表
- **问题**: Prompt 步骤 6 为"### 6. 出 PR（可选）"。虽然是可选项，但 PCSC 未提及，AI 可能完全忽略。
- **修复**: PCSC 加一行："PR 已提交（如适用）| 人工确认 | ✅ / N/A"

### B3 · 🟢 Minor — 4-dev PCSC 未显式检查 6 维 self-review

- **位置**: `4-dev.md:88` PCSC 表
- **问题**: 原 4-dev 自检清单要求"6 维 self-review 跑了（/brooks-review 或内置 6 维快查）"。PCSC 通过"SUMMARY.md 存在"间接覆盖，但未显式检查 self-review 是否完成。AI 可能写入不含 self-review 结果的 SUMMARY。
- **修复**: PCSC 细化第 3 项为"所有 verify 通过 + 6 维 self-review 已完成（brooks-review 或内置 6 维快查）"。

### B4 · 🟢 Minor — 5-test PCSC 未显式列出 1.1 测试矩阵 + 1.2 UAT 脚本

- **位置**: `5-test.md:32` PCSC 表
- **问题**: 测试矩阵（1.1）和 UAT 脚本（1.2）是第 1 轮功能测试的子步骤，PCSC 通过"第 1 轮已完成"间接覆盖。不构成漏洞，但可追溯性稍弱。
- **修复**: 可选项——将 PCSC 第 1 轮拆细，或保持现状（简洁优先）。

---

## C · GO.md PCG 路由盲区

### C1 · 🟡 Major — PCG Phase 4 只检查 TASK.md，不检查 SUMMARY 文件

- **位置**: `GO.md:156` PCG 产物清单
- **问题**: Phase 4 的描述写"TASK.md（含各 task 的 *-SUMMARY.md）"，但验证命令仅 `test -s .specs/$CHANGE_ID/TASK.md`，不检查 SUMMARY 文件是否存在。AI 可以完成所有 task 但不写 SUMMARY，PCG 仍然放行。
- **影响**: 第二层防护对 Phase 4 的 SUMMARY 文件缺失无效。
- **修复**: 验证命令改为复合检查：`test -s .specs/$CHANGE_ID/TASK.md && ls .specs/$CHANGE_ID/T*-SUMMARY.md >/dev/null 2>&1`。

### C2 · 🟢 Minor — PCG 不在 transition 执行时触发，延迟到下次路由

- **位置**: `GO.md:140` PCG 触发条件
- **问题**: Transition jq 在 prompt 内执行（同一 turn），PCG 在下一次 `/flow-go` 时才触发。这意味着同一 turn 内的阶段跳过，PCG 无法实时拦截——它只能在下一次路由时发现。
- **影响**: 低。PCSC（第一层）在同一 turn 内拦截；PCG 作为第二层补漏，延迟一拍是可接受的。且大部分 pipeline 场景中用户会在每个阶段后说"继续"。
- **修复**: 无需修复（设计如此）。可在 PCG 文档中显式标注"下一 turn 拦截"特性。

### C3 · 🟢 Minor — PCG 产物清单缺少 7-integration 的最终检查

- **位置**: `GO.md:150` PCG 产物清单
- **问题**: PCG 表以 phase 6 为最后一阶段。Phase 7 是 pipeline 完成，不出现在 PCG 表中（因为不需要 transition 到下一阶段）。但 Phase 7 完成后若有人手动回退再推进，缺少 phase 7 的产物检查。
- **影响**: 极低——Phase 7 是终点，不存在 7→X 的 transition。
- **修复**: 无需修复。可考虑在 PCG 说明中加一行"N/A（最终阶段，无 exit gate）"。

---

## D · 安装脚本影响

### D1 · 🟡 Major — 安装脚本未显式同步 GO.md + prompt 文件

- **位置**: `flow-kit-bundle/lib/install_core.sh`
- **问题**: `install_core.sh` 使用目录级复制（如 `cp -r flow-kit/ $TARGET/`），而非逐文件列表。好处是所有文件自动覆盖；坏处是如果 GO.md 或 prompt 文件被意外删除或改名，安装不会报错——静默跳过。
- **影响**: 低——当前所有文件都存在，目录复制是可靠的。但缺乏文件级校验。
- **修复**: 可选项——在 install_core.sh 末尾加 `test -f "$TARGET/GO.md" && test -f "$TARGET/prompts/1-requirement.md"` 等 sanity check。

### D2 · 🟢 Minor — 无 post-install 校验步骤

- **位置**: `install.sh` 整体流程
- **问题**: 安装完成后无自动化校验（如 bats test）。新增的 `test_phase_gate.bats` 可以在安装后自动跑以验证 prompt 完整性。
- **修复**: install.sh 末尾加可选的 `--self-test` flag 触发 `npx bats test/`。

---

## 汇总

| # | 维度 | 严重度 | 简述 |
|---|---|---|---|
| A1 | Logic | 🔴 Critical | 0-change 没有 PCSC 段 |
| A2 | Logic | 🟡 Major | 1/2/3 toll-gate 缺少 auto_advance 分支 |
| B1 | Coverage | 🟡 Major | 7-integration 缺少 Sub-goal 汇总 |
| C1 | PCG | 🟡 Major | Phase 4 PCG 不检查 SUMMARY 文件 |
| D1 | Install | 🟡 Major | 安装脚本无文件级校验 |
| A3 | Logic | 🟢 Minor | 4-dev toll-gate 选项 4 说明过时 |
| B2 | Coverage | 🟢 Minor | 7-integration 缺少"出 PR"步骤 |
| B3 | Coverage | 🟢 Minor | 4-dev PCSC 未显式检查 self-review |
| B4 | Coverage | 🟢 Minor | 5-test 矩阵/UAT 子步骤未展开 |
| C2 | PCG | 🟢 Minor | PCG 延迟到下次路由触发 |
| C3 | PCG | 🟢 Minor | PCG 表无 phase 7 |
| D2 | Install | 🟢 Minor | 无 post-install 自检 |

**总计**: 1🔴 + 4🟡 + 7🟢 = 12 项发现
