# TASK: L2/L3 独立审查开关拆分

- **Change ID**: `l2-l3-granular-gate`
- **关联**: `@.specs/l2-l3-granular-gate/REQUIREMENT.md`、`@.specs/l2-l3-granular-gate/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]
Wave 2 (parallel): T03[P], T04[P]  (depends on T01)
Wave 3:            T05 (depends on T01, T02, T03, T04)
```

- T01: 核心判定函数（done-validation.sh）— **被 T03/T04/T05 依赖**
- T02: flow skill 预设表 — 独立
- T03: 29 号 hook + gate 拦截 — 依赖 T01
- T04: 6 个 prompt L2 调度段 — 依赖 T01
- T05: bats 测试 — 依赖全部

---

<task id="T01" parallel="true">
  <name>fk_independent_review_gate_active 新增 tier 参数 + 三值映射</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    test/test_gate_integrity.bats
    test/test_flow_artifacts.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </write_files>
  <action>
    1. fk_independent_review_gate_active 新增第二个可选参数 tier（""/"L2"/"L3"）
       - tier="" 或未传：原行为（任一 tier 开启即返回 0）
       - tier="L2"：仅 gate_config 值为 "L2" 或 "both" 时返回 0
       - tier="L3"：仅 gate_config 值为 "L3" 或 "both" 时返回 0
    2. gate_config 值标准化映射函数（内联）：
       - "independent" → "both"
       - "true" → "both"
       - "L2"/"L3"/"both" → 原值
       - 其他 → ""（未开启）
    3. 更新函数注释（Usage + 返回值说明）
  </action>
  <verify>source flow-kit-bundle/hooks/stop/lib/done-validation.sh && PROJECT_ROOT=/tmp fk_independent_review_gate_active "6" "L2" && echo "L2 OK"</verify>
  <done>AC-1, AC-2, AC-3: 三值判定正确 + 现有 bats 无回归</done>
  <depends_on></depends_on>
</task>

---

<task id="T02" parallel="true">
  <name>flow skill --gate-config 支持 L2/L3 三值 + --l2-only/--l3-only flag</name>
  <read_files>
    ~/.claude/skills/flow/SKILL.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow/SKILL.md
  </write_files>
  <action>
    1. --gate-config 预设表更新：所有预设的 value 从 "independent" 改为 "both"
    2. 三值校验：合法值 {"L2", "L3", "both"}；"independent"/"true" 自动映射为 "both"
    3. 新增 flag：--l2-only → 覆盖 gate_config 所有 phase 为 "L2"
                --l3-only → 覆盖 gate_config 所有 phase 为 "L3"
    4. 冲突检测：--l2-only + --l3-only 同时传入 → 后者覆盖 + warning
    5. 预设表注释更新：标注 "both" = "L2+L3 双层"
  </action>
  <verify>grep -c '"both"' flow-kit-bundle/skills/flow/SKILL.md && echo "presets use both"</verify>
  <done>AC-4, AC-5: 预设默认 both + --l2-only/--l3-only flag 生效</done>
  <depends_on></depends_on>
</task>

---

<task id="T03" parallel="true">
  <name>29 号 hook + gate 拦截按 tier 判定</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    1. 29-independent-review.sh：
       - 在 L3 执行前调用 fk_independent_review_gate_active "$phase" "L3"
       - 返回 1 → echo "[independent-review] L3 skipped (gate_config=${gate_val})" 并 exit 0
       - 返回 0 → 正常执行 L3 外部模型盲审
    2. independent-review-gate.sh：
       - done 检查前判定活跃 tier：
         L2_active=$(fk_independent_review_gate_active "$phase" "L2")
         L3_active=$(fk_independent_review_gate_active "$phase" "L3")
       - done 要求：
         - L2_active=0 → 检查 INDEPENDENT-REVIEW 含 L2 段
         - L3_active=0 → 检查 INDEPENDENT-REVIEW 含 L3 段
         - 均 inactive → 放行（gate 未开启）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh && bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && echo "syntax OK"</verify>
  <done>AC-6, AC-7: L3 开关检测 + done 按 tier 判定</done>
  <depends_on>T01</depends_on>
</task>

---

<task id="T04" parallel="true">
  <name>6 个阶段 prompt L2 调度段更新</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    每个 prompt 的「独立 review 调度」段：
    1. L2 检测条件从：
       gate_config[phase_name] ∈ {independent, true}
       改为：
       gate_config[phase_name] ∈ {L2, both}
    2. 新增一行说明："L3-only 模式 → L2 不跑，仅靠 Stop hook 外部模型盲审"
    3. 保持 L2 子 agent 调用模板不变
  </action>
  <verify>grep -c 'L2.*both\|"L2"\|"both"' flow-kit-bundle/flow-kit/prompts/*.md | grep -v ':0$' | wc -l && echo "prompts updated"</verify>
  <done>AC-1, AC-2: prompt 按 tier 正确判定 L2 开关</done>
  <depends_on>T01</depends_on>
</task>

---

<task id="T05">
  <name>bats 测试：覆盖 L2-only / L3-only / both 三种模式</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    test/test_gate_integrity.bats
  </read_files>
  <write_files>
    test/test_l2_l3_granular_gate.bats
    flow-kit-bundle/test/test_l2_l3_granular_gate.bats
  </write_files>
  <action>
    新增 test_l2_l3_granular_gate.bats：
    - 3 个 gate_config 值映射测试（independent→both, true→both, 非法→empty）
    - 3 个 tier 判定测试（L2-only ON/OFF, L3-only ON/OFF, both ON/OFF）
    - 1 个向后兼容测试（不传 tier → 任一开启即返回 0）
  </action>
  <verify>npx bats test/test_l2_l3_granular_gate.bats && make test</verify>
  <done>AC-8: 新增测试全过 + 全量无回归</done>
  <depends_on>T01, T02, T03, T04</depends_on>
</task>
