# DESIGN: 自动 checkpoint hook

- **Change ID**: `auto-checkpoint-hook`
- **关联**: `@.specs/auto-checkpoint-hook/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目是 Bash 脚本项目（flow-kit 内部分发包），技术栈已在 CONTEXT.md 锁定，无需重选。

- **语言/运行时**: Bash 4.0+（`set -euo pipefail`）
- **JSON 处理**: jq 1.5+
- **测试**: bats-core 1.13.0（`npx bats`）
- **Hook 框架**: Claude Code PreToolUse hook（stdin JSON 协议）
- **关键依赖**: `checkpoint-lib.sh`（已有 · 本 change 移除去重逻辑）
- **明确排除**: 不引入新语言/运行时/依赖包

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/ls 出来的实际清单）：
- flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh（既有 · 本 change 移除去重）
- .flow-active（既有 · interrupt 字段已在 schema 中）
- flow-kit-bundle/skills/flow/SKILL.md（既有 · 更新 checkpoint 段文档）

新增模块：
- hooks/pre-tool-use/auto-checkpoint.sh（新 PreToolUse hook · 追加到已有 pre-tool-use/ 目录）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（L3 审查引擎，无关）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（gate 核心链 · 不可修改其逻辑）
- flow-kit-bundle/install.sh 中非 hook 注册段（打包/依赖安装，无关）
- flow-kit-bundle/hooks/stop/*.sh（Stop hook 模块 00~99，无关）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 更新 interrupt 字段 | `checkpoint-lib.sh::checkpoint_write()` | 沿用 · 但移除内部 dedup 调用 + 删除 dedup 函数 |
| 检测活跃 change | `.flow-active` 的 `change_id` 字段 | 沿用 · jq 读取判断非 null |
| Hook stdin 解析 | CC PreToolUse JSON 协议（`tool_name` / `tool_input.file_path` / `tool_input.command`） | 沿用 · 参照 `independent-review-gate.sh` 的 `jq -r '.tool_input.file_path'` 模式（已验证实际字段名） |
| Hook 安装注册 | `install_hooks.sh` 写 `.claude/settings.json` → PreToolUse 数组 | 沿用 · 参照 `independent-review-gate.sh` 的注册方式（matcher: `"Write|Edit"`，缩窄于 gate 的 `"Bash|Write|Edit"`） |
| Fail-open 容错 | 所有 hook 脚本遵循 fail-open 模式 | 沿用 · hook 异常 exit 0，不阻断工具 |

### 0.5.3 沿用模式 vs 引入新模式

```
- Hook stdin 解析：**沿用** jq 读 JSON → case 分发（与 independent-review-gate.sh 同模式）
- 文件写入：**沿用** checkpoint-lib.sh 的原子写入（jq → .tmp → validate → mv）
- 错误处理：**沿用** fail-open（stderr log + exit 0），与所有现有 hook 一致
- PreToolUse 目录：**沿用** hooks/pre-tool-use/（已有目录，含 independent-review-gate.sh），本次新增 auto-checkpoint.sh。模式参照 independent-review-gate.sh 的 stdin 解析 + install_hooks.sh 的注册方式
- install.sh hook 注册：**沿用** 既有 settings.json jq 追加模式（参照现有 PreToolUse hook 注册方式，install_hooks.sh:128）
```

---

## 0.6 PreToolUse stdin JSON 协议确认

> 本节确认 CC PreToolUse hook 的 stdin 协议实际字段名，消除 DESIGN 阶段的推测。

**已验证字段**（来源：`independent-review-gate.sh:15,105,108`——生产代码实际使用）：

```json
{
  "hook_event_name": "PreToolUse",
  "session_id": "<uuid>",
  "cwd": "<working directory>",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "<absolute or relative path>",
    "command": "<for Bash tool>"
  }
}
```

- **`tool_name`**：工具名。Write / Edit / Bash。checkpoint hook 只处理 Write 和 Edit。
- **`tool_input.file_path`**：目标文件路径。Write 和 Edit 工具均有此字段（已验证 gate 脚本实际使用）。
- **`tool_input.command`**：Bash 工具的完整命令。checkpoint hook 不使用此字段。

**决定**：直接使用 `.tool_input.file_path`，不做推测性 fallback（`|| path || filename`）。若字段缺失（未来 CC 协议变更），hook 写 `active_file=""` + stderr 日志，不阻断工具。

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | PreToolUse hook 拦截 Write/Edit，**pre-tool**（工具调用前）更新 interrupt | Post-tool 更新 / 双点记录 | Pre-tool 保证编辑中途崩溃也能恢复；单点够用不增加复杂度 | 编辑失败（工具调用本身被 deny）也会留下 checkpoint，但无害——下次恢复时看到旧 checkpoint 不碍事 |
| D2 | 移除去重逻辑：**删除** `checkpoint_dedup_check()` 函数和 `CHECKPOINT_DEDUP_WINDOW` 变量 | 保留 30s 去重 / 保留函数标记 deprecated | 用户明确选择"不去抖"；jq 更新 < 10ms，去重复杂度不值得；grep 确认该函数仅 `checkpoint_write()` 内部调用、零外部引用——保留即死代码 | 相关 4 个 bats tests（`test_checkpoint.bats:62-97`）需改写或删除 |
| D3 | 全阶段 0~7 自动 checkpoint | 仅 4-dev / 4+5+6 | 所有阶段都可能需要中断恢复；检测条件简单（有活跃 change 就写）不增加开销 | 规划阶段 Write 较少，实际多写几个 interrupt 无性能影响 |
| D4 | Fail-open：hook 异常 exit 0 | Fail-close（exit 2 阻断工具） | checkpoint 是辅助功能不是安全门禁，不应阻断正常编辑 | hook bug 导致 checkpoint 静默失败，需 stderr 日志辅助排查 |
| D5 | `checkpoint_write()` 调用时 `$3`（failing_check）传空字符串 | 额外字段区分 hook 来源 | PreToolUse hook 路径没有"测试失败"概念，传空即可 | interrupt 对象含 `failing_check:""` 空字段，对恢复无影响 |
| D6 | `install_hooks.sh` 注册 matcher 为 `"Write\|Edit"` | 复用 gate 脚本的 `"Bash\|Write\|Edit"` | AC-4 明确排除非 Write/Edit 工具；缩窄 matcher 减少不必要触发 + 降低与 gate 的 Bash 路径交互面 | 未来如需对 Bash 命令 checkpoint（如关键 jq 操作），需扩 matcher |
| D7 | auto-checkpoint.sh 与 independent-review-gate.sh 共存于同一 pre-tool-use/ 链 | 合并为一个脚本 / 独立目录 | CC PreToolUse hook 链按 settings.json 注册顺序**串行**执行；checkpoint 是纯记录（fail-open），gate 是拦截（fail-close）——两者职责正交无需合并 | 每个 Write/Edit 前执行 2 个 hook 脚本（而非 1 个），延迟增加约 < 10ms（jq 写入极快）。两 hook 均用 `jq → .tmp → mv` 原子写入，访问不同字段（interrupt vs goal.gates），实际竞态概率极低 |

### D7 补充：与 independent-review-gate.sh 的交互分析

```
CC PreToolUse hook 链执行模型（串行，按 settings.json PreToolUse[] 注册顺序）：

  settings.json: PreToolUse = [
    "auto-checkpoint.sh",        ← 先执行（matcher: Write|Edit）
    "independent-review-gate.sh" ← 后执行（matcher: Bash|Write|Edit）
  ]

  Write/Edit 调用前：
    1. auto-checkpoint.sh → 写 interrupt → exit 0（放行）
    2. independent-review-gate.sh → 读 phase/change_id → gate 校验 → exit 0/2（放行/拒绝）
  
  若 gate 拒绝（exit 2）：Write/Edit 被阻断，但 checkpoint 已记录（无害——记录了"意图编辑"的文件）
  
  竞态分析：
  - 两个 hook 串行执行，无并发写入 .flow-active 的问题
  - 两 hook 访问不同字段（interrupt vs goal.gates / phase），互不覆盖
  - hook 链执行期间 .flow-active 处于一致状态（无 Stop hook 并发——PreToolUse 在工具调用前，Stop hook 在会话结束后）```

---

## 2. 数据流 / 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                     AI 调用 Write/Edit                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           CC PreToolUse Hook 链（串行执行）                   │
│                                                              │
│  ① auto-checkpoint.sh（本 change · matcher: Write|Edit）      │
│     stdin: {"tool_name":"Write","tool_input":{"file_path"}}  │
│     ├── jq 解析 tool_name ──→ 非 Write/Edit → exit 0（放行）  │
│     ├── jq 检查 .flow-active.change_id ──→ null → exit 0      │
│     ├── source checkpoint-lib.sh                             │
│     ├── checkpoint_write "$file_path" "编辑 $file_path" ""    │
│     │   ├── 截断 action ≤ 200 字符                             │
│     │   ├── jq 原子写入 .flow-active.interrupt                │
│     │   │   {active_file, last_action, failing_check:"",      │
│     │   │    checkpoint_at}                                   │
│     │   ├── checkpoint_validate() 校验                        │
│     │   └── mv .tmp → .flow-active（原子替换）                 │
│     └── exit 0（放行 · fail-open）                            │
│                                                              │
│  ② independent-review-gate.sh（已有 · matcher: Bash|Write|Edit）│
│     ├── path-guard（防 agent 伪造握手文件）                    │
│     ├── gate_config 篡改检测                                  │
│     └── review gate 校验 → exit 0/2                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              CC 继续执行 Write/Edit 工具                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           .flow-active.interrupt 已更新                       │
│  {                                                           │
│    "active_file": "src/hooks/checkpoint.sh",                  │
│    "last_action": "编辑 src/hooks/checkpoint.sh",             │
│    "failing_check": "",                                      │
│    "checkpoint_at": "2026-07-10T15:30:00+08:00"              │
│  }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
          ┌──────────────┴──────────────┐
          ▼                             ▼
┌──────────────────┐          ┌──────────────────┐
│  正常继续会话     │          │  会话异常中断      │
│  interrupt 持续   │          │  SessionStart     │
│  被后续编辑覆盖   │          │  resume hook 读取  │
└──────────────────┘          │  interrupt → banner│
                              │  "上次编辑: X"     │
                              └──────────────────┘
```

