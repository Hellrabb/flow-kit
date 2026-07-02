# REQUIREMENT: 补齐 L2/L3 独立审查 3/5/7 缺失

## 用户故事

作为 flow-kit pipeline 用户，当我执行 `/flow goal "..." --pipeline --from 0 --gate-config all` 时，阶段 3/5/7 的独立审查应和阶段 1/2/6 一样正常工作——L2 盲审子 agent 被调度、`.done` 文件被正确写入，pipeline 不会因缺失 done 而死锁。

> 注：L3 Stop hook 自动执行已在 `gate-integrity` change 中完成（`flow-kit-artifacts.sh` 的 case 分支已扩展 3/5/7，`29-independent-review.sh` 已覆盖）。本次变更仅涉及 prompt 层（L2 调度指令）+ PRESET_MAP 层 + L2-blind-review.md checklist 层。

## 验收准则（AC）

### AC-1 · Prompt 模板补全（静态 + 结构验证）

**Given** flow-kit prompt 目录中存在 `3-task.md` / `5-test.md` / `7-integration.md`
**When** 对应阶段的 `gate_config` 设为 `"independent"` 且主 agent 进入该阶段
**Then** 每个 prompt 文件应包含完整的「独立 review 调度」段，具体含：
  - gate_config 检测说明（何时开启）
  - L2 盲审子 agent 调度模板（含 subagent_type / description / 原样注入 L2-blind-review.md / 审查参数 / 输出路径）
  - L3 说明（Stop hook 自动处理，本阶段不需手动调度）
  - 写 done 指令（touch `.independent-review-<phase>.done`）
  - 各阶段特定的审查参数（阶段号 / 审查工件 / 输出文件名）
**验证（静态）**：
```bash
for f in 3-task 5-test 7-integration; do
  grep -q "独立 review 调度" ~/.claude/flow-kit/prompts/$f.md || { echo "FAIL: $f missing section"; exit 1; }
  grep -q "L2.*独立子 agent 盲审" ~/.claude/flow-kit/prompts/$f.md || { echo "FAIL: $f missing L2 subsection"; exit 1; }
  grep -q "L3.*Stop hook" ~/.claude/flow-kit/prompts/$f.md || { echo "FAIL: $f missing L3 subsection"; exit 1; }
  grep -q "touch.*independent-review" ~/.claude/flow-kit/prompts/$f.md || { echo "FAIL: $f missing done instruction"; exit 1; }
done
echo "AC-1 PASS"
```

### AC-2 · PRESET_MAP 单阶段预设补全

**Given** `/flow goal --gate-config` 预设名解析逻辑在 `SKILL.md` PRESET_MAP 中
**When** 用户使用 `--gate-config task` / `--gate-config test` / `--gate-config integration`
**Then** gate_config 应分别映射为：
  - `task` → `{"3-task":"independent"}`
  - `test` → `{"5-test":"independent"}`
  - `integration` → `{"7-integration":"independent"}`
**验证**：`check-gate-sync.sh` set-diff 通过（SKILL.md PRESET_MAP ↔ bats `resolve_gate_config` case 分支 ↔ 预设名集合一致）

### AC-3 · PRESET_MAP 组合预设补全

**Given** 现有 PRESET_MAP 缺以下组合预设
**When** 用户使用以下任一预设名
**Then** 映射结果应为：
  - `task-review` → `{"3-task":"independent","6-review":"independent"}`
  - `test-review` → `{"5-test":"independent","6-review":"independent"}`
  - `task-test` → `{"3-task":"independent","5-test":"independent"}`
  - `task-test-review` → `{"3-task":"independent","5-test":"independent","6-review":"independent"}`
  - `spec-test` → `{"1-requirement":"independent","2-design":"independent","5-test":"independent"}`（需求+设计规划 + 测试；原称 `plan-test`，因歧义改名为 `spec-test`）
**验证**：`check-gate-sync.sh` set-diff 通过（SKILL.md PRESET_MAP ↔ bats `resolve_gate_config` case 分支 ↔ 预设名集合一致），且所有新预设名的 bats 测试用例全部 pass

### AC-4 · L2-blind-review.md 扩展（内容质量验证）

