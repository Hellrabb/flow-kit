# T-FIX-24 执行回执（第 6 轮 fix loop · 2026-09-28）

> findings `R5-5` 处置订正：`T-FIX-22` 按当时 `TASK.md` 指示把 `INDEPENDENT-REVIEW-5.md`/`-6.md` 追加进 `SELF_EXCLUDE`，与阶段 5 已裁决的 `T13`/`T17` 判据**直接冲突**（豁免面冻结集 = 本脚本 + 两份允许清单 + `INDEPENDENT-REVIEW-1/2/3.md`；新增审查档是脱敏第一现场，正确处置是就地 de-shape 而非豁免）。
> 开工基线 HEAD = `b1bfa4f`（工作树干净） · 产品提交 = `1900425cbabdd60e50f3283fc1693baf7825042a` · `%cI` = `2026-09-28T14:58:12+08:00`

## §A 先红留档

| 腿 | 命令 | 修前 | 修后 |
|---|---|---|---|
| ① | `awk '/<task id="T17"/,/<\/task>/' TASK.md \| sed -n '/<verify>/,/<\/verify>/p' \| sed '1d;$d' > /tmp/tfix24/t17-verify.sh && bash /tmp/tfix24/t17-verify.sh` | **rc=1** + 报文 `🔴 审查档 .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md 被纳入门禁排除表（豁免面不得超出冻结集 1–3；放宽须 ADR 裁决 · L-149/TD-054：审查档是脱敏第一现场，豁免即盲区）` | **rc=0** |

先红报文原文（修前实测，逐字）：

```
🔴 审查档 .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md 被纳入门禁排除表（豁免面不得超出冻结集 1–3；放宽须 ADR 裁决 · L-149/TD-054：审查档是脱敏第一现场，豁免即盲区）
rc=1
```

## §B 修法（生产件最小修 + 契约注释 + 常设腿）

1. **`SELF_EXCLUDE` 删两行**（`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`）：从 8 条恢复为冻结 6 条 —— 删 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md` 与 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md` 两行，其余 6 条一字不动。
2. **契约注释重写**（同区块 `:84-90`）：删除旧口径「后续阶段新增审查档时必须显式追加精确路径到本清单」，改为「冻结集 = 本脚本 + 两份允许清单 + `INDEPENDENT-REVIEW-1/2/3.md`（成文早于脱敏规则、原文含真实账号路径，逐条精确豁免）；此后新增的审查档一律不豁免 —— 它们是脱敏泄漏的第一现场，必须由本门禁就地判红并 de-shape；放宽豁免面须 ADR 裁决（`L-149`/`TD-054`/`T13`/`T17`）。T-FIX-22 曾误把新增审查档追加进本清单（`INDEPENDENT-REVIEW-{5,6}.md`），与阶段 5 裁决冲突，T-FIX-24 已移除。」。**硬约束遵守**：注释里用 `INDEPENDENT-REVIEW-{5,6}.md` 表述，不含完整路径字面 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md`（T17 用 `grep -qF <路径>` 全文匹配 ⇒ 注释里写完整路径同样判红）。
3. **常设腿（+1 例 · 双源镜像 · 判别力优先）**：`test/test_path_privacy_gate.bats` 新增 `T-FIX-24：SELF_EXCLUDE 成员集合精确等于冻结 6 条；副本注入伪条目（新增审查档）⇒ 膨胀 not ok，去行复绿（豁免面冻结 · L-149/TD-054）`。单例内完成三态断言：① 基线态（原 SUT 集合 == 冻结 6 条 · n=6）② 注入态（副本追加伪条目 `INDEPENDENT-REVIEW-4.md` ⇒ n=7 ≠ 冻结集 · not ok）③ 复原态（去行后 n=6 == 冻结集 · 复绿）。用例名注明「豁免面冻结 / 新增审查档被追加 ⇒ 红」+ `L-149`/`TD-054`。镜像件 `flow-kit-bundle/test/test_path_privacy_gate.bats` 经 `make test-sync` 同步，`cmp -s` IDENTICAL。

## §C 判别力实证（副本注入 · 两次输出留档）

在 `/tmp/tfix24/mut/` 副本上执行（SUT 全程 sha256 = `b28eab7618a25c45b94b28ebff686a9c4e7b3ef9c78b272654d44c0281a46d51`，注入前后一致 —— 未改仓内真件）：

**冻结集**（排序后）：
```
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-1.md
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-3.md
.specs/health-fix-2026-09b/path-privacy-allowlist.txt
flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
```

**基线态**（副本 == 冻结集）：
```
member count: 6
MATCH (== frozen 6)
```

**注入态**（副本追加伪条目 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-4.md`）：
```
member count: 7
NOT EQUAL (膨胀即红 ✅ 判别力成立)
injected member that's not in frozen:
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-4.md
```

**复原态**（从副本移除伪条目）：
```
member count: 6
MATCH (复绿 ✅ 复原成立)
```

**SUT sha256 全程一致**：注入前 `b28eab76…` · 复原后 `b28eab76…`（仓内真件未被改动）。

