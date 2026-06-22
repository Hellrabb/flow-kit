# TEST: brooks-lint npm 工具离线打包

- **Change ID**: `bundle-packaging`
- **关联**: `@.specs/bundle-packaging/REQUIREMENT.md`、`@flow-kit/reference/test-pyramid.md`
- **项目类型**: CLI / Bash 脚本（meta/distribution 项目）

---

## 0. 本次测试范围声明（5 轮金字塔）

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 8 AC | — |
| 第 2 轮 · 性能 | ❌ 跳过 | — | Bash 脚本打包工具，无 Web UI / API 端点 / 数据库查询，无性能预算定义 |
| 第 3 轮 · 安全 | ⚠️ 部分 | Shell 语法 + 路径安全 | 无 npm 依赖（打包脚本本身无 package.json）、无容器镜像、无外部 API |
| 第 4 轮 · 兼容 | ⚠️ 部分 | linux-x64 + bash 版本 | 纯 Bash 脚本，无浏览器 / DB 迁移；仅需验证目标平台兼容性 |
| 第 5 轮 · 可观测 | ❌ 跳过 | — | CLI 工具一次性执行，无运行时、无日志系统、无 metrics |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例）

| AC | 类型 | 用例文件 / UAT | 状态 |
|---|---|---|---|
| AC-1 depcheck 离线可用 | manual | UAT-1（需目标环境） | ⚠️ 待目标环境 |
| AC-2 jscpd 离线可用 | manual | UAT-2（需目标环境） | ⚠️ 待目标环境 |
| AC-3 knip 离线可用 | manual | UAT-3（需目标环境） | ⚠️ 待目标环境 |
| AC-4 ts-prune 离线可用 | manual | UAT-4（需目标环境） | ⚠️ 待目标环境 |
| AC-5 打包产出 brooks-tools | unit | `test_install_brooks_tools.bats` + E2E tarball check | ✅ |
| AC-6 Node.js 缺失提示 | unit | `test_install_brooks_tools.bats: test 5` | ✅ |
| AC-7 现有打包不退化 | regression | `test/` 全部 94 tests | ✅ |
| AC-8 shim 可被调用 | unit | `test_install_brooks_tools.bats: test 4` | ✅ |

### 1.2 UAT 脚本

#### UAT-1~4 · 目标环境离线工具验证

- **前置**: CentOS 8 x86_64，Node.js ≥ 18 已安装，`flow-kit-bundle.tar.gz` 已解压并执行 `./install.sh --global`
- **步骤**: 
  1. 打开新的 bash shell
  2. 依次执行 `depcheck --version` / `jscpd --version` / `knip --version` / `ts-prune --version`
- **期望**: 每个命令返回版本号，退出码 0
- **实际**: ⏸ 待目标环境执行
- **执行人 / 时间**: ___ / ___

### 1.3 覆盖率

```text
本项目为 Bash 脚本项目，bats 测试覆盖安装流程关键路径。
测试数量：94 tests（含本次新增 5 tests）
```

- 关键路径覆盖：T01 install_brooks_tools.sh 语法 ✅、DRY_RUN ✅、源缺失 ✅
- T02 Part G npm pack ✅、tarball 结构 ✅
- T03 --no-brooks-tools flag ✅、check_node ✅
- T04/T05 E2E ✅

### 1.4 边界 / 错误路径用例

- 源缺失：`brooks-tools/` 不存在 → install_brooks_tools 跳过 ✅
- npm 不可用：Part G 输出跳过提示 ✅
- Node.js 缺失：check_node 输出提示，不阻断安装 ✅
- PATH 不含 ~/.local/bin：输出添加 PATH 提示 ✅

### 1.5 测试质量自检（6 维测试衰退风险）

> brooks-lint 已装，使用内置 6 维快查（bats 测试不适用 brooks-test skill）。

| 编号 | 测试衰退风险 | 命中 | 说明 |
|---|---|---|---|
| T1 | Test Obscurity | 0 | 每个 bats test 有清晰的 `@test "描述"` 名称 |
| T2 | Test Brittleness | 0 | 测试基于公开接口（CLI flags、函数签名），不绑定实现细节 |
| T3 | Test Duplication | 0 | 无重复测试 |
| T4 | Mock Abuse | 0 | 使用 DRY_RUN 模式替代 mock，等效验证真实行为 |
| T5 | Coverage Illusion | 0 | 每个 test 都有显式 `[ "$status" -eq 0 ]` 或 `[[ "$output" =~ ... ]]` 断言 |
| T6 | Architecture Mismatch | 0 | bats tests 匹配 Shell 项目层级（脚本语法→DRY_RUN→E2E） |

**处理**：0 命中，无测试质量债务。

---

## 第 2 轮 · 性能测试

> **跳过**。本项目为 Bash 打包脚本，无 Web 页面（Lighthouse）、无 API 端点（k6/locust）、无数据库查询（EXPLAIN ANALYZE）。性能预算已在 REQUIREMENT.md 列出（安装 ≤ 30s，首次执行 ≤ 3s），但无法在当前环境精确测量——需在目标离线 CentOS 8 上验证。

---

## 第 3 轮 · 安全测试

### 3.1 依赖漏洞

> **跳过**。打包脚本本身无 `package.json`、无 pip/Go/Cargo 依赖。brooks-lint 插件本体不在此 change 范围内。npm pack 产出的 brooks-tools 依赖树来自 npm registry，由 registry 侧负责安全扫描。

### 3.2 秘钥扫描

> **跳过**。纯 Shell 脚本，无硬编码密钥/Token。未引入新配置文件。

### 3.3 SAST

```bash
$ bash -n package-flow-kit.sh && bash -n flow-kit-bundle/install.sh && bash -n flow-kit-bundle/lib/install_brooks_tools.sh
```
- 所有脚本语法检查通过（`set -euo pipefail` 已就位）
- `shellcheck` 未运行（开发机未装），建议后续 CI 中加入

### 3.4 OWASP Top 10

| 项 | 状态 | 备注 |
|---|---|---|
| A01-A10 | ❌ 不适用 | Bash 打包脚本，无 HTTP 端点、无认证、无数据库、无服务器 |

---

## 第 4 轮 · 兼容性测试

### 4.1 平台

| 平台 | 状态 | 备注 |
|---|---|---|
| linux-x64 (CentOS 8) | ⏸ 待目标环境 | tarball 已生成，dry-run 通过 |
| 当前开发机 (Arch Linux) | ✅ | npm pack + bats tests 全部通过 |

### 4.2 数据迁移

> **跳过**。无数据库 schema 变更。

### 4.3 Bash 版本

- 开发机: Bash 5.x ✅
- 目标 CentOS 8: Bash 4.4 ✅（`declare -A` 需 Bash ≥ 4.0，已兼容）

---

## 第 5 轮 · 可观测性验证

> **跳过**。CLI 工具一次性执行，无运行时、无日志系统、无 metrics、无 health endpoint。

---

## 新增测试登记

| 用例文件 | 类型 | 覆盖 AC | 所属轮次 |
|---|---|---|---|
| `test/test_install_brooks_tools.bats` | unit | AC-5, AC-6, AC-8 | 1 |

## 回归保护

本次变更影响的旧功能：
- `package-flow-kit.sh` Part A-F 打包逻辑 → 94 bats tests 全通过 ✅
- `install.sh` 现有 install_brooks_lint 流程 → `--no-brooks` flag 测试通过 ✅
- `install.sh` 参数解析 → 所有现有 flag 测试通过 ✅
