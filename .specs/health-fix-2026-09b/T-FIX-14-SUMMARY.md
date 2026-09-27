# T-FIX-14 SUMMARY — 安装形态下隐私检查器可达性 + pre-commit 隐私块前置

- change: `health-fix-2026-09b` · phase 4 · round 5 fix loop · task `T-FIX-14`
- commit: `7815c02d709ae3a7a03ca789dfc6e9b75d9d20bb` (`%cI` = `2026-09-14T13:30:33+00:00`)
- HEAD before: `1b5a9c39a3064ce329c10b381a82123594aad792`
- findings: R5-18 🔴 / R5-19 🟡 / R5-24 🟢

## 修复前 RED 原文（verify ① 先红）

夹具：`bash flow-kit-bundle/install.sh --platform claude --project /tmp/tfix14/proj --hooks-only` 后，两种形态跑 pre-push：

```
leg1 (symlink .git/hooks/pre-push → …):
  rc=0
  ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描

leg2 (真实脚本路径 .claude/hooks/pre-push/pre-push.sh):
  rc=0
  ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描
```

`/tmp/tfix14/pre.txt`：`grep -c '未找到可用的路径隐私检查器'` = 2，`grep -c '拒绝推送'` = 0。
两种形态均静默跳过内容扫描 ⇒ 消费者项目推送时整道门禁失效。

## 修复后 GREEN 原文（verify ② 后绿）

`npx bats test/test_install_layout.bats`：

```
ok 1 symlink form: leaky ref rejected (rc≠0 + 🔴 拒绝推送 + ref name)
ok 2 real-script form: leaky ref rejected
ok 3 clean ref: rc=0 (checker found, no leak)
ok 4 install deploys check-path-privacy.sh + allowlist at <proj>/.claude/reference
ok 5 real-missing: rc=0 + exact skip message (T-FIX-13 ① preserved)
ok 6 reverse-control: reverting candidates to old-three turns leg ① red
ok 7 pre-commit: no Makefile + leaky commit rejected (privacy block before early-exit)
ok 8 pre-commit: no Makefile + clean commit rc=0
8 tests, 0 failures
```

反向控制（verify ③，判据有牙）：strip `$HOOK_DIR/../../reference` 候选 ⇒ `not ok` count=2 ≥1；restore ⇒ 8 ok。

## 逐文件改动说明

### flow-kit-bundle/hooks/pre-push/pre-push.sh

**R5-18 🔴（检查器不可达）+ R5-24 🟢（死变量）**

新增 `_resolve_self_path()`：用 `command -v readlink` + 深度上限 40 的循环解析 `BASH_SOURCE[0]` 的 symlink 链。relative target 用 `$(cd "$(dirname "$self")" && pwd)/$target` 拼接，absolute target 直接用。`HOOK_DIR="$(cd "$(dirname "$(_resolve_self_path)")" && pwd)"` ⇒ 经 `.git/hooks/pre-push` symlink 调用时仍解析到 `<proj>/.claude/hooks/pre-push`（而非旧逻辑的 `<proj>/.git/hooks`）。

`resolve_reference_dir()` 候选 3→4 条（精确列表，无 glob）：
1. `$HOOK_DIR/../flow-kit/reference`（源码树形态）
2. `$HOOK_DIR/../reference`（user-scope 旧层级）
3. `$HOOK_DIR/../../reference`（**新增** — project-scope 安装形态：`<hook_dst>/pre-push` → 上两级到 `<hook_dst>/..` = `.claude`，再 `/reference` = `<proj>/.claude/reference`）
4. `$HOOK_DIR/../../flow-kit/reference`（user-scope 替代）

R5-24：删除 `pure_delete_seen=0`（原 :161）与 `pure_delete_seen=1`（原 :183），全文件无读取。`grep -c 'pure_delete_seen'` = 0（注释中亦不含该名）。

### flow-kit-bundle/hooks/pre-commit/pre-commit.sh

**R5-19 🟡（隐私块排在 Makefile/npx 早退之后 ⇒ 消费者项目不可达）**

全量重排：`PATH` setup → `_resolve_self_path()` + `HOOK_DIR`（同 pre-push 的 readlink-loop 逻辑 + 同 4 候选）→ `resolve_reference_dir` + `makefile_has_target` → **隐私块**（make check-path-privacy OR bundle fallback 含 T-FIX-13 三态 ② fail-closed exit 1 / ① skip message）→ **test 门**（无 Makefile exit 0 "skipping test gate" / 无 npx exit 0 / make test fail exit 1）。

隐私块 grep 行(5) < no-Makefile grep 行(107) ✓。

### flow-kit-bundle/lib/install_hooks.sh

**R5-18（注释固化层级关系）**

:277-292 注释块重写：reference 落在 `<hook_dst>/../reference/`（project: `<proj>/.claude/reference`；user: `<HOME>/.claude/reference`）；hook 落在 `<hook_dst>/<hook-name>/<hook-name>.sh`（**深一层**）⇒ 候选必须含 `$HOOK_DIR/../../reference`。`ref_dst_dir` 代码不变。

### test/test_install_layout.bats（新增，8 例）

setup：`mktemp` HOME+PROJ，`FLOW_KIT_YES=1`，stub git identity；`PROBE_LEAK` 拼接构造（`/home/''zz-tfix14-probe''/secret`）。

