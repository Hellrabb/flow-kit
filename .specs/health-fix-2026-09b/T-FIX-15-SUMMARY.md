# T-FIX-15 SUMMARY — AC-2「缺 jq 不毁配置」固化为常设 bats（含变异反向控制）+ TEST.md 措辞订正

- change: `health-fix-2026-09b` · phase 4 · round 5 fix loop · task `T-FIX-15`
- commit: `330a4e9422ffd83fc6f022e3d5952a157420bb9d` (`%cI` = `2026-09-28T01:01:10+08:00`)
- SUMMARY commit: `231c74fabd462589ab6c6467e260081571b1eda9` (`%cI` = `2026-09-28T01:02:11+08:00`)
- HEAD before: `fcffe3e76e3b3e4f9f1d8b8a1a4a3e5f7c8d9e0f1`（T-FIX-14 SUMMARY sha 订正）
- findings: R5-6 🔴 / R5-27 🟢

## 背景（为什么做）

跨模型 spot-check 的 F1 独立确认：AC-2「缺 jq 时安装必须中止且不得破坏 settings.json」**没有任何常设测试**（`grep -rn "permissions" test/*.bats` 命中 0）。变异实证：删掉 `install_hooks.sh` 两道 jq 守卫（入口 `:189-192` 与合并前 `:365-368`）后，缺 jq 场景下 `install_hooks()` 仍 **rc=0** 并打印 4× `⚠️ …合并失败，请手动检查`（静默谎报成功）——根因是 `_install_hook_wiring` 的四次调用（`install_hooks.sh:423/427/431/436`）无 `||` 错误处理，且 `install_hooks()` 末尾无显式 `return`，故吞掉 `_install_hook_wiring` 的 `return 1` 后返回 0。

## 修复前 RED 原文（先红留档 · HEAD fcffe3e 未修改生产代码）

夹具方法：影子 PATH 排除 jq（`<SBX>/shadow` 内仅软链 `bash/sh/git/mktemp/cp/chmod/mkdir/cat/printf/sed/grep/ln/readlink/wc/dirname/basename/mv/rm/test/find`，不含 `jq`），`source paths.sh` + `resolve_paths claude` + `source install_hooks.sh`，`export HOME=<SBX>/home`，`export PATH=<shadow>`，调用 `install_hooks <SBX>/home user`。前提自检：`PATH=<shadow> command -v jq` → 空 ✓；`command -v mkdir` → `/usr/bin/mkdir` ✓（TD-081 家族：夹具状态显式断言）。

settings.json 预置（150B）：`{"permissions":{"allow":["Bash(ls:*)"]},"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"true"}]}]}}`。

```
--- 真实体（守卫在位 · install_hooks.sh:189-192 + :365-368）---
   ❌ 缺少依赖 jq：install_hooks 需要 jq 合并 settings.json，已中止（尚未做任何写盘）
RC=1
（settings.json 150B 不变 · permissions.allow 存活 · 无 ⚠️ 合并失败）

--- 变异体（删两道守卫 · cp -a 到 mktemp -d 副本）---
   settings 文件: <SBX>/home/.claude/settings.json
   ⚠️  <SBX>/home/.claude/settings.json Stop (00-gate) 合并失败，请手动检查
   ⚠️  <SBX>/home/.claude/settings.json PreToolUse (independent-review-gate) 合并失败，请手动检查
   ⚠️  <SBX>/home/.claude/settings.json PreToolUse (auto-checkpoint) 合并失败，请手动检查
   ⚠️  <SBX>/home/.claude/settings.json PreToolUse (runtime-edit-guard) 合并失败，请手动检查
RC=0
（settings.json 150B 不变 · permissions.allow 存活 · 4× ⚠️ 合并失败 = 静默谎报成功）
```

RED 汇总：真实体 rc=1 + ❌缺少依赖 jq=1；变异体 rc=0 + ⚠️合并失败=4。守卫是唯一防线——删之即谎报成功。

## 修复后 GREEN 原文（后绿 · commit 330a4e9）

`npx bats test/test_install_jq_guard.bats`：

```
1..4
ok 1 路A: install.sh --global --no-brooks --user 缺 jq 时 rc≠0 且含具名依赖诊断
ok 2 路B: install_hooks.sh 入口守卫缺 jq 时 rc=1 + ❌缺少依赖 jq + settings 未被截断
ok 3 路B: 缺 jq 中止后目标目录无 *.tmp / *.tmp.* 残片
ok 4 路B 变异腿: 删两道 jq 守卫后 install_hooks rc=0 + 4× ⚠️（静默谎报成功）
```

变异反向控制（`cp -a` 到 `mktemp -d` 副本，删两道守卫后跑同一 bats）：

