# TODO — pipeline-fallback-fix 待办

- **Change ID**: pipeline-fallback-fix
- **创建日期**: 2026-07-03
- **完成日期**: 2026-07-03

---

## UAT 待验证（下次 pipeline 跑时验证）

| # | UAT | 场景 | 依赖 | 状态 |
|---|---|---|---|---|
| UAT-1 | L3 前置端到端 | 设 gate_config, 完成 L2, 执行 transition → L3 同步触发写 .done | `$ANTHROPIC_AUTH_TOKEN` 可用，外部模型 API 可达 | ⬜ |
| UAT-3 | gate_config 快照同步 | 执行 `/flow gate-config` 后 diff 验证 `.flow-active` 与 `.goal-snapshot.json` 一致 | pipeline 模式 + gate_config 修改 | ⬜ |

## 已修复

| # | 发现 | 状态 |
|---|---|---|
| TD-005 | Hook 读 `.phase` 而非 `.goal.current_phase` | ✅ 已修复 |
| TD-006 | bats 测试适配新 l3-review.sh 架构 | ✅ 已修复 (292/292 全绿) |
| TD-007 | Phase 5 .done 旧 session_id | 🟢 低优，不影响功能 |
| TD-008 | Phase 7 .done 空文件 | 🟢 低优，新 Tier1 会拒绝空文件 |

## 修复提交前检查

- [x] `npx bats test/` 全绿 (292/292)
- [x] `~/.claude/hooks/` 运行时副本已同步 (10/10)
- [x] `flow-kit-bundle/` 维护源已提交并推送
- [ ] UAT-1 + UAT-3 手工验证（需真实 pipeline + API 环境）
