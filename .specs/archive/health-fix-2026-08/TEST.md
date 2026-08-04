# TEST · health-fix-2026-08

> **Phase 5**: Test execution + AC matrix + coverage review
> **执行时间**: 2026-08-04
> **基线对比**: 修复前 687 pass / 4 fail → 修复后 692 pass / 0 fail（+4 修复 + 1 新增）

---

## § 1 · 测试执行总览

| 套件 | 命令 | 结果 | 时长 |
|---|---|---|---|
| **全量 bats** | `make test` | ✅ 692 ok / 0 fail / 0 skip | ~3 min |
| **install_coverage** | `npx bats test/test_install_coverage.bats` | ✅ 17 ok / 0 fail | <5s |
| **install_dry_run** | `npx bats test/test_install_dry_run.bats` | ✅ 4 ok / 0 fail | <5s |
| **shellcheck** | `make lint` | ✅ 0 errors | <2s |
| **bash -n** | `bash -n install_hooks.sh` | ✅ exit 0 | <1s |
| **双源 diff** | `diff test/ flow-kit-bundle/test/` (install_coverage) | ✅ identical | <1s |

**超时处理**: `make test` 692 case 套件需 ≥300s（含 L3 API 网络测试），120s 默认会超时。使用 600000ms 完成。

---

## § 2 · AC 验证矩阵

### 类别 A · 功能正确性（硬门槛）

| AC | 验证方式 | 验证命令 | 结果 |
|---|---|---|---|
| AC-A1 | `make test` exit 0 | `make test 2>&1 \| tail -5` → `✅ bats: all tests passed` | ✅ PASS |
| AC-A2 | 4 原失败 case 全 pass + case-title 锚点 grep | `npx bats test_install_coverage.bats test_install_dry_run.bats` → 0 `not ok`；全量日志 grep 4 条 case 标题各 ≥1 次 | ✅ PASS |

**AC-A2 详情**（原 4 fail case 全部修复）:
- `test_install_coverage.bats::install_hooks DRY_RUN user scope: exit 0 and output contains [DRY-RUN]` — **PASS**（原 fail: PROJECT_DIR_NAME 未绑定 exit 1）
- `test_install_coverage.bats::install_hooks DRY_RUN user scope: mentions .claude/hooks` — **PASS**
- `test_install_dry_run.bats::install_hooks DRY_RUN: no settings.json mutation` — **PASS**
- `test_install_dry_run.bats::install_hooks DRY_RUN: output contains [DRY-RUN] messages` — **PASS**

### 类别 B · 手动验证（硬门槛）

| AC | 验证 | 结果 |
|---|---|---|
| AC-B1 | user-scope dry-run exit 0 · 无 PROJECT_DIR_NAME 错误 | ✅ PASS · 输出 `[claude/user]` banner · stop-hook.json 正常 |
| AC-B2 | project-scope dry-run 含 stop-hook.json | ✅ PASS · `cp .../stop-hook.json -> .../.claude/stop-hook.json` |
| AC-B3 | runtime-edit-guard.sh 安装恢复 | ✅ PASS · `cp .../runtime-edit-guard.sh -> .../pre-tool-use/` |

### 类别 C · 防回归 + 文档（软/硬混合）

| AC | 验证 | 结果 |
|---|---|---|
| AC-C1 | 新 case: user-scope **正确写** stop-hook.json | ✅ PASS · `ok 18` in install_coverage |
| AC-C2 | header 含 FLOW_KIT_PLATFORM + 自加载 | ✅ PASS · `head -8 \| grep` 命中 2 行 |

### 类别 D · 代码质量（硬门槛）

| AC | 验证 | 结果 |
|---|---|---|
| AC-D1 | `bash -n install_hooks.sh` exit 0 | ✅ PASS |
| AC-D2 | `make lint` exit 0 · 不含 Skipping | ✅ PASS · `no errors found` |
| AC-D3 | 双源 diff exit 0 | ✅ PASS · identical |

### 主路径 smoke（L2 FINDING-5）

| 验证 | 命令 | 结果 |
|---|---|---|
| install.sh 主入口 | `DRY_RUN=true bash install.sh --project $(mktemp -d) --hooks-only` | ✅ exit 0 · full banner |

---

## § 3 · 覆盖率评估

### 3.1 · 修复路径覆盖

| 路径 | 覆盖方式 |
|---|---|
| **直接 source** (测试/独立) → paths.sh 自加载 | test_install_coverage.bats (18 cases) + test_install_dry_run.bats (3 cases) |
| **主路径** (install.sh) → resolve_paths 先于 install_hooks() → 守卫 no-op | 主路径 smoke test |
| **平台分支** claude | AC-B1/B2 (默认 claude) |
| **平台分支** opencode | 间接覆盖（守卫代码路径相同，仅 PROJECT_DIR_NAME 值不同） |
| **平台非法值** auto/其他 | `case *)` 分支 → 安全默认（未独立 case · R3 风险低 · 守卫逻辑简单） |

### 3.2 · 回归覆盖

| 风险 | 覆盖 |
|---|---|
| user-scope 崩溃复发 | AC-A2 4 case + AC-C1 新 case |
| stop-hook.json 被误移除 | AC-C1 断言 user-scope **正确写** |
| runtime-edit-guard.sh 被阻断 | AC-B3 |
| 双源不同步 | AC-D3 + `make check` |

### 3.3 · 未覆盖（可接受）

- `FLOW_KIT_PLATFORM=opencode` 的完整 e2e（opencode 平台运行时验证）— **超出本 change 范围**（out-of-scope: paths.sh 本身的设计审查）
- `FLOW_KIT_PLATFORM=invalid` 的 case 显式测试 — 守卫逻辑 `case *) resolve_paths claude` 简单，被现有 claude case 间接覆盖

---

## § 4 · 测试基线对比

| 指标 | 修复前 | 修复后 | Δ |
|---|---|---|---|
| 总 case 数 | 691 | 692 | +1 (AC-C1) |
| pass | 687 | 692 | +5 |
| fail | 4 | 0 | **-4** |
| skip | 0 | 0 | — |
| shellcheck errors | 0 | 0 | — |
| bash -n errors | 0 | 0 | — |

**结论**: 所有硬门槛 AC 通过。测试基线完全恢复并增强（+1 防回归 case）。
