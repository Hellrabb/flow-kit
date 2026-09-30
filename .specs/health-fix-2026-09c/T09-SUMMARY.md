# T09-SUMMARY — pre-push 并发闸（flock）+ 本仓换装 + 裸仓并发夹具

> 阶段：health-fix-2026-09c · Wave 2 · T09（TASK.md:243-269 · AC-17①② · M11 承接）
> 结论：**全部收口**。verify 链 RC=0；变异探针证明夹具判别力（无闸 ⇒ 标记 100% 交错 + 偶发 git 级互踩；有闸 ⇒ 10/10 严格串行）；hooks-sync 二跑幂等零漂移。

## 1. flock 并发闸设计（AC-17①）

落点：`flow-kit-bundle/hooks/pre-push/pre-push.sh:31-72`（变更头注释 :6；全文 260 行；只新增，未动既有扫描/make check 逻辑）。

| 设计面 | 决策 | 理由 |
|---|---|---|
| 锁路径 | `<git-dir>/flow-kit-pre-push.lock`（`git rev-parse --git-dir` 定位） | **确定性路径、每仓一把**——并发 push 必然撞同一把锁；落在 git-dir 内不污染工作树（`git status --porcelain` 不报）；与 F6「锁文件 + mktemp 唯一路径」范式同源（mktemp 用于测试夹具沙箱，锁本身必须确定性） |
| 锁实现 | `exec 9>>"$lock_file"` + `flock -w "$wait_s" 9`，进程持有 fd 9 至退出 | fd 随脚本退出自动释放：hook 被 kill -9 也不留死锁；锁文件内容恒空，残留无害 |
| 超时语义 | 默认 `flock -w 600`；`FLOW_KIT_PRE_PUSH_LOCK_WAIT` 可覆盖（测试注入 1s 用） | 600s ≫ 任何合法 `make check`（含全量 bats）；**超时 fail-closed**（rc=1，报文指名锁路径与等待秒数）——若超时放行等于静默重开互踩窗口，违背 AC-17 意图 |
| 降级语义 | `flock` 不可用 / git-dir 不可定位 / 锁不可写 ⇒ ⚠️ 警告 + `return 0`（闸跳过，push 判定不变） | 闸是**尽力串行化层**，不是判定层——与隐私扫描的 fail-closed 分属不同层；「放行语义不变」是编排者红线 |
| 调用点 | `_pre_push_gate || exit 1`（:72，紧随 `set -euo pipefail` 之后） | 闸先于一切 hook 主体执行：先拿锁再跑 check，才保证 check 窗口互斥 |

超时报文（原文）：`🔴 [pre-push] 并发闸超时（${wait_s}s）：另一 push 仍在进行，锁=$lock_file。排查挂死推送后重试`（>&2，git push 会透传给用户）。

## 2. 本仓 `.git/hooks/pre-push` 换装（AC-17 Given）

- **前**（8 行，原地内联逻辑）：`#!/bin/bash` + 3 行头注释（"pre-push hook — 推送前自动跑 make check" / 安装来源 / `git push --no-verify` 跳过提示）+ `echo "🔍 pre-push: running make check..."` + `make check`。
- **后**（薄壳，31 行，chmod +x）：旧 8 行**逐字归档在注释里**（保住 test_quality_baseline.bats AC-4 的 `grep -q "make check"` 与可执行位断言），正文仅：
  ```bash
  set -euo pipefail
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  exec bash "$REPO_ROOT/flow-kit-bundle/hooks/pre-push/pre-push.sh"
  ```
- **为何 exec 薄壳而非 symlink**：`flow-kit-bundle/lib/install_hooks.sh:104` 的 `is_flowkit_symlink` 对指向源码树 `*/flow-kit-bundle/hooks/pre-push/pre-push.sh` 的 symlink 一票否决；`exec bash` 完整透传 stdin（pre-push 需读 ref 列表）/rc/stderr，语义与直装等价。归档注释里写明了这三点（为何薄壳/为何非 symlink/部署语义差异），供后来者不迷路。

