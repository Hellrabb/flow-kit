# T03-SUMMARY — l3-review.sh:623 替换 :? → fk_resolve_model + 降级

## 做了什么
`l3-review.sh:621-623` 替换 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:?...}` → `fk_resolve_model "L3"` 三级链 + 降级（API 前 return）+ 正常路径 clear。

## 改了哪些文件
- `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（:621-623 替换，+降级段）

## verify 输出
```
T03_VERIFY_OK（fk_resolve_model "L3" + 无 :? + write_model_missing_correction/clear "L3"）
:? 残留：0 处（已移除）
```

## 1.8 破坏性变更（移除 :? model 解析）
- **grep 引用图**：`ANTHROPIC_DEFAULT_HAIKU_MODEL` 仅 :623（:? 已移除）+ :31 header 注释（过期文档"默认 deepseek-v4-flash"，非 T03 范围，留待清理）
- **影响**：model 解析从 `:?` 硬依赖 → 三级链 + 降级（ADR-012，DESIGN 已定，用户确认纯跨平台）
- **回归测试**：bats 全量（AC-7，T09-T11 完成后跑）

## 关键设计
- **降级 vs 错误区分**：model 空 → API 前 `return 3`（不发 `_l3_call_api`）+ correction type=l3-model-missing；不依赖 return 3 唯一性（l3-review 16 处 return 3）
- **source guard**：`type write_model_missing_correction || source correction-file.sh`（29-indep 未显式 source correction-file，guard 兜底）

## 越界检查（R6.5）
write_files: l3-review.sh | 实际 diff: l3-review.sh | 越界: 0 ✅

## LESSONS
- L-020 不适用（改既有 lib，非新模块）| L-199 source guard 容错对齐
