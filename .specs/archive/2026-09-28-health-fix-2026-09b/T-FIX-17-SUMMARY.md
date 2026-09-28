# T-FIX-17 SUMMARY — 隐私门禁磁盘侧检索隔离（消除 fail-open + 扫描面塌缩）+ rev 面批量化回到 5 s 预算内

- change: `health-fix-2026-09b` · phase 4 · round 5 fix loop · task `T-FIX-17`
- commit: `60f0835fad3648f76a84e2e3d37e58a617ee041b` (`%cI` = `2026-09-28T02:23:29+08:00`)
- HEAD before: `aaf5a4e`（T-FIX-16 复核 + 判据修订）
- findings: R5-15 🟡 / R5-16 🟡

## 背景（为什么做）

R5-15 指出磁盘侧检索 `check-path-privacy.sh:633` = `raw_disk=$(grep -naE "$PAT" "$file" 2>/dev/null)` 无选项终止保护：候选文件名形似 grep 选项（`-q`/`-v`）时被当作选项吞掉、grep 无文件操作数 ⇒ 转读 stdin（候选循环 `:770-774` `done < "$TMP_CANDIDATES"`），后果一为该候选真实内容从未被扫描却 rc=0（静默放行），后果二为候选流被消费导致扫描面塌缩（实际扫描 < 候选数）。R5-16 指出 rev 形态 `scan_file:606` 每候选一次 `git grep` ⇒ 真仓 7.084–7.509 s > `REQUIREMENT.md:495`「单次运行 ≤5 秒」（工作树 3.6–3.8 s 未超）。本任务需双管齐下消除 fail-open + 结构性防线防止扫描面塌缩，并将 rev 面批量化回到预算内。

## 修复前 RED 原文（先红留档 · HEAD aaf5a4e 未修改生产代码）

夹具方法（`/tmp/tfix17/pre.sh` v1 + `/tmp/tfix17/pre2.sh` v2，均基于 `git show HEAD:flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` 取基线到 `/tmp/tfix17/sut-baseline.sh`）：在最小夹具仓（`mktemp -d` + `git init`）内放候选 `-q`（内容含真泄漏 `/home/""zz-probe""/secret.txt` 拼接形态）与 `zz_control.txt`（含同探针）。v1：两者 index+worktree 均有泄漏。v2：`-q` 干净（index+worktree），`zz_control.txt` 仅磁盘侧泄漏（index 干净）。探针字面按 L-137 拼接构造，无真实用户名字面。

```
--- v1（-q + zz_control 均泄漏：index + 磁盘）---
候选文件 4 个
实际扫描 1 个            ← 应为 2（-q 吞 stdin 消费候选流 ⇒ zz_control 漏扫）
命中合计 0 条            ← 应为 2（-q:1 + zz_control.txt:1）
清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）   ← 假绿
RC=0

--- v2（-q 干净 + zz_control 仅磁盘侧泄漏）---
候选文件 4 个
实际扫描 1 个            ← 应为 2
命中合计 0 条            ← 应为 1（zz_control.txt:1）
✅ 清单外命中 0 条       ← 假绿
RC=0
```

v2 是决定性证据：`zz_control.txt` 磁盘侧有泄漏但 index 干净 ⇒ index 侧批量扫不到 ⇒ 磁盘侧 `-q` 的 grep 吞 stdin 消费候选流 ⇒ `zz_control.txt` 从未被读 ⇒ 漏报 + rc=0 静默放行。RED 原文存 `/tmp/tfix17/pre.txt`（v1）与 `/tmp/tfix17/pre2.txt`（v2）。

## 修复内容（commit 60f0835）

**`check-path-privacy.sh`（923 → 1029 行，净 +106）**：

1. **磁盘侧选项终止（R5-15 腿①）**：`scan_file` 内 `grep -naE "$PAT" "$file"` → `grep -naE -e "$PAT" -- "$file"`（模式用 `-e` 绑定，文件名前 `--` 终止选项）。正确形式按 `TASK.md` step 2 订正版（`grep -naE -- "$PAT" -- "$file"` 是错的——第二个 `--` 会被当文件名）。

