# REVIEW: L3 审查工具超时/token 上限可配置化

- **Change ID**: l3-review-timeout-token
- **关联**: `@.specs/l3-review-timeout-token/` 全部产物
- **审查日期**: 2026-07-25

---

## 变更概要

| 文件 | 改动 | 说明 |
|------|------|------|
| `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | +50/-6 | `_l3_call_api()` 三 env var（MAX_TOKENS/TIMEOUT/THINKING）可配 + Fail-safe + 可观测性 + jq -c compact |
| `test/test_l3_review.bats` | +19/-46 | 删 2 旧硬编码断言 + 重命名标签避编号碰撞 |
| `test/test_l3_review_params.bats` | 新增 25 测试 | stub curl 双路径 × AC-1~AC-7全覆盖 |
| `.specs/CONTEXT.md` | +6 术语 | L3 思考吃满预算 + 三 env var 术语 |
| `.specs/l3-review-timeout-token/*` | 11 产物文件 | CHANGE/REQUIREMENT/DESIGN/TASK + TEST/REVIEW + 4 SUMMARY + 3 INDEPENDENT-REVIEW |

---

## Spec 合规

| AC | 描述 | 覆盖 | 状态 |
|----|------|------|------|
| AC-1 | max_tokens 默认 32000 双路径 | T02 + test_l3_review_params.bats | ✅ |
| AC-2 | MAX_TOKENS env var 覆盖 | T02 + test_l3_review_params.bats | ✅ |
| AC-3 | timeout 默认 300 | T02 + AC-1 联测 | ✅ |
| AC-4 | TIMEOUT env var 覆盖 | T02 + test_l3_review_params.bats | ✅ |
| AC-5a/5b/5c | thinking 三取值双路径 | T02 + test_l3_review_params.bats | ✅ |
| AC-6 | Fail-safe 6 非法值回退 | T02 + 25 测试（10/12 双路径，path2 缺 MAX_TOKENS=空 + TIMEOUT=xyz——低风险：Fail-safe 逻辑在路径分支前共享） | ✅ |
| AC-7 | 可观测性 stderr | T02 + test_l3_review_params.bats | ✅ |
| AC-8 | 全量 bats 0 fail | T04 make test 606 ok | ✅ |
| AC-9 | 端到端冒烟（手动） | T04 rc=1 非 rc=3 | ✅ |
| AC-10 | 静默错判验证 | T01 探针 | ✅ |

**AC 合规**: 10/10 全覆盖 ✅

---

## 代码质量 6 维自查

| 维度 | 评估 | 详情 |
|------|------|------|
| R1 认知过载 | 🟢 | _l3_call_api 新增 ~30 行（env var 解析 + req_body 构造），函数体 ~70 行可接受。Fail-safe 用 `${VAR+x}` 检测 + case/switch 简单逻辑 |
| R2 变更传播 | 🟢 | 仅 l3-review.sh 1 文件，签名不变，2 处调用点（同文件内部）兼容 |
| R3 知识重复 | 🟢 | req_body 构造提取到公共段（if/else 分 thinking 分支），两路径共用 $req_body + $timeout |
| R4 偶然复杂 | 🟢 | thinking 条件分支是必要的（D3 决策），jq -c compact 是 d7a3f88 测出的合理优化，无过度设计 |
| R5 依赖混乱 | 🟢 | 依赖链清晰：env var > 默认值，不引入中间级（D6：2 级非 3 级链） |
| R6 领域扭曲 | 🟢 | 变量名 max_tokens/timeout/thinking 均领域词，无技术噪声 |

---

## 审查历史

本 change 在每个阶段经过 L2+L3 双层审查：

| 阶段 | L2 | L3 | 结果 |
|------|-----|-----|------|
| 1-requirement | 首轮 fail(8) → 重写 → 二轮 pass(4 残留) | pass(7 条) | ✅ |
| 2-design | pass(5) | 首轮 fail(3) → 二轮 pass(3) | ✅ |
| 3-task | pass(6) | pass(3) | ✅ |
| 4-dev | T01-T04 全 verified | — | ✅ |
| 5-test | pass(4) → Fixed in | — | ✅ |

---

## 已知限制

1. **R1b 静默错判风险**（DESIGN R2）：`_l3_parse_result` fallback 链 `.content[0].thinking // .content[0].text` 在极端情况（思考吃满 32k）可能提取思考内容当 verdict。本 change 不改解析（Out of Scope），disabled thinking 作为 escape hatch。T01 AC-10 探针确认：当前默认配置下不易触发（32k 实测 4872 token 占用 15%）。
2. **阿里云代理 32k 上限未经长期验证**：T01 R4 探针证实单次 HTTP 200，但未测持续负载下的稳定性。env var 可调作 escape hatch。
3. **非思考模型的替代方案未纳入**：`/flow model l3=<非思考模型>` 可绕过，但未纳入本 change scope（Out of Scope）。

---

## 结论

**本 change 完成且验证有效**。L3 工具的三 env var 可配化（max_tokens 8000→32000、timeout 90→300、thinking 可配）解套了 deepseek-v4-pro 大产物审查的 rc=3 问题。所有阶段产物齐全，AC 全覆盖，606 bats 全绿，端到端冒烟证实工具层解套。

**Verdict: pass** ✅（无阻塞性缺陷）
