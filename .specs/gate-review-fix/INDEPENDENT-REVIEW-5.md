# 独立审查 · 阶段 5

## L2 盲审

### 🔴 R1 · AC-NF2 未满足：全量 bats 连续 3 次全 pass 仅完成 1/3
**Symptom（症状）**：TEST.md:25 — "AC-NF2 | full bats suite | 1128 results, 34 modified tests all pass, 62 pre-existing failures (unrelated) | ⚠️ 1/3 runs"；TEST.md:89 — "已完成 1 次。建议在 commit 前补跑 2 次。"
**Source（源头）**：REQUIREMENT.md AC-NF2 — "When 连续 3 次执行 npx bats flow-kit-bundle/test/ test/ Then 每次结果全 pass（无 intermittent failure）"
**Consequence（后果）**：存在未被检测的 flaky test 风险。若第 2 或第 3 次运行出现间歇性失败，则 AC-NF2 判定为 fail，当前测试报告无法证明无回归。62 个 pre-existing failures 中可能存在与本次修改相关的隐性退化（TEST.md 仅断言 "unrelated"，未提供证据）。
**Remedy（修补）**：补跑第 2、3 次全量 bats，将结果追加到 TEST.md 的 3. 全量回归测试 段；若任一次出现新失败，修复后重新计数；3 次均通过后方可标记 AC-NF2 为 ✅。

### 🔴 R2 · 5 轮测试金字塔结构完全缺失
**Symptom（症状）**：TEST.md 全文仅含功能测试（修改测试详情 + UAT grep 脚本），无性能轮、安全轮、兼容轮、可观测轮的章节或跳过理由。
**Source（源头）**：固化指令阶段 5 审查标准 — "5 轮金字塔：功能/性能/安全/兼容/可观测是否逐轮填写（跳过的有理由）"
**Consequence（后果）**：测试策略不完整。AC-NF3（Gate 执行无性能回退）仅有手工声称 "Pure functions, no additional jq calls"（TEST.md:26），无任何性能测试数据支撑；安全测试（如竞态条件未触发时 mktemp 行为、非法 gate_val 注入）完全缺失；兼容测试（跨 bash 版本、跨 OS）未提及。
**Remedy（修补）**：在 TEST.md 中新增第 6 节 "5 轮金字塔"（或扩展第 5 节），逐轮填写：
- 功能轮：映射现有测试矩阵（已有）
- 性能轮：至少包含 AC-NF3 的 jq 调用计数测试（如 `strace -e trace=execve -c` 或 `bash -x` 调用计数）或明确标注跳过理由
- 安全轮：至少包含非法 gate_val 注入测试（AC-12 的 "" 回退路径）、mktemp 竞态窗口测试；或标注跳过理由
- 兼容轮：至少确认目标 bash 版本范围（bats-core 1.13.0 隐含依赖）或标注跳过理由
- 可观测轮：至少验证 timeout/error 路径日志输出格式（AC-8 的 CRITICAL/UNEXPECTED 日志）或标注跳过理由

### 🔴 R3 · AC-7 coverage 为虚假覆盖声明
**Symptom（症状）**：TEST.md:17 — "AC-7 | (source-level) | l2_dispatch_agent mkdir -p (结构变更，bats 环境自动创建目录) | ✅ 间接覆盖"
**Source（源头）**：REQUIREMENT.md AC-7 — "Given l2_dispatch_agent 被调用，$specs_dir 可能不存在 When 函数开始执行 Then 函数在文件操作前执行 mkdir -p "$specs_dir""
**Consequence（后果）**："bats 环境自动创建目录"意味着测试环境恰好已存在该目录，`mkdir -p` 路径从未在目录缺失的场景下被真正执行和验证。若未来代码改动删除或错误放置了 `mkdir -p`，没有测试会发现该回归。这不是"间接覆盖"——这是零覆盖。
**Remedy（修补）**：新增 bats 测试（或扩展现有测试），显式地：
1. 构造不存在 `$specs_dir` 的场景
2. 调用 `l2_dispatch_agent`
3. 断言目录被创建且后续操作成功
或将该 AC 标注为 "⚠️ 未覆盖"并在已知限制中说明原因。

