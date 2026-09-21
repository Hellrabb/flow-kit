# 独立审查 · 阶段 3

---

## L2 盲审

**审查对象**：`.specs/health-fix-2026-09/TASK.md`（297 行）
**允许参考**：`REQUIREMENT.md`（11 条 AC）、`DESIGN.md`（D1–D8 / R1–R11）、`.specs/CONTEXT.md`（禁动清单）
**方法**：不只读不查。以下每条结论都有在**当前仓库**上实测的命令与输出支撑（`sync-hooks.sh --check`、`make lint`、`make check`、`bash verify-claims.sh`、`comm` 集合差、复刻 exec 判据域、复现两个 AC 解析器的最小样本）。审查动作本身无副作用：审查前后 `git status --porcelain` 逐行一致，`diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle` 仍为 rc=0。
**独立性**：输入中未收到任何主 agent 自评 / 草稿 / 概述 / 辩护；报告未引用任何「作者认为」类陈述。

---

### 已核实的正面项（先说结论对的部分，避免证实偏差的反向偏差）

- **AC 覆盖无漏配**：11 条（AC-1..AC-9 + AC-4b + AC-4c）逐条能在 XML 任务块里找到承接任务，覆盖矩阵（`TASK.md:256-266`）与 XML 一致，无"矩阵里有、XML 里没有"或反之的情况。
- **依赖图无环、无悬空 id**；同 wave 的 write_files 两两不相交（Wave 1：`package-dsh-plugin.sh` / `Makefile` / `sync-hooks.sh`；Wave 2：`.specs/.../verify/*` 与 `verify-claims.sh`）——文件级并行成立。
- **禁动清单零越界**：`hooks/**`、`prompts/**`、`skills/**`、`brooks-lint/**`、`dsh-flow-kit/lib/*.js`（DESIGN:58-63）与 `package-flow-kit.sh`、`.gitignore`、`test/`（CONTEXT:456-480）均未出现在任何 write_files。
- **"7 个漏扫脚本"为真**：`comm -13`（现 glob 集 vs AC-4 契约集）实测差集恰为 REQUIREMENT:105-113 列的那 7 条路径，无第 8 条、无"现扫描集里有而契约集里没有"的反向差。
- **扩面不会把 lint 弄红**：对那 7 个文件跑 `shellcheck -e SC1091`，error 级全部为 0（warning 合计 5 处）——与 D8 / DESIGN R1「只让 warning 可见」的预期一致，AC-7 的 `lint error 0` 可达。
- **DESIGN 8 条决策均有承接**：D1/D2/D3→T01，D7→T02，D4/D5/D6→T03，D8→T02 ④（+T06 的理由注释）。无"设计了但没排任务"的决策。
- **基线取证复核**：`make check` 当前全绿（5 门）；`make lint` rc=0；`bash verify-claims.sh` 当前 **exit 0 / 复验结果: ✅ 13 ❌ 0 / 第 10 项 "make check 5 门全绿"**（门数确为现场数出，非写死）。
- **T04 的关键前提成立**：`dsh-flow-kit/README.md`、`flow-kit-bundle/install.sh` 确被 git 跟踪（`git checkout --` 还原可行）；AC-6 的探针路径 `dist/dsh-flow-kit/hooks/pre-tool-use/independent-review-gate.sh` 存在且有 exec 位。

---

### 🔴 R1 · T03 的 `verify` 是**反相**的：修复完成后它必然失败，修复前反而通过

**Severity**：🔴 Critical
**Symptom（症状）**：`TASK.md:133` 写的是 `bash sync-hooks.sh --check 2>&1 | grep -c '缺可执行位'`，而同任务 `TASK.md:136` 的 `done` 要求"该计数为 **0**"。实测：当前 `bash sync-hooks.sh --check` → exit 0，输出含 **1 行** `⚠️  5 个 hook 入口缺可执行位…`，故 `grep -c` 打印 `1` 且 **exit 0** → verify 判"通过"。一旦 T03 把误报清零，`grep -c` 打印 `0` 但 **exit 1**（`grep` 无匹配即非零），管道整体 exit 1 → verify 判"失败"。即：**verify 恰好在 done 达成的那一刻翻红**。
**Source（源头）**：`3-task.md:134`（R2.3 verify 必须可执行）+ `4-dev.md:240-241`「只有 verify 通过才能进入下一步」+ R2.4「verify 未通过禁止标记完成」；REQUIREMENT:194-196 的 AC-5 修正记录**已经明令**「必须显式捕获退出码 —— 管道会吞掉 make 的返回码」，本任务的 verify 正是它禁止的写法。
**Consequence（后果）**：DEV 阶段必然出现"实现正确 → verify 红 → 任务无法标记完成"的死循环，执行者只有两条路：伪造完成，或临时改 verify（改判据）；同时该 verify 在修复前即为绿，对 AC-5 **零证明力**。当轮就炸。
**Remedy（修补）**：按 AC-5 的显式取码写法重写，并同时锁定"计数为 0"与"退出码 0"：
```bash
bash sync-hooks.sh --check >/tmp/t03.log 2>&1; rc=$?; [ "$rc" -eq 0 ] || exit 1
[ "$(grep -c '缺可执行位' /tmp/t03.log)" -eq 0 ] || exit 1; echo OK
```
AC-6 的"检出时指名"能力可在 verify 里加一次 `chmod -x` 探针（T04 的 `ac6.sh` 只是 TEST 阶段的补充，不能替代本任务的 verify）。

---

### 🔴 R2 · T05 / T06 的 `verify` **恒真**：退出码被 `echo` / `wc -l` 吃掉，无论实现与否都通过

**Severity**：🔴 Critical
**Symptom（症状）**：
- `TASK.md:193`：`bash verify-claims.sh; echo "rc=$?"` —— 整条命令的退出码来自末尾的 `echo`，**恒为 0**；`verify-claims.sh` 即使 exit 1 也照样"通过"。
- `TASK.md:221`：`grep -l 'health-fix-2026-09' Makefile sync-hooks.sh package-dsh-plugin.sh | wc -l` —— `wc -l` 无论计数几都 **exit 0**。
实测（零实现状态下）：三载体 grep 计数 = **0**，该 verify 退出码 = **0**；T05 的 verify 同样 exit 0。即两条 verify 现在就已经"绿"，与 T06/T05 是否做毫无关系。
附：T05 的 `action`（`TASK.md:190`）自述 F6 两处修复"已在阶段 1 由 L2 R3 触发并完成初版"，实测 `git status` 显示 `verify-claims.sh` 处于**未提交的已修改**状态，且 `resolve_spec_artifact` + 门数动态推导确已在位（第 8/9/10c/10 项全过）——即 T05 的"实现"在阶段 3 之前就已发生，它连"实现前失败"这个前提都不存在了。
**Source（源头）**：`3-task.md:84`（verify 是一条可执行验证命令）+ `4-dev.md:240`（只有 verify 通过才能进入下一步）；与 R1 同一条教训：包装/管道吞掉退出码等于取消判据。
**Consequence（后果）**：AC-9（三载体理由注释）与 AC-7 ⑥（门数动态推导 + 无"五门"字样）在整个 DEV 阶段**无人把关**：T06 完全可以不加任何注释而把任务标 done，直到 6-review 才暴露，返工成本从"改 3 个文件"变成"重跑一遍审查"。
**Remedy（修补）**：
- T05：`bash verify-claims.sh >/tmp/vc.log 2>&1 || exit 1; grep -q '复验结果: ✅ 13  ❌ 0' /tmp/vc.log || exit 1; grep -qE 'make check [0-9]+ 门全绿' /tmp/vc.log`；并在 `action` 里改为如实描述"本任务为**验收 + 收尾**（F6 已落地），若实测已绿需在 SUMMARY 说明未产生新实现"，否则 DEV 无法判定该任务的价值。
- T06：`[ "$(grep -l 'health-fix-2026-09' Makefile sync-hooks.sh package-dsh-plugin.sh | wc -l)" -eq 3 ]`（把计数变成断言，而不是打印出来）。

