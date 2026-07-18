# TASK: L2/L3 独立审查 gate 残留缺陷根治（F/H/I/J + K）

- **Change ID**: l2-l3-mock-fix
- **关联**: `@.specs/l2-l3-mock-fix/REQUIREMENT.md`、`@.specs/l2-l3-mock-fix/DESIGN.md`、`@.specs/adr/007-011-*.md`
- **修订**：回应 L2 盲审 R1（🔴 regex）+ R2-R8（🟡）+ R9-R11（🟢），见 INDEPENDENT-REVIEW-3.md 主 agent 回应

---

## 波次划分

```
Wave 1:            T01 (D1·F pure fn · 基础)
Wave 2 (parallel): T02 (D2·H) [P], T03 (D3·I L2-first 双管) [P],
                   T04 (D4·J 内容标记) [P], T05 (D5·K pipeline 不 advance) [P]
Wave 3:            T06 (AC-T 全套 bats) → T07 (NFR-1 性能) → T08 (NFR-2 兼容)
```

> Wave 1 先行（gate.sh/common.sh/29 消费者重构）。Wave 2 四任务不同文件并行。Wave 3 **串行**：T06 跑全套 → T07 实测性能写 DESIGN → T08 实测兼容写 DESIGN（T07/T08 共写 DESIGN.md，**不可并行**，回应 L2-R5）。
> NFR-3（stderr 三要素）并入 T01-T05 集成测试（bats 内断言 deny stderr 含 phase + .done 路径 + 阻断原因三要素，回应 L2-R2）。

---

## 任务清单

```xml
<task id="T01" parallel="false" status="done">
  <name>D1·F — PHASE_GATE_KEY_MAP 抽 pure fn 单一来源 + 删重复 declare</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    .specs/l2-l3-mock-fix/DESIGN.md
    .specs/adr/007-phase-gate-key-pure-fn.md
    test/test-phase-gate-key-pure-fn.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    test/test-phase-gate-key-pure-fn.bats
  </write_files>
  <action>
    common.sh 新增 pure fn `fk_phase_gate_key <phase>`（内部 case，非 declare -A）；5 执行消费者改引用——**注意 29:77 用 `$pn` 变量、117/155 + gate.sh:395/413 用 `$phase`，逐个核对变量名勿一刀切**（回应 L2-R9）；删 common.sh:255 + gate.sh:25 两处 declare -A + common.sh:254 注释更新。禁改 7 Gate 控制流。集成测试断言受影响 deny 场景 stderr 三要素（NFR-3，回应 L2 复审 R5'）。
  </action>
  <verify>
    npx bats test/test-phase-gate-key-pure-fn.bats && npx bats test/test_l2_pretooluse_dispatch.bats -f 'INT-7'; grep -rn 'declare -A PHASE_GATE_KEY_MAP' flow-kit-bundle/hooks/ | grep -v '/test/' | wc -l | grep -q '^0$'
  </verify>
  <done>AC-F：pure fn 单测逐 key=附录 oracle + **INT-7 forward transition deny 回归**（回应 L2-R8）+ grep declare -A == 0（NFR-4）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>D2·H — is_git_commit/is_gh_pr_create 改结构判定</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    .specs/l2-l3-mock-fix/DESIGN.md
    .specs/adr/008-is-git-commit-quoting-aware.md
    test/test-is-git-commit-structural.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    test/test-is-git-commit-structural.bats
  </write_files>
  <action>
    抽 helper `_command_has_write_context` + `_command_first_tokens`；改 is_git_commit/is_gh_pr_create 结构判定（含 heredoc/多行/写重定向 → 不 deny；否则子命令前两 token 序列 token0=git ∧ token1=commit → deny）。**不改 deny_reason 标签**（verify 已豁免 `deny_reason=` 行，改名削弱可读性，回应 L2-R11 反驳）。集成测试断言 deny stderr 三要素（NFR-3）。
  </action>
  <verify>
    npx bats test/test-is-git-commit-structural.bats
  </verify>
  <done>AC-H：等价类 (a)(b)(c) 不 deny / (d)(e) deny 全通过 + 反规避 grep (f) 空 + deny stderr 含三要素（NFR-3）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>D3·I — L2-first 顺序契约文档化 + 双管（correction 兜底 + deny reason）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    .specs/CONTEXT.md
    .specs/l2-l3-mock-fix/DESIGN.md
    .specs/adr/009-l2-first-ordering-contract.md
    test/test-l2-first-correction.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    .specs/CONTEXT.md
    test/test-l2-first-correction.bats
  </write_files>
  <action>
    (a) **29 两处 D4 门都补**（回应 L2-R4）：:136 主门 + :174-176 fallback 门（l2-detect.sh 不可加载时的 canonical 路径，BUG-I 跨环境最常命中）——提示含"主 agent 请派 L2 子 agent 并写入 ## L2 盲审 段"指引 + deny reason；(b) D4 退出写 `.flow-active.correction`（type=l2-missing）+ 日志；(c) ## L2 盲审 段检测——29:166/174 已是前缀匹配（L2-R10 核实），本任务仅显式化注释，不改 regex。CONTEXT.md 追加 L2-first 契约术语（**已声明 write**，回应 L2-R6）。集成测试断言 D4 deny 场景 stderr 三要素（NFR-3，回应 L2 复审 R5'）。
  </action>
  <verify>
    npx bats test/test-l2-first-correction.bats
  </verify>
  <done>AC-I：构造 gate_config=both + 无 L2 段跑 29，**两处 D4 门**提示含派发指引 + correction flag + 日志</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="true" status="done">
  <name>D4·J — _l3_check_rerun 改 ## L3 段内容标记 + artifact hash</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    .specs/l2-l3-mock-fix/DESIGN.md
    .specs/adr/010-l3-check-rerun-content-marker.md
    test/test-l3-check-rerun-content-marker.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    test/test-l3-check-rerun-content-marker.bats
  </write_files>
  <action>
    改 _l3_check_rerun（l3-review.sh:386）：判定 = `## L3` 段 regex **`^## L3 (盲审|重审)`**（**前缀匹配真实 token，去 `$` 锚**——与 l3-review.sh:461/529 自身判定一致；回应 L2-R1 🔴：原 `(盲审|外部模型审查)$` 零匹配真实标题 `## L3 重审（模型 · 时间）`）+ artifact hash（INDEPENDENT-REVIEW-N.md 末尾 `L3_artifact_hash: <sha>` 元数据行）。**hash 写入由 l3_review_run 审后追加元数据行**（非 _l3_call_api 逻辑——DESIGN 0.5.1 禁动措辞已放宽为"l3_review_run 的 _l3_call_api 不改；hash 元数据写入允许"，回应 L2-R7）。判定优先级：hash 变→重审 / 段空→重审 / 否则 skip；hash 提取失败→重审+警告；删 case + artifact_mtime 死代码（~22 行）。
  </action>
  <verify>
    npx bats test/test-l3-check-rerun-content-marker.bats && printf '## L3 重审（test · 2026）\n## L3 盲审（timeout · 2026）\n' | grep -qE '^## L3 (盲审|重审)'
  </verify>
  <done>AC-J：regex `^## L3 (盲审|重审)` 匹配真实段（printf fixture）+ touch（hash 不变）不重审 + 内容改（hash 变）重审 + ## L3 段空重审 + hash 行缺失/提取失败重审（含 timeout 段）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T05" parallel="true" status="done">
  <name>D5·K — 26-workflow.sh G1 pipeline goal 模式不 auto-advance</name>
  <read_files>
    flow-kit-bundle/hooks/stop/26-workflow.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    .specs/l2-l3-mock-fix/DESIGN.md
    .specs/adr/011-pipeline-goal-no-g1-autoadvance.md
    test/test-pipeline-no-g1-autoadvance.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/26-workflow.sh
    test/test-pipeline-no-g1-autoadvance.bats
  </write_files>
  <action>
    26-workflow.sh G1（:87 next_phase 分支）加 `goal.scope=pipeline` 守卫：pipeline 模式不调 fk_auto_phase 写 .phase；单阶段保留 auto-advance。fk_auto_phase 函数不改。集成测试断言 deny stderr 三要素（NFR-3）。
  </action>
  <verify>
    npx bats test/test-pipeline-no-g1-autoadvance.bats
  </verify>
  <done>AC-K：pipeline goal + phase 1 + REQUIREMENT，跑 26-workflow，.phase 不 advance；单阶段仍 auto-advance</done>
  <depends_on>T01</depends_on>
