# TEST: pre-commit-user-scope

## 范围声明

| 轮次 | 适用 | 理由 |
|---|---|---|
| 第 1 轮（功能） | ✅ 必跑 | AC-1/2/3 行为测试 |
| 第 2 轮（性能） | ❌ 跳过 | 纯 bash 安装脚本，非热路径 |
| 第 3 轮（安全） | ⚠️ 部分 | 秘钥扫描 N/A；OWASP N/A（无外部输入） |
| 第 4 轮（兼容） | ⚠️ 部分 | 跨 shell 兼容由 bash -n + bats 覆盖 |
| 第 5 轮（可观测） | ❌ 跳过 | CLI 无运行时可观测 |

## AC 测试矩阵

| AC | 测试 | 状态 |
|---|---|---|
| AC-1 (user scope) 正向 | `deploy_pre_commit: user scope (no .git) installs source file only` — test -f 源文件 | ✅ pass |
| AC-1 (user scope) 负面 | 同测试 — ! -d ~/.git + ! -e ~/.git/hooks/pre-commit | ✅ pass |
| AC-1 (project scope) | `deploy_pre_commit: project scope (has .git) creates symlink → source` — test -L + readlink | ✅ pass |
| AC-1 (冲突检测) | 无行为测试（冲突块逐字保留 + 全量回归兜底）| ⚠️ 保留依赖 |
| AC-2 (回归锚点) | 由 AC-1 project scope 块覆盖 | ✅ 声明覆盖 |
| AC-3 (bats 全绿) | `npx bats test/` exit 0 | ✅ 716 ok / 0 fail |

## UAT-1（手动验证 · 可选）

```bash
# user scope 源文件安装
bash flow-kit-bundle/install.sh --platform claude --global --user
test -f ~/.claude/hooks/pre-commit/pre-commit.sh && echo "✅ source installed" || echo "❌ missing"
```

预期：`✅ source installed`（修复前为 ❌ missing）

## 覆盖率

- baseline: 714 ok / 0 fail
- current: 716 ok / 0 fail（+2 新行为测试）
- delta: +2 ok / +0 fail

## 1.4 六维自检（T1-T6）

| 维度 | 命中 | 理由 |
|---|---|---|
| T1 纯文档 diff 检测 | 0 | 本 change 有源码修改（install_hooks.sh） |
| T2 测试衰退 | 0 | +2 新测试，无既有测试修改 |
| T3 证据链 | 0 | 所有引用路径在 read_files + 工具历史中 |
| T4 验证管道 | 0 | verify 去管道，直接判 exit |
| T5 diff 越界 | 0 | 仅 write_files 内文件 |
| T6 禁动碰撞 | 0 | install_hooks.sh 禁外部 source 不禁编辑 |

## 回归登记

- 新增 2 tests：`deploy_pre_commit: user scope (no .git) installs source file only` + `deploy_pre_commit: project scope (has .git) creates symlink → source`
- 既有 22 tests 不变（test_archive_commit_gate.bats T01-T07 段）
- 全量 716 ok / 0 fail