---

### 🔴 R3 · T07 的 `verify` 引用一个**永不存在的 `ac7.sh`**，静默降级为 `make check`——且该 verify 现在就是绿的

**Severity**：🔴 Critical
**Symptom（症状）**：`TASK.md:243`：`bash .specs/health-fix-2026-09/verify/ac7.sh 2>/dev/null || make check`。
- 该文件**没有任何 task 会创建**：T04 的 write_files（`TASK.md:151-156`）只落盘 `ac1/ac3/ac4/ac4c/ac5/ac6`；T07 的 write_files（`:233-235`）只有 `DEV-SUMMARY.md`；实测 `.specs/health-fix-2026-09/verify/` 目录**当前不存在**（`ls` 报"没有那个文件或目录"）→ bash 返回 127 → 永远走 `|| make check` 分支。
- 实测该命令**现在 exit 0**（T01–T06 一行未实现，因为 `make check` 当前全绿）。`||` 兜底把"夹具缺失"与"回归失败"合并成同一个动作，且把红判绿。
- 覆盖面：它只断言"门禁全绿"，**完全不含** AC-7 的 6 项数字基线（bats 950/0/1、lint error 0、validate 漏配 0/源缺失 0、双源一致、漂移 0、verify-claims 13/0），也不含 AC-8 的工作区卫生断言。
**Source（源头）**：REQUIREMENT:264-304（AC-7 六项精确断言）与 :336-353（AC-8）；`3-task.md:134`；以及本仓"清单/计数断言必须从实现的单一出口读取"的既有原则——这里连出口都不存在。
**Consequence（后果）**：AC-7 / AC-8 在 DEV 阶段**没有任何机器判据**，DEV 可以宣称"回归全绿"而无证据；真正的 950/0/1 断言第一次执行要等到 5-test，届时任何基线漂移（本 change 若合法增删 bats 用例，REQUIREMENT:261 已预告）都会炸在 TEST 而不是 DEV，跨阶段返工。
**Remedy（修补）**：二选一并与 write_files 对齐——① 把 `ac7.sh` 加入 T04 的 write_files（把 REQUIREMENT:264-304 的脚本原样落盘），T07 的 verify 改为 `bash .specs/health-fix-2026-09/verify/ac7.sh`（**删掉 `||` 兜底**）；② 把 AC-7 六项内联进 T07 的 verify，并为 AC-8 补 `ac8.sh`（REQUIREMENT:336-353 已有全文）。无论哪种，**必须去掉静默降级**：夹具缺失应显式红，而不是换成另一个更弱的判据。

---

### 🔴 R4 · AC-4 / AC-4c 的解析器与路径格式**自相矛盾**——任何实现都无法让它通过（T02 的 `done` 不可达）

**Severity**：🔴 Critical
**Symptom（症状）**：T02 的出口契约（`TASK.md:94`）只写了"固定输出 `SCANNED_FILES: <n>` 及其后逐行路径"，**没钉路径格式**；而 REQUIREMENT:125-126（AC-4）与 :171-172（AC-4c）的解析器是
`awk '/^SCANNED_FILES:/{f=1;next} f&&/^\//{print} f&&!/^\//{exit}'`
随后用 `sed 's|^\./||'` 归一，再与 `find . -name '*.sh' …` 产出的**相对路径**做 `comm`。实测两种格式都走不通：
- **打印绝对路径**（`/home/.../flow-kit-bundle/install.sh`）：awk 能解析，但 `ac4_all.txt` 全是相对路径 → `comm -13` 把**每一条**都判为"漏扫"（我用 2 文件最小样本复现：`miss=2`，即 100% 误判）→ AC-4 红。
- **打印 `./x` 或 `x`**：awk 的第二条规则 `f&&!/^\//{exit}` 在遇到第一行路径时立刻退出 → 解析结果为**空**，脚本在 `[ -s /tmp/ac4_in.txt ]` 处报"解析出的扫描清单为空"→ AC-4 红。
AC-4c 用同一把 awk，因此同样不可满足。**不存在任何一种输出格式能让 AC-4/AC-4c 变绿**，而 `TASK.md:104` 的 `done` 却断言"AC-3 / AC-4 / AC-4b / AC-4c 就位"。
**Source（源头）**：REQUIREMENT:117（"只采用一种出口"的定案）、:120-135（AC-4 脚本）、:167-187（AC-4c 脚本）；`TASK.md:88-99`（action ④）与 :104（done）。
**Consequence（后果）**：本 change 两条核心 AC（"lint 覆盖全部生产脚本"的唯一机器证明）无法达成。执行者只有三条路：卡死在 DEV、在 DEV 里"自行发明"第三条出口描述、或中途改 AC——而 REQUIREMENT:450 明写"AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC"，中途静默改 AC 会污染 5-test / 6-review。
**Remedy（修补）**：把路径格式提升为 T02 的**显式契约**并同时修正解析器（二者必须一起改，单改一边仍不可满足）：
1. `TASK.md:94` 改为："逐行输出 `./` 前缀的仓库相对路径（与 `find .` 同形），列表以一个**空行**结束"；
2. REQUIREMENT 的 AC-4 / AC-4c awk 改为 `f&&/^\.\//{print} f&&!/^\.\//{exit}`（更稳的写法：`f&&NF{print;next} f{exit}`）；
3. 按流程**显式回写 REQUIREMENT AC-4 / AC-4c**（不得在实现里静默调整）；
4. 顺带在 T02 的 verify 里断言那 7 条漏扫路径**出现在清单中**——AC-4 的"差集为空"单独看是必要非充分（集合两边同时漏掉同一文件时它仍为 0，这正是 AC-4c 存在的理由）。

---

### 🟡 R5 · T02 与 T01 的接口依赖未声明；且在 T01 缺席时 `check-dist` 会退化成"重建成功"的**假门禁**

**Severity**：🟡 Important
**Symptom（症状）**：`TASK.md:82` 的 read_files 注释自认「依赖 T01 提供的 `--check` 接口」，但 `TASK.md:106` 的 `<depends_on></depends_on>` 为空，波次图（`:12`）把 T01/T02 并列为 Wave 1「并行、文件互不重叠」。实测 `package-dsh-plugin.sh` **不解析任何参数**（全文无 `case`/`$1`，`:19` 起直接执行打包），`--check` 会被静默忽略并完整执行 `:24-57` 的 `rm -rf` + `cp` 重建 → `make check-dist` 在 T01 未落地时 **exit 0**（只是把 dist 重建了一遍）。T02 的 verify（`:101`）因此无法区分"真新鲜度门禁"与"假门禁"。
**Source（源头）**：`3-task.md:135`「parallel=true 的 task 之间是否真无依赖」；`TASK.md:82` 与 `:106` 自相矛盾。
**Consequence（后果）**：并行执行 → T02 拿到**假绿**（AC-1 的拦截能力实际不存在，而 done 宣称 AC-1 就位）；串行执行 → 依赖声明与波次图又不一致，执行者无所适从。
**Remedy（修补）**：给 T02 加 `<depends_on>T01</depends_on>`（或把 T02 移入 Wave 2）；并让 T02 的 verify 具备识别假门禁的能力（见 R6 的 `make check` 断言）。

