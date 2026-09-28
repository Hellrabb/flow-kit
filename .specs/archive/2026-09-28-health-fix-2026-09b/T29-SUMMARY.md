# T29-SUMMARY · health-fix-2026-09b · AC-8 全量质量门禁收口

## 任务

T29（收口 task · AC-8）：跑全量质量门禁并留档，确认本 change 阶段 4（DEV）全部 28 个前序 task 交付后**无退化**。具体：

- `make check` 全绿（含两道新门禁 `check-gate-sync` / `check-path-privacy` + NFR 三态 `check-nfr-portability`）；
- `npx bats test/` ≥ 973 ok / 0 not ok（实测基线 **976 ok / 0 not ok / 0 skip**）；
- 三道副本一致性门禁 `check-test-sync` / `check-hooks-sync` / `check-dist` 0 漂移；
- **NFR 兼容性判据三态显式处理**：变更集为空时 `check-nfr-portability` 以 `exit 3`（SKIP）呈现 —— **不得把 SKIP 当绿灯**；先用 `.specs/health-fix-2026-09b/.change-base` 锚点断言变更集非空。

另含主 agent 授权的**陈旧口径清理**（严格限措辞/标签，不改语义、不改断言结构）。

## 产物（before → after）

本 task 无源码面改动（`write_files` = 无仓内文件）。仅做门禁验证 + 陈旧口径订正（4 处，均在 `.md` 文档，不改断言结构、不收紧阈值）：

### 1. `.specs/STATE.md:48`（test_framework 行）

- **before**：`973 ok / 0 not ok / 1 skip（…skip = 既有 test_lessons_cleanup.bats:137 AC-4…） · 8 in test_guide_copy_parity.bats`
- **after**：`976 ok / 0 not ok / 0 skip（TAP plan 1..976；2026-09-24 health-fix-2026-09b T29 全量实测）`；删去过时的 skip 归因与数字订正注（原算术订正已不适用）。

### 2. `.specs/health-fix-2026-09b/TASK.md:905`（T20 `<done>` 标签）

- **before**：`AC-6①：pre-commit 仓库内源已接入新门禁…`
- **after**：`AC-6③：pre-commit 仓库内源已接入新门禁…`（阶段 3 起草笔误；T20 判据与 SUMMARY 均按 ③ 执行）。

### 3. `.specs/health-fix-2026-09b/T25-SUMMARY.md:105`（回归行）

- **before**：`make test` 973 ok / 0 not ok / 1 skip`
- **after**：`make test` 976 ok / 0 not ok / 0 skip`（附 T29 收口订正说明）。

### 4. `.specs/health-fix-2026-09b/TASK.md` T27 块 `<verify>` / `<done>` 提示字符串

- T27 `<verify>` echo：`基线 2026-09-23 实测 rc=0 / 973 ok / 0 not ok` → `基线 2026-09-24 T29 收口实测 rc=0 / 976 ok / 0 not ok`；
- T27 `<done>`：`基线 2026-09-23 实测 973 ok / 0 not ok` → `基线 2026-09-24 T29 收口实测 976 ok / 0 not ok`；
- **阈值 `-ge 973` 保持不收紧**（防止无关 task 数变化造成假红）。

另翻转 T29 自身 `status`：`pending` → `done`。

## 判据实跑

所有输出均为本机实测（路径已脱敏为 `/home/<acct>/` 占位，L-129）。

### C3：两道新门禁已接线（`make -n check` 命中）

```
$ make -n check 2>/dev/null | grep -E 'check-(gate-sync|path-privacy)'
echo "🔍 make check-gate-sync: prompt↔skill 协议一致性检查 ..."
bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
echo "🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ..."
bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
```

### `make check` 全绿

```
🔍 make check-nfr-portability: NFR 兼容性判据（bash 3.2/macOS 可移植 · 三态包装）...
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过

╔════════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚════════════════════════════════════════════════════╝
CHECK_RC=0
```

### bats 计数（`npx bats test/ --formatter tap` 直跑）

```
ok 974 CF-01: write_compliance_correction creates valid JSON with all fields
ok 975 CF-02: write_compliance_correction merges with existing + dedup
ok 976 CF-03: clear_compliance_correction removes the file
SUMMARY: ok=976 not_ok=0 skip=0
b_rc=0
```

