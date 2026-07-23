# TEST — L2/L3 模型配置解耦（5 轮金字塔）

- **Change ID**: l2-l3-model-config
- **关联**: REQUIREMENT.md（AC-1~7）、TASK.md、各 *-SUMMARY.md、3 测试文件

---

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 AC（7 条）→ bats 用例 | — |
| 第 2 轮 · 性能 | ❌ 跳过 | — | Bash 脚本项目，无 QPS/Lighthouse；fk_resolve_model 仅 env var 读取+1 次 jq，<10ms（REQUIREMENT NFR 已声明，非热路径） |
| 第 3 轮 · 安全 | ⚠️ 部分 | 注入边界（jq --arg）+ 秘钥扫描 | Bash 项目无 npm audit/trivy；模型名不校验值域由 caller 降级处理 |
| 第 4 轮 · 兼容 | ⚠️ 部分 | 跨平台（本 change 核心）CC 平台实测；非 CC 平台靠 env var/.flow-active | 无法在所有非 CC 平台实测，US-1 跨平台不依赖 /flow model skill |
| 第 5 轮 · 可观测 | ⚠️ 部分 | 降级 correction + SessionStart banner | CLI/hook 无运行时指标/告警；降级可观测靠 correction 文件 + resume banner |

---

## 第 1 轮 · 功能测试

### 1.1 AC → 测试矩阵

| AC | 类型 | 用例文件 | 状态 |
|---|---|---|---|
| AC-1（L3 全链 5 场景） | unit | `test_fk_resolve_model.bats` L3-A..E | ✅ 5/5 |
| AC-2（L3 P1 命中·CC 不变） | unit | `test_fk_resolve_model.bats` L3-A（真实 ANTHROPIC_DEFAULT_HAIKU_MODEL + 截断断言） | ✅ |
| AC-3（L2 全链 5 场景） | unit | `test_fk_resolve_model.bats` L2-A..E | ✅ 5/5 |
| AC-4a/4b（降级不崩溃） | unit+集成 | test_model_degradation.bats（降级机制 + **l3-review caller 集成**：return 3 + type=l3-model-missing + 无 API + stderr 含 FLOW_KIT_L3_MODEL）+ T09 场景 D | ⚠️ l3-review caller ✅；29-indep + l2-detect caller 集成 Tech-debt（机制层 test 1/2 覆盖降级标记；caller 完整集成 l2_dispatch_prompt/29-indep 脚本复杂度高，留后续） |
| AC-5/5b/5c（/flow model 写入/合并/clear） | unit | test_flow_model.bats（jq 写入/合并/clear/边界/防注入） | ✅ |
| AC-5d（/flow model 显示） | manual UAT（已执行） | `/flow model` 无参 → jq 格式化 `.goal.l2_model`/`.goal.l3_model`；round-trip set→display→clear + 字段边界 全 PASS（见 §1.5 已执行证据 · L2 R2' 残留闭环） | ✅ UAT 已执行 |
| AC-6（SessionStart 收割） | integration | `test_flow_kit_resume.bats`（l3/l2-model-missing 不删 + compliance 读后删 + l2-missing 持久化） | ✅ 4/4 新 |
| AC-7（全量回归） | regression | `npx bats flow-kit-bundle/test/` exit 0 | ✅ 0 fail |

### 1.2 执行结果

```
test_fk_resolve_model.bats: 1..10 全 ok（L3/L2 × A-E）
test_model_degradation.bats: 1..3 全 ok（降级机制 + L3 caller 集成 · L2 R1 补强）
test_flow_model.bats: 1..6 全 ok（/flow model jq 写入/合并/clear/边界/防注入 · L2 R2 补强）
test_flow_kit_resume.bats: 1..11 全 ok（既有 7 + 新 4）
test_independent_review_model.bats: 1..12 全 ok（AC-1/AC-3 改 fk_resolve_model）
全量 bats flow-kit-bundle/test/: exit 0（0 failures，无回归）
```

### 1.3 覆盖率与边界

- **fk_resolve_model 全分支覆盖**：5 场景（P1/P2/P3/空/三级同设）× L2/L3 = 10 用例，覆盖所有优先级路径
- **边界用例**：全空降级（场景 D）✅、三级同设（场景 E）✅、P2 压 P3（场景 B）✅
- **错误路径**：降级（空 model）→ caller 写 correction + return（T03/T04/T05 集成）

### 1.4 测试质量自检 · 6 维测试衰退风险

| 维度 | 诊断 | 结果 |
|---|---|---|
| T1 测试晦涩 | 测试名 `L3-A: P1 命中，截断 P2/P3 (AC-2)` 清晰表达场景 | ✅ |
| T2 测试脆弱 | 断言返回值（`[ "$model" = "haiku-p1" ]`），非实现细节 | ✅ |
| T3 测试重复 | L2/L3 场景对称——必要（env var 名不同 ANTHROPIC_DEFAULT_HAIKU_MODEL vs ANTHROPIC_L2_MODEL） | ✅ 可接受 |
| T4 Mock 滥用 | 无 mock——真实 source common.sh + export env var + 临时 .flow-active | ✅ |
| T5 覆盖率幻觉 | 断言实际返回值（非 `toBeDefined` 空断言） | ✅ |
| T6 架构错配 | fk_resolve_model 单测（lib 函数）/ resume 集成测（hook）/ AC-7 全量回归 | ✅ 层级匹配 |

**结论**：6 维全 ✅，无测试衰退风险。

### 1.5 AC-5d `/flow model` 显示 · 已执行 UAT 证据（2026-07-24 · L2 R2' 残留闭环）

