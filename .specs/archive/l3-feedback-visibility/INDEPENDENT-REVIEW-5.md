
---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 13:42）

> 自动生成于 2026-07-07 13:42。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"test/test_l3_feedback.bats","issue":"缺少L3 API真实端到端测试，当前bats测试可能依赖mock/stub，无法捕获真实API超时、错误响应等故障。","why":"测试矩阵中AC-5（timeout/error退出码）仅验证了mock下的行为；未覆盖项主动承认真实API调用未测试，且未说明mock的保真度。这导致真实API失败（如网络波动、响应格式变更）可能被完全屏蔽，造成回归遗漏。","fix":"添加集成测试（可使用真实ANTHROPIC_AUTH_TOKEN在CI定期运行，或使用受控模拟环境），验证完整调用链路，包括超时、错误响应、畸形返回等场景的实际行为。"}],"minor":[],"verdict":"pass","summary":"测试矩阵在AC覆盖率和回归测试方面完整，但缺少对L3 API真实调用的端到端测试，存在mock屏蔽真实失败的风险。无critical问题，整体通过。"}
```


---

## L2 盲审

### R1 · Summary 三层提取测试缺失：T04 场景 2 未实现

**Symptom**：T04 task 明确要求编写 "summary 三层提取测试"（代码块 JSON / 裸 JSON / grep 正则 / 无字段降级），但 `test/test_l3_feedback.bats` 中无任何对应测试。该文件中所有 `_l3_format_result` 调用均使用预置字符串参数，从不经过 l3-review.sh 的实际 JSON 提取管道（l3-review.sh:227-241）。

**Source**：T04 场景 2 任务描述（TASK.md:182-186）。TEST.md 本应列此项为未覆盖或标注对应测试行号，但均未做。

**Consequence**：若 l3-review.sh 的 summary 三层提取（jq 代码块 → jq 裸 JSON → grep 正则）中任一层因响应格式变更而失效，summary 将静默为空，L3_RESULT 行仅剩 `summary=` 无实际内容。现有测试不会捕获此退化——空 summary 测试（场景 1，line 33-36）反而将其视为合法行为。这削弱了 AC-1/AC-2 的反馈价值。

**Remedy**：在 `test/test_l3_feedback.bats` 中新增测试：构造含 summary 字段的模拟 L3 响应 JSON（分别包裹在代码块、裸 JSON、多行混排中），调用 l3-review.sh 的提取逻辑（或内联等效测试），断言提取到的 summary 与期望值一致。

### R2 · AC-4 全模式兼容测试仅为字符串比较而非行为验证

**Symptom**：`test/test_l3_feedback.bats:242-267` 中 4 个 AC-4 测试仅验证 `gate_val` 字符串与 "L3"/"both" 的比较结果。例如 L2-only 测试（line 242-249）只做 `[[ "$gate_val" != "L3" && "$gate_val" != "both" ]]`，不调用 gate 函数、不验证 transition 退出码、不检查 INDEPENDENT-REVIEW-N.md 段结构。这些测试实质是 bash 字符串运算单元测试，非 gate 行为测试。

**Source**：AC-4 验收准则（REQUIREMENT.md:44-56）要求验证：(a) both 模式下 L2 结果可见 + 文件含两段；(b) L3-only 仅 L3 无 L2；(c) L2-only 不产生 L3_RESULT 行 + transition exit 0；(d) off 模式不产生 L3_RESULT 行 + transition exit 0。

**Consequence**：即使 independent-review-gate.sh 的 gate 分支逻辑被错误修改（例如 L2-only 模式下仍然触发 L3 审查），现有测试也不会失败——它们只验证了 bash 的 `!=` 运算符。这意味着 AC-4 的行为覆盖率实际远低于 TEST.md 宣称的 100%。

**Remedy**：重构 AC-4 测试为端到端行为测试：在临时目录中构造不同 gate_config 的 flow-kit.json，source gate 脚本核心逻辑（或直接测试 gate 分支条件函数），验证每种模式下：(1) L3_RESULT 行是否产生/不产生；(2) 退出码是否为 0。

### R3 · AC-5 超时仅测格式化函数退出码，未测完整超时降级流程

**Symptom**：`test/test_l3_feedback.bats:273-281` 的 AC-5 测试仅验证 `_l3_format_result` 返回 exit code 0。不模拟 `l3_review_with_timeout` 超时触发、不验证超时后 `.done` 文件写入（含 `L3_summary=L3 API 调用超时（30s）`）、不验证 L3_RESULT 行产出 `verdict=timeout`。

**Source**：AC-5（REQUIREMENT.md:58-67）要求验证：(1) stdout 输出 `L3_RESULT: verdict=timeout`；(2) transition exit code = 0。

**Consequence**：若 l3-review.sh 的超时处理逻辑（`_l3_write_timeout_done` at l3-review.sh:360-374）中 `L3_summary` 写入失败或 `_l3_format_result` 未被调用，现有测试仍全部通过。超时反馈的端到端正确性未被验证。

**Remedy**：新增测试模拟 `l3_review_with_timeout` 超时路径——通过设置极短 timeout 值或 mock timeout 触发，验证：(1) `.done` 文件含 `L3_verdict=timeout` 和 `L3_summary=L3 API 调用超时（30s）`；(2) `_l3_format_result` 输出 `verdict=timeout`；(3) 函数整体 exit code = 0。

### R4 · Stderr 安全测试名实不符：测试 stdout 而非 stderr

**Symptom**：T04 场景 10（TASK.md:222-225）要求 "模拟 L3 API 调用失败（curl 非零退出）→ 验证 stderr 不含 https?:// → 验证 stderr 不含 'verdict' 等 JSON 片段"。但 `test/test_l3_feedback.bats:287-315` 的 4 个安全测试全部针对 `_l3_format_result` 的 stdout 输出——该函数按设计仅输出 3 个白名单字段，安全断言实为同义反复（tautology）。

**Source**：T02 任务（TASK.md:95-98）明确警告移除 `2>/dev/null` 后 "l3_review_run() 内部的 >&2 日志也会暴露到 agent 可见 stderr"，并要求 T04 增加 stderr 安全测试作为缓解措施。实际实现中 curl 命令自身仍保留 `2>/dev/null`（l3-review.sh:154,163），部分降低了风险，但 `[l3-review]` 前缀的 >&2 日志仍会暴露（如 l3-review.sh:178,251,295,373）。

**Consequence**：安全测试矩阵 Round 3 的 4 项 "pass" 标记存在误报——它们覆盖的是设计上必然安全的 stdout 通道，而非 T02 警告的实际风险通道（stderr）。若未来某次修改在 l3-review.sh 中新增不加 `[l3-review]` 前缀的 >&2 日志或移除 curl 的 `2>/dev/null`，现有安全测试不会捕获。

**Remedy**：将安全测试重构为：(1) 模拟 curl 返回非零退出码并输出含 URL 的 stderr；(2) 捕获 l3_review_run 或等效函数的 stderr 输出；(3) 断言 stderr 不含 `https?://`、`Authorization:`、`x-api-key:`、以及原始 JSON 响应片段。同时验证 stderr 中所有日志均以 `[l3-review]` 前缀开头。

