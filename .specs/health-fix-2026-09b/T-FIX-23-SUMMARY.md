# T-FIX-23 执行回执（第 5 轮 fix loop · 2026-09-28）

> findings `R5-23` 🟡（NFR 可移植性判据盲区：`declare -A`/`mapfile`/`stat -c`/`sed -i` 等**存量**违禁构造从不进扫描面；审计 B #6 实测 `tracked .sh = 104 · 命中行 = 19 · 命中文件 = 12`）
> 开工基线 HEAD = `8bdfa6b`（工作树干净） · 产品提交 = `5bf6d2921c37743258e78cb057f347623e5acca8`
> **执行者中断披露**：子 agent（`qwen-token-plan-cn`/`glm-5.2`）写完产品件、跑完过程验证（含基线陈旧探针）后，在 `make check` 期间**未落回执即终止**（无 `T-FIX-23-SUMMARY.md`、`TASK.md` 未勾 `done`、台账未追加）。主 agent 接管收口：**逐项独立复验 `<verify>` 六条**（不复用执行者自陈）、追加 `install_brooks.sh` 失败路径 `.tmp` 清理（§F 偏离 1）、落本回执 + `TASK.md` + 台账。

## §A 先红基线（三条独立红线 · 修前实测）

| 腿 | 命令 | 修前 | 修后 |
|---|---|---|---|
| ① | `git show HEAD:sync-hooks.sh \| grep -n mapfile` + 同法查 `verify-claims.sh` | **5 处**：`sync-hooks.sh:182`/`:197`/`:198` · `verify-claims.sh:119`/`:135`（另 `34-archive-commit-check.sh:47` `stat -c %Y` · `install_brooks.sh:125` GNU `sed -i`） | **0 处** |
| ② | `NFR_RC_FILE=… FLOW_KIT_CHANGE_BASE=FULL make check-nfr-portability-internals`（**pristine worktree** `/tmp/p6d/v23base` @ `8bdfa6b`） | rc-file = **1** · **19 行 / 12 文件** | 真仓 rc = **0** + `ℹ️ 存量基线 5 条` |
| ③ | 默认（变更集 · 锚点 `.specs/health-fix-2026-09b/.change-base` = `534e3e8`） | rc = **0**（**同一构造不报 ⇒ 盲区成立**） | rc = 0 |

**19 条三分法**（与派发词一致，未改成「全量也翻红 + 只登技术债」——那等于归档后 `make check` 自红）：

| 分类 | 条数 | 处置 | 清单 |
|---|---|---|---|
| 归档面 | 7 | **判据排除**（`.specs/archive/*` 是冻结历史记录，改它无行动价值） | `2026-09-21-health-fix-2026-09/verify/ac8.sh:13`/`:28` · `2026-09-21-user-guide-sync-2026-09b/make-manifest.sh:28`/`:29` · 同目录 `verify-ac.sh:25` · `2026-09-22-privacy-path-scrub-2026-09/make-manifest.sh:28`/`:29` |
| 可修 | 7 | **本次修** | `sync-hooks.sh:182`/`:197`/`:198` · `verify-claims.sh:119`/`:135` · `34-archive-commit-check.sh:47` · `install_brooks.sh:125` |
| 登记基线 | 5 | **录入基线**（本 change 之前既有 · 修改面归 v2） | `hooks/stop/lib/common.sh:432` · `hooks/stop/lib/flow-kit-artifacts.sh:51` · `hooks/stop/lib/l3-truncate.sh:100` · 同件 `:167` · `package-flow-kit.sh:394` |

## §B 修法（六件）

