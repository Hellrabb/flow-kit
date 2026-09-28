# INDEPENDENT-REVIEW-6: health-fix-2026-09b（阶段 6）

---

## Cross-Model Spot-Check

模型: qwen3.8-flash

**独立性声明**：本段由跨模型盲审第 2 轮子 agent 产出。仅读取调用方指定的工件（REVIEW.md / REQUIREMENT.md / TEST.md / TASK.md / 生产件源码与 git diff），未接收主 agent 会话上下文。审查期间被 PreToolUse 守卫拦截两次（命令串含 `git commit` 字面 / `.done` 路径字面），属环境噪声而非上下文注入——未发现主 agent 推理内容泄漏进本会话的证据。**独立性：完好。**

### 1. 对主 review 两条 🔴 的独立判定

#### 🔴 F1 —— **成立**（独立复现，非引用主 agent 结果）

**Severity**: 🔴 Critical（同意主 agent 定级）
**Symptom**: `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:75-77` + `:339`（4× `TMP_X=$(mktemp)` 不校验 rc）+ `:205` · `:208`（候选枚举重定向失败不查）+ `:285` · `:309`（检索 `|| true` + `2>/dev/null`）+ `:198` · `:336`（`|| =0` 把读失败与 0 条合并）。注：主 REVIEW 引 `:79-81`，实测 mktemp 在 `:75-77`（off-by-4，实质不受影响）。
**Source**: 《The Pragmatic Programmer》Crash Early；《Domain-Driven Design》Ubiquitous Language（「通过」语义被实现掏空）。
**Consequence**: 工具故障静默折算成「0 命中 ⇒ ✅」，pre-commit / pre-push / make check 三个 caller 均只看 rc、无人读 stderr ⇒ 隐私门禁整体可被一个环境变量旁路。与本 change 立项动机（AC-7 消灭假绿）同族自伤。

**独立复现（本人亲跑）**：

```bash
FX=$(mktemp -d); R=$FX/repoA; mkdir -p "$R/flow-kit-bundle/flow-kit/reference"
cp <repo>/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh "$R/flow-kit-bundle/flow-kit/reference/"
cp <repo>/flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt "$R/flow-kit-bundle/flow-kit/reference/"
cd "$R" && git init -q
printf 'probe: /home/''zz-p6-pro''be/x\n' > leak.txt && git add leak.txt
bash ./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh >/dev/null 2>&1; echo "rc_normal=$?"     # → 1
TMPDIR=$FX/nope bash ./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh >/dev/null 2>&1; echo "rc_bad=$?"  # → 0
```

实测输出：`rc_normal=1`；`rc_bad_tmpdir=0`，stdout 末三行 = 「命中合计 0 条（含占位符排除后）／清单外命中 0 条／✅ 清单外命中 0 条…」，stderr 含 4 条 `mktemp: 无法通过模板 "…/nope/tmp.XXXXXXXXXX" 创建文件` + `cp: 无法创建普通文件 ''`。**该结论在 8+ 次重复运行中逐字节稳定。** 判别式控制（态 D）同仓同清单只差探针在不在 index：有 ⇒ rc=1、无 ⇒ rc=0，证明 rc=0 不是恒真而是被环境翻转。
**Remedy**: 采纳主 agent 方案（每个 mktemp / 枚举 / 检索断言 rc，失败走独立出口码），另加：**`:105-111` 的两处 `cp -- … "$TMP_ALLOWLIST"` 同样不校验 rc**（坏 TMPDIR 下 cp 目标为空串直接失败，是链路第一环）——修复时一并覆盖。

#### 🔴 F2 —— **成立**（独立复现，并发现一条同根变体）

**Severity**: 🔴 Critical（同意定级）
**Symptom**: `check-path-privacy.sh:203-209`（候选集从未断言非空）+ `:369-374`（自证五行无「候选文件 N 个」）+ `:380-392`（0 命中 ⇒ exit 0）。
**Source**: 《A Philosophy of Software Design》Ch4 Shallow Module（接口不暴露"看了多少"）。
**Consequence**: 「零扫描面」与「全部干净」同形不可区分。独立复现（非 git 目录）：脚本 + 常设清单 + 含真泄漏的 `leak.txt` 齐备、无 `.git` ⇒ **rc=0 + 「命中合计 0 条 ✅」且 stderr 全空**（连报错线索都没有——`git ls-files` 的错误也被 `2>/dev/null` 吞了）。任何解包分发件目录 / 损坏 index / 空 rev 都把门禁降级为恒绿装饰。

**遗漏变体（同一缺陷类，主 review 未列）**：**git 仓但 index 为空**（如 `git init` 之后、首次 `git add` 之前，或浅克隆异常态）+ 工作树含真泄漏 ⇒ 实测 **rc=0 + 「命中合计 0 条 ✅」**（`git ls-files` rc=0 但输出 0 行，F1 的 rc 检查抓不到它，只有 F2 的候选数断言能抓）。复现：

```bash
E=$(mktemp -d)/emptyidx; mkdir -p "$E/flow-kit-bundle/flow-kit/reference"; cd "$E"
cp <repo>/flow-kit-bundle/flow-kit/reference/{check-path-privacy.sh,path-privacy-allowlist.txt} flow-kit-bundle/flow-kit/reference/
git init -q; printf 'probe: /home/''zz-p6-pro''be/x\n' > leak.txt   # untracked
bash ./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh; echo "rc=$?"   # → ✅ + rc=0
```

⇒ Remedy 采纳主 agent 方案（自证行加候选数、N=0 fail-closed），**双态用例须同时覆盖「非 git 目录」与「git 仓 0 tracked」两型**。

### 2. 对 🟡 抽查（独立验证，一致处亦为独立得出）

- **F3（二进制双态）— 成立，已独立复现**：tracked `bin.dat` 内嵌探针（含 `\0`）⇒ 工作树模式 **rc=0 / 命中 0 条**（grep 的 binary-matches 提示走 stderr 被吞）；rev 模式（`CHECK_REV=<sha>`）**rc=1** 且归因行为垃圾三元组 `Binary file <sha>:bin.dat matches: bin.dat matches`——`file` 字段含空格与冒号，白名单永远豁免不了，两模式结论相反。REVIEW `:41` 的引文形态与实测逐字吻合。🟡 定级合理（当前分发面无含 PAT 二进制）。
- **F4 — 成立**：`:146`（校验器认 `<!--` 为注释跳过）vs `:198`（计数只认 `#`）口径分裂属实。补充一点：畸形条目行会被 `validate_allowlist_format` 拦下（`:183-186` fail-closed），所以 F4 的现实危害收窄为「`<!--` 行计入 ALLOWLIST_COUNT 使自证虚高」，与 REVIEW 表述一致。
- **F5 — 成立**：`:339-340` 第二个 EXIT trap 覆盖 `:73` 的 `trap cleanup EXIT`，`cleanup()`（`:68-72`）自此为死代码。两处临时文件清单无双份同步机制，属 R3。
- **F6 — 部分复核**：源码核实 `check-gate-sync.sh:59-68` 缺文件 ⇒ WARNING + 裸 `return`（`ERRORS` 不增）、`:205-209` 汇总按 ERRORS 判 ✅/rc=0，机制成立；未在沙箱重建夹具实证（前轮实验受守卫拦截预算限制），采信代码走查 + 主 agent 的沙箱回执。
- **F7 — 成立**：`:209` 字面「非全量 14 对全绿」不随 `PAIRS_TOTAL` 插值；`:206` 补救文案仍说「toll-gate 协议段」而 v1 已是全文比对。
- **F8 — 抽查一致**：`Makefile:106` 挂 wrapper、两份 NFR 正文并存的结构属实（76/77 逐字重复为主 agent python 比对结论，本次未重跑）。

### 3. 主 review 遗漏项

### 🟢 S1 · R2 Change Propagation：`SELF_EXCLUDE` 精确路径豁免在归档/复制场景下双向失真

**Severity**: 🟢 Minor
**Symptom**: `check-path-privacy.sh:47-53`（豁免面 = 5 条精确路径）+ `:228-235`（`is_self_exclude` 逐条 `[ = ]` 比较）。实测副产品：把脚本裸拷贝到仓根跑夹具时，拷贝件 `:23` 的注释立即被判红（假红）；反向地，`.specs/archive/<date>-health-fix-2026-09b/` 归档后豁免路径失配 ⇒ 冻结审查档若含历史真实路径形态会重新炸红，而 change 目录改名/复制即可让任意旧审查档脱离豁免（既可能误红也可能诱导把敏感件挪出豁免面再 de-shape）。
**Source**: 《Refactoring》3.2（豁免知识散落：TASK.md:537 的时间切点规则与脚本清单是同一决定的两处表达）。
**Consequence**: 门禁行为依赖文件的物理位置而非身份；归档动作（阶段 7 必做）即触发改判。当前无现实泄漏，故 Minor。
**Remedy**: 归档时把审查档路径追加进 SELF_EXCLUDE（脚本注释已要求「新增审查档显式追加」但未涵盖归档改名）；v2 用文件名后缀匹配（如 `*INDEPENDENT-REVIEW-[0-9]*.md`，仍禁宽通配吞产品件）。

### 🟢 S2 · 文档事实错误：REVIEW §A AC-6 行声称的 bats 例数与实际不符

**Severity**: 🟢 Minor
**Symptom**: `REVIEW.md:54` 称 `test/test_path_privacy_gate.bats`「10 例」；实测 `grep -c '@test'` = **9**（`:59/:71/:84/:96/:107/:120/:131/:142/:153`）。
**Source**: 审查工件自身的可复算性要求（本 change 的核心主题就是"自证数字必须真"）。
**Consequence**: 引用 REVIEW 做 fix loop 验收的人按 10 例核对会找不到第 10 例；不影响 verdict。
**Remedy**: T-FIX-03 补双态用例后更新为实际例数（届时恰好 ≥10，顺手改口径）。

### 🟢 S3 · 术语溯源：AC-9 出自流程 prompt，不在本 change 的 REQUIREMENT 里

**Severity**: 🟢 Minor
**Symptom**: `flow-kit-bundle/flow-kit/prompts/6-review.md:29`「动态门禁判定（AC-9）」；`REQUIREMENT.md` 实测 `grep -c 'AC-9'` = 0。REVIEW.md:8/:58 把它当 spec 条目引用。
**Source**: L2-blind-review checklist（spec 合规须对得上规格出处）。
**Consequence**: 无实质影响（流程 toll-gate 本就是判定权威），但严格说「AC-9 未通过」应表述为「6-review toll-gate ⑤ 未通过」。
**Remedy**: 后续 REVIEW 模板给 AC-9 标注「(prompts/6-review.md §动态门禁判定)」。

### 4. 其余核验（简）

