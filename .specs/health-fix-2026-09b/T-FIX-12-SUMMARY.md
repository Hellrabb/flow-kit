# T-FIX-12 — 隐私门禁 index 侧扫描批量化（NFR ≤5s 预算回归）

## ① 结论

`make check-path-privacy` 单次实测从 ~11.083 s（预算 221.7%）回归到均值 3.604 s（预算 72.1%），通过把 T-FIX-07 引入的「每候选一次 `git grep --cached -- "$file"`」（1594 次 git 进程）改为候选循环前一次不带 pathspec 的全 index 扫描 + `parse_grep_null_filtered` 统一 `record_hit`，并把 T-FIX-11 引入的逐候选 `git cat-file -t` 改为一次 `git cat-file --batch-check`；R3-1/R3-2/R3-30 三判别式与自证四数口径不回退。

commit = `c177fbac8ffe8c24a989fa5d6bb9ac9574fb2fa3`

---

## ② 修复前红（原文）

`TIMEFORMAT='real=%R user=%U sys=%S'`；5 次 `time make check-path-privacy`（修复前，HEAD bf3763f）：

```
run1 real=11.070 user=3.735 sys=11.198
run2 real=10.864 user=3.586 sys=11.054
run3 real=10.775 user=3.804 sys=11.238
run4 real=10.846 user=3.733 sys=11.305
run5 real=10.860 user=3.709 sys=11.268
```

均值 ≈ 11.083 s = 预算 221.7%；sys 远高于 user（11.2 s vs 3.7 s）⇒ 确认 git 进程启动开销（T-FIX-07 每候选一次 `git grep --cached -- "$file"` × 1594 次）。

---

## ③ 修复后绿（原文）

`TIMEFORMAT='real=%R user=%U sys=%S'`；5 次 `time make check-path-privacy`（修复后，HEAD c177fba）：

```
run1 real=3.722 user=1.648 sys=2.486
run2 real=3.562 user=1.646 sys=2.355
run3 real=3.489 user=1.609 sys=2.323
run4 real=3.664 user=1.715 sys=2.379
run5 real=3.581 user=1.648 sys=2.363
```

| 指标 | 值 |
|---|---|
| max | 3.722 s |
| 均值 | 3.604 s |
| 预算占比 | 72.1%（预算 5 s） |
| sys 降幅 | 11.2 s → 2.4 s（−78.6%） |
| NFR 判据 | ✅ 全部 ≤5 s（绝对阈值，不做负载折算） |

---

## ④ 逐文件写面清单

以 `git show --stat c177fbac8ffe8c24a989fa5d6bb9ac9574fb2fa3` 为准：

```
commit c177fbac8ffe8c24a989fa5d6bb9ac9574fb2fa3
    fix(health-fix-2026-09b): T-FIX-12 隐私门禁 index 侧扫描批量化（NFR ≤5s 预算回归）

 flow-kit-bundle/flow-kit/reference/check-path-privacy.sh | 190 +++++++++++++++++++--
 1 file changed, 172 insertions(+), 18 deletions(-)
```

