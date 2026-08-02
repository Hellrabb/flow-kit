# Checkpoint 协议 — 入场恢复 · 中途暂停 · 断点恢复

> 本文件是 4-dev 阶段 checkpoint / 断点恢复协议的**单一源**。4-dev.md 通过 `@see reference/checkpoint-protocol.md` 引用此处。
> 修改 checkpoint 协议时，**只改这一处**。

---

## 动手前复述边界 + 关键节点 checkpoint + 证据链（弱模型鲁棒性 · R7.4 / R6.1 / AC-3）

**进入实现前必须做**（弱模型最易跳过、最易 scope drift）：

1. **复述边界（R7.4）**：一句话复述本 task 的 `read_files`（可读）/ `write_files`（可写）+ CHANGE「范围排除」。超出 `write_files` 的改动会被 R6.5 拦截。
2. **关键节点 checkpoint（AC-3 · 非每操作，避免啰嗦 AC-7）**：在以下节点强制 `/flow checkpoint`：
   - 开始编辑文件**前**
   - 遇测试或 verify **失败**时
   - **切换 task** 时
3. **证据链（L3 · R6.1）**：编辑 / 引用任何文件 / API / 字段 / 既有抽象前，必须 `grep` / `read` 验证存在。未验证 → 标注「未找到，拒绝引用」或停下确认。禁止凭印象引用（弱模型最高频幻觉源）。

---

## 中途断点（清窗触发与恢复，对应 R1.5 / R1.6 / R1.7）

### 入场恢复（会话开头若发现是接力）

若 `STATE.md` 的「中断任务」非空，或用户要求"继续 task X"，**第一动作**：

0. **先跑入场 Goal 检测**（见 4-dev.md 上方 `## 入场 Goal 检测` 段）：
   - 读 `.flow-active.goal`，若 `null` → 触发自动提取 + 双模式建议
   - 若 `status = "active"` → 展示横幅后进入 goal 迭代模式
   - 用户确认 goal 后再继续以下加载
1. 加载顺序固定：`METHODOLOGY → RULES → 4-dev prompt → CONTEXT → REQUIREMENT → DESIGN → TASK → <task-id>-PROGRESS`
2. 执行 R1.6 反重复检查：读 PROGRESS 的「已排除方案」，确认下一步不撞车
3. 从 PROGRESS 的「当前正在做」之后续起，禁止重新规划整个任务

### 中途暂停（触发 R1.1 信号时）

若执行中出现 token > 50k / 自我复读 / 同错重现 / 用户说"打转了"中任一信号：

1. **立即停手**——不要再写代码或跑工具
2. 用 `@flow-kit/templates/PROGRESS.md` 写出 `.specs/<id>/<task-id>-PROGRESS.md`，重点填：
   - 已完成子步骤（勾选清单）
   - 当前正在做（一段话，恢复后能直接续上）
   - **已排除的方案 + 理由 + 失败次数**（这是反重复的核心）
   - 待确认的假设
3. 更新仓库根 `STATE.md` 的「中断任务」字段
4. 输出"重启指令"给用户（见 RULES R1.5 模板）
5. 检查是否触发 R1.7：若 task 体量明显过大，建议在 `TASK.md` 里就地拆为子任务后再恢复

### 任务完成后

如果该任务有 PROGRESS.md，**删除它**，把有用信息迁移到 SUMMARY.md。
PROGRESS 是临时文件，不归档。

### auto-checkpoint hook 触发

flow-kit 在关键操作时自动更新 `.flow-active.interrupt`：

- **PreToolUse hook 层**：Write/Edit 调用前自动写 interrupt（100% 覆盖，不去抖）
- **prompt 层**：测试命令失败 / phase transition / toll-gate 暂停时手动 `/flow checkpoint`
- **Stop hook G5 PROGRESS 日志**：会话粒度进度记录

三层互补不冲突——最后写入者覆盖。

---

> **协议源声明**：本文件由 `cleanup-debt-batch-2026-08` change (2026-08-03) L-068 从 `flow-kit/prompts/4-dev.md` 抽取创建。原 4-dev.md `### 1.0`（checkpoint 段）+ `## 中途断点` 段内容。
