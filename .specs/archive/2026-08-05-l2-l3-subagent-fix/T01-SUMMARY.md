# T01-SUMMARY — opencode 环节①实测：l2-detect.sh 派发生成

- **任务**: T01 · status: done · 2026-08-05
- **verify**: `test -s EVIDENCE-1-opencode-dispatch.md` → PASS (47 lines)
- **self-review (6 维快查)**:
  - 可读性: 五段结构（步骤/观测/现象/结论/脱敏）✓
  - 证据链: 每个结论附 l2-detect.sh 行号（L61-116 / L128-303 / L169-174 / L217-222）✓
  - 范围: 仅写 EVIDENCE-1，未触任何代码/禁动清单 ✓
  - 脱敏: env var 仅变量名+set/unset，值 ***（AC-2）✓
  - 真实性: 全部实测（模板生成/凭证检查/mock 写入），无推测 ✓
  - diff 边界: 单一新文件，git diff --stat 无禁动模块 ✓
- **关键发现**:
  1. l2_dispatch_prompt（环节①模板）不依赖运行时，opencode 下正常可用
  2. l2_dispatch_agent 真实路径凭证检查先行，ANTHROPIC_* env unset → return 1；curl 直连 anthropic.com 绕开 opencode provider 层（现象 B 命中）
  3. mock 路径（FLOW_KIT_L2_MOCK=1）正常，作测试基建
- **deferred**: 无
- **fix_rounds**: 0