基线 = **976 ok / 0 not ok / 0 skip**（`make test` 的 stdout 是装饰性截断，不可信；本计数由 `npx bats test/` 直跑得到）。

### 三道副本一致性门禁

```
make check-test-sync   → rc=0
make check-hooks-sync  → rc=0
make check-dist        → rc=0
```

### `.change-base` 非空断言

```
BASE8=534e3e842fc900045f39492badc66eabe3ffd4c4
FILES(.sh) count=10
flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
flow-kit-bundle/hooks/pre-commit/pre-commit.sh
flow-kit-bundle/hooks/pre-push/pre-push.sh
flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh
flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
flow-kit-bundle/lib/install_hooks.sh
flow-kit-bundle/lib/validate_staging.sh
package-flow-kit.sh
sync-hooks.sh
```

变更集非空（10 个 `.sh` 文件）⇒ NFR 兼容性判据在非空集上运行，未出现 `SKIP:`（`make check` 输出 `✅ NFR 兼容性判据通过`，无 SKIP 字样）。

### 活性演示（守卫非恒绿）

把 T29 `<verify>` 原样抽到临时文件后，以 `FLOW_KIT_CHANGE_BASE=HEAD` 跑一次：

```
$ FLOW_KIT_CHANGE_BASE=HEAD bash /tmp/t29_verify_demo.sh
…
bats: rc=0 ok=976 not-ok=0（基线 2026-09-24 T29 收口实测 rc=0 / 976 ok / 0 not ok；skip 计入 ok 行）
🔴 AC-8 时点变更集为空（相对锚点 HEAD）⇒ 兼容性判据 rc=3（未验证），不得当作通过
DEMO_RC=1
```

**rc=1** 且打印 `🔴 AC-8 时点变更集为空…` ⇒ 守卫在空变更集时正确判红，不是恒绿。演示未改动任何仓内文件（`git status --short` 仅 5 份既有 `A ` 保护文件）。

## 六维自查

- **正确性**：`make check` rc=0 全绿（含 `check-gate-sync` / `check-path-privacy` / `check-nfr-portability` 三道本 change 新增门禁）；`npx bats test/` 直跑 976 ok / 0 not ok / 0 skip；三道副本一致性门禁 rc=0；`.change-base` 锚点在位（`534e3e8…`）且变更集非空（10 `.sh`）。活性演示证明守卫非恒绿（`FLOW_KIT_CHANGE_BASE=HEAD` ⇒ rc=1 + 正确报文）。
- **完整性**：本 task `write_files` = 无仓内文件；仅做门禁验证 + 4 处陈旧口径订正（均在 `.md`，不改断言结构、不收紧 `-ge 973` 阈值）。提交仅含 4 个路径（本 SUMMARY 新建 + `TASK.md` + `STATE.md` + `T25-SUMMARY.md`），未触碰 6 份 `A ` 保护文件及其他禁动文件。
- **回归**：bats 976 ok / 0 not ok / 0 skip（较 T27 记录的 976 一致，无退化）；`make lint` rc=0（shellcheck 无错）；`make check-path-privacy` 清单外命中 0。
- **可维护性**：口径订正均为字面替换（标签 ①→③、计数 973→976、日期 2026-09-23→2026-09-24），不引入新维护点；阈值保持 `-ge 973` 不收紧。
- **安全与隐私**：本 SUMMARY 不落任何真实账号字形（路径一律 `/home/<acct>/` 占位）；`make check-path-privacy` 清单外命中 0；活性演示用临时文件，未改仓内文件。
- **文档一致性**：STATE.md / T25-SUMMARY / TASK.md（T27 提示串 + T20 标签 + T29 状态）口径已对齐实测 976 ok / 0 not ok / 0 skip；未碰 `MINOR-DEFERRED.md`（已登记项不重报）；L-146 修复注释（T29 verify 首行）保持原样，未引入全局 `export LC_ALL=C`。

## 遗留

无。`MINOR-DEFERRED.md` 已登记项（R7 / C7 / D5 / D6 / G1 / G2 / C5 / R2 / R3 等）不在本 task 修复范围，未当作新缺陷重报。本 change 阶段 4（DEV）29 个 task 全部交付。
