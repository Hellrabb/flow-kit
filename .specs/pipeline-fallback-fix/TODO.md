# TODO — pipeline-fallback-fix 待办

- **Change ID**: pipeline-fallback-fix
- **创建日期**: 2026-07-03

---

## UAT 待验证（需真实环境 e2e）

| # | UAT | 场景 | 依赖 | 状态 |
|---|---|---|---|---|
| UAT-1 | L3 前置端到端 | 设 gate_config, 完成 L2, 执行 transition → L3 同步触发写 .done | `$ANTHROPIC_AUTH_TOKEN` 可用，外部模型 API 可达 | ⬜ |
| UAT-3 | gate_config 快照同步 | 执行 `/flow gate-config` 后 diff 验证 `.flow-active` 与 `.goal-snapshot.json` 一致 | pipeline 模式 + gate_config 修改 | ⬜ |

## 已发现但未修复

| # | 发现 | 位置 | 严重度 | 建议 |
|---|---|---|---|---|
| TD-005 | Hook 读 `.phase` 而非 `.goal.current_phase` | `independent-review-gate.sh:131` | 🔴 | **已修复** — 添加 scope 检测，pipeline 模式优先读 `goal.current_phase` |
| TD-006 | bats 测试 78/80 需适配新 l3-review.sh 架构 | `test/` | 🟡 | 29 号脚本重构后，旧测试检查内联 curl 模式需更新为检查 source l3-review.sh |
| TD-007 | Phase 5 `.done` 含旧格式 `session_id=test-session-123`（诊断 session 遗留） | `.specs/pipeline-fallback-fix/.independent-review-5.done` | 🟢 | 清理或忽略（不影响功能，仅 metadata 不准） |
| TD-008 | Phase 7 `.done` 为空文件（0 bytes，诊断 session 遗留） | `.specs/pipeline-fallback-fix/.independent-review-7.done` | 🟢 | 新 Tier1 会拒绝空文件，不影响后续——但建议清理 |

## 修复提交前检查

- [ ] `npx bats test/` 全绿（当前 202/216，14 失败需分析）
- [ ] 确认 `~/.claude/hooks/` 运行时副本已同步
- [ ] 确认 `flow-kit-bundle/` 维护源已提交
- [ ] UAT-1 + UAT-3 手工验证通过