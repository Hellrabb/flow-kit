# SUMMARY: T08 - 29号握手字段 + A决策扩 artifact case 到 3/5/7

- **Change ID**: gate-integrity
- **Task ID**: T08
- **完成时间**: 2026-07-02 13:32
- **AI 角色**: Dev

## 做了什么

(1) 29号 state_file 握手加 `written_by:"stop-hook-29"` + `l3_token=sha256(L3审查原文)`（`printf '%s' "$content" | sha256sum`）；(2) **A 决策**：扩 artifact case（:77-104）到 3/5/7——3→TASK.md / 5→TEST.md / 7→REVIEW.md+CHANGELOG，各配领域 checklist。**死锁已解**：3/5/7 开 independent 时 29号 能拼工件跑 L3，握手可写，T06 Tier 2 T3 校验可达（不再因 artifact 空→exit 0→握手缺失→deny 死锁）。AC-6 已有的 `>>` 追加 + fail_count 随 verdict 保留。

## 改动文件

| 文件 | 性质 | 说明 |
|---|---|---|
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | 修改 | state_file 加 written_by + l3_token + artifact case 扩 3/5/7 |

## verify

```text
bash -n ✅
grep written_by=stop-hook-29 + l3_token ✅
artifact case: 3→TASK.md / 5→TEST.md / 7→REVIEW+CHANGELOG ✅
部署 L-015 一致 ✅
```

## 6 维快查

- 🟢 R1-R6：纯加字段/分支（机械改动），无逻辑重构。

## 越界检查

✅ 0 越界：T08 write_files = 29号，实际改动 = 29号。

## 完成判定

- TASK.md 中对应任务已勾选：是
- 提交 hash：未提交
