# T-FIX-11-SUMMARY — 不可读候选判定与 index 内容面口径（R4-1）

**change**: `health-fix-2026-09b`
**task**: T-FIX-11（阶段 6 第 3 轮 🟡 R4-1 · 用户裁决「本 change 内修」）
**round**: R4-1（fix_rounds: 0）
**date**: 2026-09-25

## 1. 问题

阶段 6 第 3 轮对抗式审计发现：本 change 新写的 `check-path-privacy.sh`（工作树模式 `scan_file()`）在
「候选面 = index（`git ls-files`）、内容面 = index ∪ 工作树」的既定口径下，把**已跟踪但未 staged 删除、
磁盘缺失**的候选项无条件计入「不可读候选」（`UNREADABLE_COUNT++`）⇒ 整门禁变红（过严红）。
更糟的是：`exit 1` 早退把 index 侧 `git grep --cached` 已扫到的泄漏命中行**遮住**（内容面被「不可读」红遮住）。

根因：`scan_file()` 磁盘侧 `[ -f "$file" ]` 为假时**无条件** `UNREADABLE_COUNT++`，未探 index 侧对象类型。

## 2. 修复前红原文（我自己跑出，非引用主 agent 结论）

夹具：`/tmp/tfix11-my-verify.sh`（自建，绝对路径 S，L-137 拼接探针 `/home/''zz-probe-d/leak.txt`，
`FLOW_KIT_PRIVACY_ALLOWLIST` 指向真仓清单绝对路径）。完整输出存底 `/tmp/tfix11-pre-fix.txt`。

```
===== ① 删未 staged·干净（修复前预期红：rc≠0 且 不可读候选≠0） =====
rc=1
   候选文件 1 个
   实际扫描 1 个
   不可读候选 1 个
🔴 不可读候选 1 个（缺失/不可读 ⇒ fail-closed，不得折算为干净）
   sub/clean.sh

===== ② 删未 staged·index 含泄漏（修复前后都应 rc≠0 + 清单外命中） =====
rc=1
   候选文件 1 个
   实际扫描 1 个
   不可读候选 1 个
🔴 不可读候选 1 个（缺失/不可读 ⇒ fail-closed，不得折算为干净）
   sub/leak.sh
   （注：未打印「清单外命中 [1-9]」—— exit 1 早退把 index 侧泄漏遮住）

===== ③ gitlink 候选（修复前后都应 rc≠0） =====
git cat-file -t :submod => commit
rc=1
   候选文件 2 个
   实际扫描 2 个
   不可读候选 1 个
🔴 不可读候选 1 个（缺失/不可读 ⇒ fail-closed，不得折算为干净）
   submod

===== ④ 磁盘可读·干净（基线绿腿，应 rc=0） =====
rc=0
   ✅ 清单外命中 0 条

PRE-FIX SUMMARY: rc=3（① ② ③ 腿红；④ 绿）— ① 过严红未修；② 内容面被遮；③ gitlink 正确 fail-closed
```

修复前红腿：① rc=1 + `不可读候选 1 个`（过严红）；② rc=1 但**未打印** `清单外命中 [1-9]`（内容面被遮）。
③④ 行为正确（gitlink fail-closed / 基线绿）。

## 3. 修复后绿原文

完整输出存底 `/tmp/tfix11-post-fix.txt`。

```
===== ① 删未 staged·干净 =====
rc=0
ℹ️ 磁盘缺失但 index 侧可读：sub/clean.sh（内容面按 index 扫描）
   不可读候选 0 个
   清单外命中 0 条
✅ 清单外命中 0 条

===== ② 删未 staged·index 含泄漏 =====
rc=1
ℹ️ 磁盘缺失但 index 侧可读：sub/leak.sh（内容面按 index 扫描）
   index 侧 1 条
   不可读候选 0 个
   命中合计 1 条
   清单外命中 1 条
   ── 清单外命中归因（file:line）──
   sub/leak.sh:1: echo <PROBE>/leak.txt
🔴 清单外命中 1 条

===== ③ gitlink 候选 =====
git cat-file -t :submod => commit
rc=1
   不可读候选 1 个
🔴 不可读候选 1 个（缺失/不可读 ⇒ fail-closed，不得折算为干净）
   submod

===== ④ 磁盘可读·干净 =====
rc=0
   ✅ 清单外命中 0 条

POST-FIX SUMMARY: rc=0（全绿）— ① 过严红修复；② index 侧泄漏被检出且打印归因；③ gitlink 仍 fail-closed
```

## 4. 改动逐文件说明

