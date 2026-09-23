# T11-SUMMARY — AC-3(a)：新建 `pre-push` 拦截器本体（保留 `make check` 语义 + 100755）

- **Change ID**: health-fix-2026-09b
- **Task**: T11（阶段 4 · DEV）
- **完成日期**: 2026-09-23
- **执行模型**: standard（MODEL-TIER hint）
- **成果**：新增 `flow-kit-bundle/hooks/pre-push/pre-push.sh`（**100755 入库**），实现 AC-3 推送拦截器本体。**次序硬契约**（IR-3 C2 定稿）：① 先逐行评估 stdin 的 `<local ref> <local sha> <remote ref> <remote sha>`，命中泄漏的 ref 在报文里**指名该 ref**（形如 `refs/heads/main`、`refs/tags/v1`）并 non-zero 拒绝；② 全部 ref 干净后才跑 `make check`（保留既有「push 前跑 make check」语义，`make check` 字面保留）。

---

## 1. 做了什么

新建 `flow-kit-bundle/hooks/pre-push/pre-push.sh`（41 行，bash 3.2 兼容）：

```bash
#!/bin/bash
# 头注释（变更 / 行为次序 / 兼容性声明）
set -euo pipefail
leaky_ref=""
while IFS= read -r line || [ -n "$line" ]; do      # ① 逐行读 stdin
    set -- $line                                     # bash 3.2 逐字段展开（不用 mapfile/关联数组）
    [ "$#" -ge 1 ] && [ -n "$1" ] || continue
    local_ref=$1
    if ! CHECK_REF="$local_ref" make check-path-privacy; then   # 泄漏评估：DESIGN §2.1 目标
        echo "🔴 拒绝推送 $local_ref：该 ref 含路径隐私泄漏（make check-path-privacy 未通过）" >&2
        leaky_ref="$local_ref"; break
    fi
done
[ -z "$leaky_ref" ] || exit 1                       # 任一泄漏 ⇒ 报文已指名该 ref，拒绝
make check                                          # ② 全部干净 ⇒ 推送前 make check（保留语义）
```

要点：
- **先说后跑**：泄漏判定（`make check-path-privacy`）全部逐 ref 评估完并 confirm 干净，才到 `make check` —— 次序反了会使 `make` 通用错误先失败、报文无法指名 ref（T19 四形态断言依赖）。
- **指名 ref**：拒绝报文含完整被拒 ref（`refs/heads/main`、`refs/tags/v1`），T19 正则 `(^|[^[:alnum:]_])main([^[:alnum:]_]|$)` 与 `v1` 命中。
- **字面保留**：末行 `make check` 字面保留（`test_quality_baseline.bats:82` 无 skip grep 依赖）。
- **泄漏评估经 `CHECK_REF=` 环境前缀传 ref**：只作归因提示（真实 `check-path-privacy` 目标忽略之，`make VAR=val` 仅是变量赋值、不成为 make goal ⇒ 不产生「No rule to make target <ref>」）；影子测试 stub 用 `$CHECK_REF` 区分各 ref。
- **bash 3.2**：`while IFS= read`、`set --`、裸变量；无 `mapfile` / `declare -A` / `readlink -f` / `sed -i` / GNU-only。

## 2. 改了哪些文件

| 文件 | 改动 |
|---|---|
| `flow-kit-bundle/hooks/pre-push/pre-push.sh` | **新增**（41 行 · 100755） |
| `.specs/health-fix-2026-09b/T11-SUMMARY.md` | 新增（本档） |
| `.specs/health-fix-2026-09b/MINOR-DEFERRED.md` | 追加 1 条（§11，见下） |
| `.specs/health-fix-2026-09b/TASK.md` | T11 `status="pending"` → `"done"` |