</task>

<task id="T06" parallel="false" status="done">
  <name>AC-T — 全套 bats 真绿（基线不破坏 + 新增）</name>
  <read_files>
    test/
  </read_files>
  <write_files>
    <!-- T06 仅验证（跑 bats），不写代码；发现的回归修复由 review/integration 的 T-FIX 处理 -->
  </write_files>
  <action>
    跑全套 bats，确认基线不破坏 + T01-T05 新增全过。**禁 `bats|tail`/`; echo EXIT`** 等吞 exit code 陷阱（LESSONS L-027，回应 L2-R3）。
  </action>
  <verify>
    npx bats test/
  </verify>
  <done>AC-T：全套真绿（exit=0，0 fail 0 BW01）——verify 命令本身可失败（无 `;echo` 兜底）</done>
  <depends_on>T01,T02,T03,T04,T05</depends_on>
</task>

<task id="T07" parallel="false" status="pending">
  <name>NFR-1 — gate hook 性能实测 + 填阈值</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    .specs/l2-l3-mock-fix/DESIGN.md
  </read_files>
  <write_files>
    .specs/l2-l3-mock-fix/DESIGN.md
  </write_files>
  <action>
    实测重构前后 `bash independent-review-gate.sh`（固定 payload）wall time（time ×3 取中位数），填 DESIGN NFR-1 具体阈值。>30% 回归 → 优化。
  </action>
  <verify>
    grep -qE '重构前|重构后' .specs/l2-l3-mock-fix/DESIGN.md && grep -qE '[0-9]+\s*ms|<\s*[0-9]+%' .specs/l2-l3-mock-fix/DESIGN.md
  </verify>
  <done>NFR-1：DESIGN 填具体 ms/%（重构前后 wall time 差 < 阈值）</done>
  <depends_on>T06</depends_on>
</task>

<task id="T08" parallel="false" status="pending">
  <name>NFR-2 — bash 兼容性实测（4.4+ / 5.x）</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/l2-l3-mock-fix/DESIGN.md
  </read_files>
  <write_files>
    .specs/l2-l3-mock-fix/DESIGN.md
  </write_files>
  <action>
    bash 4.4 + 5.x 两档实跑 gate.sh + common.sh（pure fn case 不提版本）。macOS bash 3.2 不在矩阵。
  </action>
  <verify>
    bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && bash -n flow-kit-bundle/hooks/stop/lib/common.sh && bash --version | grep -qE 'version (4\.[4-9]|[5-9]\.)'
  </verify>
  <done>NFR-2：bash 4.4+ 兼容（pure fn 不提版本）+ 语法检查通过</done>
  <depends_on>T07</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` / `in_progress` / `done` / `blocked`

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
