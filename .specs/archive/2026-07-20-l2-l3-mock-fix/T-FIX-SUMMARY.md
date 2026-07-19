# T-FIX-SUMMARY — 6-review L2 R1/R2 修复

- **Tasks**: T-FIX-01（R1 🔴 AC-H(e)）+ T-FIX-02（R2 🟡 fail-close）
- **Change**: l2-l3-mock-fix
- **触发**: 6-review L2 verdict=fail（实测确认 R1/R2 真实，主 agent 漏判）
- **状态**: ✅ T-FIX 测 20/20 + 全套 541/0 + 部署同步

## R1（T-FIX-01）· AC-H(e) 重定向/多行 git commit 漏拦
- **根因**：`_command_has_write_context` 把「重定向(>)/多行(\n)」当写上下文 → `git commit 2>log` 漏拦（AC-H(e) 要求 deny）
- **修复**：收紧——**只 heredoc(<<) → 写上下文**；重定向/多行 → 走 token 判定（git commit deny）
- **效果**：`git commit 2>log` / 多行 git commit → deny ✓；heredoc 写报告 → 不 deny ✓
- **已知限制**：`git commit -F - <<EOF`（heredoc message 真实 commit）→ 不 deny（罕见，v2 加密签名），e7 锁定
- **测试**：e4(2>log)/e5(>out)/e6(多行) deny + e7(heredoc msg) not deny

## R2（T-FIX-02）· source COMMON_LIB fail-open
- **根因**：gate.sh:27 `source || true` + :447 `local phase_name="$(fk_phase_gate_key...)"`（local 屏蔽 set -e 得空）→ gate fail-open exit 0
- **修复**：source 后 `declare -f fk_phase_gate_key` 检查，未定义 → exit 2 fail-close + stderr 告警
- **效果**：HOOK_BASE_DIR 错 → exit 2（fail-close）✓；正常路径 deny 不变 ✓

## verify
| 检查 | 结果 |
|---|---|
| T-FIX 测（e4-e7 + R2 + 既有 a-f/NFR-3） | ✅ 20/20 |
| 全套 bats | ✅ 541 ok / 0 fail / exit=0（+5 新测）|
| 部署同步 | ✅ gate.sh cp ~/.claude/hooks/（md5 46d992bf）|
| 实测 R1 git commit 2>log deny / R2 fail-close exit2 / heredoc 不 deny | ✅ |

## 越界
- ✅ gate.sh `_command_has_write_context` + source（T-FIX write_files 内）
- ✅ test-is-git-commit-structural.bats e4-e7 + R2（T-FIX write_files 内）
- ✅ 未改其他 hook / REQUIREMENT（AC-H(e) 既有要求，实现补齐非降级）

## 下一步
重审 6-review（REVIEW.md R1/R2 标 Fixed + L2/L3 复核）→ toll-gate 6→7。
