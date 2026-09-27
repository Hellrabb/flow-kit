# T-FIX-16 SUMMARY — pre-push 拦截行为固化为常设 bats（R5-7）

## 任务

`.specs/health-fix-2026-09b/TASK.md` 的 `T-FIX-16`（R5-7 🔴 · AC-3 无行为级常设覆盖）。
把 `flow-kit-bundle/hooks/pre-push/pre-push.sh`（216 行）的六条推送形态拦截行为，
从 `test/test_archive_commit_gate.bats` 的静态文本断言（`bash -n` + `grep -q`，从不执行 hook）
升级为**真跑 hook 的行为级常设网** `test/test_pre_push_behavior.bats`。

## 判据实跑

### ① `npx bats test/test_pre_push_behavior.bats` ⇒ not ok = 0 且用例数 ≥ 6

```
1..6
ok 1 leg1: clean ref ⇒ rc=0 (checker present + allowlist present + no leak)
ok 2 leg2: leaky ref ⇒ rc≠0 + report contains 「🔴 拒绝推送」 + rejected ref name
ok 3 leg3: pure delete push (local_sha = 40 zeros) ⇒ rc=0 + skip message
ok 4 leg4: malformed stdin (missing local sha) ⇒ rc≠0 + fail-closed message
ok 5 leg5: checker present + allowlist absent ⇒ rc=2 + named path-privacy-allowlist.txt
ok 6 leg6: consumer form (no Makefile) ⇒ not red for missing Makefile, but leak must rc≠0
```

not ok = 0，用例数 = 6（≥6）。`npx bats --count test/` = **1082**（开工 1076 + 6）。

### ② 变异腿：两台变异体上腿②/④必须 not ok（贴证据）

变异改法（精确两处）：
- `pre-push.sh:172` 畸形守卫 `exit 1` → `continue`
- `pre-push.sh:198-202` 泄漏拒绝整块 → `scan_rev "$local_sha" || true`（单行，语法合法）

diff 片段：
```
172c172
<         exit 1
---
>         continue
198,202c198
<         if ! scan_rev "$local_sha"; then
<             echo "🔴 拒绝推送 $local_ref：该 ref 含路径隐私泄漏（check-path-privacy 未通过）" >&2
<             leaky_ref="$local_ref"
<             break
<         fi
---
>         scan_rev "$local_sha" || true
```

变异体 `bash -n` 校验：SYNTAX OK（语法合法，不触发 `bash -n` 静态断言）。

变异体上跑同一 bats（`T_FIX16_HOOK_PATH=/tmp/tfix16/mut/hooks/pre-push/pre-push.sh`）：
```
1..6
ok 1 leg1: clean ref ⇒ rc=0 ...
not ok 2 leg2: leaky ref ⇒ rc≠0 ...   ← `[ "$status" -ne 0 ]' failed
ok 3 leg3: pure delete push ...
not ok 4 leg4: malformed stdin ...     ← `[ "$status" -ne 0 ]' failed
ok 5 leg5: checker present + allowlist absent ⇒ rc=2 ...
not ok 6 leg6: consumer form ...       ← `[ "$status" -ne 0 ]' failed（额外佐证）
```

腿②④必须 not ok ✅（腿⑥额外 not ok 亦符合预期：变异2废了所有泄漏拒绝）。

### ③ 分工核对

`grep -c 'install_layout' test/test_pre_push_behavior.bats` = 3（仅出现在文件头注释，
说明分工边界，非 `@test` 用例名）。

T-FIX-14 `test/test_install_layout.bats`（8 例）覆盖**安装形态**（真实 install.sh 部署到
`<proj>/.claude/hooks`，经 `.git/hooks/pre-push` symlink 调用）。
本文件（6 例）覆盖**源码树形态**（直接 `bash` 仓库 `flow-kit-bundle/hooks/pre-push/pre-push.sh`，
CWD = 无 Makefile 工作仓，自建沙箱 reference 目录）。

两文件用例名逐条比对无同名断言。语义边界互斥：
- T-FIX-14 腿"real-missing state: rc=0"（状态① 检查器缺失）vs 本文件腿⑤"checker present +
  allowlist absent ⇒ rc=2"（状态② 检查器在 + 清单缺）——三态边界不同。
- T-FIX-14 腿"clean ref: rc=0"（安装形态）vs 本文件腿①"clean ref ⇒ rc=0"（源码树形态）
  ——形态不同，夹具不同（安装形态走 symlink，源码树形态直接 bash 本体）。

### ④ `npx bats test/test_archive_commit_gate.bats` 仍全绿；`make check` 21 ✅ / 0 ❌

`npx bats test/test_archive_commit_gate.bats`：45 例全绿（既有静态断言未被削弱）。
`make check`：全部通过（`✅ make check: 全部通过`；bats/shellcheck/validate/test-sync/
hooks-sync/check-dist/gate-sync/path-privacy 各项 ✅，0 ❌）。

## 先红证据

存档 `/tmp/tfix16/pre.txt`。变异体（`exit 1→continue` + `泄漏拒绝→scan_rev || true`，
语法合法、`bash -n` 过）上跑 `test_archive_commit_gate.bats` 的 12 条 pre-push 静态断言子集
**全部全绿**（ok 1-12），证明既有静态断言从不执行 hook，改坏行为逻辑无法被捕获。

关键行：
```
## 变异体 bash -n 校验
SYNTAX OK (语法合法 ⇒ not ok 4 不会被触发)

