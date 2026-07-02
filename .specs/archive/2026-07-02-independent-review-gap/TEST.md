# TEST: 补齐 L2/L3 独立审查 3/5/7 缺失

> 本次 change 为 meta/配置变更（prompt 模板 + PRESET_MAP + L2 checklist），无运行时代码。测试聚焦静态验证 + 配置一致性。

## 本次测试范围声明

| 轮次 | 名称 | 状态 | 说明 |
|---|---|---|---|
| 1 | 功能 | ✅ 已跑 | bats 预设解析 + AC 验证脚本 |
| 2 | 性能 | ⏭ 跳过 | 无运行时代码，prompt 增量 < 150 行 |
| 3 | 安全 | ⏭ 跳过 | 无新攻击面（DESIGN §6 已评估） |
| 4 | 兼容 | ✅ 已跑 | bats 全量回归无新增失败 |
| 5 | 可观测 | ⏭ 跳过 | 无运行时日志变更 |

## 第 1 轮 · 功能测试

### 1.1 PRESET_MAP 预设解析

**AC 覆盖**：AC-2, AC-3, AC-6

```bash
npx bats flow-kit-bundle/test/test_gate_config_presets.bats --filter "preset"
```

**结果**：19/19 ok（含 8 个新增预设：task/test/integration/task-review/test-review/task-test/task-test-review/spec-test）

### 1.2 Prompt 静态结构检查

**AC 覆盖**：AC-1

```bash
for f in 3-task 5-test 7-integration; do
  grep -q "独立 review 调度" ~/.claude/flow-kit/prompts/$f.md
  grep -q "L2.*独立子 agent 盲审" ~/.claude/flow-kit/prompts/$f.md
  grep -q "L3.*Stop hook" ~/.claude/flow-kit/prompts/$f.md
  grep -q "touch.*independent-review" ~/.claude/flow-kit/prompts/$f.md
  grep -q "错误处理" ~/.claude/flow-kit/prompts/$f.md
done
```

**结果**：3/3 PASS

### 1.3 L2-blind-review.md checklist 内容质量

**AC 覆盖**：AC-4

```bash
for phase in 3 5 7; do
  section=$(sed -n "/^### 阶段 $phase/,/^### 阶段/p" ~/.claude/flow-kit/prompts/independent/L2-blind-review.md)
  entry_count=$(echo "$section" | grep -cE "^- \*\*" || true)
  [ "$entry_count" -ge 3 ]
done
```

**结果**：阶段 3=5 条, 阶段 5=5 条, 阶段 7=5 条，全部 ≥ 3

### 1.4 全链路同步检查

**AC 覆盖**：AC-5

```bash
grep -q "3-task" flow-kit-bundle/skills/flow/SKILL.md
grep -q "5-test" flow-kit-bundle/skills/flow/SKILL.md
grep -q "7-integration" flow-kit-bundle/skills/flow/SKILL.md
grep -q "independent-review-gap" ~/.claude/flow-kit/reference/pipeline-gates.md
```

**结果**：4/4 PASS

## 第 4 轮 · 兼容性测试 · 回归

**AC 覆盖**：AC-6（bats 全量不退化）

```bash
npx bats test/
```

**结果**：216 tests total，202 pass，14 fail（全为既有问题：correction_file / onecli / API path，与本次变更无关）。0 新增失败。

## UAT 脚本

```bash
#!/bin/bash
# UAT: 验证 independent-review-gap change 完整性
set -euo pipefail

echo "=== UAT: independent-review-gap ==="

# 1. 新预设可解析
echo "--- 1. 预设解析 ---"
for preset in task test integration task-review test-review task-test task-test-review spec-test; do
  npx bats flow-kit-bundle/test/test_gate_config_presets.bats --filter "preset '$preset'" 2>&1 | grep -q "^ok " || { echo "FAIL: preset $preset"; exit 1; }
  echo "  $preset: ok"
done

# 2. Prompt 含独立审查段
echo "--- 2. Prompt 段 ---"
for f in 3-task 5-test 7-integration; do
  grep -q "独立 review 调度" ~/.claude/flow-kit/prompts/$f.md || { echo "FAIL: $f"; exit 1; }
  echo "  $f: ok"
done

# 3. L2 checklist 条目充足
echo "--- 3. L2 checklist ---"
for phase in 3 5 7; do
  section=$(sed -n "/^### 阶段 $phase/,/^### 阶段/p" ~/.claude/flow-kit/prompts/independent/L2-blind-review.md)
  count=$(echo "$section" | grep -cE "^- \*\*" || true)
  [ "$count" -ge 3 ] || { echo "FAIL: phase $phase only $count entries"; exit 1; }
  echo "  阶段 $phase: $count entries"
done

# 4. 全链路引用
echo "--- 4. 全链路引用 ---"
grep -q "independent-review-gap" ~/.claude/flow-kit/reference/pipeline-gates.md || { echo "FAIL: pipeline-gates.md"; exit 1; }
echo "  pipeline-gates.md: ok"

echo "=== UAT PASS ==="
```

**UAT 执行结果**：全部 4 项检查 PASS

## AC 覆盖矩阵

| AC | 描述 | 测试轮次 | 结果 |
|---|---|---|---|
| AC-1 | Prompt 模板补全 | 1.2 静态检查 | ✅ |
| AC-2 | PRESET_MAP 单阶段预设 | 1.1 bats | ✅ |
| AC-3 | PRESET_MAP 组合预设 | 1.1 bats | ✅ |
| AC-4 | L2-blind-review.md 扩展 | 1.3 内容检查 | ✅ |
| AC-5 | 全链路同步 | 1.4 引用检查 | ✅ |
| AC-6 | bats 测试覆盖 | 1.1 + 回归 | ✅ |
| AC-7 | `all` 预设端到端 | 手工验证（dry-run fixture） | ⚠️ 见注 |

> 注：AC-7 端到端需要真实 pipeline 环境（gate_config["3-task"]="independent" + 主 agent 进入阶段 3），当前 dry-run fixture 环境不具备。建议在下次真实 pipeline 运行中验证（如本 change 自身的 7-integration 阶段）。
