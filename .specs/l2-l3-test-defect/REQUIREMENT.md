# REQUIREMENT: 诊断 L2/L3 gate 机制 + 全链路实跑验证

- **Change ID**: l2-l3-test-defect
- **关联**: `@.specs/l2-l3-test-defect/CHANGE.md`、`@.specs/l2-l3-test-defect/DIAGNOSE.md`（bug A-J 定义 + 证据矩阵）、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想通过 from-0-all pipeline 实跑验证 L2/L3 独立审查 gate 是否正常工作，以便确认质量门禁可信（非"假绿"）。
- **US-2**：作为 flow-kit 维护者，我想定位并修复 gate 机制的真实缺陷，以便后续 change 的独立审查真正生效。

## 测试 ID 定义表（内联 · 回应 R17）

REQUIREMENT AC 的验证方式引用以下 ID，全部定义于 `test/test_l2_pretooluse_dispatch.bats` 或 DIAGNOSE.md：

| ID | 类型 | 定义 |
|---|---|---|
| INT-1 | bats @test | phase0 forward transition 放行（BUG-A） |
| INT-2 | bats @test | phase0 纯 git commit 放行（BUG-C） |
| INT-3 | bats @test | phase1 git commit 无.done deny（BUG-B+E） |
| INT-4 | bats @test | phase6 git commit 无.done deny（BUG-B+E） |
| INT-5 | bats @test | gate_config 未配 phase 放行（BUG-D） |
| INT-6 | bats @test | .done+phases_done 含 phase 放行（AC-9 正向，mock fixture） |
| TEST-N | ctx_execute | DIAGNOSE.md「实跑证据矩阵」TEST-1~6（payload 注入 bash gate.sh） |

**Gate-N 定义**（`_run_review_gates` 的 7 个 gate，independent-review-gate.sh）：Gate1=path-guard（握手文件保护）/ Gate2=`_gate_phase_filter`（phase 过滤，非 review phase 放行）/ Gate3=`_gate_active_check`（gate 是否开启）/ Gate4=done validation（`.done` 存在则放行）/ Gate5=tamper detect（gate_config 篡改检测）/ Gate6=`_gate_phase_transition`（forward 转换 L2/L3 dispatch）/ Gate7=`_gate_deny_reason`（commit/PR/phase write deny）。

> 注：bats 文件内另有 AC-1~AC-11 编号（如 AC-1 测 l2_detect_missing、AC-9 测 auto_advance），是 **bats 内部编号**（测 l2-detect.sh 单函数），与本文档 AC-N **无对应关系**（回应 R14）。本文档 AC 由 INT-1~6 + TEST-1~6 覆盖。

## 验收准则（AC）

每条 Given/When/Then，必须可机器验证。BUG 标签定义见 DIAGNOSE.md「缺陷清单」。

### AC-1 · phase0 不再死锁（BUG-A）

- **Given** pipeline scope=pipeline current_phase=0，gate_config all
- **When** 0→1 forward transition（jq 写 current_phase=1，independent-review-gate.sh PreToolUse 审查）
- **Then** hook 放行 exit 0，bats framework 保障非挂起（超时即 fail）
- **验证方式**: INT-1（exit0）/ TEST-1

### AC-2a · review phase 纯 git commit deny（BUG-B）

- **Given** phase∈{1,2,3,5,6,7}，gate_config[phase]=both，无 .done
- **When** **纯** git commit（命令不含 jq 写 .flow-active.current_phase，即不切 phase）
- **Then** deny exit 2 + stderr 含 phase 编号 + .done 路径
- **验证方式**: INT-3/INT-4（deny exit2，覆盖 denied 分支）+ INT-6（.done 存在时 allow，覆盖 allow 分支）

> phase 集合排除 4：phase 4（dev）无独立 review gate（gate_config 不含 4-dev）；dev 审查由 phase 6 承担，3→4 transition 由 phase 3 gate 把关。
> stderr「阻断原因」字段完整依赖 BUG-F（PHASE_GATE_KEY_MAP 初始化，v2）：BUG-F 未修前 phase_name 显示空，但 phase 编号 + .done 路径正确。AC-2a stderr 校验在 BUG-F 修复后完整生效。

### AC-2b · gate-active 判定生效（BUG-E）

