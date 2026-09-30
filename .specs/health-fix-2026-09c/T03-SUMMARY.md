# T03-SUMMARY — C1 测试沙箱化（AC-1 + AC-2）

change: `health-fix-2026-09c` · task: T03（阶段 4 DEV，fresh context）· 执行模型: standard
对应事故根因: LESSONS.md 2026-09-29 🔴（`test/test_check_gate_sync.bats:15,17-24,39,46,52` 并发固化破坏，tracked SKILL.md 实际丢行）

## 改动清单

只改 2 个文件（= TASK `<write_files>`，互为同内容镜像，md5 `655f8d4cc1be8e7a4f4c43d77bf26a4c` 双侧一致）：

1. `test/test_check_gate_sync.bats`
2. `flow-kit-bundle/test/test_check_gate_sync.bats`（手动 cp 双写，**未跑** `make test-sync`——同波次并行防 cp 竞态）

具体改动（两文件相同，`+87/-10` 每侧）：

| 位点 | 旧 | 新 |
|---|---|---|
| `:15` | `SKILL="flow-kit-bundle/skills/flow/SKILL.md"` | `SKILL_REL="flow-kit-bundle/skills/flow/SKILL.md"`（相对路径常量，沙箱内拼 `$SBX/fk/$SKILL_REL`） |
| `setup()` | `cp "$SKILL" "$SKILL.t02-bak"`（固定共享路径） | `T02_BAK=$(mktemp "${TMPDIR:-/tmp}/t02-skill-bak.XXXXXX")` + cp——备份路径唯一，防并发互踩 |
| `teardown()` | `[[ -f … ]] && mv … \|\| true` | `if [[ -f "$T02_BAK" ]]; then mv -f …; fi`——**去掉 `\|\| true`**：还原失败 = teardown 判红报警；备份不存在（测试被过滤）正常返回 |
| 三个 T02 漂移用例（注入假预设 / 删真预设 design / 注英文注释） | `sed -i` 直写 tracked SKILL.md | 新增 `FXC1()` 夹具生成器（**照搬同文件 T-FIX-04 F6 双态腿现成写法**：`mktemp -d` + 复制生产件 + `cd '$SBX/fk'` 运行 + `rm -rf`），sed 注入落到 `$SBX/fk/$SKILL_REL`；每腿带 `echo "[fixture] $SBX/fk (pid $$)"` 留痕 |
| 文件末尾 | — | **新增 AC-2 kill 注入腿**（L2 r2 R10 修订 2026-09-29）：`T03 AC-2: 夹具运行中注入 SIGTERM/SIGKILL → rc≠0 + tracked skills/ 零改动（沙箱防回退）` |

AC-2 腿机制：FXC1 夹具 + 影子 `diff`（`sleep 3` 后 `exec` 真 diff，沿用 R3-20/T-FIX-25 的 PATH 影子手法）拉长运行窗口 ⇒ 后台起 SUT 子 shell，`sleep 1` 后先 `pkill -SIG -P $sut -f check-gate-sync`（杀内层）再 `kill -SIG $sut`（杀包装），对 `TERM`/`KILL` 两轮各断言：① `wait` rc≠0（143/137）；② `git diff --stat -- flow-kit-bundle/skills/` rc=0 且输出为空。**断言只查 skills/ 域**（同波次有其他并行任务的未提交改动，全树断言会假红；全树留给编排者波末跑）。

用例数：16 → 17（新增 1 条 AC-2 腿）。既有 16 条腿零语义改动（仅三条漂移腿的注入目标从 tracked 文件改为沙箱副本，断言原文未动）。

## verify 真实输出（三段 + 证据段）

### ① `npx bats test/test_check_gate_sync.bats`（直接 exit code，无管道——L-027）