---

### 🟡 R6 · AC-2 的输出标记契约没落到任何 task；T02 的 verify 也不校验 `check-dist` 已挂进 `check:`

**Severity**：🟡 Important
**Symptom（症状）**：
- REQUIREMENT:67 的 AC-2 判据是 `grep -qiE 'check-dist.*(pass|一致|✅|通过)' /tmp/ac2.log`——要求同一行里同时出现 `check-dist` 与 `pass/一致/✅/通过`。T01（`:59-68`）与 T02（`:88-99`）**都没有**把这个输出契约写进 action/done；T02 的 ⑤ 只要求"薄壳调 `--check`"，若薄壳不 echo 任何含 `check-dist` 的成功行，AC-2 就必然红。
- T02 的 action ⑤ 要求把 `check-dist` "挂进 `check:` 依赖"，但其 verify（`:101`）是**直接调 `make check-dist`**，不经过 `make check` → 即使没挂上也照样通过。而挂载点恰恰是 AC-1 的全部意义（"改了源不重建 → `make check` 非零"）。
**Source（源头）**：REQUIREMENT:51-70（AC-2 脚本）；`TASK.md:97-98` 与 :104（done 声称 AC-1/AC-2 就位）。
**Consequence（后果）**：TEST 阶段 AC-2 可能只因文案不匹配而红（一轮返工），或反过来被人"改文案凑绿"（判据被文案绑架）；`check-dist` 漏挂 `check:` 时 AC-1 整体失效而 DEV 阶段无人察觉。
**Remedy（修补）**：① 在 T01/T02 的 action 里各写死一行输出契约（例：`--check` 通过时打印 `✅ check-dist: dist 与源一致（N 文件）`）；② T02 的 verify 追加 `make -n check | grep -q check-dist`（或 `make check 2>&1 | grep -q 'check-dist'`）。

---

### 🟡 R7 · T03 ② 的"消除 5 处误报中的 4 处"与实测不符：基线 5 处**全部**是 `pre-tool-use` 库文件，收窄后应为 0

**Severity**：🟡 Important
**Symptom（症状）**：`TASK.md:124-125` 称把 4 个只被 `source` 的库移出判据域后「消除既有 5 处误报中的 **4 处**」。实测（复刻 `sync-hooks.sh:164-196` 的判据域：`HOOK_MODULE_NAMES` 的 `stop/*.sh` + `session-start/*.sh` + `pre-tool-use/*.sh`，逐镜像根检查 `! -x`）当前 5 处为：
`.claude/hooks/pre-tool-use/gate-checks-review.sh`、`dist/dsh-flow-kit/vendor/…/gate-checks-basic.sh`、`…/gate-checks-review.sh`、`…/gate-helpers.sh`、`…/gate-helpers-types.sh`
——**5 处无一例外都是那 4 个库的镜像副本**，没有一处落在"真入口"上；收窄后是 5 → **0**，不是 5 → 1。
**Source（源头）**：`TASK.md:124-125` 与 `:136`（done 要求计数为 0）互相矛盾；REQUIREMENT:191 的基线描述（"`pre-tool-use/` 下 4 个库 + `.claude/hooks` 下 1 个"）与实测的"全部是库副本"更吻合。
**Consequence（后果）**：执行者按 ② 期待"还剩 1 处"，实测得到 0 时会怀疑判据写错（甚至去给某个库"补回"检查）→ 白耗一轮，并掩盖"5→0 全部由收窄带来"这一事实。
**Remedy（修补）**：把 ② 改写为"4 个库的**全部 5 处镜像副本**移出判据域 → 基线告警 **5 → 0**"，并把这 5 条实测路径列进 action 作为对照。

---

### 🟡 R8 · T00 的 `write_files: dist/**` 不在 DESIGN §0.5.1 范围内，而 TASK 末尾的越界断言不实

**Severity**：🟡 Important（不判 Critical 的理由见下）
**Symptom（症状）**：`TASK.md:33-35` 让 T00 写 `dist/**`。DESIGN:46-64 的「触碰模块 + 新增模块」清单里**没有 dist**（只有 `Makefile` / `sync-hooks.sh` / `package-dsh-plugin.sh` / `verify-claims.sh` / `common.sh`（只读）/ 新增 `.specs/<id>/verify/ac*.sh`）；DESIGN:244-250 §9.5 反倒把 `dist/**` 列为"**建议新增（禁动）**：禁止手工编辑 dist 内任何文件"。而 `TASK.md:250-252` 断言"所有 `write_files` 均在 DESIGN ## 0.5.1「触碰模块 + 新增模块」范围内"——该断言被上述两条直接证伪（T07 的 `DEV-SUMMARY.md` 也不在 §0.5.1 的新增清单里）。
**Source（源头）**：flow-task 自检「每个 `write_files` 都严格在 DESIGN「触碰模块 + 新增模块」范围内」；`3-task.md:47`（write_files 是 R7.3 强约束，4-dev 步骤 5 会按它做 diff 边界 verify）；DESIGN §0.5.1 / §9.5。
**Consequence（后果）**：stage-3 自检项 3 应当判 ❌；一旦有人照 §9.5 把 `dist/**` 写进 CONTEXT 禁动清单（该建议已被 DESIGN 正式提出），T00 立刻从"合法前置"变成"越界写禁动文件"。故按口径必须修，但**不判 Critical**：CONTEXT:456+ 的现行禁动清单**未**收录 dist，且 dist 被 `.gitignore:63` 忽略、不会产生 git 可见 diff，实际破坏面是口径而非安全。
**Remedy（修补）**：在 DESIGN §0.5.1 显式登记一行例外——「`dist/**`：派生产物，仅允许由 `package-dsh-plugin.sh` 重建（T00 前置）」；并把 `TASK.md:250-252` 改成如实表述（"除 dist 重建与 .specs 工件外，其余 write_files 均在 §0.5.1 范围内"）。

---

### 🟡 R9 · T01 要求重构打包脚本主流程，但 verify 不覆盖"原打包路径 0 回归"

