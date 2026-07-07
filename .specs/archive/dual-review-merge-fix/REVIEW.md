# REVIEW: L2/L3 双层审查结果合并写入

- **Change ID**: `dual-review-merge-fix`
- **审查日期**: 2026-07-07
- **审查范围**: 14 files, +418/-24 lines
- **审查者**: AI Reviewer（内置回退 — brooks-lint 已装但本 change 为 Bash 脚本，走内置审查）

---

## 第一轮 · Spec 合规审查

对照 `REQUIREMENT.md` 的 8 条 AC，逐项检查代码覆盖：

| AC | 要求 | 覆盖文件 | 状态 |
|---|---|---|---|
| AC-1 | both L2-wait（29 hook + PreToolUse 双路径） | `29-independent-review.sh` (gate check + exit 0), `independent-review-gate.sh` (forward 分支 deny) | ✅ |
| AC-2 | L2 append-first 不覆写 L3 | `L2-blind-review.md`（文件写入约束段：先读→追加→禁覆写）, 6 prompt（追加指令） | ✅ |
| AC-3 | L3 `>>` 追加保留 L2 | `l3-review.sh` 的 awk 剥离 + `>>` 追加逻辑未改动（仅新增 D3 gate 段） | ✅ |
| AC-4 | both .done 延迟 | `l3-review.sh`（gate_config=both + 无 L2 → return 0 不写 .done）, `29-independent-review.sh`（skip L3 时 exit 0 不写 .done） | ✅ |
| AC-5 | 跨阶段一致性 | `done-validation.sh` phase_name case 覆盖 {1,2,3,5,6,7}（已存在，未改动） | ✅ |
| AC-6 | L2-only KVP .done | 6 prompt "写 done" 段均改为条件 KVP（含 `L3_verdict=skipped`） | ✅ |
| AC-7 | L3-only L2_verdict=skipped | `29-independent-review.sh`（`elif [[ "$gate_val" == "L3" ]]; then l2_verdict="skipped"`） | ✅ |
| AC-8 | .done 值域扩展 | `done-validation.sh` 已支持 `skipped`（line 137/139，未改动）；14 bats 测试覆盖 empty/fake/skipped 场景 | ✅ |

**结论**: 8/8 AC 全覆盖，无遗漏。

---

## 第二轮 · 代码质量审查

### 改动结构分析

```
flow-kit-bundle/hooks/stop/29-independent-review.sh      (+19/-0)  D1+D2
flow-kit-bundle/hooks/stop/lib/l3-review.sh              (+12/-0)  D3
flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh (+17/-0)  D1 PreToolUse
flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md (+12/-0)  D4
flow-kit-bundle/flow-kit/prompts/{1-7}/*.md (6 files)    (+15/-4 each) D4
.specs/CONTEXT.md                                         (+6/-0) 术语
.specs/dual-review-merge-fix/*                            (new) 产物
test/test_dual_review_merge.bats                          (new, 14 tests)
flow-kit-bundle/test/test_dual_review_merge.bats          (sync)
```

### 逐文件审查

#### 1. `29-independent-review.sh` (+19 lines) — ✅ 通过

- **D1 L2-wait**: `grep -q "^## L2 盲审"` + `module_output warning` + `exit 0` — 逻辑正确，fail-safe（阻塞 rather than 放行）
- **D2 skipped 默认值**: `elif [[ "$gate_val" == "L3" ]]; then l2_verdict="skipped"` — 仅 L3-only 时改写，both 保持 `fail`
- **gate_val 解析**: `jq -r '.goal.gate_config[$pn] // ""'` + case 标准化 — 与 `done-validation.sh` 的映射逻辑一致
- **phase_name case**: 覆盖 {1,2,3,5,6,7}，与 `done-validation.sh` 同步
- 无 shell 安全问题（变量均引用、无 eval、无未 sanitize 的用户输入插值）

#### 2. `l3-review.sh` (+12 lines) — ✅ 通过

- **D3 gate 检查**: 在 verdict 提取后、`.done` 写入前插入——位置正确，避免副作用
- **`return 0` 语义**: 非错误返回，仅延迟 `.done` 写入——调用方 `29-independent-review.sh` 的 `case $rc` 会落入 `*)` 分支（warning），行为安全
- **参数扩展**: `gate_config_value="${5:-both}"` 向后兼容——不传第 5 参数时默认 both
- **l2_verdict 值域**: `^(pass|fail|skipped)$` 扩展正确

#### 3. `independent-review-gate.sh` (+17 lines) — ✅ 通过

- **D1 PreToolUse 路径**: forward 分支内新增 gate_val 解析 + L2-wait 检查
- **deny 行为**: `exit 2` 阻断 transition——与现有 gate deny 机制一致
- **gate_val 解析与 29 号 hook 一致**: phase_name case + jq 读取 + 标准化映射

#### 4. `L2-blind-review.md` (+12 lines) — ✅ 通过

- "文件写入约束"段：三步指令清晰——Read→检查L3段→追加→禁覆写
- 与 6 prompt 的追加指令语义一致

#### 5. 6 phase prompts — ✅ 通过

- 每文件两处修改模式一致（L2 输出追加指令 + "写 done" KVP 条件化）
- 各阶段的 artifacts 列表正确对应 phase

### 发现项

| # | 严重度 | 文件 | 发现 |
|---|---|---|---|
| Q1 | 🟢 Minor | `29-independent-review.sh` | gate_val 解析的 3 个 case 分支（L2/L3/both/independent/true）与 `done-validation.sh` 的标准化映射重复。可提取为共享函数，但 v1 不改（v2 考虑） |
| Q2 | 🟢 Minor | `l3-review.sh` | `return 0` 在 D3 触发时让调用方误认为"成功"——实际是"延迟"。建议改 `return 4` 或专用 exit code 区分。当前 `99-report.sh` 和其他 consuming hooks 对其无特殊处理，影响极低 |

---

## 第三轮 · UI 审查

N/A — 非前端项目，跳过。

---

## 审查结论

| 轮次 | 结果 |
|---|---|
| 第一轮 · Spec 合规 | ✅ 8/8 AC 覆盖 |
| 第二轮 · 代码质量 | ✅ 通过（2 Minor，不阻塞） |
| 第三轮 · UI | N/A |

**Verdict**: ✅ **PASS** — 无 🔴 Critical 发现。建议合并后进入 7-integration。

---

## 门禁判定

| 检查项 | 级别 | 结果 |
|---|---|---|
| spec 合规（AC 未覆盖） | critical | ✅ 通过 |
| 代码质量 🔴 Critical | critical | ✅ 0 发现 |
| 代码质量 🟡 Major | warn | ✅ 0 发现 |
| 跨模型分歧 | warn | N/A（无 L2/L3 交叉对比——本 change 正是修此机制） |
