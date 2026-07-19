# REVIEW: L2/L3 独立审查 gate 残留缺陷根治（F/H/I/J + K）

- **Change ID**: l2-l3-mock-fix
- **Reviewer**: 主 agent（6-review）+ L2/L3 二次审查（gate_6=both · INDEPENDENT-REVIEW-6.md）
- **审查范围**: `git diff c00afb8..HEAD`（40 files +3640/-58 · 5 hook 源码 + 测试 + SPEC）
- **模式**: PR Review · brooks-lint 内置路径 B（context 限制未跑 skill 全套 shared；6 维诊断基于已读 5 hook 代码 + 5-test L2 证据）

> ⚠️ **状态演进（RR4 导航）**：本文件 verdict 经历 **pass（主 agent 初审）→ fail（L2 复核捕 R1/R2 critical）→ T-FIX 修复（commit 57b2669）→ L2 重审 pass**。**最新状态以末段「L2 复核修正」+「T-FIX 修复」为准**；下方「严重度汇总 0/0/0」「Verdict pass」（line ~92-98）为主 agent 初审**作废值**（漏判 R1/R2，L2 已纠正）。

---

## 第一轮 · Spec 合规审查

逐条 AC → 实现 + 测试覆盖：

| AC | 实现（文件） | 测试覆盖（TEST.md） | 合规 |
|---|---|---|---|
| AC-F | common.sh `fk_phase_gate_key` pure fn（D1） | test-phase-gate-key-pure-fn.bats + INT-7 forward deny | ✅ |
| AC-H | gate.sh `is_git_commit`/`is_gh_pr_create` 结构判定（D2） | test-is-git-commit-structural.bats 等价类 a-f | ✅ |
| AC-I | 29 D4 L2-first 双管 + correction（D3） | test-l2-first-correction.bats 两处 D4 门 | ✅ |
| AC-J | l3-review `_l3_check_rerun` 内容标记 + hash（D4） | test-l3-check-rerun-content-marker.bats 6 用例 | ✅ |
| AC-K | 26-workflow G1 pipeline 不 advance（D5） | test-pipeline-no-g1-autoadvance.bats 两路径 | ✅ |
| AC-T | 全套 bats 真绿 | 536 ok / 0 fail / exit=0 | ✅ |

- **out-of-scope 检查**：DESIGN §6 不在范围未触（7 Gate 控制流 / L2 盲审机制 / `_l3_call_api` / Stop 自动派 L2 均未改）✅
- **范围蔓延检查**：5 bug 修复 + pure fn 重构，无新功能 ✅
- **架构触动**：= DESIGN §0.5.1 声明范围（5 hook + common.sh pure fn）✅

---

## 第二轮 · 代码质量审查

### 2.0 TEST.md 5 轮金字塔完整性

✅ 5 轮状态明确（功能✅ / 性能✅ / 安全⚠️部分 / 兼容✅ / 可观测❌），跳过轮次有理由（Bash gate hook 项目）。第 1 轮 AC 6/6 覆盖，全套 536/0。

### 2.1 代码质量 6 维衰退风险（内置路径 B）

整体：本 change 是 **bug 修复 + pure fn 重构**，6 维**整体改善**（D1 消除重复 / D2 抽 helper / D4 删死代码）。

| 维度 | 诊断问题 | 本 change | 严重度 |
|---|---|---|---|
| R1 认知过载 | 理解成本 | ✅ 改善：D2 抽 `_command_has_write_context` + `_command_first_tokens` helper，降低 `is_git_commit` 认知负荷（结构判定比正则剥离更直观） | — |
| R2 变更传播 | 改一点坏多少 | ✅ 改善：D1 `fk_phase_gate_key` 单一来源，phase→key 映射改 1 处非 2 处 declare | — |
| R3 知识重复 | 决定多处表达 | ✅ 改善：D1 消除 2 处 `declare -A PHASE_GATE_KEY_MAP` 重复（NFR-4 grep=0 守护） | — |
| R4 偶然复杂 | 比问题更复杂 | ✅ 改善：D4 删 mtime stat 三 fallback（-c/-f/-r）死代码 ~22 行 → sha256sum 单调用；D5 守卫仅 1 jq + if 条件，最小侵入 | — |
| R5 依赖混乱 | 依赖方向 | ✅ gate.sh → common.sh（高→低 lib），方向一致；无循环 | — |
| R6 领域扭曲 | 忠实反映领域 | ✅ gate hook 领域（审查门禁 deny/allow/phase gate）忠实反映 | — |

**Source 引用**（6-review.md §2.1 表）：R1 Refactoring·DDD / R2 Refactoring·Clean Architecture / R3 Pragmatic·DDD / R4 Refactoring·Code Complete / R5 Clean Architecture / R6 DDD。

**无新 🔴/🟡**：5-test L2 R1（hash 闭环 artifact 缺失边界）/ R2（AC-J phase 5/6/7 覆盖）已 Tech-debt 登记（含计划），6-review 确认未恶化。

### 2.2 架构依赖检查（大型 change 触发评估）

触发条件：改 5 hook + common.sh pure fn（5 消费者），跨 ≥5 模块。评估：
- 无新顶级模块（沿用既有文件）
- 无危险 source（Bash 同层 lib，无业务→低层反向）
- D1 pure fn 单一来源**改善**依赖（消除重复 source）
- **无循环依赖**（common.sh 是叶子 lib，被 source 不 source 别人）

