# DESIGN · health-fix-2026-08 (rev 2)

> **关联**: CHANGE.md · REQUIREMENT.md (rev 3 · L2 cross-phase feedback)
> **评分目标**: 89 → ≥98（恢复 baseline）
> **Rev 2 变更**: L2 审查 (bg_5aa6a574) 发现 Fix B 与运行时矛盾 + Fix A 放置错误。Rev 2 删除 Fix B、Fix A 移入函数体、增加平台值校验。

---

## § 0.5 · 既有架构对齐

| 检查项 | 结论 |
|---|---|
| ARCHITECTURE.md 存在？ | ❌（flow-kit 是 distribution bundle · 无项目级架构文档） |
| 影响 ADR？ | 无新增 · 不冲突 |
| CONTEXT.md 禁动清单？ | ✅ `lib/install_*.sh` "不可独立执行" — 本 change 不改变此约束，仅增加防御性自加载 |
| 运行时契约？ | ✅ **已验证**: `common.sh:103-110` `init_paths()` 显式回退 `${HOME}/.claude/stop-hook.json`（gate-integrity dogfood 注释）· stop-hook.json 在 user-scope 是**功能依赖** |

---

## § 1 · 根因分析

### 1.1 · 执行时序（直接 source 路径）

```
source install_hooks.sh; install_hooks <dir> <scope>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
L34   install_hooks() 入口
L43   scope 分支（user/project）
L44/53  paths.sh 变量引用（set -u 未激活 · 空展开 · 不崩溃）
L64   source common.sh ← common.sh:5 set -euo pipefail 激活
L97   PROJECT_DIR_NAME ← set -u 后首个未绑定引用 → exit 1 ❌
L101  settings_file_for() ← 如修复 L97，函数不存在 → exit 127 ❌
L190  PLATFORM ← opencode 分支（如到达）
```

### 1.2 · 根因链

commit `0c79f1c` 引入 `lib/paths.sh` 依赖但未处理"被直接 source"的加载路径。`common.sh:5` `set -euo pipefail` 在 `install_hooks.sh:64` 激活后，L97 引用未绑定的 `PROJECT_DIR_NAME` 导致崩溃。

### 1.3 · baseline 对比

`git show 0c79f1c~1:install_hooks.sh` L79: 硬编码 `$project/.claude/stop-hook.json` + inline if/else（无 paths.sh 依赖）· baseline 无此 bug。

---

## § 2 · 修复方案

### Fix A · paths.sh 自加载守卫（函数体内 · L2 FINDING-2 修复）

**位置**: `install_hooks()` 函数体顶部（L36 之后 · L38 echo 之前）

```bash
install_hooks() {
  local project="$1"
  local scope="${2:-project}"

  # ── 依赖自加载 ──────────────────────────────────────────────
  # install.sh 调用: resolve_paths 已在 install.sh:153 执行 → 此块 no-op
  # 直接 source（测试/独立）: paths.sh 未加载 → 自动加载
  if [ -z "${PROJECT_DIR_NAME:-}" ] && [ -n "${SCRIPT_DIR:-}" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/lib/paths.sh"
    case "${FLOW_KIT_PLATFORM:-claude}" in
      claude|opencode) resolve_paths "${FLOW_KIT_PLATFORM:-claude}" ;;
      *) resolve_paths claude ;;  # auto/非法值 → 安全默认
    esac
  fi

  echo ""
  echo "═══ 安装 Hook 系统 [${PLATFORM}/${scope}] ═══"
  # ... 原有逻辑不变（L97 保持两 scope 都装 stop-hook.json）...
```

**L2 FINDING-2 修复**:
1. **函数体内放置** → 主路径下 `install.sh:153` `resolve_paths` 先于所有 `install_hooks()` 调用（L218/242/252）→ PROJECT_DIR_NAME 已设 → **真 no-op**
2. **平台值校验** → `case` 拦截 auto/非法 → 不让 resolve_paths 返回 1 → 不触发 install.sh:7 `set -e`
3. **L97 不变** → stop-hook.json 两 scope 都装（运行时回退依赖）

### Fix C · header 注释（AC-C2）

```bash
# 自加载：被直接 source 时 install_hooks() 内自动 source paths.sh
# 环境变量 FLOW_KIT_PLATFORM 可覆盖平台（claude|opencode · 非法值→claude）
```

### ~~Fix B~~ · 已删（L2 FINDING-1: stop-hook.json 是 user-scope 运行时回退依赖 · 移除致 module_enabled 恒 false）

---

## § 3 · 影响面

| 文件 | 变更 | 行数 |
|---|---|---|
| `install_hooks.sh` | Fix A（函数体守卫 10 行）+ Fix C（header 2 行） | +12 |
| `test/test_install_coverage.bats` | AC-C1 新 case | +12 |
| `flow-kit-bundle/test/test_install_coverage.bats` | 双源同步 | +12 |

---

## § 4 · 风险

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| 守卫在 SCRIPT_DIR 未设时 no-op | 低 | 中 | 条件含 `[ -n "${SCRIPT_DIR:-}" ]` · 不制造新问题 |
| FLOW_KIT_PLATFORM=auto/非法 | 低 | 中 | `case` 拦截 → 安全默认 claude |
| 双源同步遗漏 | 中 | 中 | AC-D3 + `make check` 双源检测 |
| AC-C1 case 影响 coverage.bats 行号 | 中 | 低 | AC 以 case 标题为锚（非行号） |

---

## § 5 · 实施顺序

1. Fix C（header）→ Fix A（函数体守卫）
2. AC-C1 case → 双源同步
3. 验证: `bash -n` + `make lint` + `make test` + 主路径 smoke

---

## § 6 · 测试策略

| 类型 | AC | 验证 |
|---|---|---|
| 单元 | AC-A1 | `make test` exit 0（692 case 含 AC-C1） |
| 回归 | AC-A2 | 4 原失败 case（分文件 + case 标题 grep） |
| 手动 | AC-B1/B2/B3 | dry-run 验证 |
| 防回归 | AC-C1 | user-scope **正确写** stop-hook.json |
| 质量 | AC-C2/D1/D2/D3 | header + bash -n + lint + 双源 diff |
| 主路径 smoke | 新增 | `install.sh --project --hooks-only` exit 0（FINDING-5） |
