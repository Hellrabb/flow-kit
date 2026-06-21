# CHANGE: PCSC/PG 双层防护全面审计

- **Change ID**: pcsc-audit-v2
- **创建日期**: 2026-06-22
- **路径建议**: 完整（0→7 全流程审计）
- **状态**: active

---

## Why（为什么做）

上一轮 `phase-skip-fix` 引入了双层防护（PCSC + PCG），但可能仍有遗漏。本轮按完整流程 0→7 重新审计，覆盖四个方面：

- **A) prompt 指令逻辑漏洞**：PCSC 是否真的不可跳过？auto_advance 分支是否在所有阶段正确？阻断规则是否有一致的措辞？
- **B) PCSC 检查项覆盖**：对照每个 prompt 的完整步骤清单，逐项核对 PCSC 表格是否有遗漏
- **C) GO.md PCG 路由盲区**：PCG 是否覆盖所有 transition 场景？回退路径是否会产生误拦截？
- **D) 安装脚本影响**：`flow-kit-bundle/lib/` 下的同步逻辑是否需要更新

## What（做什么）

1. 逐文件深度审计 7 个 prompt + GO.md + test 文件
2. 对照原始 prompt 的每个步骤/子步骤，验证 PCSC 表完整性
3. 追踪所有 auto_advance 分支逻辑一致性
4. 检查 install 脚本是否受影响的函数
5. 产出审计报告（REVIEW.md），列出所有发现（按严重度分级）

## 影响面

- [ ] 影响 `REQUIREMENT.md`（否——审计不引入新需求）
- [ ] 影响 `DESIGN.md`（否——基于已有设计审计）
- [ ] 仅修复 bug，无范围变化（是——审计 = 发现 bug，不是新功能）

## 范围排除（这次不做）

- 不直接修复发现的问题——先列报告，人工确认后再修
- 不引入新的防护机制（如第三层 hook 防线）
- 不改变 `.flow-active` JSON schema

## 验收线

- 审计报告覆盖全部 4 个维度（A/B/C/D）
- 每个发现标注严重度（🔴 Critical / 🟡 Major / 🟢 Minor）
- 报告后用户确认修复优先级

## 风险与未知

- 审计耗时可能较长（需深读 8+ 文件），但 token 可控（均为已有文件，不需生成大量新内容）
