# TEST: L3 审查结果反馈可见性修复

- **Change ID**: `l3-feedback-visibility`
- **关联**: `@.specs/l3-feedback-visibility/REQUIREMENT.md`、`@.specs/l3-feedback-visibility/TASK.md`

---

## 测试矩阵

### 第 1 轮 · 功能测试（bats）

| AC | 测试场景 | 文件 | 结果 |
|----|---------|------|------|
| AC-1 | L3_RESULT 格式匹配 grep 验证正则 + 大小写 + 相对路径断言 | `test/test_l3_feedback.bats` 场景 2, 5 | ✅ pass |
| AC-2 | SessionStart .done + L3 段检测（含 .done 不存在 / review md 无 L3 段否定用例） | `test/test_l3_feedback.bats` 场景 6 | ✅ pass |
| AC-3 | `_l3_format_result()` 共享函数（verdict=pass/fail/error/timeout 四种值） + F1 stdout 精确断言 | `test/test_l3_feedback.bats` 场景 1, 5 | ✅ pass |
| AC-4 | 全模式兼容（L2-only / L3-only / both / off 的 gate_val 判定） | `test/test_l3_feedback.bats` 场景 7 | ✅ pass |
| AC-5 | timeout/error 时 `_l3_format_result` 退出码 = 0（不阻塞 transition） | `test/test_l3_feedback.bats` 场景 9 | ✅ pass |
| AC-6 | 畸变降级 verdict=error + 不泄露原始 JSON 片段 | `test/test_l3_feedback.bats` 场景 3 | ✅ pass |

**AC 覆盖率**: 6/6 = 100%

**已知局限**（详见「未覆盖项」）：
- summary 三层 JSON 提取管道（`l3-review.sh` 内联代码）的单元测试未覆盖——提取逻辑与 `l3_review_run()` 紧耦合，需 L3 API mock 或重构为可测函数才能单测
- AC-4 测试为 gate_val 判定逻辑验证（bash 条件表达式）；gate 函数级调用（`fk_independent_review_gate_active` + `fk_validate_done_marker`）在已有 `test/test_dual_review_merge.bats` 中覆盖

### 第 2 轮 · 回归测试

| 范围 | 命令 | 结果 |
|------|------|------|
| 全量 bats | `npx bats test/` | 371 tests, 370 passed, 1 pre-existing failure (unrelated) |
| 新增测试 | `npx bats test/test_l3_feedback.bats` | 25/25 passed |
| bash -n 语法检查 | `bash -n` 全部 4 个修改文件 | 全部通过 |

**回归**: 0 regressions ✅

### 第 3 轮 · 安全测试

| 检查项 | 覆盖范围 | 结果 |
|--------|---------|------|
| `L3_RESULT:` 行不含 https?:// endpoint URL | `_l3_format_result` 白名单字段输出 | ✅ |
| `L3_RESULT:` 行不含 API key 模式（sk-ant/sk-or） | `_l3_format_result` 白名单字段输出 | ✅ |
| `L3_RESULT:` 行不含文件系统绝对路径 | `_l3_format_result` 白名单字段输出 | ✅ |
| `L3_RESULT:` 行不含 API 响应原文 JSON 片段 | `_l3_format_result` 白名单字段输出 | ✅ |
| `set +e`/`set -e` 容错包围 `.done` 读取 | T02/T03 代码审查 | ✅ |

**已知局限**：上述安全测试仅覆盖 `_l3_format_result` 的 stdout 白名单输出（天然安全）。移除 `2>/dev/null` 后 `l3_review_run()` 内部 `>&2` 日志（curl 错误含 endpoint URL、jq 解析错误含部分 API 响应原文）的 stderr 泄露风险，需在 PreToolUse hook 实际执行路径中验证——bats 环境下无真实 L3 API 调用。

### 第 4 轮 · 兼容性测试

