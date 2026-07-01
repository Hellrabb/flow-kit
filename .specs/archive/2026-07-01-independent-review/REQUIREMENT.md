# REQUIREMENT: 独立 Review Agent

- **Change ID**: independent-review
- **关联**: `@.specs/independent-review/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我希望在 6-review 阶段有独立的第二意见审查我的代码，以防主 agent 自审放过自己的错误。
- **US-2**：作为 flow-kit 用户，我希望能显式开启/关闭某阶段的独立 review（默认关闭），按需付费，不被强制消费 token。
- **US-3**：作为 flow-kit 用户，我希望独立 review 开启后**主 agent 无法绕过**——即不完成 review 就无法 commit/切阶段/开 PR。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · L3 Stop 模块盲审

- **Given** 某 change 在阶段 6 且 gate_config["6-review"] = "independent"
- **When** Stop hook 触发（主 agent 本轮结束）
- **Then** 29-independent-review.sh 调 deepseek-v4-flash 盲审 git diff + REVIEW.md，产出 .specs/<id>/INDEPENDENT-REVIEW-6.md 并写 .flow-active.independent-review 握手（status=done）。无凭证时降级写 status=failed + fail_count 递增，连续 ≥3 次提示允许手动绕过。
- **验证方式**: `bash -n` 语法通过 + 临时环境模拟 Stop hook 触发（无 onecli/API key → 降级写 failed）

### AC-2 · PreToolUse 硬拦截

- **Given** 某 change 在阶段 6 且 gate 开启 + done 标志不存在
- **When** 主 agent 尝试 `git commit` / `gh pr create` / 改 .flow-active 阶段的 jq
- **Then** PreToolUse hook exit 2 deny，stderr 提示未完成独立 review
- **验证方式**: 构造 .flow-active + 模拟 stdin → 验证 exit 2；gate 关/done 存在/jq 只读 等误伤场景验证 exit 0

### AC-3 · fk_auto_phase gate（防线1）

- **Given** 某 change 在阶段 6 且 gate 开启 + done 标志不存在
- **When** Stop hook 内 fk_auto_phase 判断是否自动推进到 7
- **Then** fk_auto_phase 返回空（不推进）。done 写后返回 7。
- **验证方式**: source flow-kit-artifacts.sh → 调 fk_auto_phase → 验证返回值

### AC-4 · SessionStart 注入独立 review 摘要

- **Given** .flow-active.independent-review 存在且 status=done 且 done 标志不存在
- **When** 新会话启动（SessionStart hook）
- **Then** flow-kit-resume.sh 打印「独立 review 报告就绪」框，含 verdict + 报告路径
- **验证方式**: 构造 .flow-active.independent-review + 模拟 stdin → 验证 banner 输出

### AC-5 · 打包完整性校验

- **Given** flow-kit-bundle/ 已包含所有新文件
- **When** 运行 `package-flow-kit.sh --validate`
- **Then** 校验通过（新文件 29-independent-review.sh / independent-review-gate.sh / L2-blind-review.md 均在 Part 对应段声明，不报漏配）
- **验证方式**: `bash flow-kit-bundle/package-flow-kit.sh --validate`

### AC-6 · 安装端到端

- **Given** 一个空项目
- **When** 运行 `install.sh <项目>`（project scope）
- **Then** 项目 .claude/ 含 hooks/stop/29-independent-review.sh、hooks/pre-tool-use/independent-review-gate.sh 且 settings.local.json 含 Stop + PreToolUse 接线
- **验证方式**: 临时目录跑 install_hooks → 验证文件存在 + jq 验证接线

### AC-7 · 现有 bats 无回归

- **Given** flow-kit-bundle/test/ 下所有 bats 文件
- **When** 运行 `npx bats flow-kit-bundle/test/`
- **Then** 0 failures（102 tests pass）
- **验证方式**: `npx bats --formatter tap flow-kit-bundle/test/ 2>&1 | grep -c 'not ok'` = 0

---

## 范围切分

### v1（本次必做）

- L3: 29-independent-review.sh + PreToolUse gate + fk_auto_phase gate
- L2: L2-blind-review.md 固化模板 + 三阶段 prompt 挂载
- 分发: install_hooks 补 27/28/29 + PreToolUse 接线 + stop-hook.json schema
- 状态机: /flow gate-config 子命令 + SessionStart 注入
- 测试: bats 全绿 + 打包校验 + install 验证

### v2（下一轮考虑，不本次）

- L2 自定义 subagent_type（固化 system prompt，主 agent 无法覆盖）
- L3 phase_models（按阶段配不同模型）
- 阶段 4/5/7 的独立 review 覆盖
- L3 真实模型调用验证（需目标环境 onecli 配通 deepseek）

### out（永远不做）

- 用主 agent 自己跑"独立 review"（伪独立，不改变触发权归属）
- 仅靠 prompt 自我约束而不加 hook 机制（独立性零保障）

---

## 非功能性需求

- **性能**: L3 外部模型调用不等同频门控（独立质量门不随机跳过），用幂等防重复。失败降级不卡死流水线（3 次后允许绕过）。
- **安全**: jq --arg 构造 prompt 防反引号/$ 注入（不用 heredoc 插值）。PreToolUse fail-open 原则（不确定就放行，不卡用户）。
- **兼容性**: 不改 flow-kit 既有阶段流程，只新增可选 gate。默认关闭，不影响现有 change。
- **可观测性**: 29 模块通过 module_output 写 Stop 报告；握手文件 .flow-active.independent-review 记录 L3 状态；SessionStart 注入显示摘要。
- **可访问性**: 无

## 依赖与假设

- onecli proxy 可用（L3 调 deepseek-v4-flash）；onecli 不可用时降级不走 L3（fail_count 递增）
- Claude Code 支持 PreToolUse hook + exit 2 deny + Agent tool 子 agent 独立上下文
- 本项目为 Bash 项目，测试用 bats-core 1.13.0
- flow-kit 现有 Stop hook 体系（00-gate.sh 调度链）不被本次改动打破
