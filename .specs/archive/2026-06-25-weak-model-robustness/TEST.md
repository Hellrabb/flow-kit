# TEST: 提升 flow-kit 在弱模型（幻觉多）下的鲁棒性

- **Change ID**: weak-model-robustness
- **关联**: `@.specs/weak-model-robustness/REQUIREMENT.md`（7 AC）· 各 `T*-SUMMARY.md`

---

## 本次测试范围声明

本项目为 flow-kit 引擎 markdown 增强 + 静态 bats/demo 脚本（meta / distribution），**无运行时 / 无 DB / 无 API / 无 UI**。5 轮金字塔按适用性裁剪：

| 轮次 | 状态 | 范围 | 跳过理由（如跳过）|
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 7 AC（bats 结构 + demo check.sh + 回归） | — |
| 第 2 轮 · 性能 | ❌ 跳过 | — | meta 项目无运行时性能指标（无 QPS / LCP / bundle）。AC-7「啰嗦度」是唯一性能相关项，已用静态检查覆盖（`strong-model-verbosity/check.sh`），定量 token/turn 阈值留 v2 |
| 第 3 轮 · 安全 | ❌ 跳过 | — | 本次不引入依赖、不碰秘钥 / hooks / 执行机制 / 攻击面。无 `package.json` 变更，无秘钥，无 SAST 新增面 |
| 第 4 轮 · 兼容 | ❌ 跳过 | — | 无 schema 迁移 / 无 API / 无跨浏览器。「向后兼容」已由第 1 轮 AC-6（既有 94 bats 全绿）覆盖 |
| 第 5 轮 · 可观测 | ❌ 跳过 | — | 无运行时系统（无日志 / 指标 / 告警 / 健康检查） |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（每条 AC ≥ 1 覆盖）

| AC | 类型 | 用例文件 / 验证 | 状态 |
|---|---|---|---|
| AC-1 禁跳反问 | unit(structure) | `test/weak-model-robustness/no-skip-clarify.bats`（3 test）| ✅ |
| AC-2 禁幻觉/证据链 | demo(static) | `regression-demos/hallucination-guard/check.sh` | ✅ |
| AC-3 关键节点 checkpoint | unit(structure) | `test/weak-model-robustness/checkpoint-keynodes.bats`（3 test）| ✅ |
| AC-4 范围漂移防护 | demo(static) | `regression-demos/scope-drift-guard/check.sh` | ✅ |
| AC-5 goal 锚定 | unit(structure) | `test/weak-model-robustness/goal-anchored.bats`（2 test）| ✅ |
| AC-6 不破坏强模型路径 | regression | 既有 `test/*.bats` 94 个全跑 | ✅ (0 fail) |
| AC-7 强模型不啰嗦 | demo(static) | `regression-demos/strong-model-verbosity/check.sh` | ✅ (静态版；定量 v2) |

### 1.2 执行结果（可量化）

- **bats 结构测试**：`npx bats test/weak-model-robustness/*.bats` → **1..8，全 ok，0 fail**
- **demo check.sh**：hallucination-guard / scope-drift-guard / strong-model-verbosity → **3/3 PASS**
- **回归基线（AC-6）**：`npx bats test/*.bats` → **94 ok，0 not ok**（加固未破坏既有测试）
- **AC 覆盖**：7/7（100%）

### 1.3 覆盖率与边界

- **Coverage**: AC 覆盖率 7/7 = 100%（meta 项目无传统代码覆盖率，产物为 markdown 规则 + 静态脚本，以 AC 覆盖率计）。
- 边界用例：
  - 反问 gate：验"未完成禁止产出"措辞存在（正向）
  - checkpoint：验"非每操作"限定词存在（防过度加固边界）
  - 啰嗦度：反向 grep「每步复述 goal / 每次操作 checkpoint」= 不命中（防反噬边界）

### 1.4 测试质量自检 · 6 维测试衰退风险（路径 B · 内置清单）

> 未调 `/brooks-test` skill（全自动推进下用内置 6 维快查省 token；6 维维度源自 brooks-lint 同源书籍）。

| 维度 | 诊断 | 本 change 状况 |
|---|---|---|
| T1 晦涩 | 测试名读得出验证什么 | ✅ 测试名中文描述性（"RULES.md 含 R3.5 禁跳反问硬约束"），场景清晰 |
| T2 脆弱 | 重构会否让测试坏 | 🟢 轻微：grep 文本模式，若 RULES 措辞大改会坏；但验的是"硬约束存在"，措辞稳定。可接受 |
| T3 重复 | 多测试换姿势验同场景 | ✅ 3 个 bats 维度不同（反问/checkpoint/goal），无重复 |
| T4 mock 滥用 | mock 是否遮蔽真问题 | ✅ 无 mock，纯 grep 真实文件 |
| T5 覆盖率幻觉 | 高覆盖但断言空 | ✅ 每测 `[ "$status" -eq 0 ]` 实质断言，非空 |
| T6 架构错配 | 测试层级匹配架构 | ✅ 结构测试用 unit(grep)，层级匹配 |

命中 0 项必修、1 项 🟢 小问题（T2，记入下方记事）。**测试质量合格**。

### 测试质量记事

- 🟢 **T2 轻微脆弱**（`test/weak-model-robustness/*.bats`）：grep 文本模式依赖 RULES/prompt 措辞稳定。若未来大改措辞，需同步更新 bats 的 grep 模式。不阻塞本次，记入 backlog。

---

## 第 2~5 轮 · 跳过（理由见范围声明）

均不适用（meta 项目无运行时 / DB / API / UI / 可观测维度）。向后兼容由第 1 轮 AC-6 覆盖。

---

## 步骤 N · 回归测试登记

本次新增测试用例（未来 grep 可追溯）：

| 用例 | 类型 | 验证 | 文件 |
|---|---|---|---|
| 反问 gate 结构 | bats | AC-1 | `test/weak-model-robustness/no-skip-clarify.bats` |
| checkpoint 结构 | bats | AC-3 | `test/weak-model-robustness/checkpoint-keynodes.bats` |
| goal 锚定结构 | bats | AC-5 | `test/weak-model-robustness/goal-anchored.bats` |
| 证据链 demo | check.sh | AC-2 | `regression-demos/hallucination-guard/check.sh` |
| 范围漂移 demo | check.sh | AC-4 | `regression-demos/scope-drift-guard/check.sh` |
| 啰嗦度 demo | check.sh | AC-7 | `regression-demos/strong-model-verbosity/check.sh` |

---

## 结论

7 AC 全覆盖，11 个验证点全过，既有 94 bats 回归 0 失败。测试质量 6 维自检合格（1 🟢 小问题已记事）。第 2~5 轮不适用（附理由）。**进入 6-review**。
