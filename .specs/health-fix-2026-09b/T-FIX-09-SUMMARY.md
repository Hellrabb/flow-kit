# T-FIX-09-SUMMARY — NFR 禁构面与文件名面（R3-15 / R3-16 / R3-22）

**task_id**: T-FIX-09
**commit_sha**: `81c920e61101f599bf9e29f7ec5bc3dbe429a887`
**completed_at**: 1790325843（commit epoch 1790325809 · Δ = 34s ≤ 120s）

## 目标

修复 Makefile `check-nfr-portability-internals` 三个判据失明：
- **R3-15（🔴 头号违禁构造失明）**：`_report_viol()` 用 `awk -v P="$_pat"` 传模式 ⇒ `\brealpath\b` 里的 `\b` 被 awk -v 解释为退格（0x08）⇒ `realpath`（本仓头号 GNU-only 构造）永不命中。
- **R3-16（🔴 文件名含空格即静默跳过）**：`:168`/`:187` 未加引号 `for _f in $$(git …)` ⇒ 含空格文件名词拆成两段、两段皆「不存在 ⇒ 跳过」却仍打印 ✅。
- **R3-22（🟡 永久门禁锚点硬编码）**：`:204` 把 `.specs/health-fix-2026-09b/.change-base` 写死进永久 Makefile ⇒ 归档后路径消失 ⇒ SKIP + exit 0 ⇒ 永久静默未验证。

## 改动清单（文件:行）

| 文件 | 改动 |
|------|------|
| `Makefile:120` | 注释移除 change id（`AC-6` 简化） |
| `Makefile:129` | 注释移除 change id（`AC-8 NFR 侧 · T28` 简化） |
| `Makefile:162-259` | recipe 重写：`_scan_tracked_file()` 新增 + `_report_viol()` 改 ENVIRON[\"P\"] + BAN 词边界改写 + 两面 `while read -d \"\"` + 锚点发现重写 |
| `Makefile:217` | BAN: `\brealpath\b` → `(^|[^[:alnum:]_])realpath([^[:alnum:]_]|$)` |
| `Makefile:233-258` | 锚点发现：`FLOW_KIT_CHANGE_BASE` → `.flow-active` change_id → `.specs/<id>/.change-base` → 通配（1=用+打印来源 / ≥2=🔴具名 / 0=全量模式） |
| `test/test_nfr_portability_gate.bats:141-247` | 新增 7 例回归钉（R3-15 realpath / R3-16 空格名 untracked+tracked / R3-22 全量模式不退化+fail-closed+锚点选中+多锚点具名红） |
| `flow-kit-bundle/test/test_nfr_portability_gate.bats` | 镜像同步（`make test-sync`） |
| `.specs/STATE.md:48-49` | 基线计数行 1047 → 1054 + T-FIX-09 演进注 |

## RED → GREEN 证据

### RED（修复前 · /tmp/tfix9_red_capture.sh）
```
R3-15: realpath .          → rc=0 假绿 ✅（mapfile → rc=2 正确红）
R3-16: sp ace.sh untracked → rc=0 假绿 ✅
R3-16: sub/sp ace.sh tracked → rc=0 假绿 ✅
R3-22: 无锚点              → SKIP rc=0 未验证
grep -c 'health-fix-2026-09b' Makefile = 3
```

### GREEN（修复后 · /tmp/tfix9_green_capture.sh）
```
R3-15: 10/10 token rc=2 ✅RED
  mapfile / readarray / declare -A / realpath / readlink -f
  stat -c / sed -i / grep -P / find -printf / timeout
R3-16: sp ace.sh untracked → rc=2 ✅RED（sp ace.sh:1:mapfile）
R3-16: sub/sp ace.sh tracked → rc=2 ✅RED（sub/sp ace.sh:2:mapfile）
R3-22: 无锚点 → 全量模式 rc=2 ✅RED（sub/newmath.sh:1:mapfile）
R3-22: .flow-active 指向 → ℹ️ 锚点来源: .specs/change-a/.change-base + rc=2 ✅
R3-22: 多锚点+坏.flow-active → 🔴 检测到 2 个 + rc=2 ✅RED
grep -c 'health-fix-2026-09b' Makefile = 0 ✅
```

## `<verify>` 输出尾部

```
bats: 1054 ok / 0 not-ok / count=1054
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过
```

### 已知偏差（非 T-FIX-09 回归）
`make check` 中 `check-path-privacy` 因工作树中 `.specs/health-fix-2026-09b/MINOR-DEFERRED.md`（冻结件，主 agent 预改）第 1301 行含字面探针路径（文档表格中的泄漏示例，形如 `<探针路径>/leak.txt`；原文已由主 agent 按 L-129 去标识化）而红。实测：用 HEAD 版 MINOR-DEFERRED.md ⇒ check-path-privacy ✅ rc=0（命中 0 条）；恢复工作树版 ⇒ 🔴 命中 1 条。此红与 T-FIX-09 Makefile 改动无关（Makefile diff 仅改注释去 change id，不影响 path-privacy 逻辑）。主 agent 预改的冻结件工作树状态不属于本任务写面。

## 全量模式语义说明（主 agent m00091 要求）

全量模式（无锚点时）扫描全部 tracked `.sh` 的**现有行**。本仓真实 tracked `.sh` 现有行（剥注释 + 剥 `stat -c…||stat -f…` 双形态后）会命中 BAN 19 处 / TMOUT 14 处（如 `flow-kit-bundle/hooks/stop/lib/common.sh:432 declare -A`、`flow-kit-bundle/hooks/stop/lib/l3-truncate.sh:167 mapfile -t`、`flow-kit-bundle/hooks/stop/00-gate.sh:71 timeout 120 bash`）。⇒ 全量模式在本仓**本来就该红**（fail-closed，符合 R3-22 意图）。变更期用锚点限定到 diff 新增行，归档后若无锚点则全量扫现有行——这是正确语义，不是 bug。

## 提交 sha

`81c920e61101f599bf9e29f7ec5bc3dbe429a887`

## 6 维自评

| 维度 | 评分 | 说明 |
|------|------|------|
| 判据忠实度 | ✅ | 三 bug 全按 `<action>` 修法修；`<verify>` 预检订正（TD-072）已遵守 |
| 写面纪律 | ✅ | 仅 `<write_files>` 路径入库；冻结件未触 |
| TDD | ✅ | RED 原文（修复前）+ GREEN 原文（修复后）均捕获；夹具 `mktemp -d` 隔离 |
| bash 3.2 兼容 | ✅ | 无 `declare -A`/`mapfile`/`sed -i`；参数展开+case 替代 grep/sed 单引号嵌套 |
| 测试活性 | ✅ | 7 例回归钉在运行时复制真实 Makefile，改坏即红 |
| 证据可复现 | ✅ | RED/GREEN 脚本可重跑；`grep -c` 自证 change id 清零 |

## 残余风险
- 全量模式对本仓会红（BAN 19/TMOUT 14）——归档后需有新 change 的 `.change-base` 或显式 `FLOW_KIT_CHANGE_BASE` 才能通过；这是 fail-closed 正确语义，非回归。
- `check-path-privacy` 红来自冻结件 MINOR-DEFERRED.md 工作树状态——主 agent 需在收口前处理该冻结件的工作树偏差。
- bash -c '...' 单引号体内用 `\\\"` 转义双引号做参数展开——对非 bash 的 /bin/sh 不可移植，但 recipe 显式 `bash -euo pipefail -c`，且本仓目标机为 bash，不构成风险。
