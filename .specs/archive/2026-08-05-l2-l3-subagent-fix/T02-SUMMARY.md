# T02-SUMMARY — opencode 环节②实测：PreToolUse gate 触发链路

- **任务**: T02 · status: done · 2026-08-05
- **verify**: `test -s EVIDENCE-2-opencode-pretooluse-gate.md` → PASS (71 lines)
- **self-review (6 维快查)**:
  - 可读性: 五段结构（步骤/观测/现象/结论/脱敏）✓
  - 证据链: 每结论附文件路径+行号（settings.json PreToolUse 第3条 / types.gen.d.ts L1170-1190 / gate-helpers-types.sh L67-75 / OPENCODE-INSTALL.md L42）✓
  - 范围: 仅写 EVIDENCE-2，未触任何代码/禁动清单 ✓
  - 脱敏: 无凭证涉及，日志仅引 permission 行 ✓
  - 真实性: 全部实测（注册位置/运行时日志/手动模拟/平台 schema）✓
  - diff 边界: 单一新文件 ✓
- **关键发现**:
  1. **根因 #1（结构性）**: gate 注册在 `~/.claude/settings.json`（claude code 专属），opencode 不读；opencode.json 无 opencode-claude-hooks 桥接插件；`.opencode/hooks/` 不存在；opencode 1.18.9 原生仅 file_edited/session_completed 两 hook 事件，无 PreToolUse/Stop → **环节② gate 在 opencode 零触发**
  2. gate 脚本逻辑正确（手动模拟验证：L2-only Write .done 放行 exit 0、gate 未开 Write .done path-guard 拦截 exit 2）
  3. **附加 bug**: `_fk_phase_direction` 正则 `=\s*"\K[0-7]` 遇转义引号 `\"4\"` 失效 → 返回 noop → phase transition 命令双引号写法可绕过 gate（🟡 Major，双平台通用，归 ROOT-CAUSE 风险清单）
- **deferred**: 无
- **fix_rounds**: 0