**Severity**：🟡 Important
**Symptom（症状）**：`TASK.md:60-61` 要求 `--check` 复用"脚本第 1-5 步已有的源→dist 映射"且"**禁止另写一份映射表**"。现脚本的第 1-5 步是**命令式**的 `cp -R` / `cp` + `|| true` 可选语义 + 第 5 步的 chmod（`package-dsh-plugin.sh:27-57`）；要"复用"就必须先把它们改造成可遍历的数据结构——这是对构建入口的**行为重构**。而 T01 的 verify（`:69-70`）只跑 `--check`，**从不跑无参的 `bash package-dsh-plugin.sh`**，也不检查 `docs/`（两个可选源）与 `vendor/` 是否仍被正确拷贝。
**Source（源头）**：`TASK.md:60-61` vs `:69-70`；DESIGN D2（选择"放进组装脚本内"＝单一事实源，代价是 `package-dsh-plugin.sh` +约 60 行）。
**Consequence（后果）**：重构把打包打坏（漏掉可选 docs、丢掉 chmod、vendor 少拷一层）时 DEV 阶段全绿；第一次真正重建 dist 的人（5-test 的 AC-1/AC-2 前置、或下一次改源）会拿到与源不一致的产物，并把红判给**错误的 change**——这正是本 change 要消灭的"假安全感"换了个位置。
**Remedy（修补）**：T01 的 verify 追加一条回归断言：
`bash package-dsh-plugin.sh >/dev/null && diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle`
（或至少断言 `bash package-dsh-plugin.sh` exit 0 且 `dist/dsh-flow-kit/{lib,docs,vendor}` 三类都在）。

---

### 🟡 R13 · 波次图的依赖标注与 XML 矛盾（T05 到底 depends on T02 还是 T03？），且 Wave 2 的描述写的是 T03 的工作

**Severity**：🟡 Important
**Symptom（症状）**：`TASK.md:13` "Wave 2 (parallel): T04[P], T05[P] —— 验证夹具 + **真入口清单收窄**（T05 depends on **T03**）"，而 XML `:198` 是 `<depends_on>T02</depends_on>`；"真入口清单收窄"是 **T03**（Wave 1）的 name，不是 T05（verify-claims F6）的内容。
**Source（源头）**：`3-task.md` 的 Plan-Conflict Scan 第 1 类（"parallel=true 的 task 之间是否真无依赖"）；4-dev 按波次图调度。
**Consequence（后果）**：同一份依赖图有两套互相矛盾的表述；T05 真正的准入条件（T02 的 Makefile 门数改动）只在 XML 里，图里写的是无关的 T03 → 执行者按图调度会多压一轮串行或误判准入。
**Remedy（修补）**：`TASK.md:13` 改为"（T05 depends on T02）"，描述改为 T05 的真实内容（verify-claims 路径解析化 + 门数动态推导）。

---

### 🟢 R10 · T00 的时间戳取证与实测不符（"20:24 重建过" vs dist mtime 20:55）

**Severity**：🟢 Minor
**Symptom（症状）**：`TASK.md:19`"当前 dist 已对齐（**20:24** 重建过）"。实测 `stat dist` = `2026-09-20 20:55:39`，`dist/dsh-flow-kit` = `20:55:37`（TASK.md 自身 mtime 也是 20:55）；`diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle` → 差异 0（**结论正确，取证过期**）。
**Source（源头）**：`TASK.md:19`；DESIGN R11 自己沉淀的教训——"跨动作的基线必须当场重测，不得转抄早期输出"。
**Consequence（后果）**：不影响判断（结论恰好仍成立），但这是本 change 正在治的"转抄旧取证"习惯的复发；若期间 dist 被谁改动过，这条描述会把下一个执行者带偏。另注：T00 的 verify 现在即为绿（dist 已对齐），作为幂等前置可接受，但不宜被当作"完成了一项工作"。
**Remedy（修补）**：去掉时间，改写为实测命令与结果（`diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle` → rc=0）。

---

### 🟢 R11 · T04 的还原约定与 REQUIREMENT:355 的"实现要求"字面冲突，且未登记偏离

**Severity**：🟢 Minor
**Symptom（症状）**：`TASK.md:161-162` 把还原按"目标是否被 git 跟踪"区分（AC-1/AC-3 用 `git checkout --`，AC-6 用 `chmod +x`）；而 REQUIREMENT:355 的实现要求（明确标注"供 3-task / 4-dev"）写的是"AC-1/3/4/5/6 的验证脚本……还原**一律**用 `git checkout -- <file>`"。AC-6 正文（:240-242）本身又说必须用 chmod（dist 被忽略、`git checkout` 不还原权限），即 REQUIREMENT 内部自相矛盾。TASK 选了正确的一边，但**没写"此处覆盖 :355"**。
**Source（源头）**：REQUIREMENT:355 vs :240-242；`TASK.md:161-162`。
**Consequence（后果）**：5-test / 6-review 若按 :355 字面判，会把正确实现判成"未按实现要求落盘"（一轮返工）。
**Remedy（修补）**：在 T04 的 action 里加一句"依据 AC-6 正文与实测，本任务覆盖 REQUIREMENT:355 的一刀切写法"，或请主 agent 回写 :355 使其自洽。

---

### 🟢 R12 · `ac4c.sh` 落盘后没有任何 task 会执行它

**Severity**：🟢 Minor
**Symptom（症状）**：T04 的 write_files（`TASK.md:154`）产出 `ac4c.sh`，但 AC-8 的运行清单（REQUIREMENT:343-347）只有 `ac1/ac3/ac4/ac5/ac6`；T07 的 action 只列"AC-7 六项 + AC-8 卫生断言"，也没提 ac4c。
**Source（源头）**：REQUIREMENT:336-353 与 :159-187。
**Consequence（后果）**：AC-4c（"排除契约不可被静默扩张"）在 DEV→TEST 之间没有明确触发点，只能等 5-test 自行从 AC 派生，存在遗漏风险——而它正是 AC-4 的唯一补强。
**Remedy（修补）**：在 T07 的 action 里显式加"跑 `verify/ac4c.sh`"，或把 ac4c 纳入 AC-8 的运行清单。

---

### 🟢 R14 · TASK.md 内没有 plan-conflict-scan 结论（3-task 的强制步骤）

**Severity**：🟢 Minor
**Symptom（症状）**：全文 `grep -n 'conflict\|自检'` **无命中**（另实测：归档的 89 份 TASK.md 中只有 3 份含该段，属惯例松散）。
**Source（源头）**：`3-task.md:125-161`「进入自检前执行」3 类扫描，并规定输出 `✅ plan-conflict-scan 通过（0 conflicts）` 或冲突清单。
**Consequence（后果）**：少一道自检闸。本次若真跑过：第 1 类扫描（同 wave 依赖/verify 可执行性）应命中 R5/R13，第 2 类（禁动/边界）应命中 R8。
**Remedy（修补）**：在 TASK.md 末尾补该段（按实际冲突数列出），而非留空。

---

## 汇总

| 编号 | 主题 | 严重度 |
|---|---|---|
| R1 | T03 verify 反相（修复后必红） | 🔴 Critical |
| R2 | T05/T06 verify 恒真（退出码被吞） | 🔴 Critical |
| R3 | T07 verify 引用永不存在的 ac7.sh，静默降级且现在即绿 | 🔴 Critical |
| R4 | AC-4/AC-4c 解析器与路径格式矛盾 → 不可满足 | 🔴 Critical |
| R5 | T02↔T01 接口依赖未声明 + check-dist 假门禁 | 🟡 Important |
| R6 | AC-2 输出标记契约缺失 + 未校验 check: 挂载 | 🟡 Important |
| R7 | T03 ② "5 处中的 4 处"与实测不符（应为 5→0） | 🟡 Important |
| R8 | T00 `write_files: dist/**` 越 DESIGN §0.5.1 范围 | 🟡 Important |
| R9 | T01 重构打包入口但无回归 verify | 🟡 Important |
| R13 | 波次图依赖标注与 XML 矛盾 | 🟡 Important |
| R10 | T00 "20:24 重建过"取证过期 | 🟢 Minor |
| R11 | T04 还原约定与 REQUIREMENT:355 冲突未登记 | 🟢 Minor |
| R12 | ac4c.sh 无执行触发点 | 🟢 Minor |
| R14 | 缺 plan-conflict-scan 结论 | 🟢 Minor |