- **Given** phase∈{1,2,3,5,6,7}，gate_config[phase]=both
- **When** _gate_active_check 调用（source done-validation.sh + PROJECT_ROOT=cwd）
- **Then** fk_independent_review_gate_active 返回"gate 生效"（非"未开"）
- **验证方式**: INT-3/INT-4（gate 生效才 deny；正向见 AC-10）

### AC-3a · phase0 命令放行（BUG-C）

- **Given** current_phase=0（非 review phase）
- **When** 任意 Bash 命令（git commit / ls）
- **Then** Gate2（_gate_phase_filter）放行 exit 0（不到 Gate6/7）
- **验证方式**: INT-2 / TEST-5

### AC-3b · 非触发命令放行

- **Given** 任意 phase
- **When** 非触发命令（ls / cat / git status，不含 .flow-active 写 + 非 git commit / gh pr create）
- **Then** 放行 exit 0
- **验证方式**: TEST-5（ls）

### AC-4 · 未配 gate 的 phase 放行（BUG-D）

- **Given** phase 的 gate_config 未配（gate_val 空）
- **When** git commit
- **Then** 放行（不再误 exit2）
- **验证方式**: INT-5

### AC-5 · L2 mock dispatch 无未绑定变量（BUG-G）

- **Given** FLOW_KIT_L2_MOCK=1
- **When** l2_dispatch_agent 派发
- **Then** 写入 `.specs/<id>/INDEPENDENT-REVIEW-<phase>.md` 的 `## L2 盲审` 段（含 mock_ts），无"mock_ts 未绑定"错
- **验证方式**: bats-AC-5a/5c/9（l2-detect.sh 单元测试）

### AC-6 · 全量 bats 全绿（加严 · 用户定 v1）

- **Given** 修复 A-E+G 后（F/H/J/I 在 v2，不影响 bats）
- **When** `npx bats test/test_l2_pretooluse_dispatch.bats`
- **Then** 18/18 全过：smoke(1) + bats-AC-1/2/3/5a/5b/5c/9/10/11(9) + regression×2(2) + INT-1~6(6)
- **验证方式**: `npx bats ... | grep -c '^ok'` == 18 且无 `^not ok`
- **注**: bats-AC-N 是 bats 内部编号（测 l2-detect.sh 函数），与本文档 AC-N 无对应（见测试 ID 定义表）。本文档 AC-8/9/10 的覆盖由 INT-3~6 + AC-10 单元断言保证，不重复计入 bats-AC-N。

### AC-7 · 全链路 toll-gate 状态可断言

- **Given** gate 修复 + 部署，pipeline from-0-all 实跑
- **When** 每阶段独立审查完成 + transition
- **Then** `.flow-active.goal.gates` 全部 "passed"，`.goal.phases_done` == ["0".."6"]，`.goal.current_phase` == "7"
- **验证方式**: `jq -e '(.goal.gates | map(select(.!="passed")) | length) == 0 and .goal.current_phase == "7" and (.goal.phases_done|length)==7' .flow-active`

> **BUG-I 降级（R34）**：AC-7 依赖每阶段真实 `.done` 写入（Stop hook 链，BUG-I v2）。若 BUG-I 在环境触发（Stop hook 未跑），AC-7 的"实跑全程"在 v1 可能不闭环——此时用 AC-9 mock fixture 验证 gate 逻辑层，AC-7 全程实跑留 BUG-I 修复（v2）后完整验证。

### AC-8 · gate_config 向后兼容

- **Given** gate_config[phase]=independent **或 true**（旧值，均测）
- **When** phase∈{1,2,3,5,6,7} git commit 无 .done
- **Then** 视为 both，deny exit 2
- **验证方式**: 两场景 payload 注入 `.flow-active.goal.gate_config["1-requirement"]="independent"` 和 `="true"`，分别跑 gate，断言均 exit 2（R37：补 true 场景）

### AC-9 · 正向：.done 存在则放行（mock fixture · v1 仅 phases_done 短路路径）

- **Given** phase∈{1,2,3,5,6,7} 且 `.independent-review-<phase>.done` 存在 + phase 在 phases_done（fk_validate_done_marker 短路路径）
- **When** git commit
- **Then** Gate4 通过 → allow exit 0
- **验证方式**: INT-6（mock .done + phases_done 含 phase → exit0）