```
1..17
ok 1 T02: check-gate-sync.sh 存在且可执行
ok 2 T02: 基线 SKILL↔bats 预设名一致 → gate-config 段报告一致（17 预设）
ok 3 T02: SKILL.md 注入假预设（有 →）→ gate-config 段报漂移 + 列出 fake-preset
ok 4 T02: SKILL.md 删除真预设 design → gate-config 段报漂移
ok 5 T02: 不依赖文本段 marker — 注入英文注释（无 →）不误报漂移
ok 6 T02 F6: 完整夹具（所有对文件齐全）→ rc=0 + 汇总打印一致
ok 7 T02 F6: 缺一对 skill 文件 → rc≠0 + 汇总不打印「✅ … 一致」
ok 8 T-FIX-10 R3-18A: 仅 skill 侧加一行 → 具名 skill 侧，不误报 prompt 侧
ok 9 T-FIX-10 R3-18B: 仅 prompt 侧加一行 → 具名 prompt 侧，不误报 skill 侧
ok 10 T-FIX-10 R3-19: 两侧预设集合同时清空 → 不静默中止（有汇总行或具名 🔴）
ok 11 T-FIX-10 R3-20: PATH 影子 diff（恒 rc=2）→ rc≠0 + 具名 🔴（不折算为一致）
ok 12 T-FIX-25 TD-104: PATH 影子 diff（恒 rc=2）→ rc≠0 + 具名 🔴 MECHANICAL + 不打印 ✅ 一致
ok 13 T-FIX-18 R5-14 ①: 缺 test_gate_config_presets.bats → rc≠0 + 🔴 MISSING + 具名路径（非 ✅ 一致）
ok 14 T-FIX-18 R5-14 ②: 缺 skills/flow/SKILL.md → rc≠0 + 🔴 MISSING + 具名路径（非 ✅ 一致）
ok 15 T-FIX-18 R5-10 ③: 仅改一行内容（行数不变）→ 判红（内容比对，非行数短路）
ok 16 T-FIX-18 R5-14 ④ 反向控制: 完整树 → rc=0 + ✅（判据有牙，非恒红）
ok 17 T03 AC-2: 夹具运行中注入 SIGTERM/SIGKILL → rc≠0 + tracked skills/ 零改动（沙箱防回退）
EXIT=0
```

### ② 并发双跑（逐 pid 捕获）

```
p1=3444557 rc=0  p2=3444558 rc=0
--- run1 tail ---  ok 15 … / ok 16 … / ok 17 T03 AC-2: …
--- run2 tail ---  ok 15 … / ok 16 … / ok 17 T03 AC-2: …
```

两实例各 17/17 全绿（这是本修复的核心反证：旧形态并发双跑会把 tracked SKILL.md 改脏）。

### ③ `git diff --stat -- flow-kit-bundle/skills/`（沙箱不泄漏到 tracked 文件）

```
rc=0 output-bytes=0          ← 空输出
SKILL.md == HEAD             ← git diff --quiet 证实 tracked SKILL.md 未动
/tmp residue: t02-skill-bak.* = 0 备份残留
git status before/after 全程 diff = 无新增改动
```

### ④ 证据段：mktemp 夹具路径在输出可见（done 判据）

`npx bats --show-output-of-passing-tests`（bats 1.13.0）节选：

```
ok 3 T02: SKILL.md 注入假预设（有 →）→ …
# [fixture] /tmp/tc1-siyMdv/fk (pid 3448602)
ok 4 …  # [fixture] /tmp/tc1-yHKFBH/fk (pid 3448670)
ok 5 …  # [fixture] /tmp/tc1-Aw6gLo/fk (pid 3448734)
ok 17 T03 AC-2: …
# [fixture] /tmp/tc1-dPb7ys/fk (pid 3449718)
# [kill-inject] sig=TERM fixture=/tmp/tc1-dPb7ys/fk
# [kill-inject] sig=KILL fixture=/tmp/tc1-dPb7ys/fk
# …tracing.bash: 第 1 行： 3449840 已杀死  ( cd "$SBX/fk" && … )    ← KILL 注入实际落地的旁证
EXIT_CHECK: PASS
```

## 6 维自查（内置快查；本任务无生产代码改动，纯测试文件）

