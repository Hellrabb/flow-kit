# DESIGN: L2/L3 模型审查双平台兼容性彻底修复

- **Change ID**: l2l3-cross-platform
- **关联**: `@.specs/l2l3-cross-platform/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@.specs/adr/023-dual-platform-l3-credential.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> CONTEXT.md 已锁技术决策（Bash 纯 Shell + jq + curl + bats-core），按 2-design 步骤 0 例外直接锁定，跳过卡片。

- **选定**：既有技术栈锁定（延续，非新选）
- **语言/运行时**: Bash（`set -euo pipefail`）+ jq + curl
- **测试**: bats-core 1.13.0（npx bats · 双源 `test/` + `flow-kit-bundle/test/`）
- **构建/部署**: 纯 Shell 打包（package-flow-kit.sh Part A~H）+ install.sh（user/project 双模式）
- **理由**：本 change 是既有 hook/prompt 体系的平台适配层扩展，零新依赖；AC-8 要求双源测试与打包校验沿用既有基础设施
- **明确排除**：无新语言/框架引入（不引入 Node/Python 侧脚本——hook 链路必须保持纯 Bash 可离线运行）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 出来的实际清单）：
- flow-kit-bundle/hooks/stop/lib/l3-api.sh（既有 · 凭证解析点 · L20-21 base_url/auth_token · L69 Path1 · L84-97 Path2）
- flow-kit-bundle/hooks/stop/lib/common.sh（既有 · fk_resolve_model L239-264 · 新增 fk_platform_is_opencode 落点）
- flow-kit-bundle/hooks/stop/lib/l2-detect.sh（既有 · L70-76 agent_type 映射 · L98 派发模板 · L170-184 平台感知提示 · L175-177/229/253-271 l2_dispatch_agent 凭证段改调共享函数 + L170-174 陈旧注释同步更新）
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（既有 · L212 general-purpose 派发点）
- flow-kit-bundle/hooks/stop/lib/transcript-parser.sh（既有 · L99 general-purpose 派发点）
- flow-kit-bundle/hooks/session-start/flow-kit-resume.sh（既有 · resume banner L124-143 降级提示段——AC-3 提示载体）
- flow-kit-bundle/hooks/stop/30-ai-analyze.sh（既有 · L94-97 同族凭证链——**登记不改**，见 §6 不在范围）
- flow-kit-bundle/flow-kit/prompts/{1-requirement.md:85, 2-design.md:239, 3-task.md:194, 5-test.md:52, 6-review.md:105+302, 7-integration.md:55}（既有 · subagent_type 派发锚点）
- flow-kit-bundle/lib/install_hooks.sh（既有 · PLATFORM/resolve_paths/install_file 平台基础设施 L15/L77/L91/L100 · 新增 .opencode/agent 安装段）
- package-flow-kit.sh（仓库根 · 禁动清单登记例外后改 Part A 覆盖范围）

新增模块：
- flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md（opencode 专用盲审 agent 定义）
- test/test_l3_credential_resolution.bats（新测试）
- test/test_l2_dispatch_mode.bats（新测试）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker（gate 核心链）
- correction-file.sh 4 函数签名 / checkpoint-lib.sh 绕过 / HOOK_MODULE_NAMES 数组
- .specs/<id>/.goal-snapshot.json / check-gate-sync.sh / PRESET_MAP 预设名
- flow-kit-bundle.tar.gz / .gitignore / ~/.claude/tools/brooks-lint/node_modules/ / ~/.local/bin/{depcheck,jscpd,knip,ts-prune}
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| L3 API 调用 | `l3-api.sh::_l3_call_api()` | 沿用（改凭证解析段，禁绕过直接 curl——CONTEXT 禁动） |
| L3 模型解析 | `common.sh::fk_resolve_model()` 三级链 | 沿用（零改动） |
| env-var-first 配置范式 | `FLOW_KIT_L3_MAX_TOKENS/TIMEOUT/THINKING`（l3-api.sh L29+） | 沿用（FLOW_KIT_L3_BASE_URL/AUTH_TOKEN 同族扩展） |
| L2 检测/派发指引 | `l2-detect.sh`（L2 检测唯一入口） | 沿用（改派发模板 + 平台分支统一） |
| 平台检测 | l2-detect.sh:180 内联 `OPENCODE_BIN` 判定 | 提取为 `fk_platform_is_opencode()` 公共函数（双信号），两处统一 |
| 平台感知提示 | l2-detect.sh:181/184 `_hint` 双分支 | 沿用模式，扩展到 L3 降级提示（l3-review.sh/29/resume） |
| opencode 路径安装 | install_hooks.sh L15/L100（`~/.config/opencode/hooks` / `$project/.opencode/hooks` + PLATFORM/resolve_paths/install_file） | 沿用（agent 安装段放 install_hooks.sh，与 hooks 安装同源——R7 盲审） |
| 打包覆盖 | package-flow-kit.sh Part A（rsync flow-kit/） | 沿用（.opencode/agent 放 flow-kit/ 下自动覆盖，需禁动例外） |

### 0.5.3 沿用模式 vs 引入新模式

```
- 凭证解析：**沿用** env-var-first 模式，扩展为三 Path 优先级链（不引入配置文件/密钥库——凭证仍只在 env，符合 .flow-active 不入库前提）
- 平台检测：**引入新模式**（fk_platform_is_opencode 公共函数）→ 理由：平台差异化逻辑将出现在 ≥4 处（l2-detect/l3-api/29/resume/prompts），单点封装防锚点漂移；既有 l2-detect 内联判定升级为此函数
- 派发指引：**沿用** l2-detect.sh 生成模板模式，扩展双模式输出
- agent 定义：**引入新模式**（.opencode/agent/ 目录）→ 理由：opencode 无 CC 式 subagent 映射，平台需要自己的 agent 定义载体；文件为新增不触碰既有结构
- 安装：**沿用** install_hooks 的 user/project 双模式 + 冲突检测询问
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | L3 凭证三 Path 优先级链，**抽为共享函数 `common.sh::fk_resolve_api_credentials()`**（L2/L3 共用，命名不表示层归属；设置 `FK_API_BASE_URL`/`FK_API_AUTH_TOKEN` 全局输出，rc 语义：0=凭证就绪 / 1=无任何凭证 / 2=Path3 配置不完整）：**平台感知优先级（F-B 修订）**——CC 平台 **Path1** `ANTHROPIC_AUTH_TOKEN`+`ANTHROPIC_BASE_URL` > **Path3** `FLOW_KIT_L3_AUTH_TOKEN`+`FLOW_KIT_L3_BASE_URL` > **Path2** `ANTHROPIC_API_KEY`（legacy 兜底，硬编码 api.anthropic.com）；opencode 平台 **Path3 > Path1 > Path2**（残留 ANTHROPIC_AUTH_TOKEN 不压制 FLOW_KIT_L3_*）；Path1 或 Path3 任一命中**短路 Path2**；**Path3 命中语义**：AUTH_TOKEN 非空 **且** BASE_URL 非空；token 非空但 BASE_URL 空 → rc=2 + stderr 明确报「FLOW_KIT_L3_AUTH_TOKEN 已设但 FLOW_KIT_L3_BASE_URL 为空」，**禁止静默落 Path2**。`_l3_call_api`（l3-api.sh）与 `l2_dispatch_agent`（l2-detect.sh L175-177/L229/L253-271，R1 漏改修复）**两处同源调用**，短路语义一致 | 按平台检测只走单路径（opencode 只看 FLOW_KIT、CC 只看 ANTHROPIC）/ 只在 l3-api.sh 改（R1 漏改路径）/ 固定 Path1>Path3 不分平台 | CC 零回归（R5 盲审要求向后兼容）；单路径方案在双平台 env 并存时行为不可预测；固定顺序在 opencode 下残留 CC env 会压制 FLOW_KIT_L3_*（F-B spot-check 防护缺口）；短路 Path2 防残留 CC env 打错端点；共享函数消灭 l2-detect 独立链（L-031 全仓锚点） | 两平台双优先级顺序 + 平台翻转测试矩阵复杂度；common.sh 新增公共函数需双源测试覆盖 |
| D2 | 平台检测提取为 `fk_platform_is_opencode()`（common.sh）：`OPENCODE_BIN` 或 `OPENCODE` 任一非空即真；l2-detect.sh:180 既有分支统一改调 | 仅用 OPENCODE_BIN（既有锚点）/ 仅用 OPENCODE=1（当前实测）/ `command -v opencode` | 双信号覆盖两种注入场景（既有代码锚点 + 当前环境实测）；command -v 会误判（装了 CLI 但不在 opencode 运行时，l2-detect 注释已否决）；单点封装防 5 处锚点漂移（R3） | 需同步改 l2-detect.sh 既有分支（小 diff）；双信号任一误报时平台判定偏差（可接受，两信号语义等价） |
| D3 | 降级提示载体边界：stderr/stdout/resume banner 可含 env 完整名（export 指引必需）；correction message 只写 `FLOW_KIT_L3_* 未配置`；落盘文件一律不含 env 名或 token 值 | correction message 也写全名（可读性好） | R1 盲审🔴：AC-3 与 AC-6 安全红线的矛盾消解；凭证不落盘是隐私红线（CONTEXT 术语·FLOW_KIT_L3_* 绝不落盘） | correction 提示信息量略少（用户仍可从 stderr/banner 拿到完整指引） |
| D4 | L2 派发平台感知双模式：**L-031 锚点全覆盖**——6 prompt 调度段（1:85/2:239/3:194/5:52/6:105+302/7:55）+ l3-review.sh:212 + transcript-parser.sh:99 + l2-detect.sh:98 模板，opencode → `task(category=...)`（如 unspecified-high），CC → 保持 `subagent_type`。**transcript-parser 工具名双平台兼容（R2 修订）**：jq 过滤同时匹配 CC 形状（`.type=="tool_use" and .tool=="Agent"`）与 opencode 形状（`.type=="tool" and .tool=="task"`，实测 part 记录），opencode 下按 `state.input.category` 归类（AC-4 mock 形状；具体 jq 嵌套路径以 bats 实测 transcript jsonl 为准——R-4 盲审修订）、CC 下按 `args.subagent_type` 归类，均落 `"general-purpose"` 兜底 | 只改 l2-detect.sh 生成模板 / 保持单一 Agent 过滤不扩形状 | R2 盲审🟡：opencode 实际记录 `"tool":"task"`，单一过滤下整个统计块 0 匹配（实测 opencode.db part 表 271 条 task 记录全不命中）；L-031 教训要求全仓枚举 | 6 prompt + 2 sh 多文件改动；jq 过滤双形状 + 归类双字段复杂度；后续新 prompt 需保持双模式（结构断言测试兜底） |
| D5 | opencode 专用盲审 agent 定义 `.opencode/agent/flow-kit-l2-reviewer.md`（prompt 引用 L2-blind-review）+ 头部附 5 种派发名映射说明 | 5 个独立 agent 文件（qa-expert/architect-reviewer/code-reviewer/oracle/general-purpose 各一） | 本 change 主路径是 category 路由（D4），agent 文件作增强（用户想用 subagent_type 时有可用目标）；5 文件重复度高且 5 名字无别名机制，映射说明成本更低 | subagent_type 在部分 opencode 环境仍可能挂起（平台行为，out 范围），该文件在这些环境不生效 |
| D6 | 安装/打包：agent 文件放 `flow-kit-bundle/flow-kit/.opencode/agent/`（Part A rsync 自动覆盖，rsync -a 含 dotfile 已验证 package-flow-kit.sh:40）+ **安装落点明确为 `install_hooks.sh`**（复用既有 PLATFORM/resolve_paths/install_file 平台基础设施——L15/L77/L91/L100 实测；user → `~/.config/opencode/agent/`；project → `$project/.opencode/agent/`，冲突检测询问，仿 pre-commit 检测模式）；package-flow-kit.sh 改动登记禁动例外 | 独立 Part 打包段 / install_core.sh 新增安装点 | Part A 覆盖核心引擎是最小侵入；安装复用 install_hooks 既有平台分支（DRY，R7 盲审）；install_core.sh 无平台分支（实测） | install_hooks.sh 加一段；需设计 agent 文件冲突检测（与用户既有 agent 同名时询问不覆盖） |

