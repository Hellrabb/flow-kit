# T05-SUMMARY · health-fix-2026-09b

## 任务与契约

- **Change**: health-fix-2026-09b · **Task**: T05（阶段 4 · Wave 2 源修复层）
- **名称**: PC1：移除 `runtime-edit-guard.sh` 的 eval 载荷求值（纯参数展开 + 绝对值校验）
- **Write 面**（唯一）：`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`
- **契约要点**（取自 task-brief T05 `/action + /verify + /done`）：
  - 以**纯参数展开**替换 `eval echo`：`~` 整体 ⇒ `$HOME`；`~/…` 前缀 ⇒ `$HOME/…`；其余不展开。
  - 展开后**绝对值校验**：结果必须以 `/` 开头，否则 `exit 2`（不是「以 `$HOME/` 开头」，那会误拒 `/tmp/x`）。
  - `~user` 形态一律拒绝（`exit 2`），不引入 `getent`/passwd、不用 `realpath`/`readlink -f`/外部进程。
  - 保留 deny 文案含 `你正在编辑: <展开后路径>`；沿用既有 `jq` 取 `tool_input.file_path` 的读入方式。
  - 空串（原 `:42` 放行）必须改 `exit 2`；运行时副本判定依赖展开后的绝对路径。
  - 文件头自述 fail 策略在注释里如实订正（路径解析改 fail-closed），不默默改行为。
  - **不 sync 安装副本**（T25 负责「副本面收口」；`make check-hooks-sync` 本波预期红，如实披露不判失败）。

## 改动面

`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`（103 → 123 行，+26/-6）：

1. **`:45-48`**（原 `:42`）：`[[ -n "$file_path" ]] || return 0`（空串放行）→ 空串直接 `exit 2`（fail-closed，D6 七态）。
2. **`:50-66`**（原 `:44-46`）：删除 `real_path=$(eval echo "$file_path" 2>/dev/null) || real_path="$file_path"`，改为纯参数展开 + 绝对值校验：
   ```bash
   case "$file_path" in
     \~)      real_path="$HOME" ;;
     \~/*)    real_path="$HOME/${file_path#\~/}" ;;
     *)       real_path="$file_path" ;;
   esac
   [[ "$real_path" == /* ]] || { echo "runtime-edit-guard: 无法解析为绝对路径，拒绝: ${file_path}" >&2; exit 2; }
   ```
3. **`:14` & `:28-31` 注释订正**：明确「整体仍 fail-open（jq 不可用 / stdin 解析失败等意外错误 → 放行），但**路径解析这一步改 fail-closed**（无法解析为绝对路径一律 exit 2）」，与 D6 显式声明的兼容性收缩一致，非默默改行为。
4. **`:86`** deny 文案 `你正在编辑: $real_path`（展开后绝对路径）保留原样。
5. 未改 `REQUIREMENT.md` / `DESIGN.md`（R3.2）；未扩范围（R7.1）。

## `<verify>` 逐字输出（export LC_ALL=C; G=…; … 全链路）

```
源树 eval-echo=0 ✅
bash -n ✅
p '~alice/x.sh' rc=2
p 'rel/x.sh' rc=2
p '' rc=2
p '/tmp/x.sh' rc=0
正例 rc=2
正例报文含'你正在编辑: /' ✅
===VERIFY ALL PASS===
```

（`p` 即 `printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" | bash "$G"` 的 rc。正例 `~/.claude/hooks/pre-tool-use/runtime-edit-guard.sh` rc=2。）

## D6 七态 fixture 全跑（HOME 可控）

`HOME=/tmp/testhome` 下以 `~/.claude/hooks/pre-tool-use/runtime-edit-guard.sh` 触达 deny 证明展开值可观测：

