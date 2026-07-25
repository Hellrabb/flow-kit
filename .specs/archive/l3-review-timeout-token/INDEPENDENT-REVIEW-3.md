# 独立审查 · 阶段 3

> 阶段 3（task 拆解）L2 盲审。审查员独立判断，未引用任何主 agent 结论或外部陈述。
> 工件：`.specs/l3-review-timeout-token/TASK.md`（参考 REQUIREMENT.md / DESIGN.md），并交叉核验源码 `flow-kit-bundle/hooks/stop/lib/l3-review.sh` 与 `test/test_l3_review.bats` 以验证 TASK 的事实性引用。

---

## L2 盲审

### 🟡 R1 · 依赖图缺陷：T02 对 T01 存在数据依赖却被标 parallel
**Symptom**：TASK.md:67 将 `.specs/l3-review-timeout-token/T01-SUMMARY.md` 列入 T02 的 `<read_files>`；TASK.md:90 T02 action 明确写「据 T01 实测证据定默认值（若 R4 发现代理上限 < 32000，下调）」；但 TASK.md:61 `<task id="T02" parallel="true">` 且 TASK.md:94 `<depends_on></depends_on>` 为空。Wave 注释 TASK.md:14 自身亦写「T01 先行收证据，T02 据证据定默认值」——叙述是串行，XML 却标并行，自相矛盾。
**Source**：任务拆解规格要求依赖图无环且 `depends_on` 反映真实数据依赖；存在 read_files + action 逻辑双重数据依赖时，depends_on 须显式声明。经典原则：依赖关系须在机器可读契约（depends_on）中忠实表达，而非仅在散文注释中。
**Consequence**：调度器读 depends_on=空 → 让 T01/T02 真并行；T02 先于 T01 完成时读取不存在的 T01-SUMMARY.md（严格 file-guard 下直接报错），或拿不到 R4 代理上限证据而把默认值 32000 写死——而 R4（DESIGN 风险表）正是「阿里云代理可能拒 32000」的未验证断言，T02 不据证据下调即把 R4 风险固化进默认值。并行标记使 T01 的探针证据无法回流到 T02 的默认值决策，解套主路径（Path 1 阿里云代理）的正确性失去保障。
**Remedy**：将 T02 改为 `<depends_on>T01</depends_on>` 并移出 Wave 1，或拆为 Wave 1a(T01) → Wave 1b(T02)；同时在 T01 的 write_files 显式声明 T01-SUMMARY.md（见 R2），使 T01→T02 的文件依赖在写/读图上可见。

### 🟡 R2 · write_files 声明缺失：T01 与 T04 实际写文件却声明为空
**Symptom**：T01 action（TASK.md:54「结果全记 T01-SUMMARY.md」）+ verify（TASK.md:56 `test -f .../T01-SUMMARY.md`）证明 T01 创建 T01-SUMMARY.md，但 T01 write_files（TASK.md:45-47）为空且注释自相矛盾「无文件修改，纯探针 + 写 SUMMARY」。T04 action（TASK.md:142 `make test-sync`）执行 `cp test/*.bats flow-kit-bundle/test/`（Makefile test-sync 已确认写 flow-kit-bundle/test/test_l3_review.bats），但 T04 write_files（TASK.md:137-139）为空。禁动清单遵守声明（TASK.md:173-177）据此谎报「T01: 无 write_files」「T04: 无 write_files」。
**Source**：阶段 3 checklist「read_files/write_files 约束是否到位」——write_files 须如实声明任务全部写表面，作为 file-guard 允写清单与依赖图可见性依据。
**Consequence**：在以 write_files 为 allowlist 的执行器下，T01 写 T01-SUMMARY.md 与 T04 经 make test-sync 写 flow-kit-bundle/test/test_l3_review.bats 会被 gate 拦截，任务无法完成；即使 gate 宽松，未声明的写使 T01→T02 的文件依赖在静态依赖分析中不可见（叠加 R1，依赖链双重隐形）。注：两文件均不在 DESIGN §0.5.1 禁动清单（禁动清单仅 hook/lib），故非禁动违规，而是声明缺失。
**Remedy**：T01 write_files 增 `.specs/l3-review-timeout-token/T01-SUMMARY.md`；T04 write_files 增 `flow-kit-bundle/test/test_l3_review.bats`；据实修正禁动清单遵守声明（T01/T04 不再写「无 write_files」）。

