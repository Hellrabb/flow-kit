# Brooks-Lint Review

**Mode:** PR Review
**Scope:** `git diff 6e8468e^..HEAD` —— 5 个生产/工具文件（`Makefile` / `package-dsh-plugin.sh` / `sync-hooks.sh` / `verify-claims.sh` / `flow-kit-bundle/lib/install_hooks.sh`），**443 行（306+/24−，含注释）**；同区间的 33 个 `.specs/**` 文件（28 A / 5 M，含 11 个 AC 夹具）只作背景，不逐行审。`dist/**`（.gitignore 生成物）跳过。
**Health Score:** 82/100
**Trend:** First run for this mode — no trend data（`.brooks-lint-history.json` 无 `PR Review` 记录；上轮 `brooks-review` 只写入 `REVIEW.md §第五轮`，未入 history 序列，故不计入趋势线）

四个交付物今天都真跑得通、无 🔴 Critical；但**守护这两道新门禁的"守卫"本身有两处假绿** —— 工件解析会静默改核另一个 change，且新门禁没有任何行为级回归保护。

---

## Findings

### 🟡 Warning

**Coverage Illusion — §8/§9/§10c 在无活跃 change 时静默改核「另一个 change」的工件，且 PASS 文案不指名**
Symptom: `verify-claims.sh:54-63 resolve_spec_artifact()` 的解析链是「活跃 change（需 `.flow-active` + `jq`）→ **硬编码历史 id** `.specs/l3-review-defects-2026-09` → 该 id 的归档 glob」。本仓当前无 `.flow-active`，实测该函数：`resolve_spec_artifact DESIGN.md` → `.specs/archive/2026-09-18-l3-review-defects-2026-09/DESIGN.md`（rc=0），`MINOR-DEFERRED.md` 同。而本次被审 change 的工件在 `.specs/archive/2026-09-21-health-fix-2026-09/`。§8(:161)/§9(:175)/§10c(:200) 全部据该解析结果判定，PASS 文案（:168 / :180 / :213 / :215）**不含 change id、也不含解析到的路径**。
Source: Winters et al. — *Software Engineering at Google*, Ch. 11（change coverage vs line coverage）—— 断言"执行过"不等于"验的是被测对象"。
Consequence: 归档后（或 `.flow-active` 缺席、或缺 `jq`）这三条断言对**本 change 零保护**，却以 ✅ 输出；读者会以为核的是"本 change 的 §5/§2.x 编号与 §0.5.1 覆盖"。下一个 change 的 DESIGN 若漏列被改文件，也不会在这里被发现。这与本 change 的立论直接冲突：**基线写死**（`19b3463`）已由 T05 修掉，**工件 id 的历史写死仍在**，而它造成的正是同一类"拿 A 的 diff 比 B 的设计文档"。
Remedy: 把 change id 变成显式输入（`bash verify-claims.sh [<change-id>]`，默认从 `.flow-active` 读）；解析失败或解析到的 id ≠ 目标 change 时，输出 ❌ 或显式 `SKIP(期望:<id> 实得:<path>)`，不要隐式回退。至少先把解析到的路径回显进 PASS 行（如 `§5 编号（l3-review-defects-2026-09/DESIGN.md）`）；历史复算改走显式 `--recompute <id>`。

**Coverage Illusion — 新门禁零 bats 覆盖，唯一跨归档存活的守护 §10d 有 2/5 是源码文本判据**
Symptom: 本 diff 的 5 个文件全是生产/工具脚本，**无任何测试文件改动**；`test/` 与 `flow-kit-bundle/test/`（各 70 个 `.bats`）中 `grep -rl "package-dsh-plugin\|sync-hooks.sh --check\|check-dist"` = **0 命中**；本 change 的 11 个 AC 夹具在 `.specs/<id>/verify/` 内，不进 `make test`，且已随归档冻结。唯一声称"归档后继续守护"的 `§10d`（:253-273）里，②(:258 `grep -qE '^check-dist:' Makefile`) 与 ④(:265-266 `grep -qE '…is_real_entry\(\)' src`) 是对**源码文本**的 grep —— 与本行上方 :239 自述的"本节**一律**用行为断言…**不 grep 源码文本**"相反。实测该判据的性质：一个只含 `is_real_entry() { … }` 定义、**没有任何调用点**的文件，`grep -qE '^[[:space:]]*is_real_entry\(\)'` 仍 rc=0（判据通过）。⇒ 删掉 `sync-hooks.sh:213` 的 `&& is_real_entry "$rel"`（T03 修复本体）后，§10d 依旧全绿，且无 bats 兜底。
Source: Meszaros — *xUnit Test Patterns*（Behavior Verification：断言"存在"≠断言"行为"）；Feathers — *Working Effectively with Legacy Code*, Ch. 1。
Consequence: 两道新门禁最核心的行为 —— "陈旧 dist 必须红"、"库文件不得告警 / 真入口缺 exec 必须告警" —— 没有任何可复算的保护。后续 change 重构 `--check`、改 target 名、或误删判据调用点，都不会被任何门禁抓到，直至把陈旧包发给用户（正是本 change 的起因）。
Remedy: 补一组**真跑** bats（可并入既有文件）：① 夹具内把 `dist` 某文件改陈旧 → `bash package-dsh-plugin.sh --check` 必须 rc=1 且**指名**；② 删源文件、留 dist 副本 → 必须报"反向残留"；③ 造"缺 exec 位的真入口 vs 库"各一 → `bash sync-hooks.sh --check` 只对真入口告警。同时把 §10d ②/④ 换成行为断言（② 已被 ① 覆盖，可删；④ 见 🟢 Suggestion 第 2 条的单一判据源）。

