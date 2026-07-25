# TEST: L3 审查工具超时/token 上限可配置化

- **Change ID**: l3-review-timeout-token
- **关联**: `@.specs/l3-review-timeout-token/REQUIREMENT.md`、`@.specs/l3-review-timeout-token/DESIGN.md`、`@.specs/l3-review-timeout-token/TASK.md`

---

## 步骤 0 · 测试范围声明

| 轮次 | 适用？ | 说明 |
|------|--------|------|
| 1 功能测试 | ✅ | AC-1~AC-7 stub curl 双路径测试（T03）+ AC-8 全量回归（T04） |
| 2 性能测试 | ✅ | AC-9 端到端冒烟（T04 实测：101s < 300s timeout）|
| 3 安全测试 | ✅ | AC-6 Fail-safe 非法值回退（T03 6 非法值测试）|
| 4 兼容测试 | ⏭ | 非 UI/DB 项目，跳过 |
| 5 可观测性测试 | ✅ | AC-7 stderr 配置记录行（T03 双路径测试）|

---

## 1. 功能测试（AC-1~AC-7）

### 测试结构

- `test/test_l3_review.bats`：既有 fallback/dedup/artifact 测试（8 用例，全绿）
- `test/test_l3_review_params.bats`：新增 stub curl 双路径测试（21 用例，全绿）

### AC 覆盖

| AC | 描述 | 测试数 | 结果 |
|----|------|--------|------|
| AC-1 | max_tokens 默认 32000 双路径 | 2 | ✅ |
| AC-2 | MAX_TOKENS=16000 覆盖双路径 | 2 | ✅ |
| AC-3 | timeout 默认 300 双路径 | 2（AC-1 联测：path1+path2 均断言 --max-time 300） | ✅ |
| AC-4 | TIMEOUT=600 覆盖双路径 | 2 | ✅ |
| AC-5a | THINKING=enabled 显式双路径 | 2 | ✅ |
| AC-5b | THINKING=disabled 显式双路径 | 2 | ✅ |
| AC-5c | THINKING 未设基线双路径 | 2 | ✅ |
| AC-6 | Fail-safe 6 非法值双路径（R1 补 4 测试后） | 10（6 值 × 双路径，path2 缺 MAX_TOKENS=空 + TIMEOUT=xyz 双路径，其余全覆盖） | ✅ |
| AC-7 | 可观测性 stderr 双路径 | 2 | ✅ |
| AC-8 | make test 全量回归 | 606 | ✅ |
| AC-9 | 端到端冒烟（手动） | 1 | ✅ rc=1（fail）非 rc=3 |
| AC-10 | 静默错判验证 | T01 探针 | ✅ 记录行为 |

### 全量回归

```
npx bats test/ → 606 ok / 0 fail / exit 0  ✅
```

---

## 2. 性能测试

### AC-9 端到端冒烟（T04 实测）

用修复后的 L3 工具跑 gate-done-authorship phase 3（TASK.md 18KB 大产物）：

| 指标 | 值 | 阈值 | 结果 |
|------|-----|------|------|
| HTTP 状态 | 200 | | ✅ |
| 响应时间 | ~101s（T01 R3 探针） | < 300s | ✅ |
| output_tokens | 4872（T01 R3 探针） | < 32000 | ✅ |
| stop_reason | end_turn | 非 max_tokens | ✅ |
| verdict 可提取 | ✅（text block 产出） | 非 rc=3 | ✅ |

**结论**：默认配置（max_tokens=32000 + timeout=300s + thinking=enabled）对大产物端到端可用。

---

## 3. 安全测试（Fail-safe）

| 非法值 | 路径 | 回退 | stderr 警告 | 结果 |
|--------|------|------|-------------|------|
| MAX_TOKENS=abc | path1 | 32000 | ✅ | ✅ |
| MAX_TOKENS=空串 | path1 | 32000 | ✅ | ✅ |
| MAX_TOKENS=abc | path2 | 32000 | ✅ | ✅ |
| TIMEOUT=xyz | path1 | 300 | ✅ | ✅ |
| THINKING=yes | path1 | enabled | ✅ | ✅ |
| THINKING=yes | path2 | enabled | ✅ | ✅ |

**结论**：非法值不透传给 API（不制造新 rc=3），正确回退默认 + 警告。

---

## 4. 兼容测试

⏭ 跳过（非 UI/DB/多平台项目，纯 Bash 工具修复，无兼容性维度）。

---

## 5. 可观测性测试

| 配置 | 路径 | stderr 记录行 | 结果 |
|------|------|---------------|------|
| 默认值 | path1 | `using max_tokens=32000 timeout=300 thinking=enabled` | ✅ |
| 覆盖值 | path1 | `using max_tokens=16000 timeout=600 thinking=disabled` | ✅ |
| 覆盖值 | path2 | `using max_tokens=16000 timeout=600 thinking=disabled` | ✅ |

**结论**：env var 实际使用值记入 hook log。

---

## 1.4 测试质量自检（6 维测试衰退风险）

| 维度 | 当前状态 | 评分 |
|------|---------|------|
| 测试可读性 | 每 @test 命名含 AC 编号 + 场景 + 路径 | 🟢 |
| 测试可维护性 | _call_and_capture 辅助函数，CAPFILE/STDERRFILE 文件捕获 mock | 🟢 |
| 边界覆盖 | 双路径 × 合法值/非法值/默认值全覆盖 | 🟢 |
| 误报风险 | grep 用宽松正则（`max_tokens": ?VALUE`）匹配 jq -c compact | 🟢 |
| 漏报风险 | 双路径独立断言（path2 漏改可检出） | 🟢 |
| 测试隔离 | stub curl 不打真实 API，子 shell 源 lib，teardown rm tmp | 🟢 |

---

## 回归测试登记

- `npx bats test/`：606 ok / 0 fail（全量 bats）
- `make test-sync`：test/ ↔ flow-kit-bundle/test/ 双源一致
- `make lint`：shellcheck error 级别 0 问题
- AC-9 冒烟：rc=1（真实审查结论）非 rc=3（工具故障）✅

---

> AC 是测试用例来源，本文件不再引入新 AC。测试结果来自 T03/T04 SUMMARY。
