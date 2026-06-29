# TASK: 弱模型鲁棒性 Hook 化升级

- **Change ID**: `robustness-hook-hardening`
- **关联**: `@.specs/robustness-hook-hardening/REQUIREMENT.md`、`@.specs/robustness-hook-hardening/DESIGN.md`
- **作者**: AI（Planner 角色）+ 人工 review

---

## 波次划分

```
Wave 1 (parallel): T01 [P], T03 [P], T05 [P]     ← 无依赖，并行
Wave 2 (parallel): T02 [P] (→ T01), T04 [P] (→ T01)  ← 依赖 T01 的函数签名
Wave 3:            T06 (→ T02, T04)              ← 全量回归验证
```

> T01 lib 是核心瓶颈——T02 和 T04 都需要它的函数签名。T03（SessionStart）和 T05（config）完全独立，Wave 1 可与 T01 并行。

---

## 任务清单

<task id="T01" parallel="true">
  <name>实现 weak-model-compliance.sh 扫描逻辑库</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
  </write_files>
  <action>
    实现弱模型合规扫描函数库。提供以下公共函数：

    1. scan_l1_rules() — L1 规则合规扫描
       - 从 CONTEXT.md「禁动清单」段解析受保护文件路径列表
       - 交叉对比 $HOOK_TMP_DIR/written-files.txt + edited-files.txt（来自 transcript-parser）
       - 检测 RULES.md/SYSTEM.md 通用违规模式（grep 关键词："编造"/"跳过"/"顺手"在 assistant 消息中）
       - 输出：violations 数组（每项含 rule/location/fix）

    2. scan_l2_selfcheck() — L2 自检完整性扫描
       - 从 $HOOK_TMP_DIR/messages.txt 提取 assistant 消息
       - 匹配 PCSC 自检表模式（| # | ... | ✅ / ❌ |）
       - 逐行验证：表格每一行非空、有 ✅ 或 ❌ 标记
       - 检测空白行/未填行/跳过的表
       - 输出：violations 数组

    3. scan_l3_evidence() — L3 证据链真实性扫描
       - 从 assistant 消息中提取文件路径（限定前缀：flow-kit/、.specs/、test/、src/、~/.claude/，至少两级深度）
       - 交叉对比 $HOOK_TMP_DIR/tool-calls.txt（Read/Grep/Glob/Bash(ls/find) 调用历史）
       - 未出现在工具调用中的路径 → 标记为幻觉引用
       - 输出：violations 数组（每项含 hallucinated_path/evidence/fix）

    4. 矫正文件管理函数：
       - init_compliance_correction_path() — 设置 CORRECTION_FILE=.flow-active.correction
       - write_compliance_correction() — 合并写入（读旧 → jq 合并 violations[] → 去重 → 写入）
       - clear_compliance_correction() — rm 矫正文件
       - has_compliance_correction() — 检查文件存在且 JSON 合法

    代码风格对齐 lib/interactive-ui-check.sh：不设 set -euo pipefail（被 source），用 : ${VAR:=} 默认值模式，函数注释用 ##。
    目标 ≤ 230 行。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh &amp;&amp; echo "SYNTAX_OK"</verify>
  <done>所有函数通过 bash 语法检查；函数签名与 DESIGN.md 约定一致；≤ 230 行</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>扩展 SessionStart flow-kit-resume.sh 处理合规矫正文件</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </write_files>
  <action>
    在现有 interactive-ui-fix 矫正 block 后追加 compliance 矫正 block：

    1. 检查 .flow-active.correction 是否存在且 JSON 合法
    2. 解析 type/layer/violations[]/written_at
    3. 输出合规矫正 banner（格式对齐 interactive-ui banner）：
       - 标题："⚠️ 合规矫正：上轮弱模型违规"
       - 逐层列出 violations（L1/L2/L3）
       - 每条违规显示：规则 + 修复动作
    4. 注入后清除 .flow-active.correction（rm -f）
    5. JSON 解析失败 → 输出警告 + 删除损坏文件（不阻断 resume）

    注意：新增 block 放在 interactive-ui-fix block 之后、Read fields 之前（保持现有结构）。
    两个矫正 block 互相独立（各自 if [[ -f ]]，不嵌套）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh &amp;&amp; echo "SYNTAX_OK"</verify>
  <done>通过 bash 语法检查；banner 格式对齐 interactive-ui 风格；两个矫正 block 独立不嵌套</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true">
  <name>注册 weak_model_compliance 模块到 stop-hook.json</name>
  <read_files>
    .claude/stop-hook.json
  </read_files>
  <write_files>
    .claude/stop-hook.json
  </write_files>
  <action>
    在 stop-hook.json 的 modules 字典中新增 "weak_model_compliance" 条目：
    ```json
    "weak_model_compliance": {
      "enabled": true,
      "checks": ["W1", "W2", "W3"]
    }
    ```
    W1=L1 规则合规, W2=L2 自检完整性, W3=L3 证据链。
    放在 "workflow" 模块之后、"ai" 段之前（与其他模块保持字母/数字顺序）。
  </action>
  <verify>jq -e '.modules.weak_model_compliance.enabled == true' .claude/stop-hook.json &amp;&amp; echo "CONFIG_OK"</verify>
  <done>jq 验证模块已启用；checks 包含 W1/W2/W3；JSON 格式合法</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>实现 28-weak-model-compliance.sh Stop hook 协调器</name>
  <read_files>
    flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh
  </write_files>
  <action>
    实现 Stop hook 第 28 号模块协调器，结构对齐 27-interactive-ui-check.sh：

    1. source lib/common.sh + lib/weak-model-compliance.sh
    2. module_enabled "weak_model_compliance" gate
    3. 检查 .flow-active 存在 + change_id 有效（同 27 号逻辑）
    4. 检查 TRANSCRIPT_PATH 可用
    5. 调用 scan_l1_rules / scan_l2_selfcheck / scan_l3_evidence（各自 || true 保护）
    6. 聚合 violations：有违规 → write_compliance_correction；无违规 + 矫正文件存在 → clear
    7. 用 module_output 输出检测摘要（info/warning/error）
    8. 整体包在 ( ) || true subshell 中（不阻断 hook 链）

    目标 ≤ 80 行。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh &amp;&amp; echo "SYNTAX_OK"</verify>
  <done>通过 bash 语法检查；结构对齐 27-interactive-ui-check 模式；≤ 80 行</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="true">
  <name>编写 bats 测试 test_weak_model_compliance.bats</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
    test/test_interactive_ui_check.bats
  </read_files>
  <write_files>
    test/test_weak_model_compliance.bats
  </write_files>
  <action>
    编写 bats 测试文件，覆盖 AC-1 ~ AC-4。参考 test_interactive_ui_check.bats 的测试结构（setup/teardown + 逐函数测试）。

    最少测试用例（≥ 11 个）：

    L1 规则合规（≥ 3 个场景）：
    - L1-01: 检测到 Write 触碰禁动文件 → violation
    - L1-02: 未触碰禁动文件 → 无 violation
    - L1-03: assistant 消息中含通用违规关键词 → violation

    L2 自检完整性（≥ 3 个场景）：
    - L2-01: PCSC 表有空行 → violation
    - L2-02: PCSC 表全部填齐 → 无 violation
    - L2-03: 回复中无自检表 → 无 violation（不误报）

    L3 证据链（≥ 3 个场景）：
    - L3-01: 引用路径不在工具调用历史中 → violation
    - L3-02: 引用路径在工具调用历史中 → 无 violation
    - L3-03: 多路径混合（部分幻觉、部分真实）→ 仅标记幻觉路径

    矫正文件（≥ 2 个场景）：
    - CF-01: 写入矫正文件 → JSON 合法、type/layer/violations 字段齐全
    - CF-02: 合并写入 → 旧 violations 保留 + 新 violations 追加（幂等去重）

    每个测试用 mock transcript 数据（内联 heredoc 或 fixture 文件），不依赖真实 transcript。
  </action>
  <verify>npx bats test/test_weak_model_compliance.bats</verify>
  <done>≥ 11 个测试用例全部通过；覆盖 L1/L2/L3 各 ≥ 3 场景 + CF ≥ 2 场景</done>
  <depends_on>T01</depends_on>
