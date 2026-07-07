# TASK: L3 审查结果反馈可见性修复

- **Change ID**: `l3-feedback-visibility`
- **关联**: `@.specs/l3-feedback-visibility/REQUIREMENT.md`、`@.specs/l3-feedback-visibility/DESIGN.md`

---

## 波次划分

```
Wave 1:            T01                         （F3 基础 — l3-review.sh 新增函数）
Wave 2 (parallel): T02[P], T03[P]              （F1 + F2 — 各自独立文件，均依赖 T01）
Wave 3:            T04                         （bats 测试 — 依赖 T01+T02+T03）
Wave 4:            T05                         （集成验证 + 全量回归）
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="false" status="done">
  <name>F3 · l3-review.sh：新增 summary 三层提取 + 第四层故障降级 + _l3_format_result() + 值域扩展</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    在 l3-review.sh 中做四处改动（见 DESIGN §2 F3 数据流）：

    1. 新增 summary 三层提取（与既有 verdict 提取 l3-review.sh:201-222 并列）：
       - Layer 1：从 JSON 代码块提取 → jq -r '.summary'
       - Layer 2：裸 JSON → jq -r '.summary'
       - Layer 3：grep 正则 → grep -oP '"summary"\s*:\s*"\K[^"]+'
       - 未提取到时默认 ""（空字符串）

    2. 新增第四层故障降级（在所有三层提取之后）：
       - if verdict 为空 或 verdict="unknown" → verdict="error" + summary 固定为"L3 结果解析失败（verdict 不可用）"
       - 利用 done-validation.sh:139 已接受的 error 值域

    3. l3-review.sh:220-223 值域 case 扩展：在 pass|fail 之外增加 error) 分支（不降级为 fail）

    4. 新增 _l3_format_result() 格式化函数：
       ```bash
       _l3_format_result() {
         local verdict="$1" summary="$2" report="$3"
         echo "L3_RESULT: verdict=${verdict} summary=${summary} report=${report}"
       }
       ```

    5. l3_write_done_marker() 扩展：在 cat <<DONE_EOF 块中增加 L3_summary=${l3_summary} 行
    6. l3_write_timeout_done() 扩展：增加 L3_summary=L3 API 调用超时（30s） 行
  </action>
  <verify>
    bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh
    grep -q '_l3_format_result' flow-kit-bundle/hooks/stop/lib/l3-review.sh
    grep -q 'L3_summary' flow-kit-bundle/hooks/stop/lib/l3-review.sh
    grep -qE 'l3_verdict=.error.|l3_verdict="error"' flow-kit-bundle/hooks/stop/lib/l3-review.sh
    grep -q 'L3 结果解析失败（verdict 不可用）' flow-kit-bundle/hooks/stop/lib/l3-review.sh
    # 验证 error 在值域中不被降级（done-validation.sh:139 已含 error）：
    grep -qE 'pass\|fail\|error' flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </verify>
  <done>summary 三层提取 + 第四层故障降级 + _l3_format_result() + error 值域均就绪；bash -n 语法检查通过</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>F1 · independent-review-gate.sh：移除 2>/dev/null + 输出 L3_RESULT: 到 stdout</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    改动 independent-review-gate.sh （见 DESIGN §2 F1 数据流）：

    1. 第 228 行附近：移除 l3_review_with_timeout ... 2>/dev/null 中的 2>/dev/null
       - 当前行：l3_review_with_timeout "$phase" "$change_id" "$spec_dir" "$l2v" 30 "${gate_val:-both}" 2>/dev/null || true
       - 改为：l3_review_with_timeout "$phase" "$change_id" "$spec_dir" "$l2v" 30 "${gate_val:-both}" || true
       - 理由：2>/dev/null 丢弃了 L3 内部日志，也丢弃了可能的错误信息；安全过滤由 _l3_format_result 的白名单字段保证

    2. 在 L3 完成后（fk_validate_done_marker 之前），新增 stdout 输出：
       - source l3-review.sh（已在上方 source，确认 _l3_format_result 可用）
       - 从 .done 读取 L3_verdict 和 L3_summary（用 _fk_done_kvp，source done-validation.sh）
       - report=".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
       - _l3_format_result "$l3_verdict" "$l3_summary" "$report"
       - 输出到 stdout（无需重定向，hook stdout 即为 agent 可见通道）

    3. 安全约束：不输出 l3_review_run 的内部日志行（这些仍在 stderr 通过 >&2），仅输出 _l3_format_result 的格式化行。
       注意：移除 2>/dev/null 后 l3_review_run() 内部的 >&2 日志（curl 错误、jq 解析错误）也会暴露到 agent 可见 stderr。
       缓解措施：(a) l3_review_run() 内部日志使用 "[l3-review]" 前缀便于过滤；(b) T04 增加 stderr 安全测试验证不泄露 endpoint URL/API 原文
  </action>
  <verify>
    bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    grep -q '_l3_format_result' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    # 确认 2>/dev/null 已从 l3_review_with_timeout 调用中移除：
    ! grep -qE 'l3_review_with_timeout.*2>/dev/null' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </verify>
  <done>independent-review-gate.sh 在 L3 完成后通过 _l3_format_result() 输出 L3_RESULT 行到 stdout；2>/dev/null 已移除</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>F2 · flow-kit-resume.sh：替换握手文件检测为 .done + L3 段检测</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </write_files>
  <action>
    改动 flow-kit-resume.sh 第 133-168 行（见 DESIGN §2 F2 数据流）：

    1. 新增 source 依赖：
       - source l3-review.sh（获取 _l3_format_result()）
       - source done-validation.sh（获取 _fk_done_kvp()）
       - 使用与 independent-review-gate.sh 相同的相对路径解析方式

    2. 替换检测逻辑：
       旧（第 133-134 行）：
         ir_state_file=".../.flow-active.independent-review"
         if [[ -f "$ir_state_file" ]] && jq empty "$ir_state_file"; then
       新：
         done_file=".specs/${change_id}/.independent-review-${phase}.done"
         review_md=".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
         if [[ -f "$done_file" ]] && grep -q "## L3 外部模型审查" "$review_md"; then

    3. 替换读取逻辑（第 136-138 行）：
       旧：从 ir_state_file（JSON）用 jq 读取 ir_status/ir_report/ir_fail
       新：set +e; l3_verdict=$(_fk_done_kvp "$done_file" "L3_verdict"); l3_verdict="${l3_verdict:-unknown}"; l3_summary=$(_fk_done_kvp "$done_file" "L3_summary"); l3_summary="${l3_summary:-}"; set -e; report=".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"

    4. 替换输出逻辑（第 152-159 行 banner 段）：
       旧：硬编码的 "🔎 独立 review 报告就绪（L3 外部模型）" banner
       新：_l3_format_result "$l3_verdict" "$l3_summary" "$report" 嵌入现有 ║ 框线 banner 中

    5. 移除旧代码：
       - 删除 ir_state_file / ir_status / ir_report / ir_fail / ir_done 相关变量（第 133-141 行旧逻辑）
       - 删除旧 done 检测条件（第 143 行的 if [[ ... ! -f "$ir_done" ]]）
  </action>
  <verify>
    bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    grep -q '_l3_format_result' flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    grep -q '_fk_done_kvp' flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    # 确认旧握手文件检测已移除：
    ! grep -q 'ir_state_file' flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    # 确认新 .done 检测逻辑存在：
    grep -q 'L3 外部模型审查' flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </verify>
  <done>flow-kit-resume.sh 在 session 启动时通过 .done + L3 段检测展示 L3_RESULT 行；旧握手文件逻辑已移除</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="false" status="done">
  <name>测试：编写 bats 测试覆盖 AC-1/2/3/5/6 + 全模式兼容 AC-4</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    test/*.bats
  </read_files>
  <write_files>
    test/test_l3_feedback.bats
  </write_files>
  <action>
    新建 test/test_l3_feedback.bats，覆盖以下场景：

    1. _l3_format_result() 格式化输出测试：
       - 正常 verdict + summary → 输出 "L3_RESULT: verdict=pass summary=OK report=test.md"
       - 空 summary → 输出含 "summary="
       - verdict=error → 输出含 "verdict=error"

    2. summary 三层提取测试：
       - 代码块包裹的正常 JSON → 提取到 summary
       - 裸 JSON → 提取到 summary
       - grep 正则 → 提取到 summary
       - 无 summary 字段 → 降级为空字符串

    3. 第四层故障降级测试：
       - verdict 为空 → 降级为 error + 固定 summary
       - verdict=unknown → 降级为 error
       - 正常 verdict → 不触发降级

    4. .done KVP 格式扩展测试：
       - .done 含 L3_summary 行 → _fk_done_kvp 可读取
       - .done 不含 L3_summary 行 → 返回空字符串

    5. F1 PreToolUse stdout 测试：
       - 模拟 L3 完成后 stdout 含 L3_RESULT 行
       - 精确断言（非 -i 宽松匹配）：
         echo "$output" | grep -qE '^L3_RESULT: verdict=(pass|fail|timeout|error) summary=.+ report=.+[.]md$'
       - summary 字段非空（至少 1 个非空白字符）
       - report 为相对路径（不以 / 开头），以 .md 结尾
       - verdict 值全小写（与 done-validation.sh:139 值域一致）

    6. F2 SessionStart 检测逻辑测试：
       - .done 存在 + review md 含 L3 段 → 输出 L3_RESULT 行
       - .done 不存在 → 不输出 L3_RESULT 行
       - review md 不含 L3 段 → 不输出 L3_RESULT 行

    7. 全模式兼容 AC-4 测试：
       - gate_config=L2 → 不输出 L3_RESULT 行
       - gate_config=off → 不输出 L3_RESULT 行

    8. AC-6 畸变降级测试：
       - 非法 JSON → verdict=error
       - 原始畸形内容不出现在 L3_RESULT 行中

    9. AC-5 超时 exit code 测试：
       - 模拟 l3_review_with_timeout 超时 → L3_RESULT: verdict=timeout 输出
       - 验证函数/脚本退出码 = 0（transition 不被阻塞，对应 AC-5 验证方式第 2 条）

    10. stderr 安全测试（R2 缓解）：
        - 模拟 L3 API 调用失败（curl 非零退出）
        - 验证 stderr 不含 https?://（endpoint URL 模式）
        - 验证 stderr 不含 "verdict" 等 JSON 片段（API 响应原文不应泄露）

    参考现有 bats 文件风格（test/test_common.bats, test/test_install.bats）编写。
  </action>
  <verify>
    npx bats test/test_l3_feedback.bats
  </verify>
  <done>所有新增 bats 测试通过；覆盖 AC-1/2/3/4/5/6 的关键路径</done>
  <depends_on>T01, T02, T03</depends_on>
</task>

<task id="T05" parallel="false" status="done">
  <name>集成验证 + 全量回归测试</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    test/*.bats
  </read_files>
  <write_files>
    <!-- 本任务仅验证，不修改文件；若发现问题修复后重新验证 -->
  </write_files>
  <action>
    1. 运行全量 bats 回归测试：
       npx bats test/
       - 确认 0 失败（所有已有测试通过）
       - 确认新增 test_l3_feedback.bats 全部通过

    2. 手动集成验证：
       a. 模拟 PreToolUse 路径：
          - 构造含 L3 响应的测试场景
          - source independent-review-gate.sh 的关键函数
          - 确认 stdout 出现 L3_RESULT 行
       b. 模拟 SessionStart 路径：
          - 创建 .done（含 L3_verdict + L3_summary）
          - 创建 INDEPENDENT-REVIEW-<N>.md（含 L3 段）
          - source flow-kit-resume.sh 的关键逻辑
          - 确认输出 L3_RESULT 行
       c. 边缘场景：
          - .done 存在但 review md 无 L3 段 → 不输出 L3_RESULT
          - .done 中 L3_verdict=error → L3_RESULT 含 verdict=error
          - .done 中 L3_verdict=timeout → L3_RESULT 含 verdict=timeout

    3. shellcheck 静态分析（如有）：
       shellcheck flow-kit-bundle/hooks/stop/lib/l3-review.sh
       shellcheck flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
       shellcheck flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </action>
  <verify>
    npx bats test/ --filter-tags ''
  </verify>
  <done>全量 bats 0 failures；手动集成验证 PreToolUse + SessionStart 路径均输出 L3_RESULT 行；边缘场景通过</done>
  <depends_on>T04</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

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
