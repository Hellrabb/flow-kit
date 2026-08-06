# T02-SUMMARY — 34-archive-commit-check.sh 新建

## 做了什么

新建 `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh`（99 行）—— D3 双模式归档后未 commit 检测。

## 实现

- 骨架对齐 28-weak-model-compliance + 32-fallback-guard 先例
- `module_enabled "archive_commit_check"` guard（F8 snake_case）
- `_check_archive_commit_body()` 全用 `$PROJECT_ROOT` env（F1 修复 · 非 $1）
- **pipeline 分支**：scope=pipeline + status=done + `.specs/archive/` 存在（F3-residual 修复 · 三条件）
- **单阶段分支**：arch_mtime > last_commit_ts（git log %ct 锚点 · F3 修复 · 全路径 `${PROJECT_ROOT}` + `cd` + `|| echo 0`）
- `correction_file_write` 2 参 path+json（F2 修复 · 对齐 correction-file.sh:47 真签名）
- type-guarded clear（F4 修复 · 对齐 write_model_missing_clear:132-152 先例 · 读 .type 匹配才 rm）
- `run_check "archive_commit_check" "AC3" "" _check_archive_commit_body`（F8 snake_case）

## verify

```
bash -n → ✅
module_enabled guard: 2 refs
run_check: 1 ref
_check body: 2 refs
type-guarded clear: 3 refs
PROJECT_ROOT env: 8 refs
T03 常量引用: 2 refs
```

## 6 维自查（内置快查 · 99 行单职责）

- R1 ✅ 99 行无嵌套 / R2 ✅ 仅新建文件 / R3 ✅ 复用既有 lib / R4 ✅ 无过度 / R5 ✅ 3 source 对齐 28 号 / R6 ✅ 语义清晰

## 越界检查

diff 仅含 `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh`（新建）→ 0 越界 ✅

## 沿用既有抽象

- module_enabled + run_check（common.sh:22-26 / common.sh:53-61）
- correction_file_write 2参 path+json（correction-file.sh:47）
- type-guarded clear 先例（correction-file.sh:132-152 write_model_missing_clear）
- CORRECTION_TYPE_ARCHIVE_UNCOMMITTED（T03 常量）
- HOOK_BASE_DIR + source common.sh 骨架（28/32 号先例）
