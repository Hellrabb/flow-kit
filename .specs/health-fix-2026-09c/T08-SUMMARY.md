# T08-SUMMARY — Makefile 门禁口径统一（AC-10 + AC-12-d/e + C1 加固）

变更：health-fix-2026-09c · 阶段4 DEV · T08
write_files（全部按边界，无越界）：`Makefile`、`package-dsh-plugin.sh`、`test/test_makefile_gates.bats`、`flow-kit-bundle/test/test_makefile_gates.bats`。

---

## 五合一 + ⑥ 逐项改动

### ① C1 并发闸（make test 加 flock）

- 前：`test` 目标无并发保护——2026-09-29 实测 3 个并发 `make check` 经测试 setup/teardown 互踩，把 tracked SKILL.md 损坏固化（LESSONS 2026-09-29 🔴，其修复建议 ④ 即本条）。
- 后（与 pre-push.sh T09 已落地的同款语义，F6 范式：锁文件 + mktemp 唯一路径）：
  - 锁 = `${TMPDIR:-/tmp}/flow-kit-make-test-$(id -u).lock`（确定性共享路径，同用户跨终端互斥；`FLOW_KIT_TEST_LOCK` 可覆盖——沙箱内嵌套跑 make test 时指向私有锁，防与外层已持锁的全量 make test 自死锁）。
  - 持锁范围 = bats 执行全程：`exec 9>>` fd 9，随 bash -c 退出自动释放，无清理路径；锁文件残留无害（内容恒空）。
  - `flock -w 600`（`FLOW_KIT_TEST_LOCK_WAIT` 可覆盖）：超时 **fail-closed 转红**——串行化拿不到就不得继续裸跑。
  - flock 不可得 / 锁不可写 ⇒ ⚠️ 警告后继续（best-effort 基础设施缺席不改内容判定，与 pre-push.sh 同层降级语义）；先 `: >>` 预探测可写性再 `exec 9>>`，把失败面收敛到可警告分支。

### ② C7 test 单跑合并

- 前（两遍执行）：`@npx bats test/ --formatter tap 2>&1 | tail -3`（仅展示）+ `@npx bats test/ > /dev/null 2>&1 && echo ✅ || { echo ❌; exit 1; }`（重跑取 rc）——全量用例白烧一遍，且两遍之间结论可能漂移。
- 后（单次执行）：`npx bats test/ --formatter tap 2>&1 | tee "$LOG" | tail -3`，`LOG=$(mktemp "${TMPDIR:-/tmp}/flow-kit-bats.XXXXXX")` 唯一路径（D9 沿用 F6 范式）；判定 `rc=${PIPESTATUS[0]}` 直接取 bats 本体退出码（防 tee/tail 吃 rc，L-098 管道吞 rc 反模式）；成功即清理 LOG，失败保留完整 TAP 日志并指名路径。整段以 `bash -c` 承载——PIPESTATUS 是 bash 扩展，make 默认 SHELL=/bin/sh（dash）不支持（与 check-nfr-portability 的 dash 兼容处理同款）。
- lesson 承接：2026-07「判定行必须直接取 bats exit」的性质不变，形态由两行制升级为单跑 PIPESTATUS（旧 lesson 被本形态取代，判定力等价）。

### ③ C10 lint 语义化（rc 判红 + fail-closed）

- 前：`OUT=$(shellcheck -e SC1091 "$f" 2>&1) || true; ERRS=$(echo "$OUT" | grep -ci "error" || true)`——文本近似判红：路径含 "error" 字样即假红（只假红不假绿，LESSONS 2026-09-29 🟢，其建议判据 `shellcheck -S error` 即本条）；shellcheck 缺席时 ⚠️ 跳过且**绿**（精简/离线环境 make check 退化为部分绿）。
- 后：`if OUT=$(shellcheck -S error -e SC1091 "$f" 2>&1); then :; else ❌ … rc=$?; ERR=1; fi`——severity 由工具自身判定，rc 即结论；**缺 shellcheck ⇒ ❌ fail-closed exit 1**（门禁在场性本身是判据一部分）；`SCANNED_FILES: <n>` + 路径 + 空行的输出契约逐字保留（REQUIREMENT AC-4b，验收脚本只解析该出口）；ADR-010 原则（error 级判红、warning 池只可见不判红）不动，注释块已改写为 rc 口径。

### ④ C14-d test-sync 递归 cp

- 前：`@cp test/*.bats flow-kit-bundle/test/`（不递归，漏 `test/fixtures/` 等子目录），而 check-test-sync 的 `diff -rq test/ flow-kit-bundle/test/` 递归比对 → 同步后 diff 仍可能红（口径错位）。
- 后：`@cp -R test/. flow-kit-bundle/test/`（含子目录，与 `diff -rq` 递归口径对齐）。

