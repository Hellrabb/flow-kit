# SUMMARY: T11 - phases_done 合法写入通路 is_phase_write 扩拦（D10）

- **Change ID**: gate-integrity
- **Task ID**: T11
- **完成时间**: 2026-07-02 14:00
- **AI 角色**: Dev

## 做了什么

gate.sh is_phase_write 加一行 `[[ "$c" =~ \.goal\.phases_done ]] && return 0` — agent 经 Bash（含写信号 >.tmp && mv）写 `.goal.phases_done` 字段 → is_phase_write return 0 → deny。`.phase`/`.goal.current_phase` 不回归，非 phase 字段（.goal.status）不误拦，无写信号的纯 jq 读不拦。transition hook 子进程独占写 phases_done。

## 改动文件

| 文件 | 说明 |
|---|---|
| independent-review-gate.sh | is_phase_write 加 `.goal\.phases_done` 匹配（1行）|

## verify

```text
phases_done jq+mv: BLOCKED ✅  .phase: BLOCKED ✅（原有）
.goal.current_phase: BLOCKED ✅   .goal.status jq+mv: LEAK ✅（不误拦）
phases_done 纯jq（无写信号）: LEAK ✅
bash -n ✅ | 部署 L-015 ✅ | bats stop_chain 13/0 ✅
```

## 完成判定

TASK.md 已勾选：是