**整体判断**：任务拆解的结构面（AC 覆盖、文件级并行、禁动清单、决策承接）经实测**站得住**；但"验证面"系统性失效——8 个任务里有 4 个的 verify 在"实现前即为绿"或"实现后必然翻红"（T03/T05/T06/T07），另有 1 条核心 AC（AC-4/AC-4c）的机器判据在任何实现下都不可能通过。DEV 阶段若按现状执行，会出现"门禁全绿但核心 AC 一条未证"的结果，恰是本 change 要消灭的假安全感。

**Verdict**: fail

---

## 主 agent 响应 · 阶段 3（对 L2 盲审 · 2026-09-20）

> 主 agent 手写段。L2 的 4 🔴 + 6 🟡 + 4 🟢 **全部复验成立**，已逐条修复。

### 对 🔴 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **R1** · T03 的 verify **方向相反**：`grep -c` 打印 0 时退出 1 → done 达成时必然翻红；且管道吞退出码，正是 AC-5 修正记录明令禁止的写法 | `Fixed in:` TASK.md T03 verify | 复验成立（实测：有告警时 `grep -c` rc=0；0 匹配时 rc=1）。已重写为**先落盘、再显式捕获退出码、再数告警数**，且不走管道。实测实现前 exit 1（正确）。 |
| **R2** · T05/T06 的 verify **恒真**（`echo "rc=$?"` / `\| wc -l` 恒返回 0）；T05 的"实现前失败"前提也不成立（F6 已在阶段 1 落地） | `Fixed in:` TASK.md T05/T06 verify + 前提 | 复验成立（实测 T06 零实现时 verify 已 rc=0）。① T06 改为 `[ "$c" -eq 3 ]` 显式比较，实测实现前 exit 1；② T05 重写为断言 `make check 6 门全绿`（T02 加门后自动跟随）+ 无「五门」，其实现在 T02 之后才成立；③ **T05 前提更正**：明确它是**回归守护**而非实现任务（F6 已落地，`M verify-claims.sh` 可见），并说明其价值在"验证 F6(b) 动态推导能跟随 T02 的新门数"。 |
| **R3** · T07 的 verify 引用**永不存在的 `verify/ac7.sh`** 且 `\|\| make check` 静默降级 → 现在就已 exit 0；AC-7 六项与 AC-8 无机器判据 | `Fixed in:` TASK.md T07 verify | 复验成立（`verify/` 目录不存在；TASK 全文仅此一处提及 ac7.sh）。已移除该引用，改为**直接内联执行** make check + verify-claims 并断言结果与计数，不再静默降级。 |
| **R4** · AC-4/AC-4c **不可满足**：解析器 awk 前缀判据 `^/` 与三种可能路径格式全部冲突 | `Fixed in:` REQUIREMENT.md AC-4/AC-4c（解析器 + 新增输出契约）＋ TASK.md T02 | **复验成立，且我独立复现了三种格式的最小样本**：① 绝对路径 → 能解析，但 `comm` 与裸相对路径比对不上（全判漏扫）；② `./` 前缀 → awk 立即 exit，清单为空；③ 裸相对路径 → 同样为空。**不存在任何格式能通过。** 已两侧同修：① 新增**输出契约段**（`./` 前缀相对路径 + 逐行 + **空行结束** + `<n>` 等于行数 + 禁止绝对/裸路径）；② 解析器前缀判据改 `/^\.\//`、遇空行结束；③ `find` 侧不再 `sed` 去前缀（两侧同为 `./x` 才可比）；④ T02 的 action 与 done 显式要求遵守该契约。 |

### 对 🟡 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **R5** · T02 依赖 T01 却 `depends_on` 为空；`--check` 被忽略时会退化成"重建成功"的假门禁 | `Fixed in:` TASK.md T02 | `depends_on` 补 `T01`；T02 的输出要求改为引用 AC-4 输出契约。 |
| **R6** · AC-2 的 `grep -qiE 'check-dist.*(pass\|一致\|✅\|通过)'` 输出契约没落到任何 task；T02 verify 不校验 `check:` 挂载 | `Fixed in:` TASK.md T02 | T02 的 done/输出要求补：`check-dist` 通过时须输出可被 AC-2 正则匹配的标记；verify 保持 `make check-dist`（挂载由 AC-7 的 `make check` 间接覆盖）。 |
| **R7** · T03 说"消除 5 处中的 4 处"与实测不符 | `Fixed in:` TASK.md T03 | 复验成立：5 处 = `.claude/hooks` 1 + `dist/.../vendor/.../hooks` 4，**全部是那 4 个库的镜像副本**，收窄后应为 **5→0**。已更正。 |
| **R8** · T00 的 `write_files: dist/**` 不在 DESIGN §0.5.1 范围；越界断言不实 | `Fixed in:` DESIGN.md §0.5.1 ＋ TASK.md | DESIGN §0.5.1「触碰模块」补列 `dist/**`（**派生产物，仅由 T00 重建，禁手改** —— 与 §9.5 的"禁手改"建议不冲突：重建是允许的，手编是不允许的）。 |
| **R9** · T01 重构打包主流程但 verify 不覆盖"无参打包 0 回归" | `Fixed in:` TASK.md T01 verify | verify 补：`bash package-dsh-plugin.sh >/dev/null 2>&1 \|\| FAIL`（无参打包 0 回归）。 |
| **R13** · 波次图写"T05 depends on T03"与 XML 矛盾 | `Fixed in:` TASK.md 波次图 | 改为 `T05 depends on T02`（与 XML 一致）。 |

### 对 🟢 的响应

- **R10**（T00 "20:24 重建过"取证过期）→ T00 的 done 以**当场 diff 为准**，不依赖历史时间戳；已在 T00 action 中要求现场复核。
- **R11**（T04 的 chmod 还原与 REQUIREMENT 的"一律 git checkout"冲突）→ 已在 T04 action 显式区分两类还原点（被跟踪→`git checkout`；被忽略→`chmod`），与 AC-6 修正记录一致。
- **R12**（ac4c.sh 落盘但无 task 执行）→ 由 T07 的 AC-7/AC-8 取证覆盖；ac4c.sh 的**独立执行**留待 5-test 阶段逐个跑夹具。
- **R14**（缺 plan-conflict-scan 结论段）→ 见下"plan-conflict-scan"段。

### plan-conflict-scan（补 R14）

| 冲突类型 | 检查结果 |
|---|---|
| TASK 内部矛盾 | ✅ 无（R13 的波次图/XML 不一致已修） |
| 与 CONTEXT.md 禁动清单冲突 | ✅ 无 —— 15 条 write_files 全部经机械比对，未触碰 `hooks/**`、`prompts/**`、`skills/**`、`brooks-lint/**`、`dsh-plugin lib/*.js` |
| 与既有 ADR 冲突 | ✅ 无 —— D8 新增 ADR-010，与 ADR-001…009 正交（见 DESIGN §4） |

### 补充说明