**Change Propagation — 打包映射被编码两份且缺失语义相反 ⇒ 必需源目录消失时门禁假绿**
Symptom: `package-dsh-plugin.sh:46-63` 的 `pairs`/`files` 与下方第 1–5 步的 `cp`（:133-137 / :140-146 / :150-152 / :156）是同一份映射的两份编码（:45 注释自承"**单一事实源** —— 打包改了映射，这里必须同步"）。两份对"源缺失"的语义**相反**：打包侧对 `lib` / `skills` / `flow-kit` / `hooks` / `brooks-lint` 是 fail-closed（`cp -R` 无 `|| true`，:141-144 还显式 `exit 1`），检查侧却是 `:69 [ -d "$src" ] || continue` —— **静默跳过整对**（连同 :81-87 的反向残留检查一起跳过）。同文件的 `files` 分支（:92-100）恰为同一 bug 类做过修复（R2-a 原文：原实现 `[ -f "$src" ] || continue` → 整条跳过 → 删掉源文件后仍报 ✅），修复**只落到了单文件分支**。
Source: Ousterhout — *A Philosophy of Software Design*, Ch. 5（Information Leakage：同一设计决策被编码在两处）；Fowler — *Refactoring*（Duplicate Code：两份拷贝已开始分叉）。
Consequence: 重命名/移走任一必需源目录（如 `dsh-flow-kit/lib`、`flow-kit-bundle/hooks`）时，`make check` 的 `check-dist` 会输出 `✅ check-dist: dist 与源一致`、rc=0，而 dist 仍带着旧树被发给用户 —— 正是本 change 要堵的"陈旧假绿"，只换了个入口。今后每次改打包映射都要记得同步第二处，无机械守护。（本条为**静态判据**，未做破坏性实测。）
Remedy: 把拷贝映射提成单一数据结构（如 `COPY_MAP=(src:dst:required)`），打包循环与 `--check` 同读一份；最小改动是让 `pairs` 分支与打包同语义 —— 源目录缺失且 dist 存在 → 报"反向残留"；缺失且 dist 不存在 → 报"缺失"（只对确实可选的项保留静默）。

### 🟢 Suggestion

**Knowledge Duplication — 同一条理由被写了两遍（3 处）**
Symptom: `Makefile:113-114` 连续两行都在说"dist/ 被 .gitignore 忽略 → 改了源忘了重建无人发现"；`verify-claims.sh:189-190` 两行**逐字相同**的小节标题；`sync-hooks.sh:189` 起的"理由 / 原判据"块把同一件事（按目录判定 → 对只被 source 的库误报）叙述了两遍。
Source: Hunt & Thomas — *The Pragmatic Programmer*, DRY（每条知识只有一处权威表述）。
Consequence: 读者要花时间判断哪一版权威；两版会漂移（本 change 内已发生同族漂移，见 LESSONS L-093）。:189-190 的逐字重复还暴露这些"理由注释块"是靠复制粘贴搬运的。
Remedy: 每处只留一条（把被删那条里的独有信息合并进去）；小节标题只留一行。

**Cognitive Overload — 判据与其白名单被定义在 7 次迭代的循环体内**
Symptom: `sync-hooks.sh:201-211` 的 `PTU_ENTRIES` 与 `is_real_entry()` 定义在 `for root in "${DEST_ROOTS[@]}"; do`（:164）… `done`（:305）**之内**，而 `DEST_ROOTS` 有 7 项 → 定义被重建 7 次；该判据无法被外部 source/直调，只能被 grep 文本（见 🟡 第 2 条的根因）；`flow-kit-bundle/lib/install_hooks.sh:136-144` 又在注释里把同一契约抄了第三遍（":142 真入口契约的单一事实源 = PTU_ENTRIES"）。
Source: McConnell — *Code Complete*, Ch. 7（High-Quality Routines：例程应是边界清晰的独立单元）。
Consequence: 想在别处复用它（测试、打包、其它 hook 工具）只能复制或 grep 文本；"真入口"这一概念同时存在于 3 个文件，新增 pre-tool-use 入口时容易只改一处。
Remedy: 提到文件作用域（与 `DEST_ROOTS` 同层），或抽成可 source 的 `hooks/pre-tool-use/entries.sh`，由 `sync-hooks.sh` / `install_hooks.sh` / `§10d` 共用；`§10d` 随之可写成直调断言（真入口 rc=0、库 rc=1）。

