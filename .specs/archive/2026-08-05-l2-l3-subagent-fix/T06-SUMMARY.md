# T06-SUMMARY — ROOT-CAUSE.md 五段合成

- **任务**: T06 · status: done · 2026-08-05
- **verify**: 五段 grep ≥5 (found 5) && 锚点 grep ≥4 (found 7) → **PASS**
- **self-review (6 维快查)**:
  - 可读性: 五段标准结构（现象矩阵/根因链/双平台差异矩阵/风险分级修复方案/受影响模块清单）✓
  - 证据链: 每根因附 EVIDENCE-N 引用 + 机制 + 影响；根因 #2/#3 附文件行号（l2-detect.sh L61-116 / l3-api.sh L20-21,69-89 / common.sh L249-264 / gate-helpers-types.sh L67-75）✓
  - 范围: 仅写 ROOT-CAUSE.md（T06 write_files），未触代码/禁动清单 ✓
  - 脱敏: 无凭证值 ✓
  - 真实性: 全部基于 EVIDENCE-1..5 实测合成（qa-expert 超时 / gate 零触发 / env 缺失 / 双平台 diff 表）✓
  - diff 边界: 单一新文件 ✓
- **关键产出**:
  - 3 根因 + 1 附加 bug：R#1 gate 注册/触发链路 opencode 结构性断裂（P4）；R#2 qa-expert model: sonnet 不可解析 → 阶段 1/5 L2 盲审挂起（P1，拉起失败直接原因）；R#3 L3 API env-var-first 与 opencode provider 认证不兼容（P2/P3）；附加 _fk_phase_direction 转义绕过 gate（P5）
  - 双平台差异矩阵 6 维度（hook 事件/gate 注册/agent 模型声明/认证方式/派发语法/L2L3 审查）
  - 5 修复方案分级：D5-① /flow model 配置（low·v1）、D5-② qa-expert sonnet→inherit（low·v1）、D5-③ gate 桥接插件（high·v2）、D5-④ L3 API 平台适配（high·v2）、D5-⑤ _fk_phase_direction 转义修复（high·v2）
  - 受影响模块 8 项（含禁动清单标注）
- **deferred**: 无
- **fix_rounds**: 0
