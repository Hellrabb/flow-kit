# DESIGN — health-debt-cleanup

> 2026-07-20 · 从已批准 plan 反向生成（代码已实施 · 补工件用）

## 0. 技术栈选定

锁定：**Bash + bats-core 1.13.0**（与 CONTEXT.md 一致 · 纯 Shell 项目 · 无变更）

## 0.5 既有架构对齐

### 触碰模块

| 本次触碰 | 路径 | 改动类型 |
|----------|------|----------|
| Stop hook 26-workflow.sh | `flow-kit-bundle/hooks/stop/26-workflow.sh` | 函数重命名（11 处） |
| flow-kit-artifacts.sh | `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh` | 注释更新（1 处） |
| CONTEXT.md | `.specs/CONTEXT.md` | 追加三段 |
| LESSONS.md | `.specs/LESSONS.md` | 条目状态更新 |
| 新增测试 | `test/test_install_coverage.bats` | 新建（16 bats cases） |

### 沿用 vs 引入

| 本次需要 | 既有？ | 决定 |
|----------|--------|------|
| 命名约定 | 无正式文档 | 新记录到 CONTEXT.md（公共 `fk_*` + 私有 `_*`） |
| install 函数测试 | `test_install_dry_run.bats` | 沿用 DRY_RUN 模式 + 新建补充覆盖 |
| `_grep` 兼容层 | `fix-compliance.sh:20` | **保留**（跨环境兼容 · 决策标注） |

### 不应触碰的模块

- `brooks-lint/plugin/` — 第三方代码
- `regression-demos/` — 独立测试夹具
- `.specs/health/` 和 `.specs/archive/` 中的历史 `.md` — 保留原始命名（可追溯性）

## 1. 技术决策

**D1 · 命名约定统一**: 两套前缀（公共 `fk_*` + 私有 `_*`）。选择理由：`fk_*` 已是项目主流（20 个公共函数），`_*` 是 bash 通用惯例。备选 `module_prefix_*` 太啰嗦。代价：`check_g*` → `_fk_check_*` 重命名触及 1 模块 + 1 注释。

**D2 · install_hooks 不拆分**: 用户确认暂不拆分。理由：安装脚本非热路径，195 行在初始化代码中可接受。改为补齐测试覆盖（16 bats cases）。

**D3 · `_grep` 保留**: `command grep` wrapper 解决 Claude Code 环境 grep→ugrep 重写导致的 `-P` 兼容问题。6 处调用均在 `fix-compliance.sh` 内，隔离良好。不引入额外依赖。

## 2. 架构图

```
health-debt-cleanup
├── R6 命名约定 ──────── 26-workflow.sh (重命名 11 函数)
│   └── flow-kit-artifacts.sh (注释更新)
├── T5 测试补齐 ──────── test_install_coverage.bats (新建 · 16 cases)
├── CONTEXT.md ──────── 追加命名约定 + _grep 决策 + install 容忍度
└── LESSONS.md ──────── L-052/L-053/观察 → resolved
```

## 3. ADR

无新增 ADR。本 change 为技术债清理，不涉及不可逆架构决策。

## 4. 风险

| # | 风险 | 缓解 |
|---|------|------|
| 1 | 重命名导致 `run_check` 函数名字符串不匹配 | `grep -r 'check_g[0-9]\b'` 零残留验证 |
| 2 | 新增测试依赖 DRY_RUN 行为变更 | 所有测试 isolate 在 `bash -c` 子进程中 |
| 3 | 部署路径未同步 | `cp` 到 `~/.claude/hooks/stop/`（L-050 要求） |

## 5. 不在范围内

- brooks-lint 插件代码（第三方）
- regression-demos 测试夹具
- 其他 stop hook 模块（21-25）的 `check_*` 函数重命名（模块 B-F 各有独立上下文，后续 sweep 单独处理）

## 9. 架构沉淀建议

本 change 无架构层面沉淀建议。改动均为代码风格/测试补齐/文档标注，不产生新的可复用抽象或项目级技术决策。
