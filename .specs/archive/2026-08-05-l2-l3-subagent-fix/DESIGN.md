# DESIGN: L2/L3 子 agent 双平台拉起失败 — 根因调查与低风险修复

- **Change ID**: l2-l3-subagent-fix
- **关联**: `@.specs/l2-l3-subagent-fix/REQUIREMENT.md`、`@.specs/l2-l3-subagent-fix/CHANGE.md`、`@.specs/CONTEXT.md`、`@.specs/ARCHITECTURE.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0₋. 架构级变更预检

- 0-change 已判定：既有抽象上的兼容性修复 / bugfix，非架构级变更（不拆模块 / 不改数据模型 / 不换运行时）。
- ARCHITECTURE.md §3 ADR 列表核对：ADR-020（OpenCode task 能力快照）可能受根因影响——**若根因指向派发命令，更新 ADR-020 属 v2 范围**（REQUIREMENT.md 已声明），v1 不触碰。
- **结论**：未命中架构级 → 直接进步骤 0，无需 A-architect / supersede 声明。

## 0. 技术栈选定

- **选定**：现有 Bash 栈（CONTEXT.md 已锁技术决策 — 纯 Shell 脚本 + bats-core 1.13.0 + npx，无前端/后端/数据库）
- **前端**：无（非 Web 项目）
- **后端**：无
- **数据库**：无
- **部署**：无（分发包仓库，tar.gz 分发）
- **关键依赖**：bats-core（npx）· jq · curl · shellcheck（make lint）
- **理由**：本 change 是运行时兼容性调查 + 低风险修复，全程在既有 Bash 派发链内操作；引入任何新语言/工具都会违反「不触碰运行时链路」的范围约束
- **明确排除**：任何新运行时（Node/Python 包装）、新依赖注入框架 — 与既有 86 处 skill/prompt 路径引用冲突

---

## 0.5 既有架构对齐（brownfield）

### 0.5.1 本次 change 触碰的既有模块（grep 验证）

```
触碰模块（调查对象 · 四环节）：
- flow-kit-bundle/hooks/stop/lib/l2-detect.sh（环节① · l2_dispatch_agent() L128-303 / l2_dispatch_prompt() / l2_detect_missing() / fk_extract_l2_verdict()）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh + gate-helpers.sh + gate-helpers-types.sh（环节② · PreToolUse 触发链）
- flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh（环节② · L53-90 调 l2_dispatch_agent/l2_dispatch_prompt）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（环节②/③ · L161 l2_dispatch_prompt 兜底）
- flow-kit-bundle/flow-kit/prompts/{1-requirement,2-design,3-task,5-test,6-review,7-integration}.md（环节③ · 「独立 review 调度」段）
- flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md（环节③ · 固化盲审指令）
- flow-kit-bundle/hooks/stop/lib/common.sh::fk_resolve_model()（环节④ · L239-270 三级优先级链）
- flow-kit-bundle/hooks/stop/lib/l3-api.sh（环节④ · L20-21 ANTHROPIC_BASE_URL/AUTH_TOKEN 直连）
- flow-kit-bundle/hooks/stop/lib/l3-review.sh + l3-prompt.sh + l3-done.sh（环节④ · L3 编排）
- 运行时 agent 定义（调查对象 · 双平台对照）：~/.config/opencode/agents/{qa-expert,architect-reviewer,code-reviewer}.md（opencode 侧 · model 字段声明）+ ~/.claude/agents/{qa-expert,architect-reviewer,code-reviewer}.md（claude code 侧 · 纯读操作，不触碰禁动清单）。本机已实测两平台 qa-expert 定义分歧：opencode `model: sonnet` vs claude code `model: inherit`——差异矩阵的天然对比锚点，调查必须做逐 agent 双平台 diff（R2 修复）

新增产物（非代码）：
- .specs/l2-l3-subagent-fix/ROOT-CAUSE.md（五段根因报告 · T06 合成）
- .specs/l2-l3-subagent-fix/DEV-SUMMARY.md（实测记录 · T07/T08）
- .specs/l2-l3-subagent-fix/EVIDENCE-1-opencode-dispatch.md（opencode 环节①派发实测 · T01）
- .specs/l2-l3-subagent-fix/EVIDENCE-2-opencode-gate.md（opencode 环节②gate 触发实测 · T02）
- .specs/l2-l3-subagent-fix/EVIDENCE-3-opencode-prompt.md（opencode 环节③prompt 派发实测 · T03）
- .specs/l2-l3-subagent-fix/EVIDENCE-4-opencode-env-model.md（opencode 环节④env 透传+模型绑定层实测 · T04）
- .specs/l2-l3-subagent-fix/EVIDENCE-5-claude-code.md（claude code 四环节+agent diff 实测 · T05）