## 3. 裸仓并发双 dry-run 夹具（AC-17② · M11 承接）

新文件 `test/test_pre_push_gate.bats`（5806 B，3 用例；镜像 `flow-kit-bundle/test/test_pre_push_gate.bats` cmp 字节一致）。夹具纪律：mktemp -d 沙箱、测试内建用完 rm -rf、不占常设文件。

- **构造**（`t09_make_fixture`）：`mktemp -d` → `git init --bare remote.git` → clone 出 worktree → 桩身份 + `commit.gpgsign false` → README+Makefile 一提交；Makefile `check:` 目标写 `start` 标记 → `sleep 1` → 写 `end` 标记（拉开观测窗）；worktree 的 `.git/hooks/pre-push` 装成与真仓同形态薄壳 `exec bash "$HOOK_SRC"`。
- **用例 1（静态腿）**：`bash -n` + `grep -c flock ≥1`——与 T09 verify 锚同源。
- **用例 2（并发腿，AC-17②）**：后台并发两条 `git push --dry-run -q origin HEAD:refs/heads/p1|p2`（同 worktree 同锁，推不同 ref 避 ref 级争用）→ 断言 ① 双 rc=0 ② 标记序列严格 `start,end,start,end` 嵌套（次序无关：谁先抢到锁不定，但两形状同形）③ `wt/.git/flow-kit-pre-push.lock` 存在（闸落痕）④ 夹具 worktree `git status --porcelain` 为空（污染断言只查夹具——真仓有并行兄弟任务，全树断言必假红，沿 test_check_gate_sync.bats T03 纪律）。
- **用例 3（超时腿）**：夹具 Makefile `check:` 置空操作；外部持有者进程 `flock -x` 占锁 5s（落 ready 标记 + 轮询确认**确实已占锁**，不竞速时间片）；`FLOW_KIT_PRE_PUSH_LOCK_WAIT=1 git push --dry-run` ⇒ 断言 rc≠0 + 报文含「并发闸超时」与 `flow-kit-pre-push.lock`。
- **判别力证明（变异探针，/tmp 沙箱非仓内）**：把 hook 副本中 `_pre_push_gate || exit 1` sed 成注释（闸失效、逻辑其余不变）后跑并发对——**16 对全部互踩**：14 对标记交错 `start,start,end,end`（rc 仍 0/0，静默互踩正是 AC-17 要治的病），另 2 对（均在早期探针）撞 git 级竞态 rc=128（`fatal: 不是 git 仓库（或者任何父目录）：.git`，hook 输出缺失 = 推程启动期互踩）。对照组：**有闸 bats 全文件 10 连跑 30/30 全绿**，标记每轮严格嵌套。结论：夹具对「闸被移除」零漏报。

## 4. hooks-sync 幂等性（T09 步骤④ · REQUIREMENT:192）

- 跑 #1：`make hooks-sync` 同步 **1 个文件**（pre-push.sh，即本任务 sanctioned 改动）到 4 个根（`/home/<acct>/.claude/hooks`、`dist/dsh-flow-kit/hooks`、`dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks`、`/home/<acct>/.config/opencode/hooks`）；dsh-profiles 双根已在 Wave 1 手动同步后一致。`make check-hooks-sync` ⇒ 6 根全 ✅ 漂移 0。
- 跑 #2（幂等证）：`make hooks-sync` ⇒ 6 根全「已一致、无需同步」零文件动作；`check-hooks-sync` 仍漂移 0。
- 判读：跑 #1 的 1 文件漂移 = 本任务对 pre-push.sh 的预期改动外溢，非遗漏面；二跑零动作证明收口完备。

## 5. verify 真实输出（原样命令，RC=0）