**Accidental Complexity — `_changed` 三条 git 命令叠加，且 rename 行取到旧文件名**
Symptom: `verify-claims.sh:198-199` 用 `git diff --name-only HEAD` + `git diff --cached --name-only` + `git status --short | awk '{print $2}'` 求并集；但 `git diff --name-only HEAD` 本身已覆盖 staged+unstaged 的全部**已跟踪**改动（前两条与第三条的已跟踪部分重复）；而 `git status --short` 对重命名输出 `R  old -> new`，`awk '{print $2}'` 取到的是**旧名**，随后 `basename` 拿去比 §0.5.1 → 改名场景给出与事实不符的结论（假 FAIL，或漏掉新名）。
Source: Fowler — *Refactoring*（Duplicate Code）；Hunt & Thomas — *The Pragmatic Programmer*, Ch. 2（Orthogonality）。
Consequence: 断言在改名场景不可信；三条命令还掩盖了它真正的语义（"工作区相对 HEAD 的改动 + 未跟踪文件"）。
Remedy: 用 `git diff --name-only HEAD` + `git ls-files --others --exclude-standard`（或正确解析 `git status --porcelain -z` 的 rename / 空格路径），并把该语义写成一行注释。

**Recommended fix order:** 先 🟡2（补真跑 bats + §10d 行为化）→ 🟡1（change id 显式化，否则 §10c 的守护对象随时可能是别的 change）→ 🟡3（映射单一化/缺失语义对齐）→ 🟢2（判据提到文件作用域，是 🟡2 的前置）→ 🟢1/🟢3（注释去重、`_changed` 收敛）。

---

## Summary

本 change 的四个交付物今天都真跑得通（`--check` rc=0 / 0.60s、门数 awk 实测 6、扫描集 66 个 `.sh` 且 7 个此前漏扫脚本全部在列），无 🔴 Critical，相对上轮已收敛（上轮 592 行 / 4 条发现，本轮 443 行；上轮 R6 已按 (b) 加了生命周期注释）。但最该先做的是把"守护者自身"补上行为级证据：**§10c 现在核的可能是另一个 change 的 DESIGN（实测如此），而新门禁在 `make test` 里没有任何行为断言**，一旦后续 change 重构门禁，不会有任何东西报警。另一处值得注意的复发模式：**"用存在性代替行为"的假绿在本轮又出现在两处**（§10d ②④、`pairs` 的 `|| continue`），说明该修复模式尚未推广到同类分支。此外，上轮 R6 处置 (b) 的"在归档清单登记残留"未见落点（`ARCHIVE-MANIFEST.txt` 是自动生成的哈希清单，无登记位）—— 建议把该残留改登记到 `MINOR-DEFERRED.md` 或 `LESSONS.md`。

---

## 附录 · 本轮实测记录（可复算）

| 实测 | 命令 | 结果 |
|---|---|---|
| `--check` 可用性 / NFR | `time bash package-dsh-plugin.sh --check` | `✅ check-dist: dist 与源一致` · rc=0 · **real 0.600s**（≤2s 达标，与注释所记 0.61s 一致） |
| check-dist 是否真挂进 check: | `make -n check \| grep check-dist` | 命中（`📦 make check-dist: 打包件新鲜度检查`） |
| 门数动态复算 | 复刻 `verify-claims.sh:227` 的 awk | 输出 `6`（与 `Makefile:106` 的 6 个依赖一致） |
| 扫描集与 7 个补扫脚本 | 复刻 `Makefile:28` 的 `find` + `SCAN_EXCLUDES` | **66** 个 `.sh`；`install.sh` / `pre-commit.sh` / `check-gate-sync.sh` / 4×`regression-demos/*/check.sh` **全部在内** |
| 工件解析（🟡1） | `source <(sed -n 38,63p verify-claims.sh); resolve_spec_artifact DESIGN.md` | `.specs/archive/2026-09-18-l3-review-defects-2026-09/DESIGN.md`（**非**本 change） |
| §10c 改动集（🟡1 相关） | 复刻 `:198-199` | 当前 `0` 行 → 走 `:213` 的"0 项跳过"分支（提交后自动失效） |
| §10d ④ 判据性质（🟡2） | 对"有定义、无调用点"的文件跑同款 grep | rc=0（**判据通过**，与是否被调用无关） |
| 新门禁的 bats 覆盖（🟡2） | `grep -rl "package-dsh-plugin\|check-dist\|sync-hooks.sh --check" test/ flow-kit-bundle/test/` | **0 命中**（两侧各 70 个 `.bats`） |
| 配置 | `ls .brooks-lint.yaml` | 不存在 → 默认（全风险、无 ignore），故无 `Config:` 行 |
