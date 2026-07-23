# T02-SUMMARY — correction-file.sh write_model_missing_correction/clear

## 做了什么
`correction-file.sh` 新增 `write_model_missing_correction <layer>` + `write_model_missing_clear <layer>`（ADR-013）。

## 改了哪些文件
- `flow-kit-bundle/hooks/stop/lib/correction-file.sh`（+55 行，两函数追加在 correction_file_clear 后）

## verify 输出
```
VERIFY_OK（两函数定义 + grep if .type=="compliance" 安全机制）
S1 无既有 → 写入 l3-model-missing ✅
S2 compliance 在场 → 不覆盖（保留安全信息）✅
S3 clear 匹配 L3 → 删除 ✅
S4 clear 不匹配(compliance) → 保留 ✅
```

## 关键设计
- **compliance 优先 + 原子写**（L3 Phase 2 竞态）：单次 `jq 'if .type=="compliance" and ((.violations//[])|length>0) then . else $new end'` → tmp → mv（避免 Check-Then-Act TOCTOU）
- schema `{type, layer, message}`，与既有 `l2-missing`（L2 段缺失）精确等值区分
- clear 仅删匹配 type（保留 compliance/l2-missing/other）

## 6 维自查
- R1 认知过载：两函数各 ~20 行 ✅ | R2 变更传播：仅追加，不改既有 4 helper ✅
- R3 知识重复：复用既有 correction_file_exists/write ✅ | R4 偶然复杂：compliance 优先是安全需求 ✅
- R5/R6：LEAF lib 无反向依赖，命名清晰 ✅

## 越界检查（R6.5）
- write_files: correction-file.sh | 实际 diff: correction-file.sh | 越界: 0 ✅

## LESSONS 查阅
- L-020（新模块三处接线）：不适用（lib 函数非模块）
- L-011（jq key）：type/layer/message 无特殊字符 OK