## 变异 hook：临时替换本体后跑同一静态断言子集
1..12
ok 1 … ok 12   ← 12 条全绿（改坏逻辑仍未被静态断言捕获）
RC_bats=0
RESTORED OK
```

## 变异反向控制证据

存档 `/tmp/tfix16/mut-run.txt`。原版 6/6 全绿；变异体腿②④ not ok（腿⑥额外 not ok）。

## 六条腿语义

| 腿 | 形态 | 输入 | 期望 rc | 报文关键措辞 |
|----|------|------|---------|-------------|
| ① | 源码树 · 检查器在 + 清单在 | 干净 ref | 0 | `项目 Makefile 未声明 check 目标：跳过` |
| ② | 源码树 · 检查器在 + 清单在 | 泄漏 ref（探针拼接） | ≠0 | `🔴 拒绝推送` + `refs/heads/main` + `路径隐私泄漏` |
| ③ | 源码树 · 检查器在 + 清单在 | 纯删除（local_sha=40 zeros） | 0 | `ℹ️ 纯删除推送：跳过内容扫描` |
| ④ | 源码树 · 检查器在 + 清单在 | 畸形 stdin（缺 local sha） | ≠0 | `pre-push stdin 行缺 local sha` + `fail-closed` |
| ⑤ | 源码树 · 检查器在 + 清单缺 | 泄漏 ref | 2 | `找到路径隐私检查器但缺少允许清单` + `path-privacy-allowlist.txt` + `fail-closed`（不得含`含路径隐私泄漏`） |
| ⑥ | 源码树 · 消费者形态（无 Makefile） | 泄漏 ref | ≠0 | `🔴 拒绝推送`（不得含`未找到可用的路径隐私检查器`） |

## 夹具设计要点

- `make_sandbox_hook` 从 `$HOOK_PATH`（默认 = 仓库本体；变异腿用 `T_FIX16_HOOK_PATH`
  覆盖为变异体）拷贝，沙箱副本与被测 hook 逐字节一致（`cmp -s "$sandbox_hook" "$HOOK_PATH"`）。
- 沙箱 reference 目录 = `$TEST_TMPDIR/hooks/flow-kit/reference`（`HOOK_DIR` 解析后指向沙箱），
  从仓库拷贝 `check-path-privacy.sh`，allowlist 由 `make_sandbox_hook present|absent` 控制。
- 注释-only 清单（`# fixture allowlist（0 条目）`）合法：`validate_allowlist_format` 跳过 `#` 注释行。
- 泄漏探针拼接构造（`PROBE_LEAK="/home/""${PROBE_USER}""/secret.txt"`），文件内不出现真实账号字面。
- 每条腿自己造状态并显式断言前提（腿①②用同夹具互证：腿②证明检查器会抓泄漏，避免腿①空跑）。

## 前提修正

派发词背景 L-54 称"仓库 `flow-kit-bundle/flow-kit/reference/` 里没有
`path-privacy-allowlist.txt`"——此为**过时信息**。`f315b64`（T21 AC-6 基线冻结）已把
常设权威清单 `path-privacy-allowlist.txt` 提交进 HEAD（`git cat-file -e HEAD:…` = TRACKED IN HEAD）。
腿⑤（缺清单态）改用**自建沙箱 reference**（从仓库拷贝检查器但不拷贝 allowlist）精确命中状态②，
不依赖过时前提。判据（状态②⇒rc=2）本身未变，实现手段合规。

## 遗留风险

- `test/test_pre_push_behavior.bats:143` 等 6 处 `cmp -s "$sandbox_hook" "$HOOK_PATH"`：
  变异腿跑时 `$HOOK_PATH` 被环境变量覆盖为变异体路径，`cmp` 断言沙箱副本与变异体一致
  （而非与仓库本体一致）。这是设计意图（真跑被测 hook 而非自造脚本），但若未来有人
  误把 `T_FIX16_HOOK_PATH` 指向空文件，`cmp` 仍会过（沙箱副本=空=被测"本体"）。
  缓解：原版腿（默认路径）仍断言与仓库本体一致；变异腿由 CI/手工显式设置环境变量。
- `flow-kit-bundle/hooks/pre-push/pre-push.sh:198-202` 泄漏拒绝块若被未来重构拆分，
  变异锚点（`if ! scan_rev …; then … break; fi`）将不再命中，变异体构造会失败。
  此时需同步更新变异脚本（本任务变异脚本内联在 `/tmp/tfix16/mut` 构造步骤，非仓库件）。
- 腿⑥与 T-FIX-14 安装形态腿语义同源但形态互斥；若未来 T-FIX-14 新增"源码树形态"腿，
  需与本文件腿⑥去重（判据③要求同名断言不得两处并存）。
