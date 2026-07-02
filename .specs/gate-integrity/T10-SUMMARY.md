# SUMMARY: T10 - fail 策略区分 + gate.sh 接线 fk_validate_done_marker（D9）

- **Change ID**: gate-integrity
- **Task ID**: T10
- **完成时间**: 2026-07-02 13:50
- **AI 角色**: Dev

## 做了什么

(1) gate.sh done_marker 检查从 `[ -f "$done_marker" ] && exit 0` 接线为 `fk_validate_done_marker "$done_marker" "$phase" "$change_id" "transition"`（return 0 有效→exit 0; return 2 无效→继续 deny 段）; (2) 加 fail 策略分段注释（path-guard = fail-open: lib 失败/不确定 exit 0; Tier 1/2 + ⑥ = fail-close: jq 不可用/解析异常 return 2 deny）。

## 改动文件

| 文件 | 性质 | 说明 |
|---|---|---|
| flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh | 修改 | done_marker 接线 fk_validate_done_marker + fail 策略注释 |

## verify

```text
T10 verify（畸形 .flow-active → fail-close return 2）✅
bash -n ✅ | 部署 L-015 一致 ✅ | bats stop_chain 13/0 ✅
```

## 完成判定

- TASK.md 已勾选：是