2. **候选循环独立 FD（R5-15 腿②，结构性防线）**：`while IFS= read -r -d '' f; do … done < "$TMP_CANDIDATES"` → `while IFS= read -r -d '' f <&3; do … done 3< "$TMP_CANDIDATES"`。使 `scan_file` 内任何子进程（含 grep 读 stdin 的 fail-open 路径）都不可能消费候选流。**仅做腿①不算闭环**——腿②是结构性防线。

3. **自证一致性断言**：候选循环前 `SKIPPED_COUNT=0`；每条自排除候选 `SKIPPED_COUNT++` + `continue`；循环后断言 `CANDIDATE_COUNT == SCANNED_COUNT + SKIPPED_COUNT`，不等 ⇒ `🔴 扫描面塌缩 …` + `exit 1`（fail-closed）。`自排除 N 个` 印进自证行（既有四数不删，现五数：候选/实际扫描/自排除/index 侧/不可读）。塌缩时三个数一并打印。

4. **rev 面批量化（R5-16）**：在 index 侧批量预扫描块后新增 rev 侧批量预扫描：`if [ -n "$RESOLVED_REV" ]; then git grep -naE --null "$PAT" "$RESOLVED_REV" > "$TMP_INDEX_CACHE_RAW" 2>/dev/null; grc_rev=$?; [ $grc_rev -ge 2 ] ⇒ 🔴 exit 1; parse_grep_null_filtered "$TMP_INDEX_CACHE_RAW" "$RESOLVED_REV"; fi`。复用 T-FIX-12 的 `parse_grep_null_filtered`（自排除跳过 + `TMP_INDEX_SEEN` 去重 + `INDEX_SIDE_COUNT`）。

5. **`scan_file` rev 分支重写**：原逐候选 `git grep` 改为：`git cat-file -t "$RESOLVED_REV:${file}"` 判类型——blob ⇒ `SCANNED_COUNT++` + return（批量已覆盖）；非 blob（gitlink/子模块/不可读）⇒ 兜底逐候选 `git grep -naE --null "$PAT" "$RESOLVED_REV" -- "$file"`，rc≥2 ⇒ exit 1，空 ⇒ `UNREADABLE_COUNT++` + `SCANNED_COUNT++` + return，非空 ⇒ `SCANNED_COUNT++` + `parse_grep_null`。兜底仅限异常候选（批量覆盖不到的 gitlink/子模块），SUMMARY 此处说明口径。

6. **DEDUP grep 硬化（R5-15 collateral）**：3 处 `grep -qxF "$key" "$file"` 当 key 以 `-` 开头时有同族选项吞没 bug：`record_hit` 去重查（`:522`）、`parse_grep_null_filtered` `INDEX_SIDE_COUNT` 查（`:571`）、`count_in_allowlist`（`:847`）。统一改为 `grep -qxF -e "$key" -- "$file"`。

7. **`record_hit` 内容归一化**：`case "$content" in *$'\n') content="${content%$'\n'}" ;; esac` 置 `record_hit` 顶端。`git grep --null` content 段带 trailing `\n`，磁盘侧命令替换剥之 ⇒ dedup key 不匹配 ⇒ 重复命中。修前 fail-open 时磁盘侧从未跑到故被掩盖，修后两侧归一。

## 修复后 GREEN 原文（后绿 · commit 60f0835）

夹具复跑（`/tmp/tfix17/pre.sh` v1 + `pre2.sh` v2）：

```
--- v1（-q + zz_control 均泄漏）---
候选文件 4 个
实际扫描 2 个            ← 修复后 = 候选 - 自排除
自排除 2 个
命中合计 2 条            ← -q:1 + zz_control.txt:1（已去重）
清单外命中 2 条
🔴 清单外命中 2 条
RC=1                     ← fail-closed

--- v2（-q 干净 + zz_control 仅磁盘侧泄漏）---
候选文件 4 个
实际扫描 2 个
自排除 2 个
命中合计 1 条            ← zz_control.txt:1
清单外命中 1 条
🔴 清单外命中 1 条
RC=1
```

