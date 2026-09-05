# 独立审查 · 阶段 5

## L2 盲审

> 审查对象：`.specs/l3-prompt-loop-fix/TEST.md`（参考 REQUIREMENT.md / TASK.md）。独立性声明：本次仅依据指定工件与仓库实测（实跑 `npx bats test/`、md5sum 四副本、逐文件 @test 计数），未引用任何主 agent 自评。

---

### 🟡 R1 · 「0 fail / 0 skip」声明失实：套件实含 1 个 skip，且 skip 检测 grep 方法无法检出 bats skip

**Severity**：🟡 Important
**Symptom（症状）**：`TEST.md:42-45` 声称 `grep -cE '^(not ok|# skip)'` 返回 0 即「0 skip」。但 bats TAP 格式下 skip 报告为 `ok N <name> # skip <reason>`（`# skip` 位于行尾，非行首），故 `^(not ok|# skip)` 永不匹配真实 skip——该检测是**空洞的**。实测 `npx bats test/` 套件含 1 个 skip：`test/test_lessons_cleanup.bats:137`（`skip "AC-4 需要全量覆盖环境；当前仓库已知有 gap，exit=1 是正确的"`），TAP 输出第 629 行 `ok 629 ... # skip ...`。实测结论：801 total = 800 pass + 1 skip，0 fail，exit 0。
**Source（源头）**：AC-6（`REQUIREMENT.md:55-58`）要求「全量 bats 无 fail/skip」；项目 LESSONS 的「假绿」类教训（L-025 / TD-012 / BUG-G）均将「声明全绿但实际不符」列为 Critical 级失败模式。
**Consequence（后果）**：报告对「无 skip」的验证形同虚设——即使套件出现数十个 skip，该方法仍报「0 skip」；AC-6 的「无 skip」要求既未满足（1 skip）又无法被该方法证伪，构成假绿。
**Remedy（修补）**：① 将 skip 检测改为匹配行内 `# skip`（如 `grep -cE '# skip '`）或改用 `bats --formatter junit` 解析 `<skipped>` 计数；② 在 TEST.md §1.3 如实披露这 1 个**既有、与本次 change 无关**的 skip（test_lessons_cleanup.bats:137，属 package-flow-kit.sh `--validate` 覆盖 gap，非 l3-prompt-loop-fix 引入），或显式声明 AC-6「无 skip」以「无本次新增 skip」口径执行。**注意**：该 skip 为前存且 out of scope，不构成本 change 的 🔴——但报告的失实声明必须修正。

---

### 🟡 R2 · AC-4 配额子规则 ②（响应 ≤200B）与 ③（总量 ≤800B）无测试覆盖，TEST.md §2 性能轮过度声明

**Severity**：🟡 Important
**Symptom（症状）**：`TEST.md:76` 性能轮声称「反馈段 ≤800B（摘要 600 + 响应 200）| T03 配额用例逐字节累加断言 | ✅」。但 `test/test_l3_pipeline_fix.bats` 中唯一的字节预算断言在 T03 quota 用例（`:414-415`）——`bytes=$(... grep -E '^(critical|major)\||^\(\+' | wc -c); [ "$bytes" -le 640 ]`——**仅**校验发现摘要段（600B 配额）与 `(+k more)` 折叠行合计 ≤640B。无任何用例断言：② 响应要点段 ≤200B、③ 前轮反馈注入总量 ≤800B。
**Source（源头）**：AC-4（`REQUIREMENT.md:43`）明确定义三条配额规则：① 摘要 `severity|file|issue` ≤600B（溢出 `(+k more)`）② 响应要点逐条分类标记行 ≤200B ③ 总量 ≤800B；非功能需求（`REQUIREMENT.md:89`）「前轮反馈注入总量 ≤ 800 字节」。代码实现（`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:216-223`）确有 200B 逻辑 + `head -8`，但无测试钉住。
**Consequence（后果）**：若响应要点超过 200B 或反馈总量超过 800B 的回归被引入，全量 bats 仍全绿——NFR 与 AC-4 的字节预算约束实际处于无保护状态，弱模型下极易回退。
**Remedy（修补）**：新增一条配额用例（fixture 含 30 条 findings + 多条 `Fixed in:` 行），断言：① 响应要点段 `wc -c ≤ 200`；② 整段注入（`_l3_inject_context` stdout）`wc -c ≤ 800`（或 verdict+摘要+响应三部分合计）。修正 TEST.md §2 的「逐字节累加」表述以匹配实际断言范围。

