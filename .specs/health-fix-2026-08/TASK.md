# TASK · health-fix-2026-08

> **来源**: DESIGN.md rev 2 · REQUIREMENT.md rev 3
> **路径**: 最短（纯 bug 修复 · REQUIREMENT+DESIGN 已涵盖设计）

---

## Wave 1 · 生产代码修复（1 任务 · 串行）

### Task-1 · install_hooks.sh Fix A + Fix C

**文件**: `flow-kit-bundle/lib/install_hooks.sh`
**读约束**: `read_files: [flow-kit-bundle/lib/install_hooks.sh, flow-kit-bundle/lib/paths.sh]`
**写约束**: `write_files: [flow-kit-bundle/lib/install_hooks.sh]`

**步骤**:
1. **Fix C** (L1-5 header): 更新注释，增加自加载说明 + FLOW_KIT_PLATFORM 说明
2. **Fix A** (L36 之后 · install_hooks 函数体内 · echo 之前): 插入 paths.sh 自加载守卫
```bash
  # ── 依赖自加载 ──────────────────────────────────────────────
  if [ -z "${PROJECT_DIR_NAME:-}" ] && [ -n "${SCRIPT_DIR:-}" ]; then
    source "${SCRIPT_DIR}/lib/paths.sh"
    case "${FLOW_KIT_PLATFORM:-claude}" in
      claude|opencode) resolve_paths "${FLOW_KIT_PLATFORM:-claude}" ;;
      *) resolve_paths claude ;;
    esac
  fi
```
3. **不修改 L97** — 保持两 scope 都装 stop-hook.json

**验证** (单任务后):
- `bash -n flow-kit-bundle/lib/install_hooks.sh` exit 0 (AC-D1)
- `make lint` exit 0 · 不含 `Skipping lint` (AC-D2)
- 手动 dry-run: `DRY_RUN=true SCRIPT_DIR=$(pwd)/flow-kit-bundle HOME=$(mktemp -d) bash -c "source flow-kit-bundle/lib/install_hooks.sh; install_hooks \$(mktemp -d) user"` exit 0 · 无 PROJECT_DIR_NAME 错误

**done 条件**: bash -n exit 0 + make lint exit 0 + user-scope dry-run exit 0

---

## Wave 2 · 防回归测试（1 任务 · 串行 · 依赖 Wave 1）

### Task-2 · AC-C1 bats case + 双源同步

**文件**: `test/test_install_coverage.bats` + `flow-kit-bundle/test/test_install_coverage.bats`
**读约束**: `read_files: [test/test_install_coverage.bats]`
**写约束**: `write_files: [test/test_install_coverage.bats, flow-kit-bundle/test/test_install_coverage.bats]`

**步骤**:
1. 在 `test/test_install_coverage.bats` 末尾新增 case:
```bash
@test "install_hooks DRY_RUN user scope: writes stop-hook.json to user config dir" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  HOME="$TEST_TMPDIR" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_hooks '$TEST_TMPDIR' user
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "stop-hook.json" ]]
}
```
2. `cp test/test_install_coverage.bats flow-kit-bundle/test/test_install_coverage.bats`（双源同步）
3. `diff test/test_install_coverage.bats flow-kit-bundle/test/test_install_coverage.bats` exit 0 (AC-D3)

**验证**:
- `npx bats test/test_install_coverage.bats --filter "writes stop-hook.json"` exit 0
- `diff test/test_install_coverage.bats flow-kit-bundle/test/test_install_coverage.bats` exit 0

**done 条件**: 新 case pass + 双源 diff exit 0

---

## Wave 3 · 全量验证（1 任务 · 串行 · 依赖 Wave 1+2）

### Task-3 · AC 全量验证

**步骤** (按 REQUIREMENT AC 顺序):
1. `make test; echo "exit=$?"` → exit 0 · 含 `✅ bats: all tests passed` · 不含 `not ok` (AC-A1)
2. 分文件验证 4 原失败 case (AC-A2):
   - `npx bats test/test_install_coverage.bats` 全量无 `not ok`
   - `npx bats test/test_install_dry_run.bats` 全量无 `not ok`
3. AC-B1 user-scope dry-run exit 0 · stderr 无 PROJECT_DIR_NAME
4. AC-B2 project-scope dry-run 含 stop-hook.json
5. AC-B3 project-scope dry-run 含 runtime-edit-guard.sh
6. AC-C2 `head -20 install_hooks.sh` 含 FLOW_KIT_PLATFORM 说明
7. AC-D1 `bash -n install_hooks.sh` exit 0
8. AC-D2 `make lint` exit 0 · 不含 `Skipping lint`
9. AC-D3 双源 diff exit 0
10. 主路径 smoke: `DRY_RUN=true SCRIPT_DIR=$(pwd)/flow-kit-bundle bash flow-kit-bundle/install.sh --project $(mktemp -d) --hooks-only` exit 0

**done 条件**: 全部 AC pass

---

## 依赖图

```
Task-1 (Fix A+C) ──→ Task-2 (AC-C1 test) ──→ Task-3 (verify all)
```

全串行 · 无并行机会（单文件 fix + 验证链）