- reviewed revision：HEAD=`7dd4bd7`，与 REVIEW 声称一致。
- 接线三处实核：`Makefile:106`（check: 含 check-path-privacy）、`flow-kit-bundle/hooks/pre-commit/pre-commit.sh:32-33`、`pre-push/pre-push.sh:48`（`CHECK_REV="$local_sha"`）——均只消费 rc ⇒ F1/F2 的 consequence 链成立。
- fail-closed 正面子系统我独立验证通过：两清单皆缺 ⇒ rc=1 指名双路径 ✅；rev 不可解析 ⇒ exit 1 ✅；允许清单畸形行 ⇒ exit 1 ✅。说明作者有 fail-closed 意识，缺口恰在「机械故障」这一维——与 F1 定性吻合，不构成降级理由。
- 脱敏自查：本段所有路径示例使用 `/home/<acct>/` 形态；探针以拼接构造，写入后不含可被自家 PAT 命中的连续字面。

### 5. Verdict

**Verdict**: fail

与主 review 一致：F1、F2 两条 🔴 经独立复现成立（含一条同根新变体「git 仓 0 tracked」），verdict=fail 恰当；T-FIX-03 的修复判据建议吸收上文三条增量（cp rc 校验、双型 0 候选用例、归档豁免面说明）。未发现需要推翻主 review 的误判；未发现第三条独立的 🔴（S1-S3 均不足 Critical 门槛）。

---

## 主 agent 响应（阶段 6 · 跨模型 spot-check · 2026-09-24）

**结论采纳**：第 2 轮 verdict = `fail` 与本轮（主 review）一致，F1/F2 两条 🔴 经独立夹具复现成立 ⇒ **不降级**（ADR-014 / R2.5：降级须人工确认接受风险；用户裁决 = option 1「回退 4-dev 执行 T-FIX-03/04/05」）。

| spot-check 项 | 处置 | 落点 |
|---|---|---|
| ① F1 行号勘误（`mktemp` 实测 `:75-77`，主 review 原引 `:79-81`） | **已订正**（就地标注 off-by-4） | `REVIEW.md` §B F1 `**Symptom**` |
| ② `:105-111` 两处 `cp --` 不校验 rc ＝ 坏 `TMPDIR` 链路**第一环** | **已并入判据** | `TASK.md` T-FIX-03 `<read_files>` 行号 + `<action>` ① + `<done>` |
| ③ F2 同根新变体「git 仓但 index 为空（未 `add`）+ 工作树真泄漏 ⇒ rc=0」 | **已并入判据**（`<verify>` 新增 E2 组，与 E 组并列） | `TASK.md` T-FIX-03 `<action>` ② + `<verify>` E2 + `<done>` |
| S1 `SELF_EXCLUDE` 精确路径豁免在归档/复制场景双向失真 | 记 🟢（涉归档期路径策略，交阶段 7 triage） | `MINOR-DEFERRED.md` 阶段 6 表第 10 行 |
| S2 `REVIEW.md:54` 称 bats「10 例」，实测应为 **9 例** | **已订正**（`grep -c '^@test' test/test_path_privacy_gate.bats` = 9） | `REVIEW.md` §A AC-6 行 |
| S3 「AC-9」术语出自 `flow-kit-bundle/flow-kit/prompts/6-review.md:29`，本 change `REQUIREMENT.md` 无该编号 | **已注明出处** | `REVIEW.md` §0.4 表 + §E |

**未采纳项**：无 —— 三条增量全部吸收进 T-FIX-03 的判据（修复面因此扩大：`cp` 断言 + 双型 0 候选用例）。

**处置入口与状态**：`TASK.md` T-FIX-03（🔴 F1/F2 + 🟡 F3/F4/F5）→ T-FIX-04（🟡 F6/F7）→ T-FIX-05（🟡 F8）；`.flow-active` 已回退 `current_phase="4"`（`phases_done=["0","1","2","3"]`、`gates["5→6"]` 复位 `pending`、`.goal.rollback` 留痕），修完重跑 5-test 与 6-review。

---

## Cross-Model Spot-Check（第 3 轮 · 2026-09-25 · qwen3.8-flash）

> 注（主 agent · 2026-09-25）：本段中 spot-check 自建夹具内的**合成探针账号路径**已按 L-129 去形为 `/home/<acct>/`、`/home/<acct-2>/`（原 `zzacct` / `zzspace`），仅为通过本仓隐私门禁；文字、判定与结论未作任何改动。

**独立性声明**：本段由第 3 轮跨模型盲审子 agent 产出。仅按任务书读取被测脚本与 git 状态，所有夹具自建自跑（`/tmp/spot3/`），未采信主审查员结论——H1/H2/H3/I1 均作为待验假设独立复现。**独立性：完好。**

### 复核环境

- GNU bash 5.2.21(1)-release x86_64-pc-linux-gnu · ShellCheck version: 0.9.0 · git version 2.43.0 · LANG=zh_CN.UTF-8
- 被测件：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（HEAD `7b624dc`，只读）；Makefile 接线 `Makefile:125-127`（`@bash …check-path-privacy.sh`，无 `-c` 覆盖 ⇒ 继承仓库 config）
- 夹具目录：`/tmp/spot3/final1`（H1 工作树·干净室）、`/tmp/spot3/h1c`（H1 rev 模式）、`/tmp/spot3/h1e`+`h1f`（含 `"` 文件名类）、`/tmp/spot3/h2b`+`rev2`+`rev3`（H2）、`/tmp/spot3/h3b`（H3）、`/tmp/spot3/i1f`+`i1g`（I1）。每个夹具自带合法空清单 `.specs/health-fix-2026-09b/path-privacy-allowlist.txt`（内容 `# 空清单`）。探针全部用拼接构造（`'/home/''zzacct'''` 等合成账号，非真实家目录）。

### 逐条判定

- **H1: confirm · 🔴 Critical（同意定级）** · 证据：`check-path-privacy.sh:302`（`git ls-files -- > "$TMP_CANDIDATES"`，无 `-z`）⇒ 默认 `core.quotePath=true` 下非 ASCII 路径输出 C 引号串 `"用户泄漏.md"` → `:450 [ -f "$file" ] || return 0` 判 MISSING 静默跳过，而 `:490 SCANNED_COUNT=$((SCANNED_COUNT + 1))` 在 `scan_file` 调用**之前**已计数。实测（final1：`用户泄漏.md` 工作树+index blob 均含 `/home/<acct>/x`，quotePath unset）：门禁打印「候选文件 4 / 实际扫描 2 / 命中合计 0 / ✅」**RC=0**（假绿）；同夹具 `git config core.quotePath false` 后 ⇒「命中合计 1 / 清单外命中 1」归因 `用户泄漏.md:2: /home/<acct>/x` **RC=1**。本仓读数：`git ls-files | grep -c '"'` 在 quotePath=true 下 = **5**（FLOW-KIT-用户指南.md、flow-kit-bundle/FLOW-KIT-用户指南.md、flow-kit-技术设计.pptx、flow-kit-用户指南.pptx、中 文名.md），5 者 `[ -f ]` 全 MISSING；门禁自证「候选文件 1596 / 实际扫描 1590」差额恰等于 SELF_EXCLUDE 条目数 6 —— 但其中 5 个引号路径同样被计入 M 却在 :450 跳过 ⇒ **M 虚高 5**（真扫 1585）。当前这 5 个真实文件内容 `grep -anoE '/home/[a-z_]…/'` = 0 命中 ⇒ 今日无实漏，机制常开。理由：隐私门禁对一整类文件名永久失明且自证行说谎，属 AC-7 消灭假绿的同族自伤。
- **H2: confirm · 🔴 Critical（同意定级）** · 证据：候选集来自 index（`:302 git ls-files` 只给名字），内容却读磁盘（`:455 raw=$(grep -naE "$PAT" "$file")`）。实测（h2b）：`notes.txt` 以 `secret /home/<acct>/keys/id` `git add` 后工作树改回干净不再 add（`git status` AM；`git show :notes.txt` 第 2 行确认 blob 仍含探针）⇒ 门禁「候选文件 3 / 实际扫描 1 / 命中合计 0 / ✅」**RC=0**，此后任何 commit 都会把 index 里的泄漏写进历史。反向对照：同仓提交后 `CHECK_REV=<rev>` ⇒「命中合计 1 / 清单外命中 1」归因 `notes.txt:2: secret /home/<acct>/x` **RC=1**（rev 模式经 `:414 git grep` 读 blob，正确）。rev3 差分（同仓两态只差磁盘脏净）：worktree RC=0 vs CHECK_REV RC=1。理由：pre-commit caller 的主路径（add→改→commit）恰好落在盲区，门禁可被一次 revert 旁路。
- **H3: confirm · 🔴 Critical（同意定级，方向为假红）** · 证据：校验器 `:234 core=${core#"${core%%[![:space:]]*}"}   # 去前导空白` ⇒ 缩进条目通过格式校验并被 `:284 ALLOWLIST_COUNT` 计入；键提取 `:519-521`（`sed -E 's/[[:space:]]*#.*$//' | sed -E 's/[[:space:]]*$//'`）**不剥前导空白** ⇒ 键停留在 `'    data.txt:2'`，`:527 grep -qxF "$key"` 精确匹配必失败。实测（h3b，data.txt:2 有泄漏）：清单 `data.txt:2 # 理由`（无缩进）⇒「允许清单 1 条 / 清单外命中 0 / ✅」RC=0；同一行加 4 空格缩进 ⇒「允许清单 1 条」（校验器接受！）但「清单外命中 1」RC=1。机制直证：同款 sed 管道输出 `od -c` = `    d a t a . t x t : 2 \n`，`grep -qxF 'data.txt:2'` ⇒ NO MATCH。理由：校验器与匹配器两套空白口径互斥 ⇒「合法却永不生效」的条目造成不可解释的永久红；fail-closed 方向但仍属缺陷（用户在两处都被告知合规）。
- **I1: confirm · 🟡（侧证，同意不定 🔴）** · 证据：`:142 TMP_FILES="$TMP_ALLOWLIST $TMP_CANDIDATES $TMP_HITS"`（`:517` 追加第 4 个）+ `cleanup() :110-115 for f in $TMP_FILES; do rm -f "$f"; done` 未加引号 ⇒ `TMPDIR='/tmp/spot3/i1f/space dir'` 下每个含空格路径被词分裂成两个残缺 token，rm 全部落空。实测：rc=0 与 rc=1 两种运行后均残留 **4 个临时文件**；关键在 rc=1 场景（i1g）残留 `tmp.ZG0Q94BCWF` 内含 `notes.txt:2:secret /home/<acct>/keys/id` ⇒ **命中缓冲（file:line:content）落盘不清**。定级 🟡：卫生/泄漏持久化问题，不产生假绿假红，但与本 change 的隐私主题直接相悖（残留物本身就是命中归因内容）。

### 反向核验结果（防误报）