### 🟡 R3 · 既有测试冲突未处置：旧 AC-5 断言硬编码值将破裂 + AC 编号碰撞
**Symptom**：`test/test_l3_review.bats:24-27` `@test "AC-5: max_tokens is 8000"` 断言 `grep -c 'max_tokens:8000' >= 2`；`:29-32` `@test "AC-5: curl timeout is 90s"` 断言 `grep -c 'max-time 90' >= 2`。T02（TASK.md:92 verify `! grep -q 'max_tokens:8000'`、`! grep -q -- '--max-time 90'`）删除这两个硬编码值后，这两条既有测试必然失败。又：既有文件 `:133-144` `@test "AC-1: git ls-files..."`、`:148-157` `@test "AC-2: phase 7 artifact..."` 等携带 AC-1..AC-6 标签，与新 REQUIREMENT 重新定义的 AC-1(max_tokens 默认)/AC-2(env var 覆盖)/.../AC-6(Fail-safe) 语义完全不同——AC 编号碰撞。T03 action（TASK.md:112-121）仅写「按 REQUIREMENT AC-1~AC-8 + AC-10 派生测试」，未枚举须删除/改写这两条破裂测试；且 TASK.md:120 第 7 点「既有测试若有 fallback 断言保留」 blanket 要求保留 `:43-48` `@test "AC-4: falls back to thinking when no text block"`——而该测试正是把「提取思考内容当 verdict」的静默错判（DESIGN R2 / AC-10 所指最危险失效模式）断言为正确行为。
**Source**：阶段 3 checklist「覆盖完整性」+「verify 可验证性」——改写既有测试须显式处置与新实现冲突的旧断言；AC 编号须唯一映射，不可同号异义。
**Consequence**：4-dev 若按 T03 action 字面派生新测试而不删两条破裂旧测试，`npx bats`（T03 verify）立即失败阻塞；若误删 `:43-48` fallback 测试则丢失 AC-10「fallback 行为不被破坏」的既有覆盖；若保留之又与 AC-10「静默错判是危险失效」的判定立场矛盾。AC-1/AC-2 编号碰撞使 AC 覆盖矩阵（TASK.md:158-167）与新测试的对应关系含混，难核实哪条「AC-1」被覆盖。T03 verify 会兜住破裂测试（bats fail），但 instruction gap 造成返工与误标。
**Remedy**：T03 action 显式增一条「删除既有 `AC-5: max_tokens is 8000` 与 `AC-5: curl timeout is 90s`（断言 T02 删除的硬编码值，须移除）」；逐条标注既有 AC-1/2/3/4/6 测试去留（git ls-files/phase 7 与本 change 无关，应迁出或重命名避免 AC 号碰撞）；将第 7 点「保留 fallback 断言」改为「保留 `:36-41` text-block 提取测试，但 `:43-48` thinking-fallback 测试须加注释标明此即 AC-10/DESIGN R2 静默错判行为、属 Out-of-Scope 既存风险，非本 change 背书为正确」。

### 🟡 R4 · T03 verify 不足以覆盖 env-var 覆盖类 AC
**Symptom**：T03 verify（TASK.md:123）为单条 `npx bats test/test_l3_review.bats`——不带任何 `FLOW_KIT_L3_*` env var。但 REQUIREMENT 对 AC-2（:33 `FLOW_KIT_L3_MAX_TOKENS=16000 bats ...`）、AC-4（:47 `FLOW_KIT_L3_TIMEOUT=600 bats ...`）、AC-5a/5b（:54/62 `FLOW_KIT_L3_THINKING=enabled/disabled bats ...`）、AC-6（:83 六非法值）、AC-7 的验证方式均以外部 env var 前缀触发。单条无 env bats 运行只能覆盖「未设」默认场景（AC-1/AC-3/AC-5c），无法触达 AC-2/4/5a/5b/6/7。T03 action（TASK.md:112-121）未强制要求「每个 @test 内部 `export FLOW_KIT_L3_*=...` 再调用」。
**Source**：阶段 3 checklist「verify 可验证性：每条 verify 是否可机器执行（非人工确认空话）」——verify 须能证明（而非仅不否定）对应 AC 被覆盖；verify 与 REQUIREMENT 验证方式须一致。
**Consequence**：4-dev 若仅写「未设默认」测试，T03 verify（单条 bats）仍全绿，但 AC-2/4/5a/5b/6/7 实际无任何测试触发——AC 未被机器验证而 verify 通过，spec 合规存在静默缺口。
**Remedy**：T03 action 增「每条 env-var AC 的 @test 须在测试体内部 `export` 对应 `FLOW_KIT_L3_*` 后再调用 `_l3_call_api`，断言后 `unset`」；或将 verify 改为多 env 前缀 bats 调用脚本（覆盖六非法值 + 各覆盖值），使 verify 本身强制触达 AC-2/4/5a/5b/6/7。

