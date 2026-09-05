# Minor Findings Deferred to Phase 7 Triage

> **Triage 结果（2026-09-05 · 用户确认「部分转债务」）**：M1-M3 已被 phase 2-4 实际吸收（见各行标注）；**M12 转技术债**（唯一有真实失真后果的潜在边界——echo -e 对字面转义序列，待 A-evolve 批量同步至 CONTEXT.md 技术债段）；其余（M4-M11, M13-M15）为措辞/加固/可移植性微项，无复发风险证据，**关闭不跟踪**。本文件随 change 归档，作为处置审计记录。

| # | Task | Finding ID | Description | Deferred reason | Date |
|---|------|------------|-------------|-----------------|------|
| M1 | T01 | R4 | REQUIREMENT.md AC-4 When「_l3_inject_context 或其内部提取逻辑」验证目标函数不唯一；唯一验证入口（_l3_build_prompt 端到端 vs _l3_inject_context 单元）由 2-design 定夺 | Minor，不入 fix loop；REQUIREMENT 层保持实现无关是分层正确姿势 | 2026-09-04 | → 已解决：phase 2 裁决验证入口统一走 _l3_build_prompt 端到端
| M2 | T01 | R5 | REQUIREMENT.md AC-3 Then 括号内混入实现诊断细节（dirname ×2 解析缺陷），应移至 DESIGN §0.5 | Minor，不入 fix loop；实现细节归位 DESIGN 属 2-design 工作 | 2026-09-04 | → 已解决：phase 2 DESIGN D5 吸收
| M3 | 4-dev | R4 | INDEPENDENT-REVIEW-2.md L2 R4：phase 6 同构位点 L91-92 的 project_root 归档布局修复 | DESIGN v1.1 D5 已吸收（两处同构位点统一修法），4-dev 实现时验证 | 2026-09-04 | → 已解决：T04 覆盖 phase 6 同构位点

| M4 | T05fix | R3 | test/test_l3_pipeline_fix.bats:2-3 头部注释仍写「l3-pipeline-fix-2026-07 / AC-1~5+8」，未反映本文件现承载两 change 用例 | Minor，不入 fix loop | 2026-09-05 |
| M5 | T05fix | R4 | TEST.md 回归登记表「数量」列混合新增/改写口径（合计 36 ≠ 新增 31 ≠ 总数 39），对账口径不自洽 | Minor，不入 fix loop | 2026-09-05 |
| M6 | T05fix | R5 | TEST.md §1.1 AC-1 行「JSON 契约永不被切」无对应断言（靠 jq 模板指令前置的设计性质保证，无回归锚） | Minor，不入 fix loop | 2026-09-05 |
| M7 | T05fix | L3-1 | TEST.md 回归登记表 36≠39：3 个既有用例（旧 change 未改写部分）未归属任何 T 组（与 M5 同源，L3 补充定位） | Minor，不入 fix loop | 2026-09-05 |
| M8 | T05fix | L3-2 | AC-6 ~/.claude cmp gate 为存在性门控，无全局部署环境平凡通过且无 skip 标记 | Minor，不入 fix loop | 2026-09-05 |
| M9 | T05fix | L3-3 | T05 端到端「组装复刻」存在随实现漂移的影子实现风险，缺与真实 build_prompt 输出的 diff 护栏 | Minor，不入 fix loop | 2026-09-05 |
| M10 | R6 | F1 | lib/l3-prompt.sh:89-166 提取器双文法单函数（78 行，界面窄/全测达标，拆分降载） | Minor，不入 fix loop | 2026-09-05 |
| M12 | R6 | F3 | lib/l3-prompt.sh:354 echo -e 对字面转义序列的低概率失真（改 awk/printf 组装） | Minor，不入 fix loop | 2026-09-05 | → 转技术债：待 A-evolve 同步 CONTEXT.md 技术债段
| M13 | R6 | F4 | l3-prompt.sh 五副本同步结构性负担（已有 AC-6+cmp 门控守护，纪律记录） | Minor，不入 fix loop | 2026-09-05 |
| M14 | T06fix | L2-R2 | REQUIREMENT AC-6 字面「无 fail/skip」与仓库 1 既有 skip（test_lessons_cleanup.bats，--validate 覆盖 gap）的措辞对账（TEST.md §1.3 已按「0 新增 skip」口径披露） | Minor，不入 fix loop | 2026-09-05 |
| M15 | T06fix | L3-3 | T06fix 用例 iconv -o /dev/null 为 GNU 扩展（部分 BSD/macOS 不支持）→ 改 stdout 重向 | Minor，不入 fix loop | 2026-09-05 |
| M16 | T06 | L3 Major-1（实为注入可见性） | LESSONS.md 为尾追加式而 L3 prompt 注入取 head（D1 既有约定），新教训对 L3 不可见——审查误报源头 | A-evolve 候选：注入改 tail 或 newest-first 重构，涉及 hook 语义变更 | 2026-09-05 |