1. **`mapfile` → 便携读循环**（`sync-hooks.sh:182`/`:197`/`:198` · `verify-claims.sh:119`/`:135`）：`mapfile -t X < <(…)` ⇒ `X=(); while IFS= read -r _l; do X+=("$_l"); done < <(…)`（bash 3.2 兼容 · 禁 `readarray`）；`set -u` 下的空数组迭代统一 `${X[@]:-}`（bash < 4.4 把空数组当未绑定变量）。**实测**：`./sync-hooks.sh --check` rc=0 / 漂移 0 · `verify-claims.sh` 第 1/2 节 `carriers=7` / `carriers=8`（数组被正确填充 ⇒ 非空分支成立，非 rc=127 静默失败）。
2. **`stat -c %Y` → 便携双分支（GNU 先、BSD 后）**（`34-archive-commit-check.sh:47-51`）：`stat -c %Y "$p" 2>/dev/null || stat -f %m "$p" 2>/dev/null || echo 0`。**GNU 先的理由**：GNU `stat` 的 `-f %m <file>` 把**文件系统信息打到 stdout**、错误打 stderr 且 rc=1 ⇒ 若写成 BSD 先，命令替换会把那段垃圾当结果；判据的 awk 也正用 `gsub(/stat -c … || stat -f …/)` 预剥离这一形态。原 fail-open `|| echo 0` 保留。
3. **GNU `sed -i` → `tmp` + 原子 `mv`**（`install_brooks.sh:122-134`）：同目录 rename 保证读者要么看到旧文件、要么看到新文件。
4. **归档面排除（受检面）**：FULL 枚举的两处循环（`git ls-files -z -- "*.sh"` **与** `git ls-files -oz --exclude-standard`）都加 `case "$_f" in .specs/archive/*) continue;; esac`，注释写明理由。
5. **存量基线 ratchet（仅全量模式）**：新建 `flow-kit-bundle/flow-kit/reference/nfr-portability-baseline.txt`（9 行表头注释 + **5 条** `路径:行号:标记`）。语义：命中**不在**基线 ⇒ `🔴` + rc=1；命中**在**基线 ⇒ `ℹ️ 存量基线 N 条` 不置错；基线条目在真仓**消失或行号漂移** ⇒ `⚠️ 基线陈旧` + rc=1。**基线只在 BASE=FULL 生效**——变更集模式保持「新增行命中即红」，否则「在基线件上新增 `declare -A`」会被豁免；该取舍写进判据自证行。
6. **全量入口**：新增 `check-nfr-portability-full`（进 `.PHONY` · 目标注释写明「日常 `make check` 用变更集模式；**收尾/归档必须再跑本入口**」），内部 `FLOW_KIT_CHANGE_BASE=FULL` 调用**同一** `-internals` 并沿用三态包装（`NFR_RC_FILE` 读取 · 3 ⇒ SKIP）。**未改** `make check` 的默认目标集合（不纳入 `check:`，避免变慢），**未造**第二套判据正文。

## §C 判据与常设腿

- **判据脚本**：`bash .specs/health-fix-2026-09b/reproduce-5-fixloop.sh` ⇒ **✅ 41 · 🔴 0**（修前 `44eef94` 态 = ✅ 35 · 🔴 5，红项**全部**是 T-FIX-23 五项）。T-FIX-23 段 6 条：全量入口 rc=0 · 输出含「存量基线」· 两脚本 bash4 内建清零 · 基线 5 条 · NFR 常设网 20 例。
- **常设腿**：`test/test_nfr_portability_gate.bats` **14 → 20 例**（+6，覆盖派发词要求的 ①归档外注入 ②变更集不报 ③便携写法双模式 rc=0 ④归档内注入 rc=0 ⑤命中基线 rc=0 + `存量基线` ⑥基线陈旧 rc≠0 + `基线陈旧`），20 例全绿；两镜像 `cmp -s` **SAME**。`npx bats --count test/` = **1114**（1108 → +6）。
- **基线陈旧实机探针（主 agent · 真仓）**：向基线追加伪条目 `sync-hooks.sh:999:declare -A` ⇒ `make check-nfr-portability-full` **非 0** + 报 `⚠️ 基线陈旧：sync-hooks.sh:999`；基线按 `sha256 f7bad353ed38aa39aabc3d5b58ceb7152064ed15452646a7c4981d57a8d61f82` **原样回滚**（H0 = H1 逐字节一致，`git status` 无残留）。
- **`sed` 改写的等价性（主 agent）**：同一输入分别走 GNU `sed -i` 与 `sed > tmp && mv` ⇒ `cmp -s` **IDENTICAL**；成功路径 `.tmp` 无残留；只读目标失败路径 ⇒ 清理 `.tmp` + rc=1。

