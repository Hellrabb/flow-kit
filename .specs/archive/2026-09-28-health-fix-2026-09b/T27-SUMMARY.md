# T27 分发件复扫（AC-1④ + AC-5）— 执行摘要

- **任务 ID**: T27（`parallel="true"`, 依赖 T24）
- **性质**: 只读复查；判据 `export LC_ALL=C` 曾致 bats 假红，主 agent 于 commit `dd0870f` 按 L-146 收窄作用域并回写 TASK.md 的 T27 `<verify>` 工件后本 task 放行。
- **结果**: 判据 rc=0；六项门禁全 rc=0；活性校验（假归档 ⇒ rc=1 / 复原后 ⇒ rc=0）通过；已提交。

## 一、任务与判据（抽取手法 + 行锚）

- 契约取自 `.specs/health-fix-2026-09b/TASK.md` 的 `<task id="T27">` 块：`awk '/<task id="T27"/,/<\/task>/'`。
- 判据抽取：同块内按 `<verify>` 起、`</verify>` 止抽取，落在 `awk '/<verify>/{f=1;next}/<\/verify>/{f=0}f'`。
- 抽取结果落盘 `/tmp/vblocks/v_T27.sh`（**仓库内未落任何临时文件**），`bash -n` 通过。
- 判据职责：①逐归档（`for t in dist/dsh-flow-kit-*.tgz`，**禁**把通配直接交给 tar，`tar tzf` 可解析）断言 `$(eval echo …)` 计数=0、`chisel` 计数=0，任一非 0 ⇒ fail ⇒ 非零退出；②`grep -rn chisel test/ flow-kit-bundle/test/` 0 命中；③`npx bats test/` TAP 断言 `not ok`=0 且 `ok`≥973 且 rc=0。
- **判据作用域修复**（主 agent 裁定 L-146，对应 TD-051）：在 `npx bats` 前插入 `unset LC_ALL; [ -n "${LANG:-}" ] || export LANG=C.UTF-8;` —— 修 `export LC_ALL=C` 泄漏进 bats 子进程、glibc iconv 在 `LC_CTYPE=C` 下拒绝合法多字节 UTF-8、导致 `test/test_l3_pipeline_fix.bats:609` 假红（非产品回归）。

## 二、产物与证据（判据实跑原始输出）

前置：`export LC_ALL=`（外壳清空地域残留），仓库根前台，`HOME` 未动。

```
dist/dsh-flow-kit-0.2.0.tgz: eval-echo=0
dist/dsh-flow-kit-0.2.0.tgz: chisel=0
bats: rc=0 ok=976 not-ok=0（基线 2026-09-23 实测 rc=0 / 973 ok / 0 not ok，skip 计入 ok 行）
```
- 判据整体 **rc=0**。
- 关键三条输出行（如实上报，bats 基线「973 ok」为陈旧措辞，实测 976 ok / 0 not ok / 0 skip）：
  1. `dist/dsh-flow-kit-0.2.0.tgz: eval-echo=0`
  2. `dist/dsh-flow-kit-0.2.0.tgz: chisel=0`
  3. `bats: rc=0 ok=976 not-ok=0`

## 三、六项门禁 rc（显式运行；core.hooksPath 为空串 ⇒ git 不调用 hook，提交**不经过**门禁，以下为独立显式执行）

| 门禁命令 | rc |
|---|---|
| `make lint` | 0 |
| `make check-dist` | 0 |
| `make check-hooks-sync` | 0 |
| `make check-validate` | 0 |
| `make check-path-privacy`（新产物未 staged 时基线） | 0 |
| `bash sync-hooks.sh --check` | 0 |

`make check-path-privacy` 在新产物 staged 后复跑一次（见第五节提交后证据）。

## 四、活性校验（证明判据非恒绿）

1. 造假归档 `dist/dsh-flow-kit-9.9.9.tgz`（含 `chisel` + `$(eval echo evil)` 两行）⇒ 判据输出：
```
dist/dsh-flow-kit-0.2.0.tgz: eval-echo=0
dist/dsh-flow-kit-0.2.0.tgz: chisel=0
dist/dsh-flow-kit-9.9.9.tgz: eval-echo=1
dist/dsh-flow-kit-9.9.9.tgz: chisel=1
🔴 分发件仍有可注入 hook 或内部项目名
```
   ⇒ **rc=1**（判据对残留确实失败，非恒绿）。✔
2. 删除假件、复原 `dist/` ⇒ `ls -l dist/` 仅剩 `dsh-flow-kit-0.2.0.tgz`（1385199 B），`sha256sum` = `0b3d73e25cd2c94c2d19eae04b57d27bbb197610c727d1cf878deed0b9d94485`（与原始一致）。复跑判据 ⇒ **rc=0**，输出同上。

## 五、提交

- 提交内容（恰 2 文件）：
  - `.specs/health-fix-2026-09b/T27-SUMMARY.md`（本文件，新建）
  - `.specs/health-fix-2026-09b/TASK.md`（仅 T27 状态行 `status="pending"` → `status="done"`）
- 提交命令：`git add <两个文件>` + `git commit -m "…" -- <两个文件>`（`-m` 在 `--` 之前；未用 `-A`/`.`/`stash`/`--no-verify`）。
- 5 个冻结 `A ` 文件（CHANGE.md / IR-1/2/3.md / REQUIREMENT.md）**未**卷入提交。
- 提交后 `git show --numstat HEAD`（见提交输出）、`git log -1 --format=%H %cI`、以及新产物 staged 后复跑 `make check-path-privacy` rc=0。

## 六、六维自查

- **正确性**：判据按契约原样实跑 rc=0，逐归档 eval-echo/chisel 计数均 0；源测试 chisel 0 命中；bats 976 ok / 0 not ok。
- **完整性**：覆盖 AC-1④（归档面）+ AC-5①（验证方式「禁通配」「判据必须能失败」）；活性校验证明判据对残留确实非零退出。
- **一致性**：产物清理（假件删除 + sha 复原自证）后 `check-dist` rc=0（dist 与源一致），未引入源面改动；hooks 副本漂移 0、validate 覆盖 0 漏配。
- **兼容性**：不改动 `test/**`、`flow-kit-bundle/**`、`dist/` 与 TASK.md 除状态行外任何内容；避免触发 T24 次序硬约束；TD-051 已登记由主 agent 后续 change 处理。
- **可维护性**：判据的作用域注释（`仅归档扫描段需要 C 地域`）与 L-146 成因注释已由主 agent 回写进 TASK.md 工件，后续可读。
- **安全性**：无新依赖、无敏感信息；SUMMARY 已脱敏（不出现真实本机账号路径）；工作树无本任务之外的改动。

## 七、遗留与说明

- bats 基线文本「973 ok」为陈旧措辞，实测 976 ok / 0 not ok / 0 skip；判据用 `>=973` 断言故不红，本摘要如实记录实测值，未改判据文本。
- `export LC_ALL=C` 与 glibc iconv 的交互属**判据环境作用域缺陷**（非产品回归），已由主 agent 收窄作用域并登记 TD-051，本 change 不动源面。
- 台账 `.flow-active` 于提交后追加 T27 记录（`commit_sha` 取本提交短 sha，`fix_rounds:0`，`deferred:[]`，`completed_at` 为真实写入时刻）。