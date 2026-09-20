# 独立审查 · 阶段 6

---

## L2 盲审

- **change-id**：health-fix-2026-09
- **被审对象（我自己取的）**：`6e8468e` 的 diff（4 个生产文件 + 2 个 `.specs` 文件）+ 工作区增量（`git diff` = `Makefile` + `verify-claims.sh`）
- **待审工件**：`.specs/health-fix-2026-09/REVIEW.md`
- **参考**：`REQUIREMENT.md` / `DESIGN.md` / `TEST.md` / `TASK.md` / `.specs/CONTEXT.md`
- **独立性声明**：本报告未接受任何来自主 agent 的自评或辩护输入；全部事实性断言由我自行读取工件、跑命令、注入探针后得出。凡引用他人结论处均标注为「需确认」。

### 我实际执行过的独立复核（结论先行）

| 复核项 | 我的做法 | 结果 |
|---|---|---|
| REVIEW 称「11/11 AC 已实现且有可执行夹具」 | 逐条读实现对位 + 亲跑 `ac4/ac4b/ac4c/ac5/ac6/ac9`（6 条）+ 亲手复现 AC-1/AC-3 的注入-还原 | **属实**（详见 §A） |
| REVIEW 称「0 🔴」 | 独立扫一遍 diff，找 AC 未实现 / 安全 / 数据损坏 | **成立**（见 §B 的两条判据级 🟡：不在 🔴 定义域内） |
| REVIEW 称 shellcheck「新代码 0 告警」 | `git show HEAD:verify-claims.sh` 与现版对照逐版跑 shellcheck | **属实**（SC2015/SC2016 计数 7/2 → 7/2，未新增；`sync-hooks.sh` SC2221/2222 确为既有，行号 243 → 265 与 REVIEW 所述一致） |
| REVIEW 称 `check-dist` 只读契约 | 跑前跑后 `find dist -type f -exec md5sum {} + \| sort -k2 \| md5sum` + README mtime | **属实**（哈希一致、mtime 一致、534 文件不变） |
| REVIEW 称「第三轮跳过」 | `git show --numstat 6e8468e` + 工作区 diff 里找 UI 文件 | **成立**（无 `.css/.tsx/.vue/.html/.svelte`，无 `UI-DESIGN.md`） |
| AC-6 承重性（真入口白名单是否完整） | 独立枚举所有 `settings.json` / `hook-bridge.js` 的 pre-tool-use 调用点 | **属实**：只有 `independent-review-gate.sh` / `auto-checkpoint.sh` / `runtime-edit-guard.sh` 三个被直接 `bash` 调用（`~/.claude/settings.json:96-117`、`.claude/settings.local.json:20-38`、`dsh-flow-kit/lib/hook-bridge.js:231-233`、`flow-kit-bundle/lib/install_hooks.sh:245-254`）→ 白名单无漏 |
| AC-7 全量回归 | `bash verify-claims.sh`（内含 `make check`） | **✅ 13 / ❌ 0，rc=0，"make check 6 门全绿"**（耗时 >60s，我以后台任务跑满） |

---

## A. 逐条 AC 的独立抽验（回答「11/11 是否属实」）

| AC | 我核到的实现 | 我的实测 | 判定 |
|---|---|---|---|
| AC-1 | `package-dsh-plugin.sh:67-95`（`check_dist`） | 亲手在 `dsh-flow-kit/README.md` 末追加一行 → `--check` 输出「❌ 陈旧: …/dist/dsh-flow-kit/README.md」且 **rc=1**；`git checkout` 还原后 rc=0 | ✅ 真实现，非纸面 |
| AC-2 | 同上 | 健康态输出「✅ check-dist: dist 与源一致」；`verify-claims.sh` 内 `make check` 6 门全绿 | ✅ |
| AC-3 | `Makefile:31-58`（find 枚举 + error 判定） | 亲手向 `flow-kit-bundle/install.sh` 追加 `if [ 1 -eq 1 ]` → `make lint` **rc=2**，输出「./flow-kit-bundle/install.sh: 3 error(s)」；还原后 rc=0 | ✅ |
| AC-4 | `Makefile:31-38`（`SCANNED_FILES` 出口） | `make lint` 输出 `SCANNED_FILES: 66` + 66 条 `./` 前缀路径 + 空行；REQUIREMENT 列的 7 个「此前漏扫脚本」**7/7 全部在列** | ✅ |
| AC-4b / 4c | `Makefile:26-29` 的 9 条 `SCAN_EXCLUDES` | `ac4b.sh` / `ac4c.sh` 亲跑 PASS（排除集 9 条模式与契约逐项一致；扫描集 ∪ 契约排除集 == 全仓 `.sh` 集，缺口 0） | ✅ |
| AC-5 | `sync-hooks.sh:188-216` | `ac5.sh` 亲跑 PASS；`sync-hooks.sh --check` 输出 7 个镜像根全 ✅、rc=0；我另行枚举 7 个镜像根的非 exec 文件，确认剩下的 5 个全是「只被 source 的库」，无真入口 | ✅ |
| AC-6 | `sync-hooks.sh:201-216`（`PTU_ENTRIES` + 逐条指名） | `ac6.sh` 亲跑 PASS；白名单完整性另证（见上表） | ✅ |
| AC-7 | `verify-claims.sh` §10（门数动态推导） | 13 ✅ / 0 ❌，`make check 6 门全绿` | ✅ |
| AC-8 | 11 个夹具的 `TMPD`+`trap` | 我跑完 ac4/4b/4c/5/6/9 + 两次注入探针后：`git status --porcelain` 仅剩本 change 的预期 2 项；`dist` 文件集 534、权限指纹与基线一致 | ✅ |
| AC-9 | `Makefile:15` / `sync-hooks.sh:188` / `package-dsh-plugin.sh:22-26` | 三载体锚点均在；并复跑 `TASK.md` T06 的语义 verify（`grep -A2` 后含「理由/避免/否则」等理由关键词）→ 3/3 OK | ✅（口径附注：`ac9.sh` 只断言 AC-9 的①「含 change-id 锚点」；②「解释判据为何这样定」由 `TASK.md` T06 的 verify 覆盖，我已复跑通过 —— 即 AC-9 的合取条件两层都有判据，但 REVIEW 的「每条 AC 均有可执行夹具」未区分这一层） |

**结论**：REVIEW.md 的「11/11 AC 已实现且有可执行夹具」**经独立复核属实**，且我未发现任何 `out` 段明令排除的内容被触碰（`out` 三项：warning→fail 升级、第三方目录检查、门禁 UI —— 全部未碰）。我另按扩展后的扫描面独立复算了一次 shellcheck：66 个文件共 **132 条输出、36 条 warning 级、error 级 0**，`make lint` rc=0 —— 与 ADR-010「扩面不升级红绿语义」的声明一致。顺带核了 ADR-010 的三项举证，**全部属实**：`install.sh` SC2034×2（`:130,133`）、`check-gate-sync.sh` SC2034×2（`:21,22`）、`regression-demo` SC1090×1。

