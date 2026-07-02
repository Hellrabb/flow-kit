# Pipeline Toll-Gate 共享协议

> 本文件是 toll-gate 协议的**单一源**。所有 prompt 和 skill 文件通过 `@see reference/pipeline-gates.md` 引用此处。
> 修改 toll-gate 协议时，**只改这一处**。改完后运行 `check-gate-sync.sh` 确认 prompt↔skill 一致。

---

## PCSC 自检表（Phase Completion Self-Check）

> ⚠️ **强制**：在进入 Phase Transition 之前，必须逐项完成以下自检。
> 任一 ❌ → **禁止进入 toll-gate**。先完成缺失项，然后重新自检。

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | `TASK.md` 中所有 task 状态 = "done" | `grep -c 'status="done"' TASK.md` | ✅ / ❌ |
| 2 | 每个 task 的 `*-SUMMARY.md` 已写入 | `test -f .specs/<change-id>/T*-SUMMARY.md` | ✅ / ❌ |
| 3 | 所有 verify 通过 + 6 维 self-review 已完成 | 检查 SUMMARY 中 verify + self-review 结果 | ✅ / ❌ |
| 4 | diff 边界 verify 已通过（提交前 diff 不越界） | `git diff --stat` 与 write_files 对照 | ✅ / ❌ |
| 5 | 沿用既有抽象 grep 已跑（1.4 段），结果在 SUMMARY 中 | 人工确认 | ✅ / ❌ |
| 6 | Sub-goal 自检（若 `phase_sub_goals["4"]` 非空） | 逐项对照 sub-goal 条件 | ✅ / ❌ |
| 7 | **1.8 触发时 bats 已跑且 0 fail**（L-010） | `grep "0 failures"` 1.8.4 输出 | ✅ / ❌ |

## auto_advance 分支

- 若 `auto_advance=true`：全 ✅ → 自动 transition 到 5-test；有 ❌ → **暂停 pipeline**，输出缺失清单，等待用户决定
- 若 `auto_advance=false`：全 ✅ → 进入 toll-gate；有 ❌ → **禁止进入 toll-gate**，补齐缺失项后重新自检

## Pipeline Toll-Gate

**触发条件**：TASK.md 中所有 task 状态 = "done"，且所有 SUMMARY.md 的 verify 通过。

**停下来。必须等待用户回复。禁止自动继续。**

输出 TOLL-GATE：

```
🚦 Toll-gate 4→5：所有 dev task 已完成。
✅ verify 全部通过
是否进入测试阶段（5-test）？
  1. 继续 → 进入 5-test（current_phase="5", phases_done+=["4"]）
  2. 暂停 → 保留当前状态，稍后 /flow-go 继续 恢复
```

用户选 1 → 执行 transition：
```bash
jq --arg ts "$(date -Iseconds)" \
  '.goal.current_phase = "5" | .goal.phases_done += ["4"] | .goal.gates["4→5"] = "passed" | .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```

---

## 全链 Gate Key Transition 校验语义（AC-2 · gate-integrity 扩展）

> **transition 前置查（核心）**：任何 phase N→N+1 transition 执行前，transition hook 必须读 `.flow-active.goal.gates["N→N+1"]`：
> - 值 = `"passed"` → 允许 transition
> - 值 ≠ `"passed"`（`"pending"` / 缺失 / 篡改）→ **拒绝推进**（deny），输出缺失的 gate key + 提示先产出合法 `.done`
>
> `passed` 状态只能由**合法 review 子进程**产出的 `.done` 触发设置（真实性校验见 gate-integrity Q1：`fk_validate_done_marker` Tier 1/2 拒空文件 / 假内容 / 跳过子进程）。agent 直接 `touch`/`echo`/写 `.done` → 真实性校验拒 → gate 保持 `pending` → transition 被前置查拦。这是防"威胁③ 跳过子进程"的协议层定义。

### 7 个 gate key

pipeline goal（`scope: "pipeline"`）的 `goal.gates` 字段含全链 transition key。`--from <n>` 决定起始阶段（默认 4 → 生成 4→5/5→6/6→7；`--from 0` → 全链 0→1...6→7）：

| gate key | from → to | transition 前置条件（gate 外的产物门禁）|
|---|---|---|
| `0→1` | 0-change → 1-requirement | `CHANGE.md` 存在 |
| `1→2` | 1-requirement → 2-design | `REQUIREMENT.md` 存在 |
| `2→3` | 2-design → 3-task | `DESIGN.md` 存在 |
| `3→4` | 3-task → 4-dev | `TASK.md` 存在 |
| `4→5` | 4-dev → 5-test | 所有 task done（**参考实例见上方 Pipeline Toll-Gate 段**）|
| `5→6` | 5-test → 6-review | `TEST.md` 存在 |
| `6→7` | 6-review → 7-integration | REVIEW 无 🔴 Critical |

> 注：gate 开启与否由 `goal.gate_config["<phase_name>"]` 决定（默认 `full` 预设仅 1/2/6 independent，3/5/7 由用户显式开；3/5/7 的 prompt 层独立审查支持由 `independent-review-gap` change (2026-07-02) 补齐，开启前确保 prompt 文件版本与此 change 同步）。gate 开启的 phase → transition 前置查 `gates["N→N+1"]` 必须为 `passed`（依赖合法 `.done`）；gate 未开启的 phase → transition 仅查产物门禁（上表第 3 列），不查 `.done`。

### 与 PCSC / Toll-Gate 的层次关系

- **PCSC 自检表**（本文件上方）：phase 完成前的产物/行为自检，phase-specific（4-dev 实例已列，其他 phase 按需补）
- **Toll-Gate**（上方 4→5 实例）：PCSC 全 ✅ 后的人工确认暂停点（`auto_advance=false` 时）
- **全链 transition 前置查**（本段）：transition **执行时**的 hook 强制 gate 检查，覆盖所有 7 个 gate key，是 toll-gate 确认后的最后一道自动门禁

---

> **协议源声明**：本文件由 `quality-baseline` change (2026-06-29) 创建（首批 DRY 提取，范围 4-dev），`gate-integrity` change (2026-07 · AC-2) 扩展为覆盖**全链 gate key transition 校验语义**。4-dev（4→5）段作为参考实例保留；其他 phase 的 PCSC 细节按需补充。
