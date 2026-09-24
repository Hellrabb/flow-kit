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
