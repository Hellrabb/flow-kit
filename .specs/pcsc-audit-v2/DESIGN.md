# DESIGN: PCSC/PG 双层防护全面审计

- **Change ID**: pcsc-audit-v2
- **关联**: `@.specs/pcsc-audit-v2/REQUIREMENT.md`

---

## 0. 技术栈选定

审计纯读操作，不涉及技术栈变更。沿用既有 Bash + jq + bats 栈。

## 0.5 既有架构对齐

### 触碰模块

```
审计范围（只读）：
- flow-kit-bundle/flow-kit/prompts/{1-requirement,2-design,3-task,4-dev,5-test,6-review,7-integration}.md
- flow-kit-bundle/flow-kit/GO.md
- flow-kit-bundle/test/test_phase_gate.bats
- flow-kit-bundle/lib/install_core.sh
- flow-kit-bundle/lib/install_hooks.sh
- ~/.claude/flow-kit/prompts/*.md（运行时副本）
- ~/.claude/flow-kit/GO.md（运行时副本）

产出文件：
- .specs/pcsc-audit-v2/REVIEW.md

禁动（本次不改）：
- 以上所有源文件均为只读，审计期间禁止修改
```

## 1. 决策清单

| # | 决策 | 理由 |
|---|---|---|
| D1 | 审计四维度 A/B/C/D 并行执行 | 维度间独立，可一次读文件同时检查 |
| D2 | 发现按严重度三级分类 | 🔴=可被利用跳阶段 / 🟡=遗漏但不易触发 / 🟢=风格不一致 |
| D3 | 不直接修复 | 用户明确要求先列报告 |

## 5. 风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 审计者自身遗漏 | 四维度交叉覆盖，A 维度的逻辑审查可发现 B 维度的覆盖遗漏 |
| R2 | 审计范围过大 | 聚焦 7 prompt + GO.md，不扩展到其他 flow-kit 组件 |