1. **SELF_EXCLUDE 是否吸收引号路径？** 否。`:344-351 is_self_exclude()` 是 `"$path" = "$se"` 精确比较，C 引号串 ≠ 任何清单条目 ⇒ 不走豁免、走 :450 跳过 ⇒ H1 无法被现有代码覆盖。
2. **`-z` 形态是否存在？** git 支持：`git ls-files -z` 输出原始字节（od 验证：裸 utf-8 + `\0` 分隔，无引号）⇒ 修复可行；但脚本 `:294`/`:302` 均未用 `-z`，且 `:487 while IFS= read -r f` 按行读取 ⇒ 修复需同时改枚举与循环（NUL 处理），非单点。
3. **H3 是否只在非法格式下触发？** 否——恰恰相反：触发条件是**校验器认可的合法条目**（缩进 + `file:line` + `# 理由`）。非法格式（如缺冒号）会在 `:236-260` 直接 🔴 格式违例退出，不进入本缺陷路径。
4. **quotePath=false 能否完全关闭 H1？** 不能。名字含字面 `"` 或 `\` 的路径（如 `we"ird.txt`）git **永远** C 引号化（即使 `core.quotePath=false`，实测 `git ls-files` 仍输出 `"we\"ird.txt"` ⇒ `[ -f ]` MISSING）⇒ 该类泄漏在工作树与 rev 两种模式下、两种配置下均漏检。本仓现存 4 个中文名文件不含 PAT 命中，`中 文名.md` 为早前探针残留（见新发现④）。

### 新发现（我方假设之外）

- **① rev 模式（CHECK_REV / pre-push 路径）同样假绿于非 ASCII 文件名**：`:294 git ls-tree -r --name-only` 同样输出 C 引号串 ⇒ `:414 git grep -nEa "$PAT" "$REV" -- '"\347…"'` 拿引号串当 pathspec ⇒ 零匹配 rc=1 ⇒ `:421 [ "$ggrc" -ne 0 ] && [ -z "$raw" ] && return 0` 静默跳过。实测 h1c（`用户泄漏.md` 已提交，rev `e9bbd73`）：`CHECK_REV=$REV` 默认配置 ⇒「命中合计 0 / ✅」RC=0；同 rev `git grep` 不带 pathspec ⇒ 能命中（`REV:"\347…":2:/home/<acct>/x`）；仓库设 quotePath=false 后同命令 ⇒ RC=1 正确归因。**即 H1 不止击穿 pre-commit，也击穿 pre-push**，且 rev 模式连 :450 都不经过（跳过分叉点在 :421）。修复应统一为 NUL 安全枚举（`ls-tree -z`/`ls-files -z` + `read -d ''`）。
- **② SCANNED_COUNT 语义失真**：`:490` 在 `scan_file` 前递增 ⇒ 凡 :450（文件缺失）跳过的路径照样计入「实际扫描 M 个」。与 SELF_EXCLUDE 差额巧合叠加后，自证行无法区分「豁免了多少」与「漏扫了多少」——本仓 1596−1590=6 表面吻合豁免表大小，实际真扫 1585。建议 M 改为 scan_file 内部成功读取后才计数，或另列「跳过 K 个（原因）」。
- **③ rev 模式对磁盘态免疫（正向确认）**：rev2 夹具中泄漏已提交、随后从磁盘删除 ⇒ `CHECK_REV` 仍 RC=1（git grep 读 blob）。说明 rev 模式唯一缺口就是①的路径引号，不存在 H2 型磁盘/content 错位——修复时勿把 worktree 模式改成「读 index blob」了事，两条模式的正确性来源不同。
- **④ 主仓观察（非脚本缺陷）**：`.git/config` 现有 `core.quotePath=false`（今日 ~12:47 写入，疑早前调试所设；本人每次 true→读数→恢复 false）。工作区/index 存在探针残留 `中 文名.md`（A 状态，第 2 行 `/home/<acct-2>/b`）：quotePath=true 下门禁 ✅ RC=0（被①类跳过吞掉），false 下 🔴 RC=1。另有 MINOR-DEFERRED.md / REVIEW.md / path-privacy-allowlist.txt 的并发暂存改动（主 agent 工作，未触碰）。建议清残留意象并评估 quotePath=false 是否入库固化（它掩盖而非修复 H1 的 utf-8 半区）。

**Verdict**: fail — 三条 🔴（H1/H2/H3）全部独立复现成立且维持 🔴 定级，I1 侧证成立维持 🟡；另将 H1 的影响面从 pre-commit 扩展到 pre-push/CHECK_REV 路径（新发现①），修复判据应包含 NUL 安全枚举与 SCANNED_COUNT 语义两点。

## Cross-Model Spot-Check（第 5 轮 · 2026-09-27 · qwen3.8-flash）

**触发**：`6-review.md:297-308` ADR-014 —— 第 5 轮 `verdict=fail` + 3 🔴（`R5-6`/`R5-7`/`R5-18`）⇒ 派不同模型盲审第 2 轮。
**执行者**：agent `8dd172a1-aef0-48dc-ade7-66909f671c8e` · provider `qwen-token-plan-cn` / model `qwen3.8-flash` · 只读（探针全在 `/tmp/spot6/`）· 被审工件 = `<repo>`（L-129 脱敏）HEAD `1b5a9c39a3064ce329c10b381a82123594aad792` + change `.specs/health-fix-2026-09b/`。
**任务面**：独立复核 `R5-6`/`R5-7` 是否成立与严重度是否恰当 + 自由猎取 2–3 条 AC 的同类缺口。
**Verdict**：**fail** —— 🔴 **2** · 🟡 **1** · 🟢 **1**（两条 🔴 均为对 `R5-6`/`R5-7` 的**独立确认**并补变异证据；🟡/🟢 为新增）。

### F1（= `R5-6` 确认成立）· 🔴 Critical · AC-2 缺 jq ⇒ 既有 settings.json 不被破坏

- **Symptom**：`TEST.md:55` 声称 AC-2 有「✅ 常设 bats（`test_install_coverage.bats` / `test_install_dry_run.bats`）」且「缺 jq 分支：目标配置字节不变 + fail-closed」——两文件合计 21 个 `@test`，**从未隐藏 jq、从未断言缺 jq 路径**。
- **Source**：声明侧 `TEST.md:55`；实现侧 `flow-kit-bundle/lib/install_hooks.sh:189-192`（入口守卫）+ `:356-359`（合并分支二道守卫）。
- **实跑证据**：`grep -rn "permissions" test/*.bats` → **0 命中**；`grep -rln "settings\.json" test/*.bats` → 仅 `test_install_dry_run.bats`（4 例全在 `DRY_RUN=true` 下，与缺 jq 无关）；`grep -rn '缺少依赖 jq|jq 不可用' test/*.bats` → install_hooks 相关 **0 命中**；`test_install.bats` 的 `run_install` 恒带 `--dry-run` ⇒ 亦不覆盖。
- **变异实证**（`/tmp/spot6/f1mutB` = 两道守卫全文删除；影子 PATH 验证 NOJQ；沙箱 HOME + `USER_SETTINGS_FILE` 钉住）：**REAL** rc=1 · size 120→120 · `❌ 缺少依赖 jq…已中止（尚未做任何写盘）`；**MUTANT-B** rc=**0** · size 120→120 但 4×`⚠️ …合并失败，请手动检查` ⇒ 守卫被删后当前代码形态是**静默安装失败（rc=0 谎报成功）**而非截断。原始 PC2 截断（122B→0B）需旧代码 create-branch `>` 重定向形态，**未能从现件复现** ⇒ 数据丢失复发条件比转述更苛刻，但「装了个寂寞仍报成功」同样击穿 AC-2 产品语义。
- **缓解事实（如实记录）**：`install.sh:125-136 check_jq()` 在 `:168-170` 硬前置（非 update 且非 `--no-hooks`）⇒ 出货 CLI 路径已有第一道防线；残余暴露 = 直接 `source` 库调用者（恰是常设 bats 的使用模式）。
- **严重度依据**：按 `flow-kit-bundle/flow-kit/prompts/6-review.md:289-296`（🔴 阻塞 toll-gate）+ `CHANGE.md:161-171` 的 TD-053 先例（生产件判定力只由 change 期判据承载 + 报告登记成 ✅ ⇒ 与 pass 不可并存）⇒ **维持 🔴，不降级**。
- **Remedy 建议**：固化 T06 为常设 bats —— 影子 PATH 排除 jq + 直调 `install_hooks`（及全 CLI `--global --no-brooks --user` 双形态）+ 断言 rc≠0 + `cmp -s` 前后一致 + `permissions.allow` 存活；并在用例内 grep 钉住守卫文本，防「静默 rc=0」变异形态。

### F2（= `R5-7` 确认成立）· 🔴 Critical · AC-3 泄漏 ref 拦截无常设行为级测试

- **Symptom**：`TEST.md:56` 声称 AC-3 由 `test_archive_commit_gate.bats`（45 例）覆盖，但该文件对 `flow-kit-bundle/hooks/pre-push/pre-push.sh` **只做 `bash -n`（`:183-186`）+ 静态 `grep -q`（`:188-212`、`:264-278`），从不以 stdin 执行 hook**。
- **Source**：同上 bats；实现 = `pre-push.sh` 185 行（畸形 stdin fail-closed `:139-142` · 泄漏分支拒绝 `:167-171` · 缺清单 `exit 2` `:107-108`）。
- **实跑证据（变异证伪网失效）**：`grep -rn "pre-push\.sh" test/*.bats` 全部命中集中于 `bash -n`/静态 grep；`grep -rn 'run bash.*pre-push' test/*.bats` 仅命中 `bash -n` 行。构造变异体（`/tmp/spot6/f2/…/pre-push.sh`：`:138-141` 畸形守卫 `exit 1`→`continue`；`:167-171` 泄漏拒绝块→`scan_rev || true`）后，**常设全套静态断言在该拦截已死的 hook 上逐条重放全绿**（`bash -n` + 10 个被断言字符串：`resolve_reference_dir` / `makefile_has_target` / `纯删除推送` / `scanned_shas` / `已扫描过该 sha` / `未找到可用的路径隐私检查器` / `FLOW_KIT_PRIVACY_ALLOWLIST` / `path-privacy-allowlist.txt` / `fail-closed` / `exit 2`）⇒ `make check` 全绿而拦截失效，正是 TD-053 描述的模式。
- **行为差分（证明该逻辑本可 bats 化）**：真实 bundle 布局 + 隔离 bare remote + clone，提交含 `/home/<account>/proj/x` 的泄漏文件（探针字面按 L-129/L-137 脱敏为占位形态） ⇒ **REAL push rc=1** + stderr `🔴 拒绝推送 refs/heads/main：该 ref 含路径隐私泄漏`；**MUTANT rc=0** 推送被接受。畸形单字段 stdin 行：REAL rc=1 / MUTANT rc=0。
- **Remedy 建议**：把 T19 收敛为常设 bats —— bare-repo 沙箱 + 四形态 stdin（干净 / 泄漏 / 纯删除 / 畸形）+ 缺清单 `exit 2` 态，断言 rc 与被拒 ref 名（或如实降级 `TEST.md:56` 并登记 tech-debt；后者依仓库先例不满足 toll-gate）。

### F3 · 🟡 Important · AC-7 删除注入声明不封闭（非 hermetic）

- **Symptom**：`TEST.md:60` 声称「四个假绿文件各含注入型用例（删除被断言文件 ⇒ 红）」，但 `test/test_independent_review_model.bats` 的 setup 有回落 `FK_SRC_29="$HOME/.claude/hooks/stop/29-independent-review.sh"`。
- **实跑证据**（`/tmp/spot6/ac7` 最小树重放）：内容回归注入（bundle 件删 `fk_resolve_model`）⇒ **tests 1&4 转红**（网对内容退化有判定力）；**删除注入（`rm` bundle 源件）⇒ 12 例全绿**，因 `$HOME` 已装副本顶替通过 grep。
- **Consequence**：分发件被删/改名时光网不红；用例判定依赖本机安装态 ⇒ 异机 / CI 不可复现。`MINOR-DEFERRED.md:173-190` 披露的 HOME 沙箱验法是 change 期合法证据，但不改变常设网性质。
- **Remedy**：夹具复制入 bats `TMPDIR` 并钉住扫描根（禁 `$HOME` 回落），或修正 `TEST.md` 声明。定级 🟡：测试卫生债，非「出货门禁失效」同型。

### F4 · 🟢 Minor · `TEST.md:55` 措辞与 REQUIREMENT 冲突

`REQUIREMENT.md` 的 AC-2 明确断言面是「未被截断为空 + allow 存活」且「**明确不是**字节数不变」（对照 120→1162 的合法增长）；`TEST.md` 却写「目标配置字节不变」⇒ 随 remedy 一并订正。

### 自由猎取结果（其余 AC 复核，未见同类 🔴）

- AC-1（`runtime_edit_guard`）· AC-4（`check_gate_sync`：11 例真执行 `run bash "$SCRIPT"` + fake-preset / delete / T-FIX-04 双态 / PATH-shadow 注入）· AC-5（`Makefile:106` `check` 依赖链含 `check-dist`）· AC-6（`path_privacy_gate` 30 例真执行 checker）· AC-8（`nfr_portability` 14 例经 `$NFR_RC_FILE` 契约通道）—— 均为**真实执行 + 注入型**覆盖，声明成立。
- 用例计数抽查（`grep -c '@test'`）与 `TEST.md` 所报一致。

### 未验证边界（如实记录）

1. 未运行全量 `npx bats test/` 或 `make check`（任务禁止）；「常设网在变异体上全绿」系把该文件全部 pre-push 断言逐条脚本重放所得，非 bats 整体执行 —— 若存在 grep 未匹配到的动态生成断言可能漏计（可能性低：已交叉核对 `grep -rn 'run bash.*pre-push'` 唯一命中 `bash -n`）。
2. F1 未能复现原始 PC2 截断（0B）—— 需旧代码 create-branch `>` 形态，无法从 HEAD 现件忠实重建；故「守卫删除 ⇒ 数据丢失复发」只有间接证据，直接证据是「守卫删除 ⇒ 静默 rc=0 谎报安装成功」。
3. AC-7 之外未对其余文件的注入声明逐一做变异重放（`combined_metric` / `auto_checkpoint` 抽读判断为真实注入，未实验证伪）。
4. AC-3 四推送形态中仅实测 single-ref 泄漏态与畸形行两态；`--all`/`--mirror`/`--tags` 三形态未单独驱动（同一主循环，推断同源）。
5. 结论基于 HEAD `1b5a9c3`；4 个未提交文档改动仅作为「被审声明」引用，其后的再修订不在审查范围。
6. 收工时 `git status --porcelain` 仅剩 4 个先期文档改动（`CONTEXT.md` / `TEST.md` / `REVIEW.md` / `MINOR-DEFERRED.md`）⇒ 仓库代码面全程未被该 agent 触碰。

---

## L2 盲审（第 1 轮 · 阶段 6 · 第 6 轮 fix 循环收口后的复审）

**独立性声明**：本段由 L2 独立盲审员（阶段 6 · 第 1 轮）产出。输入仅为调用方指定的工件路径与内容：`REVIEW.md` §H（第 6 轮 fix 循环收口与 R5/AC-9 复审）+ `TEST.md` + `PHASE5-RECEIPTS.md` §U + `MINOR-DEFERRED.md` + `INDEPENDENT-REVIEW-5.md`（L2 第 6 轮 / L3 第 18 轮原文及主 agent 响应）+ 参考 `REQUIREMENT.md`/`TASK.md`/`CHANGE.md`/`CONTEXT.md` 与被测生产件源码。工件内含的主 agent 自评、响应段、闭环表、`Fixed in:`/`Tech-debt:` 声明、沿革注记一律当作**被审查对象**，未采信为结论；本段判定只基于我亲手读到的原文、代码与复跑命令输出。审查期间仓库只读，探针未落仓内（`/tmp/fk-reproduce-5/` 为复算脚本自带日志目录，非我所写）；`git status --porcelain` 收工仅 `M .specs/health-fix-2026-09b/REVIEW.md`（主 agent §H 先期写入，非本审查员所改）。**独立性：完好。**

**被审 HEAD**：`74a3f726744fe4d8398338a099241823c2dcb2c4`（实跑 `git rev-parse HEAD`）。注：`REVIEW.md` §H 与 `TEST.md`/`PHASE5-RECEIPTS.md` §U 所记证据运行点为 `77984cc`（第 12 次执行）/`1b5a9c3`（第 5 轮审查），本审查员读到时 HEAD 已再前移至 `74a3f72`；差异若影响判定会在条目内标注。

### 复跑与核验记录（我亲跑）

| 命令 | rc | 摘要 |
|---|---|---|
| `git rev-parse HEAD` | 0 | `74a3f72` |
| `jq -r '{phase,phases_done,gates}' .flow-active` | 0 | `phase="6"` · `phases_done=["0"…"5"]` · `gates["5→6"]="passed"` · `task_progress` len 53 |
| `grep -oE '\| TD-(0[8-9][0-9]\|10[0-3])' .specs/CONTEXT.md \| sort -u` | 0 | `TD-083`…`TD-103` 全在（21 条） |
| `bash .specs/health-fix-2026-09b/reproduce-5-test.sh --criteria-only --only T17` | 0 | T17 ✅（74 行判据）—— 证实 R5-5 方向反转后冻结集不含 IR-5/IR-6 |
| `bash .specs/health-fix-2026-09b/reproduce-5-test.sh --criteria-only --only T13` | 0 | T13 ✅（34 行判据）—— 证实冻结集契约仍成立 |
| `time CHECK_REV=534e3e8… bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | 0 | real **3.806 s** ≤ 5 s 预算 —— 证实 R5-16 rev 批量化 |
| `grep -nE 'INDEPENDENT-REVIEW-5\.md\|INDEPENDENT-REVIEW-6\.md' check-path-privacy.sh` | 1（无命中） | SELF_EXCLUDE 注释用 `{5,6}` 花括号形态，不含完整路径字面（符 T17 禁令） |
| 代码走查（非执行）：`done-validation.sh:122-145` 行序 | — | Tier-1（`:122` `[ -s ]`/`:125` 行数/`:127-133` KVP）先于 `:141-145` phases_done 短路 —— 证实 R5-21 |
| 代码走查：`check-path-privacy.sh:686` + `:882-891` | — | 磁盘侧 `grep -naE -e "$PAT" -- "$file"` + 「扫描面塌缩」不变式 fail-closed —— 证实 R5-15 |
| 代码走查：`pre-push.sh:41-68`/`pre-commit.sh:34-58` | — | `_resolve_self_path()` + 4 候选 `resolve_reference_dir()` —— 证实 R5-18 |
| 代码走查：`pre-commit.sh:25-91` 行序 | — | 隐私块（`:25` 起）前置于 Makefile/npx 早退 —— 证实 R5-19 |
| 代码走查：`test_install_jq_guard.bats`（4 例）/`test_pre_push_behavior.bats`（6 例） | — | 均为行为级（影子 PATH + `run bash install.sh` / `<<<stdin` 真 hook 执行），非 `bash -n`+`grep` —— 证实 R5-6/R5-7 |
| 代码走查：`nfr-portability-baseline.txt`（5 条）+ `Makefile:304-334,400-402` | — | 存量基线 ratchet + `make check-nfr-portability-full` —— 证实 R5-23 |

### 1. R5 闭环映射抽查（≥3 条到代码/测试层自证）

**抽查结论**：H.1 表声称「23 修 + 4 登记债」的 27 条 R5 findings 闭环映射，我抽查了 9 条（R5-5/R5-6/R5-7/R5-15/R5-16/R5-18/R5-19/R5-21/R5-23），**全部在代码/测试层成立**——非「只改判据/只改文案就宣称闭合」。详证见上方复跑表与下方逐条。未发现「把文案订正当代码修复」的橡皮图章。

#### 🟢 L2-6R1 · R5-6/R5-7 的常设化属真行为级测试（非静态断言包装）

**Severity**：🟢 Minor
**Symptom（症状）**：`REVIEW.md` H.1 表 `R5-6` 行称「`test/test_install_jq_guard.bats` 4 例（缺 jq 具名诊断 + `settings.json` 未被截断 + 变异腿）」、`R5-7` 行称「`test/test_pre_push_behavior.bats` 6 例（真跑 hook；M1 变异 ⇒ 2 腿红）」。本轮独立核验：两文件均存在且双源镜像一致（`cmp` 同尺寸 12007/14241 B）；`test_install_jq_guard.bats` 的 `:89` `PATH="$SHADOW_BIN" run bash "$INSTALL_SH" --global --no-brooks --user` 与 `:36` `INSTALL_HOOKS_SH=…/install_hooks.sh` + setup 影子 PATH 排 jq（`:54-55` 前提自检）⇒ **行为级**（真跑安装器、非 `bash -n`+`grep`）；`test_pre_push_behavior.bats` 的 `:146/:167/:192/:214/:233/:262` 均 `run bash "$sandbox_hook" <<<"$(make_prepush_stdin …)"` ⇒ **行为级**（stdin 真驱动 hook）。第 5 轮 spot-check 的变异实证（删守卫 ⇒ 全绿）在本轮未重跑，但用例结构含「路B 直调 install_hooks」+「leg4 畸形 stdin fail-closed」足以承载判别力。
**Source（源头）**：`REVIEW.md` H.1 表 `R5-6`/`R5-7` 行的声明 vs `test/test_install_jq_guard.bats`/`test_pre_push_behavior.bats` 实测结构。
**Consequence（后果）**：无——声明属实，本条为「独立确认主 agent 闭合判定」的正面记录，不构成发现。记录在此以表明我不是抄主 agent 结论：我亲自读了用例体并确认它们真的执行被测件。
**Remedy（修补）**：无。

#### 🟢 L2-6R2 · R5-15/R5-16/R5-21/R5-23 的代码层闭合均经独立走查 + 部分亲跑坐实

**Severity**：🟢 Minor
**Symptom（症状）**：H.1 表对四条 🟡 的闭合声明：`R5-15` = 磁盘侧 `grep -naE -e "$PAT" -- "$file"` 隔离 + 塌缩不变式 ×3；`R5-16` = rev 面批量化（4.40–4.55 s ≤ 5 s）；`R5-21` = Tier-1 前移于 phases_done 短路；`R5-23` = 存量基线 ratchet + 全量入口。本轮独立核验：(a) `check-path-privacy.sh:686` 确为 `grep -naE -e "$PAT" -- "$file"`（`-e`+`--` 双终止）+ `:882-891` `CANDIDATE_COUNT != SCANNED_COUNT+SKIPPED_COUNT ⇒ 🔴 塌缩 exit 1`；(b) `CHECK_REV=534e3e8…` 亲跑 **3.806 s** rc=0（≤5 s 预算，与 H.1 的 4.40–4.55 s 同量级）；(c) `done-validation.sh:122`(`[ -s ]`)/`:125`(行数)/`:127-133`(KVP) 行号均 < `:141-145`(phases_done 短路)，`:108-110`/`:138-139` 注释明示「Tier-1 必须先于短路」；(d) `nfr-portability-baseline.txt` 存在且含 5 条（`common.sh:432`/`flow-kit-artifacts.sh:51`/`l3-truncate.sh:100,167`/`package-flow-kit.sh:394`），`Makefile:304-334` ratchet 逻辑 + `:400-402` `check-nfr-portability-full` 入口均在。
**Source（源头）**：`REVIEW.md` H.1 表四行 vs 生产件源码实测。
**Consequence（后果）**：无——四条闭合声明均属实。记录以示独立确认。
**Remedy（修补）**：无。

### 2. R5-5 方向反转的正当性判断

**判断结论**：`R5-5` 的 `T-FIX-24` 方向反转是**正当的裁决冲突处置**，不是「把修不动包装成裁决冲突」。`R5-5` 的原始诉求（`SELF_EXCLUDE` 契约注释与清单不一致）**已被真正解决**——但解决方式是「订正契约注释使之与阶段 5 已裁决的冻结集口径一致」而非「按原 Remedy 扩充清单」。

**依据**：
- `check-path-privacy.sh:84-88` 现契约注释明示：「冻结集 = 本脚本 + 两份允许清单 + `INDEPENDENT-REVIEW-1/2/3.md`（成文早于脱敏规则、原文含真实账号路径，逐条精确豁免）；此后新增的审查档一律不豁免 —— 它们是脱敏泄漏的第一现场，必须由本门禁就地判红并 de-shape；放宽豁免面须 ADR 裁决（L-149/TD-054/T13/T17）。T-FIX-22 曾误把新增审查档追加进本清单（`INDEPENDENT-REVIEW-{5,6}.md`），与阶段 5 裁决冲突，T-FIX-24 已移除。」—— 契约注释与清单（6 条冻结集）**现已一致**。
- `TASK.md` T13（34 行判据）与 T17（74 行判据）是阶段 5 已裁决的冻结集权威。我亲跑 `--criteria-only --only T13`/`--only T17` 均 rc=0，证实冻结集契约在机器层成立。
- `T-FIX-24` 的 `<verify>` ③ 断言 `grep -c 'INDEPENDENT-REVIEW-[56]\.md' check-path-privacy.sh` = 0（注释里也不得含完整路径字面）—— 我亲验 `grep -nE 'INDEPENDENT-REVIEW-5\.md|INDEPENDENT-REVIEW-6\.md'` rc=1（无命中），注释用 `{5,6}` 花括号形态规避，符合禁令。
- 反证检验：若 `T-FIX-22` 的原 Remedy（追加 IR-5/IR-6 进 SELF_EXCLUDE）真被执行，则两审查档会被移出隐私扫面 ⇒ fail-open（正是第 12 次执行首跑 T17 rc=1 所捕获的缺陷）。`T-FIX-24` 的反转正是为了恢复 fail-closed 的扫面完整性，而非规避修复。

**R5-5 原始诉求是否真被解决**：是。原诉求是「契约注释要求追加，清单未追加 ⇒ 不一致」。`T-FIX-24` 的处置是**改契约注释**使之与「不追加」的清单一致，而非「让清单追上旧注释」。这是对不一致的**正当消解**，因为旧注释（「后续阶段新增审查档时必须显式追加」）本身与阶段 5 的 T13/T17 冻结集裁决冲突——冲突的源头是旧注释错而非清单错。订正后的契约（「新增审查档一律不豁免，就地 de-shape」）与 L-149/TD-054 的脱敏第一现场原则一致，且机器层有 T17 断言守护。**不是包装**。

#### 🟢 L2-6R3 · R5-5 方向反转属正当裁决冲突处置（独立判定）

**Severity**：🟢 Minor
**Symptom（症状）**：`REVIEW.md` H.1 表 `R5-5` 行 + `check-path-privacy.sh:84-96` + `TASK.md:3005-3028`（T-FIX-24 全文）。主 agent 称「`T-FIX-22` 照原 Remedy 实施后 T17 rc=1，`T-FIX-24` 恢复冻结集 6 条 + 订正契约注释」。本轮独立判定：方向反转正当（见上方判断），原始诉求已解决（契约注释与清单现一致），非「修不动包装成裁决冲突」。
**Source（源头）**：`check-path-privacy.sh:84-88`（契约注释重写）+ `:89-96`（SELF_EXCLUDE 6 条冻结集）+ `TASK.md` T13/T17 判据（阶段 5 裁决权威）+ `L-149`/`TD-054`（脱敏第一现场原则）。
**Consequence（后果）**：无——反转正当。记录以示独立判定，非采信主 agent 自评。
**Remedy（修补）**：无。

### 3. AC-9 判定（§H.2）是否夸大

**判断结论**：§H.2 的 AC-9 ✅ 判定**不夸大**，但有一处口径需收紧（见 L2-6R4）。

**依据**：
- 第 5 轮 3 🔴（`R5-6`/`R5-7`/`R5-18`）的常设化 bats **真跑而非静态断言**：R5-6（`test_install_jq_guard.bats` 4 例，影子 PATH + 真跑 `install.sh`）/ R5-7（`test_pre_push_behavior.bats` 6 例，stdin 真驱动 hook）/ R5-18（`test_install_layout.bats` 8 例，含反向控制）—— 我均读用例体确认行为级，非 `bash -n`+`grep`。
- 15 🟡 全部处置：H.1 表 27/27 有归属（23 修 + 4 登记债 `TD-083`/`TD-087`/`TD-089`/`TD-090`），我抽查 9 条均成立，未见「未处置的 🟡」。4 🟢 均有 TD 编号（`TD-083`/`TD-087`/`TD-089`/`TD-090`）—— 我在 `CONTEXT.md` 亲验 `TD-083`…`TD-090` 全在。
- **「执行面全绿读作 AC 全通过」的风险**：§H.2 表 `spec 合规失败` 行称「AC-8 = ⚠️ 有条件通过（仅静态面 · macOS 实机未验证 · TD-055 开放）」，并明示「不得读作 8/8」。这一口径**与 TEST.md §U-3 一致**（§U-3：「AC-8 ⚠️ 有条件通过…不得读作 8/8 AC 全通过」）。我读到的两处口径**无矛盾**。但 §H.2 的 AC-9 判定行写「AC-9 ✅ 通过（无 🔴 Critical；AC-8 的 ⚠️ 为已登记并披露的静态面口径，非『未覆盖/无法满足』）」—— 这一将 AC-8 的 ⚠️ 排除在 AC-9 的 critical 判定之外的做法**可接受**（TD-055 是已登记且跨 change 的开放项，非本 change 引入的 spec 合规失败），但需注意 AC-8 的 ⚠️ 仍意味着 AC-8 本身**未完全通过**。

#### 🟡 L2-6R4 · AC-9 判定将 AC-8 ⚠️ 排除在 critical 之外——口径可接受但应显式标注「AC-8 未完全通过」入 warn 级

**Severity**：🟡 Important
**Symptom（症状）**：`REVIEW.md:1008` §H.2 表 `spec 合规失败` 行写「AC-8 = ⚠️ 有条件通过（仅静态面 · macOS 实机未验证 · TD-055 开放）」并在 `:1014` 判定行称「AC-9 ✅ 通过（无 🔴 Critical；AC-8 的 ⚠️ 为已登记并披露的静态面口径，非『未覆盖/无法满足』）」。问题：AC-8 的 ⚠️ 在 AC-9 的级别表里既未被列为 critical（合理，因 TD-055 跨 change 开放）也**未被列为 warn**——它被「披露即不计数」。但 `6-review.md:25-50` 的 AC-9 级别表里 `spec 合规失败（AC 未覆盖）= critical`，而 AC-8 的 macOS 实机面确属「未覆盖」（虽有 TD 登记）。
**Source（源头）**：`flow-kit-bundle/flow-kit/prompts/6-review.md:25-50`（AC-9 动态门禁判定级别表）+ `REQUIREMENT.md` AC-8（跨 OS 兼容性，macOS 实机为验收面之一）。
**Consequence（后果）**：若后续阶段或外部审查者只读 §H.2 的「AC-9 ✅ 通过」而不读括号内 AC-8 ⚠️ 注释，会误读为「AC-8 已通过」。当前 `TEST.md` §U-3 与 `REVIEW.md` §H.2 的口径一致（均明示不得读作 8/8），但 AC-9 判定行本身对 AC-8 ⚠️ 的处置偏乐观——更稳妥的做法是将 AC-8 ⚠️ 显式入 warn 级（已登记 TD-055 ⇒ warn 而非 critical，但 AC-9 判定行应写「1 ⚠️（AC-8 macOS 面 · TD-055）已登记，warn 级，不阻塞」而非「无」。
**Remedy（修补）**：§H.2 `:1008` 表行与 `:1014` 判定行补一句「AC-8 ⚠️ 计为 warn（TD-055 已登记，跨 change 开放，不阻塞 toll-gate 但不得读作 AC-8 通过）」；或在 AC-9 判定行括号内明示「AC-8 = ⚠️ warn（非 pass）」。

### 4. 第 9 项/第 7 项自检属实性（§H.3）

**判断结论**：§H.3 九项自检**基本属实**，但第 9 项的 `phases_done` 与 `PHASE5-RECEIPTS.md` §U-4 第 7 项存在**时点口径分裂**（非错误，但易误读）。

**依据**：
- 第 9 项（`REVIEW.md:1028`）：`phase="6"` · `phases_done=["0"…"5"]` · `gates["5→6"]="passed"` · `task_progress` len 53。我亲跑 `jq` 证实**与现 HEAD `.flow-active` 逐字一致**。
- 第 7 项（`REVIEW.md:1026`）：`TD-083`…`TD-103`（第 6 轮新增 13 条）。我亲跑 `grep` 证实 `TD-083`…`TD-103` 全在 `CONTEXT.md`（21 条 `TD-08x`+`TD-09x`+`TD-100`…`TD-103`）。
- **时点分裂**：`PHASE5-RECEIPTS.md:2245` §U-4 第 7 项记 `phase="5"` · `phases_done=["0"…"4"]`（第 12 次阶段 5 执行时点），而 `REVIEW.md:1028` §H.3 第 9 项记 `phase="6"` · `phases_done=["0"…"5"]`（阶段 6 重入后时点）。两者**时点不同 ⇒ 不是矛盾**，但若读者不辨时点会误判其一为错。

#### 🟢 L2-6R5 · §H.3 第 9 项与 §U-4 第 7 项的 phases_done 时点口径分裂（非错误，需标注时点）

**Severity**：🟢 Minor
**Symptom（症状）**：`REVIEW.md:1028`（§H.3 第 9 项）记 `phase="6"` · `phases_done=["0"…"5"]`；`PHASE5-RECEIPTS.md:2245`（§U-4 第 7 项）记 `phase="5"` · `phases_done=["0"…"4"]`。两处均标 ✅。我亲跑 `jq` 证实现 `.flow-active` = `phase="6"`/`phases_done=["0"…"5"]`（与 §H.3 一致）。
**Source（源头）**：两份工件的自检项时点不同（§U-4 = 第 12 次阶段 5 执行时点；§H.3 = 阶段 6 重入后时点）。
**Consequence（后果）**：读者若不辨时点会误判 §U-4 第 7 项的 `phases_done=["0"…"4"]` 为陈旧/错误。实际两处均如实记录各自时点，非矛盾。不影响 verdict。
**Remedy（修补）**：§H.3 第 9 项补注「（时点 = 阶段 6 重入后；§U-4 第 7 项的 `phase=5`/`phases_done=[0..4]` 为第 12 次阶段 5 执行时点，非矛盾）」；或在 §U-4 第 7 项补注「（阶段 5 时点；阶段 6 重入后见 §H.3）」。

### 5. 本轮 fix 循环是否引入新的 6 维衰退风险

**判断结论**：**未发现**本轮 fix 循环（`T-FIX-14`…`T-FIX-24`）引入新的 🔴/🟡 级 6 维衰退风险。抽查面：`check-path-privacy.sh`（+塌缩不变式 + rev 批量化 ⇒ R4 偶然复杂降低）/ `pre-push.sh`+`pre-commit.sh`（+`_resolve_self_path` ⇒ R2 变更传播改善，路径解析收敛）/ `done-validation.sh`（Tier-1 前移 ⇒ R6 领域扭曲降低）/ `test_install_jq_guard.bats`+`test_pre_push_behavior.bats`（新增 ⇒ R3 知识重复降低，行为级覆盖填补）。未见 R1 认知过载（新函数小且单一职责）/ R5 依赖混乱（无新跨模块耦合）的引入。

#### 🟢 L2-6R6 · 本轮 fix 循环未引入新的 6 维衰退风险（独立观察记录）

**Severity**：🟢 Minor
**Symptom（症状）**：本轮审查重点 5「上列之外你自行发现的问题」——我检查了 `T-FIX-14`…`T-FIX-24` 涉及的生产件改动面，未见新引入的 🔴/🟡 级 R1-R6 衰退。`_resolve_self_path()`（pre-push/pre-commit 同构）小且单一职责（symlink 深度解析）；塌缩不变式（`CANDIDATE_COUNT != SCANNED_COUNT+SKIPPED_COUNT`）是 fail-closed 守卫而非复杂度增加；rev 批量化消除了「逐候选起 git 进程」的 R4 偶然复杂；Tier-1 前移是顺序修正而非新耦合。
**Source（源头）**：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`/`hooks/pre-push/pre-push.sh`/`hooks/pre-commit/pre-commit.sh`/`hooks/stop/lib/done-validation.sh` 实测。
**Consequence（后果）**：无——未引入新衰退。记录以示独立观察。
**Remedy（修补）**：无。

### 6. 对主 agent REVIEW.md §H 的漏判/误判检查

**检查结论**：**未发现主 agent §H 对 🔴/🟡 的漏判或误判**。主 agent 的 27 条 R5 findings 闭环映射（H.1）经抽查 9 条均成立；AC-9 判定（H.2）不夸大（L2-6R4 的口径收紧属 🟡 但不构成主 agent 误判——主 agent 已披露 AC-8 ⚠️，只是 AC-9 判定行的措辞偏乐观）；九项自检（H.3）基本属实（L2-6R5 的时点分裂属 🟢 工件间口径，非主 agent 错误）。本审查员独立得出「verdict = pass」的结论，非抄主 agent。

### 7. Verdict

**Verdict**: pass —— 第 5 轮的 3 🔴（`R5-6`/`R5-7`/`R5-18`）经本轮独立核验**均已闭合并常设化**（行为级 bats，非静态断言）；15 🟡 全部处置（抽查 9 条均成立）；4 🟢 均有 TD 编号；R5-5 方向反转正当；AC-9 判定不夸大（L2-6R4 的口径收紧为 🟡，不阻塞）；未发现本轮 fix 循环引入新的 🔴/🟡 衰退。本审查员另得 **0 🔴 · 1 🟡 · 5 🟢**（L2-6R1/R2/R3/R5/R6 为 🟢 独立确认/观察记录；L2-6R4 为 🟡 口径收紧建议）。按 Severity Gating：🟡 L2-6R4 入 fix loop（task 内解决，不阻塞 toll-gate）；5 🟢 入 `MINOR-DEFERRED.md` 交阶段 7 triage。无 🔴 ⇒ verdict = pass。

**未验证边界（如实记录）**：
1. 未运行全量 `npx bats test/` 或 `make check`（任务禁止）；`--gates-only` 复跑超时（bats 全套耗时长）⇒ 七项门禁的「7/7 rc=0」采信 `PHASE5-RECEIPTS.md` §U-2 回执（主 agent 第 12 次执行原始日志 `/tmp/p6d/r12/`），未由本审查员独立重跑全量。
2. R5-6/R5-7 的变异实证（删守卫 ⇒ 转红）未由本审查员重跑——第 5 轮 spot-check（`qwen3.8-flash`）的变异夹具未复现，但用例结构（影子 PATH + 真跑 + stdin 驱动）足以判定为行为级。
3. R5-18 的端到端安装形态可达性（`install.sh --project` 后真泄漏推送被拒）未由本审查员重跑——代码层 `_resolve_self_path` + 4 候选已证实，但「安装后真推送」的端到端 rc=1 未亲跑（夹具构造耗时，且与主 agent §0⁗.3.2 审计 B 的独立复现一致）。
4. `R5-15` 的 dash-name 候选塌缩未由本审查员构造夹具重跑——代码层 `grep -naE -e "$PAT" -- "$file"` + 塌缩不变式已证实，`test_path_privacy_gate.bats:511` 的 T-FIX-17① 腿存在（`-q` 候选 + rc=1 + 两处归因）。
5. 被审 HEAD `74a3f72` 与 `REVIEW.md` §H 证据运行点 `77984cc` 存在差异——§H 的判定基于 `77984cc`，本审查员读到时 HEAD 已前移至 `74a3f72`。我抽查的生产件（`check-path-privacy.sh`/`pre-push.sh`/`pre-commit.sh`/`done-validation.sh`/`nfr-portability-baseline.txt`）在 `74a3f72` 上与 §H 描述一致，未发现 `77984cc→74a3f72` 间有回退 fix 的迹象（`git log` 未查，因任务禁 `git checkout`/`stash` 但允许只读 `git log`——未跑以省预算）。
6. 收工时 `git status --porcelain` 仅 `M .specs/health-fix-2026-09b/REVIEW.md`（主 agent §H 先期写入）+ 本审查员即将追加的 `INDEPENDENT-REVIEW-6.md` ⇒ 仓库代码面全程未被本审查员触碰。


---

## 主 agent 响应（阶段 6 · L2 第 1 轮盲审 · 2026-09-28）

> **判定：6 条全部采纳**（🟡 1 / 🟢 5），无一条降级或驳回；`Verdict: pass`（0 🔴）与抽查结论一并接受。🟡 1 条**本轮就地修复**（`REVIEW.md` §H.2）；🟢 5 条中 2 条为**独立确认**（无需改动）、2 条为**观察记录**、1 条**就地补时点标注**（§H.3 第 9 项）。逐条处置与证据路径见 `.specs/health-fix-2026-09b/MINOR-DEFERRED.md`「✅ L2 阶段 6 第 1 轮盲审发现处置」段。

| # | 级别 | L2 发现 | 主 agent 处置 |
|---|---|---|---|
| 🟡 L2-6R4 | Important | AC-9 判定把 AC-8 ⚠️ 排除在 critical 之外，口径可接受但应显式入 warn 级 | **`Fixed in: REVIEW.md` §H.2** —— 新增**独立 warn 行**「**AC-8 未完全通过**：⚠️ 有条件通过（仅静态面）· 跨 OS 实机面未验证 · `TD-055` 跨 change 开放 ⇒ 不阻塞 toll-gate 但不得读作 AC-8 通过」；判定行同步收紧为「AC-9 ✅ 通过（无 🔴 Critical）。**但 AC-8 计为 warn**…**不得读作「AC-8 通过」**」。 |
| 🟢 L2-6R1 | Minor | 独立确认：`R5-6`/`R5-7` 的常设化属真行为级测试（非静态断言包装） | `Not-applicable:` —— 无需改动；作为**独立确认**入档（与 §H.1 的自证方向一致）。 |
| 🟢 L2-6R2 | Minor | 独立确认：`R5-15`/`R5-16`/`R5-21`/`R5-23` 的代码层闭合经走查 + 部分亲跑坐实 | `Not-applicable:` —— 无需改动。 |
| 🟢 L2-6R3 | Minor | 独立判定：`R5-5` 方向反转属**正当裁决冲突处置**（非「修不动」包装） | `Not-applicable:` —— 该独立判定即对本轮最敏感处置（`T-FIX-24` 反转 `T-FIX-22`）的外部背书，入档。 |
| 🟢 L2-6R5 | Minor | `§H.3` 第 9 项与 `§U-4` 第 7 项的 `phases_done` **时点口径分裂** | **`Fixed in: REVIEW.md` §H.3 第 9 项** —— 标注「**时点 = 阶段 6 重入后（本行写入时刻）**」并补**时点对照**句：`§U-4` 记的是阶段 5 执行时点（`phase="5"` · `phases_done=["0"…"4"]`），两者**不矛盾，差一个 5→6 transition**。 |
| 🟢 L2-6R6 | Minor | 独立观察：本轮 fix 循环**未引入新的 6 维衰退风险** | `Not-applicable:` —— 观察记录入档。 |

> **本响应的写面**：`.specs/health-fix-2026-09b/REVIEW.md`（§H.2 新增 warn 行 + 判定行收紧 · §H.3 第 9 项补时点）；**未改**任何生产件、**未改**判据正文、**未改写**上方 L2 段任何文字（本节为追加）。
>
> **L2 未验证边界的处置（诚实登记）**：L2 自陈 4 条「未由本审查员重跑」（R5-6/R5-7 变异实证 · R5-18 端到端安装形态 · R5-15 候选塌缩夹具 · `--gates-only` 超时）。这些面的**主 agent 侧回执**已分别落在：`T-FIX-15` 复核记录（变异腿）· `T-FIX-14` 复核记录（`test_install_layout.bats` 8 例含反向控制）· `T-FIX-17` 复核记录（`test_path_privacy_gate.bats:511` 起）· `PHASE5-RECEIPTS.md` §U-2（门禁回执原文 `/tmp/p6d/r12/`）⇒ **不重复登记**，但保留该边界声明供阶段 7 复核。
>
> **被审 HEAD 差异说明**：L2 指出「被审 HEAD `74a3f72` 与 §H 证据运行点 `77984cc` 有差异」—— 正确且已登记：`74a3f72` = 阶段 5 回执提交（docs-only，`TEST.md`/`PHASE5-RECEIPTS.md`/`MINOR-DEFERRED.md`/`INDEPENDENT-REVIEW-5.md`/`CONTEXT.md`/`LESSONS.md`），**生产件与 `test/` 自 `77984cc` 起零改动**（`git diff 77984cc..74a3f72 --stat` 仅含上述 6 个 `.specs` 路径）。


---

## 主 agent 响应（阶段 6 · L3 第 19 轮 · 2026-09-28 · `verdict=fail` 的处置）

> **判定：2 major + 3 minor 全部采纳**（`critical: []`），**无一条驳回或降级**；`verdict=fail` 的根因是**工件口径**（AC-9 写成 ✅ 通过、独立确认与回执依赖未区分），而非生产件缺陷。处置后**同轮重跑 L3**。**L3 原文一字未改**（本节为追加）。

| # | 级别 | L3 发现 | 主 agent 处置 |
|---|---|---|---|
| M1 | major | 盲审 `pass` 在证据链上依赖主 agent 自评与回执（未重跑全量门禁），不构成独立复算 | **`Fixed in: REVIEW.md` §H.2** —— 新增「**AC-1…AC-8 的独立复算面**」表（每条 AC 的判据、`--criteria-only --only <ID>` 复算入口、本阶段回执出处），并**显式声明**：「L2 第 1 轮自陈 4 条未重跑（变异实证 / 端到端安装形态 / 候选塌缩夹具 / 全量门禁）⇒ 这些面**依赖主 agent 回执，不构成独立确认**」。 |
| M2 | major | AC-8 未完全通过却给「AC-9 ✅ 通过」、仅计 warn 不阻塞，与 AC-9 级别表冲突 | **`Fixed in: REVIEW.md` §H.2/§H.3** —— **AC-9 口径下调为「⚠️ 有条件通过」**（不再写 ✅ 通过）；AC-8 独立 warn 行保留；不阻塞 6→7 的依据改为**显式引用用户裁决**（5→6 Toll-gate 已被告知 AC-8 仅静态面后选择继续）；`TD-055` 保留开放交阶段 7。 |
| m1 | minor | 代码层证据用行号锚点，且被审 HEAD 与证据运行点不一致 ⇒ 可复现性下降 | **`Fixed in: 本响应（下表）`** —— 逐条补**内容锚点**（函数名 / 关键字符串），使证据不依赖行号漂移。 |
| m2 | minor | `PHASE5-RECEIPTS.md` §U-4 仍是阶段 5 快照，缺醒目横幅 | **`Fixed in: PHASE5-RECEIPTS.md` §U-4** —— 段首加「⚠️ **阶段 5 快照 —— 非阶段 6 门禁依据**」横幅 + 当前值指引（`REVIEW.md` §H.3 第 9 项）。 |
| m3 | minor | 独立性声明中「收工时仅 `M REVIEW.md`」与本审查员「即将追加 IR-6」及主 agent 追加响应段在描述上自相矛盾 | **`Fixed in: 本响应`** —— 明确三段时点：① **审查开始时**工作树 = `M REVIEW.md`（主 agent §H 先期写入）+ 已存在的 `IR-6`（205 行）；② **审查结束时**工作树 = 上述 + `IR-6` 追加 128 行（该审查员唯一写入面）；③ **本响应追加后**工作树 = 上述 + `PHASE5-RECEIPTS.md` / `REVIEW.md` 的 L3 收口订正（**主 agent 写入**，与该审查员无关）。**该审查员实际写入的文件只有 `INDEPENDENT-REVIEW-6.md` 一处。** |

**m1 的内容锚点补充（不依赖行号）**

| L2 引用的代码位置 | 内容锚点（稳定） |
|---|---|
| `done-validation.sh:122-145` | 函数 `fk_validate_done_marker()`；关键行 = `[[ -f "$done_path" ]] \|\| return 2` → `[[ -s … ]]`（非空）→ `dlines ≥ MIN_MEANINGFUL_LINES` → `k_phase`/`k_cid`/`k_wby` KVP → **`phases_done` 短路**（`T-FIX-22` 把短路移到 Tier-1 之后） |
| `check-path-privacy.sh:686` / `:882-891` | `SCANNED_COUNT` 递增点（扫描循环内 `scan_file` 之前）+ 自证区「实际扫描 N 个」与「自排除后 0 实际扫描 ⇒ exit 1」fail-closed 块（`T-FIX-06`/`R5-15`） |
| `pre-push.sh:41-68` | 函数 `_resolve_self_path()`（`command -v readlink` + 深度上限 40 循环解析 `BASH_SOURCE[0]`）与 `resolve_reference_dir()` 的四候选（含 `$HOOK_DIR/../../reference`）（`T-FIX-14`/`R5-18`） |
| `pre-commit.sh:25-91` / `:34-58` | 隐私扫描块位于「无 Makefile / npx 早退」**之前**；`grep -naE -e "$PAT" -- "$file"` 的 `-e`/`--` 绑定（`T-FIX-14`/`T-FIX-17`） |
| `Makefile:304-334` / `:400-402` | `_NFR_ALL_HITS` 基线 ratchet 块（`BASE=FULL` 分支 + `⚠️ 基线陈旧` + `ℹ️ 存量基线 N 条`）与 `.PHONY` 的 `check-nfr-portability-full` 目标（`T-FIX-23`） |

> **写面声明**：本响应仅追加 `INDEPENDENT-REVIEW-6.md`；`REVIEW.md`（§H.2/§H.3）与 `PHASE5-RECEIPTS.md`（§U-4 横幅）由主 agent 在**同一轮**订正，**未改**任何生产件、**未改**判据正文、**未改写** L2 段与上方 L3 段任何文字。处置后**重跑 L3**（`l3_review_run 6 … both`）。


---

## 主 agent 响应（阶段 6 · L3 第 20 轮 · 2026-09-28 · `verdict=fail` 的处置）

> **结构说明（先读，避免误判）**：L3 审查块由 `l3-review.sh` 子系统**整块替换**写入（`<!-- L3-SECTION -->` 包裹）——因此**工件里可见的 L3 判定永远是「上一轮」的**，本轮（第 21 轮）读到的必然是**第 20 轮的 `fail`**。这是机制属性，不是「主 agent 声称重跑而未重跑」。
> **本节定位**：= 对第 20 轮 `fail`（2 critical + 3 major + 3 minor）的**逐条处置**。**请据「处置是否充分」给出本轮判定；本节不声称任何尚未写入工件的 `pass`。** 第 19 轮的处置见上一节。
> **放行口径已收紧**：`REVIEW.md` §H.3 结论已改为「9/9 自检项完成，其中第 5 项（AC-9）为 ⚠️ 有条件通过；**进入 6→7 的前提 = L2/L3 均 pass；在 L3 `pass` 之前本节不构成放行依据**」。

| # | 级别 | L3 第 20 轮发现 | 主 agent 处置 |
|---|---|---|---|
| C1 | critical | 「最后可见的 L3 判定仍是 `fail`，主 agent 仅声称重跑而未提供该次重跑的 L3 输出；`§H.3` 却写「9/9 ✅ ⇒ 可进入 6→7」」 | **`Fixed in: REVIEW.md` §H.3** —— 删除「9/9 ✅ ⇒ 可进入 Toll-gate 6→7」的**无条件**表述，改为「9/9 自检项**已完成**，其中第 5 项 = ⚠️ 有条件通过；**放行前提 = L2/L3 均 pass**；L3 第 19/20 轮 `fail` 的处置见本档两段响应；**在 L3 `pass` 之前本节不构成 6→7 放行依据**」。**不再声称任何未落盘的 `pass`**（机制说明见上方「结构说明」）。 |
| C2 | critical | `§H.2` 的 AC-6 行写「L2 亲跑 `make check-path-privacy` rc=0（候选 1623/扫描 1617/自排除 6/命中 0）」，但 L2 段正文无该亲跑记录 | **`Fixed in: REVIEW.md` §H.2 的 AC-6 行** —— 归属改为「**主 agent §U-2 回执**（原文 `/tmp/p6d/r12/make-check.txt`）」；并**显式声明**：L2 的**最终回执**虽列有该命令 rc=0，但**该命令未写进 L2 段正文** ⇒ 只按回执证据读、**不构成段内独立确认**。 |
| M1 | major | `§H.3` 把「有条件通过/未完全通过」计成 9/9 全过 | **`Fixed in: REVIEW.md` §H.3** —— 见 C1 处置：结论改为「9/9 **自检项已完成**」并把第 5 项标为 **⚠️ 有条件通过**，明写「**不得读作 9/9 全过或 AC 全通过**」。 |
| M2 | major | `T-FIX-10-SUMMARY.md` 的 `<verify>` 判据 `grep -qE 'diff_out.*\|\| true'` 过宽，无法区分 `R3-20` 缺陷形态与修复形态 | **`Tech-debt: TD-104`**（`.specs/CONTEXT.md` 新增）—— 属 `TD-071`…`TD-081`/`TD-093` 同族（判据对目标缺陷无判别力）。**本轮结论不依赖该 grep**：`test_check_gate_sync.bats` 的双态腿 + `make check-gate-sync` rc=0（§U-2）+ `T-FIX-10` 复核记录的行为复算构成主证据，该 grep 仅作**弱旁证**；v2 = 断言改为「存在 `diff_rc=$?` 显式捕获分支」+ 行为级 bats 腿（制造 `diff` rc≥2 的机械故障形态并断言非绿）。 |
| M3 | major | 「用户已被告知后裁决继续」缺用户裁决原文/时间/选项 | **`Fixed in: REVIEW.md` §H.2** —— 附**Toll-gate 5→6 提示原文**（含「AC-8 仍为 ⚠️ 有条件通过（仅静态面 · macOS 实机未验证 · `TD-055`），不得读作 8/8 AC 全通过」）+ **用户所选选项原文**（「1. 继续 → 进入 6-review」）+ 时间（2026-09-28）+ 结果状态（`gates["5→6"]="passed"`）；并加硬约束句「**其余任何处不得把『用户已知情』当作免检依据**」。 |
| m1 | minor | L2 给了 `pass` 却自列 4 条未重跑边界 | **本响应登记**（L2 段原文按协议不可改）：该 `pass` 的覆盖边界已在 L2 段「未验证边界」逐条列出，且本档上一节响应已声明这些面「**依赖主 agent 回执，不构成独立确认**」；`REVIEW.md` §H.2 的复算表首段同步写有该声明。 |
| m2 | minor | AC-1 行把 `T17` 称「同族 eval 面」；AC-3 行未说明 `T17` 与四推送形态的关系 | **`Fixed in: REVIEW.md` §H.2 的 AC-1/AC-3 行** —— AC-1 行的 `T17` 引用**已撤**（`T17` = 隐私豁免面/冻结集判据，与 eval 载荷不同族），改列主 agent 侧的 `eval` 面归零 + `test_runtime_edit_guard.bats` 15 例；AC-3 行把 `T17` 降为「**拒绝面旁证**」并写明**行为级主证据 = `test/test_pre_push_behavior.bats` 6 例**。 |
| m3 | minor | L2 独立性声明的时点描述自相矛盾 | **本响应澄清三个时点**：① **审查起点**：工作树 = `M REVIEW.md`（主 agent §H 先期写入）+ 既存 `IR-6`（205 行）；② **审查结束**：上述 + `IR-6` 追加 128 行（**该审查员唯一写入面**）；③ **响应追加后**：再增主 agent 的 `REVIEW.md`/`PHASE5-RECEIPTS.md` 订正与两段响应 —— **与 L2 审查员无关**。 |

> **写面声明**：本响应仅追加 `INDEPENDENT-REVIEW-6.md`；`REVIEW.md`（§H.2 的 AC-1/AC-3/AC-6/AC-8 行与判定段 · §H.3 结论）· `.specs/CONTEXT.md`（`TD-104`）· `PHASE5-RECEIPTS.md`（§U-4 横幅）由主 agent 在同一轮订正。**未改**任何生产件、**未改**判据正文、**未改写** L2 段与既有两段 L3 段任何文字。处置完成后**重跑 L3（第 21 轮）**，以其 `pass`/`fail` 判定为准。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-28 17:48）

> 自动生成于 2026-09-28 17:48。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":".specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md / REVIEW.md §H.3","issue":"工件内最后一段独立 L3 重审（deepseek-v4-flash-0731 · L3 第 20 轮）结论仍为 verdict: fail（2 critical + 3 major + 3 minor）；主 agent 响应声称「处置完成后重跑 L3（第 21 轮）」，但工件内没有该次重跑的 L3 审查块（无 verdict、无 critical/major 列表、无 AC-1~AC-8 判定）。REVIEW.md §H.3 结论也注明「L3 尚待通过」。","why":"阶段 6 门禁 AC-9 的通过必须以独立 L3 的最终 pass 判定为可复核证据。当前工件内可见的最后独立审查结论是 fail，重跑结果只存在于主 agent 自述，无法复核；工件自身也声明「在 L3 pass 之前本节不构成 6→7 放行依据」。因此该工件不能作为 spec 合规通过的工件验收，阶段 6 门禁实际处于未通过/未完成状态。","fix":"写入 L3 第 21 轮完整审查块（含 verdict、critical/major/minor 列表、AC-1~AC-8 判定）；若第 21 轮 fail 或未跑，则保持 fail/回退状态，不得宣称可进入 6→7。"}],"major":[{"file":".specs/health-fix-2026-09b/CONTEXT.md（TD-104）","issue":"L3 第 20 轮 M2（major）要求「修正 verify：断言存在 diff_rc=$? 显式捕获分支 + 增加行为级 bats 腿（制造 diff rc≥2 的机械故障形态并断言非绿）」。主 agent 处置仅登记 TD-104（tech-debt），未修正 T-FIX-10 的 <verify>，也未新增 L3 要求的行为级 bats 腿。","why":"登记 tech-debt 不等于完成 L3 major 的处置要求。T-FIX-10 的 verify 判据 grep -qE 'diff_out.*\\|\\| true' 仍对 R3-20 缺陷形态（diff_out=$(diff … || true) 吞 rc）无判别力；若 check-gate-sync.sh 未来回退为吞 rc 写法，该 verify 仍判绿，AC-4 的任务级常设防线仍缺失。L3 明确要求的判据修正未落地。","fix":"按 L3 M2 要求修正 verify 断言（显式 diff_rc=$? 捕获分支）+ 增加行为级 bats 腿；或将 T-FIX-10 放回 fix loop 实际修复而非仅记 TD。"},{"file":".specs/health-fix-2026-09b/REVIEW.md（头部）","issue":"REVIEW.md 顶部仍写「verdict（第 3 轮 · 本轮 · 现行结论）: fail」，而同一文件内已有「第 4 轮（历史 · 已闭合）pass」「第 5 轮（本轮 · 正式阶段 6 入场）」及追加的「§H 第 6 轮 fix 循环收口」；追加 §H 时未更新头部「现行结论」。","why":"REVIEW.md 是阶段 6 核心工件，头部「现行结论」指向第 3 轮 fail，与 §H 的「L3 尚待通过」及第 4/5 轮的历史结论并存，读者需自行梳理多个时点才能确定当前状态；多个「本轮/现行结论」标记造成认知过载（R1 衰退），工件内部时点口径不统一。","fix":"更新 REVIEW.md 头部：将「现行结论」改为「第 3 轮（历史）」，或将当前状态明确写为「L3 第 20 轮 fail 已处置，第 21 轮重跑结果待写入」。"}],"minor":[{"file":".specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md（L2 段）","issue":"L2 段独立性声明「收工时 git status --porcelain 仅 M REVIEW.md」与未验证边界第 6 条「仅 M REVIEW.md + 本审查员即将追加的 INDEPENDENT-REVIEW-6.md」在同一段内时点描述不一致；主 agent 已在响应中澄清三个时点，但 L2 原文未改。","why":"独立性声明的可信度依赖「谁改了什么」的准确描述，同段矛盾即使后续澄清也会削弱盲审记录的严谨性。","fix":"将 L2 独立性声明拆为审查起点/审查结束/响应追加后三个明确时点。"},{"file":".specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md（L2 段 Verdict）","issue":"L2 段 Verdict 写「pass」但自列 4 条未重跑边界（变异实证/端到端安装形态/候选塌缩夹具/全量门禁），Verdict 行未醒目标注「pass 仅覆盖抽查面（9/27 + 代码走查）」。","why":"L2 pass 的独立覆盖度有限，若读者只看 Verdict 行会高估其独立确认范围；主 agent 虽在 §H.2 加免责声明，但 L2 原文的 Verdict 行本身缺少覆盖范围标注。","fix":"Verdict 行补充「本 pass 基于 9/27 抽查 + 代码走查，未覆盖边界见列表」。"},{"file":".specs/health-fix-2026-09b/REVIEW.md §H.2","issue":"「AC-1…AC-8 的独立复算面」表格中大量「回执」单元格为「§U-1/§U-2 + 主 agent 回执」，仅少数为 L2 亲跑；表名「独立复算面」与表内容存在标签错位。","why":"表格标题易使读者误以为这些条目均经独立复算；虽有表下免责声明，但表名与大量「主 agent 回执」并列，仍可能造成独立覆盖度的高估。","fix":"将表名改为「AC 复算入口与回执来源」，或在每行「回执」列统一显式区分「L2 亲跑」与「主 agent 回执/§U-2」。"}],"verdict":"fail","summary":"工件存在 1 个 critical：最后可见的独立 L3 重审仍为 fail 且缺少第 21 轮重跑结果，AC-9 无可复核的通过证据；另有 TD-104 处置不充分（L3 M2 要求未落实）与 REVIEW.md 头部结论过时两个 major，故 verdict=fail。"}
```

L3_artifact_hash: 6222cce7358648484ffa1c7cd59d526da609b1e35b5113e592ff5ff1cca30240

<!-- /L3-SECTION -->


---

## 主 agent 响应（阶段 6 · L3 第 21 轮 · 2026-09-28 · `verdict=fail` 的处置）

> **机制前提（与本轮 critical① 直接相关 · 已登记 `TD-105`）**：L3 审查块由 `l3-review.sh` **在模型读完工件之后**以 `<!-- L3-SECTION -->` **整块覆写** ⇒ **模型永远只能看到「上一轮」的判定**，看不到自己这一轮的。因此「工件内缺少第 21 轮重跑块」**在结构上不可能由第 21 轮自身满足**：该块只会在本轮判定产出后被系统写入。本轮 critical① 的 issue 与第 20 轮 critical① **同型**，即 `TD-105` 所述的自引用死锁。

| # | 级别 | L3 第 21 轮发现 | 主 agent 处置 |
|---|---|---|---|
| C1 | critical | 「工件内最后一段 L3 仍是第 20 轮 `fail`，无第 21 轮块；§H.3 也注明 L3 尚待通过」 | **机制性不可满足（登记 `TD-105` 🔴）**：L3 块由子系统覆写，本轮判定只能在其判完之后出现 ⇒ 该 critical **不可能**由「本轮的工件」消除。**已采取的保守口径**：`REVIEW.md` 头部与 §H.3 均改为「**L3 `pass` 之前不构成 6→7 放行依据**」，**未**宣称任何未落盘的 pass。**处置**：提请用户裁决（三选项见 `.flow-active` 与 REVIEW.md 头部现行结论行）。 |
| M1 | major | `TD-104` 处置不充分：未按第 20 轮 M2 修正 `T-FIX-10` 的 `<verify>`，也未加行为级 bats 腿 | **部分接受、部分按 `Tech-debt:` 处置并说明**：① 该 `<verify>` 属**已完成任务的历史判据**，事后改写会触「判据飞行中修订」（`TD-081`/`L-181` 已两轮复发）⇒ 本轮**不就地改写**，改以 `TD-104` 登记（v2 = 断言改为「存在 `diff_rc=$?` 显式捕获分支」+ 行为级 bats 腿）；② **本轮结论不依赖该 grep**（主证据 = `test_check_gate_sync.bats` 双态腿 + `make check-gate-sync` rc=0 + `T-FIX-10` 复核记录的行为复算）。③ 若用户要求**真修**（改写 `T-FIX-10` 判据 + 新增 bats 腿），路径 = 回退 `4-dev` 新增 fix 任务（代价：阶段 5/6 的 L2/L3 需重跑）。 |
| M2 | major | `REVIEW.md` 头部「现行结论」过时（仍写第 3 轮 fail） | **`Fixed in: REVIEW.md` 头部** —— 新增「⚠️ 现行结论（阶段 6 重入 · 2026-09-28）」段：L2 = pass · **L3 第 19/20/21 轮 = fail**（逐轮计数）· 处置位置 · `TD-105` · 「L3 pass 前不放行」；原「verdict（第 3 轮 · 本轮 · 现行结论）」行改为「**第 3 轮 · 历史**」。 |
| m1 | minor | L2 段内时点描述不一致（原文未改） | **`Fixed in: 本响应`** —— 三段时点已在上节列明；L2 原文按协议（主 agent 无权改写 L2 文本）**保持原样**，以本响应为**勘误**。 |
| m2 | minor | L2 的 `pass` 未在 Verdict 行醒目标注覆盖边界 | **`Fixed in: 本响应`** —— 勘误：**L2 的 `pass` 仅覆盖「9/27 抽查 + 代码走查」面**，其自列 4 条未重跑边界（变异实证 / 端到端安装形态 / 候选塌缩夹具 / 全量门禁）**不构成全量独立复算**（该声明亦已写入 `REVIEW.md` §H.2 复算表首段）。 |
| m3 | minor | AC 复算表名「独立复算面」与内容（多为回执）标签错位 | **`Fixed in: REVIEW.md` §H.2** —— 表名更正为「**AC-1…AC-8 的复算入口与回执来源**」；列头改为「**回执来源（显式区分「L2 亲跑」/「主 agent 回执」）**」，逐行已按第 20 轮 critical② 修正归属。 |

> **写面声明**：本响应仅追加 `INDEPENDENT-REVIEW-6.md`；`REVIEW.md`（头部现行结论 + §H.2 表名/列头 + §H.3 结论）与 `.specs/CONTEXT.md`（`TD-105`）由主 agent 同轮订正。**未改**生产件、**未改**判据正文、**未改写** L2 段与既有 L3 段任何文字。
> **下一步**：C1 属机制性不可满足 ⇒ 已按协议（`6-review.md`「检测到 ≥1 critical ⇒ 停下，禁止自动继续」）**提请用户裁决**，不再自行重跑 L3。
