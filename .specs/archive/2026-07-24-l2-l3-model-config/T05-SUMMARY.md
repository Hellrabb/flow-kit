# T05-SUMMARY — l2-detect.sh:215 替换 fallback → fk_resolve_model（移除 claude-sonnet-5）

## 做了什么
`l2-detect.sh:215` 替换 `${ANTHROPIC_L2_MODEL:-claude-sonnet-5}` → `fk_resolve_model "L2"` 三级链 + 降级。**移除 claude-sonnet-5 fallback**（ADR-012 产品决策，纯跨平台）。

## 改了哪些文件
- `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`（:213-215 替换 + 降级段）

## verify 输出
```
T05_VERIFY_OK（fk_resolve_model "L2" + 无 claude-sonnet-5 + write_model_missing_correction/clear "L2"）
claude-sonnet-5 残留：0
```

## 1.8 破坏性变更（移除 fallback）
- **行为变化**（US-2 已确认）：未设 ANTHROPIC_L2_MODEL 的 CC 用户从「用 claude-sonnet-5」→ 降级提示
- **降级**：API 前 return 3 + correction type=l2-model-missing

## 越界检查（R6.5）
write_files: l2-detect.sh | 实际 diff: l2-detect.sh | 越界: 0 ✅

## 注记
- 注释曾含 "claude-sonnet-5" 字样导致 verify `! grep` 误判，已改注释为"移除既有 L2 fallback"
