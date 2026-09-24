# T-FIX-04 收口摘要

> **任务**：`T-FIX-04` check-gate-sync 缺对不得报全绿 + 覆盖度分母实算（F6/F7）
> **change**：`health-fix-2026-09b`
> **阶段**：4-dev（阶段 6 REVIEW §B 发现，同 change 回退）
> **执行者**：T-FIX-04 执行者（2026-09-24）
> **commit**：`521b21c`（5 文件 +108/-18）
> **`<verify>` rc**：0（判据缺陷由执行者上报、主 agent 修复，随后原样复跑 rc=0）

---

## 1. 目标

修复阶段 6 REVIEW（`.specs/health-fix-2026-09b/REVIEW.md` §B）发现的 `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` 两条 🟡：

- **F6**：`check_pair()` 缺 prompt/skill 文件时只打 WARNING + 裸 `return`（`ERRORS` 不增）⇒ 缺对仍打印「✅ 校验对 3/14 一致」rc=0；同时 `:204`/`:209` 用静态 `${#PAIRS[@]}` 作分母与判定依据 ⇒ 覆盖度自证与实际比对对数脱节。
- **F7**：「14」在多处硬编码；`:206` 补救文案仍说「toll-gate 协议段」（v1 已是全文比对语义）⇒ 文案与实现不一致。

## 2. 改动逐文件

### `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（+24/-12）
- **F6 修复**（`check_pair()` 缺文件分支）：
  - 旧：`echo "⚠️ WARNING: … 跳过"; return`（裸 return，`ERRORS` 不增）
  - 新：`echo "🔴 MISSING: … 文件不存在（校验对未比对）"; ERRORS=$((ERRORS + 1)); return`（计入错误，不再静默）
- **F6 修复**（分母实算）：
  - 新增 `COMPARED=0` 计数器（`ERRORS` 旁），仅在两侧文件均存在并通过比对时 `COMPARED=$((COMPARED + 1))`
  - `:204` 覆盖度行：`校验对 ${COMPARED}/${PAIRS_TOTAL}`（实际比对对数），并附 `另有 $((${#PAIRS[@]} - COMPARED)) 对因文件缺失未比对`
  - `:209` 成功行：`✅ 校验对 ${COMPARED}/${PAIRS_TOTAL} 一致（仅覆盖上述 ${COMPARED} 对…）` —— 缺对时 `ERRORS>0` 走 `:206` 分支，不打印 ✅ 一致
- **F7 修复**（常量与文案单点）：
  - `PAIRS_TOTAL=14` 常量定义（`:44`），所有文案（`:204`/`:206`/`:209`/注释 `:25`/`:32`/`:202`）一律插值引用 `${PAIRS_TOTAL}`，不再出现裸字面量 `14`
  - `:206` 补救文案改为「请同步 prompt 和 skill 的全文内容（剥离平台 front-matter 后逐行比对一致）」—— 与 v1 全文内容比对语义一致，不再指向已不存在的「协议段」比对
  - `:29` 标题行由「toll-gate 协议一致性」改为「内容一致性」

### `test/test_check_gate_sync.bats` + `flow-kit-bundle/test/test_check_gate_sync.bats`（+40/-2，双源同步）
- 新增 2 例 T-FIX-04 F6 双态判据（运行时复制真实生产件进 `mktemp -d` 夹具，禁止抄正文进 bats）：
  - **好态**「完整夹具（所有对文件齐全）→ rc=0 + 汇总打印一致」：复制真实脚本 + prompts/ + skills/ 全量，断言 rc=0 且汇总含「校验对…一致」
  - **坏态**「缺一对 skill 文件 → rc≠0 + 汇总不打印 ✅ … 一致」：隐藏 `flow-evolve/SKILL.md`，断言 rc≠0、汇总不含 `✅ 校验对…一致`、含 `MISSING`
- 头部注释更新为「3/PAIRS_TOTAL」+ T-FIX-04 收敛说明