### 🟡 R4 · AC-8 error propagation 覆盖不完整：rc=3 和 default 分支未测试
**Symptom（症状）**：TEST.md:18 — AC-8 覆盖声明为 "AC-5: max_tokens 8000, curl timeout 90s (pre-existing)"。该测试验证 timeout 路径 → verdict=non-pass → .done 未写入，仅覆盖 rc=1 分支。REQUIREMENT.md AC-8 要求 rc=0/1/3/* 四个分支全部被测试。
**Source（源头）**：REQUIREMENT.md AC-8 — 显式 case 分支：rc=0 → 正常；rc=1 → "verdict non-pass"；rc=3 → "CRITICAL: .done write failed" + return 3；*) → "UNEXPECTED" + return $rc
**Consequence（后果）**：rc=3（磁盘满/权限拒绝）和 default（未来新增退出码）分支未被验证。若 `_l3_write_done` 的 case 语句有 bug（如 fall-through、错误日志格式），在正常测试中不会被发现。default 分支的防御性价值在未测试时为零。
**Remedy（修补）**：在 done-validation.bats 或 test_l3_review.bats 中新增：
- 测试 rc=3 场景：mock `_l3_write_done` 返回 3，断言 "CRITICAL" 日志出现且函数 return 3
- 测试 default 场景：mock `_l3_write_done` 返回 99，断言 "UNEXPECTED" 日志出现且函数 return 99
或标注 rc=3/default 为 "⚠️ 未覆盖（需 mock 写失败，v2）"并给出理由。

### 🟡 R5 · AC-11 fallback 路径覆盖缺失
**Symptom（症状）**：TEST.md:21 — AC-11 覆盖声明为 "AC-1: git ls-files captures new untracked .sh (pre-existing)"。git ls-files 测试验证的是文件追踪，与 `_l3_build_prompt` 中 `BASH_SOURCE[0]` 回退路径的 `dirname` 修正完全无关。
**Source（源头）**：REQUIREMENT.md AC-11 — "Given HOOK_BASE_DIR 未设，l3-review.sh 被 standalone source When _l3_build_prompt Phase 6 构造 _common_lib 路径 Then BASH_SOURCE[0] 回退路径不再追加 /lib/common.sh"
**Consequence（后果）**：若 fallback 路径修正有误（如仍然错误追加 `/lib`），没有测试会发现。该路径仅在 `HOOK_BASE_DIR` 未设时触发，是一个低频但关键的错误恢复路径。
**Remedy（修补）**：新增测试：unset HOOK_BASE_DIR，source l3-review.sh，调用 `_l3_build_prompt`，断言 `_common_lib` 解析为 `<dirname(BASH_SOURCE[0])>/common.sh` 而非 `.../lib/lib/common.sh`。或标注为 "⚠️ 未覆盖（需 standalone source 环境，v2）"。

### 🟡 R6 · 多个 AC 的覆盖声明依赖 "pre-existing" 测试，未提供修改证据
**Symptom（症状）**：TEST.md 中 AC-6（行 16）、AC-10（行 20）、AC-13（行 23）均标注 "pre-existing"。这些 AC 对应本次 change 中的行为变更（AC-6: exit→return；AC-10: 内联 jq→fk_resolve_phase；AC-13: 内联 grep→fk_extract_l2_verdict），但测试报告未说明 pre-existing 测试是否因代码变更而更新。
**Source（源头）**：测试审查原则 — 当被测代码行为发生变更时，覆盖该行为的测试必须同步更新以验证新行为（而非旧行为偶然 pass）。
**Consequence（后果）**：若 pre-existing 测试恰好因输出等价而通过，但实际未覆盖新代码路径（如 AC-13 的 heading-style fallback 分支），则部分新功能未经测试。最坏情况：某个 consumer 调用 `fk_extract_l2_verdict` 时误传参数，测试仍通过因为 pre-existing 测试走的是旧 grep 路径。
**Remedy（修补）**：对每个 "pre-existing" 覆盖声明，在 TEST.md 中补充说明该测试是否经过修改以适配新行为；若未修改，解释为何旧测试仍能正确验证新行为（等价性论证）。首选方案：为新增函数（`fk_normalize_gate_val`、`fk_extract_l2_verdict`、`fk_resolve_phase`）添加独立单元测试。

### 🟡 R7 · AC-NF3 性能验证无自动化测试
**Symptom（症状）**：TEST.md:26 — AC-NF3 覆盖声明为 "Pure functions, no additional jq calls, no I/O in shared fns | ✅"。这是手工代码审查结论，非自动化测试。
**Source（源头）**：REQUIREMENT.md AC-NF3 — "jq 调用次数不增加（共享函数不应引入重复 jq 读取）"
**Consequence（后果）**：若未来有人修改 `fk_normalize_gate_val` 或 `fk_extract_l2_verdict` 引入 jq 调用（违背 AC-NF3 的设计约束），没有回归测试会在 CI 中捕获。当前的手工断言在一次代码变更后即失效。
**Remedy（修补）**：新增自动化性能断言测试：在 gate transition 路径上统计 jq 调用次数（如通过 mock jq 计数），断言本次修改前后计数不变。或将该 AC 降级为设计约束（非测试 AC），并在 REQUIREMENT.md 中标注其仅通过 code review 验证。

### 🟢 R8 · 测试矩阵内部 "AC-N" 引用与 REQUIREMENT.md AC 编号冲突
**Symptom（症状）**：TEST.md 测试矩阵 "测试用例" 列中使用 "AC-11"（行 14）、"AC-9"（行 16）、"AC-5"（行 18）、"AC-3"（行 20）、"AC-1"（行 21）引用测试文件内部编号（如 test_l3_review.bats 中的 AC-1），而 REQUIREMENT.md 已有独立的 AC-1 至 AC-13 编号体系。
**Source（源头）**：文档一致性原则 — 同一文档体系中相同标识符不应指代不同实体。
**Consequence（后果）**：读者无法区分 "AC-1" 是指 REQUIREMENT.md 的验收准则还是测试文件内部的用例编号。降低测试报告的可审计性，增加 L3 复核时的误判风险。
**Remedy（修补）**：将 TEST.md 中的内部测试用例引用改为显式路径记法（如 `test_l3_review.bats:AC-1`、`test_gate_integrity.bats:AC-3`）或在矩阵中新增一列 "测试用例 ID（文件内）" 以避免歧义。

### 🟢 R9 · UAT 脚本以 grep/syntax 检查为主，行为验证不足
**Symptom（症状）**：TEST.md 第 4 节 4 个 UAT 脚本中，UAT-1（grep 计数）、UAT-2（bash -n 语法检查）、UAT-4（grep 否定匹配）均为静态分析，非运行时行为验证。仅 UAT-3（npx bats）为行为测试。
**Source（源头）**：阶段 5 审查标准 — "UAT 可执行：Given/When/Then 是否可脚本化（非手工步骤描述）"
**Consequence（后果）**：UAT-1 的 grep 计数验证消费者完整性，但若函数被调用而未实际使用返回值（死调用），grep 无法发现。UAT-4 的 grep 否定匹配验证 `.tmp.$$` 被消除，但若 mktemp 用法本身有 bug（如未 trap cleanup），grep 无法发现。
**Remedy（修补）**：将 UAT-1 和 UAT-4 降级为代码审查 checklist（非 UAT），或补充端到端场景脚本（如：创建 change → 配置 gate_config=all → 执行 phase 0→7 transition → 验证所有 .done 文件格式正确）。

---

**Verdict**: fail