```
$ bash -n flow-kit-bundle/hooks/pre-push/pre-push.sh \
  && test "$(grep -c flock flow-kit-bundle/hooks/pre-push/pre-push.sh)" -ge 1 \
  && test "$(grep -c 'flow-kit-bundle/hooks/pre-push' .git/hooks/pre-push)" -ge 1 \
  && make hooks-sync && make check-hooks-sync && npx bats test/test_pre_push_gate.bats
1..3
ok 1 AC-17①: pre-push.sh 语法有效且内置 flock 并发闸
ok 2 AC-17②: 裸仓并发双 dry-run → 两推程串行化、双 rc=0、夹具树零改动
ok 3 AC-17①: 锁被外部持有 + 等待超时 ⇒ fail-closed rc≠0 且指名锁路径
VERIFY-CHAIN-RC=0
```

（flock 字面计数 7；壳内 bundle 路径字面计数 1；bats 3/3。）

回归面：`npx bats test/test_pre_push_behavior.bats test/test_archive_commit_gate.bats test_quality_baseline.bats test_install_layout.bats` ⇒ **75/75 ok**（含 AC-4 pre-push 双断言 62-63、AC-7 双源一致 67、T-FIX-13 三态用例 49-51、72-73 反控腿）。首跑曾现 AC-7 单红：兄弟任务在途单侧改 `test_gate_config_presets.bats`（test/ 13024 vs bundle/ 13323）——按编排者纪律重跑一次即绿（对方补齐镜像），与本任务无关。

## 6. 6 维自查

| 维 | 结果 | 说明 |
|---|---|---|
| R1 函数>50行/嵌套>3 | ✅ | `_pre_push_gate` 26 行（含注释/空行）含守卫嵌套≤2 层；pre-push.sh 260 行无既有函数越界恶化。 |
| R2 越界 | ✅ | 仅 write_files 授权 3 件（pre-push.sh、.git/hooks/pre-push〔部署面，非 git 索引〕、SUMMARY）+ 编排者明示授权扩展的新测试对 `test(|flow-kit-bundle/test)/test_pre_push_gate.bats`。install_hooks.sh 只读未动；未跑 make test-sync/check-test-sync（镜像 cp + cmp 手工完成）；无 git commit。 |
| R3 重复粘贴 | 🟡 | 夹具薄壳 3 行与真仓 `.git/hooks/pre-push` 薄壳同形：刻意的同形断言面（夹具要测的就是「真仓形态」），抽象成共享函数反而引入测试对被测物的源依赖。接受。 |
| R4 多余抽象 | ✅ | 零新文件级抽象；唯一新函数 `_pre_push_gate` 是被测主体本体。降级三连 ⚠️+return 0 看似重复，实为三档独立降级语义（无 flock/无 git-dir/锁不可写），合并会混淆归因。 |
| R5 依赖混乱 | ✅ | 仅用 git 自带 `flock`(util-linux)/`git rev-parse`，与隐私扫描同源既有依赖面；FLOW_KIT_PRE_PUSH_LOCK_WAIT 沿 FLOW_KIT_* 环境旋钮既有惯例（check-path-privacy 的 FLOW_KIT_PRIVACY_ALLOWLIST 同款）。 |
| R6 领域扭曲/命名 | ✅ | `_pre_push_gate` 下划线私有前缀沿 hook 内既有惯例；锁名 `flow-kit-pre-push.lock` 自释义；报文沿 `[pre-push]` 模块前缀 + 既有 🔴/⚠️ 级别符号惯例。 |

## 7. 偏差与遗留

- **无功能性偏差**。三项流程性记录：① 新测试对超出 write_files 原始清单——编排者任务书明示「此时 write_files 授权扩展，SUMMARY 登记=编排者本指令」，本条即登记；② 回归 AC-7 一过性假红（兄弟在途），重跑自愈，未干预兄弟文件；③ 早期无闸探针的 2 例 rc=128 git 级互踩未根因到 git 内部（触发率 2/16、仅无闸侧出现、有闸侧 10/10 未见）——按观测现象如实记录，不冒充因果结论。
- `/tmp` 探针沙箱（t09probe/t09mut/t09ctl）已清理。
