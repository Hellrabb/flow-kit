# 独立审查 · 阶段 3

## L2 盲审

> 审查日期：2026-08-02
> 审查工件：`.specs/superpowers-v6-absorb/TASK.md`（参考 REQUIREMENT.md、DESIGN.md）
> 审查员：L2 独立盲审员

---

### 🟡 R1 · Missing DESIGN deliverable：scripts/.gitignore 无对应 task

**Symptom（症状）**：DESIGN.md:43 新增模块清单明确列出 `flow-kit-bundle/flow-kit/scripts/.gitignore（新 · 防止 scripts/ 临时输出文件入库）`，但 TASK.md 12 个 task 的 write_files 中无一包含此文件。T01 写 `scripts/review-package`，T02 写 `scripts/task-brief`，无人写 `scripts/.gitignore`。

**Source（源头）**：DESIGN § 0.5.1 新增模块清单要求该文件存在；AC-I2（现有测试不退化）间接要求交付物完整。

**Consequence（后果）**：若 scripts/ 目录后续产生临时输出（如 task-brief 的中间文件），可能被误 git add 污染仓库。低概率但零成本可修复。

**Remedy（修补）**：任选其一：
- A) T01 write_files 追加 `flow-kit-bundle/flow-kit/scripts/.gitignore`，action 段加一行"创建 scripts/.gitignore，内容 `*.tmp\n*.out`"；或
- B) 新增 T01a（cheap，1 min）：仅创建 scripts/.gitignore，depends_on T01。

---

### 🟡 R2 · T09 verify 命令覆盖不完整：遗漏两处 @see 引用校验

**Symptom（症状）**：T09:294 verify 命令为：
```
grep -q "plan-conflict-scan" 3-task.md &&
grep -q "terse-contract.md" 5-test.md &&
grep -q "narration-constraint.md" 7-integration.md &&
grep -q "MINOR-DEFERRED" 7-integration.md
```
但 T09 action 明确要求：
- B) 5-test.md 顶部加 narration-constraint.md @see 引用 **+** terse-contract.md @see 引用（两个都要）
- C) 7-integration.md 顶部加**同样两个** @see 引用（两个都要）

verify 仅检查了 5-test→terse 和 7-integration→narration，漏了 5-test→narration 和 7-integration→terse。若实现漏加其中任一个，verify 会假绿通过。

**Source（源头）**：T09 action 段 B/C 子步骤描述 vs verify 命令不对齐。

**Consequence（后果）**：5-test.md 或 7-integration.md 可能缺少 narration/terse 引用，导致 AC-C1/AC-C2 部分未满足但 verify 通过。

**Remedy（修补）**：verify 命令改为四个 grep（或等价）：
```
grep -q "narration-constraint.md" flow-kit-bundle/flow-kit/prompts/5-test.md &&
grep -q "terse-contract.md" flow-kit-bundle/flow-kit/prompts/5-test.md &&
grep -q "narration-constraint.md" flow-kit-bundle/flow-kit/prompts/7-integration.md &&
grep -q "terse-contract.md" flow-kit-bundle/flow-kit/prompts/7-integration.md
```

---

### 🟡 R3 · T08 bats 测试未覆盖 AC-F4（旧 .flow-active 向后兼容）

**Symptom（症状）**：Phase 2 L2 R1-R4 映射表（TASK.md:430）将 R2（task_progress 兼容性测试）分配给 T08。AC-F4（REQUIREMENT.md:165-169）明确要求验证"旧 .flow-active（无 task_progress 字段）→ 视为 []"。但 T08 的 test_model_tier.bats 仅含 4 个 model-tier 相关测试（cheap/standard/fallback/jq 模板），无 AC-F4 兼容性测试用例。

**Source（源头）**：AC-F4（REQUIREMENT § 类别 F）+ Phase 2 L2 R2 映射 → T08 应覆盖，但 test_model_tier.bats 测试清单未纳入。

**Consequence（后果）**：若 4-dev.md 中 task_progress jq 解析逻辑未正确处理旧 `.flow-active` 缺字段场景，可能导致 `jq: null (null) and array ([]) cannot be added` 类运行时错误，阻塞既有用户 pipeline。低概率但回归影响高。

**Remedy（修补）**：test_model_tier.bats 追加第 5 个测试用例：构造无 task_progress 字段的 mock `.flow-active` → 断言 `jq '(.goal.task_progress // []) | length'` 返回 `0`。

---

### 🟢 R4 · T08 对 T04 存在隐式依赖，depends_on 未声明

**Symptom（症状）**：T08 read_files 列出 `flow-kit-bundle/flow-kit/reference/narration-constraint.md <!-- T04 -->`（T04 产出），但 T08 depends_on 仅声明 `T02`。T04 不在 depends_on 中。

**Source（源头）**：T08 的 action 第 1 步"顶部加 narration-constraint.md @see 引用"依赖 T04 产出的 narration-constraint.md 文件存在。

**Consequence（后果）**：当前无实际后果——T04（Wave 1）在 T08（Wave 2）之前完成，隐式依赖被波次结构兜底。但若未来维护时重排波次或使 T08 与 T04 同 Wave，可能 race condition 导致 T08 在 narration-constraint.md 不存在时执行。

