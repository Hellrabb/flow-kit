# 诊断报告 · L2/L3 独立审查机制实跑验证

- **Change**: l2-l3-test-defect
- **诊断日期**: 2026-07-17
- **方法**: pipeline `--from 0 --gate-config all` 实跑 + hook 直接 payload 注入（ctx_execute，绕过框架 PreToolUse 以拿 exit code/stderr 铁证）
- **被测版本**: HEAD=749ec36 + 工作区 l2-pretooluse-dispatch 改动（已 stage 未提交）

---

## 执行摘要

诊断启动第一步（0→1 transition）即撞上 **4 个关联 bug**，根因同一：**`_gate_phase_filter` / `_gate_active_check` 的 `return 0/1` 语义与调用方 `_run_review_gates` 的 `|| exit 0` bash 惯例系统性反转**。后果双向：from-0 pipeline 第一步死锁；review phase（1-7）gate 实际完全失效。

## 实跑证据矩阵

| TEST | 命令 | phase | exit | stderr | 命中 |
|---|---|---|---|---|---|
| 1 | `jq '.goal.current_phase = "1" ...' .flow-active > .tmp && mv`（字面双引号） | 0 | **2** | **无** | A+D |
| 2 | `git commit -m "test"`（纯，trace） | 0 | **1** | trace 止于 `_gate_phase_transition return 1` | C |
| 3 | `git commit`（前置 current_phase=1） | 1 | **0** | — | B |
| 4 | 原始组合（commit heredoc + transition + log + status） | 0 | **2** | **无** | A+D |

复现脚本：`jq -n '{tool_name:"Bash",tool_input:{command:$c},cwd:$cwd}' | bash ~/.claude/hooks/pre-tool-use/independent-review-gate.sh; echo "EXIT=$?"`

## 缺陷清单

### BUG-A · phase 0 forward transition 死锁（critical · P0 阻塞）

- **症状**：任何 `--from 0` pipeline，0→1 transition 被 exit 2 拦截，无 stderr
- **代码**：`_gate_phase_filter` line 144 `[[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || return 0`（phase=0 → return 0=skip）；调用方 line 417 `pf_output=$(_gate_phase_filter "$flow_file") || exit 0`（return 0=成功 → `||` 不触发 → 继续 Gate 3-7，本该 skip）；Gate 6 `_gate_phase_transition` forward，gate_val="" → `_gate_check_l3` line 292 `else exit 2`
- **影响**：from-0 pipeline 无法启动

### BUG-B · review phase gate 反向失效（critical · 安全门禁形同虚设）

- **症状**：phase 1-7 的 commit/transition 畅通无阻（TEST 3 exit 0）
- **代码**：`_gate_phase_filter` 对 review phase return 1（continue）；line 417 `|| exit 0`（return 1=非0 → 触发 → exit 0 放行）
- **影响**：L2/L3 独立审查 gate 对真正的 review phase **完全不生效**——比 BUG-A 更严重

### BUG-C · set -e 意外退出跳过 Gate 7

- **症状**：纯 git commit（不写 .flow-active）在 phase 0 exit 1（异常）
- **代码**：`_gate_phase_transition` line 349 `if ! is_phase_write "$cmd"; then return 1; fi`；line 433 `_gate_phase_transition ...` 在 `set -euo pipefail` 下把 return 1 当失败 → 脚本 exit 1，跳过 Gate 7 deny

### BUG-D · deny 无诊断输出

- **症状**：被拦时 "No stderr output"，AI 不知为何
- **代码**：`_gate_check_l3` line 292 `else exit 2; fi` 缺 `cat >&2`（其余 exit 2 均有）

## 测试方案漏洞假说（待验证）

`test_l2_pretooluse_dispatch.bats`（12 tests，声称全绿）为何没抓到？最可能：bats 用 `\"` 转义构造命令 payload → `_fk_phase_direction` 的 `grep -oP 'current_phase[[:space:]]*=[[:space:]]*"\K[0-7]'` 匹配不到字面 `\"`（反斜杠在引号前）→ target="" → 误判 noop → exit 0 → 测试期望 exit 0 实得 exit 0 → **假绿**。正向 forward transition 路径从未被真正覆盖。本诊断 TEST 1（单引号 `\"`）exit 0 vs TEST 1（字面双引号）exit 2 的差异直接佐证。

## 根因

