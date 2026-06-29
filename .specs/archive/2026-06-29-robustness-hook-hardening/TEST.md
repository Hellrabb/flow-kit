# TEST: 弱模型鲁棒性 Hook 化升级

- **Change ID**: `robustness-hook-hardening`
- **关联**: `REQUIREMENT.md` / `DESIGN.md` / `TASK.md`
- **测试日期**: 2026-06-29

---

## 步骤 0 · 测试范围声明

本项目为 Bash 脚本项目（meta/distribution 类型），无前端/UI、无数据库、无 Web 服务。

适用测试轮次：
- **第 1 轮 · 单元测试** ✅ 执行 — bats `test_weak_model_compliance.bats`（14 tests）
- **第 2 轮 · 集成/回归** ✅ 执行 — `npx bats test/`（176 tests）
- **第 3 轮 · 手动 UAT** ⏭ 跳过 — SessionStart banner 验证需在真实 session 中触发；当前各函数已独立测试，banner 输出逻辑为确定性 jq 操作
- **第 4 轮 · 可访问性** — 不适用（非 Web 项目）
- **第 5 轮 · E2E / 性能** — 不适用（无 Web 服务、无 DB）

---

## 第 1 轮 · 单元测试

### 结果

```
npx bats test/test_weak_model_compliance.bats → 14 tests / 0 failures
```

### 覆盖

| AC | 测试用例 | 结果 |
|---|---|---|
| AC-1 (L1 规则合规) | L1-01 ~ L1-04 | ✅ 4/4 |
| AC-2 (L2 自检完整性) | L2-01 ~ L2-04 | ✅ 4/4 |
| AC-3 (L3 证据链) | L3-01 ~ L3-03 | ✅ 3/3 |
| AC-4 (矫正文件) | CF-01 ~ CF-03 | ✅ 3/3 |

### 测试质量自检（6 维测试衰退风险）

- **R1 脆弱性**: 测试使用 mock temp 目录 + heredoc fixture，不依赖真实 transcript → 低脆弱
- **R2 慢速**: 14 tests 在 < 2s 完成 → 无速度问题
- **R3 覆盖率幻觉**: 每个 AC 有 ≥ 3 个场景（正/负/边界），非单路径覆盖
- **R4 Mock 滥用**: 无 mock——全部使用真实 bash 函数调用 + 临时文件 fixture
- **R5 不可读**: 每个 test 名含中文场景描述 + 对应 AC 编号
- **R6 领域脱节**: 测试直接针对 L1/L2/L3 领域概念，与 REQUIREMENT AC 一一对应

---

## 第 2 轮 · 回归测试

### 结果

```
npx bats test/ → 176 tests / 0 failures ✅
```

### 对比基线

- 基线（change 前）：~162 tests（无 test_weak_model_compliance.bats、无 test_interactive_ui_check sync）
- 当前：176 tests（+14 新增 + test_interactive_ui_check sync 修复）
- 回归：0 failures

---

## 回归测试登记

| 环境 | 命令 | 结果 | 日期 |
|---|---|---|---|
| local | `npx bats test/` | 176 pass / 0 fail | 2026-06-29 |

---

## SessionStart UAT 说明

AC-5（SessionStart 矫正注入）的完整端到端验证需在真实 CC session 中进行：

1. **模拟触发**：写入 mock `.flow-active.correction` JSON 到项目根目录
2. **启动新 session**：SessionStart `flow-kit-resume.sh` 应检测到文件并输出合规矫正 banner
3. **验证清除**：banner 输出后 `.flow-active.correction` 应被 `rm -f` 清除

当前代码级验证：
- `bash -n` 语法检查通过（T03）
- jq 解析逻辑为确定性操作（与 interactive-ui block 同模式）
- 矫正文件 JSON schema 由 CF-01/CF-02 测试覆盖
