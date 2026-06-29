# interactive-ui-guard — 交互式 UI 触发护栏模板

> **用途**：各 prompt 在到达"反问用户"/"进入计划模式"等交互 gate 时，引用本文件加轻量护栏（≤3 行/点），作为第一道防线。
> **第二道防线**：Stop hook `27-interactive-ui-check.sh` 在系统级兜底检测 + 矫正。详见 `@flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh`。

---

## 关系说明

```
Prompt 护栏（本文件）     ← 第一道防线（预防 ~60% 跳过）
        │
        ├── 弱模型忽略了护栏 → 跳过交互 gate
        │
        v
Stop hook 检测 + 矫正       ← 第二道防线（捕获 ~95% 剩余跳过）
        │
        ├── 写入矫正文件
        │
        v
SessionStart 注入矫正指令   ← 强制模型补调工具
```

---

## AskUserQuestion guard 模板

在 prompt 中任何"反问用户"/"等待用户回复"/"停下来等用户"的位置，加以下 2 层：

### ① 自检句（1 行）

```
❌ 如果你还没调用 AskUserQuestion 工具，现在停下来调用它。不要假设用户的选择，不要跳过。
```

### ② 工具调用骨架（1-2 行）

```
AskUserQuestion({ questions: [{ question: "<你的问题>", header: "<简短标签>", options: [{ label: "<选项>", description: "<说明>" }] }] })
```

### 完整示例

```markdown
## 反问 gate

<!-- weak-model-guard: AskUserQuestion -->
❌ 如果你还没调用 AskUserQuestion 工具，现在停下来调用它。不要假设用户的选择，不要跳过。

按以下格式反问用户（最多 3 个问题）：

AskUserQuestion({ questions: [
  { question: "你想要哪种方案？", header: "方案选择", options: [
    { label: "方案 A", description: "更快的实现，但扩展性有限" },
    { label: "方案 B", description: "更完整的方案，但工期更长" }
  ]}
]})
```

---

## EnterPlanMode guard 模板

在 prompt 中任何"进入计划模式"/"先出计划"/"不要在聊天里直接出方案"的位置，加以下 2 层：

### ① 自检句（1 行）

```
⚠️ 本步骤要求先进入计划模式。调用 EnterPlanMode 工具，不要直接在聊天里出方案。
```

### ② 前置条件 gate（1 行）

```
在进入计划模式并完成计划之前，禁止开始写代码或出具体实现方案。
```

### 完整示例

```markdown
## 步骤 N：设计方案

<!-- weak-model-guard: EnterPlanMode -->
⚠️ 本步骤要求先进入计划模式。调用 EnterPlanMode 工具，不要直接在聊天里出方案。
在进入计划模式并完成计划之前，禁止开始写代码或出具体实现方案。

进入计划模式后，按以下结构输出设计：
1. ...
```

---

## 使用约定

1. **每点 ≤ 3 行**：自检句 1 行 + 工具骨架 1-2 行。不加重型 L3 证据链（由 hook 承担）。
2. **`<!-- weak-model-guard -->` 注释**：标记护栏行，方便强模型识别（可跳过冗余自检）和 grep 定位。
3. **不改变原有交互逻辑**：该反问还是反问，该进 Plan 还是进 Plan，只加"弱模型别忘了调工具"的提醒。
4. **hook 脚本为兜底**：即使 prompt 护栏被忽略，Stop hook 也会在下一轮检测到并矫正。