| 场景 | 验证方式 | 结果 |
|------|---------|------|
| `gate_config="L2"` → L3 不触发 | gate_val 判定 + T02 R3 fix（`exit 0` before L3 block） | ✅ |
| `gate_config="L3"` → L3 正常触发（无需 L2 前置） | gate_val 判定 + T02 R2 fix（elif L3-only 分支） | ✅ |
| `gate_config="both"` → L2 未完成时阻断 + L2 完成后 L3 执行 | T02 gate 逻辑（lines 208-214 + L2-wait） | ✅ |
| `gate_config="off"` → gate 不激活 | `fk_independent_review_gate_active` 返回 1 | ✅ |
| `.done` KVP 格式向前兼容（含/不含 L3_summary） | `_fk_done_kvp` 读取 + 缺失降级为空 | ✅ |
| SessionStart 无 L3 场景不产生假阳性 banner | F2 检测条件（.done + L3 段双重检测） | ✅ |

### 第 5 轮 · 可观测性测试

| 检查项 | 验证方式 | 结果 |
|--------|---------|------|
| L3 超时时日志输出 | `l3-review.sh` 代码审查（line 295: `echo "L3 timed out"`） | ✅ |
| L3 完成时日志输出 | `l3-review.sh` 代码审查（line 273: `echo "L3 complete ..."`） | ✅ |
| verdict=error 固定降级文本 | bats 场景 3（`_l3_format_result "error" ...`） | ✅ |
| 握手文件写入（R1 fix） | `independent-review-gate.sh` 代码审查（hs_file jq 写入） | ✅ |

---

## UAT 清单（手动验证 · 可选）

1. **PreToolUse 路径**：触发含 L3 gate 的 phase transition → agent 对话中出现 `L3_RESULT:` 行
2. **SessionStart 路径**：上一 session 完成 L3 后启动新 session → SessionStart banner 含 `L3_RESULT:` 行（握手文件不存在时也能触发）
3. **超时降级**：L3 API 超时 → `L3_RESULT: verdict=timeout` + transition 正常放行

---

## 未覆盖项

| # | 范围 | 原因 | 风险缓解 |
|---|------|------|---------|
| 1 | summary 三层 JSON 提取管道（`l3-review.sh` 内联） | 提取逻辑与 `l3_review_run()` 紧耦合，需 mock L3 API 或重构为独立函数才能单测 | 第四层故障降级（verdict=error）在单元测试中覆盖；提取成功路径依赖 L3 API 返回合法 JSON，由集成环境验证 |
| 2 | `l3_review_with_timeout` 完整超时链路（timeout → done 写入 → `L3_RESULT` 输出） | 需真实触发 30s 超时，bats 环境不适合 | `_l3_format_result(verdict=timeout)` 的退出码 + 格式已验证；超时降级的 .done 写入逻辑与正常路径共享 `l3_write_timeout_done()` |
| 3 | PreToolUse hook 实际执行路径中的 stderr 安全（curl/jq 错误泄露） | 需真实 L3 API 调用失败场景 | `_l3_format_result` 白名单字段保证 stdout 安全；stderr 风险依赖代码审查（curl 错误仅含 endpoint，不含 token） |
| 4 | `independent-review-gate.sh` handshake 文件创建 + `fk_validate_done_marker` 端到端 | 需 PreToolUse hook 框架实际触发 | 握手文件创建逻辑（`jq -n ... > "$hs_file"`）为简单 jq 调用；`fk_validate_done_marker` 在 `test/test_dual_review_merge.bats` 中有独立覆盖 |
| 5 | AC-3 两条路径格式一致性的集成验证（跨 session 生命周期） | 需两次独立 session 运行，自动化成本高 | 两条路径均调用同一 `_l3_format_result()` 函数（D6），单元测试已验证函数输出格式一致 |

---

## 总结

| 维度 | 结果 |
|------|------|
| AC 覆盖率 | 6/6 = 100% |
| 功能测试 | 25 bats tests, 全绿 |
| 回归测试 | 371 tests, 0 regressions |
| 安全测试 | `L3_RESULT:` 行白名单字段 4/4 通过；stderr 安全依赖集成环境 |
| 兼容性测试 | 6 场景全部验证 |
| bash 语法 | 4 文件全部通过 `bash -n` |
| 未覆盖项 | 5 项，均在集成环境或后续迭代中可验证 |
