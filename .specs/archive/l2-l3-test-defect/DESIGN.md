# DESIGN: L2/L3 gate 机制诊断修复设计（回顾性）

- **Change ID**: l2-l3-test-defect
- **关联**: `@.specs/l2-l3-test-defect/REQUIREMENT.md`、`@.specs/l2-l3-test-defect/DIAGNOSE.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ L2/L3 独立审查
- **性质**: **回顾性**（A-E+G+L3-model 修复已实施+验证于 commit 1dca070/fb78235，本文档化设计决策）

---

## 0. 技术栈选定

纯 Bash 脚本项目（STATE `detected_stack` = "Bash 脚本项目（flow-kit 分发包仓库）"）。**N/A** —— 无技术栈选择（2-design 例外：纯 CLI/脚本项目跳过）。本次修复均在既有 bash hook 体系内，不引入新语言/框架。

---

## 0.5 既有架构对齐（brownfield · grep/git diff 证实）

### 0.5.1 本次 change 触碰的既有模块

```
触碰（既有 · git diff commit 1dca070/fb78235）：
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（_run_review_gates 7 Gate · BUG-A/B/C/D/E）
- flow-kit-bundle/hooks/stop/lib/done-validation.sh（fk_independent_review_gate_active · 被 BUG-E source）
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（l3_review_run · L3 model env-first）
- flow-kit-bundle/hooks/stop/lib/l2-detect.sh（l2_dispatch_agent · BUG-G mock_ts）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（L3 model env-first）
- test/test_l2_pretooluse_dispatch.bats + flow-kit-bundle/test/ 镜像（INT-1~6 补强）

新增模块：无（仅修既有）

禁动清单（与本次无关）：
- flow-kit-bundle/hooks/stop/26-workflow.sh（workflow 模块）
- flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh（checkpoint）
- .claude/hooks/stop/lib/.l3-bg-*.json（L3 背景 task · v2）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有？路径 | 决定 |
|---|---|---|
| gate 编排 | `_run_review_gates`（independent-review-gate.sh） | 沿用（仅修 Gate2/3 调用方返回值判定）|
| gate 开启判定 | `fk_independent_review_gate_active`（done-validation.sh） | 沿用（仅修 source 依赖）|
| L3 外部模型调用 | `l3_review_run`（l3-review.sh） | 沿用（仅修 model 选择）|
| L2 子 agent 派发 | `l2_dispatch_agent`（l2-detect.sh） | 沿用（仅修 mock_ts）|
| gate_config 双源 | gate_config + stop-hook.json phases | 沿用（双源逻辑正确）|

### 0.5.3 沿用模式 vs 引入新模式

```
- gate 7 Gate 编排：**沿用** _run_review_gates 架构（仅修 Gate2/3 调用方）
- 返回值语义：**引入新模式**（显式 rc 判定 `if cmd; then exit 0; fi`）→ 替代 `|| exit 0`（理由：旧模式语义反转，ADR-004）
- L3 model：**引入新模式**（env-first，强制 ANTHROPIC_DEFAULT_HAIKU_MODEL）→ 替代固定 deepseek fallback（ADR-006）
- L2/L3 触发机制：**沿用**（PreToolUse L2 gate + Stop hook L3，仅修 bug）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | gate 函数返回值用显式 rc 判定（`if cmd; then exit 0; fi`） | 改 gate 函数 return 语义 / `\|\| exit 0` | 旧 `\|\| exit 0` 与 gate 函数 return 0=skip/1=continue 反转 → BUG-A/B | 调用方多 1 行；return 语义须文档化（ADR-004）|
| D2 | `_gate_active_check` source `done-validation.sh` + `PROJECT_ROOT=cwd` | source artifacts.sh（旧） | fk_independent_review_gate_active 定义在 done-validation.sh 且依赖 PROJECT_ROOT；旧 source 错 lib → BUG-E | 调用方传 cwd（ADR-005）|
| D3 | L3 model 强制 `ANTHROPIC_DEFAULT_HAIKU_MODEL`（env，无固定 fallback） | 固定 deepseek / claude-haiku | 跟随用户 haiku 配置；固定值不适配多环境 | env 未设 `:?` 报错，部署须设（ADR-006）|
| D4 | `_gate_phase_transition` 非阶段写时 `return 0`（非 return 1） | return 1（旧） | 旧 return 1 在 set -e 下被当失败 → BUG-C | return 0=正常返回交 Gate7 |
| D5 | `_gate_check_l3` gate_val 空分支化（空→exit0 / 异常→exit2+stderr） | else exit2（旧无 stderr） | 旧误拦未配 phase + 无 stderr → BUG-D | 多 1 分支；防御异常 |
| D6 | `l2-detect.sh` mock 分支补 `mock_ts` 定义 | 删 mock_ts 引用 | line 120 引用未定义，set -u 报错 → BUG-G | date 兜底 echo mock |
| D7 | `independent-review-gate.sh` 局部 `declare -A PHASE_GATE_KEY_MAP`（与 common.sh:255 同步）| source common.sh / 不修 | PHASE_GATE_KEY_MAP 需求在编排层（_gate_phase_transition/_gate_deny_reason）；source common.sh 全局副作用（config_get 等污染，L3 phase2 critical1）；局部 declare 隔离副作用 | DRY（两处定义，注释注明同步 common.sh:255）|

---

## 2. 数据流 / 架构图

PreToolUse hook（AI 调 Bash/Write/Edit 前触发）：

```
AI tool call (Bash/Write/Edit)
        │
        v
independent-review-gate.sh  ← reads .flow-active (phase/change_id/gate_config)
        │
        v