---

## B. 我发现的问题（四要素 + 严重度）

### 🟡 R2-a · `check_dist` 的顶层单文件映射**没有反向残留判据**：源文件被删后，dist 里的陈旧副本永远查不出来
**Severity**：🟡 Important
**Symptom（症状）**：`package-dsh-plugin.sh:87-95` 的 `files` 循环只有正向比对，且 `:89` 是 `[ -f "$src" ] || continue` —— **源不存在就整条跳过**。而同一函数的 `pairs` 循环（`:79-84`）明确做了反向残留检测。实测（我亲手做）：`rm dsh-flow-kit/DESIGN.md` 后，`dist/dsh-flow-kit/DESIGN.md` 仍存在（旧内容），而 `bash package-dsh-plugin.sh --check` 输出 **「✅ check-dist: dist 与源一致」rc=0**。
**Source（源头）**：本 change 自身的判据要求 —— `REQUIREMENT.md:33-36` AC-1 的 Given/When 定义在「进入 dist 的源文件」上；`DESIGN.md:73` 明确「dist ↔ 源映射表沿用已有 `cp` 映射」；`DESIGN.md:196` R2 把「永久假红」列为必须避免的上线风险，但未对称地处理「永久假绿」。书籍依据：Fowler · *Refactoring* · Divergent Change（同一契约两套判据）与 *Pragmatic Programmer* · 「不要让错误沉默」。
**Consequence（后果）**：这正是本 change 存在的理由的那一类事故形态 —— 2026-09-20 的 README「字节/字符」事故本质就是 dist 里躺着一份落后于源的文档。删源（改名/迁移文档）比改源更不易被察觉：`git` 对 `dist/` 结构性失明（`.gitignore:63`），门禁又亲口说「一致」，于是**旧文档随插件分发给用户**。当前 6 个顶层单文件（`package.json` / `cordis.patch.yml` / `README.md` / `DESIGN.md` / 两份 docs / ecosystem-guide）全部落在盲区里。
**Remedy（修补）**：在 `files` 循环后追加对称的反向检查（约 6 行，与 `:79-84` 同款）：
```bash
for rel in "${files[@]}"; do
  dst="${rel##*:}"; src="${rel%%:*}"
  if [ -f "$dst" ] && [ ! -f "$src" ]; then
    echo "❌ 反向残留: $dst（源已无 $src）" >&2; fail=1
  fi
done
```
同时把 `:89` 的 `|| continue` 改为「源缺失且 dist 无对应文件才跳过」，避免「源删 → 静默放行」。改完请补一条夹具（现 11 条夹具无一条覆盖该路径 —— 我 grep 过 `verify/*.sh`，无「反向残留」的顶层单文件用例）。

---

### 🟡 R2-b · 源侧存在 `.DS_Store` 时是**永久假红**，且失败信息给出的修复动作修不好它
**Severity**：🟡 Important
**Symptom（症状）**：正向遍历 `package-dsh-plugin.sh:77` 是 `find "$src" -type f -print0`，**没有** `.DS_Store` 过滤；而反向遍历 `:84` 却有 `-not -name '.DS_Store'`。打包第 5 步（`:151`）会 `find "$PKG_DIR" -name '.DS_Store' -delete`。实测（我亲手做）：`touch flow-kit-bundle/hooks/.DS_Store` 后 `--check` 报
```
❌ 缺失: …/dist/dsh-flow-kit/hooks/.DS_Store（源: …/flow-kit-bundle/hooks/.DS_Store）
❌ 缺失: …/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/.DS_Store（源: …（同一文件））
→ 修复: bash package-dsh-plugin.sh
```
rc=1；删掉该文件后恢复 rc=0。注意 `.DS_Store` 在 `.gitignore:19` 被忽略 → `git status` 看不见它；而**「重建 dist」这个提示永远修不好它**（重建的下一步就把它删掉）。
**Source（源头）**：`DESIGN.md:196` R2 原文 —— 「比对权限位则永远不等 → 制造永久假红」是本 change 显式要避免的形态；`package-dsh-plugin.sh:65-66` 的注释也自述「比 mode 会制造永久假红」。同一推理未应用到 `.DS_Store`。`TEST.md` 第 4 轮自述追求跨环境兼容（「GNU 专属选项 0 处」），而 `.DS_Store` 恰是 macOS 贡献者的常规产物。
**Consequence（后果）**：macOS 上浏览过目录的贡献者会看到 `make check` 永久红；提示语又指向一个无效动作 → 门禁被训练成噪声（这正是本 change 在 F3 里花大力气消除的失败模式），或被 `git clean` 之外的手段粗暴绕过。**判定口径提示**：若采用「AC-2 必须在任何合法工作区放行」的口径，本条可上调 🔴（AC-2 未满足）；我按本仓声明的环境口径（Linux + GNU coreutils）判 🟡，证据留在上，供人工裁定。
**Remedy（修补）**：`find "$src" -type f -not -name '.DS_Store' -print0`（两处 `find "$src"` 都改），让正反两向口径一致；或让打包器不删 `.DS_Store` 并显式注释「dist 与源逐字节同构」。前者一行改完。改完请补夹具：`touch flow-kit-bundle/hooks/.DS_Store && bash package-dsh-plugin.sh --check` 期望 rc=0。

---

