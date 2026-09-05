# 独立审查 · 阶段 3

## L2 盲审

> 阶段 3 · 任务拆解审查（TASK.md 工件 + REQUIREMENT/DESIGN 参照）。盲审范围：任务粒度 / 依赖链 / verify 可验证性 / AC 覆盖完整性 / 禁动清单 / L-031 跨文件一致性 grep。

### 🔴 R1 · `_l3_inject_context` 调用位点自相矛盾：移入 `_l3_build_prompt` 将与 `l3-review.sh` 现存拼接点双重注入
**Severity**：🔴 Critical
**Symptom（症状）**：TASK T03 action 第 5 点写「物理拼接在 T04 的 `_l3_build_prompt` 内完成」；T04 action ① 写「重排 `_l3_build_prompt` 全阶段构造顺序：① `_l3_inject_context` 反馈段置最前」；DESIGN §0.5.3 写「AC 断言统一走 `_l3_build_prompt` 端到端」。但 `l3-review.sh`（DESIGN §0.5.1 禁动清单明文「本 change 不改它们的逻辑」）在 **L81-82（--background 路径）与 L103-104（同步路径）** 两处已独立调用 `_l3_inject_context "$phase" "$artifacts_dir"` 并 `prompt_text="${context_preamble}"$'\n'"${prompt_text}"` 前置拼接。实测 grep 证实：`_l3_inject_context` 定义在 l3-prompt.sh:26，调用方只有 l3-review.sh:81 与 l3-review.sh:103，`_l3_build_prompt`（l3-prompt.sh:53-157）当前**不**调用它。
**Source（源头）**：DESIGN §2 数据流把 ① `_l3_inject_context` 画进「prompt 构造」块（即 `_l3_build_prompt` 内部），与 §0.5.1「l3-review.sh 不改」互相冲突；TASK 全 6 任务的 write_files 均不含 `l3-review.sh`。L-031 教训（触碰模块清单不完整 → 跨文件漏改）。
**Consequence（后果）**：两种解读皆崩——(A) 若 T04 按字面把 `_l3_inject_context` 移进 `_l3_build_prompt`，则生产链路（29 → l3-review.sh → `_l3_build_prompt` 内已注入 + L103-104 再前置拼接）把前轮反馈注入**两次**，反馈总量 800B → 1600B，违反 AC-4 ③「前轮反馈注入总量 ≤ 800 字节」；(B) 若 `_l3_inject_context` 留在 l3-review.sh、`_l3_build_prompt` 不调用，则 T03 第 5 点与 T04 ① 的措辞错误，且 AC-4/AC-5（前轮反馈）**无法**经「`_l3_build_prompt` 端到端」验证（DESIGN §0.5.3 自许的验证入口失效）。更隐蔽的是**假绿**：T04/T05 的 bats 直接调 `_l3_build_prompt`，走不到 l3-review.sh 的第二层拼接，测试绿而生产重复注入（CONTEXT BUG-G「假绿」同型）。
**Remedy（修补）**：DESIGN/TASK 必须显式落定调用位点，二选一：
- 方案 A（推荐·最小改动）：`_l3_inject_context` **保留**由 l3-review.sh L81/L103 调用（现拼接点不动，禁动声明成立）；T04 只重排 ②③④（CHANGELOG/LESSONS → 7 文件循环 → checklist），把 T04 ① 措辞改为「前轮反馈段（经 l3-review.sh 前置拼接）仍居最前，本任务不动 `_l3_inject_context` 调用位点」；T03 第 5 点「物理拼接在 _l3_build_prompt 内完成」删除；DESIGN §0.5.3 的 AC-4/AC-5 验证入口改为「经 `l3_review_run()` 端到端」或「`_l3_inject_context` 单元 + l3-review.sh 拼接集成」。
- 方案 B：`_l3_inject_context` 移入 `_l3_build_prompt`，则**必须**同步删除 l3-review.sh L81-82 与 L103-104 两处拼接（并把 l3-review.sh 从禁动清单移入触碰模块、新增对应 task）——否则双重注入。

