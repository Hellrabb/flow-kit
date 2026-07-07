# CHANGE: 修复 gate-integrity L2/L3 code review 3C+5I 缺陷

- **Change ID**: code-review-fixes
- **日期**: 2026-07-03
- **关联**: gate-integrity change（`74fef9e` + `d6c8e0c`）

## 背景

gate-integrity 的 L2/L3 code review（子 agent `code-reviewer`）审查了 `3c82c74..d6c8e0c` 的完整 diff（18 文件，885 行新增），发现 2 个 Critical + 4 个 Major + 5 个 Minor + 4 个建议。

## 范围

### v1（本次）

- **C1**: `is_handshake_write` 的 `tee` 正则修复（行首 `tee` 无前导空格 → 绕过）
- **C2**: `is_handshake_write` 的 `sed -i` 正则修复（`sed -E -i` 等 flag 插入 → 绕过）
- **M1**: `tampered-done/check.sh` 握手文件格式更新为 phase-keyed 格式
- **M3**: `29-independent-review.sh` curl API key 注入风险（最低优先级，既有代码）
- **M4**: `fk_independent_review_gate_active` 注释与实现一致性确认
- 选做部分 Minor + 建议（按优先级）

### out（永远不做）

- M2（PROJECT_ROOT 双斜杠）——无害，不改
- 重构 `is_handshake_write` 为穷举式——v2 范围

## 影响

- 改动文件：`independent-review-gate.sh`、`tampered-done/check.sh`、可选 `29-independent-review.sh`
- 改动量：< 10 行
- 风险：极低（正则微调）
