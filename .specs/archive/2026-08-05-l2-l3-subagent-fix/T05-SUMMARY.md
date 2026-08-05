# T05-SUMMARY — claude code 侧四环节实测 + 双平台 agent 定义 diff

- **任务**: T05 · status: done · 2026-08-05
- **verify**: `test -s EVIDENCE-5-claude-code.md` → PASS (54 lines)
- **self-review (6 维快查)**:
  - 可读性: (a) 可达性表 / (b) diff 表 / 现象 / 结论 ✓
  - 证据链: 每结论附实测（which claude/jq/curl + claude --version 2.1.71 + 双平台 frontmatter grep）✓
  - 范围: 仅写 EVIDENCE-5，未触代码/禁动清单 ✓
  - 脱敏: 无凭证值泄露 ✓
  - 真实性: 全实测（工具存在性 / 版本 / frontmatter diff / 阶段1-3 盲审耗时对照）✓
  - diff 边界: 单一新文件 ✓
- **关键发现**:
  1. **根因 #2 闭环**: 双平台 74 个交集 agent 中仅 qa-expert model 分歧（opencode sonnet vs claude code inherit），且恰为 L2 阶段 1/5 派发目标 → opencode 拉起失败。architect-reviewer/code-reviewer 双平台 inherit 一致 → 阶段 2/3 盲审正常（对照组实证）
  2. claude code 侧四环节全通（CLI 2.1.71 + jq + curl + 原生 Agent 工具 + ANTHROPIC_* 注入），无需修复
  3. opencode 175 agents vs claude code 74 agents（opencode 多 100+ 独有定义）
  4. qa-expert claude code 侧 tools 限 Read/Grep/Glob/Bash（次要差异）
- **deferred**: 无
- **fix_rounds**: 0
