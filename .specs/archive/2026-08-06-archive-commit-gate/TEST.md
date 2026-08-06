# TEST · archive-commit-gate

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由（如跳过）|
|------|------|------|-------------------|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 AC-1..AC-5 | — |
| 第 2 轮 · 性能 | ❌ 跳过 | — | 纯 bash 脚本工具，无运行时性能预算（无 QPS / 无 LCP）|
| 第 3 轮 · 安全 | ⚠️ 部分 | 秘钥扫描 + 依赖扫描 | 内部工具无 npm/pip deps（纯 bash），无 web 入口 → OWASP 减项 |
| 第 4 轮 · 兼容 | ⚠️ 部分 | bash 版本兼容 | 无数据库迁移 / 无跨浏览器 / 无 API 版本 |
| 第 5 轮 · 可观测 | ❌ 跳过 | — | CLI/hook 工具，无运行时日志/指标/告警系统 |

---

## 第 1 轮 · 功能测试（Functional）

### 1.1 测试矩阵

| AC | 类型 | 用例文件 | 状态 |
|----|------|----------|------|
| AC-1 归档 commit | unit | `test_archive_commit_gate.bats` T07 段（7-integration 5.1 + ARCHIVE_BASE_SHA + commit-protocol）| ✅ |
| AC-2 pre-commit 门禁 | unit | `test_archive_commit_gate.bats` T01 段（无 Makefile skip + make test fail reject + bash -n）| ✅ |
| AC-3 Stop hook 34 | unit | `test_archive_commit_gate.bats` T02+T04+T06 段（骨架 + 注册 + resume dispatch）| ✅ |
| AC-4 install 部署 | unit | `test_archive_commit_gate.bats` T05 段（--yes + deploy_pre_commit + package + validate）| ✅ |
| AC-5 bats 0 fail | regression | `npx bats test/` 全量 **714 ok / 0 fail**（baseline 692/0 → delta +22 ok / +0 fail）| ✅ |

### 1.2 UAT 脚本

```
UAT-1: pre-commit 端到端门禁
  前置：flow-kit-bundle/hooks/pre-commit/pre-commit.sh 已部署为 .git/hooks/pre-commit
  步骤：1. mktemp + git init + cp pre-commit.sh .git/hooks/ + chmod +x
        2. Makefile test target exit 1 → git commit
        3. Makefile test target exit 0 → git commit
  期望：步骤 2 git commit RC=1（rejected）；步骤 3 git commit RC=0（放行）
  通过/失败：✅ 实跑验证（mktemp git init + cp pre-commit.sh + chmod +x · fail→RC=1 / pass→RC=0）

UAT-2: 34-archive-commit-check 双模式检测
  前置：34-archive-commit-check.sh + common.sh + correction-file.sh + correction-types.sh
  步骤：1. pipeline 模式 .flow-active (scope=pipeline + status=done + archive dir) + git dirty → 写 correction
        2. 单阶段模式 .flow-active (goal null) + archive mtime > commit %ct + git dirty → 写 correction
        3. git clean → type-guarded clear
  期望：场景 1/2 写 archive-uncommitted correction；场景 3 清除
  通过/失败：✅ 独立实跑验证（L2 盲审 round 2 确认写/清行为正确）

UAT-3: install deploy_pre_commit 部署
  前置：install.sh + install_hooks.sh
  步骤：1. mktemp + mkdir .git + install.sh --project → deploy_pre_commit 执行
        2. ls -l .git/hooks/pre-commit → symlink 检查
  期望：symlink 创建 + install_file 复制到 hook_dst
  通过/失败：✅ 实跑验证（mktemp + mkdir .git + install.sh --project · RC=0 + symlink → .claude/hooks/pre-commit/pre-commit.sh）
```

### 1.3 覆盖率与边界

本项目纯 bash 脚本，无 `--coverage` 工具。覆盖率以 bats 测试矩阵替代：

- 全量 bats: **714 ok / 0 fail**（baseline 692/0 → delta +22 ok / +0 fail）
- 新增 22 tests 覆盖 8 任务全部 deliverable
- 边界用例：无 Makefile（空状态）+ make test fail（错误路径）+ bash -n 语法（构建验证）
- UAT E2E: UAT-1（commit reject/pass）+ UAT-3（install deploy）实跑验证

### 1.4 测试质量自检 · 6 维测试衰退风险

| 编号 | 衰退风险 | 诊断 | 命中 |
|------|----------|------|------|
| T1 | Test Obscurity | 测试名 Given/When/Then 结构明确（如 "pre-commit.sh: no Makefile → skip message"）| ✅ 无 |
| T2 | Test Brittleness | ~18 条为源码 grep 断言（实现耦合），但 bash CLI 无黑盒输入属合理取舍 | ⚠️ 有（合理）|
| T3 | Test Duplication | 每个测试覆盖不同文件/不同断言点，无重复 | ✅ 无 |
| T4 | Mock Abuse | 无 mock（纯文件 grep + bash -n + 行为验证）| ✅ 无 |
| T5 | Coverage Illusion | 每个测试有实质断言（grep -q / status eq / output match）| ✅ 无 |
| T6 | Architecture Mismatch | 全部 unit 级（grep + bash -n），匹配 CLI 工具层级 | ✅ 无 |

**命中 1 项（T2 · 合理取舍）** — 测试套件质量达标。

---

## 第 3 轮 · 安全测试（部分）

### 3.1 依赖漏洞扫描

本项目纯 bash 脚本，无 npm/pip/cargo 依赖。`npm audit` 无 production deps。

### 3.2 秘钥扫描

```bash
# 新增文件检查
grep -rE '(api_key|secret|password|token).*=' flow-kit-bundle/hooks/pre-commit/ flow-kit-bundle/hooks/stop/34-archive-commit-check.sh
# 结果：0 命中（纯逻辑脚本，不含敏感信息）
```

### 3.3 OWASP Top 10

CLI/hook 工具无 web 入口 → A01-A10 全部 ❌ 不适用。

---

## 第 4 轮 · 兼容性测试（部分）

### 4.1 跨 shell 兼容

- `#!/bin/bash` + `set -euo pipefail`：明确 bash 依赖
- `bash -n` 语法验证通过：pre-commit.sh + 34-archive-commit-check.sh + install_hooks.sh
- 未使用 bashism 外的 shell 特定语法

### 4.2 无数据库迁移 / 无跨浏览器 / 无 API 版本

---

## 步骤 N · 回归测试登记

| 测试文件 | 新增/修改 | 覆盖 AC |
|----------|-----------|---------|
| `test/test_archive_commit_gate.bats` | 新增（22 tests）| AC-1..AC-5 |
| `flow-kit-bundle/test/test_archive_commit_gate.bats` | 同步副本 | AC-1..AC-5 |