### 🟡 R2 · 响应分类行锚点 `^(Fixed in|Tech-debt|Not-applicable):` 与真实产物格式不符（行首锚定 vs 行中标记）
**Severity**：🟡 Important
**Symptom（症状）**：DESIGN D4 锚点 ③ 为 `^(Fixed in\|Tech-debt\|Not-applicable):`（行首锚定）；但真实产物 INDEPENDENT-REVIEW-2.md 的主 agent 响应段实际格式是 `- **R1** — Fixed in: \`DESIGN.md\` ...`（列表项、`**R<x>** — ` 前缀、分类 token 在**行中**）。T02 明写 fixtures「样本数据取自 INDEPENDENT-REVIEW-2.md 真实结构（脱敏改写）」，若忠实复刻，则锚点 ③ 对真实格式恒不命中。
**Source（源头）**：对照 l3-prompt.sh:156 JSON schema 无碍，但 D4 锚点 ③ 假设「分类行」是裸行首分类标记，与既有产物 `- **R<x>** — <分类>:` 清单体格式不符；DESIGN §6 又把「段头/分类行标准化」移出范围，锚点 ③ 既不匹配现状、也不匹配未来标准化格式。
**Consequence（后果）**：响应要点提取（AC-4 ②「逐条 Fixed in:/Tech-debt:/Not-applicable: 分类标记行 ≤200B」）在真实产物上提取为空——「已响应」判定尚能靠锚点 ①（`## 主 agent 响应` 段头）兜住，但响应要点摘要退化；且 T02/T03 的 fixture 若忠实复刻真实格式，T03 用例「mixed fixture（含 Fixed in: 行）→ 要点行」会暴露锚点 ③ 不命中而红；若 fixture 被「规范化」为行首格式，则测试绿但掩盖真实失配（假绿）。
**Remedy（修补）**：将锚点 ③ 改为匹配真实清单体格式，如 `[—]\s*(Fixed in|Tech-debt|Not-applicable):`（或 `\*\*R[0-9]+\*\*.*(Fixed in|Tech-debt|Not-applicable):`）；或响应要点提取改为「段级提取」（命中锚点 ① 后取 `## 主 agent 响应` 段整体 ≤200B 截断），不依赖行首分类 token。同时 T02 fixture 必须**忠实复刻** `- **R<x>** — <分类>:` 真实格式（不规范化），并明确锚点 ③ 的正则与真实格式对齐。

### 🟢 R3 · T04 波次依赖声明与 XML `depends_on` 不一致（T01 冗余但无害）
**Severity**：🟢 Minor
**Symptom（症状）**：波次划分写「Wave 4: T04 … (depends on T03)」，但 T04 的 `<depends_on>T01, T03</depends_on>` 多列了 T01。
**Source（源头）**：TASK.md L15 vs L135；T01 已由 T03→T02→T01 传递依赖覆盖，显式列 T01 语义冗余。
**Consequence（后果）**：无功能后果（依赖图仍无环、仍串行），仅文档一致性噪声。
**Remedy（修补）**：`<depends_on>T01, T03</depends_on>` 改为 `<depends_on>T03</depends_on>`（或波次行补全为 `(depends on T01, T03)`），两处对齐。

### 🟢 R4 · T04 verify `grep -c 'head -c' -le 3` 是「均在 helper 内」的弱代理
**Severity**：🟢 Minor
**Symptom（症状）**：T04 verify 仅断言 `head -c` 命中数 ≤3，done 却宣称「仅剩 helper 函数体内部（≤3 处命中均在 helper 内）」。
**Source（源头）**：D7 验证锚点为「改后 grep 仅剩 helper 函数体内部」；两 helper 各含 1 处 `head -c`（合计 2），`-le 3` 预留了 1 处 slack，若实现误留 1 处裸 `head -c` 在循环/截断点，总数 =3 仍通过 verify 而锚点被破坏。
**Consequence（后果）**：验证强度弱于宣称，极端情况下漏检 1 处漏替换（残留断裂 UTF-8 尾巴，NFR 健壮性部分失效）。
**Remedy（修补）**：verify 收紧为精确断言，如 `[ "$(grep -c 'head -c' …)" -eq 2 ]`（对应两 helper 各 1 处），或拆开断言「helper 定义块内 =2 且循环/截断点 =0」。

---

**总评**：AC → 任务映射完整（AC-1~7 全覆盖）、依赖链无环纯串行（同文件冲突切串行理由成立）、verify 全可机器执行、write_files 未触碰禁动清单（T06 仅写同步副本 + 漂移 patch）。核心阻塞项 R1（`_l3_inject_context` 调用位点自相矛盾）须在实现前落定，否则生产双重注入 + 假绿。

**Verdict**: fail

---

## 主 agent 响应