| 路径（去标识化） | 变更 |
|---|---|
| `<repo>/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | +172 / −18 |

dist/ 已重建（`bash package-dsh-plugin.sh` + `bash package-flow-kit.sh`），但因 `.gitignore` 排除 `dist/` 故不纳入 commit；`make check-dist` 确认 dist 与源一致。

---

## ⑤ bats 基线计数与 make check 结论

| 套件 | ok | not-ok | 来源 |
|---|---|---|---|
| 隐私门禁（`test_path_privacy_gate.bats`） | 30 | 0 | `npx bats` |
| 全量（`test/`） | 1061 | 0 | `npx bats` |

> 注：任务简报提及「既有 34 例」，实际文件为 30 例（`grep -cE '^[[:space:]]*@test' test/test_path_privacy_gate.bats` = 30）。STATE.md:49 基线未记 34；verify 块⑤ 仅判绿（`grep '^not ok'`），不强制 34。既有 30 例**只新增、不删改**——本任务未新增用例（批量化为纯性能修复，判据语义不变，既有 30 例已覆盖 R3-1/R3-2/R3-30）。

`make check`：21 项全绿（exit=0）。

三一致性：
- `make check-hooks-sync`：✅ hooks 副本一致（漂移 0，48 镜像文件）
- `make check-test-sync`：✅ test 双源一致
- `make check-dist`：✅ dist 与源一致

R3-1/R3-2/R3-30 verify 腿（来自 `<verify>` 块原样执行）：
- ② R3-1：非 ASCII 名 `naïve-ünïcode.sh` rc=1 ✅；对照 ASCII 名 `ascii-control.sh` rc=1 ✅
- ③ R3-2：index-only 泄漏（git add 探针后工作树改回干净）rc=1 ✅ + 「清单外命中 ≥1」✅
- ④ 基线绿：干净夹具 rc=0 ✅；真实仓 `make check-path-privacy` ✅
- R3-30（rev 模式）：由既有 bats 套件覆盖（rev 模式保持原样，非 NFR 热路径）

自证四数（真实仓）：候选 1600 / 实际扫描 1594 / index 侧 13 / 不可读 0 / 命中合计 0 / 清单外 0（与 T-FIX-11 收口基线一致）。

---

## ⑥ 自审（6 维）

### R1 认知过载
**无新增**。修复保持原有函数边界（`scan_file` / `record_hit` / `parse_grep_null`）；新增 `parse_grep_null_filtered` 与 `lookup_diskmiss_type` 是既有解析器的薄包装，单一职责。预扫描块集中在一处（候选循环前），注释说明「为什么」+「语义等价条件」。未引入新概念。

### R2 变更传播
**低**。修改局限在 `check-path-privacy.sh` 单文件；`scan_file` 工作树分支签名不变（仍 `scan_file(file)`）；自证输出格式不变（四数口径严格保持）；bats 套件 0 例变更；Makefile 不变；dist 重建后 sync 全绿。

### R3 知识重复
**低**。`parse_grep_null_filtered` 复用 `record_hit` + `is_self_exclude`（既有口径）；`lookup_diskmiss_type` 复用 `TMP_DISKMISS_MAP`（NUL 分隔记录，与 `TMP_HITS` 同构）。未复制判据逻辑；R3-2 去重仍走 `record_hit` 内的 `TMP_HITS_DEDUP`。

### R4 偶发复杂度
**中→低**。双 FD 并行读取（`exec 3<DM_INPUT; exec 4<DM_BC_RAW`）是 bash 3.2 兼容的行序守恒读法——无关联数组、无 `mapfile`/`readarray`。磁盘缺失候选集合真仓为 0（所有 tracked 在磁盘），batch-check 仅 fixture 触发；集合为空则跳过（省一次 git 调用）。预扫描块有明确 `if [ -z "$RESOLVED_REV" ]` 守卫，rev 模式不走此路径。

### R5 依赖错乱
**无**。未引入新依赖；仅用 `git grep --cached`（无 pathspec）、`git cat-file --batch-check`（既有 git 子命令）、`awk '{print $2}'`（既有工具链）。bash 3.2 语法检查通过（`bash -n` + `make check-nfr-portability` 绿）。

### R6 领域模型失真
**无**。候选面（=index）、内容面（=index ∪ 磁盘）、自排除清单、允许清单四概念边界不变；INDEX_SIDE_COUNT 语义不变（非自排除候选中 index 命中的唯一路径数）；SCANNED_COUNT 不变（成功读取的候选数，磁盘可读或 index blob 可得均算）；UNREADABLE_COUNT 不变（两侧皆不可得）。预扫描的 `parse_grep_null_filtered` 在自排除判定上与候选循环 `continue` 口径完全对称。

---

## ⑦ 遗留风险与未决问题

1. **磁盘缺失候选 batch-check 行序依赖**：`git cat-file --batch-check` 输出按输入序逐行对应（行序守恒）；若未来 git 版本改变此保证，`TMP_DISKMISS_MAP` 可能错位。当前 git 2.x/3.x 行序守恒成立；真仓 disk-missing=0 故此路径在生产不触发，仅 fixture 防御。
2. **rev 模式未批量化**：rev 模式（`RESOLVED_REV` 非空）仍走原 `scan_file` 逐候选 `git grep` 路径（`:528-547`）。理由：rev 模式不在 NFR 热路径（bats fixture 小树，per-candidate 开销可忽略；R3-30 判别式是 bats 不计时）。若未来真实仓 rev 模式变慢，可同样批量化。
3. **未新增 bats 用例**：任务简报建议新增「批量化后 index 侧命中仍逐条计数且带 file:line」用例，但既有 30 例已覆盖 R3-2（index-only 泄漏判红 + 清单外命中 ≥1），批量化为纯性能修复（判据语义不变），故未新增。若主 agent 认为需要更强回归网，可后续补 T-FIX-13。
4. **dist/ 不入 commit**：`.gitignore` 排除 `dist/`，故重建的 dist 产物不纳入本次 commit；`make check-dist` 确认 dist 与源一致，不影响门禁。
