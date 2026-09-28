# T24-SUMMARY · 分发件处置（D4）：重建 `0.2.0`、删除可注入的 `0.1.0`

- **Change ID**: `health-fix-2026-09b`
- **Task ID**: T24（Wave 7 · serial 2 · model-tier=standard · parallel=true · depends_on T05,T07,T11,T12,T16,T20,T25,T26）
- **关联**: `@.specs/health-fix-2026-09b/TASK.md`（T24 块）、`@.specs/health-fix-2026-09b/DESIGN.md`（§1 D4 归档处置裁决 + D9「只改源头不重建等于没修」）、`@.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-1④ 分发归档面 + AC-5 npm 包面 + L2 C4「归档此前无任何门禁」）
- **执行**: 阶段 4（DEV）· 2026-09-24
- **契约单一来源**: T24 `<task>` 块（name/read_files/write_files/action/verify/done）

---

## 任务

T24 是分发件收口任务：在 T05/T07/T11/T12/T16/T20/T25/T26 全部落地后（== 最后一个改动源面的步骤），

1. `bash package-dsh-plugin.sh`（无参数）重建 `dist/dsh-flow-kit-0.2.0.tgz` + 刷新 `dist/dsh-flow-kit/` 包目录；
2. 删除 `dist/dsh-flow-kit-0.1.0.tgz`（该档从未发布、无兼容义务，保留即继续分发一个**已知可注入**的发布件——实测修复前两档各含 2 处 `$(eval echo …)`）；
3. **禁止**手工编辑 `.tgz` 内文件（必须经打包路径产出，保证 staging 与源同源）；
4. 跑 `<verify>`：归档 `eval-echo=0` / `chisel=0`、0.1.0 已删、归档含修复后的 vendored 拦截器；
5. **只改源的面已冻结**（HEAD `91f51d5`）；若发现需改源码 ⇒ 停下报 BLOCKED。

**本 task 未改动任何源/产品件**（无生产代码改动）。本项目非 React / 无 UI-DESIGN 依赖、无 schema、无公共 API 破坏性变更 ⇒ 对应小节跳过（step 1.6 / 1.7 / 1.8 不适用；grep 面为归档内容）。

---

## 产物（before → after）

| 文件 | before | after |
|---|---|---|
| `dist/dsh-flow-kit-0.1.0.tgz` | `1208117` 字节（`8月16 03:13`）· 含 2 处 eval-echo | **已删除** |
| `dist/dsh-flow-kit-0.2.0.tgz` | 修复前同档 `1361815` 字节（含 2 处 eval-echo + 6 处 chisel，但内容旧） | `1385199` 字节（`9月24 02:44` 本次重建）· eval-echo=0 / chisel=0 |
| `dist/dsh-flow-kit/`（包目录） | 陈旧（`check-dist` 报 12 处陈旧+2 处缺失） | 由打包路径刷新，`check-dist` 逐文件比对全部一致 |
| `.specs/health-fix-2026-09b/TASK.md` | T24 行 `status="pending"` | `status="done"` |

> `dist/` 被 `.gitignore:63` 忽略 ⇒ 构建产物不入库；本次提交只含 `T24-SUMMARY.md`（新增）+ `TASK.md`（状态行）。

### check-dist 重建前（rc=2）抽样

```
❌ 陈旧: .../dist/dsh-flow-kit/vendor/flow-kit-bundle/lib/validate_staging.sh（不一致 → 请重建 dist）
❌ 缺失: .../dist/dsh-flow-kit/flow-kit/reference/check-path-privacy.sh（源: .../check-path-privacy.sh）
❌ 缺失: .../dist/dsh-flow-kit/flow-kit/reference/path-privacy-allowlist.txt
→ 修复: bash package-dsh-plugin.sh
make: *** [Makefile:348：check-dist] 错误 1
```
（所列绝对路径为门禁标准输出，非本 SUMMARY 撰写内容；本 SUMMARY 全程未含真实本机绝对路径。）

---

## 判据实跑（原样 + 输出）

### T24 `<verify>` 抽取（18 行，落 `/tmp/v_T24.sh`）实跑 rc=0

```bash
bash /tmp/v_T24.sh   # 输入 = sed -n '1040,/^<\/task>/p' TASK.md 中 <verify>…</verify> 去标签后余 18 行
```

**真实输出：**

```
归档内 pre-push 成员：dsh-flow-kit/hooks/pre-push/pre-push.sh dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-push/pre-push.sh
0.2.0: eval-echo=0
0.2.0: chisel=0
VERIFY rc=0
```

**关键断言逐条核验：**

- `[ -f dist/dsh-flow-kit-0.2.0.tgz ]` ✅（本次重建产物在）
- `[ ! -e dist/dsh-flow-kit-0.1.0.tgz ]` ✅（已删除）
- `tar tzf … 0.2.0.tgz` ✅ 可解析
- vendored pre-push `dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-push/pre-push.sh` ✅ 断言通过（sync-hooks 的 dist DEST_ROOT 已登记新 hook ⇒ 分发件含拦截器）
- 顶层 `dsh-flow-kit/hooks/pre-push/pre-push.sh` 存在 ⇒ verify 的 `ℹ️ 归档顶层 hooks/ 无 pre-push` **未触发**（符合环境事实 5 预期：T11 修复轮 2 已给 `package-flow-kit.sh:134-136` 补了 pre-push stanza，重建后顶层 pre-push 已出现）
- 每个 pre-push 成员含 `make check` ✅，mode 为 `-rwxr-xr-x` ✅ 可执行
- eval-echo=0 ✅、chisel=0 ✅

### 一致性迭代（次序：先 sync-hooks 校验，后打包，再验）

重建后一次性达成 `check-dist=0` + `check-hooks-sync=0` + `sync-hooks --check=0`，**无漂移 ⇒ 无需跑 `./sync-hooks.sh` 写盘**，未触发「再打包」回流。

| 门禁 | rc | 证据 |
|---|---|---|
| `make check-dist` | **0** | `✅ check-dist: dist 与源一致` |
| `make check-hooks-sync` | **0** | 48 镜像文件 · 6 roots 全 `✅` · `漂移 0` |
| `bash sync-hooks.sh --check` | **0** | 6 roots 全 `✅` · `漂移 0` |

### 额外自证

```bash
# ① 0.1.0 已不存在，0.2.0 为本次时间戳（9月24 02:44）
ls -l dist/
→ 总计 1360
  drwxr-xr-x 9 …  9月24 02:44 dsh-flow-kit
  -rw-r--r-- 1 … 1385199  9月24 02:44 dsh-flow-kit-0.2.0.tgz