**Remedy（修补）**：T08 depends_on 追加 `T04`（即 `depends_on` 改为 `T02, T04`）。

---

### 🟢 R5 · T01/T02 read_files 引用尚不存在的目录

**Symptom（症状）**：T01:28、T02:57 均列出 `flow-kit-bundle/flow-kit/scripts/*` 作为 read_files。但 scripts/ 目录在 T01 执行前不存在（本 change 新建），glob 匹配 0 文件。

**Source（源头）**：预读新目录以了解上下文，但目录为空。

**Consequence（后果）**：无功能影响——glob 无声匹配 0 文件，不报错。但 AI 在 read_files 阶段做一次无效 glob，浪费可忽略的 IO 时间。不影响执行正确性。

**Remedy（修补）**：删除此行，或改为注释 `<!-- scripts/ 为本 task 新建，无既有文件 -->`。非阻塞。

---

### 🟢 R6 · T12 write_files 含 README.md 但 DESIGN 触碰模块未列出

**Symptom（症状）**：T12 write_files 含 `README.md`，但 DESIGN § 0.5.1 触碰模块清单中无 README.md。

**Source（源头）**：T12 action 说明"README.md 若提及 scripts/ 目录则同步（预期不需要）"，属于防御性写入。

**Consequence（后果）**：若 README 不涉及 scripts/ 目录，实际不需要修改，write_files 声明为过度声明（over-declaration）。若实现阶段 AI 为满足 write_files 清单而强行修改无变化的 README，会引入噪声 diff。

**Remedy（修补）**：T12 write_files 去掉 `README.md`，或在 action 段加显式 guard："仅当 `grep -q 'scripts/' README.md` 匹配时才修改"。

---

### 🟢 R7 · verify 命令中硬编码绝对路径，不可移植

**Symptom（症状）**：T01:49 / T02:78 / T06:184 / T08:261 / T11:358 共 5 个 task 的 verify 命令均以 `cd /home/hellrabbit/unisoc/flow-kit &&` 开头，硬编码了特定机器的项目路径。在另一台机器或 CI 环境中目录结构不同时，verify 命令会因 `cd` 失败而返回非零。

**Source（源头）**：TASK.md 头部声明 `项目工作目录：/home/hellrabbit/unisoc/flow-kit`，verify 命令以此为基准。

**Consequence（后果）**：跨环境执行 verify 需要手动修路径；CI 集成时需要 wrapper 脚本做路径替换。不阻塞本次 change（单环境开发），但降低可移植性。

**Remedy（修补）**：将固定路径改为变量或相对路径约定。如 `cd "$(git rev-parse --show-toplevel)" && npx bats test/...`，或约定 `PROJECT_ROOT` 变量。非本次阻塞。

---

**Verdict**: pass

**摘要**：12 个 task 结构完整，7 字段齐全，波次划分无环依赖，write_files 无禁动清单违规（T12 的 package-flow-kit.sh Part D 有明确的例外声明和 Phase 2 L2 R1 修复映射）。发现 3 个 🟡 Major（scripts/.gitignore 缺失、T09 verify 覆盖不完整、T08 AC-F4 bats 覆盖缺失）和 4 个 🟢 Minor（隐式依赖、空目录 read、README 过声明、硬编码路径）。无 🔴 Critical，故 verdict=pass。建议在 phase 4 实施前修复 3 个 🟡 项以避免验收遗漏。

---

## 主 agent 响应（superpowers-v6-absorb Phase 3）

> L2 verdict=pass（0🔴），进入 phase 4。3 🟡 Major 全部已 patch TASK.md。

### 🟡 Major（已修复）

- **R1（scripts/.gitignore 缺失）→ Fixed in TASK.md T01 write_files + action**：T01 write_files 加 `flow-kit-bundle/flow-kit/scripts/.gitignore`，action 段加 .gitignore 内容定义（*.tmp / *.log / __pycache__/ / .DS_Store）。
- **R2（T09 verify 覆盖不全）→ Fixed in TASK.md T09 verify**：T09 verify 加 `grep -q "narration-constraint.md" flow-kit-bundle/flow-kit/prompts/5-test.md` 和 `grep -q "terse-contract.md" flow-kit-bundle/flow-kit/prompts/7-integration.md` 两个新断言，覆盖 5-test narration 和 7-integration terse 引用。
- **R3（T08 缺 AC-F4 bats 测试）→ Fixed in TASK.md T08 action**：T08 test_model_tier.bats 加第 5 个测试用例"AC-F4 向后兼容：旧 .flow-active（无 task_progress 字段）jq 不报错，fallback 为 []"，对应 Phase 2 L2 R2 兼容性检查。

### 🟢 Minor（延后到 MINOR-DEFERRED.md · phase 6 创建）

- R4/R5/R6/R7 → 全部按 ADR-017 severity gating 协议延后到 `.specs/superpowers-v6-absorb/MINOR-DEFERRED.md`，phase 6 创建。

### 修复后自评

- Verdict 维持 pass（L2 已 pass，无 🔴）
- TASK.md 3 🟡 全部 patched
- 不修改 L2 原文