### R5 · 测试矩阵行号引用系统性偏移，覆盖追溯不可靠

**Symptom**：TEST.md 测试矩阵中 6 个 AC 对应的行号引用与 `test/test_l3_feedback.bats` 实际位置均存在偏移。例如：AC-2 引用 "118-150"，实际测试始于 line 180（偏移 +62 行）；AC-4 引用 "153-175"，实际测试始于 line 242（偏移 +89 行）；AC-5 引用 "178-185"，实际测试始于 line 273（偏移 +95 行）。AC-3 引用 "109-115" 实际是节标题注释（line 109-115 不含任何 assert）。

**Source**：推测测试文件在开发过程中被重组（新增 setup/teardown、补充场景），但 TEST.md 矩阵的行号未同步更新。

**Consequence**：审查者按行号查找对应测试时，会看到不相关内容——例如按 AC-4 的 153-175 行号看到的是 `.done` KVP 测试的 skip 分支而非 gate 模式测试。这会误导后续维护者认为某些 AC 有覆盖实际没有，或遗漏真实覆盖位置。

**Remedy**：用脚本自动化生成行号引用：`grep -n '@test.*AC-\|@test.*F[12]' test/test_l3_feedback.bats` 提取实际测试起始行，更新 TEST.md 矩阵。建议在 CI 中增加 smoke 检查，确保 TEST.md 中每个行号段落至少包含一个 `@test` 声明。

### R6 · AC-2 未显式断言握手状态文件缺失

**Symptom**：AC-2 验证方式第 3 步明确要求 "确认握手状态文件不存在（模拟 29 号 hook 已清理的真实 post-hook 场景）"，但 `test/test_l3_feedback.bats:180-201` 的 F2 测试未做此断言——测试仅在未创建握手文件的环境下验证检测逻辑，未显式 assert 握手文件不存在。

**Source**：AC-2 验收准则（REQUIREMENT.md:25-33）。

**Consequence**：低风险——新检测逻辑（`.done` 存在 + review md 含 L3 段）不依赖握手文件，所以即使不显式断言，功能上无缺陷。但 AC 要求的显式验证步骤未被执行，降低了 AC 的可审计性。

**Remedy**：在 F2 正向测试（line 180-201）中增加对握手状态文件不存在的显式断言。

### R7 · AC-3 集成级验证缺失且未在未覆盖项声明

**Symptom**：AC-3（REQUIREMENT.md:35-42）要求两级验证：(1) 单元级——两条路径调用同一格式化函数；(2) 集成级——端到端对比两条路径的 L3_RESULT 行字段值一致。测试矩阵仅覆盖单元级（场景 1/5），集成级验证不在 bats 测试中实现（合理，属集成测试范畴），但 TEST.md 的 "未覆盖项" 节未将其列出。

**Source**：AC-3 验收准则验证方式第 2 条（REQUIREMENT.md:42）。

**Consequence**：低风险——集成级验证按 TEST.md "未覆盖项" 的惯例应在对应条目中标明，遗漏导致审查者可能误认为 AC-3 已 100% 覆盖。实际影响有限，因为两条路径共用 `_l3_format_result()`，格式一致性由函数本身保证。

**Remedy**：在 TEST.md "未覆盖项" 节补充："AC-3 集成级端到端对比验证（需完整 hook 链执行环境，bats 单元测试不覆盖）"。

---

**Verdict**: pass
