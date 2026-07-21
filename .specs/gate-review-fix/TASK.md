# TASK: gate-review-fix — 任务清单

> 基于 REQUIREMENT.md（16 AC）+ DESIGN.md 拆解
> 双源同步：`test/` 和 `flow-kit-bundle/test/` 下同名文件需同步修改

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]     ← 共享函数 + 低风险独立修复
Wave 2 (parallel): T03[P], T04[P]     ← L3 核心修复 + L2 竞态修复
Wave 3 (parallel): T05[P], T06[P]     ← Gate 逻辑修复 + DRY 迁移
Wave 4 (parallel): T07[P], T08[P]     ← 测试修复（依赖 Wave 1-3 源码改动）
Wave 5:            T09                ← 全量测试验证 + 打包
```

---

<task id="T01" parallel="true">
  <name>新增 fk_normalize_gate_val() 共享函数 + 4 consumer 迁移</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </write_files>
  <action>
    1. 在 common.sh 新增 fk_normalize_gate_val() 函数：
       签名: fk_normalize_gate_val &lt;raw_value&gt; → stdout
       规则: independent|true → both / L2|L3|both → 原值 / 其他 → ""
    2. 迁移 4 处 consumer：
       - independent-review-gate.sh:456 处 case→$(fk_normalize_gate_val "$gate_val")
       - 29-independent-review.sh:134 处 case→函数调用
       - 29-independent-review.sh:174 处 case→函数调用
       - done-validation.sh:66 处 case→函数调用
    3. 确认旧 pattern 零匹配: grep -rn 'independent|true).*gate_val="both"' flow-kit-bundle/hooks/
  </action>
  <verify>grep -rn 'fk_normalize_gate_val' flow-kit-bundle/hooks/ | wc -l | xargs test 4 -le</verify>
  <done>≥4 处调用 fk_normalize_gate_val()；旧 case pattern 全消除；bash -n 语法检查通过</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>新增 fk_extract_l2_verdict() 共享函数 + 3 consumer 迁移</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    1. 在 l2-detect.sh 新增 fk_extract_l2_verdict() 函数：
       签名: fk_extract_l2_verdict &lt;review_md_path&gt; → stdout (pass|fail|"")
       逻辑: grep -iE 'verdict[^a-z]*[:：]' → tail -1 → grep -ioE 'pass|fail'
       含 heading-style fallback (grep -iA 2 '^##.*Verdict'，参考 done-validation.sh:173-174)
    2. 迁移 3 处 consumer：
       - independent-review-gate.sh:421 处 grep 链→fk_extract_l2_verdict
       - 29-independent-review.sh:181 处 grep 链→函数调用
       - l3-review.sh:755 处 grep 链→函数调用
    3. done-validation.sh:171 的重复 grep 由 T06 一并迁移（T06 有 done-validation.sh write_files）
  </action>
  <verify>grep -rn 'fk_extract_l2_verdict' flow-kit-bundle/hooks/ | wc -l | xargs test 3 -le</verify>
  <done>≥3 处调用 fk_extract_l2_verdict()；旧 grep 链消除；heading fallback 可用</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>AC-3/8/11: L3 review.sh 三项修复（去重 + 错误传播 + fallback路径）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    **AC-3** (_l3_parse_result L3段去重，lines 431-536):
      - 在追加新 L3 段前（line ~480），用 sed 删除旧的 ## L3 (盲审|重审) 段
      - sed -i '/^## L3 (盲审|重审)/,/^## /{ /^## L3 (盲审|重审)/d; /^## /!d; }' 或等效逻辑
      - 确保仅保留 1 个 L3 段，L2 段不受影响

    **AC-4** (竞态修复，line 459):
      - 将 local tmp_review="${review_md}.tmp.$$" 改为 mktemp
      - 加 trap cleanup (rm -f "$tmp_review")

    **AC-8** (_l3_write_done 错误传播，line 670):
      - 移除 || true
      - 改为 case $rc in: 0) ;; / 1) log+return 0 / 3) log+return 3 / *) log+return $rc

    **AC-11** (_l3_build_prompt fallback路径，line 267):
      - BASH_SOURCE[0] 回退路径: dirname(BASH_SOURCE[0]) 已是 lib/ 目录
      - 改为: local _common_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
      - 去掉多余的 /lib 层，使路径正确指向 .../hooks/stop/lib/common.sh
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && echo "SYNTAX OK"</verify>
  <done>l3-review.sh 三项修复完成，bash -n 语法通过</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true">
  <name>AC-4/7: l2-detect.sh 竞态修复 + mkdir 保证</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
  </write_files>
  <action>
    **AC-4** (竞态修复，lines 113 + 234):
      - line 113 (mock 模式): 用 mktemp 替代 ${review_md}.tmp.$$
      - line 234 (后台 dispatch): 用 mktemp 替代 ${review_md}.tmp.$$
      - 加 trap cleanup (rm -f "$tmpfile")
      - 注: l3-review.sh:459 的 mktemp 修复在 T03 中（T03 有 l3-review.sh write_files）

    **AC-7** (mkdir -p 保证):
      - l2_dispatch_agent() 函数开头加 mkdir -p "$specs_dir"
      - 确保后续文件操作（review_md 写入 + stderr redirect）不因目录缺失失败
  </action>
  <verify>grep -n 'mktemp' flow-kit-bundle/hooks/stop/lib/l2-detect.sh | head -5</verify>
  <done>mktemp 替换完成；mkdir -p 前置保证；bash -n 语法通过</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true">
  <name>AC-6/10: independent-review-gate.sh Gate逻辑修复</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    **AC-6** (_gate_check_l3 auto_advance 感知，lines 373-379):
      - else 分支（review_md 无 L2 段时）增加 auto_advance 检测:
        1. 读 .flow-active.goal.auto_advance（参考 _gate_check_l2:291-292 模式）
        2. auto_advance=true → echo 日志 + return 1（触发 || _gate_do_transition，不阻塞）
        3. auto_advance=false → 保持 exit 2（硬阻塞）
      - 理由: _gate_check_l3:406 已用 return 1="L3 not done"，caller line 463-464 用 || _gate_do_transition 消费

    **AC-10** (_gate_phase_filter 使用 fk_resolve_phase，lines 207-211):
      - 将 5 行内联 pipeline scope 检测替换为:
        phase=$(fk_resolve_phase 2>/dev/null || echo "?")
      - 移除手写的 jq -r '.goal.current_phase // "?"' 逻辑
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && echo "SYNTAX OK"</verify>
  <done>_gate_check_l3 auto_advance 兼容；_gate_phase_filter 改用 fk_resolve_phase()</done>
  <depends_on>T01, T02</depends_on>
</task>

<task id="T06" parallel="true">
  <name>AC-9: done-validation.sh 使用 fk_phase_gate_key()</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </write_files>
  <action>
    **AC-9** (fk_independent_review_gate_active 改用 fk_phase_gate_key，lines 42-50):
      - 将 9 行内联 case "$phase" in ... esac 替换为:
        phase_name="$(fk_phase_gate_key "$phase")"
        [ -n "$phase_name" ] || return 1

    **AC-13** (done-validation.sh:171 处 L2 verdict 提取迁移):
      - done-validation.sh:171 的 grep 链改为调用 fk_extract_l2_verdict
      - 至此 fk_extract_l2_verdict 调用 ≥4 处（含 T02 的 3 处）
  </action>
  <verify>grep -c 'fk_phase_gate_key' flow-kit-bundle/hooks/stop/lib/done-validation.sh</verify>
  <done>done-validation.sh 使用 fk_phase_gate_key() 替代内联 case；旧 case 消除</done>
  <depends_on></depends_on>
</task>

<task id="T07" parallel="true">
  <name>AC-1/5: test_l3_timeout.bats + test_l2_l3_granular_gate.bats 测试修复</name>
  <read_files>
    test/test_l3_timeout.bats
    test/test_l2_l3_granular_gate.bats
    flow-kit-bundle/test/test_l3_timeout.bats
    flow-kit-bundle/test/test_l2_l3_granular_gate.bats
  </read_files>
  <write_files>
    test/test_l3_timeout.bats
    test/test_l2_l3_granular_gate.bats
    flow-kit-bundle/test/test_l3_timeout.bats
    flow-kit-bundle/test/test_l2_l3_granular_gate.bats
  </write_files>
  <action>
    **AC-1** (test_l3_timeout.bats - timeout路径真实覆盖):
      - setup() 中创建 REQUIREMENT.md fixture: echo "test" > "${WORKSPACE}/.specs/test-change/REQUIREMENT.md"
      - 加 curl-stub-invocation 验证（stub 内 touch marker file，测试断言 marker 存在）
      - timeout-01 断言 .done 未写入（verdict=timeout）
      - timeout-02 断言 .done 未写入（API error）

    **AC-5** (test_l2_l3_granular_gate.bats - 值域验证不短路):
      - L2_verdict=skipped 测试: 从 .flow-active fixture 中移除 "phases_done":["6"]
      - L3_verdict=skipped 测试: 从 .flow-active fixture 中移除 "phases_done":["6"]
      - 确保 fk_validate_done_marker 完整执行到值域正则 L137/139
  </action>
  <verify>npx bats test/test_l3_timeout.bats test/test_l2_l3_granular_gate.bats</verify>
  <done>timeout-01/02 真实覆盖；L2/L3 skipped 值域验证不短路；双源同步</done>
  <depends_on>T03, T04</depends_on>
</task>

<task id="T08" parallel="true">
  <name>AC-2/3: done-validation.bats + test_l3_review.bats 测试修复</name>
  <read_files>
    test/done-validation.bats
    test/test_l3_review.bats
    flow-kit-bundle/test/done-validation.bats
    flow-kit-bundle/test/test_l3_review.bats
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </read_files>
  <write_files>
    test/done-validation.bats
    test/test_l3_review.bats
    flow-kit-bundle/test/done-validation.bats
    flow-kit-bundle/test/test_l3_review.bats
  </write_files>
  <action>
    **AC-2** (done-validation.bats - 真正测试 fk_validate_done_marker):
      - 替换 source .done 反模式: 改为 source done-validation.sh + 调用 fk_validate_done_marker
      - 新增测试: 6行最低行数检查 (dlines >= MIN_MEANINGFUL_LINES)
      - 新增测试: phase/change_id KVP 不匹配 → return 2
      - 新增测试: L2_verdict 非法值 → return 2
      - 新增测试: L3_verdict 非法值 → return 2
      - 保留: 所有 KVP 齐全 → 有效

    **AC-3** (test_l3_review.bats - L3段去重测试):
      - 改造 AC-3 去重测试: source l3-review.sh + 调用 _l3_parse_result（而非内联 awk 模拟）
      - 验证: 旧 L3 段被删除，仅保留新 L3 段
      - 验证: L2 段不受影响
      - 验证: _l3_inject_context 仍可正常读取去重后的 L3 段
  </action>
  <verify>npx bats test/done-validation.bats test/test_l3_review.bats</verify>
  <done>done-validation.bats 调用 fk_validate_done_marker；test_l3_review.bats 调用 _l3_parse_result；双源同步</done>
  <depends_on>T03, T06</depends_on>
</task>

<task id="T09">
  <name>全量测试验证 + 打包 + 双源同步检查</name>
  <read_files>
    test/
    flow-kit-bundle/test/
  </read_files>
  <write_files>
  </write_files>
  <action>
    1. 全量 bats: npx bats flow-kit-bundle/test/ test/
    2. 连续跑 3 次确认无 flaky（AC-NF2/AC-NF3）
    3. 打包验证: bash package-flow-kit.sh
    4. AC-NF1 验证:
       - grep -rn 'independent|true).*gate_val="both"' flow-kit-bundle/hooks/ 零匹配
       - grep -rn 'fk_normalize_gate_val' flow-kit-bundle/hooks/ ≥4 处
       - grep -rn 'fk_extract_l2_verdict' flow-kit-bundle/hooks/ ≥3 处
    5. bash -n 语法检查: 所有修改的 .sh 文件
    6. 确认双源 test/ 和 flow-kit-bundle/test/ 一致
  </action>
  <verify>npx bats flow-kit-bundle/test/ test/ && bash package-flow-kit.sh</verify>
  <done>全量 bats 3 次 0 fail；打包成功；AC-NF1 grep 验证通过；双源一致</done>
  <depends_on>T07, T08</depends_on>
</task>