**未改动**：`.git/hooks/pre-push`（T16 部署面，373 B 原样）、`sync-hooks.sh`（T16）、`Makefile`、`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（本 task 期间尚不存在，T17 建；只按契约调用，未自行创建）、任何其他产品代码/测试。

## 3. verify 真实输出

判据落地为 `/tmp/t11-sbx.e8cJnD/t11v.sh`（= task `<verify>` 段，唯一授权改写：**禁用构造 grep 改为「注释盲」形态**，见 §8）。`bash -n t11v.sh` rc=0，实跑 **rc=0**：

```
== [T11 verify] path=<repo>/flow-kit-bundle/hooks/pre-push/pre-push.sh ==
ok  文件存在
ok  可执行
ok  mode=755 (755)
ok  含 'make check' 字面
ok  bash -n 语法通过
ok  注释盲形态下无禁用构造
== T11 verify rc=0 ✅ ==
t11v rc=0
```

> 注：XML 原始 `stat` 行就已是 GNU/BSD 双兼容（`stat -c '%a' … || stat -f '%Lp'`），照录执行。

## 4. 双态对照（L-120 / L-119）—— 核心判据证据（影子 PATH + stub make 隔离纯逻辑）

沙箱 `/tmp/t11-sbx.e8cJnD/bin/make`：`check-path-privacy` 按 `$CHECK_REF` 判定（`*main*`/`*v1*` ⇒ rc=1 泄漏，其余 rc=0 干净）；`check` 恒 rc=0。`path + hook` 前置影子目录实跑：

| 态 | stdin | 期望 | 实际 | rc |
|---|---|---|---|---|
| T1 干净 ref | `refs/heads/feature …` | rc=0（→ make check） | `✅ check-path-privacy: 干净` + `✅ make check: 通过` | **0** |
| T2 泄漏 ref | `refs/heads/main …` | rc≠0 且报文命中 `refs/heads/main` | `🔴 拒绝推送 refs/heads/main：…` | **1** |
| T3 多行混合 | develop 行 + main 行 | rc≠0 且指名泄漏那一行(main) | develop 判干净、main 判泄漏 → 报文指名 `refs/heads/main` | **1** |
| T4 空 stdin | （无输入） | 见下 | → 直接 `make check` | **0** |

**空 stdin 判定**：**放行**（rc=0）。理由：空 ref 集 = 本次 `git push` 无可被推送、无可泄漏的 ref（管道无输入即无推送条目），per-ref 泄漏面为空；此时仅剩 `make check` 门禁，其通过即放行。这与「干净 ⇒ 放行」的最终语义一致。

## 5. 反向对照（L-123：放行/拒绝非恒真恒假）

两个机器可判的破坏分支，判据**必随破坏翻转**（恒真/恒假则翻转不应发生）：

| 反向 | 破坏点 | 输入 | 实际 | 结论 |
|---|---|---|---|---|
| A | 移除泄漏拦截分支（变体把 `if ! make check-path-privacy` 换 `:`） | `refs/heads/main` | **rc=0**（main 被误放行） | 原「拒绝」是泄漏分支驱动，非恒真 |
| B | 破坏 `make check`（stub 恒 rc=1） | `refs/heads/feature`（干净） | **rc=1**（干净 ref 被误拒） | 原「放行」是 `make check` 通过驱动，非恒真 |

`REVERSE CONTROL PASS ✅`（rc=0）。

## 6. 越界检查（R6.5 / `git show --numstat`）

提交仅含：`flow-kit-bundle/hooks/pre-push/pre-push.sh`（新增）+ `.specs/health-fix-2026-09b/T11-SUMMARY.md`（新增）+ `MINOR-DEFERRED.md`（追加）+ `TASK.md`（T11 status 一行）。仓库中另有的 `.specs/CONTEXT.md`/`LESSONS.md`/`STATE.md` 改动与未跟踪归档档**非本次范围**，不 `git add`。

`git show --numstat <commit>`（见 §12 收尾粘贴）：越界 0 —— 非上述目标的文件改动数为 0。

## 7. 沿用了哪些既有抽象（R6.4）

- `make check-path-privacy` / `make check`（Makefile 目标，DESIGN §2.1 契约）—— 本 hook 只**调用**，不自建门禁逻辑。
- `.git/hooks/pre-push`（T16 部署面）与本新增 bundle 源同构 —— 本 task 只产源，交给 T16 symlink 部署（`flow-kit-bundle/hooks/pre-commit/pre-commit.sh` 为风格模板）。
- stdin 四元组反射 + bash 3.2 `set --` —— 沿用仓内 hook 惯用法。

## 8. 主 agent 授权判据改写（记录偏离与理由）

> 任务 §5① 授权改写，且要求双向双态对照 + 恢复后逐字节证明。

**改写点**：verify 末条 `grep -qE 'mapfile|declare[[:space:]]+-A|readlink[[:space:]]+-[fe]|sed[[:space:]]+-i' "$H" && exit 1` 是**注释盲**缺失（L-125 族）：我的头注释必然出现「不用 mapfile / declare -A / readlink -f / sed -i」字样，裸 grep 会把注释读成残留构造 ⇒ 假红。改为**按行剥注释后匹配**：

```bash
PAT='mapfile|declare[[:space:]]+-A|readlink[[:space:]]+-[fe]|sed[[:space:]]+-i'
awk '{ sub(/#.*/, ""); print }' "$H" | grep -qE "$PAT" && { echo "🔴 含 bash4/GNU-only 构造"; exit 1; }
```

**双向双态对照（真跑，`dual.sh`，DUAL-STATE PASS ✅ rc=0）**：

```
对照 A（真语句注入 → 必须红）：末尾注入 `mapfile -t x < <(echo a)`
  grep 命中注入行 ⇒ ✔ 判据【红】(检测到真语句)
