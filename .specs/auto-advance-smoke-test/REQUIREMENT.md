# REQUIREMENT: auto_advance 冒烟测试

- **Change ID**: auto-advance-smoke-test

## 验收准则

### AC-1 · auto_advance 自动推进

- **Given** `.flow-active.goal.auto_advance = true`，pipeline scope，from=4
- **When** Phase 4 PCSC 全部 ✅
- **Then** pipeline 自动 transition 到 phase 5，不输出 toll-gate 交互提示
- **验证方式**: 检查 transcript 无 "是否进入 Phase 5" 交互文本 + jq 确认 current_phase="5"

## 范围切分
- v1: 观察 auto_advance 行为
- v2: 无
- out: 无