### ⑤ C14-e --check 退出前先跑 JS 单测

- 新增 `js_unit_tests()`（**唯一** `node --test "$SRC_DIR/test"/*.test.mjs` 字面量，现 :75，先于 case 定义）；`--check` 分支改为 `js_unit_tests || exit 1; check_dist || exit 1; exit 0`（现 :204）；打包步骤 5 改调同一函数（判据只写一份，R3）。
- node 缺席 ⇒ `❌ node 不在场…` rc≠0 显式提示，不静默跳过（DESIGN R8 fail-closed）。
- 位置序断言绿：`nt=75 < ck=204`（node --test 行号 < 首个 `--check.*exit` 行号）。
- Makefile 侧**零行为改动**：check-dist 原有 `bash package-dsh-plugin.sh --check` 间接挂载（D8 设计）即达成目的；Makefile 未写任何 `node --test` 字面量（L3 裁定）。
- 连带订正（注释/文案，随 ⑤ 变为事实性错误的表述）：参数分流注释「必须不调 node/npm」、usage_check 的 `--check` 描述、Makefile check-dist 上方「只读契约：不调 node/npm」——均改为「不重建、不改工作区；退出前先跑 JS 单测（只读源、不动 dist，缺 node fail-closed）」。

### ⑥ AC-10 PATH shim 计数用例

- 新增 `test/test_makefile_gates.bats`（+ 镜像，手动 cp 后 `cmp` 校验逐字节相同，未跑 make test-sync）。
- shim 设计：shim 目录前置 PATH，内含假 `npx` / 假 `bats`——每次被调即向计数文件追加一行（`echo "$tool $*"`，内容即命令行形态），并秒回最小 TAP（`1..1` / `ok 1 shim-<tool>`），让 make test 毫秒级返回（真跑全量要几分钟）。recipe 的调用形态是 `npx bats test/ --formatter tap` ⇒ 假 npx 收到 `bats test/ --formatter tap`，计数行以 `npx bats` 开头——断言 `^npx bats` 同时钉住「经 npx 调用」形态。**假 npx 不转调 bats**（PATH 上假 bats 会再计一行 → 计数=2 假红），假 bats 仅防御 recipe 直呼 bats 的形态变化。
- 用例 1（单跑）：shim rc=0 → `make test` rc=0、输出含 `✅ bats: all tests passed`、**计数文件恰 1 行**。旧实现（两遍执行）计数=2 行 ⇒ 本用例即 C7 的回归金丝雀。
- 用例 2（失败透传）：shim rc=1 → `make test` 非 0、输出含 `❌ bats: some tests failed`、计数仍恰 1 行（rc 经 PIPESTATUS 透传，不被 tee 吃）。
- 沙箱纪律：`FLOW_KIT_TEST_LOCK`/`FLOW_KIT_TEST_LOCK_WAIT`/`TMPDIR` 全部指向 mktemp 沙箱（L-137：断言与产物不含真实家目录字面；失败路径保留的 TAP 日志随沙箱清理）。

---

## verify 真实输出（本机自跑）

```
$ make lint
（SCANNED_FILES: 24 及逐文件清单，略）
✅ shellcheck: no errors found          # lint rc=0（rc 判红路径）

$ grep -c flock Makefile
6                                        # ≥1 ✓

$ anchor chain（编排者原句）
nt=75, ck=204 → ANCHOR OK: nt < ck      # ✓（且全文件唯一 node --test 字面量在 :75）

$ npx bats test/test_makefile_gates.bats
1..2
ok 1 make test 单跑执行：npx bats 恰被调一次（AC-10 shim 计数 = 1）
ok 2 make test 失败透传：bats rc=1 → make test 非 0（PIPESTATUS 不被 tee 吃）
rc=0

$ bash package-dsh-plugin.sh             # 重建 dist（新增 bundle 镜像文件使旧 dist 陈旧）
==> unit tests (node)
# tests 20
# pass 20
# fail 0
==> done / tarball: dist/dsh-flow-kit-0.2.0.tgz      # rc=0（打包路径 js_unit_tests）

$ bash package-dsh-plugin.sh --check     # 编排者增补项：JS 单测在 check 路径内执行且 rc 透传
==> unit tests (node)
# tests 20
# pass 20
# fail 0
✅ check-dist: dist 与源一致              # rc=0
```

### 全量 make test（flock 串行化下真实全量）

```
🧪 make test: running bats...
（tap 全量经 tee|tail -3，末 3 行如下）
ok 1141 CF-01: write_compliance_correction creates valid JSON with all fields
ok 1142 CF-02: write_compliance_correction merges with existing + dedup
ok 1143 CF-03: clear_compliance_correction removes the file
✅ bats: all tests passed
MAKE_TEST_RC=0
```