### 🟡 R2-c · 三条新门禁**没有任何 bats 用例**，唯一覆盖是 `.specs/<id>/verify/*.sh`（不进 `make check`，随归档迁移）
**Severity**：🟡 Important
**Symptom（症状）**：`grep -rn "check-dist\|check_dist\|SCANNED_FILES\|is_real_entry\|package-dsh-plugin" test/ flow-kit-bundle/test/` → **0 命中**。新增判据的全部证明力只在 `.specs/health-fix-2026-09/verify/ac*.sh`（11 条），而它们：① 不被 `make test` / `make check` / `.git/hooks/pre-push` 调用；② 位于 `.specs/`（本仓归档惯例实测存在：`.specs/archive/2026-09-18-l3-review-defects-2026-09/` 等 9 个已归档 change）。副证：`verify-claims.sh` §10 的门数是从 `Makefile` 的 `check:` 依赖**动态数**出来的 —— 因此把 `check-dist` 从 `check:` 里删掉，`make check` 与 `verify-claims` 都**不会红**。
**Source（源头）**：`REQUIREMENT.md:385-390` AC-8 的「实现要求」把夹具落点定在 `.specs/<id>/verify/`（合规），但 `REQUIREMENT.md:281` AC-7 的语义是「无行为回归」，只保证当下不改坏既有门禁，**不保证新增门禁此后不被改坏**；`DESIGN.md:197-198` 的 R3/R4 只登记了「清单漂移」，未登记「判据本身可被无声移除」。本 change 的立论是「修的是检查器看见真相的能力」，则检查器自身的回归保护缺失属同族问题。
**Consequence（后果）**：本 change 归档后（`.specs/health-fix-2026-09/` → archive），三条新判据在未来任何一次 `Makefile`/`sync-hooks.sh`/`package-dsh-plugin.sh` 编辑中退化（例如把 `check_dist` 的 `cmp` 换成 `[ -f ]`、把 `PTU_ENTRIES` 清空、把 `check-dist` 从 `check:` 摘掉）都不会让任何门禁变红 —— 盲区会被重新打开，且**没有任何自动化信号**。
**Remedy（修补）**：把 3 条最小夹具搬进 bats（约 40 行）：`test/test_gate_blind_spots.bats`（① 改源不重建 → `bash package-dsh-plugin.sh --check` rc≠0 且指名；② 健康态 rc=0；③ `make lint` 输出含 `SCANNED_FILES: <n>` 且 n == 其后路径行数）。注意本仓 `check-test-sync` 要求 `test/` ↔ `flow-kit-bundle/test/` 一致 → 用 `make test-sync` 同步副本。若坚持不搬（尊重 AC-8 的落点约定），则**至少**在 `verify-claims.sh` 里补两条断言：`grep -q '^check:.*check-dist' Makefile` 与 `grep -q 'PTU_ENTRIES=' sync-hooks.sh`，让它随 `make verify-claims` 长期存活。

---

### 🟡 R1-a · REVIEW.md 自称「未装 brooks-lint」与实测不符 —— 6 维诊断实际走了低质量回退路径，且该自查项被假勾选
**Severity**：🟡 Important　（**主 agent 误判**）
**Symptom（症状）**：`REVIEW.md:205`：「未装 brooks-lint → 走内置回退路径并**已注明质量差异**（书本引用发现率 100% vs ~16%）」被勾选为 `[x]`。我的实测反证：
- `~/.claude/tools/brooks-lint/` 存在且完整（`bin/{depcheck,jscpd,knip,ts-prune}`、`node_modules/` 148 项、`manifest.json`：`platform: linux-x64, node_min 18.0.0`）；
- PATH 上已有 shim：`~/.local/bin/{depcheck,jscpd,knip,ts-prune}`；
- 斜杠命令/技能载体存在：`~/.claude/plugins/marketplaces/brooks-lint-marketplace/skills/brooks-review`（另有 `~/.claude/commands/.brooks-lint-v1.3.0`、`~/.claude/plugins/data/brooks-lint-brooks-lint-marketplace`）；
- 本仓根有 `.brooks-lint-history.json`，含 **7 次**历史运行（2026-06-16 起到 2026-07-10，score 33–97）→ 该工具在本机**跑得通**；
- 本会话的技能目录里同时列有 `brooks-review` / `brooks-audit` / `brooks-debt` / `brooks-health` / `brooks-test`。
**Source（源头）**：`flow-kit-bundle/skills/flow-review/SKILL.md` 的 2.1「路径 A · 装了 brooks-lint（**首选**）」+ 自检项「装了 brooks-lint 优先用（`/brooks-review` + `/brooks-audit`），输出原样贴入报告」；`REQUIREMENT.md` 之外，`REVIEW.md:180` 还拿「带书本引用发现率 100% vs ~16%」的数字来为回退路径标注质量差 —— 即作者知道代价仍选了代价，并给了不实的理由。
**Consequence（后果）**：① REVIEW.md 存在**可证伪的假陈述**（本仓 `verify-claims.sh` 的整个由来就是打击「声明与工件不符」）；② 6 维诊断的证明力按作者自引 benchmark 从 100% 降到约 16%，实际后果可见：`REVIEW.md:56-66` 输出 `R3/R4/R5 = 0/0/0` 且没有对 R3/R4/R5 做任何分析，而同一 diff 里 R3 有现成实例（见 🟢 R3-a / 🟢 R3-b）；③ 恰好漏掉本报告 B 段的两条判据级 🟡（漏判率 2/3，与低质量路径一致）。
**Remedy（修补）**：① 把 `REVIEW.md:205` 改为事实陈述：「brooks-lint 已安装（`~/.claude/tools/brooks-lint`，7 次历史运行），本 harness 下未调用 `/brooks-review` 技能 → 走内置回退，质量差异见 SKILL.md benchmark」；② 若坚持保留回退结论，请在 2.2 段显式说明**为什么不能调用**（例如斜杠命令不可用），而不是「未装」；③ 建议在进 7-integration 前补跑一次 `brooks-review`（技能可直接加载），把输出原样贴入 2.2 —— 这是 §2.2「路径 A」的字面要求。**需确认**：该技能是否在本 harness 下可执行，需人工验证一次。

---

### 🟡 R1-b · REVIEW.md 的「审查对象」与真实工作区增量不符 —— `verify-claims.sh` 的语义变更**两轮都没被审**
**Severity**：🟡 Important　（**主 agent 漏判**）
**Symptom（症状）**：
- `REVIEW.md:4`：「审查对象: `6e8468e`（T01–T06 实现）+ 工作区增量（**TEST.md 的诚实性修复**）」。
- 实测 `git diff --numstat`：`Makefile 4/1` + `verify-claims.sh 13/2` —— 工作区增量是**两个生产文件**（20 changed lines，与 `REVIEW.md:5` 的「+20（工作区）」数字吻合），**TEST.md 根本不在 `git diff` 里**（它在未跟踪的 `.specs/` 下，不可能以 diff 形态出现）。
- 更要紧的是：`verify-claims.sh:199-218` 的增量是一次**语义变更**（`§10c` 的「空集恒真假绿」修复：新增 `_n_changed` 计数器 + 三态分支），`REVIEW.md` 全文（第一轮 AC 对照、第二轮 6 维、2.4 shellcheck）**对这两个文件零分析** —— `verify-claims.sh` 只在依赖图（`:135`）与 shellcheck 表（`:149`）里被提到名字。
**Source（源头）**：`flow-review/SKILL.md` 的输入清单明列「本次变更的 git diff」；自检项「报告里没有自己悄悄改过的代码」与 R3.3「只产报告 + 修复任务，不改代码」。REVIEW 声明审了 X（TEST.md）却实际存在 Y（两个生产文件）的增量，属**声明与工件不符**（本仓 L-093/L-097 同族）。
**Consequence（后果）**：一个会改变门禁输出语义的改动未经任何审查即随本 change 进入 7-integration；且 `verify-claims.sh` 是「复验其他所有声明」的元工具 —— 元工具被静默修改而无人复核，是本仓历史上最敏感的一类变更（`REQUIREMENT.md:326-340` 自己记载过：`l3-review-defects-2026-09` 归档后，该脚本三处硬编码路径落空 → 「§10c 对任何新 change 结构上永不可能通过」）。
**Remedy（修补）**：① 更正 `REVIEW.md:4` 为真实清单（`Makefile` + `verify-claims.sh`）；② 对这两处增量补一轮（哪怕一句话）判定：`Makefile:111-121` 的注释订正（13ms → 0.61s，诚实性修复，✅）、`verify-claims.sh:199-218` 的空集语义修复（我复核：`_n_changed` 计数正确、三态分支正确；**但语义只是把假绿换成"明示跳过"，空集时该检查仍无证明力** —— 这一点 `TEST.md:215-220` 已诚实登记，REVIEW 应把它登记为「已知边界」而非不提）；③ 若今后工作区增量含生产文件，应把 `+N（工作区）` 一并纳入 AC/none 判定与 shellcheck 表。