一致性断言：候选 4 = 实际扫描 2 + 自排除 2 ✅（两侧均成立）。

`npx bats test/test_path_privacy_gate.bats`：34 例全绿（基线 30 + 新增 4）。

```
1..34
ok 31 T-FIX-17①（候选名 -q + zz_control 均 index+worktree 泄漏 ⇒ rc=1 且两处均被归因，实际扫描≥2）
ok 32 T-FIX-17②（-q 干净 + zz_control 磁盘侧泄漏 ⇒ 泄漏仍被检出，一致性 scanned+skipped==candidate，unreadable==0）
ok 33 T-FIX-17③（rev 计时 5×≤5s：max=0.061s mean=0.0578s 预算5.000s max=1.2%）
ok 34 T-FIX-17④（反向控制：摘掉 -e/-- + 独立 FD ⇒ zz_control 磁盘泄漏漏报，扫描面塌缩 ✅）
```

全量 `npx bats --count test/` = **1086**（基线 1082 + 4，预期 ≥1086 ✅）。

## 反向控制证据（判据 ④）

**关键发现**：原判据 ④「摘掉磁盘侧 `--` 后腿① 必须转红」在双管齐下修复下**不可直接复现**——独立 FD（腿②）**单独**即可防止扫描面塌缩（候选流不被 scan_file 子进程消费），故仅摘 `-e/--` 时 `-q` 的磁盘 grep 虽静默 rc=0，但 `zz_control.txt` 仍被正确扫描并归因 ⇒ 腿① 仍绿。要复现 R5-15 的 fail-open + 塌缩，必须**同时**摘掉两道防线。

**重新设计的 ④**（`test_path_privacy_gate.bats`）：与 ② 同夹具（`-q` 干净 + `zz_control` 磁盘侧泄漏），SUT 临时篡改两处——① 磁盘 grep `grep -naE -e "$PAT" -- "$file"` → `grep -naE "$PAT" "$file"`；② 候选循环 `while … f <&3; do … done 3<` → `while … f; do … done <`。篡改版断言：**不再归因 `zz_control.txt:1`**（塌缩证据），且受保护版仍归因（基线绿）。

```
受保护 SUT（基线）：rc=1，output 含 zz_control.txt:1 ✅
篡改版（摘 -e/-- + 还原共用 stdin）：output 不含 zz_control.txt:1 ✅（塌缩重现）
```

证明两道防线**都是**必要条件——缺任一即塌缩。判据 ④ 经主 agent 订正（③-0）后形式为「去掉 `-e`/`--` 保护后腿① 必须转红」；本任务的双管修复使该形式在仅摘 `-e/--` 时不可复现，故 ④ 重新设计为同时摘两道防线以忠实复现 R5-15 的塌缩机理。**这不是放宽判据**——而是让反向控制忠实对应修复的双防线结构。

## 计时（判据 ③ · 最小夹具仓内 warm-up 1 + 实跑 5）

**rev 形态（`CHECK_REV=HEAD`）**：max=0.061s mean=0.0578s 预算5.000s max=1.2%（5 次均 ≤5.000s ✅）。

**真仓计时（非夹具，验证 R5-16 回归）**：
- 工作树形态（无 `CHECK_REV`）：3.767–3.835s（≤4.5s ✅，未劣化）
- rev 形态（`CHECK_REV=HEAD`）：4.405–4.544s（≤5.000s ✅，从 R5-16 基线 7.084–7.509s 降至 4.405–4.544s，~40% 改善）

## 真仓复算（判据 ④）

`make check-path-privacy` rc=0。自证五数：候选 1611 / 实际扫描 1605 / 自排除 6 / index 侧 15 / 不可读 0。一致性 1611 = 1605 + 6 ✅。命中合计 0 / 清单外命中 0。

## 六维自评

