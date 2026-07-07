
---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-06 13:34）

> 自动生成于 2026-07-06 13:34。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "AC-4 flow skill 预设兼容",
      "issue": "AC-4 要求 `--gate-config review` 预设写入 `"both"`，但 US-3 明确要求已有的 `--gate-config review` 预设行为不能变（向后兼容）。文档内部矛盾：若原预设映射为 `"independent"`，则此改动破坏兼容性；若原预设映射为 `"both"`，则 AC-4 强调"非 `'independent'`" 多余且易混淆。",
      "why": "验收准则与用户故事直接冲突，导致实现方向不明确，无法保证向后兼容。",
      "fix": "明确 `review` 预设的原始映射值（例如在 CONTEXT.md 或 CHANGE.md 中记录），然后调整 AC-4 使其与 US-3 一致：若原为 `"independent"` 则应保持；若原为 `"both"` 则删除"非 `'independent'`" 的注释。"
    }
  ],
  "major": [],
  "minor": [],
  "verdict": "fail",
  "summary": "工件存在内部矛盾：AC-4 与 US-3 冲突，可能导致向后兼容性破坏，无法通过验收。"
}
```

---

## L2 盲审（同会话子 agent · 2026-07-06）

> 审查对象：`.specs/l2-l3-granular-gate/REQUIREMENT.md` vs `.specs/l2-l3-granular-gate/CHANGE.md`
> 审查标准：AC 可验证性、范围合理性、边缘情况覆盖、CHANGE.md 对齐

### 审查结论

```json
{
  "critical": [
    {
      "file": "AC-3 + T04 prompt L2 调度段",
      "issue": "AC-3 要求 gate_config='independent' 或 'true' 时 L2 应正常执行（Given: gate_config 为 'both' / 'independent' / 'true'），但 T04 明确将 prompt 中 L2 检测条件从 {independent, true} 改为 {L2, both}，移除了 'independent' 和 'true'。这意味着已有 .flow-active 文件中值为 'independent' 的 session，AI prompt 层将无法触发 L2 盲审——AI 读 raw .flow-active 看到 'independent'，prompt 只告诉它检查 {L2, both}，匹配失败。注：bash hook 层通过 fk_independent_review_gate_active 的映射函数不受影响，但 AI prompt 层直接读文件，不走该函数。",
      "why": "映射函数 fk_independent_review_gate_active 仅用于 bash 组件（hooks/done-validation），AI prompt 层直接读取 .flow-active 并做集合成员判断，不经过映射函数。prompt 检测集合缩小后，旧值 'independent'/'true' 的 session 从 prompt 层看就是 'L2 未开启'。",
      "fix": "prompt L2 调度段的检测集合需包含旧值别名。两种方案：(A) prompt 检测集保留 {L2, both, independent, true}，独立声明 'independent' 和 'true' 等价于 both；(B) 在 .flow-active 写入层强制规范化，将所有旧值在写入时立即转为 'both'，但需处理已有 session——需在 SessionStart 或 prompt 入场 jq 中做归一化。推荐 (A)+(B) 双保险：写入层规范化 + prompt 检测集保留旧值别名作为兜底。"
    },
    {
      "file": "AC-4 flow skill 预设兼容 + US-3 向后兼容",
      "issue": "US-3 声称 '已有的 'independent' 值和 --gate-config review 预设行为不能变'。AC-4 要求 review 预设写入 'both'（非 'independent'），且 DESIGN 9.5 明确 'gate_config 值不允许写入 independent（已废弃，保留读取兼容）'。写入值从 'independent' 变为 'both' 是否违反 '预设行为不能变' 取决于对 '行为' 的定义——若指运行时效果（L2+L3 双开），则不变；若指写入的字节值，则变了。AC-4 描述中 '(非 'independent')' 的强调暗示了有意识的偏差，但没有解释为何这不违反 US-3。",
      "why": "AC-4 与 US-3 之间的 tension 未在文档中澄清。若有任何外部工具/脚本直接读取 .flow-active 并检查字符串值 'independent'（不走 fk_independent_review_gate_active），写入值变化会导致其行为改变。",
      "fix": "在 AC-4 的 Then 子句中补充一句澄清：'运行时效果不变（L2+L3 均执行），仅存储值从 'independent' 规范化为 'both'；解析层已映射 'independent'→'both'（见 AC-3）。' 同时在 DESIGN 中记录这是一个写入层规范化变更，不影响向后兼容的运行时语义。"
    }
  ],
  "major": [
    {
      "file": "AC-5 新 flag 支持（缺失 --l3-only 的对称 AC）",
      "issue": "AC-5 仅覆盖了 --l2-only flag（Given: --gate-config review --l2-only, Then: gate_config='L2'），v1 范围明确列出了 --l2-only 和 --l3-only 两个 flag，T02 也覆盖了两个。但 REQUIREMENT 中没有对称的 AC 验证 --l3-only flag 将 gate_config 写入 'L3'。",
      "why": "缺少独立验收标准意味着 --l3-only 的实现无明确验收点，可能在 review 时被遗漏。",
      "fix": "新增 AC-5b：Given 用户执行 /flow goal \"test\" --pipeline --gate-config review --l3-only, When flow skill 处理, Then gate_config[\"6-review\"] = \"L3\". 验证方式: .flow-active 中 gate_config 值为 \"L3\"."
    },
    {
      "file": "缺失 AC: --l2-only + --l3-only 冲突",
      "issue": "DESIGN 4 风险 R3 明确识别了 --l2-only + --l3-only 同时传入 → 冲突 场景，缓解方案为 flow skill 解析时后者覆盖前者 + 打印 warning。但 REQUIREMENT 中无任何 AC 覆盖此冲突处理行为。",
      "why": "若未通过 AC 验证此冲突场景，实现可能遗漏 warning 打印或覆盖方向错误，导致静默的未预期行为。",
      "fix": "新增 AC: Given 用户同时传入 --l2-only 和 --l3-only (如 /flow goal \"test\" --gate-config review --l2-only --l3-only), When flow skill 处理, Then 后传入的 flag 覆盖前者（此处 --l3-only 在后 → gate_config 最终为 \"L3\"），并打印 warning 提示冲突。"
    },
    {
      "file": "AC-7 gate 拦截 done 判定适配",
      "issue": "AC-7 的验证方式写的是 independent-review-gate.sh 的 done 检查逻辑按 tier 判定，这是对实现行为的描述，不是可执行的测试命令。对比 AC-1 的验证方式：具体的 fk_independent_review_gate_active \"6\" \"L2\" 返回 0/1。AC-7 缺乏任何可独立验证的验收点。",
      "why": "无法在 review 阶段独立验证 done 拦截逻辑是否正确。实现者可能按自己理解实现，与需求偏差在最后才能在集成测试中发现。",
      "fix": "提供具体验证步骤：(a) 模拟 gate_config='L2' + 仅 L2 done 存在 → gate 放行；(b) 模拟 gate_config='L3' + 仅 L3 done 存在 → gate 放行；(c) 模拟 gate_config='both' + 仅 L2 done 存在 → gate 拦截；(d) 模拟 gate_config='both' + L2+L3 done 均存在 → gate 放行。每项对应一个 bats 测试或明确的 shell 验证命令。"
    },
    {
      "file": "--l2-only/--l3-only flag 对多阶段 gate_config 的作用范围未定义",
      "issue": "AC-5 仅用 review 预设（单阶段 phase 6）作为示例。T02 写明 flag 应 覆盖 gate_config 所有 phase。但 REQUIREMENT 未定义 --l2-only 在 full 预设（多阶段 1,2,6 或 1,2,3,5,6,7）下的行为——是所有 phase 都变为 L2？还是仅 phase 6？若为全 phase，--l2-only 的语义暗示了这一点，但 AC 中未明确。",
      "why": "用户对 flag 作用范围的预期可能不同——有人期望只影响 review 阶段，有人期望全阶段。无明确规范会导致实现随意或用户困惑。",
      "fix": "在 AC-5 中补充 scope 说明：--l2-only 和 --l3-only 作用于 gate_config 的所有 phase（非仅 6-review），覆盖预设的值。 并附加一个多阶段验证例子（如 --gate-config full --l2-only 验证所有 phase value 为 L2）。"
    }
  ],
  "minor": [
    {
      "file": "缺失 AC: gate_config 为空/未设置/非法值时的行为",
      "issue": "DESIGN 三值判定表明确定义了 其他/空 → L2 ❌ L3 ❌ 无。T01 也定义了映射逻辑（非法值 → '' → 未开启）。但 REQUIREMENT 中没有任何 AC 验证 gate_config 缺失、为空字符串、或为非法值（如 foo, l2 小写）时的行为。",
      "why": "边界行为未通过 AC 定义，可能在不同组件中有不同实现（prompt 层 vs hook 层），导致不一致。",
      "fix": "新增 AC 覆盖三种边界情况：(a) gate_config 键缺失 → fk_independent_review_gate_active 返回 1；(b) gate_config 值为非法字符串 → 返回 1；(c) gate_config 值为空字符串 → 返回 1。"
    },
    {
      "file": "AC-6 验证方式不够具体",
      "issue": "AC-6 的验证方式写的是 bats 测试——模拟 29 号 hook 执行，验证 L3 段未写入，但未给出测试名、测试文件路径或验证的具体命令。对比 AC-1 的具体命令格式差异明显。",
      "why": "review 阶段无法独立评估 L3 hook 跳过行为。",
      "fix": "补充具体的验证方式：如 test/test_l2_l3_granular_gate.bats 中 test_l3_skipped_when_l2_only 测试：设置 gate_config='L2'，source 29-independent-review.sh 模拟执行，检查 stderr 含 L3 skipped 且 INDEPENDENT-REVIEW-N.md 不含 L3 段标记。"
    },
    {
      "file": "v1 范围 6 个阶段 prompt 未列出具体哪些 prompt + Phase 4 排除无说明",
      "issue": "REQUIREMENT.md v1 范围写 6 个阶段 prompt 的「独立 review 调度」段：L2 开关判定逻辑更新 但未列出具体文件。DESIGN.md 0.5.1 列出了 1/2/3/5/6/7（共 6 个），排除了 phase 4 (4-dev.md)。Phase 4 排除是合理的（dev 阶段不产独立审查产物），但 REQUIREMENT 中未记录此决策理由。",
      "why": "阅读者可能质疑为什么 8 个阶段只有 6 个 prompt 被改动，需要到 DESIGN 才能找到答案。",
      "fix": "在 REQUIREMENT v1 范围中补充范围说明：6 个阶段 prompt（1-requirement / 2-design / 3-task / 5-test / 6-review / 7-integration）的 L2 调度段。Phase 4 (dev) 不涉及独立审查产物生成，不在 L2 调度范围内。"
    },
    {
      "file": "AC-3 independent/true 映射验证缺乏具体测试命令",
      "issue": "AC-3 验证方式写 '\"independent\" 和 \"true\" 在 fk_independent_review_gate_active 中被映射为 both'，但不像 AC-1/AC-2 那样给出期望返回值的具体命令。如 gate_config='independent' 时 fk_independent_review_gate_active '6' 'L2' 应返回 0，fk_independent_review_gate_active '6' 'L3' 应返回 0。",
      "why": "缺少具体返回值预期使测试编写者需要推断正确行为。",
      "fix": "补充验证命令示例：fk_independent_review_gate_active \"6\" \"L2\" 在 gate_config=\"independent\" 时返回 0；fk_independent_review_gate_active \"6\" \"L3\" 同样返回 0。true 同理。"
    },
    {
      "file": "AC-8 硬编码测试数 >=309",
      "issue": "AC-8 要求 全部 bats 测试通过（>=309 tests）。309 是当前测试基线，但若后续 commit 因其他 change 增删测试，这个数字会漂移。硬编码测试数在 AC 中使 AC-8 对基线变化不具备弹性。",
      "why": "非本 change 引入的测试数变化会导致 AC-8 形式上的 false negative。",
      "fix": "改为 全部 bats 测试通过（>=当前测试基线数量，无回归），新增 L2/L3 开关相关测试覆盖三种模式。基线数由运行时的 npx bats --count 动态确定，不在 AC 中硬编码。"
    }
  ],
  "verdict": "fail",
  "summary": "REQUIREMENT.md 存在 2 项 Critical、4 项 Major、5 项 Minor 问题。最严重的两个 Critical 问题：(1) prompt L2 调度段的检测集合移除 independent/true 导致已有 .flow-active session 中 AI prompt 层无法触发 L2 盲审——与 AC-3 向后兼容承诺矛盾；(2) AC-4 写入值从 independent 变为 both 与 US-3 预设行为不能变的 tension 未澄清。Major 问题包括缺少 --l3-only 的对称 AC、缺少 flag 冲突 AC、AC-7 不可独立验证、flag 多阶段作用域未定义。建议修复所有 Critical 和 Major 后再进入实施。"
}
```

---

# 独立审查 · 阶段 1

L2_verdict=fail
