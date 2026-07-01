# DESIGN: 独立 Review Agent

- **Change ID**: independent-review
- **关联**: `@.specs/independent-review/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

- **选定**：纯 Bash + JQ（与 flow-kit 既有栈一致）
- **客户端**: Claude Code hooks（PreToolUse/Stop/SessionStart）+ Agent tool
- **外部模型**: deepseek-v4-flash（经 onecli proxy → api.anthropic.com/v1/messages，跨供应商独立审查）
- **关键依赖**: jq ≥ 1.6, bats-core 1.13.0（测试）, onecli（凭证管理, 可选）
- **理由**: 不引入新语言/框架，完全复用 flow-kit 既有栈；deepseek 用作独立审查员提供跨模型多样性
- **明确排除**: 不用 Python/Node.js 重写 hook（保持 Bash 堆栈一致性）；不做自定义 Claude Code subagent_type（P2）

---

## 0.5 既有架构对齐

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（修改）：
- flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh（加 gate 函数 + 改 fk_auto_phase）
- flow-kit-bundle/hooks/stop/lib/common.sh（加 write_failed_state）
- flow-kit-bundle/hooks/config/stop-hook.json（加 independent_review schema）
- flow-kit-bundle/hooks/session-start/flow-kit-resume.sh（加摘要注入）
- flow-kit-bundle/lib/install_hooks.sh（补 27/28/29 + PreToolUse 接线）
- flow-kit-bundle/skills/flow/SKILL.md（加 /flow gate-config）
- flow-kit-bundle/flow-kit/prompts/1-requirement.md, 2-design.md, 6-review.md（加独立 review 调度段）

新增模块：
- flow-kit-bundle/hooks/stop/29-independent-review.sh
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
- flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md

禁动清单（与本次无关，AI 不许碰）：
- package-flow-kit.sh（打包核心，改动影响分发）
- flow-kit-bundle.tar.gz（已生成分发件）
- .gitignore（手动维护）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| Hook 模块调度 | 00-gate.sh + lib/common.sh | 沿用（29 模块被 00-gate.sh 调用，与 30-ai-analyze.sh 同级） |
| Hook stdin 解析 | common.sh hook_init | 沿用（29 继承 PROJECT_ROOT 等环境变量） |
| 外部模型调用 | 30-ai-analyze.sh onecli proxy 范式 | 沿用（29 抄 30 的 onecli proxy + fallback） |
| 配置管理 | stop-hook.json config_get | 沿用（新增 independent_review 块） |
| Settings 接线 | install_hooks.sh jq 合并 | 沿用（PreToolUse 仿 Stop 接线） |
| 矫正注入 | weak-model-compliance .flow-active.correction | 沿用（.flow-active.independent-review 仿此模式） |
| Gate 机制 | fk_auto_phase / fk_artifact_check | 沿用（加 fk_independent_review_gate_active） |

### 0.5.3 沿用模式 vs 引入新模式

- Hook 模块：**沿用** 00-gate.sh 调度链 + Bash 模块范式（00/01/20-30/99）
- Settings 接线：**沿用** jq 合并模式（检查已有 → 追加 → 新建）
- 外部模型调用：**沿用** onecli proxy + fallback 模式（30 号模块范式）
- 独立 review gate：**引入新模式** → 三道防线（PreToolUse + fk_auto_phase + auto_advance=false），原因：这是 flow-kit 首次在 hook 层做硬拦截（之前 hook 是报告型，不做 deny）

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | L3 用 PreToolUse exit 2 deny 而非仅 Stop 报告 | 仅 Stop 报告（软约束） | Stop hook 是报告型（00-gate.sh:68 所有 exit 被 `|| true` 吞），不能阻断主 agent。PreToolUse 是唯一硬拦截路径 | 需新增 PreToolUse hook 接线（install_hooks 改动），且 PreToolUse 拦不住 hook 内部 fk_auto_phase 推进（需防线1 补充） |
| D2 | 三道防线（PreToolUse + fk_auto_phase + auto_advance=false）而非仅 PreToolUse | 仅 PreToolUse 单防线 | 阶段切换有三条路径——PreToolUse 只能拦主 agent Bash（路径A），拦不住 Stop hook 内部 fk_auto_phase（路径B）和 pipeline toll-gate（路径C） | 三道防线维护成本略高，但覆盖完整；gate 未开时零副作用 |
| D3 | L2 用固化 prompt 模板（非自定义 subagent_type） | 自定义 subagent_type 固化 system prompt | 自定义 subagent_type 需要 Claude Code agent 定义机制（未调研），且工作量大。P1 用 prompt 固化 + 事后检测 | 独立性根本上仍在 prompt 层（主 agent 理论上可掺自评），P2 补强 |
| D4 | 默认关闭（gate_config 显式开启）而非默认开启 | 所有 change 强制跑 | 独立 review 有 token 成本（L3 每次调 deepseek），用户应主动选择。默认开会让每个 change 都付成本 | 用户需知道此能力存在并主动开启（/flow gate-config 子命令降低门槛） |
| D5 | L3 不走频率门控（与 30-ai-analyze.sh 不同）| 继承 30 的 STOP_COUNT % frequency | 独立质量门不能被随机跳过；用幂等（本阶段 done 过就跳过）防重复 | 每次 Stop 都跑一次（但 done 后幂等跳过，实际只跑一次/阶段） |
| D6 | gate_config 双源（.flow-active.goal.gate_config 优先 + stop-hook.json phases 兜底）| 单源 | 非 pipeline 模式无 goal → gate_config 不存在，需 stop-hook.json 兜底。双源保证所有模式都能启用功能 | 配置分散两处，hook 读 jq 逻辑稍复杂 |

## 2. 数据流 / 架构图

```
用户: /flow gate-config 6-review=independent
  │  写入 .flow-active.goal.gate_config["6-review"] = "independent"
  │
  ├─ 主 agent 进 phase 6
  │     │
  │     ├─ L2: Agent tool 派盲审子 agent → INDEPENDENT-REVIEW-6.md (L2 段)
  │     │
  │     └─ 本轮结束 → Stop hook 触发
  │           │
  │           ├─ 29-independent-review.sh (L3)
  │           │     ├─ Gate1: module_enabled? → on
  │           │     ├─ Gate3: fk_independent_review_gate_active? → yes
  │           │     ├─ 拼工件 (REQUIREMENT/DESIGN/git diff)
  │           │     ├─ onecli proxy → deepseek-v4-flash
  │           │     ├─ 成功 → INDEPENDENT-REVIEW-6.md (L3 段) + .flow-active.independent-review{status:done}
  │           │     └─ 失败 → write_failed_state (fail_count++)
  │           │
  │           └─ SessionStart 注入（下轮）
  │                 └─ flow-kit-resume.sh 读 .independent-review → 打印摘要框
  │
  ├─ PreToolUse: independent-review-gate.sh
  │     拦截 git commit / gh pr / 改 phase jq → exit 2 deny
  │     done 标志存在 → exit 0 放行
  │
  └─ fk_auto_phase: gate 检查（防线1）
        gate 生效 → return 空（阻断 check_g1 推进）
        done 已写 → return 7（放行）