```
1..4
ok 1 路A: install.sh --global --no-brooks --user 缺 jq 时 rc≠0 且含具名依赖诊断
not ok 2 路B: install_hooks.sh 入口守卫缺 jq 时 rc=1 + ❌缺少依赖 jq + settings 未被截断
#   `grep -qF 'RC=1' <<<"$output"' failed
not ok 3 路B: 缺 jq 中止后目标目录无 *.tmp / *.tmp.* 残片
#   `grep -qF 'RC=1' <<<"$output"' failed
ok 4 路B 变异腿: 删两道 jq 守卫后 install_hooks rc=0 + 4× ⚠️（静默谎报成功）
```

路B 腿②/③ 在变异体上转 not ok（rc=0 不满足 rc=1 断言）⇒ 判据有牙。路A 仍绿（install.sh 入口 `check_jq` 独立于 install_hooks.sh 守卫，双防线）。路④ 仍绿（变异体确实谎报——这正是守卫要拦的行为）。

`npx bats --count test/` = **1076**（基线 1072 + 4）。

## 六维自评

| 维度 | 判定 | 说明 |
|---|---|---|
| ① 先红留档 | ✅ | HEAD fcffe3e 未修改生产代码上跑等价夹具，真实体 rc=1 + 变异体 rc=0 + 4× ⚠️ 原文已贴（上文 RED 段）。影子 PATH 排 jq + 前提自检 `command -v jq` 为空。 |
| ② 后绿 | ✅ | 4 例全绿：路A install.sh 入口 check_jq + 路B install_hooks.sh 两道守卫 + 无 *.tmp 残片 + 变异反向控制腿。settings.json 未被截断为空 + permissions.allow + Stop hook 存活。 |
| ③ 变异腿纪律 | ✅ | 变异在 /tmp 副本（`mktemp -d` + `cp -a`）上做，断言未变异绿 / 变异红两侧原文已贴。删 `:189-192` + `:365-368` ⇒ 腿②/③ not ok。 |
| ④ TEST.md 措辞 | ✅ | `:55` 改为「settings.json 未被截断为空 + permissions.allow 与既有 hook 存活（非字节相等）」+ 常设 bats = `test_install_jq_guard.bats`。只动这一行。 |
| ⑤ 夹具状态显式断言 | ✅ | 前提自检 `command -v jq` 为空 + `command -v mkdir` 成功（TD-081）；变异腿内 `guard_in=0` + `guard_merge=0` 断言变异真的删了守卫；`grep -c` 无匹配用 `|| true` 转 0 计数。 |
| ⑥ 台账 + 门禁 | ✅ | task_progress 五字段已追加 + `33-flow-active-integrity.sh` rc=0；`make check` 21 ✅。 |

## 未验证边界

- **install.sh 入口 check_jq 路径**：路A 只测 `--global --no-brooks --user` 组合（REQUIREMENT.md AC-2 指定的缺陷现场）。`--global`（无 --no-brooks）⇒ rc=127 在 install_brooks.sh 中止、`--global --no-brooks`（无 --user）⇒ rc=0 未截断——这两组未单独测（REQUIREMENT.md:150-153 已验证，非缺陷现场）。`test/test_install_jq_guard.bats:88-110`。
- **变异腿只删 install_hooks.sh 守卫**：路A 的 install.sh `check_jq`（`install.sh:169`）未被变异——若同时删 check_jq，路A 也会转 not ok。本任务只覆盖 R5-6 指定的两道守卫（install_hooks.sh:189-192 + :365-368）。`test/test_install_jq_guard.bats:166-230`。
- **dsh 平台**：paths.sh `resolve_paths dsh` ⇒ `USER_SETTINGS_FILE=""`（无 settings.json 承载面）——本 bats 只测 claude 平台。`flow-kit-bundle/lib/paths.sh:88-92`。
- **macOS 实机**：影子 PATH 构造依赖 `/usr/bin` 下命令存在；macOS 路径不同（TD-055 同族，未验证）。

## 写面清单

| 文件 | +/− 行数 | 说明 |
|---|---|---|
| `test/test_install_jq_guard.bats` | +238 / −0 | 新建：4 例常设 bats（路A + 路B ×3 + 变异腿） |
| `flow-kit-bundle/test/test_install_jq_guard.bats` | +238 / −0 | 镜像（`make test-sync` 生成） |
| `.specs/health-fix-2026-09b/TEST.md` | +1 / −1 | `:55` 措辞订正（字节不变 → 未被截断为空 + 非字节相等）+ 常设 bats 指向 |
| `.specs/health-fix-2026-09b/TASK.md` | +5 / −1 | T-FIX-15 status=done + `<done>` 注记 |
| `.specs/health-fix-2026-09b/T-FIX-15-SUMMARY.md` | +本文件 | 新建 SUMMARY |