> 复现 SKILL.md:236-256 的 `/flow model` 无参显示逻辑。round-trip 在 `.flow-active` 临时副本上做，**不污染真实运行时状态**。

**UAT-1 · 真实 `.flow-active` 当前显示**（`jq -r` 格式化 `.goal.l2_model`/`.goal.l3_model`）：

```
$ jq -r '"l2_model: \(.goal.l2_model // "unset (null)")\nl3_model: \(.goal.l3_model // "unset (null)")"' .flow-active
l2_model: unset (null)
l3_model: unset (null)
```

**UAT-2 · round-trip（临时副本 `/tmp/uat-fa`）**：set → display → jq -e → clear → 字段边界

```
$ jq --arg m "deepseek-v4-flash" --arg ts "$(date -Iseconds)" \
    '.goal.l3_model = $m | .updated_at = $ts' /tmp/uat-fa > _.tmp && mv _.tmp /tmp/uat-fa   # set（SKILL.md:248-250 原样）
$ jq -r '"l2_model: \(.goal.l2_model // "unset (null)")\nl3_model: \(.goal.l3_model // "unset (null)")"' /tmp/uat-fa
l2_model: unset (null)
l3_model: deepseek-v4-flash                                          # display 正确反映写入值
$ jq -e '.goal.l3_model == "deepseek-v4-flash"' /tmp/uat-fa && echo PASS
true → exit 0 (PASS)
$ jq '.goal.l3_model = null' /tmp/uat-fa > _.tmp && mv _.tmp /tmp/uat-fa  # clear（SKILL.md:251 → null）
$ jq -r '"l3_model after clear: \(.goal.l3_model // "unset (null)")"' /tmp/uat-fa
l3_model after clear: unset (null)
$ jq -e '.goal.condition == "根据.specs/l2-l3-model-config/DESIGN.md走flow-kit流程" and (.goal.gate_config["6-review"] == "both")' /tmp/uat-fa && echo PASS
true → exit 0 (PASS)                                                 # 字段边界：condition/gate_config 未被触碰
```

**UAT-3 · 优先级链**（`.goal.l*_model` 未设时 fk_resolve_model 走 env var 三级链）：

```
ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-5.1   ← P1 命中（AC-2：CC 不向下查）
FLOW_KIT_L3_MODEL=<unset>                ← P2/P3 未设 → 无则降级 correction
```

**判定**：display 路径读取 `.goal.l2_model`/`.goal.l3_model` 正确；set 后即时反映、clear 回 null、字段边界守护成立。AC-5d ✅ 已执行（L2 R2' 的「无已执行 UAT 证据」残留闭环）。

---

## 第 2 轮 · 性能（❌ 跳过）

Bash 脚本项目，无 QPS/Lighthouse/bundle size。fk_resolve_model 仅 env var 读取 + 至多 1 次 jq 调用（.flow-active），调用开销 < 10ms（REQUIREMENT NFR 声明），非热路径（每轮 Stop hook 调 1 次）。无需性能基准。

---

## 第 3 轮 · 安全（⚠️ 部分）

- **注入边界**：`/flow model` 与 correction 写入均用 `jq --arg`（T02/T07），禁止裸插值（DESIGN NFR）。模型名不校验值域（由用户/供应商负责，错误名由 caller 降级）✅
- **秘钥扫描**：本 change 不触碰秘钥/token；`.flow-active.goal.l*_model` 存模型名（非秘钥）；correction message 无敏感信息 ✅
- **npm audit / trivy**：不适用（Bash 项目无 npm 依赖树；bats 是 dev-only）
- **OWASP**：A03 注入（jq --arg 防）✅；其余不适用（CLI/hook，无 Web 攻击面）

---

## 第 4 轮 · 兼容（⚠️ 部分 · 跨平台是本 change 核心）

- **CC 平台**（实测）：source common.sh + bats 全 pass（本环境 ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-5.1）
- **非 CC 平台**（设计验证，无法实测所有）：US-1 靠 `FLOW_KIT_*` env var / `.flow-active` 直写（不依赖 /flow model skill）；fk_resolve_model 三级链纯 Bash + jq（跨平台）
- **兼容性权衡**（US-2）：未设 ANTHROPIC_L2_MODEL 的 CC 用户行为变化（移除 claude-sonnet-5 fallback）—— CHANGELOG 标注
- **数据迁移**：不适用（无 schema 变更，.flow-active 加可选字段向后兼容）

---

## 第 5 轮 · 可观测（⚠️ 部分）

- **降级可观测**：model-missing correction（type=l3/l2-model-missing）+ SessionStart banner（T06 收割）✅
- **日志**：降级 stderr 提示（`[l3-review] L3 模型未配置...`）✅；无 PII/秘钥
- **指标/告警/健康检查**：不适用（CLI/hook 无运行时）

---

## 步骤 N · 回归测试登记

本次新增/修改的测试用例：
- `test_fk_resolve_model.bats`（新建，10 用例 · AC-1/2/3 全链）
- `test_model_degradation.bats`（新建，3 用例 · AC-4a/4b 降级机制 + L3 caller 集成 · L2 R1）
- `test_flow_model.bats`（新建，6 用例 · AC-5/5b/5c /flow model jq 写入/合并/clear/边界/防注入 · L2 R2）
- `test_flow_kit_resume.bats`（+4 用例 · AC-6 model-missing 收割 + l2-missing 持久化）
- `test_independent_review_model.bats`（AC-1/AC-3 改 fk_resolve_model 契约 · T04 连带）

全量回归基线：`npx bats flow-kit-bundle/test/` exit 0（0 failures）。
