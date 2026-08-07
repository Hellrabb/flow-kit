# ADR-023: 双平台 L3 凭证解析链 + 平台感知派发

- **日期**: 2026-08-06
- **Change**: l2l3-cross-platform
- **状态**: 提议（本 change 实施后生效）

## Context

L3 独立审查的 API 凭证在 claude code 与 opencode 两个运行时下的传递链路不同：

- claude code 通过 `settings.json` 的 `env` 段注入 `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`，hook 子进程可见。
- opencode（oh-my-opencode 4.19.4 桥接）的 hook 子进程继承 `{...process.env}`（opencode 进程 env），**不注入 settings.json 的 env 段**，且 opencode 认证走 `auth.json`（不 export ANTHROPIC_*）。实测当前 opencode 会话 env 无任何 `ANTHROPIC_*` / `FLOW_KIT_*` 变量。

后果（l2-l3-subagent-fix ROOT-CAUSE 根因 #3 残留）：`_l3_call_api` 的 env-var-first 解析在 opencode 下三级链全空 → `fk_resolve_model` 返回空 → L3 永远优雅降级，双层审查在 opencode 下单腿。同时 `ANTHROPIC_API_KEY`（Path 2 legacy，硬编码 api.anthropic.com）存在与 FLOW_KIT 凭证并存的优先级未定义问题——残留 CC env 会把请求打错端点。

L2 子 agent 派发同样双平台异构：opencode 的 `task` 工具 `subagent_type` 路由不绑定 CC 式 agent 定义（实测挂起 agent=undefined），`category=` 路由可用（Sisyphus-Junior 4s 成功）；claude code 的 `subagent_type` 派发正常。9 文件 10 处派发锚点（6 prompt + l2-detect + l3-review + transcript-parser）全是 CC 单模式。

## Decision

1. **L3 凭证三 Path 平台感知优先级链**（`common.sh::fk_resolve_api_credentials` 共享函数，L2/L3 共用；F-B 修订后优先级随平台翻转）：
   - **claude code 平台**：**Path 1** `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_BASE_URL`（主路径，最高，行为零回归）→ **Path 3** `FLOW_KIT_L3_AUTH_TOKEN` + `FLOW_KIT_L3_BASE_URL`（次高）→ **Path 2** `ANTHROPIC_API_KEY`（legacy 兜底，硬编码 `api.anthropic.com`，仅当 Path 1/3 全空）
   - **opencode 平台**：**Path 3** `FLOW_KIT_L3_AUTH_TOKEN` + `FLOW_KIT_L3_BASE_URL`（主路径，最高——**残留 `ANTHROPIC_AUTH_TOKEN` 不得压制**，F-B 修复）→ **Path 1** `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_BASE_URL`（CC 残留回退，次高）→ **Path 2** `ANTHROPIC_API_KEY`（legacy 兜底）
   - **公共规则**：Path 1 或 Path 3 任一命中即**短路 Path 2**（防残留 CC env 打错端点）；Path 3 命中 = token 且 base_url 均非空，否则 rc=2 报错禁落 Path 2
2. **平台检测单点封装**：`common.sh::fk_platform_is_opencode()`——`OPENCODE_BIN` 或 `OPENCODE` 任一非空即真。所有平台差异化分支（l2-detect 提示、L3 降级提示、派发模式）统一调用，禁止内联判定。
3. **降级提示载体边界**：stderr/stdout/resume banner 可含 env 完整名（export 指引必需）；correction message 只写 `FLOW_KIT_L3_* 未配置`；**token 值红线（`sk-`/base64 长串）任何落盘文件零容忍**；env 完整名（`FLOW_KIT_L3_AUTH_TOKEN` 等）**不进运行时状态文件**（.flow-active / correction / agent 定义）——但 **R10 豁免：审查报告（INDEPENDENT-REVIEW-*.md）与规格文档（.specs/）可含 env 名**（审查需引用 env 名描述问题），AC-6 据此拆两条 grep 断言。
4. **L2 派发平台感知双模式**：6 prompt 独立 review 调度段 + l2-detect.sh 模板 + l3-review.sh:212 + transcript-parser.sh:99——opencode 生成 `task(category=...)` 路由提示；claude code 保持 `subagent_type` 模板。两分支必须共存（bats 结构断言）。
5. **opencode 专用盲审 agent 定义**：`.opencode/agent/flow-kit-l2-reviewer.md`（prompt 引用 L2-blind-review），头部附 5 种派发名映射说明；安装到 `~/.config/opencode/agent/`（user）或 `$project/.opencode/agent/`（project），冲突检测询问。
6. 凭证**绝不落盘**：不进 `.flow-active` / correction / 日志 / 报告，仅存在于 hook 子进程 env 与 curl header。

## Consequences

正面：
- claude code 用户零回归（Path 1 优先，行为与现状一致）。
- opencode 用户获得一等配置路径（export FLOW_KIT_L3_*），L3 可在 opencode 下真实拉起。
- 平台判定/派发/提示单点化，未来双平台差异逻辑有统一落点。
- 安全红线明确：token 值任何落盘文件零容忍；env 名在运行时状态文件（.flow-active/correction/agent）零容忍，审查报告/规格文档豁免（R10），AC-6 拆两条 grep 可机器验证。

负面/约束：
- 三 Path 平台感知优先级判定增加 common.sh 共享函数复杂度，需 bats 优先级矩阵覆盖**两平台 × 三 Path 全组合**（CC: Path1>Path3>Path2 / opencode: Path3>Path1>Path2 + 平台翻转 + rc=2）。
- 用户须在 opencode **启动环境** export 凭证（hook 子进程继承启动 env，会话内无法补充）——这是桥接行为约束，未来 oh-my-opencode 版本若改变 env 注入，需同步更新检测提示（CONTEXT 假设已记录）。
- 依赖 opencode 平台 `category=` 路由可用性（实测成立）；平台层 subagent_type 挂起属 out 范围，仅分发侧规避。
- `.opencode/agent` 安装点为新增基础设施，需维护双模式（user/project）。

## 相关

- 延续：l2-l3-subagent-fix（FLOW_KIT_L3_* env 族 · env-var-first 范式）、l2-l3-granular-gate（gate_config 三值）
- 不冲突：ADR-019（写作原则）、ADR-020（opencode task 能力快照）、ADR-021（弱模型降级协议）
- 禁动清单新增：l3-api.sh 凭证段、.opencode/agent/flow-kit-l2-reviewer.md、prompts 独立 review 调度段双模式
