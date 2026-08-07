# REQUIREMENT: L2/L3 模型审查双平台兼容性彻底修复

- **Change ID**: l2l3-cross-platform
- **关联**: `@.specs/l2l3-cross-platform/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想在 opencode 和 claude code 两个运行时下都能配置 L2/L3 审查模型并真实拉起，以便独立审查机制不因运行时差异而静默失效。
- **US-2**：作为 flow-kit 维护者，我想让 L3 凭证解析链平台感知（claude code 用 `ANTHROPIC_*`、opencode 用 `FLOW_KIT_L3_*`），以便同一套 hook 代码在两个运行时行为一致且向后兼容。
- **US-3**：作为 gate-config=all 用户，我想全阶段开启 L2+L3 双层审查且不因凭证缺失降级为空，以便双层审查真正闭环。

## 验收准则（AC）

### AC-1 · L3 凭证三源解析（共享函数 fk_resolve_api_credentials）

- **Given** 环境设置 `FLOW_KIT_L3_BASE_URL` 与 `FLOW_KIT_L3_AUTH_TOKEN`（均非空），且未设置 `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY`
- **When** 调用共享凭证解析函数 `common.sh::fk_resolve_api_credentials()`（设置 `FK_API_BASE_URL`/`FK_API_AUTH_TOKEN` 全局输出，rc 语义 0=就绪 / 1=无凭证 / 2=Path3 配置不完整）
- **Then** rc=0，`FK_API_BASE_URL` 取 `FLOW_KIT_L3_BASE_URL` 值、`FK_API_AUTH_TOKEN` 取 `FLOW_KIT_L3_AUTH_TOKEN` 值；`l3-api.sh::_l3_call_api` 与 `l2-detect.sh::l2_dispatch_agent` **两处同源调用**该函数（L-031 R1 修复）
- **验证方式**: bats 测试 `test_l3_credential_resolution.bats`（新增，含 l2_dispatch_agent 同源调用断言）+ `grep` 确认 l3-api.sh 与 l2-detect.sh 凭证段均调用 `fk_resolve_api_credentials` 且无残留独立 `ANTHROPIC_AUTH_TOKEN` 直读

### AC-2 · 凭证优先级表（平台感知 + Path2 短路 + Path3 完整性）

- **Given** 多个凭证源并存，且平台已判定（`fk_platform_is_opencode()`）
- **When** 执行凭证解析
- **Then** 优先级表**随平台翻转**（F-B 盲审修订 · 平台感知优先级）：
  - **claude code 平台**：**Path 1** `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_BASE_URL`（主路径，最高）→ **Path 3** `FLOW_KIT_L3_AUTH_TOKEN` + `FLOW_KIT_L3_BASE_URL`（次高）→ **Path 2** `ANTHROPIC_API_KEY`（legacy 兜底，硬编码 api.anthropic.com，仅当 Path 1/3 全空）
  - **opencode 平台**：**Path 3** `FLOW_KIT_L3_AUTH_TOKEN` + `FLOW_KIT_L3_BASE_URL`（主路径，最高）→ **Path 1** `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_BASE_URL`（CC 残留回退，次高）→ **Path 2** `ANTHROPIC_API_KEY`（legacy 兜底，仅当 Path 1/3 全空）——残留 `ANTHROPIC_AUTH_TOKEN` **不得压制** `FLOW_KIT_L3_*`（F-B 修复）
  - **公共规则**：Path 1 或 Path 3 任一命中即**短路 Path 2**（残留 CC env 不得打错端点）；**Path 3 命中 = token 且 base_url 均非空**——token 非空但 base_url 空 → rc=2 + stderr 明确报错，**禁止静默落 Path 2**；两平台行为差异仅 Path1/Path3 的相对顺序
- **验证方式**: bats 测试（同 AC-1 文件，优先级矩阵用例覆盖 **两平台 × 三 Path 全组合** + Path3 配置不完整 rc=2 用例 + opencode 下 Path3 压制 Path1 用例）

### AC-3 · 平台感知检测提示（统一信号 + 载体界定）

- **Given** 平台检测函数 `fk_platform_is_opencode()`（common.sh 新增，`OPENCODE_BIN` 与 `OPENCODE` 任一非空即真）返回真，且 L3 凭证全空
- **When** 触发 L3 降级路径（`l3_review_run` 返回 3）
- **Then** 提示文本（hook stderr/stdout + resume banner 载体）明确包含"在 opencode 启动环境 export `FLOW_KIT_L3_BASE_URL` + `FLOW_KIT_L3_AUTH_TOKEN`（hook 子进程继承启动 env，settings.json 的 env 段不注入）"指引；claude code 环境保持"确认 ANTHROPIC_AUTH_TOKEN 已注入（env-var-first）"提示。**载体边界**：提示文本可含 env 变量名（export 指引需要）；correction message 字段只写 `FLOW_KIT_L3_* 未配置`，不写完整 env 名
- **验证方式**: bats 测试（mock 平台信号 + 空设置，断言 stderr 含 export 指引、correction 不含 env 名）+ 手动 `bash l2-detect.sh` 冒烟

### AC-4 · L2 派发平台感知双模式（L-031 锚点全覆盖）

- **Given** `fk_platform_is_opencode()` 返回真（opencode 环境）
- **When** 运行 `l2-detect.sh` 的派发指引生成段
- **Then** 生成的 Agent 派发提示使用 `task(category=...)` 路由（如 `unspecified-high`），而非 `subagent_type`；claude code 环境保持现有 `subagent_type` 派发模板（回归不变）。**L-031 锚点清单（本 change 范围枚举）**：`1-requirement.md:85`（qa-expert）· `2-design.md:239`（architect-reviewer）· `3-task.md:194`（architect-reviewer）· `5-test.md:52`（qa-expert）· `6-review.md:105`（code-reviewer）+ `:302`（oracle）· `7-integration.md:55`（architect-reviewer）· `l3-review.sh:212`（general-purpose）· `transcript-parser.sh:99`（general-purpose）· `l2-detect.sh:98`（`${agent_type}` 模板）——6 个 prompt 的独立 review 调度段与 2 个 sh 派发点全部改为平台感知双模式（opencode → category 路由），l2-detect.sh 模板同步
- **验证方式**: bats 测试 `test_l2_dispatch_mode.bats`（新增，mock 两平台环境断言两种输出）+ 结构断言：6 个 prompt 文件中 `subagent_type` 命中的每个文件必须同时含 `category=` 或平台判定标记（双模式共存，非裸子串残留判定——R9 修复）+ **transcript-parser 工具名兼容用例**（R2 修复：mock opencode 真实形状 `{"type":"tool","tool":"task","state":{"input":{"category":...}}}` 与 CC 形状 `{"type":"tool_use","tool":"Agent",...}` 各一，断言 `subagent-usage.txt` 统计正确归类——opencode 形状下按 category 归类、CC 形状按 subagent_type 归类）

### AC-4b · transcript-parser 工具名双平台兼容（R2 盲审修复 · 新增）

- **Given** opencode 平台（实测其 transcript part 记录为 `"type":"tool"` + `"tool":"task"`，非 CC 的 `"type":"tool_use"` + `"tool":"Agent"`）
- **When** Stop hook 运行 transcript-parser.sh 统计子 agent 使用情况
- **Then** 过滤条件同时匹配两种真实形状：`(.type == "tool_use" and .tool == "Agent")`（CC）或 `(.type == "tool" and .tool == "task")`（opencode）；opencode 形状下按 `state.input.category` 归类（AC-4 mock 实测形状）、CC 形状下按 `args.subagent_type` 归类，均落回 `"general-purpose"` 兜底
- **验证方式**: bats 用例（`test_l2_dispatch_mode.bats` 或独立文件，mock 两种 JSONL 形状断言 jq 输出）+ 全量回归

### AC-5 · opencode 专用 reviewer agent 定义

- **Given** flow-kit 分发包
- **When** 打包 / 安装后检查 `.opencode/agent/flow-kit-l2-reviewer.md`
- **Then** 该文件存在（含 name / description / prompt 引用 L2-blind-review 指令）；同文件头部附 5 种派发名映射说明（qa-expert / architect-reviewer / code-reviewer / oracle / general-purpose → opencode 下走 category 路由或本 agent），供用户环境选择
- **验证方式**: `test -f flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md`（**Part A 覆盖点，与 D6 安装源同路径**——R2 盲审路径统一）+ `install.sh` dry-run 覆盖该文件安装（install_hooks.sh 安装段）+ `package-flow-kit.sh --validate` 确认打包覆盖

### AC-6 · 凭证不进运行时落盘文件（安全红线 · 扫描范围豁免规格文档）

- **Given** 完成 AC-1 的配置流程
- **When** 检查**运行时产物**：`.flow-active`、`.flow-active.correction`、`.flow-active.interactive-ui-fix`、hook 日志、`INDEPENDENT-REVIEW-*.md`、测试输出、本 change 新增的落盘文件（agent 定义、bats 夹具）
- **Then** 不含 `FLOW_KIT_L3_AUTH_TOKEN` / `FLOW_KIT_L3_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY` 完整 env 名，也不含 token 值模式（`=sk-` 前缀串 / base64 长串 `[A-Za-z0-9+/]{32,}={0,2}`）；提示文本可含 env 名（AC-3 载体边界），运行时落盘文件一律不含。**豁免两类描述性文档**：`.specs/<id>/` 下规格源文档（REQUIREMENT/DESIGN/CHANGE/ADR）与 `INDEPENDENT-REVIEW-*.md`（审查报告——可执行发现必须点名 env 变量，R10 盲审）——它们仍须遵守 token 值模式（`=sk-`/base64）
- **验证方式**: **bats 断言固化（F-A 修订 · R-F-A1 修复：用 `-z "$output"` 判输出空而非 exit code，绕开 grep 缺文件 exit=2 陷阱）**——拆两条 bats 用例进 `test_l3_credential_resolution.bats`（新增 `_test_ac6_redline_no_token_values` + `_test_ac6_redline_no_env_names`）：① **token 值模式**扫运行时状态文件 + agent 定义（**不含 INDEPENDENT-REVIEW-*.md——R-F-A2 修复：审查文件由第三方 L2/L3 写入，不可约束其不写长字符串，钉进断言会假红**）：`run grep -rsE "=sk-[A-Za-z0-9]{8,}|[A-Za-z0-9+/]{32,}={0,2}" .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null; [ -z "$output" ]`（无输出=零命中=通过，无论 exit 1 或 2）；② **env 名模式**扫同范围非审查者产物：`run grep -rsE "FLOW_KIT_L3_AUTH_TOKEN|FLOW_KIT_L3_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY" .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null; [ -z "$output" ]`——`[ -z "$output" ]` 断言无输出（零命中语义），容忍缺文件（`2>/dev/null` + 输出空判定）；**INDEPENDENT-REVIEW-*.md 的 token 值红线保留在手动 grep 复核 + T12 verify 一次性验证**（不进 bats，因第三方写入不可控）；范围仅运行时状态文件 + agent 定义

### AC-7 · 降级路径回归（全空 → 优雅降级）

- **Given** L2/L3 模型与凭证全空
- **When** 调用 `fk_resolve_model` / `l3_review_run`
- **Then** 返回空字符串 / return 3，写 `l3-model-missing` correction，不崩溃、不挂起（与 l2-l3-subagent-fix 交付行为一致）
- **验证方式**: 回归锚点 = 三文件合集 25 用例全绿：`test_model_degradation.bats`（3 用例）+ `test_fk_resolve_model.bats`（10 用例）+ `test_independent_review_model.bats`（12 用例）

### AC-8 · 双源测试全绿 + 打包完整性（禁动例外登记）

- **Given** 本次所有代码改动完成
- **When** 运行 `npx bats test/`（开发源）与 `npx bats flow-kit-bundle/test/`（打包源）且 `make check`
- **Then** 全部通过（含既有 3 个文件合集 25 个 L2/L3 相关用例无回归），打包脚本 `package-flow-kit.sh --validate` 通过（新 agent 定义文件在 Part A~F 覆盖范围内）
- **验证方式**: `npx bats test/ && make check`；**打包源全量验证以二进制 bats 逐文件或目录模式实跑为准**（npx 包装在本环境会卡 registry 网络检查——AC-8 修订 · R1 盲审修复：声明必须附实跑证据，禁止采信未实跑的数字）；**禁动例外**：本次需改 `package-flow-kit.sh` 打包清单段（新增 `.opencode/agent/` 覆盖点），在 DESIGN 阶段按 superpowers-v6-absorb 先例登记例外到 CONTEXT.md 禁动清单（指明可改的 Part 段），未登记不得动手

### AC-9 · gate-config=all + both 端到端（本 change pipeline 自身）

- **Given** `.flow-active.goal.gate_config` 全部阶段为 `both`
- **When** 本 change 走完 0→7 各阶段
- **Then**（拆硬/软条件）：
  - **AC-9a（硬）**：每个开启阶段（1/2/3/5/6/7）的 `INDEPENDENT-REVIEW-N.md` 同时含 `## L2 盲审` 段与 `## L3` 段（grep 可确定性检查），`.independent-review-N.done` 存在且 6 键齐全（phase/change_id/written_by/L2_verdict/L3_verdict/artifacts），transition gate 全部 passed
  - **AC-9b（软）**：`.done` 的 `written_by` 为审查子系统（l3_review_run / L2 子 agent）而非 main-agent 伪造（人工审计确认）