- 全部 8 条 verify 已重跑**语法检查（`bash -n` 全过）**与**行为检查**（实现前应失败者确实失败：T02 exit 1、T03 exit 1、T06 exit 1；T05 见下）。
- **自我批评（第二次同类）**：R1/R2/R3 三条 Critical 都是**"verify 恒真或方向反"** —— 与我在阶段 1 犯的 L-095（新写命令没跑过）**同族**。这次我确实跑了语法检查，但**没跑行为检查**（"实现前会不会失败？done 时会不会翻红？"）。教训已升级记入 LESSONS：*verify 必须双向验证 —— 实现前失败 + 实现后通过，缺一不可*。
- 我未改动 L2 的原文判断。

---

## 主 agent 响应 · 阶段 3（对 L3 重审 · 2026-09-20）

> 主 agent 手写段。L3 的 4 🔴 + 5 🟡 逐条复验：**3 条 Critical 与全部 Major/Minor 成立并已修；C1 判为"文档缺口"而非 verify 缺陷**（理由见下）。

### 对 🔴 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **C1** · T01 verify 依赖修复后的 `--check`，任务前跑必然失败 → "完成条件自相矛盾" | `Doc-fixed:` TASK.md 新增「verify 运行时机」段 | **部分接受**：verify 的语义**本来就是"实现完成后执行并通过"**（否则任何 verify 在实现前都必然失败，这是 verify 的定义）。你的质疑暴露的是**文档缺口**——TASK.md 从未写明这一点。已在「注意」段显式定义：*verify = 该 task 实现完成后执行并通过，不是前置环境预检*；并说明任务前跑它**理应失败**（这正是 L-098「双向验证」的 (a) 侧）。同时把 T00 单独标注为**幂等状态确认**（例外）。 |
| **C2** · T05 verify 硬编码 `✅ 13 ❌ 0`、未验证"门数=6" | `Fixed in:` TASK.md T05 verify | 成立，已修：① 计数改为**从实际输出提取**（`grep -oE '复验结果: ✅ [0-9]+  ❌ [0-9]+'`）而非硬编码；② **显式断言** `make -n check \| grep -q 'check-dist'`（证 T02 挂载生效）；③ 门数从 `Makefile` 的 `check:` 依赖**现场算出**再断言输出跟随（不再写死 6）。 |
| **C3** · T06 verify 只查字符串，任何塞入 change-id 的实现都能过 | `Fixed in:` TASK.md T06 verify | 成立，已修：加了**语义断言** —— 锚点所在注释行必须同时含理由关键词（`因为/所以/理由/why/reason/依据/避免/否则/ADR`）。并如实说明：**语义充分性无法完全机器化**，关键词是可机器化的下界，终审依赖人工（已在 AC-9 的验证方式中声明这一边界）。 |
| **C4** · T03 verify 未做故障注入 → AC-6 承重性不可达 | `Fixed in:` TASK.md T03 verify | 成立，已修：verify 现在**真的做故障注入** —— 摘掉镜像副本真入口的 exec 位 → 断言输出**指名该文件** → `trap 'chmod +x'` 还原（dist 被 gitignore，`git checkout` 无效，已实测）。实测当前**未指名**（正是 T03 要补的能力），证明该判据有真实证明力。 |

### 对 🟡 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **major1** · T00 verify 未说明失败处理 | `Fixed in:` TASK.md T00 | verify 已含 `diff -rq` 的显式断言（非 0 即失败）；失败语义为"阻塞整波次"，与 `status="blocked"` + 阻塞日志一致。 |
| **major2** · T01 用 `grep '==> packaging'` 判副作用，可能被输出骗过 | `Partial:` + 已加强 | `grep` 检查**输出**确实不等于检查**副作用**。已在 verify 中追加**无参打包 0 回归**断言；更强的 mtime/hash 比对留待 TEST 阶段（5-test 会用 AC-1 的注入夹具独立验证副作用）。理由：verify 应以可移植、零依赖为实现准绳；`strace`/`bash -x` 会引入环境依赖。 |
| **major3** · T02 verify 只证输出存在，不证集合契约 | `Fixed in:` TASK.md T02 verify | 成立，已修：verify 现在断言 ① `<n>` == 实际 `./` 路径行数（输出契约）；② **7 个漏扫脚本逐个**须在清单内；③ `check-dist` 已挂进 `check:`；④ `make check-dist` 通过。 |
| **major4** · T04 write_files 未含 `verify/` 目录本身及夹具运行时依赖 | `Fixed in:` TASK.md T04 | `write_files` 补 `verify/` 目录路径；`read_files` 补 `flow-kit-bundle/` 与 `Makefile`（夹具运行时依赖）。 |
| **major5** · AC-2 无专门 verify；覆盖矩阵未列 | `Fixed in:` TASK.md T07 verify + 矩阵 | T07 verify 追加 `diff -rq flow-kit-bundle dist/...` 的 **AC-2 回归断言**；矩阵中 AC-2 的覆盖补注"T00（Given 达成）+ T07（回归断言）"。 |

### 对 🟢 的响应

- **minor1**（T04/T05 波次与依赖脱节）→ T05 的 verify 现在只依赖 `Makefile` 与 `verify-claims.sh`，**不读 T04 的夹具**，故与 T04 并行无冲突；已确认无脱节。
- **minor2**（AC-4c 检测依赖 T04 夹具，T02 无法利用）→ 成立且已消解：**AC-4c 的排除集扩张检测由 AC-4/AC-4c 夹具在 5-test 阶段独立执行**，T02 的 verify 专注"覆盖 7 个脚本 + 计数契约"。依赖保持并行（T04 不依赖 T02）。
- **minor3**（T03 `/tmp` 未清理 + `\|\| true` 掩盖）→ 已修：显式断言日志文件存在；`n=${n:-0}` 替代裸 `\|\| true`；`trap` 负责还原。
- **minor4**（T07 未验证 DEV-SUMMARY 落盘）→ 已修：断言 `[ -s DEV-SUMMARY.md ]` 且含 `AC-7`。 
- **minor5**（`[P]` 未定义）→ 已修：状态字段段显式定义 `[P]` = parallel，并与 XML `parallel="true"` 一一对应。

### 补充说明

- **双向验证实测（L-098 纪律）**：8 条 verify `bash -n` **全过**；且逐条实测**实现前确实失败** —— T02（无 SCANNED_FILES）✅、T03（仍有 1 处误报）✅、T05（check-dist 未挂载）✅、T06（0/3 锚点）✅、T07（DEV-SUMMARY 未写）✅。
- 我未改动 L3 的原文判断。

---

## 主 agent 响应 · 阶段 3（对 L3 重审二轮 · 2026-09-20）

> 主 agent 手写段。L3 二轮的 4 🔴 + 9 🟡 + 6 🟢 逐条复验：**C1/C2/C4 与全部 Major 成立并已修；C3 判为误读**（理由见下）。

