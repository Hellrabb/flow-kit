# Minor Findings Deferred to Phase 7 Triage

> 来自各阶段 L2 审查的 🟢 Minor findings，按 ADR-017 severity gating 协议延后到此。
> Phase 7-integration 时由用户决定 triage 路径。

---

| ID | Phase | Source | Task/Finding | Description | Recommended action |
|---|---|---|---|---|---|
| M1 | 1 | INDEPENDENT-REVIEW-1 R7 | AC-A3 "如可用"弱化 | macOS conditional skip ≠ pass，AC 措辞"如可用"使 macOS 不可用时自动退化为 Linux-only | 拆为 AC-A3a (Linux 硬) + AC-A3b (macOS 软)；下次 prompt 规则变更时重构 |
| M2 | 1 | INDEPENDENT-REVIEW-1 R8 | 多条 AC 含"人工"验证 | AC-B1/B2/D2/F2/G1/G2 验证方式含"人工 + grep"——降低自动化置信度 | 将 grep 部分独立为 bats 测试；下次测试基础设施完善时处理 |
| M3 | 1 | INDEPENDENT-REVIEW-1 R9 | 范围决策嵌入 REQUIREMENT | Token 测量协议 / spot-check 语义 / task_progress vs SUMMARY 等设计决策嵌入 REQUIREMENT 正文（属 DESIGN 层） | 移到 CHANGE.md 验收线段或独立 DESIGN-NOTES.md；下次 REQUIREMENT 重构时处理 |
| M4 | 2 | INDEPENDENT-REVIEW-2 R5 | ADR-016 探测脚本 JSON 路径未验证 | detect_opencode_tier_support 缓存路径 `.specs/<id>/.opencode-capability.json` 来自未验证假设 | phase 7 实测时确认路径或改为临时文件 |
| M5 | 2 | INDEPENDENT-REVIEW-2 R6 | task_progress lifecycle 图细节 | 图未展示 skip 任务时 task-brief 是否仍需提取 | 完善 DESIGN.md 图注释 |
| M6 | 2 | INDEPENDENT-REVIEW-2 R7 | D5/D6 弱模型缓解引用 ADR-001 | terse contract + narration constraint 在弱模型场景的退化问题引用 ADR-001 gate（不直接适配输出风格约束） | 弱模型场景实测后补 ADR |
| M7 | 5 | INDEPENDENT-REVIEW-5 R8 | 安全注入测试缺失 | TEST.md 安全段仅代码结构描述，无注入测试 | 加 edge case bats（special chars in commit messages / path traversal attempt） |
| M8 | 5 | INDEPENDENT-REVIEW-5 R9 | 集成测试无自动化 | 3 个集成测试场景全部手动验证 | 加 smoke test bats (test_integration_smoke.bats) |
| M9 | 6 | INDEPENDENT-REVIEW-6 R4 | AC-B4 测试深度 | 仅测 task-brief 输出，未测 4-dev.md + task-brief 合并指标 | 见 INTEGRATION.md AC-B4 澄清 |

---

## Triage 决策（phase 7-integration）

**全部 9 个 Minor findings 转技术债登记到 `.specs/LESSONS.md`**：
- 不在本次 change 内修复（sev gating 契约允许延后）
- 登记为 L-058 ~ L-066（继续编号）
- 各自分配到独立的 future change 处理（或在相关 change 实施时一并修）
