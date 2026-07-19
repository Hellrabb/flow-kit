# REVIEW — health-debt-cleanup

> 2026-07-20 · Phase 6 代码审查

## 审查范围

| 文件 | 变更类型 | 行数 |
|------|----------|------|
| `flow-kit-bundle/hooks/stop/26-workflow.sh` | 函数重命名（11 处定义 + 5 处调用 + 2 处引用） | +18/-18 |
| `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh` | 注释更新 | +1/-1 |
| `.specs/CONTEXT.md` | 追加三段（命名约定 + _grep + install 容忍度） | +6 |
| `.specs/LESSONS.md` | L-052/L-053/观察 → resolved + 元数据更新 | +19/-3 |
| `test/test_install_coverage.bats` | 新建（16 bats cases） | +175 |
| `flow-kit-bundle/test/test_install_coverage.bats` | 同步副本 | +175 |

**仅关注源码变更**（jscpd report JSON 是巡检产物缓存，非源码）。

## 6 维审查

### R1 · Cognitive Overload
- 重命名后的函数名更清晰：`_fk_check_g1_body()` 比 `check_g1_body()` 更能表达"flow-kit 私有检查函数"语义
- `_fk_file_age_days()` 统一到 `_fk_*` 私有前缀
- **发现**: 修复过程中曾引入双重前缀 `_fk__fk_file_age_days`（replace_all 对已重命名函数二次替换），已修复。**教训**: 重命名批处理时避免 `replace_all: true` 对已包含目标前缀的标识符二次命中

### R2 · Test Coupling
- 新增测试沿用 DRY_RUN 模式 + `bash -c` 子进程隔离，不依赖真实文件系统
- 全量回归 559/0 → 重命名未引入回归

### R3 · Knowledge Duplication
- 无新增重复。命名约定统一反而消除了 `check_g*` / `fk_*` 两套风格的知识分裂

### R4 · Error Handling
- 重命名未改变任何控制流。函数体完全不变，仅函数名变更

### R5 · Security
- 无安全影响。纯重命名 + 文档标注

### R6 · Naming Convention
- ✅ 本 change 正是修复 R6 命名不一致问题。`check_g*` → `_fk_check_*` 统一到私有 `_*` 前缀

## 总结

| 维度 | 评级 |
|------|------|
| R1 认知负荷 | 🟢 改善（命名更清晰） |
| R2 测试耦合 | 🟢 独立隔离 |
| R3 知识重复 | 🟢 消除分裂 |
| R4 错误处理 | 🟢 未改变 |
| R5 安全 | 🟢 无影响 |
| R6 命名 | 🟢 已修复 |

**Verdict**: ✅ PASS — 0 Critical / 0 Major / 0 Minor

**双重前缀 bug 已修复并部署**。建议：今后批重命名时使用精确匹配（`\<oldname\>` word boundary）或逐条 Edit 替代 replace_all。
