# T-FIX-22 执行回执（第 5 轮 fix loop · 2026-09-28）

> findings `R5-20` 🟡 / `R5-21` 🟡 / `R5-22` 🟡 / `R5-5` 🟡
> HEAD（开工基线）= `1f34aaa83aba588e8ed460ca374408879725792a`（工作树干净）

## §A 先红基线（三条独立红线 · 修前实测）

| 腿 | 命令 | 修前 rc | 修前报文 | 修后 rc | 修后报文 |
|---|---|---|---|---|---|
| ① R5-20 | `install.sh --platform claude --project /tmp/tfix22/proj1 --hooks-only`（settings.local.json 预置 `{ broken json`） | 5 | 沉默中止（`set -euo pipefail` 下 `jq` parse 失败终止脚本；`:393` 告警不可达） | 1 | 含 `settings.local.json` + `合并失败` + `jq` + `parse error`；无「安装完成」 |
| ② R5-21 | `fk_validate_done_marker empty.done dev health-fix-2026-09b transition`（empty.done 0 字节 + phases_done=["dev"]） | 0 | 空文件被 phases_done 短路放行（Tier-1 非空校验在短路之后） | 2 | Tier-1 非空校验先于 phases_done 短路 ⇒ 空 .done deny |
| ③ R5-22 | `_l3_build_prompt 2 <artifacts_dir> 60000`（DESIGN.md 引用 10 ADR） | 0 | 8 ADR 纳入（--- 标记），0 丢弃标记，ADR-001/002 静默丢弃 | 0 | 8 ADR 纳入 + 落标记「已丢弃 2 条工件引用的 ADR」 |

**先红留档**：`/tmp/tfix22/pre.txt`（含命令 + rc + 报文）。

## §B 四个修法

### R5-20 — `flow-kit-bundle/lib/install_hooks.sh:378-395`

**修前**：`merged=$(jq ... 2>/dev/null)` + `[ -n "$merged" ] && write`；`set -euo pipefail` 下 `jq` parse 失败 ⇒ 脚本终止 rc=5，`:393` 告警成死代码。

**修后**：
- `jq` stderr 重定向到临时文件 `$_jq_err`，退出码显式捕获：`merged=$(jq ... 2>"$_jq_err") || _jq_rc=$?`
- `_jq_rc ≠ 0`（parse 失败）：打印具名诊断（settings 路径 + jq rc + jq stderr `head -1` + fail-closed 消息）→ `return 1`
- `_jq_rc = 0` 但 `write` 失败：`:393` 告警现在**可达**（区分 parse 失败与 write 失败两条路径）

**反向控制**：把 `jq` 恢复为 `2>/dev/null` 无 rc 捕获 ⇒ 腿① bats 必须 not ok（断言 `settings.local.json` 具名 + 非零退出）。

### R5-21 — `flow-kit-bundle/hooks/stop/lib/done-validation.sh:104-141`

**修前**：`phases_done` 短路在 `:126` `[[ -s "$done_path" ]] || return 2` 之前 ⇒ 空 `.done` + phases_done 命中 ⇒ rc=0 放行。

**修后**（按 Remedy「把短路移到 Tier-1（非空 + 行数 + phase/change_id/written_by）之后，短路只豁免 Tier-2/3 产物比对」）：
- Tier-1 顺序：`[[ -f ]] || return 2` → `[[ -s ]] || return 2`（非空）→ `dlines ≥ MIN_MEANINGFUL_LINES`（行数）→ **KVP**：`k_phase`/`k_cid`/`k_wby`（phase/change_id/written_by 三键齐全且匹配）
- `phases_done` 短路移到 Tier-1 全部通过**之后**：`phase ∈ phases_done ⇒ return 0`（跳过 Tier-2/3 L2/L3/artifacts 比对）
- docstring 更新：`phases_done 短路（D1/R11 · R5-21 修正）: phase ∈ goal.phases_done → 跳过 Tier-2/3 产物比对，但不越过 Tier-1（非空 + 行数 + phase/change_id/written_by KVP）`

**两态实测**：空 `.done` + phases_done 命中 ⇒ rc=2（deny）；非空有效 `.done` + phases_done 命中 ⇒ rc=0（短路跳过 Tier-2/3）。

**反向控制**：把短路次序改回 Tier-1 之前 ⇒ 腿② bats 必须 not ok（断言空 `.done` + phases_done ⇒ rc=2）。

**既有测试回归修复**：`test/test_review_gate_validity.bats:188`（旧测「空标记 + phases_done ⇒ rc=1 放行」编码了旧 bug 行为）→ 拆为两测：
- 「phases_done 短路保持（历史阶段 + Tier-1 有效标记 ⇒ 跳过 Tier-2/3，rc=1）」：非空有效 `.done` + phases_done + Tier-2 不一致 ⇒ rc=1（短路保持）
- 「R5-21 空 .done + phase ∈ phases_done ⇒ 仍 deny rc=0（Tier-1 不短路）」：空 `.done` + phases_done ⇒ rc=0（deny）

### R5-22 — `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:356-367`

**修前**：`[ "$_adr_n" -lt 8 ] || break`（静默截断，丢弃的 ADR 无标记）。