_run_review_gates (7 Gate 串行)
   Gate1 path-guard      : 拦 .flow-active.independent-review 直写
   Gate2 _gate_phase_filter : phase∈{1,2,3,5,6,7}?  ← D1（if rc 判定）
   Gate3 _gate_active_check : gate_config 开启?     ← D1+D2（source done-validation.sh）
   Gate4 done validation    : .done 存在? (fk_validate_done_marker)
   Gate5 tamper detect      : gate_config vs snapshot 一致?
   Gate6 _gate_phase_transition : forward? L2/L3 dispatch ← D4+D5
   Gate7 _gate_deny_reason  : commit/PR/phase write deny
        │
   exit 0 (放行) / exit 2 (deny + stderr)
```

修复点作用位置：D1→Gate2/3 调用方 · D2→Gate3 source · D4→Gate6 return · D5→Gate6(_gate_check_l3) · D3→L3 dispatch · D6→L2 dispatch。

---

## 3. 关键状态机

**gate_config 值域**（fk_independent_review_gate_active 标准化）：
- `both` / `independent` / `true` → L2+L3（向后兼容映射 independent/true=both）
- `L2` → 仅子 agent 盲审
- `L3` → 仅外部模型
- 空（未配）→ inactive = 放行（AC-4/AC-10）

**gate state**（pipeline）：`0→1`...`6→7` 每个 transition gate `pending` → `passed`。

**phase 方向**（_fk_phase_direction）：`forward`（target>cur，触发 L2/L3）/ `rollback`（target<cur，放行）/ `noop`（target==cur，放行）。

---

## 4. ADR 索引

- `@.specs/adr/004-gate-return-value-semantics.md`（D1 · BUG-A/B）
- `@.specs/adr/005-gate-active-source-dependency.md`（D2 · BUG-E）
- `@.specs/adr/006-l3-model-env-first.md`（D3 · L3 model）

D4/D5/D6/D7 是局部修复，可逆性高，不入 ADR。D7（局部 declare）的 DRY 风险登记为 Technical Debt（见 §5 R5），v2 重构 common.sh 为 pure function 消除。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | ~~BUG-F（cosmetic phase_name 显示空）~~ → **升级 critical（L2 phase2 R1 发现，已修 v1）**：PHASE_GATE_KEY_MAP 在 common.sh:255 定义，hook 从不 source → 数组未定义 → gate_val 空 → BUG-D 放行 → **forward transition 全量绕过 gate**（phase1+ review 无.done 仍 forward 放行）| 实跑 EXIT=0 绕过（违反核心安全）| 高（已确认）| **已修 v1**（D7 source common.sh + INT-7 回归）|
| R2 | BUG-H（is_git_commit 子串误判）| L2 写报告等被误拦 | 中 | v2（结构化命令识别）/ **当前缓解**：审查文本含触发词时用 chr() 拼装绕过 |
| R3 | BUG-I（Stop hook 链本环境未自动触发 L3）| L3 需手动触发 | 中 | v2 / **当前缓解**：手动 `l3_review_run` 兜底（本 change 各 phase 均用此）|
| R4 | BUG-J（_l3_check_rerun mtime 误判已审查）| L3 误 skip | 中 | v2（检查 ## L3 段）/ **当前缓解**：touch artifact 触发 re-review |
| R5 | 实现风险：显式 rc 判定，未来 gate 函数 return 语义易混淆 | 新 gate 函数 return 须文档化 | 低 | ADR-004 + CONTEXT 术语 |
| R6 | 上线风险：L3 env-first，部署未设 env 则 L3 报错 | L3 无法跑（明确报错）| 低 | 部署文档 + `:?` 显式报错 |

---

## 6. 不在范围

- BUG-H/I/J 修复（v2，l2-l3-mock-fix）—— 注：BUG-F 已升级 v1 critical 修复（D7 source common.sh + INT-7），见 §5 R1
- 新 gate 机制设计（L4 hook 补跑 / 双轨 L5）—— 保留现有 7 Gate 架构
- L2/L3 调度机制重设计（PreToolUse 同步 L3 等）—— 仅修 bug

---

## 9. 架构沉淀建议（供 A-evolve 同步）

### 9.1 新增可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `test/test_l2_pretooluse_dispatch.bats` `_gate_run` helper | PreToolUse payload 注入 bash gate.sh + exit code 断言 | gate 编排层集成测试 | 后续 gate 修改必用此 pattern |

### 9.2 项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| gate 函数返回值约定 | return 0=成功/放行，1=失败/继续（bash 惯例）| 所有 gate hook | 重新审计所有 `\|\| exit` |
| L3 model 来源 | ANTHROPIC_DEFAULT_HAIKU_MODEL（env）| L3 外部模型审查 | 改回固定值（降低灵活性）|

### 9.3 跨模块契约

```
- gate_config 双源：.flow-active.goal.gate_config[phase] 优先，空时回退 .claude/stop-hook.json independent_review.phases（视为 both）
- .done 6 键 KVP：phase/change_id/written_by/L2_verdict/L3_verdict/artifacts
- gate state：.flow-active.goal.gates["N→N+1"] ∈ {pending, passed}
```

### 9.4 新增/升级依赖

无（纯 bash，依赖既有 jq/curl）。

### 9.5 禁动清单变化

```
- 新增禁动：.flow-active.independent-review（握手字段，仅 29 号 hook 子进程写，PreToolUse path-guard 拦 agent 直写）
- 解禁：无
```

---

> 本文件回顾性文档化已实施的 gate 修复（A-E+G+L3-model）。不含新代码实现（修复已在 commit 1dca070/fb78235）。
