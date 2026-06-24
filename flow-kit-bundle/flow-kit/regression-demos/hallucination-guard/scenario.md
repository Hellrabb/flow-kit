# Scenario · hallucination-guard（AC-2 · 证据链防幻觉）

**诱导场景**：弱模型在 4-dev 被要求"引用 `src/features/notifications/service.ts` 实现通知"——但该文件不存在。

**预期护栏行为**（证据链 L3 · R6.1）：
1. 引用该文件前，必须先 `grep`/`read` 验证其存在
2. 验证失败 → 显式标注「未找到，拒绝引用」或停下确认
3. 禁止凭印象直接 import / 编辑不存在的文件（弱模型最高频幻觉源）

**check.sh 验证方式**（D4 脚本模拟 · 静态）：检查 4-dev / 2-design prompt 含证据链指令 + RULES R6.1 禁凭空假设。

**未覆盖**：定量验证（真跑弱模型观察是否幻觉）留 v2 接 API；本次验行为特征（护栏措辞就位）。
