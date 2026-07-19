# TEST — health-debt-cleanup

> 2026-07-20 · 测试执行报告

## 测试矩阵

| 测试文件 | cases | pass | fail | 说明 |
|----------|-------|------|------|------|
| `test_install_coverage.bats` | 16 | 16 | 0 | 新增 · install 函数补齐覆盖 |
| `test_install_dry_run.bats` | 4 | 4 | 0 | 既有 · DRY_RUN 模式 |
| `test_install.bats` | 11 | 11 | 0 | 既有 · CLI 参数 |
| `test_install_brooks_tools.bats` | 5 | 5 | 0 | 既有 · brooks-tools |
| 其余 40+ bats 文件 | 523 | 523 | 0 | 既有 · 全覆盖 |
| **总计** | **559** | **559** | **0** | ✅ |

## 测试覆盖

### 新增覆盖（T5）

| # | 被测函数 | 测试内容 | 结果 |
|---|----------|----------|------|
| 1-2 | `install_flow_kit_core()` | DRY_RUN 输出 + flow-kit 目录提及 | ✅ |
| 3-4 | `install_skills()` | DRY_RUN 输出 + flow- skills 提及 | ✅ |
| 5-6 | `install_specs_template()` | DRY_RUN 输出 + 已存在 .specs/ 跳过 | ✅ |
| 7-8 | `install_hooks()` user scope | DRY_RUN 输出 + .claude/hooks 路径 | ✅ |
| 9-10 | `install_brooks_lint()` | DRY_RUN 输出 + brooks-lint mention | ✅ |
| 11-14 | `install_brooks_tools()` | shim 列出 + 源缺失跳过 + PATH warning | ✅ |
| 15-16 | `install_file()` helper | DRY_RUN 不复制 + 非 DRY_RUN 复制 | ✅ |

## 语法门禁

```bash
$ find . -name '*.sh' -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/brooks-lint/*' -not -path '*/brooks-tools/*' \
  -not -path '*/.claude/plugins/*' -exec bash -n {} \; -print 2>&1
```
**结果**: 63 脚本 · 0 语法错误 ✅

## 验收线对照

| # | 验收条件 | 状态 |
|---|----------|------|
| 1 | `grep -rn '\<check_g[0-9]_body\>\|\<check_g[0-9]()\>' flow-kit-bundle/hooks/ --include='*.sh'` 零命中（word-boundary 精确匹配，新旧名不误判） | ✅ |
| 2 | install 函数 ≥ 15 bats cases | ✅ (16) |
| 3 | CONTEXT.md 追加三段（命名约定 + _grep + install 容忍度） | ✅ |
| 4 | `make test` 全绿 · 0 fail | ✅ (559/0) |

## UAT

```bash
# 验收脚本（可手工执行）
npx bats test/ && echo "✅ ALL PASS" || echo "❌ FAILURES"
```
