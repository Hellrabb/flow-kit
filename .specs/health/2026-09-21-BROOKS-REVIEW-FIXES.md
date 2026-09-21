# brooks-review 2026-09-21 发现的修复记录（Remedy Mode）

> 对象：`.specs/health/2026-09-21-BROOKS-REVIEW.md` 的 3🟡 + 3🟢（无 🔴）。
> 形态：**热修**（未走 flow pipeline，与 `l3-review-defects-2026-09` 同型：直接响应外部报告）。
> 未重评分（Remedy Mode 规定：Health Score 反映诊断时状态，不反映修复后状态）。

## 逐条处置

| # | 发现 | 修复 | 证据 |
|---|---|---|---|
| 🟡1 | §8/§9/§10c 在无活跃 change 时静默改核**另一个 change** 的工件 | `verify-claims.sh`：删隐式历史回退 → 三态解析（0 解析到 / 1 未指定 / 2 指定了找不到）；新增 `spec_target()` 统一处置；PASS/FAIL 文案**指名**解析到的路径；新增 `<change-id>`、`<base-ref>` 两个参数；无法核对项计 **⏭ SKIP**（不入退出码） | 实测：无 id → `rc=1`（此前返回 `.specs/archive/2026-09-18-l3-review-defects-2026-09/DESIGN.md`）· 指定 `health-fix-2026-09` → 正确解析到 `.specs/archive/2026-09-21-health-fix-2026-09/DESIGN.md` · 指定不存在 id → `rc=2`（FAIL） |
| 🟡2 | 新门禁零 bats 覆盖；§10d ②/④ 是源码文本判据（死定义可过） | 新增 `test/test_gate_freshness.bats`（9 例，真跑命令）+ `make test-sync` 双源；`§10d` 删 ②（① 已覆盖）、④ 改**行为断言**（走 `sync-hooks.sh --entry-class` 自检出口，真入口 rc=0 / 库 rc=1） | 9/9 全绿；全量 bats **950 → 959 ok / 0 not ok**。**后续（同日回溯登记为 change `brooks-review-fix-2026-09`）**：审查期补了用例 10（`--entry-class` 未知前缀 rc=2）、11（`<base-ref>` fail-closed rc=2）与 12（**L3 阶段6 critical 的回归**：必需源文件与 dist 都缺 → rc=1）→ 最终态 **14 例 / 950 → 964**，见 `.specs/brooks-review-fix-2026-09/TEST.md` |
| 🟡3 | 打包映射两份编码、缺失语义相反 ⇒ 必需源目录消失时门禁假绿 | `package-dsh-plugin.sh`：`COPY_DIRS`/`COPY_FILES`/`COPY_OPTIONAL` 三张表成为**唯一映射**，打包与 `--check` 同读；目录对源缺失不再 `|| continue`，改为报"源目录缺失（打包会失败）"+ dist 旧副本，与打包侧 fail-closed 同语义 | 夹具实测：基线 rc=0 · 陈旧 rc=1 指名 · 源目录移走 rc=1（原实现 rc=0）· 删源留副本 rc=1 · 只读无副作用 · 未知参数 rc=2 · 打包侧缺必需源 rc=1。**打包等价性**：重构后重建 dist 的整树哈希与重构前**逐字节相同**（`9c0b7b1e…`，525 文件） |
| 🟢1 | 同一理由写两遍（3 处） | `Makefile:113-114` 去重（`dist/ 被 .gitignore 忽略` 由 2 处→1 处）；`verify-claims.sh` §10c 重复标题行去重；`sync-hooks.sh` 判据理由合并为文件作用域一段 | `grep -c` 实测：2→1、2→1、重复叙述 1 处 |
| 🟢2 | 判据与白名单定义在 7 次迭代的循环体内 | `sync-hooks.sh`：`PTU_ENTRIES` + `is_real_entry()` **提到文件作用域**（与 `DEST_ROOTS` 同层）；新增 `--entry-class <rel>` 无副作用自检出口；`install_hooks.sh` 的交叉引用指向该单一事实源 | `--entry-class` 实测：`gate-helpers.sh`→library rc=1 · `stop/lib/common.sh`→library rc=1 · `independent-review-gate.sh`→entry rc=0 · `stop/00-gate.sh`→entry rc=0 · 缺参数 rc=2 |
| 🟢3 | `_changed` 三条 git 命令叠加、rename 取旧名 | `verify-claims.sh:198`：改为 `git diff --name-only HEAD`（已含 staged+unstaged）+ `git ls-files --others --exclude-standard`；`<base-ref>` 给定时并入 `git diff <base>..HEAD` | §10c 复刻实测：`BASE_REF=6e8468e^` → 改动集 7 项（含已提交区间），改名场景不再取旧名 |

## 全量验证（修复后）

| 门 | 命令 | 结果 |
|---|---|---|
| 1 test | `make check` → `npx bats test/` | **959 ok / 0 not ok**（新增 9 例） |
| 2 lint | 同上 | `SCANNED_FILES: 66` · 无 error |
| 3 check-validate | 同上 | ✅ staging coverage OK |
| 4 check-test-sync | 同上 | ✅ 双源一致（新 bats 已同步 `flow-kit-bundle/test/`） |
| 5 check-hooks-sync | 同上 | ✅ 7 个副本漂移 0（`--entry-class` 不动副本） |
| 6 check-dist | 同上 | ✅ dist 与源一致（test/ 变更后已重建） |
| 汇总 | `make check` | **exit 0 · 6 门全绿 · 4m3s** |
| 独立复验 | `bash verify-claims.sh` | **✅ 11 ❌ 0 ⏭ 3** · exit 0（三条工件断言显式声明"未核对"，不再假装核过） |

## 遗留与口径

1. **§10c 对本仓当前状态会报一项 FAIL**：`test_gate_freshness.bats` 不在任何 change 的 DESIGN §0.5.1（本次热修没有 change 登记）。这是判据**正确工作**的结果，不是回归 —— 若要把本次热修登记为 change，需在 `.specs/<id>/DESIGN.md §0.5.1` 列入该文件。
2. **未做**：`install_hooks.sh` 的"对所有 pre-tool-use/*.sh 一律 chmod +x"仍与 `PTU_ENTRIES` 语义不同（上轮 R6 处置 (b) 的既定决策：以注释交叉引用 + 白名单为单一事实源）。本次把该白名单提到文件作用域并提供自检出口，未改变 chmod 行为。
3. **未做**：CHANGELOG / LESSONS 登记 —— 需先定"是否登记为 change"（见上）。