> v1 仅验证 **phases_done 短路路径**（INT-6 可验）。Tier1 6 键校验路径（无 phases_done 短路时）依赖真实 .done 写入（Stop hook，BUG-I v2），v1 不覆盖、留 v2。（回应 R24：移除 OR 双分支歧义）

### AC-10 · fk_independent_review_gate_active 双源读

- **Given** phase∈{1,2,3,5,6,7}
- **When** fk_independent_review_gate_active(phase)
- **Then** 返回值语义：**0 = gate active（已配 gate → 触发 deny）**，**1 = gate inactive（未配 → 放行）**；判定源 = gate_config[phase]（优先），gate_config 空 → stop-hook.json phases（视为 both），**双源皆空 → 返回 1（inactive = 未配 = 放行，与 AC-4 一致）**
- **验证方式**: `source done-validation.sh; PROJECT_ROOT=<tmp> fk_independent_review_gate_active <phase>; echo $?`；三场景：gate_config 源（==0，active）/ stop-hook 回退（==0，active）/ 双源皆空（==1，inactive=放行）

> fail-close 仅适用「已配 gate（both/L2/L3）但无 .done」（AC-2a deny 路径）。未配 gate（双源皆空）= inactive = 放行（AC-4），**非 deny**。此修订消除 v4 AC-10「返回 1（deny）」与 AC-4 的矛盾（R23：return 1 语义是 inactive=放行，v4 误标 deny）。

### AC-11 · L3 model 用 ANTHROPIC_DEFAULT_HAIKU_MODEL（R35）

- **Given** ANTHROPIC_DEFAULT_HAIKU_MODEL 已设（用户的 haiku 定义，如 deepseek-v4-flash[1m] / glm-4.7）
- **When** l3_review_run 调用（L3 外部模型审查）
- **Then** model = ANTHROPIC_DEFAULT_HAIKU_MODEL（无固定 deepseek/claude-haiku fallback；env 未设则报错强制配置）
- **验证方式**: `grep 'ANTHROPIC_DEFAULT_HAIKU_MODEL' flow-kit-bundle/hooks/stop/lib/l3-review.sh` 显示 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:?...}`（强制 env，无 `:-deepseek` / `:-claude-haiku` 固定 fallback）

---

## 范围切分

### v1（本次必做）

- 诊断 L2/L3 gate 7 bug（A-G）—— DIAGNOSE.md（先诊断，用户确认修复 A-E+G）
- 修复 A-E（gate 编排）+ G（l2-detect mock_ts）+ L3 model（haiku env-first，移除固定 deepseek fallback）
- INT-1~6 集成测试防回归
- bats 全绿 18/18
- from-0-all pipeline 实跑（逐阶段 toll-gate 验证 AC-7）

### v2（l2-l3-mock-fix change）

- BUG-F：_gate_deny_reason PHASE_GATE_KEY_MAP 未初始化（phase_name 显示空）
- BUG-H：is_git_commit 文本子串误判（L2 活体发现）
- BUG-J：_l3_check_rerun 用文件 mtime 误判已审查（应检查 ## L3 段）
- BUG-I：Stop hook 链触发可靠性（环境/框架层）

### out（永远不做）

- 其他 hook 子系统重构（26-workflow / auto-checkpoint / L3-bg-*.json）
- L2/L3 调度机制重设计

---

## 非功能性需求

- **性能**: 无
- **安全**: gate 恢复 fail-close（**已配 gate** 的 review phase 未审查不得 commit/transition）；未配 gate（双源皆空）= inactive = 放行（AC-4/AC-10），**非 deny**（R32：删陈旧"双源皆空 deny"子句，它与 AC-4 矛盾且是 L3 误判 deny 的来源）
- **兼容性**: gate_config 向后兼容（independent/true → both，AC-8）
- **可观测性**: exit2 带 stderr（phase 编号 + .done 路径；阻断原因完整依赖 BUG-F v2）

## 依赖与假设

- fk_independent_review_gate_active 双源读由 AC-10 显式验证（不假设"已验证"）
- .done 写入依赖 Stop hook（BUG-I 环境问题，AC-9 用 mock fixture 规避以验证 gate 逻辑层）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