- **验证方式**: 本 pipeline 实际执行产物 + `.flow-active` gates 检查（9a 自动；9b 人工）

---

## 范围切分

### v1（本次必做）

- `FLOW_KIT_L3_BASE_URL` / `FLOW_KIT_L3_AUTH_TOKEN` env 支持（l3-api.sh 凭证解析链扩展，**平台感知优先级**：CC 下 Path1 ANTHROPIC_* > Path3 FLOW_KIT_L3_* > Path2 ANTHROPIC_API_KEY；opencode 下 Path3 > Path1 > Path2 + 短路——F-B 修订）
- 平台检测函数 `fk_platform_is_opencode()`（common.sh 新增，`OPENCODE_BIN` + `OPENCODE` 双信号）+ L3 降级提示按平台差异化 + l2-detect.sh:175 既有 OPENCODE_BIN 分支统一改调此函数
- `l2-detect.sh` 派发指引双模式生成（opencode → category= 路由）
- **L-031 锚点全覆盖**：6 个 prompt（1-requirement:85 / 2-design:239 / 3-task:194 / 5-test:52 / 6-review:105+302 / 7-integration:55）独立 review 调度段 + `l3-review.sh:212` + `transcript-parser.sh:99` 派发点全部平台感知双模式
- **transcript-parser 工具名双平台兼容（R2 修订）**：过滤条件同时匹配 CC 形状（`tool_use`+`Agent`）与 opencode 形状（`tool`+`task`），opencode 下按 `state.input.category` 归类（AC-4 mock 实测形状）
- 分发包新增 opencode reviewer agent 定义（`.opencode/agent/flow-kit-l2-reviewer.md`）+ install.sh 安装覆盖 + package-flow-kit.sh 打包覆盖（**禁动例外登记**）
- 新增 bats 测试（凭证解析优先级 / 派发模式 / 平台提示 / **AC-6 红线两条 bats 断言——F-A 修订**）+ 双源同步
- 本 change pipeline 以 gate-config=all + both 跑通（AC-9）