### 🟡 R5 · T03 任务粒度超标：7 AC × 双路径 × 多取值单任务无内检查点
**Symptom**：T03（TASK.md:101-126）单任务承载 AC-1~AC-7 全部派生：AC-1/2(max_tokens 默认+覆盖×双路径)、AC-3/4(timeout×双路径)、AC-5a/5b/5c(thinking 三取值×双路径)、AC-6(六非法值×双路径=12)、AC-7(可观测性×双路径)——约 26 个用例。既有文件 157 行（10 测试），新增估计 +290~450 行（每用例 ~12-18 行 + 共享 curl stub setup），净变更逾 200 行 guideline，且 verify（TASK.md:123）为单条 all-or-nothing `npx bats`，无内检查点。
**Source**：阶段 3 checklist「单 task 是否 ≤ 200 行变更？波次划分是否清晰」——任务粒度须可审、可局部定位失败。
**Consequence**：单任务过大 + 单 verify 全有或全无，一处错误致整任务阻塞且难定位；7 AC 一揽子无中间检查点，review diff 大、回归风险集中。
**Remedy**：拆 T03 为 T03a（AC-1~AC-4：max_tokens/timeout 默认+覆盖，双路径）+ T03b（AC-5~AC-7：thinking/Fail-safe/可观测性，双路径），各自 `npx bats` 内检，T04 再合量回归；共享的 `curl()` stub 与路径触发 helper 抽到 setup 或 load helper 文件避免拆分后重复。

### 🟢 R6 · T01 verify 仅存在性检查，不验证证据实质
**Symptom**：T01 verify（TASK.md:56）`test -f .../T01-SUMMARY.md && grep -q "实测证据" && grep -qE "R4|R3|AC-10"`——仅查文件存在 + 含「实测证据」+ 含 R4/R3/AC-10 任一字符串。不验证 AC-10 <Then>（REQUIREMENT:103-107）要求的实质产出：记录的代理 max_tokens 上限数值、`.content[0]` 字段名、是否触发 fallback 静默错判的判定结论。
**Source**：阶段 3 checklist「verify 可验证性」——verify 应尽量断言 AC 的实质产出而非仅文档关键词存在。
**Consequence**：4-dev 写一个只含「R4」「实测证据」标题的空壳 SUMMARY 即可通过 verify，AC-10 的强制验证（C3 落地）沦为橡皮章。虽 AC-10 本质手动（无法机器验证 API 判断），但 verify 可更强。
**Remedy**：verify 增 `grep -qE '代理上限|max_tokens.*[0-9]{4}' T01-SUMMARY.md`（强制记录数值化代理上限）+ `grep -qE 'content\[0\]|thinking|\.text' T01-SUMMARY.md`（强制记录字段名判定），使空壳无法过关。

---

**Verdict**: pass（无 🔴 Critical；6 项 🟡/🟢 建议实施前修复，其中 R1 依赖图、R2 write_files、R3 既有测试冲突三者叠加使 T01→T02 数据流在 depends_on 与写/读图双重隐形，应优先处置）

---

## L3 重审（deepseek-v4-pro 外部模型 · 2026-07-25 01:26）