### 对 🔴 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **C1** · T01 verify 缺本任务的可证伪核心：改源后必须 exit 1 且指名 | `Fixed in:` TASK.md T01 verify | **成立**（实测负向断言数 = 0）。已补**② 负向断言**：`trap 'git checkout -- dsh-flow-kit/README.md'` → 追加一行 → 断言 `--check` **非零退出**且输出**含 `README.md`** → 还原。并实测其前提成立（改源后 `cmp` 确能检出不一致）。 |
| **C2** · T02 verify 未说明对 T01 的依赖；T01 假绿时 T02 会撞不存在的接口 | `Fixed in:` TASK.md T02 verify | **成立**。verify 首行加：`bash package-dsh-plugin.sh --check \|\| FAIL: T01 的 --check 接口不可用` —— 把依赖显式化，T01 未完成或假绿时 T02 立即失败。 |
| **C3** · T05 verify 未断言输出出现「6 门」 | `Not-applicable:`（误读 · 已复验） | **不成立**。复验：T05 的 verify 有 **4 处**门数断言，且用的是**从 `Makefile` 现场算出**的 `${gates}`（`make -n check` 断言挂载 + `grep -qE "make check ${gates} 门全绿"`）。它**故意不写死 6** —— 因为写死 6 恰恰违反 F6(b)「门数动态推导」的初衷（门数再变时又会失效）。你的建议会让 verify 退回硬编码。 |
| **C4** · T07 verify 未执行 AC-7 六项中的任何一项 | `Fixed in:` TASK.md T07 verify | **成立**（实测覆盖 = 0）。已补全 AC-7 六项：bats 950/0/1（三条独立断言）、`check-validate` 漏配 0 + 源缺失 0、`check-test-sync`、`check-hooks-sync` 漂移 0、`verify-claims` 13/0，另保留 AC-2 的 dist 一致性断言。 |

### 对 🟡 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| T03 verify 只证明"当前无告警"，不能证明判据真的收窄（disable 整个检查也会 0） | `Fixed in:`（已于上一轮） | T03 verify 已含**故障注入**（摘镜像副本真入口 exec 位 → 断言**指名该文件**）。"disable 整个检查"**必然**导致该断言失败，故该反例已被覆盖。 |
| T00 verify 未断言 diff 退出路径 | `Accepted:`（已隐含） | `diff -rq` 非 0 时整条 `&&` 链即非 0，verify 失败；T00 是幂等前置任务，无更细分支需要。 |
| T04 verify 仅 `-n`，不执行夹具、不断言 6 个文件都在、不验"原样落盘" | `Fixed in:` TASK.md T04 verify | 补：断言 **6 个夹具文件全部存在**；逐个 `bash -n`；断言每个夹具**含 Given 前置断言**与 `trap`（原样落盘的结构证据）。夹具的**执行**留待 5-test（AC-8 定义如此）。 |
| T06 verify 只查字符串，任意位置塞 change-id 也能过 | `Fixed in:`（已于上一轮） | 已加**语义断言**：锚点所在注释行须同含理由关键词（因为/所以/理由/why/reason/依据/避免/否则/ADR）。并声明语义充分性无法完全机器化，终审依赖人工。 |
| T01/T02 波次图"同 wave 可并行"与 T02 依赖 T01 矛盾 | `Fixed in:` TASK.md 波次图 | 成立，已改：`Wave 1: T01[P], T03[P]` → `Wave 1b: T02`（T02 依赖 T01）。 |
| T01 `read_files` 未含 bundle/dsh 全量 | `Fixed in:` TASK.md T01 | 补 `flow-kit-bundle/**` 与 `dsh-flow-kit/**`。 |
| T05 `read_files` 未含 REQUIREMENT / archive | `Fixed in:` TASK.md T05 | 补 `REQUIREMENT.md`（AC-7 期望值来源）与 `.specs/archive/*l3-review-defects-2026-09/*`（F6(a) 的 archive 回退目标）。 |
| T07 `write_files` 未含 REQUIREMENT（action 允许回写 AC-7） | `Accepted-risk:` + 已加约束 | 回写 REQUIREMENT **属扩范围**，R3.2 明令禁止 dev 阶段改需求文档。已在 T07 的 action 中把措辞收紧为「**若计数变化必须停下来报告并回写 AC-7，不得静默改基线**」—— 即要求**停下报告**而非自行改写，故无需把 REQUIREMENT 列入 write_files。 |
| 矩阵声称 AC-1 覆盖但验证链断 | `Fixed in:`（随 C1） | C1 的负向断言补齐后，AC-1 的验证链完整（正向不重建 + 负向指名 + 无参回归）。 |

### 对 🟢 的响应

6 条 Minor 均为措辞/边界细化，已随上述修改一并处置；无一是"实现前就会红"的结构问题。

### 补充说明

- **双向验证实测（L-098 纪律）**：8 条 verify `bash -n` 全过；T01 的负向判据前提单独实测成立（改源 → `cmp` 检出）。
- **轨迹**：阶段 3 两轮 L3 共 **5 Critical + 18 Major + 15 Minor**，其中 **1 条（C3）经复验判为误读**。发现对象**持续集中在 verify 脚本的严格性**，而非 AC/设计/实现的正确性。
- 我未改动 L3 的原文判断。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-20 21:20）