**Given** `L2-blind-review.md` 固化盲审指令目前仅有阶段 1/2/6 的审查 checklist
**When** L2 子 agent 被调用审查阶段 3/5/7 的产物
**Then** L2-blind-review.md 应包含以下 checklist，每个阶段 ≥ 3 条具体审查条目：

  - **阶段 3（任务拆解审查）**：审查 TASK.md —
    - 任务粒度是否合理（单 task ≤ 200 行变更）？
    - 任务依赖链是否无环、可并行部分是否已标注？
    - 每条 verify 是否可机器验证（非"人工确认"空话）？
    - 波次划分是否清晰（wave 1/2/3）？

  - **阶段 5（测试审查）**：审查 TEST.md —
    - 测试矩阵是否覆盖所有 AC（每条 AC 至少 1 条测试用例对应）？
    - 5 轮测试金字塔（功能/性能/安全/兼容/可观测）是否逐轮填写（跳过的有理由）？
    - 覆盖率是否达标（功能 100% AC 覆盖、其他轮按需）？
    - 是否有 UAT 脚本且 Given/When/Then 可执行？

  - **阶段 7（集成审查）**：审查归档完整性 —
    - 所有阶段产物是否齐全（CHANGE/REQUIREMENT/DESIGN/TASK/SUMMARY×N/TEST/REVIEW）？
    - LESSONS.md 是否从本次 REVIEW 中提取了新教训？
    - CHANGELOG.md 是否追加了本次 change 条目？
    - `.specs/<id>/` 目录是否有残留临时文件未清理？

**验证（内容质量）**：
```bash
for phase in 3 5 7; do
  section=$(sed -n "/^### 阶段 $phase/,/^### 阶段/p" ~/.claude/flow-kit/prompts/independent/L2-blind-review.md)
  entry_count=$(echo "$section" | grep -cE "^- \*\*" || true)
  if [ "$entry_count" -lt 3 ]; then
    echo "FAIL: 阶段 $phase checklist 仅 $entry_count 条（需 ≥ 3）"
    exit 1
  fi
done
echo "AC-4 PASS"
```

### AC-5 · 全链路阶段列表同步

**Given** 多个文件引用 gate_config 的合法阶段列表
**When** 补全完成后
**Then** 以下位置应与 PRESET_MAP `all` 预设的阶段集合 {1,2,3,5,6,7} 一致：

  - `SKILL.md` `/flow gate-config` 子命令的合法值列表：当前仅写 `1-requirement / 2-design / 6-review` → 需扩展为含 `3-task / 5-test / 7-integration`
  - `pipeline-gates.md` L75 说明文字：当前写"默认 `full` 预设仅 1/2/6 independent，3/5/7 由用户显式开" → 追加"3/5/7 的 prompt 层支持由 `independent-review-gap` change 补齐"

**验证**：
```bash
# SKILL.md gate-config 合法值列表包含 3/5/7
grep -q "3-task" flow-kit-bundle/skills/flow/SKILL.md || { echo "FAIL: SKILL.md missing 3-task"; exit 1; }
grep -q "5-test" flow-kit-bundle/skills/flow/SKILL.md || { echo "FAIL: SKILL.md missing 5-test"; exit 1; }
grep -q "7-integration" flow-kit-bundle/skills/flow/SKILL.md || { echo "FAIL: SKILL.md missing 7-integration"; exit 1; }
# pipeline-gates.md 说明包含本次 change 引用
grep -q "independent-review-gap" ~/.claude/flow-kit/reference/pipeline-gates.md || { echo "FAIL: pipeline-gates.md missing gap note"; exit 1; }
echo "AC-5 PASS"
```

### AC-6 · bats 测试覆盖新预设

**Given** `test_gate_config_presets.bats` 测试 gate_config 预设名解析
**When** 新增预设名被加入 PRESET_MAP
**Then** bats 测试应覆盖所有新增预设的解析结果（每个预设至少 1 个 test case 验证映射正确性）
**验证**：
```bash
npx bats test/test_gate_config_presets.bats --filter "preset" 2>&1 | grep -E "^ok |^not ok "
# 预期：所有 test case 均为 ok，零 not ok
```

### AC-7 · `all` 预设端到端不阻塞（可机器验证）

**Given** prompt 已补全「独立 review 调度」段 + PRESET_MAP 已补全
**When** 在 dry-run fixture 环境下模拟 pipeline 推进经过阶段 3/5/7（gate_config 含对应 key="independent"），主 agent 完成对应阶段
**Then** 对每个阶段 N ∈ {3,5,7}：
  1. `INDEPENDENT-REVIEW-{N}.md` 文件存在且包含 L2 盲审段（非空）
  2. `.independent-review-{N}.done` 文件存在（由合法 review 子进程写入，非 touch 空文件）

**验证（可机器化）**：
```bash
change_id="independent-review-gap"
for phase in 3 5 7; do
  review_file=".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
  done_file=".specs/${change_id}/.independent-review-${phase}.done"
  # 检查 REVIEW 文件存在且含 L2 盲审段（非空标题）
  test -s "$review_file" || { echo "FAIL: $review_file missing or empty"; exit 1; }
  grep -q "L2 盲审" "$review_file" || { echo "FAIL: $review_file missing L2 section"; exit 1; }
  grep -q "Verdict" "$review_file" || { echo "FAIL: $review_file missing Verdict"; exit 1; }
  # 检查 done 文件存在
  test -f "$done_file" || { echo "FAIL: $done_file missing"; exit 1; }
done
echo "AC-7 PASS"
```

