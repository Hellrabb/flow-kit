# T08-SUMMARY — AC-4：`check-gate-sync.sh` 由比行数改为比内容 + 打印覆盖度 `校验对 3/14`

- **change-id**: `health-fix-2026-09b`
- **task**: T08（阶段 4 · DEV）
- **AC**: AC-4（门禁看见「内容漂移」而非只数行数 · AR2）
- **状态**: DONE
- **commit sha**: 见 `.flow-active.goal.task_progress`（以该字段为权威源；SUMMARY 不自指 sha · L-126）

## 1. 做了什么

把 `check-gate-sync.sh` 的 PCSC（prompt↔skill 一致性校验对）判据由**比行数**（`grep -c "^| [0-9] |"`）改为**比内容**：剥离 SKILL 独有的 YAML front-matter 后逐行 `diff`，仅允许平台 front-matter 差异、其余按内容比对。

- 比较对收敛为 **3 对**（`A-evolve`↔`flow-evolve`、`I-intel-scan`↔`flow-intel`、`L-restyle`↔`flow-restyle`）；实测 `diff` 恒为 **6 行**（1 hunk header `0a1,5` + 5 front-matter 内容行）⇒ 剥离 front-matter 后内容 diff = 0。
- 输出打印覆盖度 **`校验对 3/14`**（防旧 `:157` 汇总行「✅ 所有校验对一致」被读成 14 对全绿）。
- 漂移报文含 **`文件:行号`**：`prompts/A-evolve.md:N` / `skills/flow-evolve/SKILL.md:N`（满足下游 `grep -E '(prompts|skills)/[^ :]+:[0-9]+'`）。
- **边界（DESIGN D5）写进代码注释**：本 task 只改 PCSC 判据，**不碰**同文件 `check_gate_config_sync()` 的值比较（TD-033/034 属 v2）；排除 PCSC 表本身（`phase-prompt-template.md:144`「结构性文档化、不抽取」）与 hooks 镜像面（已有 `check-hooks-sync`）。

## 2. 改了哪些文件

| 文件 | 改动 |
|---|---|
| `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（159→217 行） | 重写 `check_pair()` 为内容比对；PAIRS 数组替换 `4-dev↔flow-dev` 为 3 对；`check_gate_config_sync()` **未改**（D5 边界）；汇总行打印覆盖度 |

（另：TASK.md T08 的 `status` 由 `pending` 改为 `done`；本 SUMMARY 新建。）

## 3. verify 真实输出

verify 段（task XML `<verify>` 整段）落成 `/tmp/t08v.sh`，`bash -n` rc=0 后实跑：

```
$ bash /tmp/t08v.sh; echo rc=$?
（健康态全量输出略）
   ── 校验汇总 ──
   覆盖度: 校验对 3/14（v1 仅覆盖内容本应一致、仅差 front-matter 的对；其余 11 对已实质分叉，留 v2/TD-025）
   ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。
✅ verify 全部通过
rc=0
```

verify 含 4 个失败分支断言（健康 rc=0 / 覆盖度 3/14 / 漂移态 rc≠0 / 报文含 `文件:行号`）+ 逐字节复原 `cmp` 断言，全部通过。

## 4. L-119/L-120 双态对照证据（必做）

**态 A（健康）**：`rcA=0`，3 对内容一致，打印 `校验对 3/14`。

**态 B（漂移）**：在受控副本 `prompts/A-evolve.md` 第 1 行末尾加一个空格（行数不变的内容漂移）→ `rcB=1`，报文：
```
🔴 DRIFT: 内容不一致（已剥离 front-matter，仍存在差异）
     定位: prompts/A-evolve.md:1（prompt 侧内容漂移）
     定位: skills/flow-evolve/SKILL.md:1（skill 侧内容漂移）
