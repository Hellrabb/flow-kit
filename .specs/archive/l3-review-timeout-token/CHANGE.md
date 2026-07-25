# CHANGE: L3 审查工具超时/token 上限不足（deepseek-v4-pro 扩展思考吃满预算）

- **Change ID**: l3-review-timeout-token
- **创建日期**: 2026-07-24
- **路径建议**: 最短（`TASK → DEV → TEST → REVIEW → INTEGRATION`，纯 bug 修复）
- **状态**: active（暂停 gate-done-authorship 后开 · 解套用）
- **来源**: gate-done-authorship phase 3 L3 第二轮复核失败（2026-07-24 11:12）

---

## Why（为什么做）

`l3-review.sh` 的 `_l3_call_api()` 硬编码了两个上限，导致 deepseek-v4-pro（当前 L3 模型）的扩展思考模式无法完成审查：

1. **`max_tokens:8000`**（L350 路径1 阿里云代理 / L366 路径2 Anthropic 直连）：deepseek-v4-pro 在产生结论前，将全部 8000 token 预算花在扩展思考（thinking block）上 → `jq select(.type == "text")` 返回空（无 text block）→ "L3 API 调用失败（响应中无内容）" → rc=3。
2. **`curl --max-time 90`**（L346/362）：deepseek-v4-pro 生成约 144s，超过 90s 上限 → curl 杀进程 → 同样空响应错误。

实测（L3 子 agent 只读诊断）：
- 180s 宽限重放：HTTP 200，`stop_reason=max_tokens`，`content[].type=thinking`（仅思考块，无 text），`output_tokens=8001`
- 生成耗时 ~144s > 90s curl 上限

不修会导致：**所有 gate_config 含 L3 的 change（both/L3）在产物较大时卡死在 L3 审查**——L3 永远拿不到 text block，`.done` 不写，gate 拦 transition，pipeline 死锁。当前已卡住 gate-done-authorship phase 3。

### 证据链

1. **gate-done-authorship phase 3 L3 两轮失败**：
   - 首轮（10:43）：成功（产物较小，思考在 8000 token 内完成）→ verdict=fail（1 Critical + 4 Major + 4 Minor，已全修）
   - 第二轮（11:12）：失败 rc=3（修复后产物变大，思考吃满 8000 token + 144s 超 90s）
2. **L3 子 agent 越权改 l3-review.sh**（首轮）：加 `thinking:{type:"disabled"}` 验证——禁用思考后，相同 prompt 58.4s 返回 3334 token，含干净 text block。**已回退**（越权，但论证有效）。
3. **记忆 [[l3-model-unreliable]]**：glm-4.7 时代标注 L3 不可靠（幻觉 critical）。现模型换 deepseek-v4-pro，失败模式从"幻觉"变为"思考吃满预算+超时"——同类操作主题。

### 根因

L3 工具设计时假设：(a) L3 模型不使用扩展思考（max_tokens 8000 够输出结论）；(b) L3 审查 < 90s。两个假设在 deepseek-v4-pro + 大产物场景下均不成立。硬编码值无法配置，无 env var / 配置文件覆盖入口。

---

## 影响面

- [x] **需要新增/修改 REQUIREMENT.md**：虽为纯 bug 修复，但需落 AC（env var 覆盖 + Fail-safe + 双路径断言 + mock 策略）供 TEST 派生用例
- [ ] **不触及架构**：不改 ADR，不改模块结构
- [x] **影响现有 AC/测试**：需补 L3 工具的超时/token 上限可配置测试

---

## What（做什么）

修 `l3-review.sh::_l3_call_api()` 的硬编码上限，改为可配置 + 提高默认值 + 思考可控（用户选定完整方案 改 1+2+3）：

### 改动 1 · max_tokens 可配置 + 提高

- `max_tokens:8000` → 读 env var `FLOW_KIT_L3_MAX_TOKENS`（默认 `32000`，保守值，大产物也能跑）
- 两处（L350 路径1 / L366 路径2）同步改

### 改动 2 · curl --max-time 可配置 + 提高

- `--max-time 90` → 读 env var `FLOW_KIT_L3_TIMEOUT`（默认 `300`，覆盖大产物生成 + 余量）
- 两处（L346 / L362）同步改

### 改动 3 · thinking 可配（治本）

- 加 env var `FLOW_KIT_L3_THINKING`（默认 `enabled`，可切 `disabled`）
- `enabled`（默认）：保持 deepseek-v4-pro 扩展思考（推理质量高），靠改动 1+2 提高的预算承载
- `disabled`：请求体加 `thinking:{type:"disabled"}`（L3 子 agent 实测验证过——相同 prompt 58.4s 返回 3334 token 含干净 text block），用于大产物场景或快速审查
- 两处请求体（L350 / L366）按 env var 条件加 thinking 字段

> 决策依据：完整方案最灵活——默认 enabled 保留推理质量，disabled 作为 escape hatch。比纯提高上限（治标）更治本，比换非思考模型（改配置层）保留在工具层可控。


---

## Out of Scope

- 不改 L3 审查的 prompt 构建逻辑（`_l3_build_prompt`）
- 不改 L3 结果解析逻辑（`_l3_parse_result`）
- 不改 L3 重审/积压扫描机制（`_l3_check_rerun` / `_l3_scan_backlog`）
- 不改 gate 机制（gate-done-authorship 的 scope）
- 不换 L3 默认模型（保持 deepseek-v4-pro，仅让工具能承载它）

---

## 验收线（粗粒度 · done line）

1. **可配置**：`FLOW_KIT_L3_MAX_TOKENS` + `FLOW_KIT_L3_TIMEOUT` + `FLOW_KIT_L3_THINKING` 三个 env var 可覆盖默认值
2. **默认值提高**：max_tokens 默认 32000，timeout 默认 300s
3. **思考可控**：FLOW_KIT_L3_THINKING=disabled 时请求体含 `thinking:{type:"disabled"}`，enabled 时不含
4. **端到端（手动冒烟 · 非回归验收线）**：gate-done-authorship phase 3 的 L3 第二轮复核能跑通（verdict=pass 或 fail，但不再 rc=3 超时/空响应）。此项依赖外部 deepseek API 实时可用，非离线可验证，不纳入回归验收线（AC-8 全量 bats 不含）——对应 REQUIREMENT AC-9 手动冒烟附录项，不影响本 change 的 spec 合规判定
5. **回归**：全量 bats 0 fail，既有 L3 测试不退化

---

## 关联

- 卡住的 change：`gate-done-authorship`（phase 3 L3 无法完成 → transition 3→4 被拦）
- 相关代码：`flow-kit-bundle/hooks/stop/lib/l3-review.sh::_l3_call_api()`（L346/350/362/366）
- 记忆笔记：[[l3-model-unreliable]]（L3 模型不可靠，本次失败模式变种）
- 技术债：TD-008（l3-review.sh 574 行，含本文件的多职责）

---

## 架构层影响声明（0.4 预检 · 非触发）

0.4 判定：本 change 属「bug 修复」例外（聚焦 L3 工具超时/token 上限可配置化），**不触发 A-architect**。不涉模块拆分 / ADR / 公共契约 / 容量边界 / 跨服务编排。