### `.specs/STATE.md`（+2/-1）
- `test_framework` 行基线 `1023→1025`（TAP plan 1..1025）
- 新增「基线演进（T-FIX-04 收口实测）」引用行：1023 + 2 例 F6 双态

### `.specs/CONTEXT.md`（+2/-1）
- TD-029 行追加「阶段 6 REVIEW 发现（F6/F7）· 本 change 内修复（T-FIX-04）」标注与修复概述

## 3. TDD 双态证据（判别式）

### 修复前转红（原文）
**沙箱夹具**（复制未修改脚本 + prompts/ + skills/ 全量，隐藏 `flow-evolve/SKILL.md`）：
```
🔍 check-gate-sync: 校验 prompt↔skill toll-gate 协议一致性...
   校验: A-evolve ↔ flow-evolve
   ⚠️  WARNING: skill 文件不存在，跳过
   …
   ── 校验汇总 ──
   覆盖度: 校验对 3/14（…）
   ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。
rc=0
```
⇒ 缺对仍 rc=0 + 打印 ✅ 一致（F6 bug 成立）。

**bats TDD 红**（还原 pre-fix 脚本跑新用例 7）：
```
not ok 7 T02 F6: 缺一对 skill 文件 → rc≠0 + 汇总不打印「✅ … 一致」
# (in test file test/test_check_gate_sync.bats, line 88)
#   `[ "$status" -ne 0 ]                                    # 坏态必须非 0（F6 收敛）' failed
```
⇒ 新用例确实在未修复脚本上转红。

### 修复后全绿
- bats `test_check_gate_sync.bats`：7/7 ok（含 2 新双态）
- 完整夹具 rc=0 + `✅ 校验对 3/14 一致`
- 缺对夹具（隐藏 `flow-evolve/SKILL.md`）rc=1 + 汇总 `🔴 发现 1 处问题…` + 无 `✅校验对…一致`

## 4. 判据原文与 rc

### `<verify>` 原文（契约逐字）
见 `.specs/health-fix-2026-09b/TASK.md` T-FIX-04 `<verify>` 段（主 agent 修复判据缺陷后版本）。

### 判据缺陷上报与主 agent 修复
- **执行者上报**：`<verify>` F6 夹具原实现 `hidden=$(ls …/skills/*/SKILL.md | head -1)` 取字母序首个 skill = `flow-architect/SKILL.md`（**非 PAIRS 成员**，PAIRS=flow-evolve/flow-intel/flow-restyle）⇒ 隐藏非比对对成员时 MISS=0、汇总照旧 ✅ ⇒ 判据自我误报 🔴（修复后代码的正确行为被当成缺陷）。
- **主 agent 修复**（TD-065，🟡）：改为从 PAIRS 声明派生首个真实成员 `pair_skill=$(grep -oE '\|flow-[a-z0-9-]+' … | head -1 | tr -d '|')` ⇒ `flow-evolve`，保证被隐藏的确是一对中的文件。其余断言、汇总 printf、bats/门禁段逐字未动。
- **复跑 rc=0**：原样重跑修复后的 `<verify>` ⇒ `verify hides: flow-kit-bundle/skills/flow-evolve/SKILL.md`、`real=21 full_fixture=0 missing_pair=1`、rc=0。

### `<verify>` 原始输出（rc=0）
```
   （诊断）verify hides: flow-kit-bundle/skills/flow-evolve/SKILL.md
real=21 full_fixture=0 missing_pair=1
```
bats/门禁段无 🔴 输出（全 pass，静默）。

## 5. 门禁 rc 清单

| 门禁 | rc | 备注 |
|------|----|----|
| `bash -n check-gate-sync.sh` | 0 | 语法 |
| `make check-gate-sync`（真实仓） | 0 | `✅ 预设名集合一致 (17 个预设)` 正常路径自证行在位 |
| 完整夹具（mktemp -d 复制全量） | 0 | 好态 |
| 缺对夹具（隐藏 PAIRS 成员） | 1 | 坏态，汇总无 ✅ 一致 |
| `npx bats test/test_check_gate_sync.bats` | 0 | 7/7 ok（+2 双态） |
| `npx bats test/`（全量） | 0 | 1025 ok / 0 not ok |
| `make check-hooks-sync` | 0 | hooks 副本一致 |
| `make check-test-sync` | 0 | test 双源一致 |
| `make check-dist` | 0 | dist 与源一致 |
| `make check-nfr-portability` | 0 | bash 3.2 兼容，无 GNU-only |
| `make check` | 0 | `✅ make check: 全部通过` |
| `<verify>`（契约判据，主 agent 修复后） | 0 | rc=0 |

## 6. 提交

- sha：`521b21c`
- numstat：
```
521b21c fix(health-fix-2026-09b): T-FIX-04 check-gate-sync 缺对不得报全绿（F6/F7）
2	1	.specs/CONTEXT.md
2	1	.specs/STATE.md
24	12	flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
40	2	flow-kit-bundle/test/test_check_gate_sync.bats
40	2	test/test_check_gate_sync.bats
```
- 显式路径 `git add` + `git commit -m "…" -- <路径>`；未带入 5 个冻结件（`A ` 暂存态）、`MINOR-DEFERRED.md`、`REVIEW.md`、`INDEPENDENT-REVIEW-6.md`、`T-FIX-03-SUMMARY.md`。
- 本仓 `core.hooksPath` 为空串 ⇒ git hooks 未生效；门禁证据只来自显式运行命令的 rc。

## 7. 台账时点

- `.flow-active` `goal.task_progress` 追加：`{"id":"T-FIX-04","commit_sha":"521b21c","fix_rounds":0,"deferred":[],"completed_at":"2026-09-24T23:31:48+08:00"}`
- commit 时间 `2026-09-24T23:31:40+08:00`；台账 `completed_at` `2026-09-24T23:31:48+08:00`；Δ = 8s ≤ 120s（规则 9）。

## 8. 遗留与未坐实项

- **TD-065**（主 agent 登记，🟡）：`<verify>` F6 夹具样本不得用文件系统枚举的偶然顺序，必须从被测集合派生 —— 与 TD-060 同属「判据自身缺陷」家族。已由主 agent 修复本次判据，属一次性修复，不复发。
- **TD-025 / TD-034**（既有，🟡）：14 对全量同步策略、`check_gate_config_sync()` 值比较逻辑属 v2，本 task 不收（边界 DESIGN D5）。
- **TD-029**（既有，🟡）：check-gate-sync 判据错误 + 未接门禁 + 测试豁免 —— F6/F7 面已在本 task 收敛（缺对计错、分母实算、常量单点、文案对齐），但「未接门禁 + 测试豁免」的历史措辞面仍以 v2 全量覆盖为最终目标。
- **dist/**：已由 `package-dsh-plugin.sh` 重建，但 `dist/` 在 `.gitignore`（第 63 行），不入提交（同 T-FIX-03 先例）。

## 9. 没有做的事

- 未改 `check-path-privacy.sh`（T-FIX-03 已交付面）。
- 未改 `path-privacy-allowlist.txt`（T21 冻结）。
- 未改 `.specs/health-fix-2026-09b/` 下 CHANGE/REQUIREMENT/INDEPENDENT-REVIEW-*/REVIEW.md/TEST.md 既有内容。
- 未改 TASK.md 的 `<verify>` 判据（判据缺陷由主 agent 修复，TD-065）。
- 未改 `check_gate_config_sync()` 的值比较逻辑（TD-033/TD-034，v2 范围）。
- 未声称 git hooks 门禁生效（`core.hooksPath` 为空串）。
- 未提交 SUMMARY（留主 agent housekeeping）。
- 未勾 `TASK.md` 的 `status="done"` + `<done>`（留主 agent housekeeping，或本执行者收尾 —— 见下）。
