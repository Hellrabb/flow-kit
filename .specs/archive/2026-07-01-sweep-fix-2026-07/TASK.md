# TASK: 修复 2026-07-01 全量健康扫描发现的 6 项技术债

- **Change ID**: sweep-fix-2026-07
- **关联**: `@.specs/sweep-fix-2026-07/REQUIREMENT.md`、`@.specs/sweep-fix-2026-07/DESIGN.md`
- **AC 覆盖**: AC-1 ~ AC-6

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P]          ← 独立小修 + 环境准备
Wave 2 (parallel): T04[P], T05[P]                   ← 基础设施（共享数组 + 新 lib）
Wave 3 (parallel): T06[P], T07[P], T08[P], T09[P], T10[P]  ← 消费者迁移 + 重构
Wave 4 (parallel): T11[P], T12[P], T13[P]           ← 新测试
Wave 5:            T14                               ← 最终回归验证
```

---

## 任务清单

<task id="T01" parallel="true">
  <name>MIN_MEANINGFUL_LINES 添加注释 (AC-6)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </write_files>
  <action>
    在 `readonly MIN_MEANINGFUL_LINES=3` 行上方添加注释：
    `# 阈值: <3 行的文件视为空壳（常见于只有 shebang + 空行的空模板），≥3 行才开始内容检验`
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh && grep -A1 "MIN_MEANINGFUL_LINES" flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh | grep -c "#"</verify>
  <done>注释存在且 bash -n 通过</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>输出格式审计：统一使用 module_output() (AC-5)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/[0-9][0-9]-*.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh
  </write_files>
  <action>
    grep 所有 stop hook 中裸 `echo "warning|"` / `echo "error|"` / `echo "info|"` / `echo "suggestion|"` 调用，
    替换为 `module_output "warning"` / `module_output "error"` 等调用。
    预期仅有 27/28 两个 hook 需要修改（其余已统一）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh && grep -rL "module_output" flow-kit-bundle/hooks/stop/[0-9][0-9]-*.sh | wc -l</verify>
  <done>所有 stop hook 均包含 module_output 调用（grep -L 返回 0）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>安装 bats-core 测试运行器 (AC-4 前提)</name>
  <read_files>
    flow-kit-bundle/test/test_smoke_syntax.bats
  </read_files>
  <write_files>
    （无代码修改——环境安装）
  </write_files>
  <action>
    优先 `sudo dnf install -y bats`，失败则 `npm install -g bats`。
    验证 `bats --version` 成功。
  </action>
  <verify>bats --version</verify>
  <done>bats 命令可用，版本号输出正常</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true">
  <name>HOOK_MODULE_NAMES 数组添加到 common.sh (D1, AC-1)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/lib/install_hooks.sh
    package-flow-kit.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
  </write_files>
  <action>
    在 common.sh 末尾「Project paths」段之后添加：
    ```bash
    # ── Hook module registry (single source of truth) ──────────────────
    # All consumers iterate: for name in "${HOOK_MODULE_NAMES[@]}"; do ...
    declare -a HOOK_MODULE_NAMES=(
      00-gate 01-transcript-parse
      20-claude-md 21-memory 22-git 23-quality 24-session 25-project
      26-workflow 27-interactive-ui-check 28-weak-model-compliance
      29-independent-review 30-ai-analyze 99-report
    )
    ```
    顺序与现有的 install_hooks.sh / package-flow-kit.sh 硬编码列表一致。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/common.sh && source flow-kit-bundle/hooks/stop/lib/common.sh 2>/dev/null; echo "${HOOK_MODULE_NAMES[@]}" | grep -c "00-gate"</verify>
  <done>common.sh bash -n 通过，数组可被 source 后引用</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true">
  <name>创建 correction-file.sh 通用 lib (D3, AC-3 前提)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
  </write_files>
  <action>
    新建 lib/correction-file.sh，提供 4 个函数：
    - `correction_file_exists(path)` → 返回 0（文件存在且 jq empty 通过）/ 1
    - `correction_file_read(path)` → stdout JSON；文件不存在输出 "{}"
    - `correction_file_write(path, json_array, dedup_key)` → 读已有 violations，merge 新条目（按 dedup_key 逗号分隔字段去重），原子写入（首次 jq -n 创建，覆写用临时文件 + mv）
    - `correction_file_clear(path)` → rm -f
    dedup_key 示例：compliance 调用方传 "rule,location"；interactive-ui 调用方传 "gate_type,required_tool"
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/correction-file.sh</verify>
  <done>bash -n 通过；4 个函数均已定义（grep "^correction_file_" 命中 4 次）</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="true">
  <name>install_hooks.sh 改用 HOOK_MODULE_NAMES (D1, AC-1)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/lib/install_hooks.sh
  </read_files>
  <write_files>
    flow-kit-bundle/lib/install_hooks.sh
  </write_files>
  <action>
    在 `install_hooks()` 函数中将硬编码的 `for script in 00-gate 01-transcript-parse ... 99-report` 替换为：
    ```bash
    for script in "${HOOK_MODULE_NAMES[@]}"; do
      install_file "$SCRIPT_DIR/hooks/stop/${script}.sh" "$hook_dst/stop/${script}.sh"
      chmod +x "$hook_dst/stop/${script}.sh" 2>/dev/null || true
    done
    ```
  </action>
  <verify>bash -n flow-kit-bundle/lib/install_hooks.sh && grep -c "HOOK_MODULE_NAMES" flow-kit-bundle/lib/install_hooks.sh</verify>
  <done>bash -n 通过；install_hooks.sh 引用 HOOK_MODULE_NAMES（不再硬编码）</done>
  <depends_on>T04</depends_on>
