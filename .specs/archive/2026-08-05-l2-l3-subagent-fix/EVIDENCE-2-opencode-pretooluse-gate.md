# EVIDENCE-2 — opencode 环节②实测：PreToolUse gate 触发链路

> 任务：T02（opencode 环节②） · change-id: l2-l3-subagent-fix
> 日期：2026-08-05 · 平台：opencode 1.18.9（本运行时）
> 对应：REQUIREMENT.md AC-1 环节②（opencode 侧）

## 实测步骤

1. 定位 gate 脚本注册位置：`~/.claude/settings.json` PreToolUse matcher `Bash|Write|Edit` → `bash ${HOME}/.claude/hooks/pre-tool-use/independent-review-gate.sh`
2. 检查 opencode 侧等效注册：`~/.config/opencode/opencode.json`（hooks 字段）、`~/.config/opencode/opencode.jsonc`、项目级 `.opencode/`、plugin 目录
3. 检查 opencode 运行时日志（`~/.local/share/opencode/log/opencode.log`）中 gate 触发痕迹
4. 手动模拟 PreToolUse stdin 喂给 gate 脚本，验证脚本逻辑本身（隔离临时 .flow-active，PROJECT_ROOT 指向模拟目录）
5. 检查 opencode 1.18.9 config schema 原生 hook 事件能力（sdk types.gen.d.ts）

## 观测结果

### 注册侧：gate 只注册在 claude code 配置

- `~/.claude/settings.json` PreToolUse 第 3 条：matcher `Bash|Write|Edit` → `bash "${HOME}/.claude/hooks/pre-tool-use/independent-review-gate.sh"`（**claude code 专属**，opencode 不读此文件——OPENCODE-INSTALL.md L42 明示「opencode 不原生读取 ~/.claude/settings.json」）
- 项目级 `.claude/settings.local.json` = `{"hooks": {}}`（空 hooks）
- `~/.config/opencode/opencode.json` plugin 数组 = `["oh-my-opencode", "opencode-acp@latest"]` —— **无 opencode-claude-hooks 桥接插件**（OPENCODE-INSTALL.md 方案 A 要求装此插件才有 hooks）
- `~/.config/opencode/plugin/` 目录**不存在**
- 项目级 `.opencode/hooks/` 目录**不存在**（OPENCODE-INSTALL.md 方案 C 声称安装器会建 `.opencode/hooks/`，实测未建）
- `~/.claude/hooks/pre-tool-use/independent-review-gate.sh` 存在（6029B，8-04 更新）——但只被 claude code 调用

### 运行时侧：opencode 日志零 gate 痕迹

- `opencode.log` 中 grep `independent-review|pre-tool-use|hook` → 仅 permission 评估记录（`evaluated permission=bash pattern="...independent-review-gate.sh..." action=allow`），**无任何 hook 事件触发记录**
- 说明：gate 脚本在本 opencode 会话中从未作为 hook 被调用过（手动 bash 调用除外）

### 平台能力侧：opencode 1.18.9 无 PreToolUse/Stop 事件

- sdk `types.gen.d.ts` L1170-1190 config schema：`experimental.hook` 仅 `file_edited`（编辑后）与 `session_completed`（会话完成）两事件
- **无 PreToolUse / PostToolUse / SessionStart / Stop / UserPromptSubmit** 事件定义
- 结论：即便不装桥接插件，opencode 原生也无阶段切换/工具调用前拦截点

### gate 脚本自身逻辑（手动模拟验证，脚本无平台问题）

隔离目录模拟（PROJECT_ROOT=$T, .flow-active: phase=3, gate_config[3-task]=L2, 无 .done）：

- **Write .done + gate_config=L2** → exit 0 放行（L2-only 例外，`_gate_is_l2_only` L34-45 读取 `fk_phase_gate_key` 映射 phase→3-task → gate_config=L2 → 放行）✓ 符合协议
- **Write .done + gate 未开（gate_config={}）** → exit 2 拦截（path-guard D7，`_gate_path_guard` L58-94，fail-open 语义下 path-guard 独立生效）✓
- **Bash transition + phase=3** → 未拦截 exit 0（见下「gate 自身 bug」）

## 附加发现：gate 自身 bug（_fk_phase_direction 转义引号失效）

`_fk_phase_direction`（gate-helpers-types.sh L67-75）用正则 `current_phase[[:space:]]*=[[:space:]]*"\K[0-7]` 提取目标 phase：

- 命令含 shell 转义引号 `jq ".goal.current_phase = \"4\""` 时，`\` 字符挡在 `"` 前 → 正则不匹配 → target 空 → 返回 `noop` → `_gate_phase_transition`（gate-checks-review.sh L40）提前 exit 0 放行
- 真实 PreToolUse stdin 的 command 字段经 JSON 序列化后 `"` → `\"`，命令文本中保留 `\"` 转义 → **phase transition 命令若用双引号包裹 jq 表达式，gate 会漏检**
- 影响：环节②在 claude code 下若 transition 命令写成 `jq ".goal.current_phase = \"4\""`（双引号外层），gate 拦截失效（noop 分支）；单引号写法 `jq '.goal.current_phase = "4"'` 无此问题
- 严重度：🟡 Major（gate 校验可被特定命令写法绕过，非平台差异）

## 现象分类（对照 CHANGE.md「拉起失败」两类现象）

- **现象 A（派发命令架构不兼容）命中（结构性根因）**：环节② PreToolUse gate 的注册载体是 claude code 的 settings.json hooks 机制，opencode 无此机制且未装桥接插件 → gate 在 opencode **零触发**。这不是脚本 bug，是**平台架构差异**：flow-kit 的 gate 链（independent-review-gate.sh + 29-independent-review.sh Stop hook）设计绑定 Claude Code hooks 生命周期
- 现象 B 不适用本环节（无 env var 依赖）

## 结论（环节② opencode 是否可拉起）

- **环节② gate 在 opencode 下完全不触发**（结构性根因 #1）：
  1. 注册文件 `~/.claude/settings.json` opencode 不读
  2. opencode.json 未装 opencode-claude-hooks 桥接插件
  3. 项目级 `.opencode/hooks/` 不存在
  4. opencode 1.18.9 原生无 PreToolUse/Stop hook 事件（仅 file_edited/session_completed）
- gate 脚本自身逻辑经手动模拟验证**正确**（L2-only 放行、path-guard 拦截均符合协议）——问题在注册链路不在脚本
- 附带：`_fk_phase_direction` 转义引号漏检（gate 自身 🟡 bug，双平台通用）

## 脱敏声明

- 无 env var 凭证涉及；日志仅引用 permission 评估行，不含敏感值