- **R1（🔴 调用位点自相矛盾）** — Fixed in: TASK.md（T03 action 第 5 条 / T04 action 首段 / T04 AC-1、AC-5 测试行 / T05 AC-4、AC-7 测试行）+ DESIGN.md（§0.5.3 验证入口裁决 / D1 决策行 / §2 数据流图）。采纳**方案 A**：`_l3_inject_context` 调用关系不变（生产拼接方 = l3-review.sh:81/L103 既有 `context_preamble` 前置，禁动文件零改动，杜绝双重注入）；`_l3_build_prompt` 只重排自身段序（CHANGELOG/LESSONS → 7 文件 → checklist，输出内不含反馈段）。验证入口拆分：AC-1/2/3 走 build_prompt 单调用；AC-4/5/7 走复刻 l3-review.sh:81-104 组装的组合调用（`out="$(_l3_inject_context 7 <dir>)$(_l3_build_prompt 7 <dir> 20000)"`），与生产拼装同构、不假绿。
- **R2（🟡 分类行锚点与真实格式不符）** — Fixed in: TASK.md（T03 action 第 2 条）+ DESIGN.md（D4 锚③ + §2 图内锚行）。去 `^` 行首锚，改行内 `(Fixed in|Tech-debt|Not-applicable):` 匹配，实证格式 `- **R1** — Fixed in:`（INDEPENDENT-REVIEW-1/2.md 响应段）；fixtures 忠实复刻真实格式。
- **R3（🟢 波次图与 XML 依赖不一致）** — Fixed in: TASK.md（Wave 4 行改 `(depends on T01, T03)`，与 T04 `<depends_on>` 对齐）。
- **R4（🟢 verify 弱代理）** — Fixed in: TASK.md（T04 verify 改 `grep -c 'head -c' -eq 2`；T01 action 新增实现约定「两 helper 内部各恰好 1 处 head -c」——精确计数杜绝任何漏替换）。

---

## L2 盲审（复审轮）

> 复审范围：验证首轮 R1–R4 修复是否落地 + 独立重扫新问题（L-031 全仓一致性 grep）。已读工件：TASK.md / REQUIREMENT.md / DESIGN.md / INDEPENDENT-REVIEW-3.md（首轮 + 主 agent 响应）；实测 flow-kit-bundle/hooks/stop/lib/l3-prompt.sh（157 行）与 l3-review.sh（246 行）。

**首轮 R1–R4 修复确认（全部正确落地）**：
- R1（调用位点矛盾）✅ 方案 A 已落定：TASK T03 action 第 5 条 / T04 action 首段 / DESIGN §0.5.3、D1、§2 均改为「`_l3_inject_context` 调用关系不变，生产拼接方 = l3-review.sh:81/L103，禁动文件不改」。实测 grep 证实 `_l3_inject_context` 调用方确仅 l3-review.sh:81、:103 两处，`_l3_build_prompt`（l3-prompt.sh:53-157）不调用它，方案 A 与真实代码一致，无双重注入。
- R2（分类行行首锚）✅ D4 锚 ③ 已去 `^` 行首锚，改为行内 `(Fixed in|Tech-debt|Not-applicable):` 匹配 + 实证格式 `- **R1** — Fixed in:`。
- R3（波次图 vs XML 依赖）✅ Wave 4 行已改为 `(depends on T01, T03)`，与 `<depends_on>` 对齐。
- R4（verify 弱代理）✅ T04 verify 已收紧为 `grep -c 'head -c' -eq 2`，T01 action 新增「两 helper 各恰好 1 处 head -c」实现约定。

