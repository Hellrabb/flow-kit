# CHANGE: 2026-07-10 Full Sweep 统一清理

- **Change ID**: `sweep-fix-2026-07-10`
- **创建日期**: 2026-07-10
- **路径建议**: 中等（无 UI / 无 schema / 纯代码改进，可跳 DESIGN 大部分，仅需轻量设计决策）
- **状态**: draft
- **来源**: `M-health 2026-07-10 Full Sweep`（评分 65/100 → 目标 ≥80）

---

## Why（为什么做）

2026-07-10 Full Sweep 发现 2🔴 + 4🟡 + 3🟢 共 9 项改进点。上次正常 Full Sweep（07-01）评分 68，本次 65（更严格函数级分析）。核心问题：

- **2 个超长函数**（307 行 / 290 行）是当前最大可维护性风险——任一环节变更需理解全部逻辑
- **check_* 模式重复**在 6 模块中逐字复制模板，新增 check 需手工复制 30-50 行
- **死代码**（`write_failed_state`）污染共享 lib，18 个 source 文件承担认知负荷
- **命名约定**无文档，5 种前缀混用

本次一次性消除全部 9 项，将评分从 65 提升至 ≥80。

## What（做什么）

1. **拆分 `l3_review_run()`**（TD-017 🔴）：307 行 → prompt 构造 + API 调用 + 结果解析 + .done 写入 + 编排器 5 个独立函数
2. **重构 `independent-review-gate.sh` 主逻辑体**（TD-018 🔴）：~285 行（L106-391，7 个 gate 检查混合为无名代码块）→ 提取为 `_gate_*` 命名函数 + `_run_review_gates()` 编排器；`is_gh_pr_create()`（3 行谓词）保持不变
3. **check_* 模式去重**（TD-019 🟡）：引入 `run_check()` 包装函数或声明式注册，消除 6 模块中 20+ 处模板重复
4. **清理 `write_failed_state` 死代码**（TD-020 🟡）：移除定义 + CONTEXT.md 条目
5. **命名约定文档化**（TD-021 🟡）：CONTEXT.md 加「命名约定」段，明确公共/私有前缀规则
6. **安装函数测试补充**（TD-022 🟢）：install_hooks / install_brooks_lint 加 DRY_RUN 单元测试
7. **`_grep` 兼容层评估**（🟢）：确认 ugrep 兼容状态，决定保留或移除

## 影响面

- [x] 影响 `REQUIREMENT.md`（需明确各函数的拆分边界和新接口签名）
- [x] 影响 `DESIGN.md`（TD-019 check_* 去重需设计决策：包装函数 vs 声明式注册）
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不做 `l3-review.sh` 按职责拆文件（TD-008 · 已登记为独立技术债，本次只拆函数不拆文件）
- 不做 `install_hooks()` / `install_brooks_lint()` 函数拆分（这些是线性安装步骤，拆分收益低）
- 不做批量重命名（命名约定只文档化，不执行重命名）
- 不做 CONTEXT.md「既有抽象索引」全量审计（范围太大，留给下次 evolve）

## 验收线（粗粒度，不是 AC）

- **AC-粗-1**：`l3_review_run()` ≤ 50 行（编排器），`is_gh_pr_create()` 重命名为 `_run_review_gates()` ≤ 40 行（编排器），各有 ≥ 4 个独立子函数
- **AC-粗-2**：所有现有测试（462 bats）全绿 0 fail，新增测试 ≥ 6 条（安装 DRY_RUN ×4 + check 去重 ×2）
- **AC-粗-3**：`write_failed_state` 定义 + CONTEXT.md 条目已移除；命名约定段已写入 CONTEXT.md；`_grep` 已评估并标注去留决策

## 风险与未知

- TD-017（l3_review_run 拆分）：函数被 2 处 source（independent-review-gate.sh + 29-independent-review.sh），需确认拆分后两者行为一致
- TD-018（is_gh_pr_create 拆分）：PreToolUse 关键路径，每次 tool call 触发，拆分不能引入性能退化
- TD-019（check_* 去重）：需决定包装函数签名——是所有 check_* 共用同一签名还是按模块分组
- 462 bats 0 fail 基线已确认，本次改动后必须保持

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
