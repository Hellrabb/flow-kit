# TASK — L3 独立审查异步化

- **Change ID**: l3-async-dispatch
- **总任务**: 5 个

---

## 波次划分

```
Wave 1: T01 (l3_dispatch_prompt)
Wave 2: T02 (gate restructure, depends on T01)
Wave 3: T03 (bats tests, depends on T02)
Wave 4: T04 (regression, depends on T03)
Wave 5: T05 (review + archive, depends on T04)
```

---

## 任务清单

<task id="T01" status="pending">
  <name>新增 l3_dispatch_prompt() 到 l3-review.sh</name>
  <depends_on></depends_on>
  <read_files>
    - flow-kit-bundle/hooks/stop/lib/l2-detect.sh（l2_dispatch_prompt 参考实现）
    - flow-kit-bundle/hooks/stop/lib/l3-review.sh（插入位置：l3_write_timeout_done 之后）
  </read_files>
  <write_files>
    - flow-kit-bundle/hooks/stop/lib/l3-review.sh（追加 ~65 行）
  </write_files>
  <action>
    1. 在 l3_write_timeout_done() 之后新增 l3_dispatch_prompt() 函数
    2. 参数: $1=phase, $2=change_id, $3=specs_dir, $4=gate_val
    3. 输出: 派发提示到 stdout（框线格式 + 子 agent 命令 + 手动 bash + 参数说明）
    4. L2_verdict 推导: gate_val=both → 从 INDEPENDENT-REVIEW-<N>.md 提取；gate_val=L3 → "skipped"
    5. 按阶段映射 artifact_desc（与 l3_review_run case 一致）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh</verify>
  <done>bash -n 通过；函数可被 source 加载，type l3_dispatch_prompt 返回 "l3_dispatch_prompt is a function"</done>
</task>

<task id="T02" status="pending">
  <name>重构 PreToolUse gate L3 分支为异步派发</name>
  <depends_on>T01</depends_on>
  <read_files>
    - flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（line 249-361）
  </read_files>
  <write_files>
    - flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（~110 行删，~35 行增）
  </write_files>
  <action>
    1. 删除两处同步 L3 调用代码块:
       - both 路径: l3_review_with_timeout(30s) + handshake + F1 (line 257-308)
       - L3-only 路径: 同上 (line 312-357)
    2. 替换为统一异步派发块:
       a. 先检查 .done 是否存在且通过 fk_validate_done_marker "transition" tier
       b. 存在 → F1 输出 L3_RESULT + fix-compliance check (phase 5/6/7) + exit 0
       c. 不存在 → l3_dispatch_prompt >&2 + 拦截说明 >&2 + exit 2
    3. 保留 L2-only 模式的 exit 0 逻辑（无 L3 需求时直接放行）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh</verify>
  <done>bash -n 通过；grep 确认文件中不再有 l3_review_with_timeout 调用</done>
</task>

<task id="T03" status="pending">
  <name>编写 async dispatch 专项 bats 测试</name>
  <depends_on>T02</depends_on>
  <read_files>
    - flow-kit-bundle/test/test_l2_l3_fix_compliance.bats（参考测试结构）
    - flow-kit-bundle/hooks/stop/lib/done-validation.sh（_fk_done_kvp 签名）
  </read_files>
  <write_files>
    - flow-kit-bundle/test/test_l3_async_dispatch.bats（新文件，~6-8 tests）
  </write_files>
  <action>
    1. AC-2: 测试 .done 存在且有效时 gate 放行（mock .done 文件 + fk_validate_done_marker）
    2. AC-3: 测试 .done 不存在时 gate 拦截（验证 exit code=2 + stderr 含派发提示）
    3. AC-4: 测试 l3_dispatch_prompt() 输出包含框线 + 子 agent 命令 + 参数说明
    4. 边界: gate_val=L3 且无 L2 review 文件 → L2_verdict=skipped
    5. 边界: gate_val=both 且 L2 verdict=pass → L2_verdict=pass 传递到派发提示参数
  </action>
  <verify>npx bats flow-kit-bundle/test/test_l3_async_dispatch.bats</verify>
  <done>全部 @test 通过（≥ 6 tests）</done>
</task>

<task id="T04" status="pending">
  <name>全量回归测试 + bash -n 门禁</name>
  <depends_on>T03</depends_on>
  <read_files>
    - (无，执行命令即可)
  </read_files>
  <write_files>
    - (无)
  </write_files>
  <action>
    1. bash -n 全量 .sh 文件: find . -name '*.sh' -not -path '*/node_modules/*' -not -path '*/.git/*' -exec bash -n {} \;
    2. npx bats test/（全量 bats 测试）
    3. 如有 failure → 修复并重跑
  </action>
  <verify>全量 bats 0 failures; bash -n 全部通过</verify>
  <done>全部通过，无 regression</done>
</task>

<task id="T05" status="pending">
  <name>Review + 产物归档</name>
  <depends_on>T04</depends_on>
  <read_files>
    - .specs/l3-async-dispatch/ 下全部产物
  </read_files>
  <write_files>
    - .specs/l3-async-dispatch/REVIEW.md
    - .specs/l3-async-dispatch/TEST.md
    - .specs/l3-async-dispatch/INTEGRATION.md
  </write_files>
  <action>
    1. 写 TEST.md（测试结果汇总）
    2. 写 REVIEW.md（双轮审查: spec 合规 + 代码质量）
    3. 写 INTEGRATION.md（产物完整性检查 + CHANGELOG 更新）
    4. 写 .independent-review-7.done
    5. 归档到 .specs/archive/
  </action>
  <verify>全部产物齐全；bash -n 全过；bats 全绿</verify>
  <done>归档完成，change 关闭</done>
</task>

---

## 状态字段说明

- **pending**: 未开始
- **in_progress**: 执行中
- **done**: 完成（T<NN>-SUMMARY.md 已写）
