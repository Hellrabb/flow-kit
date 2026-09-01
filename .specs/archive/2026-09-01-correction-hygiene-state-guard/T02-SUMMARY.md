# T02-SUMMARY — 33-flow-active-integrity.sh 去重/健康清零/外来让位

## What

3 changes, all in `flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh` (write_files 边界 = 该文件 ONLY):

1. **AC-1/AC-2 去重+容量** (`_fai_append_violation`): 每次 append 成功后执行 `correction_file_dedupe` + `correction_file_trim <file> 10`（复用 T01 已落地的 lib 函数，未重实现）。两者 fail-open（`|| true`，append 已成功）。lib 通过新增私有 helper `_fai_ensure_correction_lib()` 幂等 source（`type correction_file_dedupe` 探测；`${HOOK_BASE_DIR:-${BASH_SOURCE%/*}}` + `2>/dev/null || true`）。
2. **AC-3/D3 健康清零**: 主函数退出点（5 个 check 全部跑完、无违规）且 `.flow-active` 为合法 JSON（入口 `jq empty` 已通过）时，调用新 helper `_fai_clear_whitelist <file>` 单次 jq pass 过滤掉白名单类 violation（atomic mktemp+mv，幂等）。移除 N>0 时 stderr 审计行 `state-integrity cleared N items`。D3 标志：main 顶部 `local _FAI_APPENDED=0`，`_fai_append_violation` 入口 `_FAI_APPENDED=1`（bash 动态作用域），抑制退出点清零。
3. **AC-5/6/D5/D6 外来让位**: 重写入口 `jq empty` 失败分支（不再 append corrupt_json）。33 号单一 actor：① `_fai_clear_whitelist` 清空白名单类（AC-10 compliance/l2-missing/model-missing/foreign_state 保留）② 合并标签含 state-integrity 段时 `correction_file_strip_type file "state-integrity"`（纯 type no-op 非零 rc 忽略——correction-file.sh 边界契约）③ `_fai_append_foreign_note` 追加恰好 1 条去重 foreign_state note（去重键=check，已存在则 no-op 不重写文件 → 幂等）④ 一条 stderr 提示行。措辞区分：内容首非空白字符为 `{`/`[`（疑似 JSON 但解析失败）→ 损坏措辞；否则（YAML 等）→ 外来措辞。全程只读 .flow-active 本体（AC-7），不写/不转换/不删除外来文件。

## Files

| File | Change |
|---|---|
| `flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh` | 唯一修改（+154 行） |
| `.specs/correction-hygiene-state-guard/T02-SUMMARY.md` | 本文档 |

新增函数：`_fai_ensure_correction_lib`、`_fai_clear_whitelist`（stdout 输出移除数）、`_fai_append_foreign_note`。修改：`_flow_active_integrity_main`（入口外来分支 + 退出点健康清零 + `_FAI_APPENDED` 标志）、`_fai_append_violation`（置位 + append 后 dedupe/trim）。

## Verify (verbatim)

```
$ bash -n flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
$ shellcheck -e SC1091 -S error flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
（两者无输出 = 通过）
$ ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/test_stop_chain.bats
1..43
ok 1 smoke: 22-git.sh 语法正确
...（43/43 全过，含 33 三条：ok 29 语法 / ok 30 shebang / ok 31 含完整性检查函数）...
ok 43 smoke: 25-project.sh 含 project 检查函数
```

## Functional smoke (/tmp/t02smoke, HOOK_BASE_DIR 已 export)

```
SMOKE A (AC-1 dedupe on append):
  violations count: 1        ← 3× corrupt_json collapse to 1
  latest message:   dup-m3   ← 保最新

SMOKE B (AC-3/D3 health clear):
  rc=0
  state-integrity cleared 5 items          ← stderr 审计行
  remaining checks:   l2-missing           ← 5 白名单清空
  count:              2                    ← l2-missing + compliance 保留
  compliance preserved: 1 / l2-missing preserved: 1   （jq -c 直接验证，AC-10）

SMOKE C (AC-5/6 foreign YAML yield, run 两次):
  foreign_state count: 1    ← 恰好 1 条，run twice → still 1（幂等）
  corrupt_json count:  0    ← 不再追加 corrupt_json
  type:                l2-missing          ← 合并标签剥离 state-integrity 段
  checks left:         l2-missing,foreign_state   ← compliance-keep 保留（jq -c 验证）
  foreign_state msg:   外来的状态文件，已让位并清除 state-integrity 状态。如果你是 flow-kit，请重新 /flow 启动。
  foreign file identical: YES               ← sha256 前后一致（AC-7 只读）

SMOKE D (损坏措辞, JSON-like damaged):
  msg: 状态文件已损坏（非 flow-kit JSON），已让位并清除 state-integrity 状态。如果你是 flow-kit，请重新 /flow 启动。
```

## 6-dim self-check

| Dim | Result |
|---|---|
| 正确性 | 3 变化全部按 TASK.md/DESIGN/REQUIREMENT 实现，smoke A-D 全过；幂等（C 跑两次 foreign_state 仍 1 条） |
| 契约对齐 | AC-1/2/3/5/6/7/10 全覆盖；D3 标志、D5 单一 actor、D6 去重键=check；ADR-024 白名单作用域（compliance 字节级保留） |
| fail-open | append/dedupe/trim/strip/clear/note 全部 `|| true` 或内建 guard；主函数各分支 return 0；stop 链永不破坏 |
| set -euo pipefail | 所有 jq/mktemp/grep 均 guard（`|| fallback`、`if` 条件、`|| true`）；`_FAI_APPENDED` 用 `${VAR:-0}` 引用 |
| 无范围蔓延 | write_files = 33-flow-active-integrity.sh only；复用 T01 函数未重实现；未触碰外来文件 |
| 可维护性 | 复用 `_fk_ci_whitelist_json`（白名单单一来源）；新 helper 均按文件既有 `_fai_` 命名 + 函数头注释契约风格 |

## Boundary check (R6.5)

`git status --short`：本任务编辑仅 `flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh`。工作区其余改动（`lib/correction-file.sh` = T01、`29-independent-review.sh`、`.specs/CONTEXT.md`、`Makefile`、`README.md`、ADR-024/REQUIREMENT 等）均为本 change 其他任务产出，非 T02 写文件。`git diff --stat` 确认 33 为 154 行新增，无越界文件。

## 实施要点 / 偏差

- **jq 陷阱（自发现并修复）**: `$wl | index(.check)` 中 `.check` 在 `index()` 参数上下文对 `$wl`（数组）求值 → `Cannot index array with string "check"`。修复：`[.violations[] | . as $e | select(... $wl | index($e.check) ...)]`（绑定变量，与 lib `$item.check` 同模式）。**无偏差**。
- smoke 环境需 `export HOOK_BASE_DIR`（`flow-kit-artifacts.sh:12` 用裸 `${HOOK_BASE_DIR}`，`set -u` 下未导出会中止——真实运行时由 00-gate/common 注入，非本任务问题）。
- 措辞判定：DESIGN risk-2「note 文案区分非 flow-kit 格式或已损坏」→ 以内容首字符 `{`/`[` 区分 外来/损坏 两种措辞，行为完全一致（同路径）。
- T02 未在 TASK.md 标记 done（由主 agent 验证后标记）。
