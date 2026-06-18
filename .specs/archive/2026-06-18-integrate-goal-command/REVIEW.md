# REVIEW: 整合 CC /goal 到 flow-kit

- **Change ID**: integrate-goal-command
- **日期**: 2026-06-18
- **判定**: ✅ 通过

## 审查维度

### 1. spec 合规

| AC | 实现 | 验证 |
|---|---|---|
| AC-1 · 设定 goal | flow SKILL.md /flow goal 子命令 | jq 验证 ✅ |
| AC-2 · 查看状态 | flow SKILL.md /flow goal 无参数 | jq 验证 ✅ |
| AC-3 · 清除 goal | flow SKILL.md /flow goal clear | jq 验证 ✅ |
| AC-4 · 内置回退 | 4-dev.md 入场检测 + 迭代逻辑 | prompt 级，人工验证 |
| AC-5 · 自动提取 | 4-dev.md AC 解析 + 建议展示 | prompt 级，人工验证 |
| AC-6 · 路由可见 | GO.md 路由声明模板 + 注入步骤 | grep 验证 ✅ |
| AC-7 · 恢复存活 | flow-kit-resume.sh goal 读取 | grep 验证 ✅ |

### 2. 代码质量

- Schema 一致性：全部 5 个文件使用相同的 goal 字段名和类型 ✅
- jq 语法：所有命令已在 bats test 中验证 ✅
- 边界处理：goal=null / .flow-active 不存在 / 空条件 ✅
- 向后兼容：goal 为可选字段，旧版 .flow-active 不报错 ✅

### 3. 越界检查

✅ 无越界改动

### 4. 测试覆盖

- `test/test_flow_goal.bats`: 7 条测试，全部通过
- 代码引用：GO.md (3) + 4-dev.md (13) + resume.sh (9) ✅

## 问题

无 🔴/🟡 问题。

## 人工验证清单（AC-4/AC-5 prompt 级）

- [ ] 在实际 change 流程中运行 4-dev，验证 goal 自动提取建议
- [ ] 在无原生 /goal 的 CC 环境验证回退循环