</task>

<task id="T07" parallel="true">
  <name>package-flow-kit.sh 改用 HOOK_MODULE_NAMES (D1, AC-1)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    package-flow-kit.sh
  </read_files>
  <write_files>
    package-flow-kit.sh
  </write_files>
  <action>
    在 package-flow-kit.sh 的 Part B（flow-kit 技能包装器 staging）和 Part D（hook stop 模块 staging）中，
    将硬编码的模块名列表替换为 `for name in "${HOOK_MODULE_NAMES[@]}"` 迭代。
    确认 common.sh 在此脚本中可 source 或数组内容可被读取。
  </action>
  <verify>bash -n package-flow-kit.sh && grep -c "HOOK_MODULE_NAMES" package-flow-kit.sh</verify>
  <done>bash -n 通过；package-flow-kit.sh 引用 HOOK_MODULE_NAMES（不再硬编码）</done>
  <depends_on>T04</depends_on>
</task>

<task id="T08" parallel="true">
  <name>interactive-ui-check.sh 迁移到 correction-file.sh (D3, AC-3)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
  </write_files>
  <action>
    将 interactive-ui-check.sh 中的 `init_correction_path()` / `write_correction_file()` / `read_correction_file()` /
    `clear_correction_file()` / `has_correction()` 函数替换为对 `correction-file.sh` 函数的调用。
    source correction-file.sh 在文件顶部。
    调用 `correction_file_write` 时传入 `dedup_key="gate_type,required_tool"`。
    保留 GATE_MAP、transcript 解析、detection 函数这些独特逻辑。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh && grep -c "correction_file_" flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh</verify>
  <done>bash -n 通过；interactive-ui-check.sh 不再自有 correction 实现，改用 correction-file.sh</done>
  <depends_on>T05</depends_on>
</task>

<task id="T09" parallel="true">
  <name>weak-model-compliance.sh 迁移到 correction-file.sh (D3, AC-3)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
  </write_files>
  <action>
    将 weak-model-compliance.sh 中的 `init_compliance_correction_path()` / `write_compliance_correction()` /
    `read_compliance_correction()` / `clear_compliance_correction()` / `has_compliance_correction()` 函数
    替换为对 `correction-file.sh` 函数的调用。
    source correction-file.sh 在文件顶部。
    调用 `correction_file_write` 时传入 `dedup_key="rule,location"`。
    保留 L1/L2/L3 scan 函数这些独特逻辑。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh && grep -c "correction_file_" flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh</verify>
  <done>bash -n 通过；weak-model-compliance.sh 不再自有 correction 实现，改用 correction-file.sh</done>
  <depends_on>T05</depends_on>
</task>

