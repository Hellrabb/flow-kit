# CHANGE: M-health eval 巡检收尾 — 修测试路径残留 + 点亮 lint 门禁 + 清 CONTEXT 空占位

- **Change ID**: health-cleanup-2026-07-08
- **创建日期**: 2026-07-08
- **路径建议**: 最短（TASK → DEV → TEST → REVIEW → INTEGRATION）· 纯 bug 修复 + 清理，无新需求 / 无架构变更
- **状态**: draft

---

## Why（为什么做）

2026-07-08 M-health eval 巡检（bats 实跑 exit 0 + health 报告 + 结构探查）发现 3 个低风险收尾问题 + 一批杂物残留。本 change 收口它们，让**质量门禁真正生效**、**测试路径残留清零**、**CONTEXT 回到目标行数**。第 4 个问题（l3-review 重构）性质不同，已延后到独立 change。

具体触发证据：

- **T1 测试路径残留**：bats 实跑暴露 `test/test_package_flow_kit.bats:15/32` 硬编码 `/home/hellrabbit/unisoc/package-flow-kit.sh`（缺 `flow-kit/` 层）→ exit 127（BW01 warning，不阻断所以被 L-025 修复漏过）。这是 L-025「测试路径双重前缀」的**同源残留**。
- **T2 lint 门禁空转**：`make lint` 因 `SHELLCHECK := $(shell which shellcheck)` + `ifdef` 检测在当前环境失效（疑似 RTK proxy 改写 `which`），误报 "not installed" 而跳过 —— shellcheck **实际已装** 0.9.0。真跑发现 error 级仅 6 个（5 个 `install_*.sh` line 1 + `independent-review-gate.sh:68`），且 lint target 扫描覆盖**漏了 `pre-tool-use/` 子目录**。
- **T3 CONTEXT 超标**：`.specs/CONTEXT.md` 435 行，超 ARCHITECTURE.md 自定目标 200-400。抽象索引里 HTTP 客户端 / 数据库访问 / 状态管理 / 自定义 hooks(前端) / 错误处理 / Schema 迁移 **全是 intel-scan 生成的 3 行空占位**，对 flow-kit 这个 bash 项目不适用。
- **T4 杂物残留**：`.specs/null/`（误建目录）、`.specs/STATE.md.tmp`（临时文件）、`.specs/health/tmp/`、`.specs/CONTEXT.md.bak-2026-07-08`（备份未清）。

## What（做什么）

一个极简收尾 change，4 个低风险 task：

- **T1**：`test_package_flow_kit.bats` 路径硬编码改用 `${BATS_TEST_DIRNAME}/../package-flow-kit.sh`（消除 BW01 exit 127）。
- **T2**：修 Makefile lint 检测（`command -v` 或 `$(shell shellcheck --version)` 替代失效的 `$(shell which)`）+ 扫描覆盖补 `pre-tool-use/` + 修 6 个 shellcheck error（仅 error 级）。
- **T3**：删 CONTEXT 抽象索引里的空占位章节（HTTP/DB/状态/hooks前端/错误/Schema），**保留**有内容的 flow-kit 核心抽象（35 行）+ 禁动清单（39 行）+ 工具函数，回到 ~400 行内。
- **T4**：清杂物（null/ 目录、STATE.md.tmp、health/tmp、CONTEXT.md.bak）。

## 影响面

- [ ] 影响 `REQUIREMENT.md`（否 · 纯 bug/清理，无新需求）
- [ ] 影响 `DESIGN.md` / 引入新 ADR（否 · 0.4 架构预检未命中，无架构变更）
- [ ] 影响现有 AC（否）
- [ ] 影响数据模型 / 迁移（否）
- [ ] 影响外部 API 兼容性（否）
- [x] 仅修复 bug + 清理，无范围变化

## 范围排除（这次不做）

- **l3-review.sh `l3_review_run()` 260 行单函数拆分**：性质是**重构**（非 bug），需独立 DESIGN + 风险隔离。本次仅写入 `.specs/LESSONS.md` 标注排期，等独立窗口另起 change `refactor-l3-review-split`。
- **shellcheck 117 个 warning/info 级指示**：scope 大且非阻断。本次只修 6 个 error 级；warning/info 记入 TECH-DEBT 后续专项清理。
- **intel-scan 模板（`templates/CONTEXT.md`）的通用章节结构改造**：T3 只清本项目实例的空占位，**不改模板本身**（改模板影响所有项目，超出本 change 范围）。
- **STATE.md 的 `last_change_archived` 字段更新**（仍停在 l3-comprehensive-fix，未跟进 health-fix-2026-07-08）：非本 change 主题，归档时另处理。

## 验收线（粗粒度，不是 AC）

1. `make lint` 真正运行 shellcheck 并输出结果（不再误报 not installed），6 个 error 清零。
2. `make test` 全绿，`test_package_flow_kit.bats` 的 BW01 warning（exit 127）消失。
3. `wc -l .specs/CONTEXT.md` ≤ 400，且禁动清单 / flow-kit 核心抽象等有内容章节完好保留。
4. `.specs/null/`、`STATE.md.tmp`、`health/tmp/`、`CONTEXT.md.bak` 清除。

## 风险与未知

- **T2 Makefile 检测修法**：`$(shell which shellcheck)` 失效根因疑似 RTK proxy 改写 which。需在 make 子 shell 里验证 `command -v shellcheck` / `$(shell shellcheck --version >/dev/null 2>&1 && echo ok)` 哪种可靠。低风险（Makefile 局部改动）。
- **T2 修 6 个 shellcheck error**：5 个 `install_*.sh` 在 line 1（疑似 SC2148 缺 shebang 类），`independent-review-gate.sh:68` 需看具体指示。error 级通常 1-2 行改，低风险。
- **T3 删 CONTEXT 空占位**：探查已确认各章节 3 行占位（标题 + 1-2 行示例），禁动清单（39 行）/ flow-kit 核心抽象（35 行）/ 工具函数（8 行）有内容不误删。低风险。
- 无破坏性变更，无 schema / 迁移 / 外部 API 影响。

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
