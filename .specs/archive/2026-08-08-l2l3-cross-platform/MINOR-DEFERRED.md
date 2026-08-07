# Minor Findings Deferred to Phase 7 Triage

| # | Task | Finding ID | Description | Deferred reason | Date |
|---|------|------------|-------------|-----------------|------|
| M1 | Phase 1 | R7 | REQUIREMENT.md AC-5 原含未解析占位符 `<file>` + 「或等价目录」hedge，破坏 AC 确定性 | Minor，文本级——已在 REQUIREMENT 修订中直接落地（具体文件名 `flow-kit-l2-reviewer.md` + 删除 hedge），此处登记留痕 | 2026-08-06 |
| M2 | Phase 1 | R8 | REQUIREMENT.md AC-9 硬/软条件未拆，TEST 阶段通过判定口径不一 | Minor，文本级——已在 REQUIREMENT 修订中拆 AC-9a（硬）/ AC-9b（软），此处登记留痕 | 2026-08-06 |
| M3 | Phase 2 | R8 | l2-detect.sh L170-174 陈旧注释（「opencode 下 PreToolUse 结构性不触发」已被 oh-my-opencode 4.19.4+ 桥接证伪） | Minor，实现级——D2 编辑该区域时（l2-detect.sh L170-184 平台分支统一）顺带更新注释为 4.19.4+ 桥接行为描述，与 CONTEXT 一致 | 2026-08-06 |
| M4 | Phase 2 | R9 | l3-api.sh L19-21 / l2-detect.sh L126-127 env 文档头未列 FLOW_KIT_L3_BASE_URL/AUTH_TOKEN | Minor，实现级——D1 实现时同步更新两处文件头 env 注释 | 2026-08-06 |
| M5 | Phase 2 | R11 | DESIGN.md §2 架构图最初写 install_core.sh 为安装点（无平台分支），与 D6（install_hooks.sh 复用 PLATFORM/resolve_paths）不一致 | Minor，文本级——已改图与 D6 一致（install_hooks.sh），此处登记留痕 | 2026-08-06 |
| M6 | Phase 2 | R12 | DESIGN.md §3 rc=1 行误写「写 model-missing correction」，实际凭证缺失不写该 correction（仅模型解析空触发，既有逻辑不变）| Minor，文本级——已澄清语义并标注 R12，此处登记留痕 | 2026-08-06 |
| M7 | Phase 2 | R13 | 共享函数初名 fk_resolve_l3_credentials 被 L2 复用（L2 自动派发也要凭证）→ 命名表示层归属不准确 | Minor，命名级——已改名 `fk_resolve_api_credentials()`（输出 FK_API_BASE_URL/FK_API_AUTH_TOKEN），DESIGN.md/REQUIREMENT.md/ADR-023 全同步，此处登记留痕 | 2026-08-06 |
| M8 | Phase 3 | R6 | T02 verify `grep -c "ANTHROPIC_AUTH_TOKEN"` 与文件头注释同步要求自相矛盾（保证性失败） | Minor，verify 文本级——已直接修（排除注释行后断言零直读，注释保留为准确文档），此处登记留痕 | 2026-08-06 |
| M9 | Phase 3 | R7 | l2-detect.sh 注释锚点 L10（模板注释）+ L126-127（env 文档头）未纳入 T03 同步 | Minor，实现级——T03 action 已补两处注释同步，4-dev 执行时落实 | 2026-08-06 |
| M10 | Phase 3 | R8 | AC-6 红线断言（bats→shell grep 偏差）不在任何 verify 元素内，执行全靠 dev 自觉 | Minor，verify 文本级——两条 grep 已移入 T12 verify 元素（机器强制），此处登记留痕 | 2026-08-06 |
| M11 | Phase 3 | R9 | prompt 双模式用注释行实现，弱模型可能忽略（protect the weakest 弱化） | Minor，设计取舍——注释行是 D4 最小 diff 方案（box 并列双行改动 CC 既有模板与结构断言基线）；结构断言（category= 子串）兜底；并列正文行增强列 v2 候选 | 2026-08-06 |
| M12 | Phase 5 | G1 | l3-api.sh:46-48 用 `ANTHROPIC_AUTH_""TOKEN` 拆串规避 T02 verify 零直读 grep——verify 沦为可被字符串拼接骗过的形式检查 | Minor，测试硬化——v2 改 verify 为精准模式（仅对 `\$ANTHROPIC_` 展开读取断言）并删 hack | 2026-08-07 |
| M13 | Phase 5 | G2 | l3-api.sh:89-92 source 标签重读 env，违反 common.sh:271「调用方读全局不重读 env」契约；Path1 生效且 base_url 恰好相同时可误标 flow-kit | Minor，实现级——v2 建议共享函数导出 `FK_API_SOURCE` 第 4 全局 | 2026-08-07 |
| M14 | Phase 5 | G3 | flow-kit-resume.sh L139/L141 新增两行宽 76 vs 边框 67 错位（T06 引入，超出 9 列） | Minor，展示级——v2 对齐边框（52 字符内容区） | 2026-08-07 |
| M15 | Phase 5 | G4 | l2-detect.sh box 既有行宽 43~72 vs 边框 60 不齐（本次新增行 110-113 已对齐；T03 done「box 宽度对齐」声明不成立，属旧账展示问题） | Minor，展示级——v2 全 box 行宽统一 | 2026-08-07 |
| M16 | Phase 6 | R6-2 | l3-review.sh box 双模式两行并存（subagent_type + category 同时列出），用户复制提示时可能两行都保留 | Minor，展示级——注释已引导按平台选择一行；v2 候选：l3_dispatch_prompt 按 fk_platform_is_opencode 条件渲染单行（box 宽度已有对齐基础） | 2026-08-07 |
| M17 | Phase 6 · T-FIX-01 | R5 | TD-012 类打包源路径 bug 复发防护：新增/修改 bats 测试时路径必须用向上查找 BATS_ROOT 模式（对齐 test_fk_resolve_model.bats） | Minor——v2 候选：test-setup-path-fix 类专项（统一所有测试 setup） | 2026-08-07 |
| M18 | Phase 6 · L2 盲审 | R2 | transcript-parser `.tool == "Agent"` 过滤 vs opencode 实际工具名（task）——category 分支在 opencode transcript 可能永不命中 | Minor，观测级——不影响 CC 路径与审查执行；v2 候选：确认真实形状后扩过滤 + 补真实形状回归用例 | 2026-08-07 |
| M19 | 2026-08-07 | F-A | ✅ 已由 delta 解决（AC-6 bats 断言 2 条已实现，2026-08-08）：固化为 bats 断言进 CI | 2026-08-07 |
| M20 | Phase 2 · L2 盲审 | R-G1 | L-031 锚点行号漂移：6-review.md:302→303、l3-review.sh:212→215、l2-detect.sh:98→110（文件级覆盖完整，仅行号滞后） | Minor——下次实施时 grep 锚点更新行号 | 2026-08-08 |
| M21 | Phase 3 · L2 盲审 | R4 | T02-rev CC 分支归类序（`.args.category //` 优先）与 AC-4b 文字「按 subagent_type」不一致 | Minor——行为等价（CC Agent args 无 category），既有测试已钉；v2 对齐措辞 | 2026-08-08 |
| M22 | Phase 3 · L2 盲审 | R5 | TASK「17+7 用例」实测 17+12 | Minor——数值陈旧，不影响执行 | 2026-08-08 |
| M23 | Phase 3 · L2 盲审 | R6 | T01-rev read_files 未列 l3-api.sh/l2-detect.sh 两调用方 | Minor——变更封闭在函数内无漏改风险；L-031 强化建议 | 2026-08-08 |