<task id="T10" parallel="true">
  <name>fk_artifact_check() 改为查表驱动 (D2, AC-2)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </write_files>
  <action>
    按 DESIGN.md §2.3「变更后」方案改造 `fk_artifact_check()`：
    1. 在函数外定义 `declare -A PHASE_ARTIFACTS` 关联数组（累积语义已编码在表值中）
    2. 通用循环：`for f in ${PHASE_ARTIFACTS[$phase]}; do fk_file_nonempty "${spec_dir}/${f}"; done`
    3. 保留两个条件分支：Phase 4 的 task_id SUMMARY 查找 + Phase 5 的 find | wc -l 计数
    4. Phase 2|2a 共用同一 case 条目
    验证：返回值语义不变（0=全部就绪，1=有缺失）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh && grep -c "PHASE_ARTIFACTS" flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh</verify>
  <done>bash -n 通过；PHASE_ARTIFACTS 关联数组存在；if/elif case 已替换为查表循环 + 条件分支</done>
  <depends_on></depends_on>
</task>

<task id="T11" parallel="true">
  <name>新增 test_correction_file.bats (AC-3 验证)</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/test/test_common.bats
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_correction_file.bats
  </write_files>
  <action>
    编写 bats 测试覆盖 correction-file.sh 的 4 个函数：
    - write → read 往返：写入 2 条 violation，读回验证内容
    - dedup：写入相同 dedup_key 的 violation，验证读回仅 1 条
    - clear：写入后 clear，验证 exists 返回 1
    - empty read：不存在时 read 返回 "{}"
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/correction-file.sh</verify>
  <done>测试文件创建，bats 可执行（bats 已安装前提下）</done>
  <depends_on>T05</depends_on>
</task>

<task id="T12" parallel="true">
  <name>新增 test_flow_kit_resume.bats (AC-4)</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/test/test_common.bats
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_flow_kit_resume.bats
  </write_files>
  <action>
    编写 bats 测试覆盖 flow-kit-resume.sh 的关键逻辑：
    - .flow-active 存在时 banner 包含 change_id + phase
    - .flow-active 不存在时无输出
    - interrupt 非空时 banner 包含 checkpoint 信息
    - interactive-ui correction 存在时 banner 含矫正提示
    Mock 所需的 env vars 和文件（HOOK_EVENT、SESSION_ID、PROJECT_ROOT 等）
  </action>
  <verify>bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh</verify>
  <done>测试文件创建，覆盖 resume banner 的主要分支</done>
  <depends_on></depends_on>
</task>

<task id="T13" parallel="true">
  <name>新增 test_stop_report_reminder.bats (AC-4)</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/stop-report-reminder.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/test/test_common.bats
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_stop_report_reminder.bats
  </write_files>
  <action>
    编写 bats 测试覆盖 stop-report-reminder.sh 的关键逻辑：
    - report 文件存在且新鲜时输出提醒
    - report 文件不存在时无输出
    - subagent SessionStart 时跳过
    - reminder 被 disabled 时跳过
  </action>
  <verify>bash -n flow-kit-bundle/hooks/session-start/stop-report-reminder.sh</verify>
  <done>测试文件创建，覆盖 reminder 的主要分支</done>
  <depends_on></depends_on>
</task>

<task id="T14" parallel="false">
  <name>最终回归验证：全量 bash -n + 语法门禁 (AC 全量)</name>
  <read_files>
    （全部已修改文件）
  </read_files>
  <write_files>
    （无新增修改——仅验证）
  </write_files>
  <action>
    1. `find . -name '*.sh' -not -path '*/node_modules/*' ... -exec bash -n {} \;` 全量语法检查
    2. 确认无新增语法错误
    3. 确认 AC-1~AC-6 的 verify 命令全部通过
    4. 若 bats 已安装（T03），运行 `bats test/` 确认无回归
  </action>
  <verify>find . -name '*.sh' -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/.claude/plugins/*' -exec bash -n {} \; 2>&1 | grep -c "语法错误"</verify>
  <done>全部 34 个 .sh 文件 bash -n 通过；AC-1~AC-6 的 verify 命令全部 0 退出；无回归</done>
  <depends_on>T01,T02,T03,T06,T07,T08,T09,T10,T11,T12,T13</depends_on>
</task>