```

## 3. 关键状态机

done 标志生命周期：
```
不存在 ──(L2 done + L3 done)──> 主 agent 写 .independent-review-6.done
                                      │
                                      ├── PreToolUse 放行
                                      ├── fk_auto_phase 放行
                                      └── 29 Gate5: rm .flow-active.independent-review
```

## 4. ADR 索引

凡不可逆决策，单独写 ADR：
- 本次无不可逆决策（所有改动都在 flow-kit-bundle/ 内，可在后续 change 中调整）。D1-D6 均为可逆设计决策。

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | L2 独立性被主 agent prompt 污染（掺入自评） | L2 降级为橡皮图章 | 中 | L2-blind-review.md 顶部硬声明 + 子 agent 自检；Stop hook 事后扫 transcript Task 调用 prompt 关键词（违规标注）；P2 自定义 subagent_type |
| R2 | deepseek 审需求/设计质量不佳（擅长代码 diff） | 1/2 阶段 L3 报告无价值 | 中 | POC 阶段人工抽检；必要时加 phase_models 按阶段换模型（如 1/2 用 claude-haiku） |
| R3 | PreToolUse + fk_auto_phase + auto_advance 三道防线有遗漏路径 | 独立 review 可被绕过 | 低 | 已对已知三条推进路径做了防线覆盖（主 agent Bash/Stop 内部/pipeline）；单元测试覆盖了各路径；引入后监控 feedback |
| R4 | install_hooks 的 Stop 模块列表 stale（27/28 漏加） | 新装项目缺 27/28 | 低 | 本次顺手补全 27/28/29；bundle 源 + install 测试验证 |
| R5 | PreToolUse hook fail-open 策略过于宽松 | 某些错误状态被绕过 | 低 | 宁可漏拦不卡死——fail-open 是 hook 设计原则（lock-out > lock-in）；false positive 代价远大于 false negative |

## 6. 不在范围

- 自定义 subagent_type 的创建与注册（P2）
- L3 真实模型调通后的端到端验证（需目标环境 onecli→deepseek 路由通）
- 独立 review 结果自动触发回退逻辑（如 verdict=fail → 自动回 4-dev）—— 本次只拦不自动决策；回退仍由主 agent 在 toll-gate 做
- 对阶段 0/4/5/7 的独立 review 覆盖

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象（建议 append 到 CONTEXT 「既有抽象索引」段）

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| fk_independent_review_gate_active() | 独立 review gate 判定（双源 + done 标志检查） | 任何 stage 要加 gate 时 | 阶段 4/5/7 若要加独立 review，直接复用此函数 |
| write_failed_state() | L3 失败降级 + fail_count 递增 | 异步检查失败降级 | 任何 hook 模块要做失败降级 + 绕过阈值 |
| PreToolUse deny 模式 | Bash 工具调用硬拦截 | 任何硬门禁需求 | 需要硬拦截的场景（如禁止 git push 前未跑 test）可复用此模式 |

### 9.2 新增/改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 独立 review 架构 | L2（prompt 固化）+ L3（PreToolUse + Stop）双层 | flow-kit 所有项目 | 低——功能默认关闭，改动在 bundle 源，不影响现有 change |
| 三道防线 | PreToolUse + fk_auto_phase + auto_advance | 阶段切换机制 | 中——如果防线路由有问题，需调整 fk_auto_phase 逻辑 |
| user-scope hooks 统一 | hooks 只装 user scope（~/.claude/），项目级不接线 | flow-kit 安装策略 | 低——install.sh 仍支持两种模式，用户可选 |

### 9.5 禁动清单变化

- 新增禁动：fk_auto_phase() gate 检查段——修改时需理解三道防线覆盖的推进路径，不能简单删除 return 0