---

## 3. 关键状态机

无复杂状态机。hook 是纯函数：输入 → 写文件 → 放行。

---

## 4. ADR 索引

本次无不可逆架构决策。D1~D7 均为实现层选择，不符合 ADR 门槛。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **实现风险**：CC PreToolUse stdin JSON 的 `tool_input.file_path` 字段名未来版本变更 | hook 解析不到文件路径，checkpoint 写入 `active_file=""` | 低 | 已通过 `independent-review-gate.sh:108` 生产代码验证字段名 `file_path`；若未来变更：stderr 日志 + fail-open 不阻断 |
| R2 | **上线风险**：`.flow-active` 被多个写入方（Stop hook 链、其他 PreToolUse hook、prompt 层手动操作）访问——jq 写入竞态 | interrupt 字段被旧值覆盖，checkpoint 丢失 | 低 | 所有写入方均使用 jq 原子写入（.tmp → mv）降低窗口；PreToolUse hook 链串行执行无并发；下一次编辑立即覆盖，丢失可控 |
| R3 | **长期债务**：移除 `checkpoint_dedup_check()` 和 `CHECKPOINT_DEDUP_WINDOW` 后，`test_checkpoint.bats` 中 4 个 dedup 测试需改写/删除 | 测试失败，CI 红灯 | 中 | 本 change 的 bats 测试文件中重写这 4 个测试（改为验证"不 dedup 行为"：连续两次 `checkpoint_write` 均返回 0） |
| R4 | **实现风险**：install_hooks.sh 在无 PreToolUse 键的 settings.json 上 jq 追加失败 | 安装后 hook 未注册，auto-checkpoint 不工作 | 低 | jq 先检测 PreToolUse 键是否存在，不存在则创建空数组再追加；install_hooks.sh 已有处理此情况的先例（gate 脚本注册） |

