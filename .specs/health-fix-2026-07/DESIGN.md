# DESIGN: package-flow-kit.sh 孤儿 fi 修复 + bash -n 门禁加固

> **Lite 版**（最短路径 · 纯 bug 修复）。无架构决策、无数据模型、无 ADR。本文件只锁定技术栈 + 模块边界，供 TASK 的 `read_files`/`write_files` 引用。

- **Change ID**: health-fix-2026-07
- **创建日期**: 2026-07-01

## 0. 技术栈选定

> 沿用 `CONTEXT.md`「技术栈（团队级默认 / 已锁定）」。变栈视为开新 CHANGE（R7.1）。

- **选定**: Bash + bats-core（项目默认栈，无变更）
- **语言/运行时**: Bash（`#!/bin/bash` + `set -euo pipefail`）
- **测试**: bats-core 1.13.0（`npx bats`）
- **构建/部署**: 纯 Shell 脚本，无 CI/CD
- **理由**: 本次是修复既有 Bash 脚本 + 加 bats 测试，完全在既有栈内
- **明确排除**: 不引入 shellcheck 二进制依赖（`bash -n` 已覆盖语法层；shellcheck 风格检查留给未来单独 change）

## 0.5 既有架构对齐（brownfield）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（既有 · 修改）:
- package-flow-kit.sh（仅删 581-587 残留碎片；顶部 19-139 行 validate_staging_coverage() 不动）

新增模块:
- test/test_package_flow_kit.bats（package 专项回归测试 · AC-1/2/3）
- test/test_smoke_syntax.bats（全量 bash -n 门禁 smoke · AC-4）

既有·复用（参考不修改）:
- test/test_quality_baseline.bats（参考其 bats 写法约定）
- test/test_stop_chain.bats（参考其 mock 临时目录手法）

flow-health skill 文档增补（AC-5）:
- flow-kit-bundle/skills/flow-health/SKILL.md（项目内源 · 若存在则改此，进 git）
- ~/.claude/skills/flow-health/SKILL.md（全局 · 若项目内无源则改此，不进 git）

禁动清单（与本次无关，AI 不许"顺手"碰）:
- package-flow-kit.sh:19-139（顶部 validate_staging_coverage 函数体 · --validate 功能依赖）
- .claude/hooks/stop/{27,28}-*.sh + lib/*.sh（本周刚加，176 bats 已覆盖）
- .claude/hooks/session-start/flow-kit-resume.sh
- flow-kit-bundle/hooks/**（镜像，非本次范围，除全量 smoke 只读扫描外不修改）
- .specs/ 下其他 change 工件
```

### 0.5.2 既有抽象沿用对照表

| 既有抽象 | 位置 | 本次如何沿用 |
|---|---|---|
| bats 测试约定（`@test` + `run` + `[ "$status" ... ]`） | `test/test_quality_baseline.bats` | 新测试文件沿用同一风格 |
| 临时目录 mock 手法 | `test/test_stop_chain.bats` | AC-2/AC-3 打包验收复用（避免真打包写 `$HOME/flow-kit-export`） |

### 0.5.3 沿用模式 vs 引入新模式

沿用既有 bats 测试模式，不引入新测试框架 / 新 mock 库。

## 1. 决策清单

- **D1**: 用 `bash -n` 而非 shellcheck —— `bash -n` 是 bash 内建，零依赖，覆盖语法层（本次目标）；shellcheck 风格检查超出范围
- **D2**: 全量 smoke 单独建 `test/test_smoke_syntax.bats` —— 不塞进 `test_quality_baseline.bats`（那是另一个 change 的 AC-1~7，语义不匹配）
- **D3**: 正常打包验收用 mock OUTPUT_DIR —— 避免真打包触发 rsync / npm pack 等重操作与网络副作用

## 5. 风险

- 全量 `bash -n` 可能暴露其他脚本的潜在语法问题。已知 6 个核心脚本语法 OK + 现有 176 bats smoke 覆盖核心 hook，预期全过；若个别边角脚本暴露问题，作为本 change 附带修复项（不另开 change）。

## 6. 不在范围

见 `REQUIREMENT.md`「范围切分 · out」。

## 9. 架构沉淀建议（本 change 完成后供 A-evolve 同步用 · 软约束）

- **9.2 已锁技术决策**: 「所有生产 `.sh` 必须通过 `bash -n`」建议同步到 `CONTEXT.md`「已锁技术决策」段（由 INTEGRATION 阶段或 A-evolve 处理）
- **9.5 禁动清单变化**: 无（本次不新增禁动项）

> 本文件不包含完整代码实现。函数签名、伪代码可以；函数体不行。