禁动清单（与本次无关 / v1 不实施 · AI 不许"顺手"碰）：
- gate 校验核心链：independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker（v1 仅读不写，除非根因直指且经用户确认 → 入 v2）
- l3-review.sh 封装（L3 API 直连必须走 l3_review_run()，禁止绕过 curl）
- checkpoint-lib.sh（checkpoint 必须走 checkpoint_write()）
- PRESET_MAP 预设名（禁止改名）
- .flow-active.goal 字段（必须通过 /flow 子命令操作）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 模型名解析 | `common.sh::fk_resolve_model()`（三级链：ANTHROPIC_* env > FLOW_KIT_* env > .flow-active.goal.l*_model） | 沿用（调查对象，不重复实现） |
| L2 派发命令生成 | `l2-detect.sh::l2_dispatch_prompt()` / `l2_dispatch_agent()` | 沿用（调查对象） |
| L3 API 调用 | `l3-api.sh::_l3_call_api()`（env-var-first） | 沿用（调查对象） |
| 子 agent 盲审指令 | `L2-blind-review.md` 固化指令 | 沿用 |
| L2/L3 状态检测 | `l2-detect.sh::l2_detect_missing()` | 沿用 |
| 根因报告模板 | 无 | 新建（本 change 首个调查型交付物，五段结构见 REQUIREMENT AC-1） |
| 审查模型配置持久化 | `.flow-active.goal.l2_model/l3_model`（/flow model 子命令） | 沿用（若根因指向模型解析缺失，此为 low 风险修复入口） |

### 0.5.3 沿用模式 vs 引入新模式