---

## 2. 数据流 / 架构图

```
【L3 凭证解析链】fk_resolve_api_credentials()（D1 · 平台感知——F-B 修订：优先级表随 fk_platform_is_opencode() 翻转）

  fk_platform_is_opencode()
      │
      ├─ 假（claude code）→ 顺序: Path1 > Path3 > Path2（零回归）
      │
      │     ├─ Path1: ${ANTHROPIC_AUTH_TOKEN:-} 非空？
      │     │        ├─ 是 → base_url=${ANTHROPIC_BASE_URL:-https://api.anthropic.com}
      │     │        │        → FK_API_AUTH_SCHEME=bearer → 直连（CC 主路径）
      │     │        └─ 否 ↓
      │     ├─ Path3: ${FLOW_KIT_L3_AUTH_TOKEN:-} 且 ${FLOW_KIT_L3_BASE_URL:-} 均非空？
      │     │        ├─ 是 → 短路 Path2 → FK_API_AUTH_SCHEME=bearer（opencode 主路径 · 但 CC 下次优）
      │     │        │  token 非空但 base_url 空 → rc=2 + stderr 报错（禁止静默落 Path2）
      │     │        └─ 否 ↓
      │     └─ Path2: ${ANTHROPIC_API_KEY:-} 非空？ → FK_API_AUTH_SCHEME=x-api-key（legacy 兜底 · 硬编码端点 · 仅当 Path1/3 全空）
      │
      └─ 真（opencode）→ 顺序: Path3 > Path1 > Path2（残留 ANTHROPIC_AUTH_TOKEN 不得压制 FLOW_KIT_L3_*）
            │
            ├─ Path3: ${FLOW_KIT_L3_AUTH_TOKEN:-} 且 ${FLOW_KIT_L3_BASE_URL:-} 均非空？
            │        ├─ 是 → 短路 Path2 → FK_API_AUTH_SCHEME=bearer（opencode 主路径 · 第一优先）
            │        │  token 非空但 base_url 空 → rc=2 + stderr 报错（禁止静默落 Path2）
            │        └─ 否 ↓
            ├─ Path1: ${ANTHROPIC_AUTH_TOKEN:-} 非空？
            │        ├─ 是 → base_url=${ANTHROPIC_BASE_URL:-https://api.anthropic.com}
            │        │        → FK_API_AUTH_SCHEME=bearer（CC 残留回退）
            │        └─ 否 ↓
            └─ Path2: ${ANTHROPIC_API_KEY:-} 非空？ → FK_API_AUTH_SCHEME=x-api-key（legacy 兜底 · 仅当 Path3/1 全空）

  → 两平台 rc 语义一致: 0=就绪（FK_API_* 全局就绪）/ 1=无凭证 / 2=Path3 配置不完整
  → rc=1 → 调用方降级: 平台感知提示（D3）；rc=2 → stderr 报错，不落 Path2
  → 详细确定性状态机见 § 3（两平台分支图 + F-B 翻转语义说明）

【平台感知派发】fk_platform_is_opencode()（D2）

  fk_platform_is_opencode() = [ -n "${OPENCODE_BIN:-}" ] || [ -n "${OPENCODE:-}" ]
      │
      ├─ 真（opencode）→ L2 派发提示: task(category=unspecified-high)  ← 6 prompt + l2-detect + l3-review + transcript-parser（D4）
      │                    → L3 降级提示: export FLOW_KIT_L3_BASE_URL/AUTH_TOKEN 指引（启动环境，hook 子进程继承）
      └─ 假（claude code）→ L2 派发: subagent_type: <qa-expert|architect-reviewer|code-reviewer|oracle>（回归不变）
                            → L3 降级提示: 确认 ANTHROPIC_AUTH_TOKEN 已注入（env-var-first）

【agent 定义安装/打包】D5 + D6

  flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md
      │  Part A rsync（禁动例外登记）
      ▼
  package-flow-kit.sh staging → flow-kit-bundle.tar.gz
      │  install_hooks.sh 新增安装段（复用 PLATFORM/resolve_paths——R11 修正）
      ▼
  user 模式: ~/.config/opencode/agent/flow-kit-l2-reviewer.md（冲突检测询问）
  project 模式: $project/.opencode/agent/flow-kit-l2-reviewer.md（冲突检测询问）

【边界】不触碰：gate 核心链（independent-review-gate.sh / 29 / fk_validate_done_marker）、
correction-file.sh 签名、HOOK_MODULE_NAMES、gate_config schema、.done 协议。
```