## §D 门禁

| 门禁 | rc | 报文要点 |
|---|---|---|
| `make check-nfr-portability`（默认/变更集） | 0 | `✅ NFR 兼容性判据通过`（锚点来源 `.specs/health-fix-2026-09b/.change-base`） |
| `make check-nfr-portability-full`（新增入口） | 0 | `ℹ️ 存量基线 5 条（已登记：flow-kit-bundle/flow-kit/reference/nfr-portability-baseline.txt）` |
| `make test-sync` | 0 | test 双源已同步（未产生改动） |
| `./package-dsh-plugin.sh` · `bash package-flow-kit.sh` | 0 · 0 | 新件已入 `dist/dsh-flow-kit/flow-kit/reference/nfr-portability-baseline.txt`（+ vendor 副本） |
| `make check-hooks-sync` · `check-test-sync` · `check-dist` | 0 · 0 · 0 | 漂移 0 · 双源一致 · dist 与源一致 |
| `make check-path-privacy` | 0 | 候选 1620 / 扫描 1612 / 自排除 8 / 不可读 0 / 命中 0（不变式 1620 = 1612 + 8） |
| 全量 `npx bats test/` | 0 | `1..1114 ok=1114 not_ok=0 skip=0` |
| `make check`（21 步复合） | 见下（主 agent 复跑） | 日志 `/tmp/p6d/v23-make-check.log`（主 agent · docs 提交后安静树） |

## §E 台账

`goal.task_progress` len **51 → 52**；末条 `{"id":"T-FIX-23","commit_sha":"5bf6d2921c37743258e78cb057f347623e5acca8","fix_rounds":1,"deferred":[],"completed_at":"2026-09-28T12:29:44+08:00"}`（五字段齐 · 无 `.goal` 幽灵键 · 顶层 `updated_at` 仍为 epoch int）。**Δ = 52 s**（= `completed_at` − 产品提交 `%ct` `1790569732`）；超出既有 120 s 上限的部分归因「主 agent 追加 `install_brooks.sh` 失败路径加固并独立复验」，非执行者延迟——据实登记，不粉饰。

## §F 偏离登记与写面

1. **主 agent 追加（非执行者产物）**：`install_brooks.sh` 原写 `sed … > tmp && mv …` 裸命令 ⇒ `sed`/`mv` 任一失败时在 `set -e` 下**带 `.tmp` 残留中止**，与「`.tmp` 不得残留」冲突。改为 `if sed … > tmp && mv …; then … else rm -f tmp; return 1; fi`（两条失败路径都清理，失败语义不变：调用方 `set -e` 下照旧中止）。
2. **`make verify-claims` 的既有 ❌（非本次引入 · 不在 `make check` 面）**：其 §10c「§0.5.1 覆盖被改文件」核的是「工作树相对 HEAD 的改动是否列在 `DESIGN.md §0.5.1`」——fix loop 期间新增触碰文件（本任务 5 件）不回填冻结的 `DESIGN.md` ⇒ 该 ❌ 是**流程性预期**（`verify-claims` 不在 `make check:` 目标集合内，见 `Makefile:5`）；同批另有 `MINOR-DEFERRED.md` M 编号口径 ❌（第 5 轮整轮既有）。二者均**未**因本任务改变，登记备查，不改冻结设计件。
3. **写面**：`Makefile`(+99/−25) · `sync-hooks.sh`(+8/−5) · `verify-claims.sh`(+4/−2) · `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh`(+5/−1) · `flow-kit-bundle/lib/install_brooks.sh`(+11/−2) · `flow-kit-bundle/flow-kit/reference/nfr-portability-baseline.txt`(新 14 行) · `test/test_nfr_portability_gate.bats`(+105/−1) · `flow-kit-bundle/test/test_nfr_portability_gate.bats`(镜像) · `.specs/health-fix-2026-09b/T-FIX-23-SUMMARY.md` · `.specs/health-fix-2026-09b/TASK.md`(本件 status/done) · `.flow-active`(gitignored 不提交)。