- **R1 认知过载**：最长新函数 = kill 腿 ~24 行（<50），嵌套 ≤2 层 ✅
- **R2 变更传播**：diff 仅 2 个 `write_files`（见越界检查），零无关文件 ✅
- **R3 知识重复**：🟡 FXC1 是文件内第 4 个同构夹具生成器（F6 内联 ×2 / FXB10 / FXB25 / FXB18）——按 TASK「照搬 F6 范式勿新造」+ 不越界重构既有腿，保留同构；四合一收敛应另开任务
- **R4 偶然复杂**：teardown 备份保留为回归安全网（TASK 明确要求加固而非删除），注释写明降级理由；无投机扩展点 ✅
- **R5 依赖混乱**：不适用（纯 bash 测试，无 import）✅
- **R6 领域扭曲**：命名沿用文件既有域词（SBX/FXB*/SKILL_REL/T02_BAK/sut）✅

✅ 沿用既有抽象 grep（R6.4）：
- 测试沙箱范式：找到同文件 T-FIX-04 F6 双态腿（`mktemp -d` + `cp -r` + `cd '$SBX/fk'` + `rm -rf`）→ 照搬为 FXC1（**注：grep 全部 `*.bats` 无任何 flock 用法；DESIGN §0.5.2「F6 flock+mktemp」中的 flock 指 pre-push 本体/Makefile 并发闸范式，测试文件内 F6 范式实际只有 mktemp——并发安全由 mktemp 唯一路径保证，与本文件四个既有夹具生成器一致**）
- PATH 影子命令：找到同文件 T-FIX-10 R3-20 / T-FIX-25（影子 diff + chmod + PATH 前置）→ 沿用（AC-2 腿复用为「sleep 3 拉窗」变体）
- set -e 下取 rc：找到同文件 T-FIX-25 `{ …; } || rc=$?` 写法 → 沿用（`wait "$sut" || sut_rc=$?`）
- LESSONS 扫描（§1.5）：命中 2026-09-29 🔴（本任务本体，四条处方中 ①②③ 属我、④ Makefile flock 属同波次他任务，未越界）；L-027（verify 用直接 exit code，无管道）已遵守；LESSONS :279（source lib 的 `|| true` 是合理容错）——与本次删除的 teardown `|| true` 场景不同（还原失败必须报警），不冲突

TDD 说明：本任务交付物即测试本身（无生产代码改动），RED→GREEN 不适用；新增 AC-2 腿首跑即绿（17 ok），三条漂移腿沙箱化后断言原文不变仍绿。

## 越界检查（R6.5）

```
✅ TASK write_files：test/test_check_gate_sync.bats + flow-kit-bundle/test/test_check_gate_sync.bats（2 项）
✅ 实际 diff（git status --porcelain 限定三路径，含 skills/ 验零改动）：
  M flow-kit-bundle/test/test_check_gate_sync.bats
  M test/test_check_gate_sync.bats
→ 越界：0
```

worktree 另有 `.specs/*`、`check-path-privacy.sh`、`hooks/pre-tool-use/*`、`hooks/stop/lib/l3-*.sh`、`test_path_privacy_gate.bats` 等未提交改动——均为**同波次并行任务（T04/T05 等）的改动，非本任务所写**（会话开场三目标路径 git status 为空可证基线）。全树 diff/commit 留给编排者波末。

## 纪律遵守与偏差

- 未跑 `make test-sync` / `make check-test-sync`（按编排纪律：同波次并行防竞态）；镜像用 cp 手动双写 + md5 证实一致
- 未 git commit、未改 `.flow-active`、未改 TASK.md 状态（编排者所有）
- 🔴 必修项：无；🟡 记录项：R3 夹具生成器同构（如上）
- 备注（低风险已知点）：teardown 备份还原是「无条件回写 setup 时刻快照」——若未来有人在单测运行窗口内合法改写 tracked SKILL.md，会被安全网回退。本波次无此写入方（write_files 唇齿），且这是 TASK 处方要求的加固形态，接受并在此留痕

## verify 三段命令（复现）

```bash
npx bats test/test_check_gate_sync.bats; echo "EXIT=$?"
npx bats test/test_check_gate_sync.bats >/tmp/r1 2>&1 & p1=$!; npx bats test/test_check_gate_sync.bats >/tmp/r2 2>&1 & p2=$!; wait "$p1"; r1=$?; wait "$p2"; r2=$?; echo "rc1=$r1 rc2=$r2"
git diff --stat -- flow-kit-bundle/skills/   # 期望空输出
```