# ② 归档内 pre-push 成员逐行
tar tzf dist/dsh-flow-kit-0.2.0.tgz | grep -E 'hooks/pre-push/pre-push\.sh$'
→ dsh-flow-kit/hooks/pre-push/pre-push.sh
  dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-push/pre-push.sh

# ③ 归档与源同源（sha256 一致）
源 sha256 = 581237c21b641345a3c6ef6319d09036a58b3467cc057487dcb68f8ca789d0c9
归档 dsh-flow-kit/hooks/pre-push/pre-push.sh          → 相同 ✅
归档 dsh-flow-kit/vendor/…/pre-push.sh               → 相同 ✅

# ④ 拦截器含 T11 修复轮 1 评估面修复（CHECK_REV）
归档内 两个 pre-push 成员  CHECK_REV 出现次数 = 2 ≥ 1 ✅
（源 pre-push 同 = 2，证明归档是源的真实快照）
```

**里程碑达成（done 条件）**：重建后的归档 `eval-echo=0` / `chisel=0`，可注入的 `0.1.0` 已删除 —— **AC-1④ + AC-5 分发归档面收口**。

---

## 6 维自查

| 维度 | 结论 | 证据 |
|---|---|---|
| **正确性** | ✅ | `<verify>` 原样抽取 18 行实跑 rc=0；关键断言（0.2.0 在 / 0.1.0 删 / 归档可解析 / vendored pre-push 在 / eval-echo=0 / chisel=0 / 顶层 pre-push 已出）全部成立 |
| **完整性** | ✅ | 本次提交含 `T24-SUMMARY.md`（新增）+ `TASK.md`（T24 行 `pending→done`）；`git status --short` 收尾只剩 5 个冻结 `A ` |
| **一致性** | ✅ | `check-dist=0`（dist 逐文件 = 源）、`check-hooks-sync=0`、`sync-hooks --check=0`（6 roots 漂移 0）；`npx bats test/` rc=0 / ok=976 / not_ok=0 / skip=0（基线持平）；`make check-test-sync` rc=0 |
| **兼容性** | ✅ | 无源改动、无公共 API、无 schema ⇒ 无兼容面变动；归档仍可从 `dsh plugin add file:...` 安装（包目录结构 = 打包路径刷新） |
| **可维护性** | ✅ | 打包仍走单一事实源 `package-dsh-plugin.sh` 的 COPY_* 映射；未手工编辑 `.tgz`；0.1.0 删除符合 D4 裁决（无兼容义务），无残留历史对照依赖 |
| **安全性** | ✅ | 归档 eval-echo=0（无可注入 hook）、chisel=0（无内部项目名）、sha256 与源同源；0.1.0（已知可注入件）已彻底移除 |
| **沿用既有抽象（R6.4）** | ✅ | 打包抽象仅 `package-dsh-plugin.sh`（唯一打包入口）→ 沿用；`sync-hooks.sh` 为副本同步面 → 沿用校验；无需新抽象 |
| **破坏性变更（R4.6）** | ✅ 不适用 | 无源文件增删改（纯分发件重建+删除 .tgz），无公共符号/API 变更 |

---

## 遗留

- **TD-048（已知可接受）**：`package-flow-kit.sh` Part C 未登记 `hooks/pre-push/pre-push.sh` stanza。本 task 重建后**顶层归档已含** `dsh-flow-kit/hooks/pre-push/pre-push.sh`（verify 的 `ℹ️` 未触发），但 `package-flow-kit.sh --validate` 仍报「漏配(ERROR): 1」具名该文件 —— 该文件**不在本 change 写面**、已按 ADR-027 作为已知可接受项登记 TD-048，不升级为 fail。vendored 副本仍覆盖安装器路径。
- **`dist/` 不入库**：构建产物由 `.gitignore` 忽略，为 build-time 平台物；如需对外发布需独立渠道（不在本 change 范围）。