---

## 6. 不在范围

- Post-tool 二次确认（v2）
- 去重/去抖逻辑（v2 或永不做——用户选择不去抖，D2 已彻底删除 dedup）
- 跨 session checkpoint 统计面板 `/flow checkpoint --history`（out）
- 自动 checkpoint 覆盖非 Write/Edit 工具（out，AC-4 明确排除）
- 用 `interrupt` 字段替代 Stop hook G5 PROGRESS 日志（互补，不替代）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `hooks/pre-tool-use/auto-checkpoint.sh` | PreToolUse 阶段自动写 interrupt | AI 调用 Write/Edit 前 | 未来其他需要 PreToolUse 拦截的场景可参照此文件的 stdin 解析模式 + checkpoint-lib.sh 调用方式 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| checkpoint 去重策略 | 不启用（移除去重 · 删除 `checkpoint_dedup_check()` 函数和 `CHECKPOINT_DEDUP_WINDOW` 变量） | 所有调用 `checkpoint_write()` 的场景 | 低——如需恢复去重，重新实现 dedup 函数即可 |

> **本次推翻的已锁决策**：CONTEXT.md `[2026-07-04]`（来自 `user-guide-update` change）锁定了 "去重窗口 30s（同 file+同 type）"。本 change（`auto-checkpoint-hook`）在 REQUIREMENT 阶段经用户确认选择"不去抖"，DESIGN D2 决定彻底删除 dedup 逻辑。**CONTEXT.md 已同步更新**：已锁决策条目更新为 `[2026-07-10]`，域语言 "auto-checkpoint" 条目与决策一致（均标注"不去抖"）。

### 9.3 新增 / 修改的跨模块契约

```
- hooks/pre-tool-use/ 目录新增 auto-checkpoint.sh（与已有 independent-review-gate.sh 共存）
- checkpoint-lib.sh 的 checkpoint_write() 行为变更：不再内部调用 checkpoint_dedup_check()；CHECKPOINT_DEDUP_WINDOW 变量移除
- .flow-active.interrupt 字段新增写入路径：PreToolUse hook（此前仅 prompt 层手动 /flow checkpoint 写入）
- install_hooks.sh PreToolUse 注册数组新增 auto-checkpoint.sh 条目（matcher: "Write|Edit"）
```

### 9.4 新增 / 升级的依赖

无新增依赖。所有操作基于已有 jq + bash + checkpoint-lib.sh。

### 9.5 禁动清单变化

```
- 新增禁动：hooks/stop/lib/checkpoint-lib.sh 的 checkpoint_write() 不允许重新引入去重调用（除非走新 change + ADR 评审）
- 新增禁动：hooks/pre-tool-use/independent-review-gate.sh 不允许修改其 gate 校验逻辑（与 checkpoint hook 正交）
- 新增禁动：.flow-active.interrupt 不允许绕过 checkpoint_write() 直接 jq 写入（已有约束，本次 reinforce）
```
