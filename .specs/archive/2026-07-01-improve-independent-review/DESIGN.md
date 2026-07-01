# DESIGN: 独立 review 模型配置化 + gate-config 预设

- **Change ID**: improve-independent-review
- **关联**: `@.specs/improve-independent-review/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 纯 Bash 脚本项目（meta/distribution），无框架/DB/前端。技术栈锁定自 CONTEXT.md。

- **选定**：Bash 4+（`set -euo pipefail`）+ jq 1.6+
- **语言/运行时**: Bash（项目标准，`package-flow-kit.sh` 同约定）
- **测试**: bats-core 1.13.0（npx）
- **关键依赖**: jq（JSON 处理）、curl（API 调用）、onecli（可选，降级为 fallback）
- **理由**: 项目已有 102 个 bats 测试，jq 是 stop hook 链的标准依赖，无需引入新技术栈
- **明确排除**: Python/Node.js 替代方案（增加依赖链，违反项目"零运行时依赖"原则）

---

## 0.5 既有架构对齐（brownfield）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（来自实际 grep/ls）：
- ~/.claude/hooks/stop/29-independent-review.sh（180 行 · L3 外部模型审查）
- ~/.claude/hooks/stop/30-ai-analyze.sh（156 行 · AI 分析模块）
- ~/.claude/stop-hook.json（129 行 · Stop hook 配置中心）
- ~/.claude/skills/flow/（223 行 · /flow skill 状态管理）
- ~/.claude/flow-kit/prompts/independent/L2-blind-review.md（75 行 · 仅做参考，不修改）

新增/修改范围：
- 29/30 号脚本中新增 env var 读取逻辑（model + API endpoint）
- stop-hook.json 中模型字段改为环境变量引用
- /flow skill 中新增 gate-config 预设/简写解析函数

禁动清单（与本次无关，AI 禁止"顺手"碰）：
- 28-weak-model-compliance.sh（弱模型合规检测，不同关注点）
- L2-blind-review.md（盲审 prompt 本身，明确排除）
- 27-interactive-ui-check.sh
- package-flow-kit.sh（打包脚本核心逻辑，禁动清单明确列出）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| JSON 配置读取 | `config_get()` in `common.sh` | 沿用——通过 config_get 读 stop-hook.json |
| 模块启用检查 | `module_enabled()` in `common.sh` | 沿用 |
| Gate 状态检查 | `fk_independent_review_gate_active()` in `flow-kit-artifacts.sh` | 沿用 |
| 环境变量读取 | Bash 内置 `${VAR:-default}` | 沿用——标准 Bash 参数扩展 |
| API 调用 | curl（29/30 脚本既有） | 沿用——改为优先直连 |
| 原子文件写入 | `tmp + mv` 模式（common.sh 惯例） | 沿用 |
| gate-config 解析 | `/flow` skill 内联 jq 逻辑 | **引入新模式**——新增 `resolve_gate_config()` 函数 |

### 0.5.3 沿用模式 vs 引入新模式

```
- 配置读取：**沿用** config_get() → env var → hardcoded 三级 fallback 链
- API 调用：**沿用** curl 直连 + onecli fallback（仅调整优先级：直连优先）
- 文件写入：**沿用** jq + tmp + mv 原子模式（与 stop hook 一致）
- gate-config 解析：**引入新模式** → 理由：既无预置解析函数，需新建 auto-detect 逻辑
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | 模型名读取优先级：`$ANTHROPIC_DEFAULT_HAIKU_MODEL` > `stop-hook.json` 字段 > `deepseek-v4-flash` | 仅读 env var（无 fallback）/ 仅读 config 文件 | env-var-first 让用户可在 settings.json 统一管理所有模型配置，跨 session 生效；保留 config fallback 确保不设 env var 的老用户不受影响 | 三级 fallback 链增加 ~3 行代码/脚本；优先级冲突时静默选 env var（需在日志中明确标注来源） |
| D2 | API 调用路径：直连 `$ANTHROPIC_BASE_URL` 优先，onecli proxy 可选 fallback | 仅直连（移除 onecli）/ 仅 onecli（保持现状） | 用户环境通过 DeepSeek 兼容 API 直接访问，onecli 是额外依赖；保留 onecli fallback 兼容已装 onecli 的用户 | onecli fallback 代码路径保留但实际可能永远不走（取决于环境）；需在 HTTP 403/连接失败时优雅降级到 onecli |
| D3 | gate-config 解析策略：auto-detect 三段式（合法 JSON → 预设名 → 数字简写 → 报错） | 每种格式独立 flag / 仅支持 JSON | 同一条 `--gate-config` 兼容三种格式，不增加用户认知负担 | 解析逻辑从 3 行 jq 变为 ~20 行 case/branch；"1" 作为字符串既是合法 JSON 又是数字简写——优先按合法 JSON 解析（`jq empty` 检测） |
| D4 | gate-config 预设命名：语义化英文名（full/code-only/design/requirement/review/plan/design-review/requirement-review） | 中文名 / 纯数字编号 | 与 flow-kit 其他配置（kebab-case、英文 AC 标题）风格一致；英文名可自解释（code-only = 仅代码审查） | 非英语用户需查表；在 `/flow` skill 帮助文本中内嵌映射表 |
| D5 | stop-hook.json 保留硬编码值不变 | 改为环境变量占位符字符串 | 脚本层 D1 已实现 env-var-first，无需改 config 文件格式。stop-hook.json 是 11 个 hook 模块的共享配置中心，改格式会造成跨模块破坏性变更（参见风险 R2） | 用户看 stop-hook.json 时不知道 env var 可覆盖——在脚本注释和 `/flow doctor` 输出中标注覆盖关系 |