简化依赖图（方向一致 hook → lib）：
```
gate.sh ──source──→ common.sh (fk_phase_gate_key)
29-independent-review.sh ──source──→ common.sh + l3-review.sh
26-workflow.sh ──source──→ common.sh + flow-kit-artifacts.sh
l3-review.sh ──source──→ common.sh + done-validation.sh
```
无反向/循环/跨边界依赖。

---

## 第三轮 · UI 视觉审查

❌ **跳过**（Bash gate hook 项目，无 UI-DESIGN.md，diff 不涉 .css/.tsx/.vue/.html/.svelte）。

---

## 第四轮 · 补充审查

### 4.1 技术债评估
**未触发**（本 change 是 bug 修复，非里程碑/季度大版本/重构项目）。已知 Tech-debt（均含计划，非本次新增）：
- 5-test L2 R1：hash 闭环 artifact_file 缺失边界
- 5-test L2 R2：AC-J phase 5/6/7 覆盖增强
- bash 4.4 未实跑（仅 5.2 + 论证）

### 4.2 跨模型 spot-check
gate_6=both → 由 L2（code-reviewer 子 agent）+ L3（Stop hook）统一接管，产 INDEPENDENT-REVIEW-6.md（本 REVIEW.md 是待复核对象）。

---

## 严重度汇总

- 🔴 Critical: **0**
- 🟡 Major: **0**（5-test L2 R1/R2 已 Tech-debt，非新发现）
- 🟢 Minor: **0**（6 维整体改善，无新退化）

## 结论

**Verdict: pass**。spec 合规（AC 6/6 + 测试覆盖 + 全套 536/0）+ 代码质量 6 维整体改善（D1 消除重复 / D2 抽 helper / D4 删死代码）+ 架构依赖无恶化（无循环/反向）。无 🔴 Critical，无新 🟡 Major。可进 toll-gate 6→7。

## fix 任务

无（0 Critical + 0 新 Major）。Tech-debt 项（R1/R2/bash4.4）已登记含计划，随本 change commit。

---

## L2 复核修正（2026-07-19 · verdict 翻转 pass→fail）

> L2 code-reviewer 盲审 verdict=**fail**（实测确认）。主 agent 上述「Verdict pass / 0 Critical」**作废**——L2 复核 + 主 agent 实测复现确认：

### R1 🔴 Critical（主 agent 漏判）· AC-H(e) 重定向/多行 git commit 漏拦
- **实测**：`git commit -m x 2> log` / `$'a\ngit commit'` → gate **exit 0**（不 deny）
- **根因**：`_command_has_write_context`（gate.sh:114-116）把「重定向到非 /dev/null」+ 多行判为写上下文 → is_git_commit return 1（不 deny）
- **AC 违规**：AC-H(e)（REQUIREMENT:39）明文要求重定向 git commit → deny。**AC 未实现 + 测试 (d)(e) 漏覆盖重定向/多行**

### R2 🟡 Major（主 agent 漏判）· source COMMON_LIB fail-open
- **实测**：`HOOK_BASE_DIR=/tmp/nonexistent` → gate **exit 0**（fail-open）
- **根因**：gate.sh:27 `source "$COMMON_LIB" 2>/dev/null || true` + :447 `local phase_name="$(fk_phase_gate_key...)"`（local 屏蔽 set -e 得空）→ gate 失效
- **声明矛盾**：与 header :9 "review gate = fail-close" 矛盾

### 处置
Gate 失败暂停 → 用户选**回退 6→4**。T-FIX-01（R1）+ T-FIX-02（R2）追加 TASK.md。修完重跑全套 bats + 重审 L2/L3。

**修正 Verdict: fail**（1 🔴 R1 + 1 🟡 R2）。原「6 维整体改善」过度乐观——R4 偶然复杂度（write-context 过宽 + `|| true`）实为净倒退，主 agent 误判。

---

## T-FIX 修复（2026-07-19 · R1/R2 已修，待 L2/L3 复核）

> 回退 6→4 后 T-FIX-01/02 修复 R1/R2（commit 57b2669），重审 6-review。

### R1 → Fixed in: gate.sh `_command_has_write_context`（T-FIX-01）
收紧：**只 heredoc(<<) → 写上下文**；重定向/多行 → 走 token 判定 deny。补 e4-e7 测试。实测 `git commit 2>log` / 多行 git commit → deny ✓；heredoc 写报告 → 不 deny ✓。

### R2 → Fixed in: gate.sh source COMMON_LIB（T-FIX-02）
fail-close：source 后 `declare -f fk_phase_gate_key` 检查，未定义 → exit 2 + stderr 告警。补 R2 测试。实测 HOOK_BASE_DIR 错 → exit 2 ✓。

### verify（T-FIX 后）
- T-FIX 测（e4-e7 + R2 + 既有 a-f/NFR-3）：**20/20 pass**
- 全套 bats：**541 ok / 0 fail / exit=0**（+5 新测）
- 部署同步：gate.sh cp ~/.claude/hooks/（md5 46d992bf）

**修正 Verdict: 待 L2/L3 复核**（R1/R2 已 Fixed in 代码 + 测试，主 agent 自评待独立复核确认）。