对照 B（同一文本进注释 → 必须绿）：注入 `# mapfile -t x < <(echo a)`
  注释盲剥离后无命中 ⇒ ✔ 判据【绿】(注释盲放行注释)
恢复证明：恢复副本 sha256 与原脚本一致；真实脚本 sha256 未变
  基线 = 复原版 d2a14f6f863b655980bb831145f0ee3b933283e424620ac8fea5d348bacd3524
```

## 9. TDD 声明

本 task 无独立测试文件（新增 hook 的测试面由 **T16**（部署形态/`test_quality_baseline` .git/hooks 断言）与 **T19**（四形态端到端实跑）承担，如实声明）。我方在本 task 内完成的「先红后绿」等价循环：
- **行为双态（§4）**：干净 ref ⇒ rc=0，泄漏 ref ⇒ rc≠0 且指名该 ref —— 直接验证 SUT 行为。
- **反向对照（§5）**：破坏分支 ⇒ 判据翻转，证明判据有判定力（非恒真/恒假）。
- 泄漏判定本身（`make check-path-privacy` 的扫描逻辑）属于 T17/T18/T19，本 task 不越界实现。

## 10. 质量门禁（默认环境）

- `bash sync-hooks.sh --check`：**rc=0，漂移 0**（预取：pre-push 不在正向同步集也不在 orphan 反向扫描集 ⇒ 新增文件不产生漂移，实测符合；未改 sync-hooks.sh）。
- `make test`（`npx bats test/ --formatter tap`）：**973 ok / 0 not ok / rc=0**（计数 `ok 973` 末行为 CF-03）。
- `make check-test-sync`：**rc=0**（`✅ test 双源一致`）。
- `make check-dist`：**预期为红（待 T24 收口），未修、未据此判失败**。含我新文件对应的两条「缺失」—— `dist/dsh-flow-kit/hooks/pre-push/pre-push.sh` 与 vendor 镜像 —— 为**打包件新鲜度/缺失**（源→dist 未重建），属集成打包阶段刷新范围，非源缺陷，本 task 不重建 dist（重建会触碰打包面，越界）。
- pre-commit：自然跑绿（无 `--no-verify`、无环境覆盖）。

## 11. 遗留 / 说明（也登记 MINOR-DEFERRED）

- **dist 缺失刷新生效时间点**：`check-dist` 对我新 hook 的两条「缺失」在 `bash package-dsh-plugin.sh` 重建前仍红；这不影响源正确性，且 `check-dist` 整体本来预期红到 T24 ⇒ 判定为**本 task 已知接受项、非缺陷**，发到集成/打包阶段刷新即可。

## 12. 6 维自查（R1–R6）

- **R1 认知过载**：hook 41 行，单循环 + 一次 `make check`，分支扁平 ⇒ ✅
- **R2 变更传播**：写面严格封闭，仅 4 个目标文件；`git add` 显式路径；不触碰部署面 ⇒ ✅
- **R3 知识重复**：泄漏扫描逻辑完全委托 `check-path-privacy` 目标，hook 无重复门禁逻辑 ⇒ ✅
- **R4 偶然复杂**：无兜底、无 `|| true`；`CHECK_REF` 环境前缀仅作归因提示（真实目标忽略） ⇒ ✅
- **R5 依赖混乱**：只依赖 `make check-path-privacy` / `make check` 契约目标，不 mock SUT ⇒ ✅
- **R6 领域扭曲 / R6.4 / R6.5**：不引行号；沿用具名目标；`git show --numstat` 越界 0 ⇒ ✅

**收尾**：commit sha 见提交；`make test` 973/0/rc=0；`sync-hooks --check` 漂移 0；`check-test-sync` rc=0；`check-dist` 红（预期，待 T24）；行为双态 4/4；空 stdin ⇒ 放行（理由 §4）；越界 0；遗留 = dist 条目的打包刷新（§11）。