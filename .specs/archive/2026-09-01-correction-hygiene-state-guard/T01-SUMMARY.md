# T01-SUMMARY · correction-hygiene-state-guard

> task: T01（parallel）· 执行者: Dev · 2026-09-01
> write_files 严格限定: `flow-kit-bundle/hooks/stop/lib/correction-file.sh`（唯一源）

## 做了什么

在 `flow-kit-bundle/hooks/stop/lib/correction-file.sh` **追加**（0 删除、166 行新增，其中可执行 ~85 行 + 文档注释）：

1. **`CORRECTION_STATE_INTEGRITY_CHECKS`** — `readonly` 数组常量，9 值逐字按序：
   `corrupt_json / change_id_dangling / change_id_null_with_dirs / phase_artifact_missing / pipeline_phase_artifact_missing / pipeline_gate_not_passed / pipeline_gate_phase_mismatch / stale_updated_at / token_spent_unmaintained`（与 33 号源码顺序一致，ADR-024 单一源；注释标注「新增 check 名需同步白名单」L-031 提示）
2. **`correction_file_dedupe <path>`** — violations[] 同 `check`+`field` 只保留最新（数组末尾）一条，作用域仅 check ∈ 白名单；compliance 类（check 缺失/不在白名单）逐字节原样保留且相对顺序不变。单步 jq（`-e` + `(.violations|type)=="array"` guard）→ mktemp+mv 原子写。文件缺失/非法 JSON/无 violations 数组 → 静默非零、文件不动。
3. **`correction_file_trim <path> <max>`** — 先调 dedupe，再对白名单类条目 FIFO 淘汰（保留末尾 max 条）；compliance 不计配额、永不淘汰。同款原子写 + 错误语义。
4. **`correction_file_strip_type <path> <segment>`** — `+` 合并标签中剥离指定段（`l2-missing+state-integrity` strip `state-integrity`→`l2-missing`；strip `l2-missing`→`state-integrity`）；violations[] 原样保留；仅在真正剥离时原子写。**边界契约（盲审 N3）**：纯 type（无 `+`）→ no-op 返回非零、文件不动；合并标签但 segment 不存在 → no-op 返回 0；非法 JSON/文件缺失 → 非零。

私有 helper `_fk_ci_whitelist_json()`（`_fk_` 前缀，文件内私有）把常量数组序列化为 jq `--argjson` 白名单，dedupe/trim 共用。

**未触碰**：既有 4 函数签名（exists/read/write/clear）+ `write_model_missing_clear` / `write_model_missing_correction` 函数体（禁动条款）。

## 改动文件

- `flow-kit-bundle/hooks/stop/lib/correction-file.sh`（唯一改动，追加 166 行，0 删除）

## verify 真实输出

```
$ bash -n flow-kit-bundle/hooks/stop/lib/correction-file.sh && shellcheck -e SC1091 -S error flow-kit-bundle/hooks/stop/lib/correction-file.sh && ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/test_correction_file.bats test/test_common.bats; echo "VERIFY_EXIT=$?"
1..35
ok 1 correction_file_exists returns 1 for missing file
ok 2 correction_file_exists returns 0 for valid JSON file
ok 3 correction_file_exists returns 1 for invalid JSON
ok 4 correction_file_read returns {} for missing file
ok 5 correction_file_read returns file content for existing file
ok 6 correction_file_write with overwrite strategy writes file
ok 7 correction_file_write overwrite replaces previous content
ok 8 correction_file_write with merge strategy deduplicates by fields
ok 9 correction_file_clear removes file
ok 10 round-trip: write → read → clear → exists
ok 11 config_get returns value for existing key
...（test_common 24 项，全部 ok）...
ok 35 fk_perf_timing: end without start warns but does not exit
VERIFY_EXIT=0
```

- bash -n: 0 语法错误 ✅
- shellcheck（-e SC1091 -S error）: 0 error ✅
- bats test/test_correction_file.bats + test/test_common.bats: **35 ok / 0 fail / exit 0** ✅（4 函数签名零变更回归绿）

### 功能 smoke（/tmp，30s 内完成，29/29 PASS）

sample correction（3 条同 check+field 重复 + compliance 无 check 条目 + 非白名单 check 条目 + 合并标签）：

```
SMOKE RESULT: PASS=29 FAIL=0
- dedupe 混合 7 条 → 5 条：3 条 corrupt_json/flow_active 仅留最新 dup3；compliance 2 条逐字节保留、相对顺序不变；非白名单 check 条目保留
- dedupe 错误语义：缺失文件 rc=1 / 非法 JSON rc=1 / 无 violations 数组 rc=1 且文件字节不变
- trim max=2：5 条白名单 + 2 compliance → 4 条（FIFO 淘汰最旧 3 条白名单，保留最新 2；compliance 保留且不占配额）
- trim 先去重：3 重复 + 2 白名单 max=2 → 先去重剩 3 再淘汰最旧 1 → 剩 2
- strip_type："l2-missing+state-integrity" strip "state-integrity"→"l2-missing"（violations 不动）rc=0；strip "l2-missing"→"state-integrity" rc=0
- strip_type 纯 type "l2-missing" → rc=1 文件字节不变（N3 边界）；合并标签 strip 不存在段 → rc=0 文件不变；非法 JSON/缺失文件 → rc=1
```

