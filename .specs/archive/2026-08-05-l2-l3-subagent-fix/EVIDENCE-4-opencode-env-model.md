# EVIDENCE-4 — opencode 环节④实测：env 透传 + L3 API 直连 + 模型绑定层

- **change**: l2-l3-subagent-fix · 阶段 4 · T04 · 2026-08-05
- **read_files**: common.sh / l3-api.sh / l3-review.sh / l3-prompt.sh / l3-done.sh / ADR-020

## 实测步骤

### (a) env var 透传（fk_resolve_model 三级链）

1. 宿主 shell env 扫描：`env | grep -E '^(ANTHROPIC|FLOW_KIT)'` → **NONE SET**
2. `fk_resolve_model "L2"`（common.sh L249-264 三级链）实测 → **空串**
   `fk_resolve_model "L3"` → **空串**
   （三级链 = ANTHROPIC_DEFAULT_HAIKU_MODEL > FLOW_KIT_L3_MODEL > .goal.l3_model，全空）
3. `_l3_call_api` env 解析（l3-api.sh L20-21 dry 实测）：
   - `base_url=${ANTHROPIC_BASE_URL:-https://api.anthropic.com}` → **https://api.anthropic.com**
   - `auth_token=${ANTHROPIC_AUTH_TOKEN:-}` → **未设置**
   - `ANTHROPIC_API_KEY` → **未设置**
   → Path1 (Bearer) 与 Path2 (x-api-key) 均不满足，`_l3_call_api` 无凭证可发。
4. l3-review.sh L57-61 实测结论：`fk_resolve_model "L3"` 空 → **return 3（API 调用前降级）**，
   输出 `[l3-review] L3 模型未配置（三级链全空）`。

### (b) 模型绑定层验证（盲审发现 R1 · ADR-020 三层模型选择）

1. `opencode models` 全量列表 → **无 sonnet / 无 anthropic provider**：
   - opencode/*（deepseek-v4-flash-free 等 8 个 free 模型）
   - alibaba-token-plan-cn/*（deepseek-v3.2/v4-flash/v4-pro、glm-5/5.1/5.2、kimi-* 等）
   - deepseek/*、zhipuai-coding-plan/*、zai-coding-plan/*（部分截断）
2. 三层模型选择对照（ADR-020 · 2026-08-03 已接受）：
   - **Harness 配置层**：opencode.json 无 model 绑定（本环境未配置）
   - **Category 路由层**：实测 `task(category=quick)` → Model = `deepseek/deepseek-v4-flash (category: quick)`——**实际生效层**
   - **子 agent 覆盖层**：实测 `task(subagent_type=qa-expert)` → agent 声明 `model: sonnet` → 无 provider 可解析 → **30min 超时无产出**
3. **差异矩阵回答「子 agent 模型由哪一层决定」**：
   | 层 | opencode | claude code |
   |---|---|---|
   | Harness 配置 | 未配置 | ANTHROPIC_* env 驱动 |
   | Category 路由 | ✅ 生效（category→model） | 无此概念 |
   | 子 agent 覆盖 | ⚠️ model: sonnet 不可解析 → 挂起 | model: inherit → 继承主 agent |

## 现象

- **现象 B（env var 缺失）命中**：L3 API 直连依赖 ANTHROPIC_* env（env-var-first），
  opencode 运行时无这些 env → `_l3_call_api` 无凭证、`fk_resolve_model` 返回空 → L3 在 API 调用前降级 return 3。
- **根因 #2 补充确认**：子 agent 模型绑定走 Category 路由层（正常）或子 agent 覆盖层（qa-expert 的
  `model: sonnet` 无 provider → 挂起）。模型由**子 agent 覆盖层决定**（当声明存在且可解析时），
  声明不可解析则任务挂起至超时。
- opencode 的认证走 `auth.json`（provider 配置），不是 env var——与 claude code 的
  `ANTHROPIC_AUTH_TOKEN` env-var-first 直连模式**架构性不兼容**。

## 结论（环节④）

1. **根因 #3（opencode 侧）**：L3 API 直连（l3-api.sh）是 claude code 架构（env-var-first 直连
   anthropic.com）；opencode 用 provider 认证（auth.json），不注入 ANTHROPIC_* env →
   L3 必降级 return 3。→ 修复方向：opencode 平台检测 + provider 认证适配（v2 范围，触 l3 链禁动）。
2. **根因 #2（实证升级）**：模型绑定三层中「子 agent 覆盖层」的 `model: sonnet` 不可解析是
   qa-expert 挂起的直接原因；「Category 路由层」正常（quick→deepseek-v4-flash 4s）。
   → D5 候选②（qa-expert model: sonnet → inherit）可消除该覆盖层失败。
3. `fk_resolve_model` 三级链在 opencode 下返回空 → L2 派发走 write_model_missing_correction 降级
   （l2-detect.sh return 3），L3 走 return 3——两级都降级，与「拉不起来」现象链一致。
4. ADR-020 三层模型选择结论（Harness/Category/子 agent 覆盖）实测成立：模型由
   **Category 路由层或子 agent 覆盖层**决定，取决于 task() 是否传 subagent_type。
