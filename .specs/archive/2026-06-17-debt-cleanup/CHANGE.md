# CHANGE: 清理剩余技术债（5 合 1）

- **Change ID**: `debt-cleanup`
- **创建日期**: 2026-06-17
- **路径建议**: 最短（5 条均为单文件小改，无需 DESIGN/TEST/REVIEW 闭环）
- **状态**: active

---

## Why

health-fix 之后剩余 5 条活跃技术债（L-004/L-005/L-009/L-010/L-011），全是低成本单文件修复，堆积不如清掉。

## What

一次性修复全部 5 条，预计总改动 < 30 行。

| # | 文件 | 改动 | 行数 |
|---|------|------|------|
| L-005 | `package-flow-kit.sh` | STAGING 前置空值/根目录校验 | +3 |
| L-009 | `common.sh` | `CONFIG_FILE=""` → `: "${CONFIG_FILE:=}"` | ~1 |
| L-011 | `common.sh` | jq key 改为 bracket 引用 | ~2 |
| L-010 | 流程文件 | LESSONS 已记录，本次不做代码改动 | 0 |

L-004（辅助函数抽取）暂不修——当前函数数量未到阈值，等下次自然触及。

## 影响面

- [x] 影响 `REQUIREMENT.md`（最小 AC）
- [ ] 影响 `DESIGN.md`
- [ ] 影响现有 AC
- [ ] 影响数据模型/迁移

## 范围排除

- L-004 辅助函数抽取（等 ≥3 个新函数时自然触发）
- 新增 bats 测试（已有 28 tests 覆盖相关路径）

## 验收线

- bats 28/28 通过
- `package-flow-kit.sh` STAGING 校验生效
- `common.sh` source 后不再覆盖 CONFIG_FILE
- `module_enabled "claude-md"` 等连字符 key 正常解析