### 🔴 R5 · 双源测试同步缺失：test/ ↔ flow-kit-bundle/test/ 无同步步骤，`make check` 必失败
**Severity**：🔴 Critical
**Symptom（症状）**：TASK T01–T05 的 write_files 只写 `test/test_l3_pipeline_fix.bats`（开发源）+ `test/fixtures/` 下 5 个新 fixture（independent-review-{l2,l3,mixed,no-response,empty}-sample.md）；无任何 task 写 `flow-kit-bundle/test/` 或执行 `make test-sync`。T06 只同步 l3-prompt.sh 四处副本，不同步测试文件。DESIGN 0.5.1 L29 把测试挂靠点写成 `flow-kit-bundle/test/test_l3_pipeline_fix.bats`（打包源），与 TASK 写 `test/`（开发源）路径不一致，且两处均未声明双源同步义务。实测：`test/test_l3_pipeline_fix.bats`（inode 2020679）与 `flow-kit-bundle/test/test_l3_pipeline_fix.bats`（inode 2020706）是**独立物理文件**（非 symlink）；当前 `diff -rq test/ flow-kit-bundle/test/` 为空（恰在同步态）。
**Source（源头）**：Makefile `check-test-sync`（L62）执行 `diff -rq test/ flow-kit-bundle/test/`，不一致即 `exit 1`；`make check`（L66）= `test lint check-validate check-test-sync`，由 pre-push hook 自动调用（CONTEXT.md「make check … pre-push hook 自动调用」）。且 `make test-sync`（L54）仅 `cp test/*.bats flow-kit-bundle/test/`，**不覆盖 fixtures/** 子目录。CONTEXT.md「双源测试同步」约定 + L-031 教训（触碰模块清单漏列跨文件批量修改点）。
**Consequence（后果）**：改动落地后 `test/` 与 `flow-kit-bundle/test/` 漂移（新增 5 fixture + 修改的 bats 只在 dev 源），`make check` 的 check-test-sync 必失败 → pre-push 阻塞，AC-6「无 fail/skip」基线无法达成；打包源 `flow-kit-bundle/test/` 携带旧测试 → `package-flow-kit.sh` 产出的 bundle 缺失 AC-1~7 覆盖，回归防护静默失效。
**Remedy（修补）**：给 T05（或新增 T06.5 前置步骤）补双源同步，二选一：
- 方案 A（推荐）：T05 action 增加「`make test-sync`（.bats）+ 显式 `cp test/fixtures/independent-review-*.md flow-kit-bundle/test/fixtures/`（因 test-sync 不覆盖 fixtures）」；T05 verify 增加 `make check-test-sync` 通过断言。
- 方案 B：把 fixtures 同步纳入 `make test-sync`（`cp -r test/fixtures flow-kit-bundle/test/`），再统一走 test-sync；同时 DESIGN 0.5.1 触碰模块清单补 `flow-kit-bundle/test/`（打包源）与同步义务。

### 🟡 R6 · 溢出/超配额 fixture 缺失：AC-4 ① `(+k more)` 折叠行为无定义测试输入
**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT AC-4 验证方式（L44）要求「溢出 fixture 验证 `(+k more)` 裁剪标记」；T05 action（L150）引用「超配额 fixture」；但 T02 write_files（L61-65）的 5 个 fixture（l2/l3/mixed/no-response/empty）无一为溢出样本，T03/T05 的 write_files 也不创建新 fixture。且 T03 action 的单元测试清单（第 6 点）只列 no-response / mixed / empty 三例，**不含配额折叠用例**（T02 action 明写「不测配额折叠——配额在 T03」，但 T03 未接）。
**Source（源头）**：REQUIREMENT AC-4 ①（L43）「溢出时末尾追加 `(+k more)` 标记」+ 验证方式「溢出 fixture」；TASK T02 write_files vs T03 action vs T05 action 三处对折叠测试输入的归属未闭环。
**Consequence（后果）**：`(+k more)` 折叠逻辑（AC-4 ① 核心行为之一）在 T03 单元层零覆盖、在 T05 端到端层引用一个不存在的「超配额 fixture」——要么测试用内联合成输入（偏离固化 fixture 语义、与 T02 样本脱钩），要么折叠逻辑事实上无 AC 断言覆盖，回归时静默失效。
**Remedy（修补）**：二选一：
- 方案 A（省）：T03 action 显式写明折叠用例用「降低 600B 配额参数 + mixed/l3 fixture」触发溢出并写清断言（不改 fixture 集）；T05「超配额 fixture」措辞改为「超配额触发（降配额）」。
- 方案 B（明确）：T02 write_files 增补第 6 个溢出 fixture（如 `independent-review-overflow.md`，含 >N 条 critical/major 使 600B 配额必溢出），T03/T05 直接引用。

**Verdict**: fail

---

## 主 agent 响应（复审轮）

- **R5（🔴 测试双源同步缺失）** — Fixed in: TASK.md（T06 更名「全量同步」，action 增 `make test-sync` + 显式 `cp -r test/fixtures/. flow-kit-bundle/test/fixtures/` + `make check-test-sync` 收口；write_files 增 `flow-kit-bundle/test/*`；verify 命令追加 `&& make check-test-sync`；done 增「6 fixtures 双源一致」）+ DESIGN.md（§0.5.1 触碰清单增 `flow-kit-bundle/test/` 双源同步目标条目与 `test/fixtures/` 6 fixtures 条目；D8 决策增测试双源同步方案与备选 c 及其否决理由）。实证采纳：`make test-sync` = `cp test/*.bats`（Makefile:53）不含子目录；`make check` 含 `check-test-sync`（diff -rq 递归双向）。
- **R6（🟡 溢出 fixture 缺失）** — Fixed in: TASK.md（T02 write_files 增 `test/fixtures/independent-review-overflow.md`，action 固化样本改六类、溢出样本 ≥6 条 findings 使 600B 配额必溢出；T03 单元测试第 1 条接 overflow fixture 断言 `(+k more)` 折叠行）+ DESIGN.md（§0.5.1 fixtures 条目同步 6 个）。配额折叠属注入层（T03 实现），提取层（T02）不预支断言。

---

## L2 盲审（第三轮）

> 复审范围：验证复审轮 R5–R6 修复落地 + 独立重扫新问题（L-031 全仓一致性 grep + 既有测试断言对账）。已读工件：TASK.md / REQUIREMENT.md / DESIGN.md / INDEPENDENT-REVIEW-3.md（首轮 + 复审轮 + 两轮主 agent 响应）；实测 l3-prompt.sh（157 行）、l3-review.sh（246 行）、Makefile（82 行）、test/test_l3_pipeline_fix.bats（173 行）。

**首轮 R1–R4 + 复审轮 R5–R6 修复确认（全部正确落地）**：
- R1 ✅ 方案 A 落定：T03 action 第 5 条 / T04 action 首段 / DESIGN §0.5.3、D1、§2 均改为「`_l3_inject_context` 调用关系不变，生产拼接方 = l3-review.sh:81/L103」。实测 l3-review.sh:81（--background 路径）+ :103（同步路径）为仅有两处 `_l3_inject_context` 调用，`_l3_build_prompt`（l3-prompt.sh:53-157）不调用它。无双重注入。
- R2 ✅ D4 锚 ③ 已去 `^` 行首锚，改行内 `(Fixed in|Tech-debt|Not-applicable):` + 实证格式 `- **R1** — Fixed in:`。
- R3 ✅ Wave 4 行 `(depends on T01, T03)` 与 T04 `<depends_on>T01, T03</depends_on>` 对齐。
- R4 ✅ T04 verify 收紧为 `grep -c 'head -c' -eq 2`；T01 action 增「两 helper 各恰好 1 处 head -c」约定。
- R5 ✅ T06 更名「全量同步」，action 增 `make test-sync` + `cp -r test/fixtures/. flow-kit-bundle/test/fixtures/` + `make check-test-sync` 收口；write_files 增 `flow-kit-bundle/test/*`；verify 追加 `&& make check-test-sync`。实测 Makefile:53 `test-sync` = `cp test/*.bats`（不含子目录）、Makefile:62 `check-test-sync` = `diff -rq test/ flow-kit-bundle/test/`（递归双向）。方向一致（test/ → bundle）。
- R6 ✅ T02 write_files 增 `independent-review-overflow.md`（6 fixtures 齐）；T03 单元测试第 1 条接 overflow fixture 断言 `(+k more)` 折叠行。

**D7 13 位点实证复核（L-031）**：实测 `grep -n 'head -c' l3-prompt.sh` 恰 13 处，与 D7 分类精确一致——10 文件路径形（L60/66/73/80/86/106/122/132/139/143）+ 3 流形（L115/118/145）。L91-92（phase 6）与 L127-128（phase 7）两处 `dirname ×2` 同构位点确认存在，D5 归档布局 `dirname ×3` 修法正确（`<repo>/.specs/archive/<id>/` → ×3 解析到 `<repo>`）。L156 JSON schema 与 D3「无 severity 字段」实证一致。

### 🟡 R7 · `_l3_inject_context` 重写静默丢弃 verdict 注入（l3-pipeline-fix-2026-07 D4 行为），无设计决策，且破坏既有 test_l3_pipeline_fix.bats AC-5 测试
**Severity**：🟡 Important
**Symptom（症状）**：现 `_l3_inject_context`（l3-prompt.sh:26-48）输出「前次审查上下文」verdict 摘要块（`- **Verdict**` / `- L3 Verdict:` / `主 agent 已响应前次发现` 四行）。T03 action 1–4 点将函数整体重写为「发现摘要 + 响应要点 + 未响应标注 / 静默」，**无任何一点保留 verdict 注入**。既有测试 `test/test_l3_pipeline_fix.bats:106-132`（`@test "AC-5: _l3_inject_context injects prior review context with disclaimer"`）构造 mock `INDEPENDENT-REVIEW-1.md`（含 `**Verdict**: pass` + `## 主 agent 响应` + `Fixed in: REQUIREMENT.md`，但**无 `### 🔴`/`### 🟡` 行、无 critical/major JSON**），断言 `[[ "$preamble" =~ 审查上下文 ]]`。重写后该 mock 的发现集为空（AC-7），verdict 文本已删 → `preamble` 空/不含「审查上下文」→ 断言必红。
**Source（源头）**：DESIGN D2/D3/D4 只描述发现/响应/标注三块，§5 风险表（R1–R6）无一登记「verdict 注入被移除」；T05 action 将回归成因定为「因 prompt 段序变化而失败的既有断言」（只点名 test_l3_review / test_hook_integration / l3-truncation，**漏点名实际会红的 test_l3_pipeline_fix.bats**），且「段序变化」误判了真实成因（实为「verdict 注入语义移除」，非段序调整）。CONTEXT「L3 上下文注入」（L-040 限制⑤ fix）明确该函数职责含「前次 verdict + L2 verdict」。
**Consequence（后果）**：① `make test` 回归——test_l3_pipeline_fix.bats AC-5 红，若 T05 按「只修断言锚点」盲删 `=~ 审查上下文` 而不识破语义移除，则 L-040 限制⑤ 的「verdict 上下文」静默丢失（重审模型失去「上次 verdict」信号），假阳性循环的部分诱因复活；② T05 回归范围与真实破坏点失配，AC-6「无 fail/skip」基线有被「改断言遮语义」的风险。
**Remedy（修补）**：DESIGN 须显式落定 verdict 注入去留（二选一）：方案 A（推荐·保留）——T03 重写时在发现摘要之上**保留** `- **Verdict**: ... / - L3 Verdict: ...` 两行，T05 把 test_l3_pipeline_fix.bats AC-5 断言改为「含 verdict 行」；方案 B（移除）——DESIGN D 决策表新增一条「verdict 注入随 findings 注入取代」+ 理由（findings 信息密度 > bare verdict），T05 显式点名 test_l3_pipeline_fix.bats AC-5 为语义对齐目标（改断言为新行为），并在 ADR-025 Consequences 记录该行为变更。无论哪案，T05 回归清单必须显式点名 test_l3_pipeline_fix.bats。

### 🟡 R8 · AC-7 静默条件（「两类提取源皆空」）与 T03 第 4 点（「findings 与响应要点皆空」）不一致，致「有响应但无发现」边界场景行为未定义
**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT AC-7（L63）静默条件是「两类提取源皆空」= 无 L2 🔴/🟡 且无 L3 critical/major（即**仅 findings 为空即静默**）；T03 action 第 4 点（L100）写「findings **与响应要点皆空** → 整段静默」。两者对「findings 空但响应检测命中」的边界：AC-7 → 静默；T03 第 2 点（响应检测三锚命中即提取要点 ≤200B，无 findings 前置条件）→ 注入响应要点。该边界恰被既有 mock（`## 主 agent 响应` + `Fixed in:` 但无 findings）命中——实现路径会为「无发现的首轮文件」注入一条孤零零的响应要点，违反 AC-7 静默语义。
**Source（源头）**：AC-4 ② 的 Given 是「已含前轮发现…与响应段」，语义上「响应」是对「发现」的回应，无发现即无响应对象；但 T03 未把响应提取前置到「findings 非空」，导致静默判定与响应提取两处条件解耦。
**Consequence（后果）**：首轮审查（无 findings）若文件碰巧含 `## 主 agent 响应` 段头或 `Fixed in:` 字样，重审 prompt 会注入无意义的响应要点、破坏 AC-7 静默契约；T03 单元测试（empty fixture → stdout 为空）可能通过（empty fixture 无响应段），但真实文件带响应段时行为与 AC-7 不符，属测试未覆盖的边界。
**Remedy（修补）**：统一静默/注入判定为「**findings 非空**」为唯一前置——T03 第 4 点改为「findings 空 → 整段静默（无摘要无标注，exit 0）（AC-7）」；T03 第 2 点响应提取加前置「仅当 findings 非空时执行响应检测与要点提取」；T03 单元测试补「有响应段但无 findings 的 fixture → stdout 为空」负例。

### 🟡 R9 · AC-6「四处副本 md5 一致性」无硬断言：T06 verify 的 md5sum|wc -l 只打印不 gate，且未计入 bats 用例
**Severity**：🟡 Important
**Symptom（症状）**：T06 verify（L179）为 `md5sum <4 files> | awk '{print $1}' | sort -u | wc -l && make check-test-sync`——`wc -l` 只**打印**唯一 md5 数（"1" 或 "4"），恒 exit 0，从不 gate；`make check-test-sync`（Makefile:62）只 diff `test/` ↔ `flow-kit-bundle/test/`，**不覆盖** hooks 四处 l3-prompt.sh 副本。故「仓库内四处副本内容一致」无任何硬性失败路径——副本漂移时 verify 打印 "4" 仍 exit 0、`make check`（test/lint/check-validate/check-test-sync）四项无一触碰 hooks 副本。
**Source（源头）**：REQUIREMENT AC-6（L56）明写「仓库内四处副本内容一致（**自动化断言，计入 bats 用例**）」；TASK AC→任务映射表（L196）将 AC-6 验证层归为「命令」（非「bats 用例」），T06 verify 用裸 md5sum 而非 bats 用例，且不做值断言。与 R4 同型（「verify 弱代理」——可打印不可证伪），但作用对象是 AC-6 核心不变量。
**Consequence（后果）**：四处副本（bundle 源 + .claude 运行时 + dist×2）一旦漂移（如后续 change 只改 bundle 源忘 cp），无任何 gate 拦截；打包产出的 dist/vendor 副本静默携带旧逻辑，回归防护失效。verify 的「证伪性」不达标（阶段 3 checklist「verify 是否可机器执行且能证伪」）。
**Remedy（修补）**：二选一：方案 A——T06 verify 改为硬断言 `[ "$(md5sum <4 files> | awk '{print $1}' | sort -u | wc -l)" -eq 1 ]`；方案 B——按 AC-6 原文，在 test/ 新增 bats 用例断言四处 md5 一致（`run md5sum ...; [[ 唯一值数 -eq 1 ]]`），T05/T06 挂靠该用例，AC→任务映射 AC-6 验证层改「bats 用例」。

### 🟢 R10 · T02 done 字段「五类 fixtures」残留，与 R6 修复后的「六类」不一致
**Severity**：🟢 Minor
**Symptom（症状）**：T02 write_files（L61-66）已列 6 fixtures（含 overflow），action（L75）写「六类样本」；但 T02 done（L79）仍写「五类 fixtures 提取断言全绿」。
**Source（源头）**：R6 修复新增第 6 个 overflow fixture 时，同步更新了 write_files 与 action，漏更新 done 字段。
**Consequence（后果）**：无功能后果，仅 done 声明与 action/write_files 计数不一致（6 vs 5），审计噪声。
**Remedy（修补）**：T02 done「五类」改「六类」。

**Verdict**: pass

---

## 主 agent 响应（第三轮）

- **R7（🟡 verdict 注入静默丢弃）** — Fixed in: TASK.md（T03 action 第 3 条：L2/L3 verdict 行 + 「审查上下文」disclaimer 行保留——l3-pipeline-fix-2026-07 D4 行为不回退，bats:106-132 既有断言锚向后兼容；单元测试清单补「既有 AC-5 用例保持绿」）+ DESIGN.md（D2 决策行补 verdict 行保留条目）。
- **R8（🟡 静默条件不一致/边界未定义）** — Fixed in: TASK.md（T03 action 第 4 条改四象限边界矩阵：findings 有+响应有→全注入 / findings 有+响应无→摘要+未响应标注 / findings 无+响应有→verdict+响应要点（无标注，响应存在即信号）/ findings 无+响应无→整段静默）+ DESIGN.md（D2 决策行补边界矩阵）。REQUIREMENT AC-7 Given（「两类提取源皆空」）与新矩阵无矛盾——矩阵第 3 象限超出 AC-7 Given 范围，属 DESIGN 层规范扩展。
- **R9（🟡 md5 一致性无硬断言）** — Fixed in: TASK.md（T06 action 新增「AC-6 bats 硬断言」条目——test_l3_pipeline_fix.bats 新增四处 md5 sort -u 唯一值=1 用例，不满足即 fail，满足 AC-6「计入 bats 用例」；write_files 增 test/test_l3_pipeline_fix.bats；verify 改 `[ md5|wc -l -eq 1 ] && bats && make check-test-sync` 三重硬 gate；用例在同步完成后编写并同 task 双源同步，避免 T05 全量跑先红）。
- **R10（🟢 done 字段五类/六类不一致）** — Fixed in: TASK.md（T02 done 改「六类 fixtures」）。

---

## L3 重审（glm-5.3-flash 外部模型 · 2026-09-04 19:27）

> 自动生成于 2026-09-04 19:27。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"任务清单/T04（AC-1 端到端测试项）","issue":"AC-1「反馈段先于工件正文（截断前提下存活）」的验证落在 _l3_build_prompt 单调用上，而该输出明确不含反馈段；组合调用侧仅有 AC-5 no-response 场景断言「未响应标注在最前部」，mixed（有 findings）场景无反馈段先于工件正文的顺序断言，组合输出总大小（注入 ~800B 叠加 20000B 预算后）也无任何断言","why":"映射表宣称 T04 端到端覆盖 AC-1，但所述断言无法证伪「反馈段先于工件正文」这一定义属性；组装层前置与截断预算的交互未被任何测试钉住，AC-1 实际处于弱覆盖状态","fix":"在 T04/T05 组合调用测试中显式断言反馈段标记位置 < `=== CHANGELOG.md ===` 位置（mixed 与 no-response 各一），并在 ≥1500B fixtures + 满载工件场景断言组合输出中反馈段完整存活；AC-1 映射补列 T05"},{"file":"任务清单/T03（四象限边界矩阵）","issue":"第4象限「findings 无 + 响应无 → 整段静默（无 verdict）」与第3条「保留既有注入项：L2/L3 verdict 行」在「文件存在、仅有 `**Verdict**: fail`、findings 与响应均不可提取」子情形上冲突未定义；且 fixtures 无 verdict-only 样本钉住该行为","why":"按矩阵实现会静默丢弃前轮 fail 结论（与本次改动让前轮结论进入 prompt 的目标相悖），按第3条实现则违反第4象限与 AC-7 断言；两种读法测试结果不同，实现无法被现有用例唯一约束","fix":"显式定义该子情形（建议：文件存在且可解析出 verdict 时保留 verdict 行，仅文件缺失/空才整段静默），新增 verdict-only fixture 与对应断言，并同步 DESIGN D4"}],"minor":[{"file":"任务清单/T06","issue":"done 声称「~/.claude 全局副本已部署（人工确认）」，但 verify 仅覆盖仓库内四处，仓库外部署不可证伪","why":"verify 与 done 不对应，人工步骤无机器门禁，易漏部署且事后无法审计","fix":"verify 增加存在性门控的 md5 断言（如 `[ -f ~/.claude/hooks/stop/lib/l3-prompt.sh ] && md5sum ~/.claude/... 与 bundle 同值`），或将该项移出 done 改为独立人工清单项"},{"file":"任务清单/T04（verify）","issue":"`grep -c 'head -c'` 统计命中行数而非出现次数，注释行含该串或单行多次出现均会误判 -eq 2","why":"精确计数是该 verify 证伪能力的核心，行计数语义偏差会产生假阳/假阴","fix":"改为 `grep -o 'head -c' <file> | wc -l`，必要时过滤注释行"},{"file":"任务清单/T06","issue":"同步四副本 + 新增 md5 用例 + 双源同步后，verify 仅跑单测试文件与 check-test-sync，未收口全量 bats","why":"T05 的全量绿基线建立在同步之前，同步动作对其他依赖仓库状态的用例影响不可见，存在回归缺口","fix":"T06 verify 追加 `bats test/`（或 make check）作为收口"},{"file":"任务清单/T06","issue":"write_files 含 `test/test_l3_pipeline_fix.bats`（新增 md5 用例），但 read_files 未列该文件","why":"写前需读的边界约定不自洽，审计时无法确认修改基于最新文件内容","fix":"read_files 补 `test/test_l3_pipeline_fix.bats`"}],"verdict":"pass","summary":"拆解覆盖全部 7 个 AC、依赖严格无环（T01→T02→T03→T04→T05→T06，T04 双依赖合规）、write 边界基本清晰；主要缺口为 AC-1 组合层顺序/总量断言缺失与 T03 第4象限同 verdict 保留规则的冲突未定义，均为可修复的 major，不构成 fail。"}
```

L3_artifact_hash: dfd04c0d6ca93ff3b385fa144ebee0e709df44076218283423422e2d285a7793

---

## 主 agent 响应（L3）

- **Major-1（AC-1 组合层断言缺失）** — Fixed in: TASK.md（T04 新增「AC-1 组合层顺序断言」测试项：mixed 与 no-response 两 fixture 组合输出中反馈段标记字节位置 < `=== CHANGELOG.md ===` 位置 + ≥1500B 满载下反馈段完整存活；T05 补对应独立 @test 固化；AC 映射表 AC-1 补列 T05）。组装层前置与 20000B 预算的交互现被测试钉住。
- **Major-2（第 4 象限与 verdict 保留冲突）** — Fixed in: TASK.md（T03 边界矩阵第 4 象限拆分：文件存在且 verdict 可解析 → 仅 verdict 行（前轮 fail 结论不静默丢弃）；文件缺失/空/verdict 不可解析 → 整段静默；单元测试补 verdict-only fixture 断言）+ TASK.md T02（第 7 个 fixture `independent-review-verdict-only.md` + 样本清单/单元测试/计数同步七类）+ DESIGN.md（D2 边界矩阵同步细化）。
- **minor-1（~/.claude 部署不可证伪）** — Fixed in: TASK.md（T06 verify 追加存在性门控 cmp 断言：`[ ! -f ~/.claude/... ] || cmp -s bundle ~/.claude/...`）。
- **minor-2（grep -c 行计数语义偏差）** — Fixed in: TASK.md（T04 verify 改 `grep -o 'head -c' | wc -l` 逐次计数）。
- **minor-3（T06 缺全量收口）** — Fixed in: TASK.md（T06 verify 改 `md5 gate && make check && cmp gate`——make check 覆盖全量 bats + lint + validate + check-test-sync）。
- **minor-4（read_files 缺 bats）** — Fixed in: TASK.md（T06 read_files 补 test/test_l3_pipeline_fix.bats）。