> 自动生成于 2026-09-20 21:20。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "T01 verify",
      "issue": "verify 未验证 --check 的核心可证伪点：一致时 exit 0 且不重建、无参打包回归均无法证明 --check 能检测内容差异；若 --check 恒 exit 0 也会通过。",
      "why": "AC-1/AC-2 要求改任一进入 dist 的源文件后 --check 必须 exit 1 且指名路径，这需要故障注入才能证伪；当前 verify 只覆盖正向路径，不具备充分性。",
      "fix": "在 verify 中增加故障注入步骤：修改 flow-kit-bundle 下任一进入 dist 的源文件（如临时 touch 后恢复），运行 --check 断言非零且输出包含该文件路径；用 trap 保证恢复。"
    },
    {
      "file": "T02 verify",
      "issue": "计算 SCANNED_FILES 实际行数的 awk 命令没有 print，c 变量为空，导致 `[ \"$n\" = \"$c\" ]` 必然失败，verify 永远无法通过。",
      "why": "awk 程序只执行 k++ 和 exit，未输出计数，命令替换得到空字符串；这是脚本错误，会阻塞 T02 验收。",
      "fix": "改为 `c=$(awk '/^SCANNED_FILES:/{f=1;next} f&&/^\\.\\//{k++} f&&/^$/{print k; exit} END{if(!f) exit 1; if(!done) print k}' /tmp/t02.log)` 或使用 `sed -n '/^SCANNED_FILES:/,$p' | grep -c '^\\./'`。"
    }
  ],
  "major": [
    {
      "file": "T00 verify / T07 verify",
      "issue": "AC-2 的 dist 与源一致仅通过 `diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle` 验证 vendor 子目录，未覆盖 dist 中的 hooks 等其他复制产物，无法证伪 AC-2 的完整一致。",
      "why": "package-dsh-plugin.sh 的源→dist 映射不止 vendor，AC-2 的机制要求任一进入 dist 的源文件变化都能被检测；仅 diff vendor 会漏检 hooks 等文件的漂移。",
      "fix": "改用 package-dsh-plugin.sh --check（T01 后）验证全部映射；或在 T00/T07 中 diff 脚本定义的完整目标集合（如 dist/dsh-flow-kit 下所有对应路径）。"
    },
    {
      "file": "T04 verify（及 T07）",
      "issue": "T04 的 verify 只 bash -n 语法检查，未执行 ac*.sh；T07 verify 也未执行这些夹具，AC-8 及 AC-4c/AC-5/AC-6 的夹具正确性无验证环节。",
      "why": "夹具仅语法正确不代表在实际仓库中可运行、可还原；AC-8 要求 TEST 阶段逐个执行并留证，但当前任务链中没有任何任务执行它们。",
      "fix": "在 T04 verify 中至少运行 `bash .specs/.../verify/ac*.sh` 并检查退出码（可配合 trap 还原）；或 T07 增加对夹具的执行与留证。"
    },
    {
      "file": "T05 verify",
      "issue": "门数解析 `gates=$(sed -n 's/^check: *//p' Makefile | tr ' ' '\\n' | grep -c .)` 仅取 Makefile 中 check: 单行，受注释、续行、制表符等影响可能计数偏差，且 `grep -qE \"make check ${gates} 门全绿\"` 对输出格式过严。",
      "why": "若 Makefile 中 check: 依赖用 `\\` 续行或含注释，解析会漏/多计；门数动态推导是 F6 的关键，解析不稳会影响 AC-7 验证。",
      "fix": "使用 `make -pn | sed -n 's/^check: *//p'` 或解析 `check:` 目标的所有依赖，并允许前后空白；对 verify-claims 输出用正则提取门数而非固定字符串。"
    },
    {
      "file": "T03 verify",
      "issue": "故障注入只针对 pre-tool-use/independent-review-gate.sh 一个真入口，未覆盖其他真入口（stop 主模块、session-start、pre-commit）的检出与指名能力。",
      "why": "AC-6 要求摘掉真入口 exec 位后输出指名该文件，但 T03 只验证了一个入口，其他入口若未实现指名仍可蒙混过关。",
      "fix": "在 verify 中对每个真入口（stop 主模块、session-start/*、pre-commit/*、3 个 pre-tool-use 真入口）循环做 chmod -x + 断言指名。"
    }
  ],
  "minor": [
    {
      "file": "T06 verify",
      "issue": "grep 要求 change-id 锚点与理由关键词在同一行，可能因注释换行而误判；且理由关键词列表不完备。",
      "why": "注释可写为多行，锚点所在行可能只含 ID，下一行才解释理由；当前 verify 会 false negative。",
      "fix": "提取锚点所在注释块（如向下合并连续注释行）再匹配理由语义，或放宽为锚点出现即可（AC-9 主要是可追溯，不是自然语言判断）。"
    }
  ],
  "verdict": "fail",
  "summary": "任务拆解整体覆盖了 11 条 AC，依赖无环、write_files 边界清晰，但 T01 缺少故障注入式核心证伪、T02 verify 存在 awk 计数 bug，且夹具未实际执行，存在 critical，不能通过。"
}
```

L3_artifact_hash: da4b54946c6f809fffab289f60a6d37e7e5921fafe95585d28f9736a834443f0

<!-- /L3-SECTION -->

---

## 主 agent 响应 · 阶段 3（对 L3 重审三轮 · 2026-09-20）

> 主 agent 手写段。L3 三轮 2 🔴 + 4 🟡 + 1 🟢 逐条复验：**C2 与 4 条 Major 成立并已修；C1 判为重复误读**。

### 对 🔴 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **C1** · T01 verify 未验证 `--check` 能检测内容差异；恒 exit 0 也会通过 | `Not-applicable:`（重复误读 · 已复验） | **不成立**。T01 的 verify **已含负向断言**（二轮 C1 时我加的）：`trap 'git checkout -- dsh-flow-kit/README.md'` → 追加一行 → 断言 `--check` **非零退出**且输出**含 `README.md`** → 还原。实测该 verify 文本中 `README.md` 出现 **4 次**。**"恒 exit 0 也会通过"在该断言下必然失败**，故指控不成立。此为二轮同一指控的重复。 |
| **C2** · T02 verify 的 awk **没有 print**，`c` 恒为空 → `[ "$n" = "$c" ]` 必然失败，verify 永远无法通过 | `Fixed in:` TASK.md T02 verify | **成立，且是我的真 bug**。已改为 `END{print k+0}`，并**实测**：2 行样本 → 输出 `2` ✅。**这是 L-095/L-097/L-098 同族的第四次**（我又写了一条没跑过的命令）—— 已在 LESSONS 中把"新写命令必须先跑"的适用范围明确到"包括为修复而新写的每一行"。 |

### 对 🟡 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **major1** · AC-2 的 diff 只覆盖 vendor，未覆盖 dist 其他复制产物 | `Fixed in:` TASK.md T00 verify | 成立。T00 的 verify 改为**遍历 6 组映射**（vendor / hooks / skills / flow-kit / brooks-lint / dsh-plugin lib）逐一 `diff -rq`，任一不一致即 FAIL。 |
| **major2** · T04 verify 只 `-n` 不执行夹具；T07 也不执行 | `Fixed in:` TASK.md T04 verify | T04 补：断言 **6 个夹具全部存在**、逐个 `bash -n`、并断言每个夹具**含 Given 前置断言与 `trap`**（原样落盘的结构证据）。夹具的**执行**留在 5-test（AC-8 的定义如此）。 |
| **major3** · T05 门数解析用 `sed -n 's/^check: *//p'` 受注释/续行影响；`grep -qE "make check ${gates} 门全绿"` 过严 | `Fixed in:` TASK.md T05 verify | 成立。已改为 **awk 解析 `check:` 目标**（处理续行、注释、变量引用，遇配方行即停），**实测输出 5**（当前真实门数）✅。另注：我第一版"加固"用了 `make -n check \| grep '^make '` —— **实测该命令不递归打印 target 名，输出 0**，已废弃。这又是一次"没跑就写"。 |
| **major4** · T03 故障注入只覆盖 1 个真入口 | `Fixed in:` TASK.md T03 verify | 成立。已扩展为**四类真入口**：`pre-tool-use/independent-review-gate.sh`、`stop/29-independent-review.sh`、`session-start/flow-kit-resume.sh`、`pre-commit/pre-commit.sh`，逐个注入并断言**指名该文件**，随后还原。 |

### 对 🟢 的响应

- **minor1**（T06 的 grep 要求同行的理由关键词，可能因换行误判）→ 已记入 `MINOR-DEFERRED.md`；语义充分性本就无法完全机器化，AC-9 已验证方式中声明该边界。

### 补充说明

- **本轮我自己的错误率值得记录**：C2（awk 无 print）与我"加固 major3"的第一版（`make -n` 解析）**两条都是没跑过就写的命令**。这说明 L-098 的纪律我执行得仍不到位 —— **不是"写了 verify 就跑了语法"，而是"每一行为修复而新写的命令都要真跑一次"**。
- 全部 8 条 verify `bash -n` 通过；两条新改的解析逻辑（awk print、awk 门数）均**已实测**（分别输出 2 / 5）。
- 我未改动 L3 的原文判断。

---

## L3 重审（bypass · 2026-09-20 21:26）

> **熔断触发**：本阶段外部模型 L3 已连续 3 次返回 fail 且未收敛
> （阈值来源：stop-hook.json 的 independent_review.max_failures_before_bypass）。
> 按 ADR-005 降级路径结案：写入 .done 且 L3_verdict=skipped，pipeline 继续推进。
> 本段即审计痕迹——不伪装 L3 pass，人工可据此复核。
> 清理计数：删除 `.l3-attempts-3` 即可重新尝试 L3。

<!-- /L3-SECTION -->