---

### 🟢 R3-a · `Makefile` 的 `check-dist` 注释块把同一理由**连写两遍**（R3 计数应为 ≥1 而非 0）
**Severity**：🟢 Minor
**Symptom（症状）**：`Makefile:112-114`：
```
112 # **理由**：dist/ 被 .gitignore 忽略 → git 对它失明；否则改了源忘了重建无人发现
113 # 为什么存在：dist/ 被 .gitignore 忽略 → **git 对它结构性失明**，改了源忘了重建
114 #   不会被任何既有门禁发现。2026-09-20 即因此发出一份…
```
第 112 行是第 113-114 行的截短重写（同一次改动里两份草稿叠加）。
**Source（源头）**：Fowler · *Refactoring* · Duplicated Code / *Pragmatic Programmer*「DRY 是知识层面的」；`flow-review/SKILL.md` 的 R3 定义（同一决策被表达在多处）。REVIEW.md `:62` 报 R3 = 0/0/0。
**Consequence（后果）**：几乎无功能影响（注释），但它使「R3 = 0」的结论不成立，并给后来者两份措辞略异的理由（读者会怀疑哪份是权威）；同类叠加若发生在实现行而非注释行，就是真 bug。
**Remedy（修补）**：删 `Makefile:112`，保留 113-114（信息更全）。顺手扫一遍 `check-dist` 段落（`:111-121`）与 `package-dsh-plugin.sh:22-26` 是否有同款叠加。

---

### 🟢 R1/R6 · 6 维归属错位 + R1 的关键数据不实：`check_dist` 是 **68 行**（不是 64），整行注释 **5 行**（不是「约 20 行 / 1/3」）
**Severity**：🟢 Minor　（**主 agent 误判**）
**Symptom（症状）**：
- `REVIEW.md:97`：「`check_dist()` 单函数 64 行（含注释）」；实测 `awk` 定位 `check_dist() {` 在 `:38`、闭合 `}` 在 `:105` → **68 行**；其中整行注释 5 行（`:45,54,65,66,78`），注释+代码混排 6 行，占比约 16%。
- `REVIEW.md:105` 的「接受现状」理由①写作「64 行中约 1/3 是解释…的关键注释，删注释换拆分会损失可追溯性」—— 该理由把选择伪装成「删注释 vs 拆分」的假二分，且建立在被夸大约 2 倍的注释量上。
- 同一 `REVIEW.md:113` 把「局部子程序定义在循环内」记为 **R6 领域扭曲**，并自述「此处更贴近 McConnell · Code Complete · Ch.7 —— 实事求是标为 🟢 而非硬套」。自认不匹配却仍记入 R6，使 R6=1、R4=0 的统计失真（该问题实为 R1/R4 范畴）。
**Source（源头）**：`flow-review/SKILL.md` 的 6 维定义表（R6 = 「代码是否忠实反映业务领域」，与函数定义位置无关）与自检项「二轮 · 6 维诊断输出含 4 要素 + 书本引用 + R1~R6 编号」；`REQUIREMENT.md` 之外，`REVIEW.md:6` 自述遵守 R3.3「只产报告」，则报告内数据应可复算（本仓 `verify-claims.sh` 的立论：计数现场复算，不抄快照）。
**Consequence（后果）**：结论不变（68 < 80，4.2 的「单函数 > 80 行」触发判定仍不命中），但「R1 暂不改」的理由强度被我下调为**弱接受**（见 §C），且 R4（偶然复杂）维度实际未被评估过。
**Remedy（修补）**：把 `:97` 改为「68 行（整行注释 5 行，占 16%）」；把该条从 R6 移入 R1（或 R4），R6 归 0；并在 `:105` 用真实理由陈述「新代码、有夹具、注释密度正常；拆分收益 < review 噪声成本」。

---

### 🟢 R5 · diff 规模口径不实：`+274（提交）` 含 2 个 `.specs` 文件，且把删除行也算作「+」
**Severity**：🟢 Minor　（**主 agent 误判**）
**Symptom（症状）**：`REVIEW.md:5`：「4 个生产文件 · **+274**（提交）」。实测 `git show 6e8468e --numstat`：Makefile 38/5、package-dsh-plugin.sh 95/1、sync-hooks.sh 33/11、verify-claims.sh 60/5 → **生产文件 = +226 / −22 = 248 changed lines**；另加 `.specs/CONTEXT.md` 6/0 与 `.specs/LESSONS.md` 20/0，六文件合计 252 增 + 22 删 = **274**。即 274 是「六文件改动行数总和」，与「4 个生产文件」这个限定词不符，且「+274」的记号把 22 行删除也归入加号。
**Source（源头）**：`flow-review/SKILL.md` 自检「不允许笼统结论…每条结论必须有具体行号或文件引用」；本仓对「计数口径必须现场复算」的既定纪律（`LESSONS.md` L-092「同名多份文件禁止用 basename 去重计数」同族）。
**Consequence（后果）**：低。但规模数字是人工复核 diff 覆盖面的入口 —— 把 `.specs` 文档算进「生产文件」，会让读者误判改动面（并掩盖「两个 `.specs` 文件不在任何 task 的 `write_files` 内」这一事实，见下条）。
**Remedy（修补）**：`REVIEW.md:5` 改为「4 个生产文件 **+226/−22**（六文件合计 274 改动行，含 `.specs/CONTEXT.md`、`.specs/LESSONS.md`）；工作区增量 2 个生产文件 +17/−3」。

---