### v2（下一轮考虑，不本次）

- auth.json provider 凭证**存在性**探测自动化（仅用于提示"哪个 provider 可用"，不读取 token 内容）
- `/flow model` 显示凭证配置状态（已配置 / 缺失 + 平台指引）
- 跨机器配置迁移文档（.flow-active 不入库，模型名/凭证配置如何随项目迁移）
- opencode 下 L3 API 与 deepseek 等 provider 的 thinking 参数矩阵实测调优

### out（永远不做）

- 读取 / 解析 / 缓存 auth.json 的 token 内容（隐私红线）
- 修改 opencode / oh-my-opencode 平台层代码修复 subagent_type 挂起（平台行为，flow-kit 只做分发侧规避）
- opencode.json `provider` 段自动发现（实测为空 `{}`，无稳定数据源）
- gate 核心链校验顺序 / .done 协议 / gate_config schema 改动（独立审查四层架构保持现状）

---

## 非功能性需求

- **性能**: 凭证解析纯 env/变量读取（无额外 API 调用、无文件锁）；平台检测为单次 `fk_platform_is_opencode` 判定（env 双变量测试）；对 Stop/PreToolUse hook 链路零新增延迟
- **可访问性**: 无（CLI 脚本项目）
- **安全**: token 不落盘（.flow-active / correction / 日志 / 报告均不含）、不 echo 输出、不写入 INDEPENDENT-REVIEW 报告；`AUTH_TOKEN` 仅出现在 curl header 赋值（延续既有 l3-api.sh 约定）；落盘文件不含 env 完整名（AC-6）
- **兼容性**: claude code（ANTHROPIC_* 路径）与 opencode（FLOW_KIT_L3_* 路径）双运行时；bash + jq + curl 既有依赖不变；bats 双源同步
- **可观测性**: 凭证缺失时降级提示按平台给出可执行指引（export 命令模板）；hook 日志记录解析源（`[l3-review] credential source: env|flow-kit`，不记 token 值）

## 依赖与假设

- **依赖**: `common.sh::fk_resolve_model`（既有三级链）、`l3-api.sh::_l3_call_api`（凭证解析点）、`l2-detect.sh`（派发指引生成）、`install.sh`（新文件安装覆盖）、`package-flow-kit.sh`（打包覆盖，需禁动例外）、既有 `FLOW_KIT_L3_MAX_TOKENS/TIMEOUT/THINKING` env 模式（复用其 env-var-first 范式）
- **假设**: opencode 环境通过 `fk_platform_is_opencode()` 可识别（`OPENCODE_BIN` / `OPENCODE` 任一非空，当前实测 `OPENCODE=1` 成立；`OPENCODE_BIN` 为 l2-detect.sh 既有可靠信号，两信号合并）；用户愿意在 opencode 启动环境 export 凭证 env（hook 子进程继承 `{...process.env}`，桥接不注入 settings.json env 段——oh-my-opencode 4.19.4 行为，未来版本变化时检测提示需同步更新）；`.flow-active` 保持不入库（凭证依赖此前提）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
