# T03-SUMMARY · pipeline-gates.md 扩全链 Gate Key Transition 校验语义

- **Change**: gate-integrity
- **Task**: T03（Wave 1 · 并行 · 独立文件）
- **AC**: AC-2（transition 前置查 gate + 扩展单一源全链）
- **完成**: 2026-07-02

## 改动清单

| 文件 | 角色 | 改动 |
|---|---|---|
| `flow-kit-bundle/flow-kit/reference/pipeline-gates.md` | 维护源（toll-gate 协议单一源）| 追加「全链 Gate Key Transition 校验语义」段 + 更新协议源声明 |

运行时 `~/.claude/flow-kit/reference/pipeline-gates.md` 经 `install.sh --global` 部署同步（L-015 合规）。

## 实现内容（对应 AC-2 Then ①②）

AC-2 要求：① transition 前置查 `goal.gates["N→N+1"]` 非 passed 则拒；② 扩展 pipeline-gates.md 覆盖全链 gate key transition 校验语义。

1. **transition 前置查语义（核心段）**：定义 transition hook 行为——读 `gates["N→N+1"]`，值=`passed` 放行，否则 deny + 提示产出合法 `.done`。明确 `passed` 只能由合法 review 子进程 `.done` 触发（关联 gate-integrity Q1 `fk_validate_done_marker`），是防"威胁③ 跳过子进程"的协议层定义
2. **7 个 gate key 表**：`0→1` ... `6→7` 全链，每 key 列 from→to + 产物门禁（CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW 存在性 + 4→5 的 task done）
3. **gate 开启语义**：gate_config 决定是否查 `.done`（开启→查 gates passed；未开启→仅查产物门禁），与 AC-4 的 3/5/7 默认 off 一致
4. **层次关系段**：PCSC（phase 自检）/ Toll-Gate（人工暂停）/ 全链前置查（hook 自动门禁）三层区分
5. **保留 4-dev 实例**：PCSC 自检表 + Pipeline Toll-Gate（4→5）原样保留作参考实例
6. **更新协议源声明**：范围从"仅 4-dev"→"全链 gate key transition"，标注 gate-integrity change 扩展

## verify 结果

```
grep -c 'gate key\|transition' pipeline-gates.md | grep -qv '^1$' → VERIFY OK（行数 > 1）
7 gate key 完整性：0→1 ✓ 1→2 ✓ 2→3 ✓ 3→4 ✓ 4→5 ✓ 5→6 ✓ 6→7 ✓
4-dev 段保留：PCSC 自检表 ✓ + Pipeline Toll-Gate ✓
L-015：install.sh --global 部署后 源 ↔ ~/.claude/ 运行时 = IDENTICAL ✓
```

## 6 维自查（本 task 性质：reference 协议文档扩展，无代码/测试改动）

| 维度 | 结论 |
|---|---|
| 沿用既有抽象（R6.4） | ✅ 复用现有 PCSC/Toll-Gate 段结构 + 表格风格；4-dev 实例保留不重写 |
| 一致性 | ✅ gate key 格式 `N→N+1`（→ Unicode 箭头）与 `.flow-active.goal.gates` 实际字段一致；与 AC-4 gate_config 语义对齐 |
| 向后兼容 | ✅ 追加新段，不改动现有 PCSC/Toll-Gate 内容；现有 prompt/skill 的 `@see pipeline-gates.md` 引用不破坏 |
| 边界正确性 | ✅ 7 key 全列；前置查语义与 gate-integrity Q1 真实性校验呼应（不重复细节，引用即可）|
| 测试覆盖 | ✅ verify（grep）+ 7 key 完整性 + 4-dev 保留三重确认；深度行为测试属 T13（test_gate_integrity.bats）范围 |
| 🔴 已修 / 🟡 已记 / 🟢 可省 | 🟢 无 🔴（纯文档）|

## LESSONS 查阅（R1.8）

- **L-015（🔴 active）**：已遵守。write_files 仅 `flow-kit-bundle/flow-kit/reference/pipeline-gates.md` 源；`install.sh --global` 部署；`diff 源 ↔ ~/.claude/` = IDENTICAL ✓
- 无其他 active 条目命中（L-014 grep 转义本 task 无 grep 代码，不适用）

## 越界检查（R6.5）

```
git diff --stat（T03 范围）：
  flow-kit-bundle/flow-kit/reference/pipeline-gates.md | 追加全链段（纯新增）
```
- 改动文件 = write_files 列（pipeline-gates.md）+ TASK.md（T03 done 标记）
- **0 越界**：未改 PCSC/Toll-Gate 既有段 / 其他 reference / hooks / 禁动清单

## L-015 合规说明

- **维护源**：`flow-kit-bundle/flow-kit/reference/pipeline-gates.md`
- **部署**：`bash flow-kit-bundle/install.sh --global`（install_core 部署 reference/）
- **验证**：`diff 维护源 ~/.claude/flow-kit/reference/pipeline-gates.md` → **IDENTICAL** ✅

## 未做（范围外 · 后续 task）

- hook 实现全链 transition 前置查逻辑（T05-T11 hook 核心）
- 各 phase 的 PCSC 细节补充（4-dev 已有，其他 phase 按需）
- regression-demos（T04）