```

**逐字节复原证明**：
- sha256 before = `a052ca5e0c47b3adda1b9ff3ddde2b2a461254c20578b61485babbc4ea3216a`
- sha256 after drift = `e5dce78f6b883461f124c31196d5a196d730e9cd9c469c5b371c99fdc8610883`
- sha256 after restore = `a052ca5e0c47b3adda1b9ff3ddde2b2a461254c20578b61485babbc4ea3216a`
- `cmp -s "$F" /tmp/gs-bak` → ✅ 逐字节复原
- 用 `trap 'cp -f /tmp/gs-bak-A "$F" 2>/dev/null' EXIT` 保证中途被 kill 也还原。

**差分结论**：rcA=0 ∧ rcB=1 ⇒ 差分成立；永久红门禁无法骗过（态 A 先断言 rc=0）。

## 5. 反向对照（front-matter 差异仍放行）

构造沙箱内临时对（prompt 无 front-matter / skill 有 front-matter，内容相同）：
```
prompt:  # title / line2 / line3
skill:   --- / name: test / description: test / --- / (空) / # title / line2 / line3
```
剥离 front-matter 后两侧 body 均 = `# title / line2 / line3` → content diff = 0 行 → **✅ 放行（不误报）**。

额外验证：无 front-matter 的文件经 strip 后**原样输出**（首空行不丢 · L-123：改完还过得了门禁）。

## 6. 越界检查（R6.5）

- TASK 声明 write_files：`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（1 项）
- 实际 diff 涉及（本 task 产生）：`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（1 项）
- 越界：**0** ✅

> 注：`git diff --name-only HEAD` 另含 `.specs/CONTEXT.md` / `.specs/STATE.md` / `.specs/health-fix-2026-09b/MINOR-DEFERRED.md` —— 这些是 **pre-existing**（前序 task / 主 agent 维护），非本 task 产生。

## 7. D5 边界遵守证明

`check_gate_config_sync()` 函数体逐字节未改（`diff <(git show HEAD:…:check-gate-sync.sh 的函数体) <(当前函数体)` = 空）。代码注释已写明边界声明（文件头部 + 函数上方）。

## 8. 沿用既有抽象 grep（R6.4）

- 原子写：grep 仓内 `.tmp` 写入点范式 → 本脚本用 `mktemp` + `trap RETURN` 清理（沿用 DESIGN 0.5.2）。
- 失败指名口径：grep `file:line` 范式 → 沿用 NFR「失败必须指名 file:line」（A-evolve 下游消费该格式）。
- front-matter 剥离：无既有 helper（grep `strip.*front\|front.*matter` 仓内 0 命中）→ 新建内联 awk（只此一处用，建 helper 属过度抽象）。

## 9. 6 维自查（R1–R6）

- **R1 认知过载**：`check_pair()` 主体 ~40 行，嵌套 ≤ 2 层 → ✅
- **R2 变更传播**：仅改 `check-gate-sync.sh`；未碰 `check_gate_config_sync()`（D5）；未碰 hooks 镜像面（已排除）→ ✅
- **R3 知识重复**：strip_front_matter 定义一次、两侧对称调用 → ✅
- **R4 偶然复杂**：无「以后可能用到」的扩展点；PAIRS_TOTAL=14 是 DESIGN D2 实测定档 → ✅
- **R5 依赖混乱**：无反向 import；awk/diff/mktemp 均为 POSIX 原语 → ✅
- **R6 领域扭曲**：变量名 `prompt_file/skill_file/left_num/right_num` 均领域词 → ✅

## 10. 破坏性变更（R4.6）

本 task **未命中** 1.8 协议：未删 ≥ 5 行既有代码（重写 `check_pair()` 内部实现，但导出行为 = 门禁语义升级，非删公共接口）；未改公共 API。`check_gate_config_sync()` 导出签名未变。故跳过 1.8 协议。

## 11. 数据库 / Schema

不涉及（纯 shell 脚本任务）。

## 12. TDD 声明

本 task 走 **verify-first**：task XML 的 `<verify>` 段即从 AC-4 派生的失败测试（健康 rc=0 / 漂移 rc≠0 / 覆盖度 / file:line）。先写判据脚本 → 跑 verify 确认红（首版 front-matter stripper 有 bug 导致健康态误报 + 漂移报文不含规范路径 → verify 红）→ 修 → 跑 verify 确认绿。双态对照 + 反向对照构成差分证明。非纯文档/配置任务，TDD 未跳过。

## 13. 遗留

- **TC1/TC2（`check_gate_config_sync()` 值比较）**：D5 明确留 v2（TD-033/TD-034，🔴 登记但本 change 不收）。
- **其余 11 对载体漂移无门禁**：v1 仅 3/14，全量策略属 v2/TD-025；已在门禁输出打印覆盖度防误读。
- **`make check-dist` 预期为红**：dist/vendor 的 test 副本待 T24 收口（主 agent 裁定已记 MINOR-DEFERRED）；不据此判定本 task 失败。