### 🟢 R4 · 第四轮两项「未命中」的**结论成立**，但两处理由不实；范围蔓延检查未核 `write_files` 边界
**Severity**：🟢 Minor　（**主 agent 误判 + 漏判**）
**Symptom（症状）**：
- `REVIEW.md:167`：「`.specs/CONTEXT.md` 的**「技术债」段**今日（2026-09-20）刚更新（TD-025 登记）」。实测 `.specs/CONTEXT.md` 的二级标题只有：源文档 / 项目概要 / 技术栈 / 域语言 / 已锁决策 / 默认偏好 / 既有抽象索引 / 项目结构 / intel-scan 元数据 —— **不存在「技术债」段**；TD-025 在 `:531`，属「既有抽象索引」表。技能给的触发条件是「`.specs/CONTEXT.md` 的『技术债』段多于 30 天未更新」，该条件在此文件上**无法成立/无法核验**。
- `REVIEW.md:180`：以「阶段 1/3/5 的 L3（deepseek-v4-flash）×5 轮 + 三轮熔断 bypass」论证「等价于一次持续的多模型交叉审查，故不再重复」。跨阶段对**别的 diff** 的审查，不构成对**本 diff** 的 spot-check；该论证无论成立与否都与 4.2 的四个触发条件无关。
- `REVIEW.md:30-36` 的范围蔓延表三项（`out` 内容 / REQUIREMENT 外功能 / DESIGN 外架构）**都没有核 R7.3 的 `write_files` 边界**：实测 `grep -n "CONTEXT.md\|LESSONS.md" TASK.md` → **0 命中**，即提交里的 `.specs/CONTEXT.md`、`.specs/LESSONS.md` 不在任何 task 的 `write_files` 中（提交信息写的「0 越界（**4 个生产文件**均在对应 task write_files 内）」字面成立，但审查表未指出这两个文档文件的边界问题）。
**Source（源头）**：`flow-kit-bundle/flow-kit/prompts/6-review.md` 的门禁表（`跨模型分歧（spot-check）` 默认 `warn`；`gate_config["6-review"]="both"` → L2+L3 双层），`flow-review/SKILL.md` 的 4.1/4.2 触发条件原文，以及 `TASK.md` 末尾「`read_files` / `write_files` 是 R7.3 强约束」。
**Consequence（后果）**：判定结论不受影响 —— 4.1 即便触发，也因未调用 `brooks-debt`（`REVIEW.md:175`「未装 brooks-lint → 跳过本段」，同 🟡 R1-a 的不实前提）而无法产出；4.2 的四个触发条件我独立核过（无安全/认证、无并发、最大函数 68 行 < 80、bats 950→950 无覆盖率下降）**确实全部未命中**，故跳过合规，且阶段 6 的 L3 由本文件所在的独立审查链承担（`gate_config["6-review"]="both"`），不存在漏做 L3 的问题。真正的代价是：REVIEW.md 里两条可证伪的理由会污染后续判断（尤其「未装 brooks-lint」被复用了两次）。
**Remedy（修补）**：① `:167` 改为「CONTEXT.md 无『技术债』段（债务登记在 LESSONS.md / TECH-DEBT.md），本次未跑债务评估」；② `:180` 删去「等价于跨模型审查」的推论，只保留「四项触发条件均未命中」；③ 范围蔓延表增一行「R7.3 write_files 边界：`.specs/CONTEXT.md` / `.specs/LESSONS.md` 未在任何 task 声明（DESIGN §9 沉淀允许，属文档边界，非代码越界）」。

---

### 🟢 R3-b · 新增/变更的注释里带着**未现场复算的陈旧计数**（SC1090 实为 22 处，不是 21）
**Severity**：🟢 Minor
**Symptom（症状）**：`Makefile:20-21`（本 diff 新增）写「理由：warning 池含 **21 处** SC1090（shellcheck 无法跟踪动态 source）等 known-acceptable」；而同一 diff 的 F2 把扫描面从手写 glob 扩到 66 个生产脚本。我按扩展后的扫描面独立复算（`shellcheck -e SC1091 -f gcc` × 66 文件）：**SC1090 = 22 处**、warning 级 36 条、error 级 0。即新注释引用的是扩面**前**的快照（TD-023 · 2026-09-01 的 21 处），扩面恰好新增了第 22 处：`flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/check.sh:26`。`REQUIREMENT.md` 的 `out` 段与 ADR-010 同样写「21 处」。
**Source（源头）**：`LESSONS.md` L-092 / L-093（「跨动作的计数一律现场复算，不得转抄早期输出」）；`verify-claims.sh` 头部自述的立论「计数现场复算，不抄快照」；ADR-010 自己把「21 处 SC1090」当作「不升级为 fail」的论据。
**Consequence（后果）**：不影响红绿（warning 不拦），但 ADR / 需求 / 实现三处**共同引用一个已失效的数字**作论据；下一位读者照 21 去核对时会先怀疑工具、后怀疑注释 —— 与本 change 要治的「计数与事实不符」同族。
**Remedy（修补）**：把 `Makefile:20-21` 与 `REQUIREMENT.md` 的 `out` 段改为「22 处（2026-09-20 复算；扩面前为 21 处）」，或在注释里只写「多处 SC1090」并把复算命令写进 ADR-010。

---