---

## 3. 关键状态机（如有）

L3 凭证解析优先级（D1 的确定性顺序，**平台感知**——F-B 修订后：优先级表随 `fk_platform_is_opencode()` 翻转；纯 env 判定，测试矩阵驱动；rc 语义由 `fk_resolve_api_credentials()` 统一定义）：

```
平台判定 → claude code（fk_platform_is_opencode 假）:
Path1(ANTHROPIC_AUTH_TOKEN) → 命中即用（base_url=ANTHROPIC_BASE_URL 或默认 api.anthropic.com），rc=0
   │ 空
   ▼
Path3(FLOW_KIT_L3_AUTH_TOKEN 且 FLOW_KIT_L3_BASE_URL) → 命中即用（短路 Path2），rc=0
   │ token 非空但 BASE_URL 空 → rc=2 + stderr 明确报错（禁止静默落 Path2）
   │ 全空
   ▼
Path2(ANTHROPIC_API_KEY) → 命中即用（legacy 硬编码端点），rc=0
   │ 空
   ▼
rc=1（无任何凭证）→ 降级（下同）

平台判定 → opencode（fk_platform_is_opencode 真）:
Path3(FLOW_KIT_L3_AUTH_TOKEN 且 FLOW_KIT_L3_BASE_URL) → 命中即用（短路 Path2），rc=0
   │ token 非空但 BASE_URL 空 → rc=2 + stderr 明确报错（禁止静默落 Path2）
   │ 全空
   ▼
Path1(ANTHROPIC_AUTH_TOKEN) → 命中即用（CC 残留回退，base_url=ANTHROPIC_BASE_URL 或默认 api.anthropic.com），rc=0
   │ 空
   ▼
Path2(ANTHROPIC_API_KEY) → 命中即用（legacy 硬编码端点），rc=0
   │ 空
   ▼
rc=1（无任何凭证）→ 调用方走降级: l3_review_run return 3 / l2_dispatch_agent 输出提示 + 平台感知提示（D3）。**注意**：rc=1 是凭证缺失，**不写 model-missing correction**（该 correction 仅模型解析空时触发，既有逻辑不变——R12 语义澄清）
```