`independent-review-gate.sh` 多个 gate 函数采用 `return 0=skip/未开, return 1=continue/开` 的约定（类 C 的 0=false），但 `_run_review_gates` 用 bash `cmd || exit 0`（非0=失败→放行）消费返回值。两套语义相反 → 双向 bug。修复方向二选一：
- (a) 把 gate 函数 return 语义改成 bash 惯例（0=成功/继续检查，非0=skip→放行）
- (b) 调用方改用显式判定（`pf_output=$(...); rc=$?; [ $rc -eq 1 ] || exit 0`）而非 `|| exit 0`

## 对本 change 的影响

- pipeline 卡在 phase 0，无法自动推进
- 已 stage 的 35 文件（l2-pretooluse-dispatch 成果）**无法 commit**（BUG-A/C 阻塞 git commit）
- 待决策：先修 bug 解阻塞，还是手动 bypass 继续观察后续 phase

## 修复结果（2026-07-17 · 用户选"修4bug+补测试+重跑"）

诊断性修复深入到 **5 个 bug（A-E）**，全部修复 + 部署到 user-scope + 实跑验证通过。

### 修复清单

| BUG | 修复 | 验证 |
|---|---|---|
| A | Gate2 `pf_output=$(...)\|\|exit0` → `if pf_output=$(...);then exit0;fi`（显式 rc 判定） | TEST1 exit0 ✓ |
| B | 同 Gate2 + Gate3 if 判定（return0/1 语义反转） | TEST3/6 exit2 ✓ |
| C | _gate_phase_transition `return1`→`return0` | TEST2 exit0 ✓ |
| D | _gate_check_l3 line292 分支化（gate_val 空→exit0 / 异常→exit2+stderr） | TEST3/6 stderr 正常 ✓ |
| E | _gate_active_check source **done-validation.sh**（函数真正定义处）+ 传 PROJECT_ROOT=cwd | TEST3/6 gate 生效 ✓ |

### 实跑验证（payload 注入 ~/.claude/ 部署版）

| TEST | 场景 | 修复前 | 修复后 |
|---|---|---|---|
| 1 | phase0 forward transition | exit2 无stderr | exit0 ✓ |
| 2 | phase0 纯 git commit | exit1（BUG-C） | exit0 ✓ |
| 3 | phase1 git commit 无.done | exit0（gate失效） | exit2+stderr ✓ |
| 4 | phase0 组合 commit+transition | exit2 无stderr | exit0 ✓ |
| 5 | phase0 纯 ls | exit0 | exit0 ✓ |
| 6 | phase6 git commit 无.done | exit0（gate失效） | exit2+stderr ✓ |

### 残留瑕疵 BUG-F（非阻塞 · 归属后续 change）

TEST3/6 stderr 显示「阶段 1 ()」——括号内 phase_name 空。根因：`_gate_deny_reason` 用 `PHASE_GATE_KEY_MAP[$phase]` 但该数组从未初始化。不影响 gate 功能（数字 phase deny 正确），仅显示瑕疵。

### 遗留 BUG-G（l2-detect.sh · 归属后续 change · 非本次引入）

跑现有 bats 发现 AC-5a/5c/9 三个 mock 测试失败：`l2-detect.sh:120 mock_ts: 未绑定的变量`（`set -u` 下 mock_ts 未定义）。**非本次诊断引入**（未改 l2-detect.sh），是 l2-pretooluse-dispatch change 遗留。关键意义：上个 change CHANGELOG 声称「12 tests 全绿」实为**假绿**——这 3 个 mock 测试一直失败，坐实"测试方案有缺陷"的直觉。

### 测试方案核心缺陷（已补集成测试固化）

现有 AC-1~11 全是单元级（source l2-detect.sh + 调单函数），**0 个**通过 _run_review_gates 完整入口跑 → BUG-A/B/C/D/E（全在编排层 + lib source 层）根本覆盖不到。本次已补 **INT-1~5** 集成测试（payload 注入 `bash gate.sh` + exit code 断言），覆盖 BUG-A/C/B+E/D，全部通过。现有 17 tests：**14 过**（含 5 新 INT）/ 3 失败（BUG-G 遗留）。

## 下一步（用户定：固化 A-E · F/G 开新 change）

- ✅ A-E 已修 + 部署 user-scope + INT-1~5 防回归
- ⏭️ commit A-E 修复 + 本 DIAGNOSE 报告（l2-l3-test-defect 产物）
- ⏭️ F/G 开 `l2-l3-mock-fix` change 专门修（不同子系统：phase_name 显示 / l2-detect mock_ts）
- ⏭️ commit 后 transition 0→1（gate 修复后不再死锁）