---

### 🟢 R3 · test_l3_pipeline_fix.bats 头部注释陈旧（文件名与 AC 列表误导）

**Severity**：🟢 Minor
**Symptom（症状）**：`test/test_l3_pipeline_fix.bats:2-3` 头部注释仍写「L3 管线修复行为级测试（l3-pipeline-fix-2026-07）」与「覆盖 AC-1~AC-5 + AC-8」；该文件现承载两个 change 的用例（旧 l3-pipeline-fix 的 AC-1~AC-8 + 本次 l3-prompt-loop-fix 的 T01-T06 / AC-1~AC-7）。
**Source（源头）**：命名/文档一致性（CONTEXT.md 命名约定）。
**Consequence（后果）**：读者误判文件归属与覆盖范围，维护时易误删/误改对应用例。
**Remedy（修补）**：更新头部注释为两段式（旧 change 段 + 本次 change 段），或注明「本文件承载 l3-pipeline-fix + l3-prompt-loop-fix 两 change 用例」。

---

### 🟢 R4 · 回归登记表「数量」口径不一致（表合计 36 ≠ 文件 39）

**Severity**：🟢 Minor
**Symptom（症状）**：`TEST.md:103-110` 回归登记表「数量」列合计 7+7+11+5+4+2=36，其中 T03 记为「11（新增 6 + 改写既有 5）」；而文件实测 39 个 @test（8 既有 + 31 新增），`TEST.md:49` 的「8→39（+31）」与实测一致。表内「数量」列混合了「新增」与「改写既有」两口径，与 1.3 的「+31」口径矛盾（36 ≠ 31 ≠ 39）。
**Source（源头）**：测试登记口径一致性。
**Consequence（后果）**：登记表无法与 git diff 精确对账，弱化「回归测试是否全量登记」的审计能力。
**Remedy（修补）**：统一「数量」列为单一口径（建议纯「新增」=31），「改写既有」另列或并入备注；使表合计与「8→39」自洽。

---

### 🟢 R5 · TEST.md 1.1 AC-1 矩阵声称「JSON 契约永不被切」但无对应断言

**Severity**：🟢 Minor
**Symptom（症状）**：`TEST.md:27` AC-1 行写「T04 'AC-1 ①总输出≤20000 字节 + JSON 契约永不被切'」，但 `test/test_l3_pipeline_fix.bats:432-446`（T04 AC-1）仅断言 total≤20000 / >10000 / CHANGELOG+LESSONS 标记存活 / `pos_cl < pos_art`，未断言 JSON 契约（jq 指令前导）存活。
**Source（源头）**：测试矩阵描述与实现对齐。
**Consequence（后果）**：矩阵过度声明了测试能力；JSON 契约靠「指令前置 + 尾部截断」的设计性质保证，但无回归锚，未来重排若破坏该性质不会被捕获。
**Remedy（修补）**：要么在 T04 AC-1 用例加一条断言（grep `"critical":[` 或 `审查重点` 指令锚仍在输出前部），要么从矩阵行删去「JSON 契约永不被切」表述。

---

**Verdict**: pass

> 说明：本次未发现 🔴 Critical（AC-1~AC-7 均有真实、可运行、全绿的 bats 用例；四副本 l3-prompt.sh md5 唯一值=1 已实测一致；fixtures 双源已就位）。2 条 🟡 建议入 fix loop（R1 修正「0 skip」失实声明 + 检测方法；R2 补齐 AC-4 配额子规则 ②③ 测试），3 条 🟢 写入 MINOR-DEFERRED.md。

---

## 主 agent 响应

> 按 Severity Gating 协议：🟡 入 fix loop（task 内解决），🟢 写入 MINOR-DEFERRED.md（phase 7 triage）。