**修后**：
- `[ "$_adr_n" -lt 8 ] || { ... ; break; }` 块内先算丢弃数再写标记再 break
- `_adr_total` = 工件引用的 ADR 唯一去重总数（`printf '%s\n' $_adr_ids | grep -c '.'`）
- `_adr_dropped` = `_adr_total - _adr_n`（下限 0）
- `_adr_dropped > 0` ⇒ `artifact+=$'\n\n（⚠️ ADR 纳入上限（8 份）命中，已丢弃 N 条工件引用的 ADR；以下为**未纳入**的 ADR 清单，需要时按工件给出的复现命令自行查阅：<adr_ids>）'`
- 标记**先于** `break` 写入（可达）

**实测**：10 ADR → 8 纳入 + 丢弃标记「已丢弃 2 条」；9 ADR → 丢弃 1 条；8 ADR → 无丢弃标记（无假阳性）。

### R5-5 — `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:92-93`

**修后**：在 `SELF_EXCLUDE` 多行清单追加两行（与现有 IR-1/2/3 同目录风格、独占行）：
```
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md
```

## §C 门禁实测

### `make check-path-privacy`（rc=0）
| 指标 | 实测 |
|---|---|
| 候选文件 | 1617 |
| 实际扫描 | 1609 |
| 自排除 | 8 |
| index 侧 | 15 |
| 命中 | 0 |

### `make check`（21 步全部通过 ✅ / 0 ❌）
```
npx bats test/ → 1..1108
ok = 1108 · not ok = 0 · skip = 0
```

**增量归因**（1098 → 1108 = +10）：
- `test/done-validation.bats`：+2（R5-21 空 `.done` + phases_done deny / 非空有效 + phases_done rc=0）
- `test/test_install_coverage.bats`：+3（R5-20 非法 JSON 非零退出 / jq 报文 + fail-closed / 合法 JSON rc=0）
- `test/test_l3_adr_truncation.bats`（新件）：+4（10 ADR 8 纳入 / 丢弃标记含计数 / 9 ADR 丢弃 1 / ≤8 无假阳性）
- `test/test_review_gate_validity.bats`：净 +1（旧测 1 条拆为 2 条：短路保持 + R5-21 deny）

### 其他门禁
- `./sync-hooks.sh`：6 文件同步 ✅
- `make test-sync`：test/ → flow-kit-bundle/test/ 双源一致 ✅
- `bash package-flow-kit.sh` + `bash package-dsh-plugin.sh`：dist 重建 ✅
- `make check-hooks-sync check-test-sync check-dist`：全部 ✅
- `bash -n` 四个生产件：rc=0 ✅
- `make check-nfr-portability`：无 bash4-only / GNU-only ✅

## §D 回执额外三项（主 agent 判据脚本钉桩用）

| # | 命令 | 实测 |
|---|---|---|
| 1 | `grep -cE 'settings\.json.*jq\|jq.*settings\.json' flow-kit-bundle/lib/install_hooks.sh` | **4** |
| 2a | `grep -cE '^\.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5\.md$' flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | **1** |
| 2b | `grep -cE '^\.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6\.md$' flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | **1** |
| 2c | `grep -cE 'INDEPENDENT-REVIEW-[56]' flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（主 agent 已废此口径，因 :615 注释行含「INDEPENDENT-REVIEW-6 ③」致散文漂移） | **3**（两 SELF_EXCLUDE 行 + 一注释行） |

### ADR 上限命中标记文本原文 + 行号

**行号**：`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:366`

**标记文本原文**（完整字符串）：
```
              artifact="${artifact}"$'\n\n（⚠️ ADR 纳入上限（8 份）命中，已丢弃 '"${_adr_dropped}"$' 条工件引用的 ADR；以下为**未纳入**的 ADR 清单，需要时按工件给出的复现命令自行查阅：'"$_adr_ids"'）'
```

**丢弃计数变量**：`${_adr_dropped}`（运行时展开为 `_adr_total - _adr_n`，下限 0）。

## §E 写面清单

| 文件 | 类型 | 说明 |
|---|---|---|
| `flow-kit-bundle/lib/install_hooks.sh` | 产品件 | R5-20 jq parse 失败具名诊断 |
| `flow-kit-bundle/hooks/stop/lib/done-validation.sh` | 产品件 | R5-21 Tier-1 先于 phases_done 短路 |
| `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` | 产品件 | R5-22 截断标记先于 break |
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | 产品件 | R5-5 SELF_EXCLUDE 追加两行 |
| `test/done-validation.bats` | 测试件 | R5-21 +2 例 |
| `test/test_install_coverage.bats` | 测试件 | R5-20 +3 例 |
| `test/test_l3_adr_truncation.bats` | 新测试件 | R5-22 +4 例 |
| `test/test_review_gate_validity.bats` | 测试件 | R5-21 旧测拆分 +1 例 |
| `flow-kit-bundle/test/`（5 件镜像） | 测试件 | make test-sync 双源镜像 |

## §F ADR-015 台账（`.flow-active` · gitignored · 不提交）

提交后追加 `T-FIX-22` 条目到 `goal.task_progress`（5 字段：id / commit_sha / fix_rounds / deferred / completed_at）。
