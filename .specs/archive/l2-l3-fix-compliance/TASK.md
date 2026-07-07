# TASK: L2/L3 review 发现强制代码修复

- **Change ID**: l2-l3-fix-compliance
- **关联**: `@.specs/l2-l3-fix-compliance/REQUIREMENT.md`、`@.specs/l2-l3-fix-compliance/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P], T05[P]   — lib + 4 prompt 文件独立修改
Wave 2:             T06                                        — gate hook 扩展 (depends on T01 lib)
Wave 3:             T07                                        — 测试 (depends on T01+T06 实现细节)
Wave 4:             T08                                        — 全量回归 + AC 验收
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>新建 fix-compliance.sh 实效性校验 lib</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    .specs/l2-l3-fix-compliance/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/fix-compliance.sh
  </write_files>
  <action>
    新建文件，实现 DESIGN §9.3 定义的四个函数：
    - fk_classify_source_files()：按扩展名白名单分类文件列表（源码 vs 文档）。默认白名单见 DESIGN D3。支持 env var L3_FIX_SOURCE_EXTS 覆盖。
    - fk_check_doc_only_diff()：检测 git diff 是否仅含文档文件。AC-2 纯文档响应检测。
    - fk_verify_finding_files()：解析 INDEPENDENT-REVIEW-&lt;N&gt;.md 中 "Fixed in:" 声明，逐项校验文件是否在 git diff 中。AC-2b 逐发现校验。
    - fk_fix_compliance_check()：主入口，仅对 phase 5/6/7 触发。调用上述三个 helper，返回 0/1/2/3。

    实现要点：
    - 文件分类采用硬编码白名单 + env var 覆盖模式（与 l3-review.sh 模型选择一致）
    - 所有错误路径 fail-closed（D7）——出错阻断而非静默放行
    - "Fixed in:" 解析使用 grep -oP 正则（DESIGN §3.2 统一格式）
    - 文件不存在或 jq 不可用时返回 3（错误→阻断）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/fix-compliance.sh</verify>
  <done>AC-2/AC-2b helper 函数实现完成，语法检查通过</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>L2-blind-review.md 追加修代码优先 checklist 项</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
    .specs/l2-l3-fix-compliance/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
  </write_files>
  <action>
    在 L2-blind-review.md 的阶段 5/6/7 checklist 中各追加一项：
    - "主 agent 响应段是否对每条发现输出了分类标记（Fixed in: / Tech-debt: / Not-applicable:）？纯文档敷衍（仅写「已知限制」「未覆盖」无代码变更）视为不合格。"

    同时在「与主 agent 的关系」段追加：
    - "主 agent 的响应必须对每条 🔴/🟡 发现给出具体行动。禁止仅回复「已知」「待后续处理」「已记录」等无代码变更的敷衍回应。"

    使用 DESIGN §3.2 统一格式 "Fixed in:"（非方括号格式）。
  </action>
  <verify>grep -q "Fixed in:" flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md &amp;&amp; grep -q "纯文档敷衍" flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md</verify>
  <done>AC-1：L2 盲审员 checklist 含代码修复强制检查项</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>5-test.md prompt 追加修代码优先协议段</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/5-test.md
    .specs/l2-l3-fix-compliance/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/5-test.md
  </write_files>
  <action>
    在 5-test.md 的「独立 review 调度」段后追加「修代码优先协议」子段，要求主 agent：
    1. 读取 INDEPENDENT-REVIEW-5.md 后，逐条处理发现
    2. 每条发现输出分类标记（DESIGN §3.2 统一格式）：Fixed in: &lt;file&gt; / Tech-debt: &lt;reason&gt; / Not-applicable: &lt;reason&gt;
    3. 禁止仅写文档不修代码——纯 "已知限制" / "未覆盖" / "暂不处理" 无代码变更视为不合格
    4. AC-4 技术债登记滥用防护：若 ≥50% 发现被标记为 Tech-debt，需输出显式说明

    PCSC 追加一项："所有 review 发现已处理（Fixed in / Tech-debt / Not-applicable 分类完成）"
  </action>
  <verify>grep -q "Fixed in:" flow-kit-bundle/flow-kit/prompts/5-test.md &amp;&amp; grep -q "修代码优先" flow-kit-bundle/flow-kit/prompts/5-test.md</verify>
  <done>AC-1：5-test.md 含修代码优先协议</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>6-review.md prompt 追加修代码优先协议段</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
    .specs/l2-l3-fix-compliance/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
  </write_files>
  <action>
    同 T03，在 6-review.md 的「独立 review 调度」段后追加「修代码优先协议」子段。
    6-review 特殊点：主 agent 自身也是 reviewer（产 REVIEW.md），L2/L3 是对 REVIEW.md 的二次审查。
    协议要求：L2/L3 发现的问题必须在代码中修复后重新验证，不可仅在 REVIEW.md 中「补充说明」或「标注为已知限制」。
  </action>
  <verify>grep -q "Fixed in:" flow-kit-bundle/flow-kit/prompts/6-review.md &amp;&amp; grep -q "修代码优先" flow-kit-bundle/flow-kit/prompts/6-review.md</verify>
  <done>AC-1：6-review.md 含修代码优先协议</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>7-integration.md prompt 追加修代码优先协议段</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    .specs/l2-l3-fix-compliance/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    同 T03/T04，在 7-integration.md 的「独立 review 调度」段后追加「修代码优先协议」子段。
    7-integration 特殊点：归档前最后一道审查，L2/L3 发现的问题必须在归档前修复，不可推迟到"下一轮 change"。
  </action>
  <verify>grep -q "Fixed in:" flow-kit-bundle/flow-kit/prompts/7-integration.md &amp;&amp; grep -q "修代码优先" flow-kit-bundle/flow-kit/prompts/7-integration.md</verify>
  <done>AC-1：7-integration.md 含修代码优先协议</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="false" status="pending">
  <name>independent-review-gate.sh 扩展实效性校验</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/fix-compliance.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    .specs/l2-l3-fix-compliance/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    按 DESIGN D1 + §9.3 插入点规约，在 independent-review-gate.sh 中：
    1. 在 forward direction 分支、L3 完成后、exit 0 前，插入实效性校验调用（见 DESIGN §9.3 代码骨架）
    2. 仅对 phase 5/6/7 触发（AC-5 阶段限定）
    3. source fix-compliance.sh lib，调用 fk_fix_compliance_check()
    4. 返回非 0 → exit 2 deny；返回 0 → 继续 exit 0
    5. 阻断时输出明确的错误信息到 stderr（含阻断原因 + 相关文件路径）

    不修改：fk_validate_done_marker()、fk_check_gate_config_tamper()、is_phase_write()、L3 前置逻辑
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh &amp;&amp; grep -q "fk_fix_compliance_check" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh</verify>
  <done>AC-2/AC-2b/AC-5：gate hook 含实效性校验，仅对 5/6/7 触发</done>
  <depends_on>T01</depends_on>
</task>

<task id="T07" parallel="false" status="pending">
  <name>新建 test_l2_l3_fix_compliance.bats 测试文件</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/fix-compliance.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/test/test_gate_config_presets.bats
    .specs/l2-l3-fix-compliance/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_l2_l3_fix_compliance.bats
  </write_files>
  <action>
    新建 bats 测试文件，覆盖 AC-2/AC-2a/AC-2b/AC-5：

    AC-2 纯文档响应检测：
    - 仅 .md diff → fk_check_doc_only_diff 返回 1（阻断）
    - 含 .sh diff → 返回 0（放行）
    - diff 为空 → 返回 2（阻断）

    AC-2a 源码级发现分类：
    - Symptom 含 .sh 路径 → 判定源码级
    - Symptom 仅含 .md 路径 → 判定文档级
    - Symptom 无文件路径 → 默认源码级

    AC-2b 逐发现文件校验：
    - "Fixed in: a.sh" 且 diff 含 a.sh → 通过
    - "Fixed in: a.sh" 且 diff 不含 a.sh → MISSING
    - ≥50% MISSING → fk_verify_finding_files 返回 1

    AC-5 阶段限定：
    - phase=5/6/7 → fk_fix_compliance_check 执行
    - phase=1/2/3 → 跳过（不触发）

    AC-3 双层共存场景（R1 fix）：
    - 构造假 .done（空文件/假内容）+ 纯文档 diff → 两层均报错且信息不重叠
    - 构造合法 .done + 纯文档 diff → 真实性通过但实效性阻断
  </action>
  <verify>npx bats flow-kit-bundle/test/test_l2_l3_fix_compliance.bats</verify>
  <done>AC-2/AC-2a/AC-2b/AC-5 测试用例全部通过</done>
  <depends_on>T01, T06</depends_on>
</task>

<task id="T08" parallel="false" status="pending">
  <name>全量回归测试 + AC 验收</name>
  <read_files>
    .specs/l2-l3-fix-compliance/REQUIREMENT.md
    .specs/l2-l3-fix-compliance/DESIGN.md
    flow-kit-bundle/test/
  </read_files>
  <write_files>
  </write_files>
  <action>
    1. 运行全量 bats 测试套件：npx bats flow-kit-bundle/test/
    2. 确认无回归（现有 213 tests 全 pass）
    3. 逐 AC 验收：
       - AC-1: grep 确认 4 份 prompt 文件含修代码优先协议关键词
       - AC-2/AC-2b: 新增 bats 测试通过（T07 已验证）
       - AC-3: 现有 gate-integrity 测试不受影响
       - AC-4: grep 确认 AC-4 约束在 prompt 中
       - AC-5: grep 确认 hook 硬编码 phase 5/6/7 白名单
    4. 如有回归或验收失败 → 修复对应文件并重跑
  </action>
  <verify>npx bats flow-kit-bundle/test/ &amp;&amp; echo "=== AC-1 ===" &amp;&amp; for f in flow-kit-bundle/flow-kit/prompts/{5-test,6-review,7-integration}.md flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md; do echo "$f: $(grep -c 'Fixed in:' $f) matches"; done &amp;&amp; echo "=== AC-4 ===" &amp;&amp; grep -q '50%' flow-kit-bundle/flow-kit/prompts/5-test.md &amp;&amp; echo "AC-4 threshold in 5-test: OK" &amp;&amp; echo "=== AC-5 ===" &amp;&amp; grep -q '[5|6|7]' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh &amp;&amp; echo "AC-5 phase whitelist in gate: OK"</verify>
  <done>全量 bats 通过 + 5 条 AC 全部验收通过</done>
  <depends_on>T01, T02, T03, T04, T05, T06, T07</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加。

```xml
<!-- 占位 -->
```
