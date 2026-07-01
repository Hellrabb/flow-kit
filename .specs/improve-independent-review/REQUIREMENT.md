# REQUIREMENT: 独立 review 模型配置化 + gate-config 预设

- **Change ID**: improve-independent-review
- **关联**: `@.specs/improve-independent-review/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想 L3 独立 review 使用我 session 中配置的 haiku-tier 模型（`ANTHROPIC_DEFAULT_HAIKU_MODEL`），以便切换 API 提供商时无需手动改 hook 脚本。
- **US-2**：作为 flow-kit 用户，我想 L3 review 直连我配置的 API endpoint（`ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN`），以便在不安装 onecli 的环境中也正常运行。
- **US-3**：作为 flow-kit 用户，我想用简短预设名或数字设定 gate-config，以便省去手写 JSON 的繁琐。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 29 号 hook 读环境变量模型

- **Given** 用户已在 `~/.claude/settings.json` 的 `env` 中设置 `ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash`
- **When** Stop hook 触发 29-independent-review.sh，且 independent_review gate 对当前阶段开启
- **Then** L3 API 调用使用的 model 参数为 `deepseek-v4-flash`（从 env var 读取），而非硬编码值
- **验证方式**: `grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL' ~/.claude/hooks/stop/29-independent-review.sh` 返回 ≥1

### AC-2 · 30 号 hook 同样读环境变量

- **Given** 同上环境变量已设置
- **When** Stop hook 触发 30-ai-analyze.sh
- **Then** AI 分析使用的 model 参数从 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 读取，API 请求发送至 `$ANTHROPIC_BASE_URL`（与 29 号同策略）
- **验证方式**: `grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL' ~/.claude/hooks/stop/30-ai-analyze.sh` 返回 ≥1；`grep -c 'ANTHROPIC_BASE_URL' ~/.claude/hooks/stop/30-ai-analyze.sh` 返回 ≥1

### AC-3 · 环境变量缺失时回退默认值

- **Given** `ANTHROPIC_DEFAULT_HAIKU_MODEL` 环境变量未设置
- **When** 29 或 30 号 hook 脚本执行
- **Then** 模型名回退到 `deepseek-v4-flash`（保持向后兼容）
- **验证方式**: 脚本中 fallback 逻辑为 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-deepseek-v4-flash}`

### AC-4 · API 直连 $ANTHROPIC_BASE_URL

- **Given** 用户已在 `env` 中设置 `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic` 和 `ANTHROPIC_AUTH_TOKEN`
- **When** 29 号 hook 调用外部模型 API
- **Then** 请求发送至 `$ANTHROPIC_BASE_URL/v1/messages`，Header 为 `Authorization: Bearer $ANTHROPIC_AUTH_TOKEN`，onecli proxy 降级为可选（有则用，无则直连不报错）
- **验证方式**: `grep 'ANTHROPIC_BASE_URL' ~/.claude/hooks/stop/29-independent-review.sh` 返回 ≥1；`grep 'ANTHROPIC_AUTH_TOKEN' ~/.claude/hooks/stop/29-independent-review.sh` 返回 ≥1

### AC-5 · 脚本优先读环境变量，config 文件作为 fallback

- **Given** 环境变量 `ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash`，且 stop-hook.json 中 `ai.model` 和 `independent_review.model` 为硬编码值（如 `deepseek-v4-pro`）
- **When** 29 或 30 号 hook 脚本读取模型配置
- **Then** 脚本使用 env var 值 `deepseek-v4-flash`（而非 config 文件中的 `deepseek-v4-pro`）
- **验证方式**: bats 集成测试——以不同 env var 值执行脚本，捕获实际传参，断言为 env var 值

### AC-6 · gate-config 预设名识别

- **Given** 用户执行 `/flow goal "..." --pipeline --from 0 --gate-config full`
- **When** `/flow` skill 解析 `--gate-config` 参数
- **Then** gate_config 写入 `{"1-requirement":"independent","2-design":"independent","6-review":"independent"}`
- **验证方式**: 执行后 `jq '.goal.gate_config' .flow-active` 输出含三个 key 且值均为 `"independent"`

### AC-7 · gate-config 数字简写识别

- **Given** 用户执行 `/flow goal "..." --pipeline --from 0 --gate-config 6`
- **When** `/flow` skill 解析参数
- **Then** gate_config 写入 `{"6-review":"independent"}`
- **验证方式**: 执行后 `jq '.goal.gate_config' .flow-active` 输出仅含 `"6-review":"independent"`

### AC-8 · 向后兼容完整 JSON

- **Given** 用户执行 `/flow goal "..." --pipeline --from 0 --gate-config '{"1-requirement":"independent"}'`
- **When** `/flow` skill 解析参数（检测到合法 JSON）
- **Then** 直接使用该 JSON，行为与修改前一致
- **验证方式**: 执行后 `jq '.goal.gate_config' .flow-active` 输出与输入 JSON 一致

### AC-9 · API token 不泄露到日志

- **Given** 29/30 号 hook 脚本中使用了 `$ANTHROPIC_AUTH_TOKEN`
- **When** hook 脚本输出日志或错误信息
- **Then** 日志中不含 token 明文（`echo`/`module_output` 不引用 `$ANTHROPIC_AUTH_TOKEN`）
- **验证方式**: `grep -n 'ANTHROPIC_AUTH_TOKEN' ~/.claude/hooks/stop/29-independent-review.sh ~/.claude/hooks/stop/30-ai-analyze.sh` 返回的行均为赋值或 curl Header 引用，无 `echo` / `module_output` 行包含该变量

---

## 范围切分

### v1（本次必做）

- 29-independent-review.sh：模型读 `$ANTHROPIC_DEFAULT_HAIKU_MODEL`，API 直连 `$ANTHROPIC_BASE_URL`
- 30-ai-analyze.sh：同上
- stop-hook.json：`ai.model` + `independent_review.model` 指向环境变量引用
- `/flow goal --gate-config`：支持 8 种预设名 + 数字简写 + 完整 JSON
- bats 测试覆盖新增解析逻辑

### v2（下一轮考虑，不本次）

- 清查其他 hook 模块中是否还有 onecli 依赖
- 将 `ANTHROPIC_BASE_URL` 的 fallback 默认值也写入 stop-hook.json 配置
- gate-config 预设支持用户自定义别名

### out（永远不做）

- 运行时自动探测模型能力并切换（不可靠，弱模型会幻觉）
- 改动 L2 盲审 prompt（`L2-blind-review.md`）本身
- 移除 onecli 的所有其他使用场景（仅在 29/30 号脚本中调整优先级）

---

## 非功能性需求

- **性能**: 无（纯配置变更，不影响执行时间）
- **可访问性**: 无
- **安全**: hook 脚本中 API token 不得出现在日志输出或错误信息中
- **兼容性**: 向后兼容——环境变量未设置时回退到 `deepseek-v4-flash`；onecli 存在时仍可用（降级为可选而非移除）
- **可观测性**: hook 脚本输出应注明实际使用的模型名和 API endpoint（如 `IR L3 完成（模型=deepseek-v4-flash, endpoint=api.deepseek.com）`）

## 依赖与假设

- 假设用户已在 `~/.claude/settings.json` 的 `env` 字段中配置了 `ANTHROPIC_DEFAULT_HAIKU_MODEL`、`ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`
- 假设 onecli 并非所有用户都安装——不能作为唯一路径
- 依赖 `jq` 处理 JSON（与现有 hook 一致）
- `/flow` skill 修改依赖 `~/.claude/skills/flow/` 目录下的 skill 文件

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