</task>

<task id="T06" parallel="false">
  <name>全量回归测试 + 集成验证</name>
  <read_files>
    test/*.bats
    .specs/robustness-hook-hardening/REQUIREMENT.md
  </read_files>
  <write_files>
  </write_files>
  <action>
    全量回归验证：

    1. 运行 npx bats test/ → 确认所有现有测试通过（零 fail）
    2. 确认新增的 test_weak_model_compliance.bats 包含在测试运行中
    3. 检查 .gitignore 是否已覆盖 .flow-active.correction（当前 .*fix 模式涵盖）
    4. 手动验证：echo 一个模拟矫正 JSON → 运行 flow-kit-resume.sh → 确认 banner 输出正确 → 确认文件被清除

    如任何现有测试 fail → 回 T02/T03 修复（禁止带着 fail 前进）。
  </action>
  <verify>npx bats test/ &amp;&amp; echo "ALL_TESTS_PASS"</verify>
  <done>npx bats test/ 零 fail；.flow-active.correction 已 gitignored；SessionStart banner 手动验证通过</done>
  <depends_on>T02, T04</depends_on>
</task>

---

## 依赖图

```
Wave 1 ───────────────────── Wave 2 ──────────── Wave 3
T01 [P] lib ───────────────► T02 [P] coordinator ──► T06 全量回归
  │                           T04 [P] bats tests ────►
  │
T03 [P] SessionStart (独立)
T05 [P] config (独立)
```

---

> 任务编号连续 T01-T06。波次 1 三任务无依赖可并行；波次 2 依赖 T01 的函数签名；波次 3 串行收尾验证。