### 🟢 R2-d（流程） · 决定要修的 🟡 未按 SKILL.md 追加 `T-FIX-XX` 任务
**Severity**：🟢 Minor
**Symptom（症状）**：`REVIEW.md:195` 明确「采用 **Remedy (a)**」（= 决定要修的 Major），但 `TASK.md` 中 `grep -n "T-FIX"` 只命中 `:416` 的占位说明（「此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`」）——**无任何 T-FIX 条目**；工作区亦确无 `install_hooks.sh` 改动（`git status` 只有 `Makefile` 与 `verify-claims.sh`）。
**Source（源头）**：`flow-kit-bundle/skills/flow-review/SKILL.md`「产出修复任务」段：「对所有 Critical 和**决定要修的 Major**，**追加到 `TASK.md` 末尾**，编号延续（如 `T-FIX-01`），并触发回到 `4-dev`」。
**Consequence（后果）**：低 —— REVIEW 已把该偏离显式写出并标注「此偏离需人工确认」（`REVIEW.md:195`），属**透明偏离**而非隐瞒；但流程上这条 🟡 目前两头不靠：既未进 `TASK.md` 的 fix 队列，也未在代码里落地，只有一句「建议并入阶段 7」。
**Remedy（修补）**：二选一 —— ① 追加 `T-FIX-01`（`install_hooks.sh:140` 的 cross-ref 注释）并在阶段 7 提交里带上，同时在 `REVIEW.md:195` 记下实际处置；② 若人工确认接受现状，按 R2.5 的写法显式登记为「已知接受（人工确认 + 日期）」，不要停在「建议」。

---

## C. 对 REVIEW 的 🟡/🟢「接受现状」理由的独立评级（是否敷衍）

| 条目 | REVIEW 的理由 | 我的评级 | 依据 |
|---|---|---|---|
| 🟡 R2（`PTU_ENTRIES` vs `install_hooks.sh:140` 双定义） | 采纳 Remedy (a)：加交叉引用注释；论证「installer 对子库 chmod +x 属无害冗余」 | **站得住**（我独立验过：`install_hooks.sh:139-141` 对 `pre-tool-use/*.sh` 全量 `chmod +x`；4 个库确无直接调用点；3 个真入口另有 `settings.json`/`hook-bridge.js` 的 `bash` 调用），但**处置未落地**：`REVIEW.md:195` 自己承认该 fix「需人工确认」并建议并入阶段 7 —— 我核查工作区，`install_hooks.sh` **无任何改动**，即这条 🟡 到阶段 6 结束时**仍未修**。**另注**：REVIEW 只报了 `install_hooks.sh` 这一处「第二定义」，漏了 `DESIGN.md:74` D6 明文声明的单一事实源是 `common.sh::HOOK_MODULE_NAMES` + 白名单，而实现在 `sync-hooks.sh:203` 用 `stop/*.sh` **通配**代替 `HOOK_MODULE_NAMES`（我核过：`STOP_EXTRAS` 为空，两者当前集合等价，故无功能缺口；但声明与实现不同源，属同类「两处定义」） |
| 🟢 R1（`check_dist` 不拆） | ① 64 行中 1/3 是注释，拆分损失可追溯性；② 六步共享 `fail` 变量 | **弱接受**（数据不实、假二分），但**结论可接受** | 见 🟢 R1/R6：68 行、整行注释 5 行；真实理由（新代码 + 有夹具 + 无复用需求）未被写出来 |
| 🟢 R6（`is_real_entry` 留在循环内） | 移到循环外会降低局部性；bash 重定义无副作用 | **站得住**（低风险，且作者已自认维度不匹配） | 我核过：函数体不依赖循环变量，两种位置功能等价；7 个镜像根重复定义确为纳秒级 |

**结论**：两条 🟢 的「接受现状」**不是敷衍**（都给了可检验的理由），但 🟢 R1 的理由含不实数据；🟡 R2 的理由成立却**未落地为代码**，而 `REVIEW.md:195` 把该 🟡 的落地推给阶段 7 并自标「需人工确认」—— 这是**流程上的未闭合项**，人工确认前不应视为已处置。

---

## D. 对「0 🔴」的独立复核结论

我按「AC 未实现 / 安全漏洞 / 数据损坏」三条定义独立扫了一遍 diff（含 `check_dist` 的路径拼接与 `find`/`cmp` 调用、`SCAN_EXCLUDES` 的正则面、`is_real_entry` 的 glob 跨 `/` 陷阱、`verify-claims.sh` 的 `git status --short | awk` 解析、`Makefile` recipe 的 `mktemp`/`rm` 生命周期）：

- **AC 未实现**：无。11/11 均被我实跑或亲手复现（§A）；`check_dist` 的路径映射与打包第 1-5 步**逐条对应**（我对着 `package-dsh-plugin.sh:122-145` 的 `cp` 清单核对过 6 组 `pairs` + 7 个 `files`，无缺项、无多写），「单一事实源」的声明属实。
- **安全漏洞**：无。`--check` 路径零写操作（我以 dist 全量 md5 指纹实测前后一致）；`usage_check` 用引号 heredoc；未知**首参** fail-closed（实测 `--bogus` → rc=2 + usage，且不重建）。附注一条极轻的口径瑕疵：`case "${1:-}"` 只看第一个参数，`--check --typo` 会静默接受第二个参数（不影响 `--check` 的只读性）—— 记为观察，不单列条目。
- **数据损坏**：无。三处新代码在只读路径上；`make lint` 的 `mktemp` 临时文件在两条分支都 `rm -f`。

**因此我不把 B 段的 🟡 R2-a / R2-b 上调为 🔴**（它们是「新门禁的判据缺口」，不是 AC 未实现、也不是数据损坏），我也**不把 🟡 R1-a 的假陈述上调为 🔴**（它是审查工件的过程缺陷，不改产品行为）—— 但请人工注意：若项目把「REVIEW 自检项必须与事实一致」当作阶段门禁的硬条件（这正是本仓 `verify-claims.sh` 的存在理由），则 🟡 R1-a 应按 🔴 对待。

---

## E. 总结

| 项 | 我的独立结论 |
|---|---|
| 11/11 AC 已实现 | **属实**（6 条夹具亲跑 PASS + AC-1/AC-3 注入探针亲手复现 + `make check` 6 门 + `verify-claims` 13/0） |
| 0 🔴 是否成立 | **成立**（无 AC 未实现 / 无安全漏洞 / 无数据损坏） |
| 范围蔓延 | **无**（未碰 `out` 三项、未新增功能、`hooks/**` 运行时逻辑零改动 —— 我核过 `git show --numstat`：改动全在 4 个门禁脚本 + 2 个 `.specs` 文档） |
| shellcheck 结论 | **属实**（逐版本对照：新代码 0 新增；`sync-hooks.sh` 2 条 SC2221/2222 确为既有、行号从 243 移至 265）。**口径附注**：`shellcheck verify-claims.sh` 实际返回 rc=1 并输出 10 条（7×SC2015 info、2×SC2016 info、1×SC2126 style），均为既有且低于 warning 级 —— REVIEW 表头写的是「warning+」，故结论不算错，但建议补一列实际输出条数，免得读者以为该文件「全清」 |
| 第三轮跳过 | **成立**（diff 无 UI 文件、无 `UI-DESIGN.md`） |
| 第四轮未命中 | **4.2 四项触发条件确实全未命中（我独立核过）**；4.1 的理由不实（CONTEXT.md 无「技术债」段）但结论不变（未跑债务工具） |
| 对主 agent 的复核 | **误判 4 处**（🟡 R1-a「未装 brooks-lint」；🟢 R1/R6 的「64 行 / 1/3 注释」与 R6 归属；🟢 R5 的「+274」口径；🟢 R4 的「技术债段刚更新」）；**漏判 4 处**（🟡 R2-a 顶层单文件假绿；🟡 R2-b `.DS_Store` 永久假红；🟡 R2-c 新门禁零 bats 回归保护 + 工作区增量未审；🟢 R3-b 注释里的陈旧计数 21→22）；**流程未闭合 1 处**（决定要修的 🟡 既未落码、也未生成 `T-FIX`，REVIEW 自标「需人工确认」） |
| 修代码优先 | REVIEW 对唯一 🟡 给出了具体行动（注释级 cross-ref），但**未落地**（`install_hooks.sh` 工作区无改动），且自标「需人工确认」→ 属未闭合项，人工确认前不应视为已处置；对本报告 B 段 5 条 🟡，建议在 7-integration 提交前至少修掉 R2-a / R2-b（各 ≤10 行）与 R2-c 的两条 `verify-claims` 断言 |

**Verdict**: pass

---

## 主 agent 响应 · 阶段 6（对 L2 盲审 · 2026-09-21）

> 主 agent 手写段。L2 的 0 🔴 + 5 🟡 + 6 🟢 逐条复验：**全部成立**，已逐条处置。
> **其中 3 条是对我自身报告可信度的直接质疑，全部属实。**

### 对 🟡 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **R2-a** · `check_dist` 顶层单文件映射**缺反向残留判据**（`:89` 的 `[ -f "$src" ] \|\| continue` 把"源已删"整条跳过）→ 删源后 dist 留旧副本而门禁报"✅ 一致" | `Fixed in:` `package-dsh-plugin.sh` | **复验成立，我判它必须修**（虽被标 🟡）：它**直接违反 AC-1 的承诺**——"改任一进入 dist 的源文件 → 必须变红并指名"，而**删除也是改动**。实测 `rm dsh-flow-kit/DESIGN.md` → 修前 rc=0「✅ 一致」（假绿，旧文档随插件发给用户）；**修后 rc=1「❌ 反向残留: …/DESIGN.md（源已无 …）」并指名**。讽刺的是我在**目录**映射里做了反向残留检测，却在**顶层文件**映射里漏了。 |
| **R2-b** · 源侧 `.DS_Store` 触发**永久假红**（正向 find 未过滤 / 反向已过滤 / 打包又删除它 → 提示的"重建 dist"永远修不好） | `Fixed in:` `package-dsh-plugin.sh` | **复验成立**：实测源里放 `.DS_Store` → 报"缺失"，但因为打包第 5 步会删它，重建也修不好 → **永久假红**。已给正向 find 加 `-not -name '.DS_Store'`（与反向 find 对齐）。修后实测 rc=0 ✅。 |
| **R2-c** · 三条新门禁**零 bats 覆盖**；且 `verify-claims` 的门数是"动态跟随"→ **摘掉 check-dist 也不会红** | `Fixed in:` `verify-claims.sh` **新增 §10d** | **两条断言均复验成立**：① `grep -rl 'check-dist\|SCANNED_FILES\|is_real_entry' test/` = 0；② 实测从 `check:` 摘掉 `check-dist` 后 `verify-claims` 仍 rc=0（输出"5 门全绿"）。已补 **§10d 存在性断言**（断言本 change 4 项交付物在位：check-dist 挂载+target / SCANNED_FILES 出口 / 真入口判据+白名单 / `--check` 模式）。**双向实测**：正例 14✅/0❌；摘掉 check-dist → **13✅/1❌ rc=1** 被抓。这使回归保护从"只存在于随归档迁移的 `verify/`"变为"落在**被跟踪**的 `verify-claims.sh`"。 |
| **R1-a** · **【主 agent 误判】** REVIEW.md 自称"未装 brooks-lint"不实 | `Fixed in:` REVIEW.md（新增方法论缺陷说明节） | **完全成立，我认错**。实测：`~/.claude/tools/brooks-lint/` 存在 · marketplace 的 `skills/brooks-review` 存在 · `.brooks-lint-history.json` **7 次历史运行** · 本会话技能目录含 `brooks-review`/`brooks-audit`/`brooks-debt`/`brooks-health`/`brooks-sweep`/`brooks-test`。**我为何写错**：未核实即断言（凭"本轮没调用过"推断"没装"）。**实质后果**：6 维诊断走了**低质量回退**（该工具 benchmark：带书本引用 100% vs 约 16%），故 **R3/R4/R5 三维全 0 很可能是漏判** —— 你的复核（4 条属我漏判）印证了这一点。已把"6 维诊断未经专用工具、结论可信度受限"**显式记为已知局限**，并建议**由人工在 Claude Code 内跑 `/brooks-review` 复核**。 |
| **R1-b** · **【主 agent 漏判】** 工作区增量描述错误，且 §10c 语义变更两轮均未审 | `Fixed in:` REVIEW.md（更正 + 补审） | **成立**。① 增量的实际内容是 `Makefile`(+5/−1) 与 `verify-claims.sh`(+15/−2)，**非**我写的"TEST.md 的诚实性修复"；② 其中 `verify-claims.sh` §10c 是**语义变更**（空集假绿修复 + 计数 `echo \| wc -l` 的 1≠0 陷阱），初版两轮**均未覆盖**。已在 REVIEW.md 补审该变更（判定 ✅ 无问题）。 |

### 对 🟢 的响应

| Finding | 处置 |
|---|---|
| `Makefile:112-113` 同一理由连写两遍 | 已删重复句 |
| `check_dist` 行数"64 行/注释 1/3"不实（实为 **68 行 / 5 个整行注释块**） | 已更正两处引用 |
| 该 🟢 被**错记为 R6**（应为 R1 认知过载） | 已更正并标注"归类更正" |
| "+274" 含 2 个 `.specs/` 文件（生产实为 **+226/−22**） | 已更正并说明口径 |
| 第四轮 4.1 的"CONTEXT.md 技术债段刚更新"——**该段名不存在** | 已更正为 CONTEXT.md 的 **`### 技术债（来自 M-health · …）`** 小节（`:494` 起） |
| 注释里"21 处 SC1090"实为 **22 处**（扩面后） | 已更正 5 个载体；并在 `Makefile` 注明来源（扩面前 21 → 扩面后 22，+1 属既有告警随扩面暴露，非新引入） |

### ⚠️ 我在处置过程中犯的一处**协议违规**（自查发现，已回退）

批量更正 SC1090 计数时，我的脚本**把 `INDEPENDENT-REVIEW-6.md` 里的文字也改了** —— 那是**审查员的原文**，
而 `L2-blind-review.md` 明文规定「**主 agent 无权修改你的原文判断**；它若反驳，必须在你的报告之后另起段标注」。
**我立即回退了该处**（把 22 改回审查员原文的 21），并确认其余修改只落在**本 change 自己的工件**上。
**正确做法**：对审查员结论有异议，只能写在"主 agent 响应"段 —— 本次即如此（见上表 R1-a 的"已更正"说明都在响应段与本 change 工件内）。

**教训已并入 LESSONS**：批量文本替换脚本必须**排除审查产物**（`INDEPENDENT-REVIEW-*.md`），否则会无意改写审计凭证。

### 附带发现（我在响应 R2-c 时自测发现，L2 未提）

`make lint` 的扫描面在本次响应过程中从 **66 → 67** —— 追查发现仓库根多了一个**未跟踪的游离文件**
`.sync-hooks-orphan-test.sh`（mtime **01:45:54**，晚于本 change 的全部实现动作）。其内容是
`sync-hooks.sh` 的整体副本，仅一处差异：第 49 行把用户级路径替换为 `/tmp/tmp.fR7C6PJtRw/fake-root-orphan`
—— 显然是为测试 orphan / 真入口检测而造的**隔离探针残留**。

**处置**：移出仓库（备份 `/tmp/stray-orphan-test.sh.bak`），扫描面恢复 **66**。

**这条的意义**：它说明"卫生"是**时点性**的 —— `ac8.sh` 在跑完我的夹具后确实零残留（当时 PASS 为真），
但**外部探针可能在之后引入游离文件**。`make lint` 的扫描面因此成为一个**意外的游离文件探测器**
（67≠66 即暴露）。**建议**：把"扫描面计数"纳入健康巡检的常规观察项。

### 补充说明

- **我对 L2 的核心判断无异议**：它把 R2-a 标 🟡 而非 🔴（理由：不属"AC 未实现 / 安全漏洞 / 数据损坏"三分类），
  按 flow-kit 的严重度定义**是正确的**。我仍选择修它，理由是它违反 AC-1 的**语义承诺**（删除源文件后仍报"一致"），
  属"判据有洞"而非"风格问题"—— 本 change 的整个目的就是堵这类洞。
- 关于 L2 的提醒"若项目把『REVIEW 自检项必须与事实一致』当作阶段门禁硬条件，则 R1-a 应按 🔴 对待"——
  **我接受该提示但不擅自改判严重度**；按流程，这属**需人工裁定**项，已在报告与本节同时留明。
- 我未改动 L2 的原文判断（含本次回退）。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-21 02:13）

> 自动生成于 2026-09-21 02:13。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "verify-claims.sh",
      "issue": "新增的 10d 关键门禁存在性检查使用 `grep -q 'SCANNED_FILES' Makefile`、`grep -q -- '--check' package-dsh-plugin.sh` 等纯字符串匹配，未排除注释，存在假绿风险。",
      "why": "Makefile 注释中明确包含“SCANNED_FILES 出口（REQUIREMENT AC-4 输出契约）”等字样（本次 diff 中可见），package-dsh-plugin.sh 注释中也含 `--check` 说明。若实际实现被删除而注释保留，grep 仍会命中，导致该检查在交付物缺失时错误通过，违背其“关键门禁存续”的守护目的。",
      "fix": "改用更精确的判定：例如检查 `Makefile` 中非注释行 `^\s*@?.*SCANNED_FILES` 或直接运行 `make lint` 并断言输出含 `^SCANNED_FILES:` 行；对 `--check` 可检查 `case` 分支或 `getopts` 中的实际处理，而非全文 grep。"
    }
  ],
  "minor": [
    {
      "file": ".specs/health-fix-2026-09/verify/ac1.sh",
      "issue": "第二个 `trap 'git checkout -- ...' EXIT` 覆盖了第一个 `trap 'rm -rf \"$TMPD\"' EXIT`，导致 mktemp 创建的临时目录在脚本退出后残留。",
      "why": "同一 shell 进程对同一信号只能有一个 trap，后注册的会覆盖先前的。这样 TMPD 不会被清理，反复运行会在 /tmp 积累垃圾文件；ac3.sh 也有相同问题。",
      "fix": "合并为单一 trap，例如 `trap 'rm -rf \"$TMPD\"; git checkout -- dsh-flow-kit/README.md' EXIT`；或分别用不同信号 / 显式 cleanup 函数。"
    },
    {
      "file": ".specs/health-fix-2026-09/verify/ac3.sh",
      "issue": "与 ac1.sh 相同的 trap 覆盖问题：`trap 'git checkout -- '\"$F\" EXIT` 覆盖了 `trap 'rm -rf \"$TMPD\"' EXIT`。",
      "why": "临时目录不会被清理，造成资源泄漏；模式与其他夹具不一致。",
      "fix": "合并 trap：`trap 'rm -rf \"$TMPD\"; git checkout -- \"$F\"' EXIT`。"
    },
    {
      "file": ".specs/health-fix-2026-09/verify/ac4.sh",
      "issue": "脚本内硬编码了与 Makefile/REQUIREMENT 相同的排除路径列表，且使用固定文件 `/tmp/ac4_log`。",
      "why": "排除列表在多处重复，若契约更新而此脚本未同步，会产生误报或漏报；固定 /tmp 文件名在并发执行时互相覆盖。",
      "fix": "从 Makefile 的 SCAN_EXCLUDES 单一来源动态提取排除列表；日志文件改放 `$TMPD` 下。"
    },
    {
      "file": ".specs/health-fix-2026-09/verify/ac4c.sh",
      "issue": "同样硬编码了契约排除集（`-path '*/.git/*'` 等），并直接写入 `/tmp/ac4c_log`。",
      "why": "排除集若在 REQUIREMENT/Makefile 中变更，此处可能漂移；固定 /tmp 文件并发不安全。",
      "fix": "与 ac4b.sh 类似，从 REQUIREMENT 表格解析排除集；日志使用 `$TMPD`。"
    },
    {
      "file": ".specs/health-fix-2026-09/verify/ac8.sh",
      "issue": "基线文件全部写死在 `/tmp/ac8_base_*.txt`，没有使用 mktemp 隔离。",
      "why": "并发运行多个夹具或与其他使用 /tmp 的进程冲突时，基线会被篡改，导致 AC-8 误报。",
      "fix": "使用 `TMPD=$(mktemp -d)` 并在 trap 中清理，所有中间文件放入 `$TMPD`。"
    },
    {
      "file": ".specs/health-fix-2026-09/DEV-SUMMARY.md",
      "issue": "性能数字与更新后的 Makefile 注释矛盾：DEV-SUMMARY 写“NFR「≤2s」实际为 13ms 量级”，而 Makefile 注释明确更正为“实测 0.61s（中位数 ×3……低估了 47×）”。",
      "why": "同一 change 的交付文档存在事实性矛盾，后续维护者无法确定哪个是真实数据，违背了本 change 自己强调的“事实性断言必须实测并标注取证方式”的教训。",
      "fix": "将 DEV-SUMMARY 中的性能数字同步更正为 0.61s，并注明旧值 13ms 为设计期低估。"
    },
    {
      "file": ".specs/health-fix-2026-09/verify/ac7.sh",
      "issue": "硬编码了 `950 ok / 0 not ok / 1 skip` 和 `✅ 13  ❌ 0` 等精确计数。",
      "why": "一旦后续 change 增加或删除任何测试/验证项，AC-7 会无条件失败，即使仓库本身健康，导致回归门禁过于脆弱并增加维护成本。",
      "fix": "考虑将精确计数改为范围或基线文件驱动（例如从已知基线生成期望值），或至少在 REQUIREMENT 中明示该 AC 是严格的快照式回归并附带更新流程。"
    }
  ],
  "verdict": "pass",
  "summary": "整体实现与 AC 覆盖基本完整，验证脚本设计较扎实；但存在一处验证逻辑假绿风险（字符串匹配注释）和若干临时文件/硬编码/文档一致性问题，均不构成 critical 缺陷。"
}
```

L3_artifact_hash: 2b2b98052e1f311f8f72577b5e197ee1194779ec3481a4cd05ba5c519487497a

<!-- /L3-SECTION -->