| 文件 | +/− | 说明 |
|---|---|---|
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | +16/−3 | `scan_file()` 工作树模式磁盘侧 `[ -f "$file" ]` 为假分支改写：先探 `git cat-file -t ":$file"`，blob ⇒ 不递增 `UNREADABLE_COUNT` 且打印 `ℹ️ 磁盘缺失但 index 侧可读：<file>（内容面按 index 扫描）`；非 blob/探测失败/gitlink（`commit`）⇒ 维持 fail-closed（`UNREADABLE_COUNT++` + 详情）。index 侧 `git grep --cached -naE --null` 逐字不变、无条件保留。 |
| `test/test_path_privacy_gate.bats` | +56/−0 | 追加 3 例：T-FIX-11①（删未 staged·干净 rc=0 且「不可读候选 0 个」+ 提示行）· T-FIX-11②（同删除态 index 含泄漏 rc≠0 且 `清单外命中 [1-9]`）· T-FIX-11③（gitlink 候选 `git update-index --add --cacheinfo 160000,<sha>,submod` rc≠0）。三例夹具一律 `mktemp` 隔离、拼接探针 `${PROBE}`、`FLOW_KIT_PRIVACY_ALLOWLIST` 指向空覆盖清单（避免 CWD 读序依赖）。 |
| `flow-kit-bundle/test/test_path_privacy_gate.bats` | +56/−0 | `make test-sync` 镜像（与 `test/` 逐字节一致）。 |
| `.specs/STATE.md` | +3/−1 | bats 基线计数行 1058→1061 + 演进注记。 |
| `.specs/health-fix-2026-09b/TASK.md` | +4/−4 | T-FIX-11 块 `status="pending"`→`"done"` + `<done>` 注记。 |

## 5. 六维自检

1. **判定口径**：磁盘缺失先探 index 侧 `git cat-file -t ":$file"` ⇒ blob 不计不可读；非 blob/gitlink 维持 fail-closed。✅
2. **index 内容面不回退**：`git grep --cached -naE --null` 逐字不变、无条件保留；修复后 ② 腿 index 侧泄漏被检出并打印归因。✅
3. **计数自洽**：`SCANNED_COUNT` = 内容面至少一侧可读；「不可读候选」只统计两侧皆不可得者；自证四数（候选/扫描/index 侧/不可读）不回退为静默折算成干净。✅
4. **gitlink 仍红**：`git cat-file -t :submod` = `commit`（非 blob）⇒ `UNREADABLE_COUNT++` + fail-closed。✅
5. **bash 3.2 可移植**：无 `declare -A`/`mapfile`/`readarray`/`realpath`/`stat -c`/`sed -i`；`make check-nfr-portability` 全绿。✅
6. **去标识化**：仓内文本（SUMMARY/TASK.done）无真实家目录路径/账号/项目名；探针用拼接构造（`/home/''zz-probe-d/leak.txt`、`${PROBE}`）。✅

## 6. `.specs/STATE.md` 新基线

bats 基线计数行：**1061 ok / 0 not ok / 0 skip**（TAP plan 1..1061；T-FIX-11 全量实测）。
= T-FIX-10 基线 1058 + T-FIX-11 不可读候选判定 3 例（test_path_privacy_gate.bats T-FIX-11①②③）。
`npx bats --count test/` 同步为 1061。

## 7. `<verify>` 原样实跑结果

`<verify>` 静态块原样跑（`/tmp/tfix11-verify-orig.txt`）：**rc=1（非全绿）—— 判据自身路径缺陷**：
块内 `S=flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（**相对路径**）+ `FXR()` 内 `cd "$FX" && bash "$S"`
⇒ 进入 `mktemp -d` 夹具仓后相对路径解析失败 ⇒ `rc=127 没有那个文件或目录`。此为判据块自身的路径转录缺陷，
**未自行放宽**：主 agent 独立夹具（`/tmp/p6c/verify-tfix11.sh`，`S="$R/flow-kit-bundle/..."` 绝对路径）与我自建夹具
（`/tmp/tfix11-my-verify.sh`，绝对路径 S）均跑通四腿 + bats + 真仓 + 三一致性 + make check，意图与判据四腿一致。

关键输出（绝对路径 S 跑通的夹具）：
- ① rc=0 + `不可读候选 0 个` + `ℹ️ 磁盘缺失但 index 侧可读`
- ② rc=1 + `清单外命中 1 条` + `sub/leak.sh:1: echo <PROBE>/leak.txt`
- ③ rc=1 + `不可读候选 1 个`（gitlink `commit`）
- ④ rc=0 + `清单外命中 0 条`
- bats 常设网：`1061 ok / 0 not-ok / count=1061`
- 真仓 `make check-path-privacy`：`不可读候选 0 个` + `✅ 清单外命中 0 条`
- `make check`：**全部通过**

## 8. 遗留问题 / 风险

1. **`<verify>` 静态块路径缺陷**（判据自身）：`.specs/health-fix-2026-09b/TASK.md:2338`（`S=flow-kit-bundle/...` 相对路径）+
   `:2339`（`FXR()` `cd "$FX" && bash "$S"`）⇒ rc=127。判据意图清晰（四腿 + bats + 真仓 + 三一致性 + make check），
   主 agent 夹具与我自建夹具用绝对路径 S 均跑通。**建议主 agent 后续把 TASK.md 内 `<verify>` 的 `S=...` 改为绝对路径**
   （`S="$R/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh"`）以消除路径缺陷。未在本任务内改判据（L-166）。
2. **真仓 `不可读候选 0 个`**：修复后真仓 `make check-path-privacy` 报 `不可读候选 0 个`（候选 1598 / 扫描 1592 / index 侧 13）。
   工作树内确有 6 个「已跟踪但磁盘缺失」的候选（被 `.git/index` 覆盖的删除态），修复前会被误报为不可读，
   修复后正确按 index 侧 blob 处理。无风险。
3. **提示行非断言必需**：`<verify>` ① 腿对 `ℹ️ 磁盘缺失但 index 侧可读` 提示行的断言是「若实现选择静默兜底，请在 SUMMARY 说明」
   （非硬断言）。本实现选择打印该行，bats T-FIX-11① 进一步断言该行存在。无风险。
