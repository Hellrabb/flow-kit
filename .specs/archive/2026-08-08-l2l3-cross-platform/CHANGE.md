# CHANGE: L2/L3 模型审查双平台（claude code + opencode）兼容性彻底修复

- **Change ID**: l2l3-cross-platform
- **创建日期**: 2026-08-06
- **路径建议**: 完整（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

`l2-l3-subagent-fix`（2026-08-05 归档）解决了 L2/L3 子 agent 在 opencode 下的**挂起**问题（v1：category 路由 + 平台感知提示），但调查结论明确列出 v2 未实施项与残留风险：

1. **L3 在 opencode 下仍不会真正执行**（根因 #3 残留）：hook 子进程 env = `{...process.env}`，**不注入** `~/.claude/settings.json` 的 env 段（`ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_BASE_URL` 只有 claude code 注入）；opencode 进程自身不携带 `ANTHROPIC_*` → `fk_resolve_model` 三级链（实测 L2/L3 全空）→ `l3_review_run` 降级 return 3。结果是：**opencode 下 L3 审查永远拉不起**，只是"优雅降级"而非报错。
2. **L2 派发仍依赖主 agent 手动理解平台差异**：`l2-detect.sh` 已有平台感知提示（L172-184），但派发命令生成未真正双模式化，opencode 下 `subagent_type` 路由挂起（agent=undefined）的坑仍可能被新写的派发路径踩中。
3. **gate-config=all 需要真双层**：用户要求本 change 及后续 pipeline 用 `all`（全阶段 1/2/3/5/6/7）+ `both`（L2+L3 双层），当前 opencode 环境下 L3 必降级 → 双层审查形同虚设。

目标：**claude code 和 opencode 两个运行时下，L2 子 agent 与 L3 外部模型审查都能真实拉起并完成**，无平台特判死角。

## What（做什么）

在 flow-kit hook 层（`l2-detect.sh` / `l3-api.sh` / `l3-review.sh` / `common.sh::fk_resolve_model`）实施双平台适配：

1. **统一配置路径升级**：`FLOW_KIT_L3_MODEL` / `FLOW_KIT_L2_MODEL` 与 `/flow model` 持久化（`.flow-active.goal.l*_model`）从"降级兜底"升级为一等公民配置路径；新增 `FLOW_KIT_L3_BASE_URL` / `FLOW_KIT_L3_AUTH_TOKEN` env（凭证**不进** .flow-active，hook 子进程继承 opencode 启动 env 即可用）。
2. **平台检测**：hook 检测运行时（`OPENCODE=1` vs claude code），L3 凭证解析链平台感知——claude code 下 `ANTHROPIC_*` 优先（零破坏回归），opencode 下回退 `FLOW_KIT_L3_*`；两者皆缺 → 升级现有检测提示（指明 opencode 下应 export 到启动环境，而非 settings.json）。
3. **L2 平台感知双模式派发**：`l2-detect.sh` 派发指引双模式生成——opencode 下输出 `task(category=...)` 路由提示，claude code 下保持现有派发；分发包新增 opencode 专用 reviewer agent 定义，使 `subagent_type` 路由在 opencode 下也有可用目标。
4. **gate-config=all + both**：本 change 自身 pipeline 用 `all` 预设 + `both` 层级验证端到端。

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR（双平台模型凭证解析契约）
- [x] 影响现有 AC（`test_fk_resolve_model.bats` 三级链 AC 需扩展凭证链；`test_model_degradation.bats` 降级路径语义调整）
- [ ] 影响数据模型 / 迁移（凭证不入 .flow-active，无 schema 破坏；模型名复用既有 `l2_model`/`l3_model` 字段）
- [x] 影响外部 API 兼容性（l3-api.sh 凭证读取逻辑扩展，向后兼容：ANTHROPIC_* 优先顺序保持）
- [ ] 仅修复 bug，无范围变化（非——含新能力）

## 范围排除（这次不做）

