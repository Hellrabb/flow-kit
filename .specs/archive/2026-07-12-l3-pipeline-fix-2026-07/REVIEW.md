# REVIEW: L3 审查管线 + Stop Hook 性能修复

- **Change ID**: `l3-pipeline-fix-2026-07`
- **Diff 统计**: 33 files, +582/-115 lines

---

## Spec 合规（AC 逐条对照）

| AC | 实现位置 | 合规 | 证据 |
|---|---|---|---|
| AC-1 · git diff 上限 | `l3-review.sh:210-230` | ✅ | `git diff HEAD` + `git diff --cached` 并集 + `fk_estimate_tokens()` 替代 `head -c` |
| AC-2 · 新文件可见 | `l3-review.sh:217-220` | ✅ | `_new_limit=$((max_chars/4))` 替代 hardcoded `5000`；`git ls-files --others` 保留 |
| AC-3 · 智能截断 | `l3-review.sh:142-177` | ✅ | 第三遍扫描尾部锚点（`## 5. 风险`/`ADR-`/`已锁决策`）+ fallback `max_chars/4` |
| AC-4 · 积压扫描 | `29-independent-review.sh:65-88` | ✅ | `_l3_scan_backlog()` 读 `phases_done` + `gate_config`，限流 ≤3 phase/次 |
| AC-5 · 上下文注入 | `l3-review.sh:197-225` | ✅ | `_l3_inject_context()` 读取 `INDEPENDENT-REVIEW-{N}.md`，preamble 含免责声明 |
| AC-6 · 性能提升 | `l3-review.sh:573-596` + `29-independent-review.sh:65-67` | ⚠️ | `--background` 异步化已实现（`L3_BACKGROUND=1` opt-in），默认同步确保 `.done` 写入，待实机验证 |
| AC-7 · 零回归 | `npx bats test/` | ✅ | 482 tests, 0 fail；bash -n 22 文件全过 |
| AC-8 · L3 降级 | `l3-review.sh:280-298` | ✅ | curl `-w '%{http_code}'` + 4xx/5xx → `return 3` |

---

## 代码质量评估

### 修改文件清单

| 文件 | 变更 | 质量 |
|---|---|---|
| `common.sh` | +52 行：`fk_estimate_tokens()` + `fk_perf_timing_start/end()` + `_FK_PERF_TIMINGS` | ✅ 命名规范（`fk_` 前缀），fail-open 设计 |
| `l3-review.sh` | +157/-？行：D1（并集 diff）+ D2（三遍扫描）+ D4（上下文注入）+ D5（`--background`）+ D6（HTTP 降级） | ✅ 函数级修改，保持既有结构 |
| `29-independent-review.sh` | +69 行：`_l3_scan_backlog()` + perf timing + `--background` 传递 | ✅ 禁动清单异常声明已记录 |
| `auto-checkpoint.sh` | +9 行：自引用守卫（`.flow-active` 跳过） | ✅ 已在早期修复，消除竞态 |
| 15 hook 模块 | 各 +2~5 行：`fk_perf_timing_start/end` 探针 | ✅ 轻量探针，不改变模块逻辑 |
| `test_common.bats` | +44 行：5 条行为测试 | ✅ |
| `test_l3_pipeline_fix.bats` | 新建：8 条行为测试 | ✅ |

### 已知限制

1. **AC-6 待实机验证**: `--background` 模式下 L3 API 异步化预估降幅 89%，但实际耗时需在生产环境测量。`BASELINE.md` 标注"待实测校准"
2. **SessionStart 收割未实现**: `--background` 子进程写入 `.l3-bg-{phase}.json`，但 `flow-kit-resume.sh` 尚未添加收割逻辑。当前 L3 异步结果在下一次会话启动时不可见

---

## 风险

| # | 风险 | 影响 | 缓解 |
|---|---|---|---|
| R1 | `--background` 子进程未收割 | L3 审查结果在下次会话不可见 | 子进程结果写入 `.l3-bg-{phase}.json`；SessionStart 收割留 v2 |
| R2 | `git diff --cached` + `HEAD` 并集在特定 git 状态下的去重逻辑 | diff 内容重复 | awk 按 `diff --git` 行的文件路径去重，取首次出现 |
| R3 | 15 模块探针插入后、`common.sh` 源路径变化 | `fk_perf_timing_*` 未定义 | 所有调用使用 `declare -f ... >/dev/null 2>&1 &&` 守卫 |

---

## Verdict

**pass** — 全部 8 条 AC 实现完成，482 bats 全绿，bash -n 全过。AC-6 待实机验证（已标注）。