| # | fixture | rc | 展开/报文 |
|---|---|---|---|
| 1 | `~` | 0 | → `$HOME`（绝对，放行） |
| 2 | `~/x.sh` | 0 | → `$HOME/x.sh`（绝对，放行） |
| 3 | `~alice/x.sh` | **2** | `cannot resolve as absolute, rejected: ~alice/x.sh` |
| 4 | `/abs/x.sh` | 0 | 原样绝对路径，放行 |
| 5 | `rel/x.sh` | **2** | `cannot resolve as absolute, rejected: rel/x.sh` |
| 6 | 空串 `""` | **2** | `file_path 为空串，拒绝` |
| 7 | `/a b/x.sh` | 0 | 含空格绝对路径，放行 |

**展开值证明**（`HOME=/tmp/th_a`、`/tmp/th_b` 交替跑）：
- `~/.claude/hooks/pre-tool-use/runtime-edit-guard.sh` → `你正在编辑: /tmp/th_a/.claude/hooks/pre-tool-use/runtime-edit-guard.sh`（rc=2）⇒ `~` 正确展开为 `$HOME`。

## 双态对照（L-120 强制 · before=baseline `534e3e8` → `/tmp/guard-before.sh`，不动工作区）

| fixture | before(534e3e8) | after(工作区) | 差异 |
|---|---|---|---|
| `~alice/x.sh` | 0 | 2 | ✅ |
| `rel/x.sh` | 0 | 2 | ✅ |
| 空串 | 0 | 2 | ✅ |
| `/tmp/x.sh` | 0 | 0 | ✅（合法绝对路径前后都不误拒） |

三态 before=0 / after=2 结果不同 ⇒ 证明新逻辑真在拒绝（非恒绿、非只字面消失）。

## bats TAP（make test）

初始 `make test` rc=2、`971 ok / 2 not ok`，两条 not ok 为同步漂移红；**经父 agent 裁定走方案 1（先 `./sync-hooks.sh` 再正常提交，方案 2 `--no-verify` 不予授权）** 后，全部转绿。

**同步前后漂移证据**：
- 同步前：`make check-hooks-sync` rc=2 → 6 个镜像面各「1 个文件与源不一致」（即 `runtime-edit-guard.sh`）。
- `./sync-hooks.sh`（rc=0）→ 6 面各「同步 1 个文件（其中 0 个副本缺失）」，合计「✅ 已同步 6 个文件」。
- 同步后：`bash sync-hooks.sh --check` rc=0、「✅ hooks 副本一致（漂移 0）」；`make check-hooks-sync` rc=0。

**最终**：`npx bats test/ --formatter tap` = **973 ok / 0 not ok / rc=0**；`make test` rc=0、「✅ bats: all tests passed」。

**两条 red 根因归属**（父 agent 独立定位，非完成任务方自述）：
- `B5-R2` 失败在 `test/test_l3_review_defects_2026_09.bats:968` 的 `[ "$status" -eq 0 ]` —— 直接跑 `bash sync-hooks.sh --check` 并要求输出含「漂移 0」；源已改、6 镜像未同步 ⇒ 必红。
- `B5-R5` 失败在同文件 `:1330`（默认 advisory 应 rc=0）—— 把 `sync-hooks.sh` 变异成只替换 `$HOME/.claude/hooks` → 假镜像根，其余 5 个真实镜像目的地仍在比对，同一漂移渗入而顶红 ⇒ 同一根因。
- 两条 red 都是**门禁正常工作**，非 T05 代码回归，也非「预期红、不应 sync」——初始判断为误，已作废。

## 6 维自查（R1–R6 内置快查；brooks-lint 未安装）