```
- 派发链路：**沿用** 既有四环节（l2-detect → gate → prompt → env 透传），不重构派发架构
- 根因证据：**引入** 双平台实测矩阵模式（opencode 本机实测 + claude code CLI 2.1.71 实测 + 差异对照）→ 理由：既有仓库无跨运行时调查先例，这是调查型 change 的首次形态，验收需要双平台对照证据
- 修复实施：**沿用** 既有小步修复协议（risk 分级 → 用户确认 → 实施 → 实测验证），不引入新变更流程
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **调查方法论：四环节分层实测**（① l2-detect.sh 派发生成 ② PreToolUse gate 触发 ③ prompt 派发段 ④ env var 透传 + L3 API 直连），每环节独立给出 opencode 实测 + claude code 实测 + 差异结论。**opencode 子 agent 模型绑定层验证**（ADR-020 已锁知识）：确认本环境 harness/category 对 qa-expert / architect-reviewer / code-reviewer 的模型绑定——task() 路由实际落到的模型 ID，ROOT-CAUSE.md 差异矩阵显式回答"子 agent 模型由哪一层决定"（R1 修复） | 整体黑盒复现（只在运行时层跑一遍看报错） | 根因可能横跨 hook 层与运行时层（CHANGE.md 风险 #2），分层才能定位"哪一环断了"；黑盒复现只能确认"拉不起来"现象，无法定位环节；且 ADR-020 已实测记录模型选择发生在三层（Harness 配置层 / Category 路由层 / 子 agent 覆盖层），不验证绑定层会复现失败但归因错误层 → D5 候选 ② 无效修复 | 调查工作量增大（每环节要构造双平台实测）；但这是 REQUIREMENT AC-1 硬要求 |
| D2 | **证据脱敏规范**：ROOT-CAUSE.md 中的 env var 只显示变量名 + set/unset 状态，值一律 `***`；命令输出中的 token/路径做同样处理 | 原文粘贴实测输出 | 调查对象恰是 `ANTHROPIC_*`/`FLOW_KIT_*` 透传链，实测输出必含凭证值（R2 修复）；仓库 push 到公开 GitHub，凭证入库不可逆（security-privacy-audit 六大维度） | 证据可读性略降（无法直接看到实际值）；补救：原始脱敏前输出留存本机日志（不入库） |
| D3 | **mock 边界**：AC-4 验收的"实测拉起"必须走真实运行时派发（真实 task tool / hook 路径 + 真实 env 透传），仅 L2 审查内容本身可 mock；真实派发不可行时在 DEV-SUMMARY.md 记录原因 | mock 全链路（FLOW_KIT_L2_MOCK=1 风格） | mock 绕过真实派发对"修复 opencode 拉不起来"零证明力（R3 修复 + l2-l3-test-defect BUG-G 假绿教训） | 验收门槛变高：若真实派发在本环境确实不可行，只能记录原因并依赖 claude code 侧验证 |
| D4 | **修复范围 gate**：v1 仅实施 risk:low 修复（用户确认清单后），high 修复（触及 gate 核心链 / 禁动清单）一律 v2 | v1 实施所有候选修复 | CHANGE.md 范围排除 #1/#3 + CONTEXT 禁动清单；调查先行，修复基于报告确认，不基于猜测改禁动模块 | v1 可能"只出报告不修复"（若所有候选都 high），change 价值缩水；缓解：D5 预先规划 low 候选 |
| D5 | **low 风险候选预研**（供报告确认时快速圈定，非承诺实施）：① 若根因 = L2/L3 模型解析缺失 → `/flow model` 配置 + `fk_resolve_model` 链已有机制，修复 = 配置层（零代码）；② 若根因 = qa-expert agent 声明 `model: sonnet` 在 opencode 不可解析 → 改为 `inherit`（用户 scope 配置，非仓库代码）。**首个验证动作 = 双平台 agent 定义 diff**（R2 修复）：逐 agent 对比 `~/.config/opencode/agents/<name>.md` vs `~/.claude/agents/<name>.md` 的 `model:` 字段（已实测 qa-expert: sonnet vs inherit 分歧）+ task() 路由实测落到模型 ID；diff 一致才可实施修复；③ 若根因 = l2_dispatch_agent 凭证缺失路径（ANTHROPIC_* 空 → return 3）→ 增加运行时探测提示或降级文档 | 不预研，报告出来再说 | 用户确认环节需要"报告 + 候选清单"一起呈现（CHANGE.md 验收线 #2 要求修复基于报告确认）；预研让确认有据可依 | 预研投入可能白费（若实测推翻候选）；但预研本身是调查的一部分（实测即证据） |
| D6 | **验证策略**：AC-4 以"真实 opencode 派发 + 回写 INDEPENDENT-REVIEW-N.md"为证（本仓库即 opencode 运行时，本次 phase 1 已实测拉起 L2 = 基线证据）；AC-5 基线比对 = `npx bats test/ 2>&1 | grep -c '^not ok'` 输出 0（基线 662/662 来源 STATE.md，当前实测 710 @test） | 仅看 git diff | 修复有效性的唯一证据是"修复后能拉起"；基线数字必须有出处（R4 修复） | 需要在 DEV-SUMMARY.md 保留完整实测记录（派发命令 + 回写文件 + bats 输出），证据链较长 |

---

## 2. 数据流 / 架构图

```
┌───────────────────────── 四环节调查链（D1） ─────────────────────────┐
│                                                                       │
│  ① 派发命令生成          ② PreToolUse 触发           ③ prompt 派发段      │
│  l2-detect.sh ──────►  independent-review-gate.sh ──► prompts/*.md      │
│  l2_dispatch_prompt    gate-checks-basic.sh          「独立 review 调度」 │
│  l2_dispatch_agent     (L53-90 调 l2_dispatch_*)      subagent_type:     │
│       │                          │                   qa-expert(1,5)      │
│       ▼                          ▼                   architect-reviewer  │
│  ④ env var 透传链 ◄──────────────┤                   (2,3,7)             │
│  fk_resolve_model (common.sh)    │                   code-reviewer(6)    │
│  L2: ANTHROPIC_L2_MODEL > FLOW_  │                                        │
│      KIT_L2_MODEL > .goal.l2_model│                                        │
│  L3: ANTHROPIC_DEFAULT_HAIKU_    │                                        │
│      MODEL > FLOW_KIT_L3_MODEL > │                                        │
│      .goal.l3_model              │                                        │
│       │                          │                                        │
│       ▼                          ▼                                        │
│  L3 API 直连（l3-api.sh）  子 agent 运行时（opencode task tool /          │
│  ANTHROPIC_BASE_URL +     claude code Task tool）                         │
│  ANTHROPIC_AUTH_TOKEN     model 解析：agent 定义 model 字段               │
└───────────────────────────────────────────────────────────────────────────┘
         │
         ▼
  ROOT-CAUSE.md（五段）──► 用户确认 low 修复清单 ──► 修复实施 ──► AC-4/5 验证
```

**双平台差异焦点**：
- opencode：task tool 参数 / agent 定义在 `~/.config/opencode/agents/*.md`（`model:` 字段），session 默认 `deepseek/deepseek-v4-flash`，无 anthropic provider。**模型绑定层**（ADR-020 已锁）：模型选择发生在三层——Harness 配置层（按 agent type 绑定 model）/ Category 路由层（category→模型 tier）/ 子 agent 覆盖层，task() 参数仅 `subagent_type` + `category` 两个路由维度 → 调查必须实测"qa-expert 派发实际落到的模型 ID"，不能只看 agent 定义文件（R1 修复）
- claude code：CLI 2.1.71 本机可用（`claude --version` 已确认），`subagent_type` 原生支持；agent 定义在 `~/.claude/agents/*.md`（双平台对照见 §0.5.1，R2 修复）

## 3. 关键状态机（调查流程）

```
INVESTIGATE（四环节×双平台实测）
   │  每环节产出：opencode 实测结论 / claude code 实测结论 / 差异
   ▼
ROOT-CAUSE.md 五段完成（AC-1/2/3 验证）
   │
   ▼
用户确认 low 风险修复清单（AC-4 Given）
   ├─ 清单非空 → 实施修复 → opencode 实测拉起 L2（AC-4）→ bats 基线比对（AC-5）
   └─ 清单为空 → 交付物 = ROOT-CAUSE.md（R7 分支声明）
```

## 4. ADR 索引

- v1 无新增 ADR。ADR-020（OpenCode task 能力快照）更新属 v2（REQUIREMENT.md 已声明）；若根因实测需要记录"opencode agent model 解析"持久结论，随报告附建议、由用户决定是否升 ADR。

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | claude code 侧本机不可复现（CHANGE.md 风险 #1） | AC-2 双平台证据缺一半，差异矩阵不完整 | 中 | 报告中显式标注"claude code 侧未复现 + 原因"（AC-2 已内置逃生口）；验证以可复现环境为准 |
| R2 | 实测证据含凭证值入库（R2 修复对象） | 公开仓库泄露 token，不可逆 | 中 | D2 脱敏规范（值一律 `***`）；原始输出留本机日志 |
| R3 | 验收假绿：mock 绕过真实派发（R3 修复对象） | 修复无效却宣告成功，问题复发 | 低（有 BUG-G 前车之鉴） | D3 mock 边界 + DEV-SUMMARY.md 实测记录留痕 |
| R4 | 调查发现根因全部落在禁动清单内（gate 核心链 / l3-review.sh） | v1 只能出报告，无修复交付 | 中 | D5 预研 low 候选（配置层 / 用户 scope agent 定义）；high 项明确归 v2 并按报告建议 |
| R5 | 修复 opencode 侧破坏 claude code 侧（兼容性 NFR） | 双平台机制断裂扩大 | 低 | 每项修复双平台回归（claude CLI 可实测则实测）；不可实测的平台标注验证缺口 |
| R6 | 根因错层归因（R1 修复对象）：opencode 子 agent 模型绑定层（harness/category 层）未纳入调查 → 复现成功但归因到错误环节，D5 候选 ② 无效修复 | 调查报告结论错误，修复方案打偏，v2 白投入 | 中（ADR-020 已实测三层模型选择，盲审确认存在盲点） | D1 四环节 + 绑定层验证子步骤；ROOT-CAUSE.md 差异矩阵显式回答"子 agent 模型由哪一层决定"；每环节结论附"哪一层验证"标注 |

## 6. 不在范围

- high 风险修复（gate 核心链 / 禁动清单条目）→ v2
- ADR-020 更新 / 双平台 e2e 自动化验收 → v2
- opencode task-level model-tier 支持（ADR-020 实测不支持）→ out
- 统一两平台 agent 架构 → out
- 大规模派发链重构 → v2+（若根因指向架构层面，单独开 change）

---

## 9. 架构沉淀建议

> 本 change 为调查型，v1 主要沉淀**调查方法论**与**双平台差异事实**（若根因成立，下述候选均有项目级复用价值）。

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `.specs/<id>/ROOT-CAUSE.md` 五段结构 | 调查型 change 的标准交付物模板（现象矩阵/根因链/差异矩阵/修复方案/影响模块） | 未来任何"系统性定位问题根因"的 change | 沉淀为 `templates/ROOT-CAUSE.md` 模板（若本 change 验证结构有效） |
| 双平台实测矩阵 | opencode/claude code 逐环节实测对照的记录范式 | 任何跨运行时兼容性 change | 写入 CONTEXT.md 术语表（已在 REQUIREMENT 阶段沉淀 4 术语） |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 双平台模型解析入口 | 统一走 `fk_resolve_model()` 三级链 + `.flow-active.goal.l*_model`（既有 ADR-012） | L2/L3 全部审查模型配置 | 低（已有 fallback） |
| opencode agent model 声明规范 | agent 定义 `model:` 字段须用本环境可解析值（`inherit` / 实际模型 ID），禁止 `sonnet` 等不可解析别名 | 所有 opencode 子 agent 派发 | 低（改用户 scope 配置） |

### 9.3 新增 / 修改的跨模块契约

```
- 无新增 API / Schema / 事件。若修复涉及 l2_dispatch_agent 的凭证探测逻辑，需保持既有函数签名（l2_dispatch_agent <phase> <change_id> [specs_dir]）
```

### 9.4 新增 / 升级的依赖

| 包 | 版本 | 用途 | 是否替换既有 |
|---|---|---|---|
| 无 | — | — | — |

### 9.5 禁动清单变化

```
- v1 无禁动清单变化（不触碰 gate 核心链 / l3-review.sh）
- 建议（随报告，非本次实施）：若根因确认为 agent model 声明，考虑将"运行时 agent 定义 model 字段"登记为禁动检查项（v2 讨论）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