- **R1** — Fixed in: `.specs/l3-prompt-loop-fix/TEST.md` §1.3（skip 检测改 `grep -cE '# skip '` 三段命令如实记录 801=800 pass+1 skip；披露既有 skip 归属 `test_lessons_cleanup.bats:137` / `ce482c4`，AC-6 按「0 fail + 0 新增 skip」口径）+ `T05-SUMMARY.md` 勘误段。
- **R2** — Fixed in: `test/test_l3_pipeline_fix.bats` 新增用例「T05fix: AC-4 quota ② response essentials <=200B and ③ total variable content <=800B」（fixture 30🔴+12 条 Fixed in 响应行；断言响应要点内容 ≤200B、发现行内容+响应内容合计 ≤800B、(+ 折叠在场；实测一次绿 ok 40，行为已实现属回归钉住）+ `TEST.md` §2 性能轮表述对齐实际断言范围。
- **R3** — Not-applicable（🟢 不入 fix loop）→ MINOR-DEFERRED.md M4。
- **R4** — Not-applicable（🟢 不入 fix loop）→ MINOR-DEFERRED.md M5。
- **R5** — Not-applicable（🟢 不入 fix loop）→ MINOR-DEFERRED.md M6（设计性质保证 + 矩阵表述收紧可在 7-integration triage 时一并处理）。

---

## L3 重审（glm-5.3-flash 外部模型 · 2026-09-05 02:15）

> 自动生成于 2026-09-05 02:15。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[{"file":"TEST.md §步骤N 回归登记表","issue":"登记表用例数总和（7+7+11+5+4+2=36）与 §1.3 声明的文件用例总数 39（8→39）不闭合：新增 31 与改写 5 可追溯，但仍有 3 个既有用例未归属任何 T 组，回归登记不完整","why":"回归登记应可完整审计全部既有用例的去向；36≠39 的差额无工件内解释，无法确认那 3 个既有用例是否仍被有效守护","fix":"补登缺失的 3 个既有用例所属用例组（或显式说明其并入哪个 T 组/为何不入组），使登记数量与 §1.3 的 39 闭合"},{"file":"TEST.md §1.2 UAT","issue":"AC-6 的 ~/.claude 全局 cmp gate 为存在性门控，在无全局部署的环境（如干净 CI）中平凡通过，该子断言可能长期从未真正执行且不体现为 skip","why":"平凡通过会让 AC-6 全局一致性子项在流水线中获得虚假绿灯，与套件『0 新增 skip』口径下 skip 不可见的结构性问题同源","fix":"改用 HOME 重定向到临时目录并预置全局副本的 fixture 使 cmp 断言无条件执行；至少在缺失分支输出显式『# skip (no global deploy)』标记，保持 TAP 层可审计"},{"file":"TEST.md §1.5 T4 / §1.1 AC-1","issue":"T05 端到端断言依赖『组装复刻』（复刻 l3-review.sh:81-104 拼接）生成期望，复刻复制实现逻辑，存在同义反复与随实现漂移后锚定影子实现的风险","why":"若实现演化而复刻被手工同步修改，T05 的字节位/排序断言将不再守护真实组装路径；当前仅 T04 的手写期望提供独立纠错","fix":"在 T05 增加复刻产物与真实 build_prompt 实际输出的 diff/cmp 一致性护栏断言，并在工件中注明复刻仅作期望生成器、真实路径守护以 T04 手写期望为准"}],"verdict":"pass","summary":"前轮两项 major（bats skip 检测 grep 方法、AC-4 配额子规则②③覆盖缺口）已在本版实质修复且数字自洽，AC-1~7 矩阵全覆盖、0 fail、UAT 全自动化可复现、回归与双源镜像同步齐备；遗留回归登记计数不闭合、存在性门控平凡通过、组装复刻漂移三项 minor，不构成放行障碍。"}
```

L3_artifact_hash: a8eff3a9658d39c242748c459210b22f8440486a542299f9f5aab14aa4c0a944

---

## 主 agent 响应（L3）

- **L3 Minor-1**（登记表 36≠39，3 个既有用例未归属）— Not-applicable（🟢 不入 fix loop）→ MINOR-DEFERRED.md M7（与 M5 同源，7-integration triage 时一并补归属注记）。
- **L3 Minor-2**（cmp gate 存在性门控平凡通过）— Not-applicable（🟢 不入 fix loop）→ MINOR-DEFERRED.md M8。
- **L3 Minor-3**（组装复刻影子实现风险）— Not-applicable（🟢 不入 fix loop）→ MINOR-DEFERRED.md M9。注：T04 手写期望断言（AC-1/2/3 单调用路径）即为独立纠错层，与 L3 建议一致。