bats 常设腿内同一逻辑（`ok 35`）：基线 n=6 == frozen · 注入 n=7 != frozen（not ok）· 去行 n=6 == frozen（复绿）。

## §D 复跑面（逐条实跑 · rc + 关键输出）

| 腿 | 命令 | rc | 关键输出 |
|---|---|---|---|
| ① | `bash /tmp/tfix24/t17-verify.sh`（T17 <verify> 原样抽取实跑） | **0** | 三项子断言全过（宽通配 0 · 冻结 3 档在表内 · 枚举 IR 档 ≥3 且新增档不在表内） |
| ② | `bash .specs/health-fix-2026-09b/reproduce-5-test.sh --criteria-only --only T17` | **0** | `T17 ✅ rc=0（74 行判据）` · `✅ 复算全绿` |
| ③ | `make check-path-privacy` | **0** | 候选 **1622** / 实际扫描 **1616** / 自排除 **6**（修前 8）/ index 侧 15 / 不可读 0 / 命中 **0** / 清单外 **0** |
| ④ | `npx bats test/test_path_privacy_gate.bats` | **0** | `1..35` · 35 ok · 0 not ok（含新腿 ok 35）· `cmp -s` 镜像 IDENTICAL |
| ⑤ | `npx bats test/`（全量） | **0** | `1..1115` · 1115 ok · 0 not ok（`npx bats --count test/` = 1115） |
| ⑥ | `make check` | **0** | **21 ✅ / 0 ❌** |

**计数变化实证**（verify ③ 须贴）：
- 自排除 **8 → 6**（删两行）
- 实际扫描 **1614 → 1616**（+2 = 两份审查档重新进扫面）
- 候选 **1622 不变**
- 命中合计 **0** · 清单外命中 **0**（取消豁免未引入假红 —— 两文件当前机器路径字面命中 = 0/0，与主 agent 实测一致）

## §E 门禁收尾

| 门禁 | rc | 报文要点 |
|---|---|---|
| `make test-sync` | 0 | test 双源已同步 |
| `./package-dsh-plugin.sh` | 0 | unit tests 20 pass / 0 fail · dist 6.0M |
| `make check-hooks-sync` · `check-test-sync` · `check-dist` | 0 · 0 · 0 | hooks 漂移 0 · test 双源一致 · dist 与源一致 |
| `make check` | **0** | **21 ✅ / 0 ❌** · 含 check-path-privacy（自排除 6 / 扫描 1616 / 命中 0）· NFR rc=0（无新增 bash4/GNU-only 构造）|

## §F 台账

`goal.task_progress` 末条 append：`{"id":"T-FIX-24","commit_sha":"1900425cbabdd60e50f3283fc1693baf7825042a","fix_rounds":1,"deferred":[],"completed_at":"2026-09-28T14:58:54+08:00"}`（五字段齐 · 无 `.goal` 幽灵键 · `deferred == []` · 顶层与 `goal` 的 `updated_at` 保持 epoch 整数）。**Δ = 42 s**（= `completed_at` 14:58:54 − 产品提交 `%cI` 14:58:12）≤ 120 s。

## §G 写面清单

`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`(+7/−4 · SELF_EXCLUDE 删 2 行 + 注释重写) · `test/test_path_privacy_gate.bats`(+96/−0 · +1 例 T-FIX-24) · `flow-kit-bundle/test/test_path_privacy_gate.bats`(镜像 +96/−0) · `.specs/health-fix-2026-09b/T-FIX-24-SUMMARY.md`(新建) · `.specs/health-fix-2026-09b/TASK.md`(本件 status=done + `<done>`) · `.flow-active`(goal.task_progress append · gitignored 不提交)。

## §H 遗留风险

1. **`make verify-claims` §10c ❌（非本次引入 · 不在 `make check` 面）**：其「§0.5.1 覆盖被改文件」核的是工作树相对 HEAD 的改动是否列在 `DESIGN.md §0.5.1` —— fix loop 期间新增触碰文件不回填冻结的 `DESIGN.md` ⇒ 该 ❌ 是流程性预期（`verify-claims` 不在 `make check:` 目标集合内）。同批另有 `MINOR-DEFERRED.md` M 编号口径 ❌（第 5/6 轮整轮既有）。二者均**未**因本任务改变，登记备查，不改冻结设计件。
2. **契约注释里的 `INDEPENDENT-REVIEW-{5,6}.md` 表述**：用花括号展开形态而非完整路径字面，遵守 T17 `grep -qF <完整路径>` 全文匹配的硬约束。若未来有人把花括号展开改成完整路径字面（如 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md`）写在注释里，T17 会判红。注释 `:88-90` 是这一约束的承载点。
3. **常设腿判别力依赖 `sed` 块提取**：新腿用 `sed -n '/^SELF_EXCLUDE=/,/^'"'"'$/p'` 提取块成员。若未来 `SELF_EXCLUDE` 的引号风格改变（如改用双引号），提取会失效 ⇒ 腿假绿。当前风格（单引号起始 + 单引号终止）是脚本既有约定（`:85`/`:94`），未因本任务改变。
