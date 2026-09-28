# T-FIX-21 执行回执（第 5 轮 fix loop · 2026-09-28）

> 台账归一 + `TEST.md` §1.3 复算表 · findings `R5-8` / `R5-1` / `R5-2`
> HEAD（开工基线）= `e722dfe4177ef543a8bce3484e65b3def29543da`（`%cI` = 2026-09-28T06:01:48+08:00）

## §A 复算表（逐条重跑 `TEST.md` §1.3 引用命令 · 三列对照）

| # | 命令原文 | 实测数（HEAD `e722dfe` · 第 12 次执行） | 报告新值（订正后 `TEST.md`） | 旧报告值（订正前） |
|---|---|---|---|---|
| 1 | `npx bats --count test/` | **1098** | §1.3 第 2/5 条 = 1098 / 有效 1097 | 1064 / 1063（第 11 次） |
| 2a | `grep -cE '^[[:space:]]*@test' test/test_archive_commit_gate.bats` | **45** | §1.3 第 3 条 = 45 | 45（未变） |
| 2b | `grep -cE '^[[:space:]]*@test' test/test_path_privacy_gate.bats` | **34** | §1.3 第 3 条 = 34 | 30 |
| 2c | `grep -cE '^[[:space:]]*@test' test/test_nfr_portability_gate.bats` | **14** | §1.3 第 3 条 = 14 | 14（未变） |
| 2d | `grep -cE '^[[:space:]]*@test' test/test_check_gate_sync.bats` | **15** | §1.3 第 3 条 = 15 | 11 |
| 2e | `grep -cE '^[[:space:]]*@test' test/test_runtime_edit_guard.bats` | **15** | §1.3 第 3 条 = 15 | 9 |
| 3 | `git diff --name-only 534e3e8..HEAD -- test/ \| wc -l` | **15** | §1.3 第 4 条 = 15 文件 | 8（第 1 次时点）/ 12（第 11 次 HEAD 实测标注） |
| 4 | `grep -cE '^[[:space:]]*@test' test/*.bats \| awk -F: '{s+=$2} END{print s}'` | **1098** | §1.3 数量口径生成规则行 = 1098（= 收集面，口径一致） | — |

**15 文件清单**（`git diff --name-only 534e3e8..HEAD -- test/ | sort`）：
`test_archive_commit_gate.bats`、`test_auto_checkpoint.bats`、`test_check_gate_sync.bats`、`test_combined_metric.bats`、`test_correction_hygiene.bats`、`test_independent_review_model.bats`、`test_install_jq_guard.bats`、`test_install_layout.bats`、`test_l3_review_defects_2026_09.bats`、`test_lessons_cleanup.bats`、`test_nfr_portability_gate.bats`、`test_path_privacy_gate.bats`、`test_pre_push_behavior.bats`、`test_review_gate_validity.bats`、`test_runtime_edit_guard.bats`。

**演进增量归因**（1064 → 1098 = +34）：
- `test_path_privacy_gate.bats` 30 → 34 = `T-FIX-17`（`60f0835`）+4（磁盘侧检索隔离 + rev 面批量化）
- `test_check_gate_sync.bats` 11 → 15 = `T-FIX-18`（`4ce0d5e`/`467a755`）+4（缺件 fail-closed + AC-4 判别形态腿 + macOS 可移植）
- `test_runtime_edit_guard.bats` 9 → 15 = `T-FIX-19`（`40b909a`）+6（AC-1 载荷注入 + 6 副本判据常设化 · **R5-9 闭合**）
- 其余 +20 例分布：`test_install_jq_guard.bats`（新增 · `T-FIX-15`）/ `test_install_layout.bats`（新增 · `T-FIX-16`）/ `test_pre_push_behavior.bats`（新增 · `T-FIX-14`）/ `test_stop_chain.bats` / `test_l3_pipeline_fix.bats` / `test_l2_l3_fix_compliance.bats` / `test_common.bats` / `test_l3_review_params.bats` / `test_interactive_ui_check.bats` / `test_fix_l3_gate.bats` 等。

## §B TEST.md 订正清单

| 行（订正后） | 位置 | 旧值 | 新值 | 依据 |
|---|---|---|---|---|
| §1.3 第 2 条 | 收集面 | 1064/1063 | 1098/1097 | 复算表 #1 |
| §1.3 第 3 条 | 专项用例 | 45/30/14/11/9 | 45/34/14/15/15 | 复算表 #2a–2e |
| §1.3 第 4 条 | 差异面 HEAD 实测 | 12 文件 | 15 文件 | 复算表 #3 |
| §1.3 基线演进 | 第 5 轮 fix loop 后 | — | 1064→1098 = +34（七腿 T-FIX-14..20） | 复算表 #4 + 增量归因 |
| §1.3 第 5 条 | 有效口径 | 1064/1063 | 1098/1097 | 复算表 #1 |
| §1.3 数量口径生成规则行 | 新增 | — | 4 条命令原文 + 实测数 | `R5-8` 立规 |
| :54 AC-1 TD-053 行 | 回归列 | 9 用例·TD-053 已闭合 | 15 用例·R5-9 已闭合 | `R5-9` 落地（`T-FIX-19`） |

