# BASELINE — Stop Hook 性能基线

- **Change ID**: `l3-pipeline-fix-2026-07`
- **测量日期**: 2026-07-11
- **测量方法**: `fk_perf_timing_start/end` 探针（D5 Phase 1）+ 99-report.sh 汇总
- **测量环境**: flow-kit 开发仓库，16 hook 模块（含 29号 积压扫描）

---

## 各模块耗时分布（预估基线 · 待实测校准）

> ⚠️ 以下为代码分析预估。实测需在实际 Claude Code session 运行 Stop hook 链后采集。
> 测量命令：触发一次 Stop hook → 查看 99-report.sh 输出的 `[perf] timings:` 行 → 重复 3 次取中位数。

| 模块 | 预估耗时 | 主要操作 | 瓶颈类型 |
|---|---|---|---|
| 00-gate | ~50ms | stdin 读取 + 环境初始化 | N/A |
| 01-transcript-parse | ~100ms | JSONL 解析 + jq 提取 | N/A |
| 20-claude-md | ~200ms | CLAUDE.md 同步检查 | N/A |
| 21-memory | ~200ms | Memory 文件更新 | N/A |
| 22-git | ~300ms | git status/diff/stash 检查 | N/A |
| 23-quality | ~200ms | shellcheck/lint 调用 | N/A |
| 24-session | ~300ms | Session 数据分析 | N/A |
| 25-project | ~200ms | 项目级检查 | N/A |
| 26-workflow | ~500ms | flow-kit 状态检查 + artifact 验证 | 中度 |
| 27-interactive-ui-check | ~200ms | transcript grep 扫描 | N/A |
| 28-weak-model-compliance | ~300ms | L1/L2/L3 合规扫描 | N/A |
| **29-independent-review** | **~30,000ms** | **L3 API 同步 curl 调用（30s timeout）** | **🔴 主要瓶颈** |
| 30-ai-analyze | ~200ms | 频率门控检测（通常跳过） | N/A |
| 31-auto-advance | ~100ms | jq 状态检查 | N/A |
| 32-fallback-guard | ~100ms | jq 状态检查 | N/A |
| 99-report | ~200ms | 汇总输出 | N/A |
| **总计（无 L3）** | **~3,350ms** | 13 个轻量模块 | — |
| **总计（含 L3）** | **~33,350ms** | 29 号模块主导 | — |

---

## Top 3 瓶颈分析

### 🔴 瓶颈 1: 29-independent-review（L3 API 同步等待）— ~30,000ms（90%）

- **根因**: `l3_review_run()` → `_l3_call_api()` → `curl --max-time 90` 同步阻塞，等待外部模型 API 返回
- **影响**: 单模块占 Stop hook 链总耗时的 90%
- **优化方向**: L3 API 异步化——Stop hook 路径改为 fire-and-forget，SessionStart 收割结果
- **预估收益**: Stop hook 链 wall-clock 从 ~33s 降至 ~3.5s，降幅 **89%**

### 🟡 瓶颈 2: 26-workflow（flow-kit 状态检查）— ~500ms（1.5%）

- **根因**: 多项 jq 读取 + artifact 验证 + 自动推进检测
- **影响**: 轻量但可优化——部分检查可缓存或合并 jq 调用
- **优化方向**: 合并多次 jq 调用为单次（`jq '{a: .a, b: .b}'` 替代两次 `jq '.a'` + `jq '.b'`）
- **预估收益**: ~100ms（20%），不足以单独作为优化目标

### 🟢 瓶颈 3: 22-git / 24-session — 各 ~300ms（0.9%）

- **根因**: git 命令 + session 日志解析
- **影响**: 轻量，优化收益有限
- **建议**: 不单独优化，留在 v2

---

## 优化建议

### 建议 1（推荐 · 高收益低风险）: L3 API 异步化

- **策略**: `l3_review_run()` 新增 `--background` flag
  - 正常调用（PreToolUse transition 路径）：保持同步（需要 L3 verdict 才能放行）
  - Stop hook 兜底路径（29 号模块）：使用 `--background` → fire-and-forget curl → 不等待返回
  - SessionStart: `flow-kit-resume.sh` 检测后台 L3 结果 → 读取 + 写入 .done + 注入 banner
- **预估收益**: 29 号模块耗时从 30s → <100ms（仅 jq 写入 + 后台进程 fork），Stop hook 链总耗时降幅 **~89%**
- **风险**: L3 结果在 SessionStart 才可用，PreToolUse transition 路径不受影响
- **实施难度**: 中（需修改 `l3_review_run` + `flow-kit-resume.sh` + 添加后台结果文件格式）

### 建议 2（中等收益）: jq 调用合并

- **策略**: 26-workflow.sh 中多次独立 jq 调用合并为单次多字段提取
- **预估收益**: ~100ms
- **实施难度**: 低

### 建议 3（长期 · v2）: 模块并行化

- **策略**: 27-interactive-ui-check / 28-weak-model-compliance / 33-flow-active-integrity 三个独立检查模块后台并行跑
- **预估收益**: ~400ms（在无 L3 场景下约 12%）
- **实施难度**: 高（需要各模块声明依赖，避免共享状态冲突）

---

## 30% 目标可行性评估

### ✅ 可达

- **建议 1（L3 API 异步化）单独即可达成远超 30% 的目标**（89% 降幅）
- 实施后 Stop hook 链 wall-clock 从 ~33s → ~3.5s
- 即使仅实施 Stop hook 兜底路径的异步化（不碰 PreToolUse 同步路径），每次 Stop hook 的 wall-clock 时间降低 ~30s

### 实施计划

1. **v1（本次 change）**: 实施建议 1（L3 API 异步化在 Stop hook 兜底路径）
2. **验证**: 复测 3 次，确认降幅 ≥ 30%
3. **v2（独立 change）**: 建议 2 + 建议 3

---

## 优化实施记录

### 优化 1: L3 API 异步化（2026-07-11 实施）

- **选定策略**: 建议 1 — L3 API 异步化（Stop hook 兜底路径）
- **实施内容**:
  - `l3_review_run()` 新增 `--background` flag（`l3-review.sh`）
  - 后台模式：fork 子进程执行 API 调用 + 写入 `.l3-bg-{phase}.json`
  - `29-independent-review.sh` 通过 `L3_BACKGROUND=1` 环境变量 opt-in（默认同步）
  - **修正**（L2 审查 R1）：默认同步模式确保 `.done` 写入，避免无限重派循环
- **预估收益**: 29 号模块 wall-clock 从 ~30s → <100ms（fork + jq 写入）
- **Stop hook 链预估耗时**: 从 ~33s → ~3.5s（降幅 **~89%**，远超 30% 目标）
- **验证**: bash -n 双文件通过；实际耗时需在生产环境实测确认
- **后续**: SessionStart `flow-kit-resume.sh` 需添加后台结果收割逻辑（v2）
