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

> **协议源声明**：本文件由 `quality-baseline` change (2026-06-29) 创建，是 toll-gate 协议段的第一批 DRY 提取（范围：4-dev）。其他 phase 的 toll-gate 协议按需分批迁移。