> **F-B 平台翻转语义**：opencode 下残留 `ANTHROPIC_AUTH_TOKEN`（如 .bashrc 遗留）**不得压制**用户显式配置的 `FLOW_KIT_L3_*`——Path3 在 opencode 下优先。CC 平台顺序不变（零回归）。两平台差异仅 Path1/Path3 相对顺序，短路规则（Path1 或 Path3 任一命中即短路 Path2）与 rc=2 完整性检查两平台一致。

平台判定（D2）：`OPENCODE_BIN | OPENCODE` 任一非空 → opencode；否则 claude code。两信号等价，无优先级。

---

## 4. ADR 索引

- `@.specs/adr/023-dual-platform-l3-credential.md` — 双平台 L3 凭证解析链 + 平台感知派发（新 ADR：确立 FLOW_KIT_L3_* 凭证族为一等配置路径，延续 l2-l3-subagent-fix 的 env-var-first 决策族；可逆性低——一旦发布，用户环境按此配置，推翻需双平台迁移）

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | 三 Path 平台感知优先级实现缺陷：平台翻转写反 / Path2 短路条件漏写 / 共享函数只改 l3-api 漏 l2-detect（R1 盲审漏改 class 复发） | 残留 CC env 打错端点 401；opencode 下 FLOW_KIT_L3_* 被压制；CC 回归破坏；L2 自动派发静默死亡 | 中 | bats 优先级矩阵**两平台 × 三 Path 全组合**（CC: Path1>Path3>Path2 / opencode: Path3>Path1>Path2 + 平台翻转用例 + Path3 配置不完整 rc=2 用例）+ **`test_l2_dispatch_mode.bats` 断言 l2_dispatch_agent 走共享函数** + AC-6 红线 bats 断言 + test_independent_review_model 回归 |
| R2 | 平台检测信号漂移：oh-my-opencode 未来版本改变 env 注入行为（OPENCODE=1 不再注入） | 平台判定失效 → 提示/派发回到错误分支 | 低-中 | fk_platform_is_opencode 单点封装（改一处）；提示文案标注依赖版本；CONTEXT 假设记录（未来版本变化时检测提示需同步更新） |
| R3 | L-031 锚点漂移：未来新增 prompt 漏写双模式分支 | opencode 下新阶段 L2 派发静默挂起 | 中 | AC-4 结构断言 bats（subagent_type 命中文件必须含 category= 或平台标记）；CONTEXT 禁动/索引登记 |
| R4 | 凭证泄露：export 指引误写 token 值 / 日志输出 env | 隐私红线破坏 | 低 | AC-6 落盘 grep（4 env 名 + =sk- + base64 模式）；credential source 日志只记 `env\|flow-kit` 不记值；review 检查 |
| R5 | 安装冲突：目标环境已有同名 agent 文件被覆盖 | 用户自定义 agent 丢失 | 低 | 冲突检测询问（仿 pre-commit 检测模式），不静默覆盖 |