- **不读 auth.json 的 token 内容**：隐私红线。hook 最多探测"凭证存在性"用于提示，不解析、不缓存、不输出 token。
- **不改 opencode / oh-my-opencode 平台层**：subagent_type 挂起是平台行为，flow-kit 只做分发侧规避（category 路由 + agent 定义），不修平台代码。
- **不做 opencode.json provider 段自动发现**：实测 provider 段为空（`{}`），无稳定数据源；凭证注入走 `FLOW_KIT_L3_*` env（用户 export 到 opencode 启动环境）。
- **不改 gate 核心链校验顺序 / .done 协议 / gate_config schema**：独立审查四层架构（PRESET_MAP / prompt / hook / checklist）保持现状，只动派发与凭证解析。
- **不重做 l2-l3-subagent-fix 已交付的 v1 内容**：category 路由提示、运行时 hooks 同步、ROOT-CAUSE 文档均已就绪，本次在其上扩展而非重写。

## 验收线（粗粒度，不是 AC）

1. claude code 环境全链路回归 0 破坏：`ANTHROPIC_*` 优先解析、L2/L3 审查照旧可跑（bats 双源全绿）。
2. opencode 环境配置 `FLOW_KIT_L3_MODEL` + `FLOW_KIT_L3_BASE_URL` + `FLOW_KIT_L3_AUTH_TOKEN` 后，L3 审查**真实调用 API 并产出报告**（不再降级为空）；L2 通过平台感知双模式派发拉起。
3. 本 change pipeline 以 gate-config=all + both 跑通全部阶段，每个阶段 L2+L3 双审有真实 .done 证据。

## 风险与未知

- **opencode 凭证注入依赖用户行为**：`FLOW_KIT_L3_*` 必须 export 到 opencode 启动环境（hook 子进程继承），无法完全自动化；检测提示只能降低踩坑率。
- **桥接版本漂移**：oh-my-opencode 4.19.4 的 hooks 桥接行为（env 继承、事件触发）可能随版本变化，gate 集成测试需覆盖双平台冒烟。

---

## 修订记录（2026-08-07 · Phase 6 盲审回退修订）

> 本 change 走完 Phase 0-6 后，Phase 6 双盲审（L2 + Cross-Model Spot-Check）发现 3 项需本次修订的问题，pipeline 回退到 Phase 1 修订后重走 2→3→4→5→6。

| # | 来源 | 问题 | 修订 |
|---|---|---|---|
| F-B | spot-check 🟡 | opencode 下残留 `ANTHROPIC_AUTH_TOKEN` 会压制 `FLOW_KIT_L3_*`（Path1 固定最高）| **AC-2/D1 改为平台感知优先级**：CC 下 Path1>Path3>Path2（零回归）；opencode 下 Path3>Path1>Path2（Path3 压制残留 ANTHROPIC_*） |
| R2 | L2 盲审 🟡 | transcript-parser 过滤 `.tool=="Agent"` 在 opencode 下整个统计块 0 匹配（实测 opencode 记录 `"tool":"task"`）| **新增 AC-4b**：jq 过滤双形状兼容（CC: tool_use+Agent / opencode: tool+task），opencode 按 `input.category` 归类；D4 同步 |
| F-A | spot-check 🟡 | AC-6 红线验证无 bats 断言（仅一次性 grep，无 CI 回归保护）| **AC-6 验证方式改为 bats 断言固化**（两条 grep 进 test_l3_credential_resolution.bats） |
| R1 | L2 盲审 🔴 | AC-8 双源全绿声明虚假（打包源 28 失败，TD-012 类路径 bug）| **已 T-FIX-01 修复**（2 测试文件路径改向上查找 + 双源同步 + 声明如实改写）——本次修订前已完成，修订重走时保留 |

**回退状态**：`.flow-active` phase=1（phases_done=[0,1]，gates 保留），REQUIREMENT/DESIGN 已修订，重走 2-design → 3-task（追加修订任务）→ 4-dev → 5-test → 6-review。
- **opencode 下 L3 API 模型兼容性未知**：deepseek provider 的 API 形状与 Anthropic Messages API 的差异（thinking 参数等）已有 `FLOW_KIT_L3_MAX_TOKENS` / `FLOW_KIT_L3_TIMEOUT` / `FLOW_KIT_L3_THINKING` 覆盖，但 opencode 平台凭证对应的 endpoint 行为需实测。
- **.flow-active 不入库**（运行时状态），`/flow model` 持久化的模型名跨机器迁移不随 repo 走——文档化即可，非本次范围。

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