smoke 脚本位于 `/tmp/opencode/smoke_correction_hygiene.sh`（不入库）。

## 6 维自查（R1–R6 内置快查）

| 维度 | 结果 |
|---|---|
| R1 功能完整 | ✅ 3 函数 + 1 常量全部导出可用（smoke 29/29 覆盖每个函数正常路径 + 错误语义 + N3 边界） |
| R2 既有签名零变更 | ✅ `git diff` 证实 0 删除行（唯一 `-` 行是 diff 头）；exists/read/write/clear 与 write_model_missing_* 逐字节未动 |
| R3 共享抽象 | ✅ strip_type 供 T02（外来剥 state-integrity）/T03（退场剥 l2-missing）共用，本文件单一实现，无双份内联 |
| R4 白名单不可参数化 | ✅ 常量内嵌本文件，非函数参数（DESIGN §9.1 盲审 R4：参数化会允许调用方削弱白名单） |
| R5 compliance 保护（ADR-013/024） | ✅ dedupe/trim 作用域严格限 check ∈ 白名单；compliance 逐字节保留 + 相对顺序不变（smoke 断言字节级） |
| R6 静态门禁 | ✅ bash -n 0 错误 · shellcheck 0 error（文件自带 `#!/bin/bash` shebang，SC2148 天然满足，无需额外 `# shellcheck shell=bash`）· 既有 35 测试全绿 |

## 越界检查（R6.5）

`git diff --name-only` vs write_files（`flow-kit-bundle/hooks/stop/lib/correction-file.sh`）——**本任务改动恰 1 文件**：

```
$ git diff flow-kit-bundle/hooks/stop/lib/correction-file.sh | grep -c '^+'      # 新增 166 行
166
$ git diff flow-kit-bundle/hooks/stop/lib/correction-file.sh | grep '^-'        # 唯一 '-' 为 diff 头
--- a/flow-kit-bundle/hooks/stop/lib/correction-file.sh
```

工作树其余改动（CONTEXT.md / Makefile / README.md / 29-independent-review.sh / dsh-scm-test-untracked.txt / 未跟踪的 .specs 目录）均为本 change 前期阶段或其他并行任务（T03/T04）既有产物，非 T01 触碰。

## 既有抽象 grep（R6.4）

```
$ grep -rn "dedupe\|unique_by" flow-kit-bundle/hooks/
flow-kit-bundle/hooks/stop/lib/correction-file.sh:40:  # merge 注释（既有 correction_file_write merge strategy 文档）
flow-kit-bundle/hooks/stop/lib/correction-file.sh:57:  # merge 注释（既有，full object 去重，非数组级 helper）
flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh:102: unique_by({layer, rule, location})  # 28 号 compliance 内部 merge 专用，非通用 helper
```

**结论**：除 28 号 compliance 内部 merge 的 `unique_by`（其 own 去重键，与数组级卫生 helper 职责不同）外，无既有 dedupe/trim/strip helper —— 本次新增为该项目首例数组级 correction 卫生抽象，无重复实现。⚠️ 修一个调试中发现的既有文档小误：correction-file.sh:40 注释称 merge「dedupe by gate_type+tool」，实际实现为 full object `unique`（L64）——仅注释与实现不符，未改函数体（在禁动边界内，登记为既有技术债备注）。

## 关键实现决策

- **jq 管道陷阱（已实测修复）**：`$wl | index(.check)` 中 `.check` 绑定到 `$wl`（数组）而非 violations 元素 → `Cannot index array with string "check"` 运行时错误。dedupe 用绑定变量 `$item.check`（无此问题）；trim 的 `map(select(...))` 改用 `select(. as $e | ($e.check and ($wl | index($e.check))))` 绑定后取字段。
- **去重键分隔符**：jq 不支持八进制 `\0` 转义（编译错误），用 `"\u0000"`（NUL）分隔 `check`+`field`，杜绝 `check="a" field="bc"` 与 `check="ab" field="c"` 键碰撞。
- **错误语义**：`jq -e` + `empty` guard 使「无 violations 数组 / 非法 JSON / 无输出」统一静默非零，且文件仅在成功分支 mv（失败路径 rm tmp + return 1，文件字节不动）。
- **返回值契约（strip_type）**：bash 层先读 type → 无 `+` → 返回 1（纯 type no-op，调用方各自走 rm/保留分支）；segment 不在合并标签 → 返回 0；命中才走单步 jq `.type = $nt` 原子写（TD-012 无管道吞码）。
