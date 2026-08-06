# TASK — L3 审查管线 + Stop Hook 性能修复

- **Change ID**: `l3-pipeline-fix-2026-07`
- **关联**: `@.specs/l3-pipeline-fix-2026-07/REQUIREMENT.md`、`@.specs/l3-pipeline-fix-2026-07/DESIGN.md`

---

## 波次划分

```
Wave 1:     T01                        ← 基础设施（common.sh 合并为单 task，避免同文件写冲突）
Wave 2:     T02 → T03 → T04            ← l3-review.sh 核心修改（同文件，顺序执行）
Wave 3:     T05 → T06                  ← 其他模块（先积压扫描，后探针；29号hook 共享，去 [P]）
Wave 4 [P]: T07, T08, T09             ← 测试 + 基线 + 优化实施（互不冲突）
Wave 5:     T10                        ← 收尾验证
```

---

## Wave 1 — 基础设施

<task id="T01">
  <name>common.sh 新增 fk_estimate_tokens() + fk_perf_timing_start/end() + bats 测试</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    test/test_common.bats
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    test/test_common.bats
  </write_files>
  <action>
    在 common.sh 末尾新增两个基础设施函数组：

    A. fk_estimate_tokens():
    - 签名：fk_estimate_tokens(text, context_window=100000)
    - 算法：${#text} / 4（字符数除以 4 近似 token 数）
    - context_window 可从环境变量 FK_CONTEXT_WINDOW 覆盖，默认 100000

    B. fk_perf_timing_start(label) / fk_perf_timing_end(label):
    - fk_perf_timing_start(label)：记录起始 SECONDS 到全局关联数组 _FK_PERF_TIMINGS
    - fk_perf_timing_end(label)：计算耗时 = SECONDS - start，追加到 _FK_PERF_TIMINGS[label]
    - declare -A _FK_PERF_TIMINGS 在函数外初始化

    bats 测试追加到 test_common.bats：
    - fk_estimate_tokens: 正常文本 / 空文本 / 环境变量覆盖（3 条）
    - fk_perf_timing: start+end 配对 / 未 start 直接 end 应报错（2 条）

    （合并原 T01+T02 为避免 common.sh 同文件并行写冲突）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/common.sh && npx bats test/test_common.bats --filter "fk_estimate_tokens|fk_perf_timing"</verify>
  <done>fk_estimate_tokens() + fk_perf_timing_start/end() 在 common.sh 中可用；bats 5 条测试全部通过</done>
  <depends_on></depends_on>
</task>

---

## Wave 2 — l3-review.sh 核心修改（顺序执行 · 同文件避免冲突）

<task id="T02">
  <name>l3-review.sh D1：git diff 并集策略 + fk_estimate_tokens 集成</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/l3-pipeline-fix-2026-07/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    修改 _l3_build_prompt() phase 6 的 diff 收集逻辑（当前 l3-review.sh:200-206）：
    1. 保留 git diff HEAD（工作区 vs HEAD）
    2. 新增 git diff --cached（index vs HEAD）
    3. 合并两者，按文件路径去重（同名文件取两者中较长的）
    4. 新文件内容截断从 hardcoded 5000 → max_chars / 4
    5. 整体 diff 截断从 head -c "$max_chars" → 调 fk_estimate_tokens()，token ≤ context_window × 60% 则保留全量，否则按比例截断
    6. source common.sh（若尚未 source）以使用 fk_estimate_tokens
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -c 'git diff --cached\|fk_estimate_tokens' flow-kit-bundle/hooks/stop/lib/l3-review.sh</verify>
  <done>git diff 收集使用并集策略（HEAD + --cached）；fk_estimate_tokens() 替代 head -c 硬截断；bash -n 通过</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03">
  <name>l3-review.sh D2+D6：smart_truncate 三遍扫描 + HTTP 状态码降级</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    .specs/l3-pipeline-fix-2026-07/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    D2 — smart_truncate() 增强（当前 l3-review.sh:44-144）：
    1. 保留前两遍扫描（标题 + AC 索引 → 按段填充）
    2. 新增第三遍：从文件末尾向前扫描，匹配尾部锚点关键词（"## 5. 风险"/"## 风险"/"ADR-"/"已锁决策"/"| # | 风险"）
    3. 匹配到的段追加到输出末尾，标注 "[尾部保留: N 段]"
    4. 若零匹配 → fallback 保留最后 max_chars/4 字符，标注 "[尾部保留: 0 段锚点匹配，已回退到通用保留]"

    D6 — _l3_call_api() + _l3_parse_result() 降级增强：
    1. curl 调用添加 -w '\n%{http_code}'（当前 l3-review.sh:254 仅 -s）
    2. _l3_parse_result() 用 tail -1 提取 HTTP 状态码，其余行作为 body
    3. 200 → 正常解析；4xx/5xx → verdict=error，记录状态码
    4. verdict=error 行为同 timeout：不写 .done，记录失败原因
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -c '尾部保留\|tail -1.*http_code\|verdict=error' flow-kit-bundle/hooks/stop/lib/l3-review.sh</verify>
  <done>smart_truncate 含尾部锚点保留 + fallback；curl 捕获 HTTP 状态码（-w）；bash -n 通过</done>
  <depends_on>T02</depends_on>
</task>

<task id="T04">
  <name>l3-review.sh D4：_l3_inject_context() 上下文注入</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    .specs/l3-pipeline-fix-2026-07/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    在 _l3_build_prompt() 的 prompt 构建阶段插入上下文注入逻辑：
    1. 新增 _l3_inject_context(phase, artifacts_dir) → echo context_preamble
    2. 检查 INDEPENDENT-REVIEW-{phase}.md 是否存在
    3. 若存在 → grep 提取：L2 Verdict 行 + L3 Verdict 行 + "## 主 agent 反驳" 段（若有）
    4. 格式化为 preamble（含免责声明）：
       ```
       [前次审查上下文 · 最近一次]
       - L2 Verdict: <pass/fail>（<发现数>）
       - L3 Verdict: <pass/fail>（<摘要>）
       - 主 agent 响应: <反驳/修复摘要>
       [注意：以上为历史审查上下文，本次审查仍应基于工件本身独立判断]
       ```
    5. preamble 注入在 system prompt 和审查内容之间
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -c '_l3_inject_context' flow-kit-bundle/hooks/stop/lib/l3-review.sh</verify>
  <done>_l3_inject_context() 函数存在；preamble 含免责声明；bash -n 通过</done>
  <depends_on>T03</depends_on>
</task>

---

## Wave 3 — 其他模块（先积压扫描，后探针 · 29号hook 共享，非并行）

<task id="T05">
  <name>29-independent-review.sh D3：_l3_scan_backlog() 积压扫描 + perf timing</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/l3-pipeline-fix-2026-07/DESIGN.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    在 fk_independent_review_run() 入口新增积压扫描：
    1. 新增 _l3_scan_backlog(flow_file, cwd) 函数
    2. 读 goal.phases_done[] + goal.gate_config
    3. 对每个 phases_done 中的 phase N ∈ {1,2,3,5,6,7}：
       a. 查 gate_config[phase_name] 是否含 "L3" 或 "both"
       b. 检查 .specs/<id>/.independent-review-{N}.done 是否存在
       c. 缺失 → 加入补跑队列
    4. 限流：取队列前 3 个 phase，按编号升序依次调 l3_review_run()
    5. 超出部分记录 "backlog: N phases deferred" 到 hook 日志

    同时插入 fk_perf_timing_start/end 探针（29 号 hook 独自分发，避免 T06 和本 task 并行写冲突）：
    - 入口：fk_perf_timing_start "29"
    - 出口：fk_perf_timing_end "29"

    ⚠️ 禁动清单异常声明：CONTEXT 行 383 gate 校验核心链。触碰理由：积压扫描必须注入 L3 补跑唯一调度点。触碰范围限定：入口 _l3_scan_backlog() 调用 + perf timing 探针（各 1 行），不修改 L3 派发核心逻辑。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh && grep -c '_l3_scan_backlog\|fk_perf_timing' flow-kit-bundle/hooks/stop/29-independent-review.sh</verify>
  <done>_l3_scan_backlog() 存在；限流 ≤3 phase/次；perf timing 探针；bash -n 通过</done>
  <depends_on>T04</depends_on>
</task>

<task id="T06">
  <name>Stop hook 模块 fk_perf_timing 探针插入（D5 Phase 1 · 不含 29号 + 33号）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/00-gate.sh
    flow-kit-bundle/hooks/stop/01-transcript-parse.sh
    flow-kit-bundle/hooks/stop/21-claude-md.sh
    flow-kit-bundle/hooks/stop/22-git.sh
    flow-kit-bundle/hooks/stop/23-memory.sh
    flow-kit-bundle/hooks/stop/24-session.sh
    flow-kit-bundle/hooks/stop/25-quality.sh
    flow-kit-bundle/hooks/stop/26-workflow.sh
    flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/30-ai-analyze.sh
    flow-kit-bundle/hooks/stop/31-auto-advance.sh
    flow-kit-bundle/hooks/stop/32-fallback-guard.sh
    flow-kit-bundle/hooks/stop/99-report.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/00-gate.sh
    flow-kit-bundle/hooks/stop/01-transcript-parse.sh
    flow-kit-bundle/hooks/stop/21-claude-md.sh
    flow-kit-bundle/hooks/stop/22-git.sh
    flow-kit-bundle/hooks/stop/23-memory.sh
    flow-kit-bundle/hooks/stop/24-session.sh
    flow-kit-bundle/hooks/stop/25-quality.sh
    flow-kit-bundle/hooks/stop/26-workflow.sh
    flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/30-ai-analyze.sh
    flow-kit-bundle/hooks/stop/31-auto-advance.sh
    flow-kit-bundle/hooks/stop/32-fallback-guard.sh
    flow-kit-bundle/hooks/stop/99-report.sh
  </write_files>
  <action>
    在每个 hook 模块的主入口（source lib 之后、主逻辑之前）插入：
    - fk_perf_timing_start "<module-number>"
    在每个模块的末尾（exit 之前）插入：
    - fk_perf_timing_end "<module-number>"
    在 99-report.sh 末尾汇总输出：
    - 遍历 _FK_PERF_TIMINGS 关联数组，输出 "[perf] timings: 00=XXms 01=XXms ... total=XXms"

    排除范围：
    - 29-independent-review.sh：已在 T05 中处理（避免并行写冲突）
    - 33-flow-active-integrity.sh：禁动清单保护（CONTEXT 行 382 完整性检测模块），不触碰

    轻量探针（每模块 +2 行），不改变模块逻辑。
  </action>
  <verify>for f in flow-kit-bundle/hooks/stop/[0-9]*.sh; do bash -n "$f" || echo "FAIL: $f"; done</verify>
  <done>14 个 hook 模块各含 fk_perf_timing_start/end 调用；99-report 输出汇总；禁动清单无越界；全部 bash -n 通过</done>
  <depends_on>T05</depends_on>
</task>

---

## Wave 4 [P] — 测试 + 基线 + 优化实施（互不冲突）

<task id="T07" parallel="true">
  <name>bats 测试：l3-review + 积压扫描 + token 估算 + 降级行为</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    test/
    .specs/l3-pipeline-fix-2026-07/REQUIREMENT.md
  </read_files>
  <write_files>
    test/test_l3_pipeline_fix.bats
    flow-kit-bundle/test/test_l3_pipeline_fix.bats
  </write_files>
  <action>
    新建 test_l3_pipeline_fix.bats，覆盖 AC-1~AC-5 + AC-8 的行为级验证：
    - AC-1: 构造 mock git 仓库（含 staged + unstaged + untracked）→ source l3-review.sh → 调 diff 收集 → 断言输出含三类变更
    - AC-2: 构造 untracked .sh 文件 → 断言内容出现在 diff 中且长度 > 5000（验证 5000 硬限已移除）
    - AC-3: 构造 15K mock REQUIREMENT.md（头含 AC，尾含风险）→ 调 smart_truncate → 断言头含 AC- + 尾含 "风险"
    - AC-4: 构造 .flow-active（phases_done=["1","2"]，gate_config 含 L3，仅 phase1 有 .done）→ 调 _l3_scan_backlog → 断言返回 [2]
    - AC-5: 构造 INDEPENDENT-REVIEW-1.md（含 L2/L3 verdict + 主 agent 反驳）→ 调 _l3_inject_context → 断言 preamble 含 verdict + "独立判断" 免责声明
    - AC-8: mock curl 返回 HTTP 500 → 调 _l3_parse_result → 断言 verdict=error；mock timeout → verdict=timeout

    **双源同步**：写入 test/ 后同步到 flow-kit-bundle/test/
  </action>
  <verify>npx bats test/test_l3_pipeline_fix.bats</verify>
  <done>6 条 bats 测试覆盖 AC-1~AC-5 + AC-8；全部通过；双源同步完成</done>
  <depends_on>T04, T05</depends_on>
</task>

<task id="T08" parallel="true">
  <name>D5 Phase 2：Stop hook 性能基线测量 + 瓶颈报告</name>
  <read_files>
    .specs/l3-pipeline-fix-2026-07/REQUIREMENT.md
    .specs/l3-pipeline-fix-2026-07/DESIGN.md
  </read_files>
  <write_files>
    .specs/l3-pipeline-fix-2026-07/BASELINE.md
  </write_files>
  <action>
    测量 Stop hook 链的性能基线：
    1. 在干净环境运行 Stop hook 链（模拟典型 change 场景）
    2. 收集 99-report.sh 输出的 [perf] timings 行
    3. 重复 3 次取中位数
    4. 识别 Top 3 耗时模块
    5. 写入 BASELINE.md：
       - 各模块耗时分布表（含中位数 + 波动范围）
       - Top 3 瓶颈分析（根因 + 影响量级）
       - ≥1 条可实施的优化建议（含预估收益）
       - 30% 目标可行性评估（是否可通过本次 change 的优化策略达成）
  </action>
  <verify>test -f .specs/l3-pipeline-fix-2026-07/BASELINE.md && grep -c 'ms\|瓶颈\|优化建议\|30%' .specs/l3-pipeline-fix-2026-07/BASELINE.md</verify>
  <done>BASELINE.md 存在；含耗时分布 + Top 3 瓶颈 + ≥1 条优化建议 + 可行性评估</done>
  <depends_on>T06</depends_on>
</task>

<task id="T09" parallel="true">
  <name>D5 Phase 3：实施 Top 1 优化（基于 T08 瓶颈报告选取）</name>
  <read_files>
    .specs/l3-pipeline-fix-2026-07/BASELINE.md
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/l3-pipeline-fix-2026-07/DESIGN.md
  </read_files>
  <write_files>
    （优化目标文件由 T08 瓶颈报告确定，限定在 common.sh / l3-review.sh / 29-independent-review.sh 范围内）
  </write_files>
  <action>
    基于 T08 的瓶颈报告，实施 Top 1 优化：
    1. 从 BASELINE.md 读取 Top 1 瓶颈和优化建议
    2. 按 D5 Phase 3 的三类策略选择实施：
       - 若瓶颈 = L3 API 30s 同步等待 → l3_review_run() 加 --background flag（fire-and-forget，SessionStart 收割）
       - 若瓶颈 = lib source 串行 → 识别可并行 source 的 lib，用 & + wait 并行加载
       - 若瓶颈 = 独立检查模块串行 → 选 27/28/33 中耗时最高的模块后台并行跑
    3. 实施后复测性能（复跑 T08 的测量命令），验证实际收益
    4. 将优化结果追加到 BASELINE.md 的 "## 优化实施记录" 段：
       - 选定的优化策略 + 实际收益（ms / %）+ 对比基线
    5. 若优化后整体降幅 ≥ 30% → AC-6 满足
    6. 若 < 30% 但仍有收益 → 记录为部分达成 + 剩余差距 + 建议 v2 策略
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -c '优化实施记录' .specs/l3-pipeline-fix-2026-07/BASELINE.md</verify>
  <done>Top 1 优化已实施；BASELINE.md 含优化实施记录（策略 + 实际收益 + 对比基线）；bash -n 通过</done>
  <depends_on>T08</depends_on>
</task>

---

## Wave 5 — 收尾验证

<task id="T10">
  <name>全量回归验证 + bundle 源同步（AC-7）</name>
  <read_files>
    flow-kit-bundle/
    test/
  </read_files>
  <write_files>
    （验证任务，仅在发现问题时修改对应源文件）
  </write_files>
  <action>
    1. bash -n：对所有修改过的 .sh 文件做语法检查
       find flow-kit-bundle/hooks -name '*.sh' -print0 | xargs -0 -n1 bash -n
    2. bats 全量回归：npx bats test/
    3. bats exit code 校验：确认 npx bats 返回 0（非管道吞错）
    4. 双源同步检查：diff -r test/ flow-kit-bundle/test/ --exclude='fixtures' --exclude='regression-demos' 确认无差异
    5. bundle 源同步：将修改从 flow-kit-bundle/hooks/ 同步到运行时 ~/.claude/hooks/
       - 确认 auto-checkpoint.sh 运行时版本与 bundle 源一致（已在本 change 早期修复）
  </action>
  <verify>npx bats test/ && echo "BATS_EXIT: $?" && test "$(find flow-kit-bundle/hooks -name '*.sh' -print0 | xargs -0 -n1 bash -n 2>&1 | grep -cv 'error')" -eq 0</verify>
  <done>bats 全量 0 fail，exit code 0；bash -n 全过；双源测试同步；bundle 源与运行时一致</done>
  <depends_on>T07, T08, T09</depends_on>
</task>