> 覆盖实现风险（R1/R3）、上线/兼容风险（R2/R5）、长期债务（R3 锚点漂移）。

---

## 6. 不在范围

- auth.json provider 凭证**存在性**探测自动化（v2：仅提示"哪个 provider 可用"，不读 token 内容）
- `/flow model` 显示凭证配置状态（v2）
- 跨机器配置迁移文档（v2：.flow-active 不入库，模型名/凭证如何随项目迁移）
- opencode 下 L3 API 与 deepseek 等 provider 的 thinking 参数矩阵实测调优（v2）
- 读取/解析/缓存 auth.json token 内容（out：隐私红线）
- 修改 opencode / oh-my-opencode 平台层修复 subagent_type 挂起（out：平台行为，只做分发侧规避）
- opencode.json `provider` 段自动发现（out：实测为空 `{}`，无稳定数据源）
- gate 核心链校验顺序 / .done 协议 / gate_config schema 改动（out）
- **`30-ai-analyze.sh` 凭证链不改**（Stop hook 30 号模块 AI 分析 API 调用，L94-97 同族 ANTHROPIC-only 链；不在 L2/L3 审查范围，opencode 下维持现状，**v2 候选**——R5 盲审登记）
- **L2 自动 API 派发在 opencode 下的可用性**（`l2_dispatch_agent` 经共享函数拿到凭证后可调用兼容端点；若 FLOW_KIT_L3_BASE_URL 指向的端点不支持 L2 派发 API，opencode 下仍走 category 路由手动派发——凭证问题解决，API 兼容性不在本 change 范围）