**未改动**（`R5-3` 已完成部分 · 任务 action ④ 禁动）：
- §1.1 AC-6 补记（:59 AC-6 行的 `30 用例` 等时点值——本轮 scope 仅限 §1.3 第 3/4 条 + 数量口径生成规则行；§1.1 AC 表的计数过时属 `R5-8` 同族再犯，但不在本轮写面，留给后续轮次或主 agent 裁决）
- 发现表 `#43`–`#49` 七行（:557–:563）
- `:558` 索引行
- `:63` 数量口径生成规则行（`R5-3` 立规，§1.1 AC 表后）

## §C 台账归一记录（`.flow-active` · gitignored · 不提交）

**归一前**：`goal.task_progress` len = **50**，顶层 `updated_at` = `1790546510`（epoch 整数）。

### 规则 ① 删除 `T-FIX-09` 伪条目
- 伪条目 `[37]`：`id=T-FIX-09`、`commit_sha="$(git rev-parse HEAD)"`（shell 替换未展开的字面量）、`completed_at=1790325853`（epoch）。
- 真条目 `[38]`：`id=T-FIX-09`、`commit_sha=81c920e61101f599bf9e29f7ec5bc3dbe429a887`、`completed_at=1790325860`（epoch）。
- 处置：**删除伪条目**，保留真条目。归一后 `T-FIX-09` 唯一一条，sha = `81c920e6…`。

### 规则 ② `completed_at` 归一为 `+08:00` ISO8601
| 条目 | 旧值 | 形态 | 新值 |
|---|---|---|---|
| T01 | 2026-09-23T02:04:12Z | Z(UTC) | 2026-09-23T10:04:12+08:00 |
| T02 | 2026-09-23T02:29:10Z | Z(UTC) | 2026-09-23T10:29:10+08:00 |
| T-FIX-09 | 1790325860 | epoch | 2026-09-25T16:44:20+08:00 |
| T-FIX-10 | 1790327360 | epoch | 2026-09-25T17:09:20+08:00 |
| T-FIX-11 | 1790330769 | epoch | 2026-09-25T18:06:09+08:00 |
| T-FIX-12 | 1790339356 | epoch | 2026-09-25T20:29:16+08:00 |
| T-FIX-13 | 1790507877 | epoch | 2026-09-27T19:17:57+08:00 |
| T-FIX-09(伪) | 1790325853 | epoch | **已删**（规则 ①） |

转换方法：epoch 用 `datetime.fromtimestamp(n, tz=+08:00).isoformat()`；Z(UTC) 用 `datetime.fromisoformat(ca.replace('Z','+00:00')).astimezone(+08:00).isoformat()`。

### 规则 ③ 按 `completed_at` 升序稳定排序
- 排序前顺序非单调：`T11`（2026-09-24T02:32）排在 `T12`（2026-09-23T15:47）之前。
- 排序后：全部 49 条按 `completed_at` 字符串升序（因全表统一 `+08:00` 偏移，字符串序 = 时间序）。同刻条目保持原序（Python `sorted` 稳定）。

### 规则 ④ 删除顶层 `.goal` 幽灵键
- 实测：顶层无 `.goal` 键（`'.goal' not in d` = True）⇒ **跳过**（无操作）。

### 规则 ⑤ 短 sha 展开为 40 位
- 归一前 49 条（删伪后）中有 **23 条 7 位短 sha**，全部经 `git rev-parse --verify --quiet <short>^{commit}` 解析成功，展开为 40 位。
- 解析失败者：**0 条**（唯一不可解析的 `$(git rev-parse HEAD)` 伪条目已由规则 ① 删除）。
- 展开示例：`a674c56` → `a674c56e3c03…`（T01）、`5ee4ebc` → `5ee4ebc4308d…`（T-FIX-01）等共 23 条。

### `deferred` 非空 3 条（语义不动）
| 条目 | deferred |
|---|---|
| T07 | `['T07-1']` |
| T08 | `['TC1/TC2 留v2', '11对漂移无门禁留v2/TD-025']` |
| T11 | `['dist 重建触发 check-dist 两条缺失·留打包阶段刷新(T24)']` |

### 顶层 `updated_at` 保持 epoch 整数
- 归一前 = `1790546510`（int）⇒ 归一后 = `1790546510`（int，**未动**）。
- 理由：`33-flow-active-integrity.sh:235` 做 `now - updated_at` 算术；写成 ISO 会让钩子报 `行 235: 2026-09: 值对于底数而言过大` 且 rc=1。

**归一后**：`goal.task_progress` len = **49**（50 − 1 伪条目）。

## §D 判据实跑证据

### 判据 ⑤ python 断言（归一后、append 前）
```
ALL ASSERTS PASS (pre-append)
updated_at=1790546510 (int)
```
断言项：`'.goal' not in d` ✓、无 `$( sha` ✓、全部 sha 长度 = 40 ✓、全部 `datetime.fromisoformat` 可解析 ✓、全部以 `+08:00` 结尾 ✓、`tp == sorted(tp, key=completed_at)` ✓、`deferred` 3 条保留 ✓、`T-FIX-09` 单条真 sha ✓、`updated_at` 为 int ✓。

### `npx bats --count test/`
```
1098
```

### `make check`
```
✅ bats: all tests passed
✅ shellcheck: no errors found
✅ validate: staging coverage OK
✅ test 双源一致
✅ hooks 副本一致（漂移 0）
✅ check-dist: dist 与源一致
✅ check-gate-sync: 校验通过（3/14 一致 + 17 预设名一致）
✅ 清单外命中 0 条
✅ NFR 兼容性判据通过
║  ✅ make check: 全部通过
```
**21 ✅ / 0 ❌**（bats 全量 1098 例 ok=1098 / not ok=0 / skip=0）。