> 自动生成于 2026-07-25 01:26。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"T02","issue":"T02 write_files 声明写 l3-review.sh，但 T04 write_files 也声明写 flow-kit-bundle/test/test_l3_review.bats——T04 写的是双源同步目标文件，与 T03 的 write_files（test/test_l3_review.bats）是不同文件，不矛盾。但 T02 的 verify 用 grep 检查 FLOW_KIT_L3_MAX_TOKENS 等 env var 名，而 DESIGN.md 可能要求不同命名（如 FLOW_KIT_L3_MAX_TOKENS vs FLOW_KIT_MAX_TOKENS），verify 断言可能与实际实现不一致。当前工件中 verify 的 grep 字符串未提供 DESIGN 中的确切变量名对照，存在 verify 不可执行的风险。","why":"verify 的 grep 字符串（FLOW_KIT_L3_MAX_TOKENS）若与 DESIGN 规定的变量名不同，则 verify 会错误失败，且无法通过工件本身确定 DESIGN 中的确切命名。","fix":"在 T02 的 verify 中增加对 DESIGN.md 中变量名的引用验证，或改为检查 _l3_call_api 函数中变量解析逻辑的语法正确性（如 bash -n 已做），并确保 grep 的变量名与 DESIGN 完全一致。"},{"file":"T03","issue":"T03 的 verify 要求运行 FLOW_KIT_L3_MAX_TOKENS=16000 FLOW_KIT_L3_TIMEOUT=600 FLOW_KIT_L3_THINKING=disabled npx bats test/test_l3_review.bats 等多种组合，但 T02 尚未完成（depends_on T01 但 T03 depends_on T01,T02），verify 在 T02 的代码修改完成前无法执行。verify 作为独立检查项，不能依赖未完成的任务，否则无法在 T03 实施时验证。","why":"T03 的 verify 要求运行修改后的测试文件，但测试文件依赖 T02 修改后的 l3-review.sh，而 T02 在 T03 之前完成，但 verify 本身是 T03 的一部分，无法在 T02 完成前独立验证，存在逻辑循环。","fix":"将 T03 的 verify 改为检查测试文件语法（如 bash -n 或 bats --dry-run）和测试用例结构（如 grep 特定 @test 名称），将实际运行测试的验证移至 T04 的 verify 中。"},{"file":"T04","issue":"T04 的 write_files 声明写 flow-kit-bundle/test/test_l3_review.bats，但 action 说明是 'make test-sync 同步 test/test_l3_review.bats → flow-kit-bundle/test/test_l3_review.bats'，write_files 应明确为 make test-sync 的输出产物，而非直接声明写入。此外，verify 中的 diff -q 要求两个文件一致，但若 T03 和 T04 的 write_files 都正确，该验证应通过，但需确保 T03 的 write_files 已正确生成 test/test_l3_review.bats。","why":"write_files 声明与 action 描述不一致（声明直接写文件，实际是同步命令生成），可能导致实施者误解；diff 验证依赖 T03 的输出，但 T04 的 verify 本身是可执行的，只要 T03 完成。","fix":"将 T04 的 write_files 改为空或声明为同步命令的输出，并在 action 中明确写入的是同步后的目标文件，验证逻辑保持不变。"}],"minor":[{"file":"T01","issue":"T01 的 verify 检查 T01-SUMMARY.md 包含 '代理上限|代理.*[0-9]' 和 'content\\[0\\]|thinking.*字段' 等模式，但 T01 的 action 要求记录 '代理上限数值' 和 'content[0] 完整结构'，verify 模式可能匹配到不完整或错误的记录（如仅匹配 '代理' 一词而非具体数值）。","why":"verify 可能通过但不充分验证 AC 覆盖，如 grep -E '代理上限|代理.*[0-9]' 可能匹配到 '代理上限未确定' 而非实际数值，导致误判 T01 完成。","fix":"增强 verify 模式，要求匹配具体数值格式（如 '代理上限： [0-9]+'）和完整的 content[0] 字段名（如 'thinking' 或 'text' 字段名），确保 AC-10 落地证据充分。"},{"file":"T02","issue":"T02 的 action 要求 '据 T01 实测证据定默认值'，但 T01 的 T01-SUMMARY.md 是 T01 运行时产物，T02 的 read_files 包含它，但 T01 的产出是探测数据，T02 的实施者需手动解析该文件中的数值来调整默认值。action 未提供具体的解析指令或默认值调整逻辑，可能因人为错误导致默认值设置不当。","why":"依赖人工解析 T01 输出，缺乏自动化检查，可能引入默认值设置错误，违反 AC-1 默认值要求。","fix":"在 T02 的 action 中增加明确步骤：从 T01-SUMMARY.md 中提取代理上限数值（如 grep 特定标记），并设置 max_tokens 默认值为该值（若小于 32000），否则保持 32000。或在 verify 中增加检查：默认值是否与 T01-SUMMARY.md 中的数值一致。"},{"file":"T03","issue":"T03 的 action 提到 '若超 450 行拆两文件' 但未在 verify 或 done 中明确如何验证拆分，且 T04 的 verify 依赖 diff -q 两个文件一致，若 T03 拆分文件，T04 的双源同步对象可能变化，导致依赖断裂。","why":"拆分决策未在任务间同步，可能导致 T04 验证失败或遗漏测试文件。","fix":"在 T03 的 done 中明确是否拆分及拆分后的文件列表，并更新 T04 的 read_files/write_files 和 verify 以包含所有拆分文件的双源同步检查。"}],"verdict":"pass","summary":"任务拆解完整覆盖 REQUIREMENT 全部 AC，depends_on 无环，但 T03 verify 依赖未完成代码、T01 verify 模式可能不充分、T04 write_files 声明不一致等 🟡 问题需在实施前澄清。"}
```

L3_artifact_hash: 2363102e7e470e6fde786695efbbef21f031bb5ba376bea2825e7fb00b0ca88c