---

## 2. 数据流 / 架构图

### 2.1 L3 模型配置 + API 调用流

```
~/.claude/settings.json (env)
  │  ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash
  │  ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
  │  ANTHROPIC_AUTH_TOKEN=sk-...
  ▼
29-independent-review.sh / 30-ai-analyze.sh
  │  1. model=${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$(config_get ... "deepseek-v4-flash")}
  │  2. base_url=${ANTHROPIC_BASE_URL:-"https://api.anthropic.com"}
  │  3. auth=${ANTHROPIC_AUTH_TOKEN:-}
  ▼
  ├─ onecli 存在? ──yes──> onecli proxy curl $base_url/v1/messages
  └─ no ─────────> curl -H "Authorization: Bearer $auth" $base_url/v1/messages
                         │
                         ▼
                    INDEPENDENT-REVIEW-<phase>.md
```

### 2.2 gate-config 解析流

```
/flow goal "..." --pipeline --from 0 --gate-config <value>
  │
  ▼
resolve_gate_config(value):
  ├─ echo "$value" | jq empty 成功? → 合法 JSON → 直接使用（向后兼容）
  ├─ value in PRESET_MAP? → 预设名 → 查表映射为 JSON
  ├─ value =~ /^[0-9](,[0-9])*$/ ? → 数字简写 → 拆分 + 映射为 JSON
  └─ 以上都不匹配 → ❌ 报错：无效 gate-config
  │
  ▼
jq 写入 .flow-active.goal.gate_config
```

PRESET_MAP:
```
full                → {"1-requirement":"independent","2-design":"independent","6-review":"independent"}
code-only           → {"6-review":"independent"}
design              → {"2-design":"independent"}
requirement         → {"1-requirement":"independent"}
review              → {"6-review":"independent"}    # alias of code-only
plan                → {"1-requirement":"independent","2-design":"independent"}
design-review       → {"2-design":"independent","6-review":"independent"}
requirement-review  → {"1-requirement":"independent","6-review":"independent"}
```

数字映射:
```
1 → "1-requirement"
2 → "2-design"
6 → "6-review"
```

---

## 3. ADR 索引

无不可逆架构决策。所有决策均为 hook 脚本内部实现细节，不影响 flow-kit 外部接口契约。

---

## 4. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **实现风险**：env var 展开逻辑错误导致模型名为空字符串，API 调用静默失败 | L3 review 不可用，independent review gate 卡死 | 低 | 三级 fallback 确保最低回退到硬编码 `deepseek-v4-flash`；bats 测试覆盖 env var 空/未设/错误值三场景 |
| R2 | **上线风险**：env-var-first 行为变更后，已有环境中 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 可能已设但指向旧模型（如用户之前设过但忘了），静默切换导致 L3 review 质量变化 | 用户环境中 env var 可能指向过期模型 | 低 | stop-hook.json 保留 `deepseek-v4-flash` 硬编码值作为显式 fallback；hook 日志输出实际使用的模型名和来源（env var 或 config），用户可据此排查 |
| R3 | **长期债务**：gate-config 预设名硬编码在 `/flow` skill 中，新增阶段（如 phase 8）需同步更新 | 未来流程扩展时预设映射表过时 | 低 | PRESET_MAP 集中定义在 skill 文件顶部，加注释标注"新增阶段时同步更新"；bats 测试会因映射表不一致而失败，起哨兵作用 |
| R4 | **兼容性风险**：移除 onecli 优先路径后，依赖 onecli 特殊路由（如内网代理）的环境可能断连 | 特定企业环境 L3 review 不可用 | 低 | onecli 保留为 fallback（有则用，无则跳过），不主动移除；仅在 `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 均已设置时优先直连 |
| R5 | **安全风险**：curl 命令中 `$ANTHROPIC_AUTH_TOKEN` 被 `set -x` 或错误日志暴露 | Token 泄露到终端输出/日志文件 | 低 | AC-9 约束：不将 AUTH_TOKEN 传入 echo/module_output；curl 使用 `-H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN"` 格式（Bash 不会在 `-x` 中展开字符串内的变量，但 Header 值仍会展开——需确认）。额外缓解：禁止在 hook 脚本中使用 `set -x` |

---

## 5. 不在范围

- 统一所有 hook 模块的 API 调用方式（仅改 29+30 号）
- 为 gate-config 提供交互式 UI 选择器（如 `AskUserQuestion` 列出预设选项）
- 将 env-var-first 模式推广到其他配置项（如 `max_artifact_chars`、`max_failures_before_bypass`）
- 运行时模型能力自动探测（弱模型不可靠，见 CONTEXT.md 已锁决策 127）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| 29/30 号脚本中的 `resolve_model()` 模式 | env-var-first + config-fallback + hardcoded-default 三级链 | 任何 hook 脚本需要读取可覆盖配置项时 | 待本次验证后，可提取为 `common.sh` 的 `config_get_with_env()` 通用函数供其他模块复用 |

### 9.2 新增 / 改变的项目级技术决策

本 change 无项目级技术决策变更。env-var-first 仅应用于模型和 API endpoint 两个字段，不升级为全局约定。

### 9.3 新增 / 修改的跨模块契约

无。L3 API 调用的请求/响应格式不变；gate-config JSON 写入格式不变（仅入口解析层扩展）。

### 9.4 新增 / 升级的依赖

无新增依赖。

### 9.5 禁动清单变化

```
- 新增禁动：无
- 解禁：无
```

---
> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