| 维度 | 结果 | 说明 |
|---|---|---|
| R1 认知过载 | ✅ | 新增段为单 `case` 三分支 + 一个 `[[ == /* ]]`，嵌套 ≤2 |
| R2 变更传播 | ✅ | diff 仅 guard 一个文件，与 write_files 一致，0 越界 |
| R3 知识重复 | ✅ | `~` 展开内联（DESIGN §0.5.2「不建 helper」），未复制 |
| R4 偶然复杂 | 🟢 轻微·可接受 | `case` 三分支为 D6 语义必要最小表达，无投机扩展点 |
| R5 依赖混乱 | ✅ | 纯 shell，无 import / 反向依赖 |
| R6 领域扭曲 | ✅ | `real_path`/`file_path`/`runtime_kind` 等为领域词 |

🔴 0 · 🟡 0（登记无）· 🟢 1（R4 轻微，已注明可接受）。无「已知接受」列表项需新登记。

## TDD 声明

`grep -rln 'runtime-edit-guard' test/ flow-kit-bundle/test/` = **0**（已实测复核）—— 本任务无 bats 载体，无法用测试先行。
**替代证据**（L-119/L-120/L-121/L-122/L-123 定式全部落实）：
1. 七态 fixture 逐态实跑（rc + 报文，HOME 可控证明展开值）；
2. 双态对照（before `534e3e8` vs after：`~alice`/`rel`/空串 三态 0→2 变化，非恒真）；
3. 反向守卫 `grep -rEn '\$\([[:space:]]*eval[[:space:]]' flow-kit-bundle/ | wc -l` = 0；
4. `bash -n` 通过；
5. 合法绝对路径 `/tmp/x.sh` 不被误拒（对照 - 无假绿）。

每条断言自带失败分支，故无「命令 ≠ 断言」类漏判。

## 越界检查（R6.5）

```
✅ 越界检查（R6.5）：
   - TASK write_files：1 项（flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh）
   - 实际 diff 涉及：1 项
   - 越界：0
```

未提交面（本次不涉及，先前已存在的 workspace 变更）：
- `.specs/CONTEXT.md` / `.specs/STATE.md`（进入本任务前已 `M` 的工作区改动，非 T05 产物）
- `.specs/health-fix-2026-09b/CHANGE.md`、`INDEPENDENT-REVIEW-{1,2,3}.md`、`REQUIREMENT.md`、`.specs/adr/028-*.md`、`.specs/health/2026-09-22-FULL-SWEEP.md`（untracked，属其它 task/阶段）
本次 `git add` 只列显式路径（guard + TASK.md + T05-SUMMARY.md + MINOR-DEFERRED.md + .flow-active）。

## 遗留/移交项

- **安装副本同步（6 面）**：本任务按父 agent 方案 1 **已执行 `./sync-hooks.sh`**（6 镜像与源一致，漂移 0）。工艺结论见下。
- **T04 `<done>` 陈旧实测值**：登记于 MINOR-DEFERRED 主 agent 裁定段（TASK.md 正文不改）。
- **测试中途产物清理**：失败的 `B5-R5` 在 `rm -f "$sh"` 之前中止，仓库根留下未跟踪变异脚本 `.sync-hooks-orphan-test.sh`；已用 `git ls-files --error-unmatch .sync-hooks-orphan-test.sh` 确认**未被跟踪**（rc=1），随后 `rm -f` 删除。此乃 **bats 测试中途产物，不属于任何 task**，已清理并在此记录。

## 工艺结论（同步 → 提交）

> 本仓 `make test`（bats）内含**源↔安装副本一致性机器检查**（`B5-R2` / `B5-R5`）。任何修改
> `flow-kit-bundle/hooks/**` 或 `install_hooks.sh` 的 task，**必须先 `./sync-hooks.sh` 再提交**，否则
> pre-commit 的 `[archive-commit-gate]` 会因漂移而红 —— 这是**门禁正常工作**，非缺陷。
> T05 实测：同步前 rc=2（971 ok / 2 not ok）；`./sync-hooks.sh` + `--check` 漂移 0 后 rc=0（973 ok / 0 not ok）。
> 此工艺已追加至 `MINOR-DEFERRED.md`（标注为工艺说明，非缺陷）。