- 全量 1143 用例全绿（任务块写的 1133 为拆解时基数；+10 来自同波兄弟任务新增用例与本任务 ⑥ 的 2 例，方向一致）。
- 旧实现此输出需要跑两遍 bats；单跑后一遍完成，flock 全程持默认锁，无假红。
- `test_gate_freshness.bats`（--check 全家回归）在本次全量内通过——js-first --check 未破坏其夹具/断言。


---

## 偏差与说明

1. `make check-test-sync` 按任务块留给编排者波末统一跑（同波兄弟任务的镜像文件可能仍在途）。
2. dist 在 verify 中重建了一次：新增 `flow-kit-bundle/test/test_makefile_gates.bats` 使旧 dist 对源陈旧，不重建则编排者增补的 `--check` 必红——重建属 --check 可执行的前置条件（packaging 全程 rc=0，未见其他差异项）。
3. make test 经 flock 串行化执行；若兄弟波次同时在跑 bats 属预期（等待互锁，非死锁：各自沙箱锁独立、全量共用默认锁）。
4. 无 git commit、未改 .flow-active、未改 TASK.md 状态。

## 破坏性变更段（flow-dev 1.8）

- 删除/替换面：Makefile `test` 目标两行旧 recipe（≈3 行）、`lint` 判红主体（`OUT/ERRS` 文本近似 → rc 判红）、test-sync 的 cp 一行；package-dsh-plugin.sh 打包步骤 5 的内联单测块 → 函数调用。合计 ≈12 行被替换，无对外接口变更（make 目标名、`--check` 语义外壳、SCANNED_FILES 出口、tarball 产物均不变）。
- 回归覆盖：⑥ 的 2 个新用例（单跑/失败透传）钉住 test 目标契约；`test_gate_freshness.bats` 全家（--check 的 9 个用例 + 打包侧）经全量 make test 覆盖——其夹具自带 dummy .test.mjs，js-first --check 在夹具内同样过；`test_quality_baseline.bats` 断言 `^test:`/`^lint:` 目标定义与 make lint 绿，均保持。

## 6 维自查

- **R1 认知过载**：test recipe 的 bash -c 脚本 ≈27 行（注释外置，嵌套 ≤3：flock 分支 × bash -c × if）；`js_unit_tests()` 9 行单一职责。达标。
- **R2 变更传播**：git diff 仅触 write_files 四文件（`git status` 复核；dist/ 为 .gitignore 忽略的构建产物，重建属预期）。达标。
- **R3 知识重复**：`node --test` 判据从「打包内联一份」收敛为 `js_unit_tests()` 唯一一处，--check 与打包同调（本任务的主目的之一）；flock 语义与 pre-push.sh 同款但载体不同（Makefile recipe vs bash hook），共享语义约定而非复制代码，且两者注释互指。达标。
- **R4 偶然复杂**：bash -c 承载为必要复杂（dash 无 PIPESTATUS）；shim 双写（npx+bats）各司其职（计数主体 / 形态防御）。达标。
- **R5 依赖混乱**：无新增外部依赖；flock/shellcheck/node 均带缺席降级或 fail-closed 分支，缺席路径显式可观测。达标。
- **R6 领域扭曲**：均为门禁/构建层改动，不触业务域。达标。
- **1.4 既有抽象检查（grep 结果）**：`grep -rn 'make test\|make lint' test/*.bats` 仅 test_archive_commit_gate（pre-commit 文案断言）与 test_quality_baseline（目标定义存在性）引用相关字样，无可复用的「make 目标 shim 计数」既有工具——⑥ 为新判据，自建 `make_shim()`；flock 范式复用 pre-push.sh T09 已定稿的语义（fd 9 / -w 超时 / 缺席降级 / 超时 fail-closed）。

## 引用 lesson

- LESSONS 2026-09-29 🔴（3 并发 make check 互踩 tracked SKILL.md → 修复建议 ④ 即 C1 本条）。
- LESSONS 2026-09-29 🟢（lint `grep -ci error` 文本近似只假红不假绿 → 建议判据 `shellcheck -S error` 即 C10 本条）。
- L-098（验证双向性/管道吞 rc 反模式 → PIPESTATUS 取真 rc，本任务判据与 verify 均遵循）。
- L-137/去标识化（夹具 mktemp + 断言不含真实家目录字面 → ⑥ 沙箱纪律）。
- 2026-07 legacy（test 判定行直接取 bats exit——性质保持，形态被 C7 单跑取代，已在 ② 注明承接）。
