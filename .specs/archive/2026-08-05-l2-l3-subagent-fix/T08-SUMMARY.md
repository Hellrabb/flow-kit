# T08-SUMMARY — 基线回归（AC-5）

- **任务**: T08 · status: done · 2026-08-05
- **verify**: `[ "$(npx bats test/ 2>&1 | grep -c '^not ok')" = "0" ]` → **PASS**（692 ok / 0 not ok）
- **self-review (6 维快查)**:
  - 可读性: 基线命令 + 结果 + 归因说明 ✓
  - 证据链: 完整命令输出（ok 692 行 / not ok 0 行）✓
  - 范围: 仅补 DEV-SUMMARY 基线段 + 本 SUMMARY，未触代码 ✓
  - 脱敏: 无凭证 ✓
  - 真实性: 真实 npx bats 全量执行（非 mock）✓
  - diff 边界: 无新增代码改动 ✓
- **关键产出**: 基线 692 ok / 0 not ok；修复①②③ 后 0 新增 fail；
  AC-5 基准 662/662（STATE.md 记录）→ 当前 692 全绿，优于基准
- **deferred**: 无
- **fix_rounds**: 0
