# TEST: L3 审查管线 + Stop Hook 性能修复

- **Change ID**: `l3-pipeline-fix-2026-07`
- **关联**: `@.specs/l3-pipeline-fix-2026-07/REQUIREMENT.md`
- **项目类型**: CLI / 库（Bash 脚本项目）

---

## 0. 本次测试范围声明（5 轮金字塔）

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 8 条 AC（bats 行为测试） | — |
| 第 2 轮 · 性能 | ✅ 必跑 | Stop hook wall-clock 降幅验证 | AC-6 要求 ≥30% |
| 第 3 轮 · 安全 | ❌ 跳过 | — | 无新依赖/API/秘钥；不改变 L3 API 鉴权 |
| 第 4 轮 · 兼容 | ⚠️ 精简 | bash -n 语法 + Bash 4.0+ 兼容 | 非 Web/DB 项目，无跨浏览器/数据迁移 |
| 第 5 轮 · 可观测 | ⚠️ 精简 | fk_perf_timing 探针输出验证 | 无 HTTP/DB，无需 RED/USE/trace |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例）

| AC | 类型 | 用例文件 | 状态 |
|---|---|---|---|
| AC-1 · git diff 上限 | unit | `test_l3_pipeline_fix.bats::AC-1` | ✅ |
| AC-2 · 新文件可见 | unit | `test_l3_pipeline_fix.bats::AC-2` | ✅ |
| AC-3 · 智能截断 | unit | `test_l3_pipeline_fix.bats::AC-3` | ✅ |
| AC-4 · 积压扫描 | unit | `test_l3_pipeline_fix.bats::AC-4` | ✅ |
| AC-5 · 上下文注入 | unit | `test_l3_pipeline_fix.bats::AC-5` | ✅ |
| AC-6 · 性能提升 | manual | `BASELINE.md` 优化实施记录 | ⚠️ 预估达标（89%），待实机验证 |
| AC-7 · 零回归 | regression | `npx bats test/`（480 tests） | ✅ 0 fail |
| AC-8 · L3 降级 | unit | `test_l3_pipeline_fix.bats::AC-8` | ✅ |

### 1.2 新增测试登记

| 用例文件 | 类型 | 覆盖 AC | 测试数 |
|---|---|---|---|
| `test/test_common.bats` | unit | 基础设施 | +5（T01） |
| `test/test_l3_pipeline_fix.bats` | unit | AC-1~5, AC-8 | +6（T07） |
| **合计新增** | | | **11 tests** |

### 1.3 覆盖率

- 全量 bats: **480 tests, 0 fail**（2026-07-11 实测）
- 既有测试无退化
- bash -n 全量语法检查: **0 errors**（22 .sh 文件）

### 1.4 边界 / 错误路径

- `fk_estimate_tokens("")` → 0（空文本）
- `fk_perf_timing_end("no_start")` → WARNING + return 0（fail-open）
- smart_truncate 尾部锚点零匹配 → fallback 保留最后 max_chars/4
- L3 API HTTP 4xx/5xx → verdict=error, return 3
- 积压扫描限流 → ≤3 phase/次，超出推迟

---

## 第 2 轮 · 性能测试

### 2.1 性能预算（来自 REQUIREMENT.md AC-6）

```yaml
stop_hook_chain:
  baseline: ~33s（含 L3 API 30s 同步等待）
  target: ≤ 23s（降低 ≥ 30%）
  optimized_estimate: ~3.5s（降幅 ~89%，L3 API --background 异步化后）
```

### 2.2 实测结果

| 指标 | 预算 | 优化前（估） | 优化后（估） | 判定 |
|---|---|---|---|---|
| Stop hook wall-clock | ≤ 23s | ~33s | ~3.5s | ✅ 预估达标 |
| 29 号模块耗时 | — | ~30s | <100ms | ✅ 消除主瓶颈 |
| bash -n 语法 | 0 errors | 0 | 0 | ✅ |
| bats 全量 | 0 fail | 0 | 0 | ✅ |

> ⚠️ 实际 wall-clock 测量需在生产 Claude Code session 中运行 Stop hook 链后采集。预估基于代码分析：29 号模块的 `--background` flag 消除了 30s L3 API 同步等待。

---

## 第 3 轮 · 安全测试

**跳过**。理由：
- 无新增依赖包
- 不改变 L3 API 鉴权方式（沿用 `ANTHROPIC_AUTH_TOKEN`）
- 不暴露新端点
- 不引入新的文件读写路径（仅修改既有 .sh 文件）
- `--background` 子进程写入 `.l3-bg-{phase}.json` 到既有 `.specs/<id>/` 目录

---

## 第 4 轮 · 兼容性测试

**精简**。仅验证 Bash 语法兼容：
- `bash -n` 全量通过：22 个 .sh 文件，0 errors ✅
- Bash 版本兼容：无 Bash 4.0+ 特性变更（使用的 `mapfile` 在 4.0+ 可用，`declare -A` 在 4.0+ 可用）
- 向下兼容：不改动 `.flow-active` 字段结构，不改动 `L3_RESULT` 输出格式，不改动 `.done` 6 键 KVP

---

## 第 5 轮 · 可观测性验证

**精简**。验证新增的 `fk_perf_timing` 探针：
- [x] 16 个 hook 模块各含 `fk_perf_timing_start/end` 调用
- [x] `99-report.sh` 汇总输出 `[perf] timings:` 行
- [x] `fk_perf_timing_end` 未配对的 start 时 fail-open（WARNING stderr，不阻断）
- [ ] 实际生产环境 Stop hook 运行后确认 `[perf] timings:` 出现在输出中（需实机验证）

---

## 回归保护

本次变更可能影响的旧功能：
- L3 独立审查调度（29 号 hook）→ 保持调度逻辑，仅新增积压扫描 + 异步化
- PreToolUse transition gate → 不传 `--background`，保持同步 path
- smart_truncate 现有行为 → 保留两遍扫描逻辑，新增第三遍（尾部锚点），向后兼容
- git diff 收集 → 新增 `git diff --cached` + 去重，保留 `git diff HEAD`

对应已有测试：**480 tests 全绿，0 fail** ✅