> 注：若 dry-run fixture 环境不可用，变通方案：在 bats 中创建 fixture 子目录，复制必要 prompt 文件，用脚本模拟主 agent 的 L2 调度行为（写 INDEPENDENT-REVIEW + done），然后运行以上验证脚本。此变通方案与 AC-6 的 bats 模式一致。

## 范围切分

### v1（本次必做）
- 3-task.md / 5-test.md / 7-integration.md 各加「独立 review 调度」段（AC-1）
- PRESET_MAP 补 3 个单阶段预设（AC-2）
- PRESET_MAP 补 5 个组合预设（AC-3）
  - task-review / test-review / task-test / task-test-review / spec-test
- L2-blind-review.md 扩展 3/5/7 checklist（AC-4）
- SKILL.md gate-config 合法值列表更新（AC-5）
- pipeline-gates.md 说明文字同步（AC-5）
- bats 测试覆盖新预设（AC-6）
- check-gate-sync.sh set-diff 通过
- bats 全量回归不退化（目标 ≥ 216 pass）

### v2（下次再说）
- 4-dev 独立审查段（执行阶段审查发生在 6-review，4-dev 已有 1.8 自检 gate）
- 3/5/7 独立审查的回归演示（regression-demo）

### out（永远不做）
- 给 0-change 加独立审查（变更提案是人工决策密集阶段，不适合自动化盲审）
- 改变现有 1/2/6 独立审查机制（prompt 段 / hook 层 / done 文件命名均不变）
- 修改 hook 层（已在 gate-integrity 中完成 3/5/7 扩展）
- L3 在 3/5/7 的验证（已在 gate-integrity 中交付，本次仅涉及 L2 prompt 调度层）

## 非功能性需求

### 兼容性
- 现有 1/2/6 独立审查行为不变
- 现有 8 个 PRESET_MAP 预设名解析结果不变
- 现有数字映射（1→1-requirement 等）不变

### 可维护性
- 新增 prompt 段与现有 1/2/6 模式一致（复制结构，替换阶段参数）
- PRESET_MAP 新增预设遵循现有命名约定：单阶段用阶段名、组合用 `阶段1-阶段2` 连字符

### 测试
- bats 全量回归不退化（当前 216 tests pass，目标 ≥ 216 pass）
- 新增预设的 bats 测试用例全部 pass

### 安全性
- 本次变更不引入新的攻击面：done 文件写入路径限定在 `.specs/<change-id>/` 内，与现有 1/2/6 的 done 文件同目录同一权限模型
- L2-blind-review.md 子 agent 指令为固化模板文本，无用户输入拼接 → 无指令注入风险
- 子 agent 调用隔离由 Claude Code Agent 工具自身沙箱保证（非本次变更范围）
- 结论：安全风险等级 = 低（与现有 1/2/6 独立审查同等）

### 性能
- prompt 文本增加约 50-80 行/文件（3 个文件），单次推理 token 增量约 1.5k-2.5k
- 预计单次推理延迟增加 < 3%，在可接受范围内
- 独立审查不在关键路径上（异步子 agent + Stop hook），不影响交互响应延迟

### 可观测性
- 主 agent 在进入独立审查阶段时，prompt 要求其显式输出 `🔍 L2 独立审查已调度（阶段 <N>）`
- L2 子 agent 完成后，主 agent 应输出 `✅ L2 审查完成，verdict: pass|fail`
- `.done` 写入后，主 agent 应输出 `🚦 gate cleared，可继续推进`
- 以上输出约定写入各 prompt 的「独立 review 调度」段，不依赖外部日志系统

### 错误处理
- L2 子 agent 调用失败（超时 / API error / 返回空内容）→ `.done` 不写入，pipeline 阻塞在当前阶段；主 agent 应输出 `❌ L2 审查失败：<原因>，pipeline 暂停，等待人工介入`
- L2 审查 verdict=fail → `.done` 不写入，pipeline 阻塞；主 agent 输出 `⛔ L2 审查 verdict: fail，pipeline 暂停`
- L2 审查 verdict=pass → `.done` 正常写入，pipeline 继续推进
- `.done` 文件写入失败（磁盘满 / 权限不足）→ 主 agent 输出错误并暂停，不静默跳过
- L3 连续失败 ≥3 次（与 1/2/6 相同机制）→ Stop 报告提示「允许手动绕过」，可凭提示手动 touch 继续
