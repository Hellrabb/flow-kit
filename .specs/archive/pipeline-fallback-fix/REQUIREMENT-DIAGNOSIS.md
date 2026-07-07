# REQUIREMENT: 诊断 pipeline 自动推进 + 回退模式

- **Change ID**: pipeline-fallback-fix
- **关联**: `@.specs/pipeline-fallback-fix/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想验证 `auto_advance=true` 时 pipeline 能在 PCSC 全✅后自动推进到下一阶段，以便确认自动推进机制未因 L2/L3 hook 加固而断裂。
- **US-2**：作为 flow-kit 维护者，我想验证 L2/L3 hook 的执行结果能正确反馈到 pipeline gate 状态，以便确认独立审查+合规检测+交互UI矫正的闭环完整性。
- **US-3**：作为 flow-kit 维护者，我想验证 fallback 模式（CC native `/goal` 不可用）下的 pipeline 行为与 native 模式一致，以便确认回退路径在 native `/goal` 不可用时仍可用。

## 验收准则（AC）

### AC-1 · auto_advance 推进链路

- **Given** `.flow-active.goal.auto_advance = true`，pipeline 处于某个阶段 N（N ≠ 7），PCSC 全部 ✅
- **When** 阶段 N 的所有产物已写入磁盘，PCSC 自检完成
- **Then** pipeline 自动 transition 到 N+1（current_phase 更新、gates["N→N+1"] = "passed"、phases_done 追加 N），**不输出** toll-gate 交互提示
- **验证方式**: `jq '.goal.current_phase' .flow-active` 读取阶段号，确认自动递增；grep transcript 确认无 "是否进入 Phase N+1" 交互文本

### AC-2 · PCSC ❌ 阻塞行为

- **Given** `auto_advance = true`，pipeline 处于某个阶段，但该阶段至少 1 项 PCSC 产物缺失（如 REQUIREMENT.md 未写入）
- **When** PCSC 自检执行
- **Then** pipeline **暂停**并输出缺失清单（列出具体缺失项），**不**执行 transition，**不**更新 current_phase
- **验证方式**: 故意不写某产物 → 跑 PCSC → 确认 current_phase 未变 + transcript 含缺失清单

### AC-3 · auto_advance=false 的 toll-gate 行为

- **Given** `auto_advance = false`，阶段完成、PCSC 全 ✅
- **When** AI 在阶段完成后执行 PCSC 自检并确认全 ✅，随后进入 transition 评估逻辑
- **Then** 输出 toll-gate 交互提示（含 "是否进入 Phase N+1" 和 1/2/3 选项），**等待用户回复**才执行 transition
- **验证方式**: 当前 change（auto_advance=false）的每个阶段完成时，确认 toll-gate 提示被输出且等待用户确认

### AC-4 · gate_config 独立审查 done 文件写入

- **Given** `.flow-active.goal.gate_config["N-xxxx"] = "independent"`，阶段 N 的主 agent 已派 L2 盲审子 agent
- **When** L2 盲审完成并产出 `INDEPENDENT-REVIEW-<N>.md`，L3 Stop hook 审查完成并写入了同文件的 L3 段
- **Then** 主 agent 可执行 `touch .specs/<id>/.independent-review-<N>.done`，文件非空（含至少一行有效内容）
- **验证方式**: 解析 `.done` 文件，按 AC-5a 的结构化字段校验（phase/change_id/L2_verdict/L3_verdict/artifacts 五键齐全且值有效）

### AC-5 · .done 文件真实性校验

- **Given** `.done` 文件存在
- **When** PreToolUse hook（`independent-review-gate.sh`）检查 `.done` 文件
- **Then** hook 能区分合法 .done（符合 AC-5a 的结构化内容规范）vs 伪造 .done（空文件 / 仅 "done" / 占位文本 / 缺少必填键 / verdict 值无效）
- **验证方式**: 手动创建空 `.done` 或 `echo "done" > .done` → 尝试 commit → hook 应拒绝（exit 1）；手动创建缺少 L3_verdict 键的 `.done` → 尝试 commit → hook 应拒绝（exit 1）

### AC-5a · done 文件内容规范

- **Given** 独立审查（L2 + L3）均已完成，主 agent 准备写入 `.done` 文件
- **When** 主 agent 写入 `.done` 文件内容
- **Then** `.done` 文件至少包含以下键值对（每行格式 `key=value`）：
  ```
  phase=<N>
  change_id=<change-id>
  L2_verdict=pass|fail
  L3_verdict=pass|fail
  artifacts=<逗号分隔的产物文件列表>
  ```
- **验证方式**: 解析 `.done` 文件，检查上述 5 个键均存在且值有效（phase 为正整数、change_id 非空、verdict 为 pass 或 fail、artifacts 至少含 1 个文件名）

### AC-6a · PreToolUse hook 拦截 transition jq

- **Given** gate_config 对阶段 N 开启了独立审查，`.done` 文件不存在或无效（不符合 AC-5a 规范）
- **When** AI 尝试执行 transition（N→N+1）的 jq 命令
- **Then** PreToolUse hook 拦截该 jq 命令（exit 1），输出明确拒绝原因（含缺失的 `.done` 文件路径），gate 状态不更新
- **验证方式**: 不创建 `.done` → 执行 transition jq → 确认 hook 输出拒绝消息 + exit 1 + `gates["N→N+1"]` 仍为 "pending"

### AC-6b · toll-gate 在 .done 缺失时拒绝放行

- **Given** gate_config 对阶段 N 开启了独立审查，`.done` 文件不存在，PreToolUse hook 被绕过或未触发（如通过非 jq 方式修改状态）
- **When** toll-gate 评估阶段 N 的通行条件
- **Then** toll-gate 检测到 `.done` 缺失，输出拒绝消息并阻止 transition
- **验证方式**: 手动修改 current_phase（绕过 jq hook）→ 触发 toll-gate 评估 → 确认 toll-gate 拒绝 + current_phase 回退

### AC-7 · fallback 模式触发

- **Given** 环境变量或版本检测使 `claude --version` 返回 < 2.1.139（或直接设 `mode: "fallback"`）
- **When** pipeline goal 启动
- **Then** flow-kit 走内置 prompt 驱动迭代循环（非 CC native `/goal`），每 turn 结束后自行检查条件是否满足
- **验证方式**: 设置 `mode: "fallback"` → 启动 pipeline → 确认 transcript 中出现 fallback 迭代提示（非 native goal success/failure 消息）
- **注**: 两种触发方式（版本检测模拟 vs 直接设 mode）预期等价。v1 诊断至少覆盖直接设 mode 路径；若同时验证版本检测路径则在 DIAGNOSIS.md 中标注等价性结论

### AC-8 · fallback 路径 toll-gate 一致性

- **Given** fallback 模式下 pipeline 处于某阶段的 toll-gate
- **When** 阶段完成
- **Then** toll-gate 行为与 native 模式一致：相同暂停点（相同阶段间）、相同选项（1/2/3）、相同 transition jq 命令
- **验证方式**: 对比 fallback 和 native 路径同一阶段的 toll-gate 输出，确认结构一致（仅模式标识不同）

### AC-9 · fallback 终止条件正确性

- **Given** fallback 模式下所有阶段（0→7）已完成
- **When** 最后一阶段（7-integration）完成
- **Then** 迭代循环正确终止，输出符合以下任一模式的终止消息：
  a) "Goal achieved"（精确匹配）
  b) "Pipeline complete: 0→7"（含阶段范围声明）
  c) "All phases completed"（含阶段计数）
  不无限循环
- **验证方式**: 跑完 0→7 → 确认循环停止 + transcript 最后 5 行匹配上述模式之一 + `.flow-active.goal.status` = "completed"

### AC-10 · fallback 不应停时不停

- **Given** fallback 模式下 pipeline 处于中间阶段（如阶段 3 完成，还有 4→5→6→7 未跑）
- **When** 当前阶段完成
- **Then** 迭代循环**不**提前终止（不误判 goal 完成），继续推进到下一阶段
- **验证方式**: 阶段 3 完成 → 确认继续推进到阶段 4，而非输出 "Goal achieved"

### AC-11 · 诊断证据完整性

- **Given** v1 诊断执行完成，产出了 DIAGNOSIS.md
- **When** 审核 DIAGNOSIS.md
- **Then** 对于每个标记为 ❌ 或 ⚠️ 的 AC，DIAGNOSIS.md 的对应小节至少包含：
  a) 一段 transcript 摘录（≥3 行），精确体现异常行为
  b) 一个 `.flow-active` 状态快照（jq 输出），标注快照时间戳
  c) 一份根因假设（非仅复述症状）
- **验证方式**: 对 DIAGNOSIS.md 中所有 ❌/⚠️ AC 逐条检查，确认 a/b/c 三项齐备

### AC-12 · native 模式管线完成行为

- **Given** native 模式下（auto_advance=true 或 false），pipeline 已完成阶段 7（integration），PCSC 全部 ✅
- **When** 阶段 7 的所有产物写入磁盘，PCSC 自检完成
- **Then** pipeline 输出明确的完成消息（含 "Goal achieved" 或等效的阶段范围声明），`.flow-active.goal.status` = "completed"
- **验证方式**: native 模式 0→7 跑完 → 确认 transcript 末尾含完成消息 + jq 读取 status 为 "completed"

---

## 范围切分

### v1（本次必做 — 诊断）

- native 路径（auto_advance=false）0→7 端到端诊断（含当前 change 自身）
- native 路径 auto_advance=true 最小验证（单独的最小 change 模拟）
- fallback 路径 0→7 端到端诊断（手动设置 `mode: "fallback"`）
- .done 真实性校验的手动验证（构造假 .done 文件测试 hook 反应）
- 产出 `DIAGNOSIS.md`：逐 AC 状态 + 根因 + native/fallback 差异对比表 + 修复建议优先级

### v2（下一轮 — 修复 change）

- 修复 DIAGNOSIS.md 中标记为 ❌/⚠️ 的问题
- 为 pipeline 推进关键路径添加 bats 自动化测试
- fallback 路径的自动化回归测试

### out（永远不做）

- 修改 CC native `/goal` 的源码或行为（非 flow-kit 控制范围）
- 重写 pipeline 推进逻辑（诊断阶段不改代码）
- 移除或降级任何 L2/L3 护栏

---

## 非功能性需求

- **性能**: 无（诊断任务）
- **可访问性**: 无
- **安全**: 无
- **兼容性**: 诊断需覆盖 native（CC ≥ 2.1.139）和 fallback（模拟 CC < 2.1.139）两个路径
- **可观测性**: 诊断过程每步需记录实际行为（transcript 摘录 + `.flow-active` 状态快照），作为 DIAGNOSIS.md 的证据附件

## 依赖与假设

- **依赖**: flow-kit 当前版本的完整 hook 链（22-git / 24-session / 26-workflow / 27-interactive-ui-check / 28-weak-model-compliance / 29-independent-review）均已安装且可执行
- **依赖**: `.claude/stop-hook.json` 的 `independent_review` 模块已启用
- **假设**: 当前 CC 版本 2.1.198 支持 native `/goal`，可作为 native 路径的测试环境
- **假设**: 可通过修改 `.flow-active.goal.mode` 或临时环境变量模拟 fallback 路径。两种触发方式（版本检测 vs 直接设 mode）预期等价——诊断时至少验证一种，若两种均验证则在 DIAGNOSIS.md 中标注等价性确认结果
- **假设**: gate_config all 的独立审查机制在本次诊断 change 自身中会被触发，可作为"自我诊断"的一部分观察
- **阶段编号映射**: pipeline 内部使用 0-indexed（0=init ~ 7=integration），但独立审查文件命名使用 1-indexed phase 编号（phase 1=requirement ~ phase 7=integration）。阶段 0（init）无独立审查 gate
- **change 隔离**: v1 的 auto_advance=true 最小验证在**独立分支或独立 `.flow-active` 状态**下执行，不污染当前 change 的 pipeline 状态。DIAGNOSIS.md 中记录隔离措施