---

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象（建议 append 到 CONTEXT「既有抽象索引」段）

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `common.sh::fk_platform_is_opencode()` | 双平台检测（OPENCODE_BIN \| OPENCODE）单点封装 | 任何未来平台差异化逻辑（提示/派发/凭证） | 平台相关分支一律先调此函数，禁止内联 `[[ -n $OPENCODE ]]` 判定 |

### 9.2 新增 / 改变的项目级技术决策（建议 append 到 CONTEXT「已锁技术决策」段）

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| L3 凭证配置路径 | claude code 用 `ANTHROPIC_*`（Path1 优先）；opencode 用 `FLOW_KIT_L3_BASE_URL`/`FLOW_KIT_L3_AUTH_TOKEN`（**Path3 优先，压制残留 ANTHROPIC_***——F-B 修订）；`ANTHROPIC_API_KEY`（Path2）仅 legacy 兜底且被 Path1/3 任一命中短路 | 所有 L3 API 调用方（l3-api/29/PreToolUse） | 高——用户环境按此配置，双平台迁移 |

### 9.3 新增 / 修改的跨模块契约（建议 append 到 CONTEXT「跨模块契约」段）

```
- 凭证解析优先级契约（`common.sh::fk_resolve_api_credentials` 单一实现，L2/L3 共用）：**平台感知**——CC：Path1 ANTHROPIC_AUTH_TOKEN > Path3 FLOW_KIT_L3_* > Path2 ANTHROPIC_API_KEY（仅当 1/3 空）；opencode：Path3 > Path1 > Path2（F-B 修订）；Path1 或 Path3 任一命中短路 Path2；Path3 命中 = token 且 base_url 均非空，否则 rc=2 报错；l3-api.sh::_l3_call_api 与 l2-detect.sh::l2_dispatch_agent 两处同源调用
- 平台感知派发契约（prompts 独立 review 调度段 + l2-detect 模板）：opencode → task(category=...)；CC → subagent_type: <agent>；两分支必须共存（结构断言）
- transcript-parser 工具名兼容契约（R2 修订）：过滤同时匹配 CC 形状（tool_use+Agent）与 opencode 形状（tool+task）；opencode 按 state.input.category 归类、CC 按 args.subagent_type 归类，兜底 general-purpose（R-4 盲审：具体 jq 嵌套路径以 bats 实测为准）
- 降级提示载体契约：stderr/stdout/banner 可含 env 名；correction message 只写 `FLOW_KIT_L3_* 未配置`；运行时落盘文件（.flow-active* / correction / hook 日志 / INDEPENDENT-REVIEW-*.md / 测试输出）不含 env 名/token 值；**豁免** .specs/<id>/ 规格源文档（DESIGN/REQUIREMENT/CHANGE/ADR——描述性文档必须点名 env，AC-6 扫描范围据此豁免）
- 新增安装点：.opencode/agent/flow-kit-l2-reviewer.md（user → ~/.config/opencode/agent/；project → $project/.opencode/agent/；install_hooks.sh 实现）
- 已知例外：30-ai-analyze.sh 为 ANTHROPIC-only 凭证调用方（不在本 change 范围，v2 候选）
```

### 9.4 新增 / 升级的依赖

| 包 | 版本 | 用途 | 是否替换既有 |
|---|---|---|---|
| 无新依赖（纯 Bash + 既有 jq/curl/bats） | — | — | 否 |

### 9.5 禁动清单变化（建议 patch CONTEXT「禁动清单」段）

```
- 新增禁动：l3-api.sh 凭证解析段 — 禁止绕过 _l3_call_api 直接调 curl（延续既有禁动，明确凭证 Path 判定在内）
- 新增禁动：.opencode/agent/flow-kit-l2-reviewer.md — 修改需同步 prompts 派发映射（L-031 锚点之一）
- 新增禁动：prompts 独立 review 调度段 — 修改需保持双模式共存（结构断言测试兜底）
- 解禁例外登记：package-flow-kit.sh Part A 覆盖范围（本 change 一次性 · 仿 superpowers-v6-absorb 先例 · 仅新增 .opencode/agent 覆盖点）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