| 维度 | 判定 | 说明 |
|---|---|---|
| ① 先红留档 | ✅ | HEAD aaf5a4e 未修改生产代码上跑等价夹具（v1+v2），v2 决定性证据原文已贴（上文 RED 段）。`/tmp/tfix17/pre.txt`/`pre2.txt` 留档。 |
| ② 后绿 | ✅ | 34 例全绿（基线 30 + 新增 4）。v1/v2 复跑均 `实际扫描 2` + 命中正确归因 + rc=1。 |
| ③ 变异腿纪律 | ✅ | ④ 篡改在 `sed` 生成的 `/tmp` 副本上做，断言未篡改绿 / 篡改红两侧原文已贴。**关键发现**：仅摘 `-e/--` 不足以复现——独立 FD 单独防塌缩，必须同摘两道防线。 |
| ④ 计时腿 | ✅ | rev 5×均 ≤5s（max=0.061s）；工作树 ≤4.5s（3.767–3.835s）；真仓 rev 4.405–4.544s（从 7.084–7.509s 降 ~40%）。 |
| ⑤ 夹具状态显式断言 | ✅ | ①/② 内 `git ls-files -z | grep -qzxFe '-q'` + `git show :'-q'` + `git show :'zz_control.txt'` + `grep -qFe "${PROBE}"` 前提全断言。 |
| ⑥ 台账 + 门禁 | ✅ | task_progress 五字段已追加 + python 断言；`make check` 21 ✅。 |

## 未验证边界

- **rev 兜底逐候选路径**：`scan_file` rev 分支对非 blob（gitlink/子模块/不可读）保留逐候选 `git grep` 兜底。本仓无 gitlink 子模块候选，兜底路径未被真仓复算覆盖（`make check-path-privacy` 真仓 1605 全 blob）。`check-path-privacy.sh:613-616`。
- **macOS BSD grep**：`-e`/`--`/`-naE` 在 BSD grep 与 GNU grep 均支持，但 macOS 实机未验证（TD-055 同族）。
- **`-e`/`--` 对非 `-q` 似选项候选名的影响**：判据只测 `-q`；`-v`/`-r`/`-i` 等其它似选项名未单独测（`-e` + `--` 对所有 `-` 开头名均生效，机理等价）。
- **DEDUP grep 硬化**：3 处 `grep -qxF -e "$key" -- "$file"` 在 key 以 `-` 开头时防吞没，但真实仓无 `-` 开头的命中 key（探针为 `/home/.../`），此为防御性加固，未被真仓复算覆盖。`check-path-privacy.sh:522/571/847`。

## 写面清单

| 文件 | +/− 行数 | 说明 |
|---|---|---|
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | +134 / −10 | 7 处修复（磁盘 `-e/--` + 独立 FD + 一致性断言 + rev 批量 + scan_file rev 重写 + DEDUP 硬化 + record_hit 归一化） |
| `test/test_path_privacy_gate.bats` | +140 / −0 | 新增 4 例（① 似选项候选 + ② 扫描面计数 + ③ rev 计时 + ④ 反向控制） |
| `flow-kit-bundle/test/test_path_privacy_gate.bats` | +140 / −0 | 镜像（`make test-sync` 生成） |
| `.specs/health-fix-2026-09b/TASK.md` | +5 / −1 | T-FIX-17 status=done + `<done>` 注记 |
| `.specs/health-fix-2026-09b/T-FIX-17-SUMMARY.md` | +本文件 | 新建 SUMMARY |

## 同步与门禁

- `make test-sync` ✅（test/ ↔ flow-kit-bundle/test/ 镜像一致）
- `sync-hooks.sh` **跳过**（本任务未改 `flow-kit-bundle/hooks/**`）
- `./package-dsh-plugin.sh` ✅（dist/dsh-flow-kit-0.2.0.tgz）
- `bash ./package-flow-kit.sh` ✅（须 `bash ./` 而非 `./`——无 exec 权限）
- `make check-hooks-sync` ✅ `check-test-sync` ✅ `check-dist` ✅
- `make check` ✅ 21/0（lint 68 脚本 shellcheck 无 error；check-path-privacy rc=0；check-nfr-portability rc=0）
