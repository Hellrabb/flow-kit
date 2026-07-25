# REVIEW: 独立 review gate `.done` 作者性校验缺口修复

- **Change ID**: gate-done-authorship
- **审查日期**: 2026-07-25
- **方案**: 方案 A（彻底废弃握手 · path-guard D7 扩展保护 .done）

---

## 变更概要

| 文件 | 改动 | 说明 |
|------|------|------|
| `independent-review-gate.sh` | +55/-16 | `_is_dotdone_write` + `_gate_is_l2_only` + 重写 `_gate_path_guard` 保护 .done |
| `done-validation.sh` | -24/+6 | 删 T3 握手校验 + T3b SESSION_ID · T4 L2 比对保留 |
| `29-independent-review.sh` | -18/+3 | Gate 4 改用 .done 幂等 · Gate 5 删 state_file · L202-204 清理 |
| `test_gate_integrity.bats` | +73/-27 | 23 tests: D7 path-guard 改写 + AC-6 payload + AC-4 L2-only + T4 负向 |
| `regression-demos/` | 引用更新 | `is_handshake_write` → `_is_dotdone_write` |

---

## Spec 合规

| AC | 覆盖 | 状态 |
|----|------|------|
| AC-1 agent 伪造 .done 被拦截 | D7 path-guard 6 测试 + AC-6 payload | ✅ |
| AC-2 合法 .done 放行 | D9 正向 + T4 L2 一致（transition return 0） | ✅ |
| AC-3 握手死代码清理 | `is_handshake_write`/`state_file`/`written_by=stop-hook-29` 全删 + 死代码 grep 0 匹配 | ✅ |
| AC-4 L2-only 例外 | `_gate_is_l2_only` + AC-4 测试（exit 0） | ✅ |
| AC-5 既有测试改写 | 23 tests（D7 + 集成 + T4 负向） | ✅ |
| AC-6 payload 集成测试 | AC-6 payload 测试（exit 2） | ✅ |
| AC-7 全量 bats 0 fail | make test 613 ok | ✅ |

---

## 代码质量 6 维

| 维度 | 评估 |
|------|------|
| R1 认知过载 | 🟢 `_is_dotdone_write` 继承 11 种写模式 · `_gate_is_l2_only` 用 fk_phase_gate_key 单一源 |
| R2 变更传播 | 🟢 3 文件 · 签名不变 · 内部调用兼容 |
| R3 知识重复 | 🟢 req_body 公共段消除重复（l3-review-timeout-token 已修） |
| R4 偶然复杂 | 🟢 方案 A 比方案 B 简洁——删握手代码 > 恢复握手 |
| R5 依赖混乱 | 🟢 path-guard 前置 + Tier 1 后置互补 |
| R6 领域扭曲 | 🟢 `.done` 作者性 / L2-only 例外 / 架构天然隔离 均领域术语 |

---

## 已知限制

1. **T4 L2 裁决不匹配负向测试已补**（R1 修复）→ 23 tests 全绿
2. **AC-6 bypass-transition 负向**（R2）：path-guard 拦截写入（exit 2）+ transition 层 Gate 4 兜底——单元覆盖不足（留 v2）
3. **L2-only fail-open**（R3）：_gate_is_l2_only 读取失败放行——D3 设计决策
4. **R1b 静默错判**（l3_review.sh:378 fallback 链）：预存代码 · l3-review-timeout-token 已记录 · 本 change 不改解析

---

## Verdict: pass ✅
