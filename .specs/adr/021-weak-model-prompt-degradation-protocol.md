# ADR-021: Weak Model Prompt Degradation Protocol

**Status**: Accepted (DESIGNED — implementation deferred to v2)
**Date**: 2026-08-03
**Supersedes**: 无
**Superseded by**: 无

## Context

L-063（来自已归档 `superpowers-v6-absorb`）标记了 DESIGN.md 中 D5/D6 弱模型降级场景**已描述但未实现**。

### 现有弱模型防护（v1 已就位）

flow-kit 当前通过三层防护确保弱模型（minimax-m2.7、qwen3.6-35b-a3b、deepseek-v4-pro 等）的行为鲁棒性：

| 层级 | 名称 | 机制 | 实施状态 |
|---|---|---|---|
| L1 | 规则硬护栏 | RULES.md / SYSTEM.md 禁动指令 | ✅ 已实施（`weak-model-robustness` change） |
| L2 | prompt 结构化强化 | 自检 gate（填空式模板）+ 交互式 UI 触发护栏 | ✅ 已实施（`weak-model-robustness` + `weak-model-interactive-ui` change） |
| L3 | 证据链机制 | grep-before-cite + hook 层事后验证（28 号模块） | ✅ 已实施（`weak-model-robustness` + `robustness-hook-hardening` change） |
| L4 | 伪双轨（model_tier opt-out） | 强模型显式声明 `model_tier: strong` 跳过加固 | ❌ 未实施（v2 计划） |

### 当前缺口

1. **无自动模型能力检测**：main agent 不会根据自身模型能力调整行为（如 deepseek-v4-pro 跳过大量 prompt 指令时，无法自动补 checklist 或降低并行度）
2. **无降级协议**：prompt 和 hook 层不对弱模型特征（幻觉、跳步骤、跳过工具调用）做主动适配——所有模型收到相同 prompt，仅靠 L1/L2/L3 被动拦截
3. **DESIGN.md D5/D6 的描述**是目标行为，但未形成可实施的协议文档

### design 哲学依据

flow-kit 的 `protect the weakest` 原则（ADR-001）规定：规则/prompt 默认按"最弱模型能扛住"写。但此原则解决的是**结构刚性**（护栏存在性），不解决**行为适配**（弱模型运行时降级）。两者互补：

- protect the weakest → 护栏对所有人开启（基线刚性）
- degradation protocol → 弱模型运行时获得额外帮助（动态适配）

## Decision

**分三阶段设计降级协议，v1 仅完成设计，实施推迟到 v2。**

### Phase 1: Prompt 层自识别 + 自适应（v2.0）

GO.md 路由结束后，main agent 通过 prompt 自我识别模型 tier：

```
[MODEL CAPABILITY SELF-CHECK]
你当前运行的模型是哪个 tier？
- strong: Claude-grade, 指令遵循稳定
- standard: GPT-4o-grade, 偶尔跳指令
- weak: minimax/qwen/deepseek-grade, 频繁跳步骤/幻觉

请回答一个词（strong/standard/weak），然后按以下规则调整行为：
- weak → 每阶段额外跑附录 checklist
- weak → 禁止并行派发 task（单 task 波次）
- weak → 每个 prompt 步骤后强制跑 L3 证据链验证（不可跳过）
- standard → 保持默认行为
- strong → 可跳过冗余自检
```

**实现要点**：
- GO.md 路由到 phase prompt 后，phase prompt 顶部注入此 self-check
- 模型回答后，后续 dispatch 逻辑读取 tier 并调整行为（单 task 波次 vs 并行、checklist 开/关）
- 不修改 prompt 文件本身（保持所有模型一份 prompt），而是通过运行时注入控制开关

### Phase 2: Hook 层自动检测 + 自动降级（v2.1）

SessionStart / Stop hook 分析 transcript 中的弱模型特征模式：

| 特征 | 检测方式 | 降级动作 |
|---|---|---|
| 连续 3 轮无工具调用（prompt 要求调但未调） | `grep -c "tool_calls"` < 阈值 | 注入矫正 banner + 追加 checklist |
| 引用的文件路径在 transcript 中未出现 | L3 证据链检测（已有） | 注入矫正 banner + 强制 grep-before-next |
| PCSC 自检表空白/跳过 | L2 自检完整性检测（已有） | 注入矫正 banner + 要求回填空 |

**实现要点**：
- 复用现有 `28-weak-model-compliance.sh` 和 `27-interactive-ui-check.sh` 的检测基础设施
- 新增 `DEGRADATION_LEVEL` 字段到 `.flow-active.correction`，从 binary（违规/未违规）升级为 graded（L0 正常 / L1 提醒 / L2 降级 / L3 阻断）
- 检测逻辑从"是否违规"扩展为"违规严重程度 + 频率"，累积触发降级

### Phase 3: A/B 测试基础设施（v2.2）

同 task 在 weak vs strong 模型上的行为对比：

- 记录 weak model session 的 task_progress（完成步骤、fix_rounds、幻觉次数）
- 与 strong model session 的同 task 记录对比
- 生成 degradation report（哪些 prompt 段在 weak model 下失败率最高）

**价值**：量化弱模型的实际降级程度，指导后续 prompt 优化优先级。

## Consequences

**正面**：
- L-063 关闭——D5/D6 降级场景已形成可实施的三阶段协议设计
- 协议与现有 L1/L2/L3 基础设施复用（不引入全新机制）
- 渐进式实施（v2.0 仅改 prompt 注入，v2.1 加 hook 检测，v2.2 加 A/B 测试）

**负面**：
- v2.0 的"自我识别"依赖模型诚实回答 tier——弱模型可能错误声明自己为 strong（幻觉）。Mitigation：Phase 2 hook 层自动检测可作为交叉校验
- 三阶段完整实施周期长（估计 v2.0~v2.2 跨越 2-3 个 change cycle）

**v1 用户影响**：
- 无。现有 L1+L2+L3 三层防护继续生效
- 弱模型在当前版本的行为不变（prompt 不注入 self-check，hook 不做自动降级）
- 仅在 v2.0 实施后，弱模型会话的行为会自适应调整

**禁动约束**：
- Phase 1 的 self-check prompt 文本不得嵌入 phase prompt 文件——必须通过 GO.md 路由层注入
- Phase 2 的 `DEGRADATION_LEVEL` 字段不得破坏现有 correction file schema（追加字段，非替换）
- Phase 3 的 A/B 数据不得包含用户业务内容（仅记录 task_progress 元数据）

## Verification

协议设计的内部一致性检查：

- Phase 1→2 的交叉校验闭环：Phase 1 self-check 的结果可被 Phase 2 hook 检测验证（弱模型自称 strong 但 transcript 显示跳步骤 → hook 可纠正）
- 与现有 L3 证据链的兼容：degradation 检测复用 L3 的 grep-before-cite 逻辑，不重复实现
- 与 pipeline goal 的兼容：弱模型在 toll-gate 处的 checklist 追加不影响 gate 判定逻辑（仅增加待办项）

实施验证（v2 future work）：
- Phase 1: bats 测试 self-check 注入 + tier→behavior 映射
- Phase 2: bats 测试 degradation 检测阈值 + correction file 正确性
- Phase 3: regression-demos 场景下 weak vs strong 对比数据

## 触发条件

- v2.0：新建 change，实施 Phase 1（prompt self-check + 行为适配）
- v2.1：新建 change，实施 Phase 2（hook 自动检测 + 降级）
- v2.2：新建 change，实施 Phase 3（A/B 测试基础设施）