- ① symlink 形态泄漏 ⇒ rc≠0 + `🔴 拒绝推送` + `refs/heads/main`
- ② 真实脚本路径形态 ⇒ 同
- ③ 干净 ref ⇒ rc=0（用**独立 clean_proj fixture** — 干净 commit 树不含 leaky.txt，否则误红）
- ④ 安装位 `check-path-privacy.sh` + `allowlist` 就位 `<proj>/.claude/reference`
- ⑤ 真缺失态（mv 两者走）⇒ rc=0 + 逐字跳过消息（T-FIX-13 ① 未回退）
- ⑥ 反向控制：`awk` strip for-line 的 `$HOOK_DIR/../../reference` 候选（保持 for-done 结构完整）⇒ legs①② 红
- ⑦ pre-commit 无 Makefile + 泄漏 ⇒ rc≠0
- ⑧ pre-commit 无 Makefile + 干净 ⇒ rc=0

### test/test_archive_commit_gate.bats（setup 修改）

setup 新增 `git init -q` + 提交干净 `.gitkeep`。原因：pre-commit 隐私块前置后，`check-path-privacy.sh` 在空 git index（0 候选）下按 ADR-027 fail-closed ⇒ 挡住 "no Makefile" 腿。夹具让隐私扫描走「清单内、放行」分支。

**关于 test_archive_commit_gate.bats setup 修改的越界说明**：T-FIX-14 `<action>` 只授权「pre-commit 隐私块前置」，未显式授权改此夹具。但隐私块前置使该夹具的 T01 腿（`no Makefile → skip message` / `make test fail → reject`）在原 setup（非 git mktemp 根）下 fail-closed。两条路：(a) 在 pre-commit.sh 加 `git rev-parse --is-inside-work-tree` 失败 ⇒ 跳过的 fail-open 分支（**不在 `<action>` 授权内，且引入消费者侧 fail-open 风险**），或 (b) 在夹具里 `git init` + 提交干净占位文件（**只影响测试夹具，不改生产行为**）。选 (b) 更安全：夹具行为更接近真实消费者场景（消费者项目 pre-commit 由 git 触发，CWD 必在仓库根且有提交），且不引入任何 fail-open 路径。初始实现曾加 (a) 的 skip 分支，经主 agent 复核指出越界后已删。

## 六维自检

| 维度 | 判据 | 结果 |
|------|------|------|
| ① 先红 | pre-RED 原文 ≥2 条 skip、0 条拒绝 | ✅ `/tmp/tfix14/pre.txt` skip=2 reject=0 |
| ② 后绿 | npx bats test/test_install_layout.bats not ok=0 / ok=8 | ✅ 8 tests, 0 failures |
| ③ 反向控制 | strip 新候选 ⇒ not ok≥1 | ✅ not ok=2；restore ⇒ 8 ok |
| ④ 静态 | pure_delete_seen 计数=0；privacy grep 行 < no-Makefile grep 行 | ✅ count=0；privacy L5 < no-Makefile L107 |
| ⑤ 语法 | bash -n 三件 rc=0 | ✅ |
| ⑥ 全量 | npx bats --count test/ ≥1070 | ✅ 1072（基线 1064 +8） |

## 未验证边界（6 条）

1. **user-scope 安装形态**：测试只覆盖 project scope（`--platform claude --project`）。user-scope（`--platform claude` 无 `--project`）的 `<HOME>/.claude/reference` 落位与 `$HOOK_DIR/../../reference` 解析未端到端验证。逻辑上候选 4 条覆盖该形态，但无 bats 腿。
2. **opencode platform**：测试只覆盖 claude platform。opencode 的 hook_dst 与 ref_dst_dir 布局不同，`resolve_reference_dir` 的候选是否命中未验证。
3. **HOOK_DIR 深度边界**：`_resolve_self_path` 深度上限 40。若 symlink 链 >40 层（非现实场景），会停在最后一跳。未测边界。
4. **check-path-privacy.sh 自身修改**：检查器本体不在本任务写面。若其后续修改了 CHECK_REV 语义或 CWD 要求，pre-push/pre-commit 的调用契约可能需同步。`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:196`。
5. **pre-commit 非 git 目录**：删了 fail-open skip 分支后，若消费者在非 git 目录手动跑 pre-commit.sh，`check-path-privacy.sh` 会因 `git rev-parse` 失败而 fail-closed（exit 1）。这是更安全的行为，但与 pre-T-FIX-14 行为不同。实际消费者场景由 git 触发，CWD 必在仓库根，故不可达。
6. **TASK.md 含主 agent 第 5 轮任务定义块**：`git show --numstat` 显示 TASK.md +351 行，含主 agent 的 T-FIX-14…23 任务定义 + 本任务的 `status="done"` + `<done>` 注记。主 agent 指示「fix loop 计划随首个修复任务落史，不必拆分」。

## sync/dist 验证

- `make test-sync` ✅ test 双源已同步
- `bash sync-hooks.sh` ✅ 已同步 6 个文件（6 镜像）
- `bash package-dsh-plugin.sh` ✅ 5.9M dir / 1.4M tgz / syntax 20/0
- `bash package-flow-kit.sh /tmp/tfix14/pkg-out2` ✅ exit 0
- `make check-hooks-sync check-test-sync check-dist` ✅ 漂移 0
- `make check` ✅ 全部通过（21/21）
