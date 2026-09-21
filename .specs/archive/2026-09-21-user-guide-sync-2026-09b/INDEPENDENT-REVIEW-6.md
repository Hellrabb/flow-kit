# 独立审查 · 阶段 6

## L2 盲审

审查对象（终态快照，读于 2026-09-21 22:33–22:34）：`git status --porcelain` + `git diff`(10 文件) + 未跟踪新增（`.specs/user-guide-sync-2026-09b/**`、`test/test_guide_copy_parity.bats`、`flow-kit-bundle/test/test_guide_copy_parity.bats`）+ 参考 `REQUIREMENT.md`(AC 唯一来源)/`DESIGN.md`/`TASK.md`/`TEST.md`/`DEV-SUMMARY.md`/`UAT.md`/`MINOR-DEFERRED.md`/`REVIEW.md`(待复核对象)。

独立复跑（只读，不采信他方结论）：
`bash verify-ac.sh` **86/0 rc=0** · `bash verify-boundary.sh` **rc=0** · `python3 deck_checks.py` **rc=0(24 页)** · `npx bats test/test_guide_copy_parity.bats` **7/7 ok** · 同一文件在 `flow-kit-bundle/` 下再跑 **7 ok 但 3 skip** · `md5sum` 四副本 **唯一值=1**(`a78810f7…`) · `bash package-dsh-plugin.sh --check` **rc=0** · `bash sync-hooks.sh --check` **rc=0** · `bash package-flow-kit.sh --validate` **rc=0(314 项/漏配 0)** · `diff -rq test/ flow-kit-bundle/test/` **无输出** · `soffice→pdfinfo` **24 页** · L-031 全仓锚点重扫。
**未**运行 `make check`（耗时长，按调用方约束）；其六门中的 5 门已由上列单点命令独立复现（缺 `make lint`，但 shellcheck 0.9.0 在位，且新增 `.bats`/`.specs/*.sh` 均在 `SCAN_EXCLUDES` 之外——见 R7）。

独立性声明：输入只含工件路径 + 只读复跑白名单，未见主 agent 自评/草稿/辩护文本。以下结论全部由本机实跑与读源码独立得出。

---

### 🔴 R1 · AC-11 的「每阶段 L3 段 + `.done`」在阶段 2/3/5 不存在，而 pipeline 账本仍停在阶段 1

**Severity**：🔴 Critical

**Symptom（症状）**：
- `.specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-{2,3,5}.md` 的 `^## L3` 计数 = **0**（IR-1 = 1）。IR-2 末条 verdict = `fail`（`:416` 区段），IR-3 末条 = `fail`（`:181`），IR-5 末条 = `fail`（`:156`）——**三阶段的 L2 最后一轮都是 fail，且此后无任何 L3 段**。
- `find .specs/user-guide-sync-2026-09b -name '.independent-review*'` → **零命中**；仅存 `.l3-attempts-1`。即 `AC-11 验证方式`（`REQUIREMENT.md:210`）逐字要求的 `ls .specs/<id>/.independent-review-*.done` 输出为空。
- `.flow-active`：`phase=1` · `goal.current_phase=1` · `gates={"0→1":"passed","1→2":"pending",…,"5→6":"pending"}` · `auto_advance=false`。**主管线尚未离开阶段 1**，而本审查已被按「阶段 6」发起。

**Source（源头）**：`REQUIREMENT.md:206`（AC-11 Then 第 1 条「每阶段 `INDEPENDENT-REVIEW-<N>.md` **必含 `## L2 盲审` 段**」+ 第 2 条「L3 段由 `l3_review_run` 产出（6 键 KVP `.done` + L3 段）」）；`REQUIREMENT.md:210`（验证方式 = `ls …/.independent-review-*.done` + 最后一轮 verdict 行）；`.flow-active.goal.gate_config`（`1-requirement`…`7-integration` 全 `both` → 每阶段 L2 **与** L3 双轨）。实现侧唯一合法生产者是 `l3_review_run`（`git HEAD:flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh:9-10`：「l3_review_run 写 .done 不被拦截」；`:123-127`：主 agent 直写 `.done` 被 path-guard deny，除非 `gate_config=L2`）。

**Consequence（后果）**：
1. 阶段 2/3/5 的 L2 末轮判 `fail` 之后，**没有任何独立（L3）复核**记录它们是否被真正处置——唯一的处置证据是主 agent 自写的「主 agent 响应」段，而该段正是 L2 协议要求被独立复核的对象（`L2-blind-review.md:140-144`）。这三个阶段的 toll-gate 事实未闭合。
2. 该缺口会**在阶段 7 变成硬阻塞**：`.done` 缺失 → PreToolUse review gate 对 `git commit` / 阶段切换 `exit 2 deny`（`independent-review-gate.sh:5-6`）；而主 agent 又不能自产 `.done`（path-guard）。不补 L3（或按 AC-11 的降挡口径留痕）就无法 commit 收口。
3. 本阶段（6-review）自身的前置不成立：账本 `current_phase=1`、`5→6 = pending`，故本轮 L2/L3 的 `phase` 解析、`.done` 落点与「阶段 6 双轨 pass」都站不住。

**Remedy（修补）**（二选一，二者都必须在 TEST/REVIEW 留痕）：
- (a) 正常路径：对阶段 2/3/5 逐阶段跑 L3（凭证可用时），产出 `## L3 盲审` 段 + `.independent-review-{2,3,5}.done`，再按 Host 协议推进账本；
- (b) 降挡路径（AC-11 已授权）：凭证不可用/超时/连续 fail 达阈值时，写入含 `l3-bypass` / `timeout` 锚点与 `L3_verdict=skipped` 的审计段，并把「降挡原因 + 重试方式（删 `.specs/<id>/.l3-attempts-<phase>` 后重跑）」显式记入 TEST.md/REVIEW.md。
两路径共同的前置：**先把 `.flow-active` 的 `phase`/`gates` 与真实阶段对齐**，否则阶段 6 的 `.done` 会被写到错误阶段或直接被 gate 判为未完成。

> 独立判据（不引用主 agent 自述）：IR-1 的 `.l3-attempts-1` + `## L3` 段证明「L3 机制在本机可用」，因此阶段 2/3/5 的缺失**不能**用「环境不可用」解释为已留痕降挡——`MINOR-DEFERRED.md` 与 TEST.md 均无对应降挡登记。

---

### 🟡 R2 · `guide_parity_report` 的修复指引方向写反：根副本漂移时它指挥用户去覆盖 bundle

**Severity**：🟡 Important

**Symptom（症状）**：`test/test_guide_copy_parity.bats:43-54`（`flow-kit-bundle/test/test_guide_copy_parity.bats` 逐字节同源）以 `ref="${present[0]}"` 取**数组第一项**为基准，而 `COPIES[0]` = 仓库根副本（`:23-28`）。当**根副本**是分叉方（即 AC-10 Given 记录的历史事故 `5583e2a` 形态：bundle 已改、根副本落后）时，循环打印的是：
`MISMATCH: flow-kit-bundle/FLOW-KIT-用户指南.md 🔴 dist/…` + `修复: cp flow-kit-bundle/FLOW-KIT-用户指南.md dist/…`，
—— **不会**提示 `cp flow-kit-bundle/FLOW-KIT-用户指南.md FLOW-KIT-用户指南.md`；而「bundle → 根」正是 `REQUIREMENT.md:126` 固定为唯一合法方向的同步边（「底稿 = `flow-kit-bundle/FLOW-KIT-用户指南.md`」）。

**Source（源头）**：`REQUIREMENT.md:126`（AC-5「同步方向显式固定：底稿 = bundle → 覆写根副本 → 窄路径 `cp` 到 dist 两份」）；`REQUIREMENT.md:193`（AC-10 修复命令按 target 类型给出的授权形态）。守护的**判等逻辑**与基准无关（md5 唯一值），故不影响召回；错的是**给人看的恢复动作**。

**Consequence（后果）**：下一次真漂移（根副本落后）时，执行者按打印出的命令操作 → 根副本**仍是旧内容** → 重跑仍红，修复指引本身制造一次额外绕行；若执行者反向理解成「以根为准」，会把旧内容覆盖回 bundle，直接制造新一轮静默漂移（本 change 存在的唯一理由）。爆得快慢取决于下次谁先跑 `make test` 并读 MISMATCH 段——即下一次改指南时。

**Remedy（修补）**：

```bash
# before（test_guide_copy_parity.bats:48-53）
ref="${present[0]}"
for f in "${present[@]:1}"; do
  if ! cmp -s "$ref" "$f"; then
    printf 'MISMATCH: %s 🔴 %s\n  修复: cp flow-kit-bundle/%s %s\n' "$ref" "$f" "$GUIDE_NAME" "$f"
  fi
done

# after —— 基准恒为「底稿 bundle 副本」，任何偏离底稿的副本都按 target 类型给命令
ref="$root/flow-kit-bundle/$GUIDE_NAME"
[ -f "$ref" ] || return 0
for f in "${present[@]}"; do
  [ "$f" = "$ref" ] && continue
  cmp -s "$ref" "$f" && continue
  case "$f" in
    */dist/*) printf 'MISMATCH: %s 🔴 %s\n  修复: cp flow-kit-bundle/%s %s\n' "$ref" "$f" "$GUIDE_NAME" "$f" ;;
    *)        printf 'MISMATCH: %s 🔴 %s\n  修复: cp flow-kit-bundle/%s %s\n' "$ref" "$f" "$GUIDE_NAME" "$f" ;;
  esac
done
```
（已装插件目录**不得**附 `cp` 建议——该边只允许 `make dsh-sync`，见 `REQUIREMENT.md:193`；用例 6 已按此口径单独报错，勿在 report 里回归。）

---

### 🟡 R3 · `flow-kit-bundle/test/` 那份守护在**自己的分发位置**退化为 3 skip + 1 条恒真比较

**Severity**：🟡 Important

**Symptom（症状）**：`REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"`（`test_guide_copy_parity.bats:20`）。在镜像位置执行时 `REPO_ROOT` = `flow-kit-bundle/`，实测 `npx bats test/test_guide_copy_parity.bats`（cwd=`flow-kit-bundle/`）：

```
ok 1 … md5 唯一值 = 1
ok 2 … # skip bundle 副本不存在
ok 4 … # skip pptx 不存在（未生成的 checkout）
ok 6 … # skip dist 缺席，无法比较 docs/FLOW-KIT-用户指南.md
```

- 用例 1：`present` = `flow-kit-bundle/FLOW-KIT-用户指南.md` 单项 → `guide_parity_ok` 在 `[ "${#present[@]}" -ge 2 ] || return 0` 处返回 0 → 它比较的是**一份文件与自己**（恒真）；`guide_parity_report` 同样零输出。用例 1 打印的 `NOTE: dist/ 缺席（fresh clone）…` 是与事实相反的说明。
- 用例 2 的 `bundle 副本不存在` 分支（`:80`）、用例 4 的 `pptx 不存在`（`:108`）、用例 6 的 `dist 缺席`（`:155`）在本位置**必然命中**——即 `flow-kit-bundle/test/` 这份镜像里，7 例中只有 3 例（夹具 3/5/7）在真正断言。

**Source（源头）**：`REQUIREMENT.md:196`（AC-10 Then：「断言落在 `test/test_guide_copy_parity.bats`（DESIGN D2）+ 同源镜像 `flow-kit-bundle/test/test_guide_copy_parity.bats`（`make test-sync` 产出），且**真的会被跑到**」）；`.specs/CONTEXT.md`（本轮新增术语「指南副本一致性」把 bundle 副本并列为**消费者可见载体**）。

**Consequence（后果）**：镜像文件是分发包的一部分、也会被用户/下游 checkout 直接跑；在那里它对「四副本一致」给出**空绿**（1 条自比 + 3 条 skip），而 AC-10 的守护域恰恰包含 bundle 副本本身。这不是「本仓门禁漏跑」（`make test` 只收 `test/`，已核实），而是**分发出的守护不具备它宣称的检测力**——与 `REVIEW.md §4 F1` 同型的「守护域声明 > 实际守护」。

**Remedy（修补）**：在文件头统一解析真正的仓库根，并在找不到时**显式失败**而不是静默降级：

```bash
# before（:20）
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# after —— 兼容「根 test/」与「bundle 镜像 test/」两种落点；两者都取不到真根则显式失败
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
if [ ! -f "$REPO_ROOT/FLOW-KIT-用户指南.md" ] && [ -f "$REPO_ROOT/../FLOW-KIT-用户指南.md" ]; then
  REPO_ROOT="$(cd "$REPO_ROOT/.." && pwd)"
fi
[ -f "$REPO_ROOT/FLOW-KIT-用户指南.md" ] || { echo "指南根副本不在 $REPO_ROOT —— 镜像被放到错误位置，拒绝静默 skip"; return 1; }
```
（`make test-sync` 会把同一份文件复制到两处，故修改需同步镜像——`check-test-sync` 会强制。）

---

### 🟡 R4 · 「`deck_checks.py` 已接进 `make test`」的 `Fixed in:` 声明在产物中不成立

**Severity**：🟡 Important

**Symptom（症状）**：`INDEPENDENT-REVIEW-2.md`（阶段 2 主 agent 响应，R23 行）声明：
`**Fixed in: `test/test_guide_copy_parity.bats` 新增用例 8 + TEST.md` | ① 把 `deck_checks.py` 的**全部**断言接进 `make test`（进而 `make check`）……当前 `deck_checks.py` rc=0、bats 8/8`。
产物事实：`test/test_guide_copy_parity.bats` = **7 个 `@test`**（`grep -c '^@test'`，文件 177 行），`npx bats` 输出 `1..7`；`grep -n 'deck_checks' test/test_guide_copy_parity.bats` **零命中**；`test/` 内也无其他文件引用 `deck_checks.py`。即：deck 成品断言（页数/封面日期/BANNED/关键串/标题寻址）**至今不在任何门禁的执行路径上**，`REVIEW.md §4 F1` 自己把「deck_checks 进 make check」列为 v2 候选（`REVIEW.md:66`），与其上游 `Fixed in` 声明互相矛盾。

**Source（源头）**：`L2-blind-review.md:107`（阶段 6 重点·**修代码优先**：`Fixed in:` 声明对应的文件必须真的在 diff 中）；`REQUIREMENT.md:196`（AC-10「验收以**行为**证明……不以『Makefile 里出现某字符串』这类文本判据代替」）。

**Consequence（后果）**：这是「已修复声明 vs 产物」的偏离（本仓 `verify-claims.sh` 的立身之本）：读者据此认为 deck 已有门禁，实际没有 → 下次只改 `slides.json` 正文/数值而不重建 pptx、或改 `deck_checks.py` 后忘记接线，都不会红。同时它把 `REVIEW.md §4 F1` 的「短期可加」说成已完成，掩盖了真实的守护缺口。

**Remedy（修补）**：二选一并同步文本——
- (a) 真接线：在 `test/test_guide_copy_parity.bats` 增 1 例，`cd "$REPO_ROOT" && python3 .specs/user-guide-deck-gen/deck_checks.py`（python-pptx 不可用则显式 skip 并打印原因），再 `make test-sync`；
- (b) 若本轮不做（`REVIEW.md` 已把该面列为 v2/M2）：把 IR-2 响应里的 `Fixed in:` 降级为 `Tech-debt: M2`，并在 `REVIEW.md §4 F1` 明确写「deck 成品断言当前**不在** `make check` 内」。
不得保留「声明已接、产物未接」的双口径。

---

### 🟡 R5 · 镜像位置的用例数/结果计数与实测不符，`REVIEW.md` 与 `TEST.md` 三处口径互相打架

**Severity**：🟡 Important

**Symptom（症状）**：同一变量在三处取三个值：
| 位置 | 文本 | 实测 |
|---|---|---|
| `REVIEW.md:23` | 「6 用例全绿」 | 文件 7 例、实跑 `1..7`（这是**待复核对象**本轮唯一失实的具体计数） |
| `TEST.md:35` | 「（6 用例）」、`TEST.md:312` | 7 例 |
| `TEST.md:134-145` | `1..6` … `ok 7 …`（自相矛盾）+「守护现在 7/7」 | `npx bats` → `1..7`；且 `TEST.md §5.3`（`:182`）仍写「test_guide_copy_parity.bats **6/6** ok」 |

**Source（源头）**：`L2-blind-review.md:105`（阶段 6 重点：对照 `REVIEW.md` 指出漏判/误判）；`REQUIREMENT.md` 各 AC 的「验证方式」均要求「实跑输出记入 TEST.md」。

**Consequence（后果）**：计数是可机械复算的量，一旦与环境不符，阶段 7 的 `verify-claims`（`make verify-claims`）会把整段响应标 ❌，浪费一轮往返；更实际的是掩盖了 R4 里「用例 8 是否存在过」这类问题——审阅者无法判断「8/8」是历史真值还是笔误。

**Remedy（修补）**：三处统一为 `7`（`REVIEW.md:23` 改写「7 用例全绿；用例 3/5/7 为夹具非恒绿 + 用例 4 曾在真实缺口变红」），并把 `TEST.md` 的贴入块按最后一次实跑**整段替换**（贴 `1..7` 全量输出，勿手工拼 `ok 7`）。

---

### 🟢 R6 · AC-4 · N3 的「六门」锚点集合未被断言矩阵覆盖（缺 `check-validate` / `check-test-sync`）

**Severity**：🟢 Minor

**Symptom（症状）**：`REQUIREMENT.md:106` 的 N3 正例锚点 = `check-dist` · `check-validate` · `check-hooks-sync`（三串均应 ≥1 命中）。`verify-ac.sh:159-163` 只断言 `check-dist` / `check-hooks-sync` / `verify-claims` / `make dsh-sync`；全文无 `check-validate`、无 `check-test-sync` 断言（`grep -c` = 0）。实测四份副本 `check-validate` 命中数均为 1（指南 `:949` 六门表第 3 行），故**当前为真**，仅判据缺失。

**Source（源头）**：`REQUIREMENT.md:106`（N3 锚点串枚举）+ `:118`（AC-4 验证方式「上表逐串 `grep -c` ≥1」）。

**Consequence（后果）**：下次改写六门表时把 `check-validate` 写丢，矩阵仍 86/0 全绿——锚点集合断言比 AC 表窄一档（与阶段 1 L2 R18 已修过的同类缺口同型）。

**Remedy（修补）**：在 `verify-ac.sh` AC-4 段补两行：
```bash
pos AC-4 "N3 check-validate"      'check-validate'
pos AC-4 "N3 check-test-sync"     'check-test-sync'
```
（并顺手确认 `make test`/`make lint` 两门是否也应入 N3 锚点——指南六门表把它们列为第 1/2 门且已在正文命中，属设计选择，非缺陷。）

---

### 🟢 R7 · `render-preview/` 的 24 张 PNG 早于其声称渲染的 pptx 36 分钟

**Severity**：🟢 Minor

**Symptom（症状）**：`render-preview/*.png` mtime = `09-21 22:19:26–28`；`flow-kit-用户指南.pptx` mtime = `09-21 22:30:58`（22:2x 的 `slides.json` 合法修订之后重建，见 `INDEPENDENT-REVIEW-2.md` 末段自述）。即 AC-7 的机检产物**不再对应终态 deck**。我独立复算的**口径部分仍成立**：`soffice --headless --convert-to pdf` → `pdfinfo` = **24 页** = `len(slides.json)`，PNG 24 张、尺寸唯一 `1067×600`、无纯白页（`PIL.getextrema` 全非空）。

**Source（源头）**：`REQUIREMENT.md:145`（AC-7 机检「PDF 页数 = PPT 页数；每页 PNG 尺寸一致且非纯白；产物落在 `.specs/user-guide-sync-2026-09b/render-preview/`」）。

**Consequence（后果）**：归档目录里留下的目视证据渲染的是**上一版** deck；下次有人拿它复核「封面日期/新专页排版」时会对错版本。不影响任何 AC 判定（页数/尺寸/非空由 pptx 侧独立成立）。

**Remedy（修补）**：重建 pptx 后按 `TEST.md §10` 的同一命令重跑 `soffice → pdftoppm`（幂等、约数秒），并把 mtime 晚于 pptx 作为 AC-7 的重跑判据写进 TEST.md §3.3。

---

### 🟢 R8 · `REVIEW.md §4 F4` 登记的两处 DESIGN 引用不实仍未清理（阶段 6 禁改，故只登记）

**Severity**：🟢 Minor

**Symptom（症状）**：`REVIEW.md:58` 自述「DESIGN §7 证据链两处引用不实（`Makefile:6` 空行等）」并写「阶段 7 归档前顺手清理」。实测两处**都还在**：
- `DESIGN.md:218` 的「所有引用到的既有文件（… `Makefile:6`）均已 `grep`/`read` 验证存在」→ `Makefile:6` 是**空行**（`.PHONY` 在 `:5`，`check:` 六门在 `:106`），该句的「已验证存在」不成立；
- `DESIGN.md:86` 的「守护域与 `Makefile:136-137` 的 `DSH_PROFILE ?= web` 同源」→ 实测 `Makefile:133-134` 才是 `DSH_PROFILE ?= web` / `DSH_PLUGIN_DIR`（`:136-137` 是 `dsh-sync` 的 `echo` / `if`），即 `MINOR-DEFERRED.md` M10 记的「第三处本轮已顺手修正」**在产物中未生效**。

**Source（源头）**：`L2-blind-review.md:37`（🟢 Minor → 写 `MINOR-DEFERRED.md`，不入 fix loop）；`L-031`（证据链引用需可复算）。

**Consequence（后果）**：仅影响后续读者按行号复查 DESIGN（`DESIGN.md:218` 那句「已验证存在」会让读者跳过复查），不阻塞任何门禁。

**Remedy（修补）**：阶段 7 归档前把这两处行号按实测改写（`Makefile:6` → 删掉该引用或改 `Makefile:106`；`Makefile:136-137` → `:133-134`），或统一改为「见 `Makefile` 的 `check:` / `dsh-sync` target」这种不写死行号的指法（与 AC-1 的 R26 口径一致）。已有 M10 跟踪，但 M10 描述与实测不符（称第三处已修），需一并订正。

---

## 6 维衰退风险（B 维度）与本轮新增物

| 维 | 观察（本轮实跑） | 判定 |
|---|---|---|
| **R1 认知过载** | 指南 +184/−123（`flow-kit-bundle/FLOW-KIT-用户指南.md`），新增 2 个自成一体的 H3 节；deck 24 页标题全部可按标题寻址 | 🟢 无新增结构债 |
| **R2 变更传播** | 事实源 = 4 份 md + `dist` 镜像 + deck + 2 份 README；本轮把 root↔bundle 边纳入 `make test`（`check-test-sync` 保证镜像同源，我已复算 `diff -rq` 空） | 🟡 见 R3/R4：**deck 面仍无门禁**、镜像副本检测力不足 |
| **R3 知识重复** | 与上同源；本轮的收益是「副本层」被机械化，代价是新增第 3 份比较逻辑实现（`guide_parity_ok` + `guide_parity_report` + 同名镜像） | 🟡 三份副本各存一份逻辑（`test/`、`flow-kit-bundle/test/`、`dist/…/test/`），靠 `check-test-sync` 约束；可接受，但 R2/R3 的修补**必须双改** |
| **R4 偶然复杂** | `deck_checks.py` 由位置索引 `items[13]/items[19]` 改为 `by_title[...]` 寻址 + 重复标题自检（`assert len(by_title) == len(items)`）——真实降耦 | 🟢 改善 |
| **R5 依赖混乱** | 无新依赖（python-pptx 1.0.2 / LibreOffice 24.2 / pdftoppm / npx bats 均在位） | 🟢 |
| **R6 领域扭曲** | 术语与实现一致面抽查通过：`单轮合并审查`、`max_artifact_bytes 80000`、六门表 = `Makefile:106`（`test lint check-validate check-test-sync check-hooks-sync check-dist`）、`17 个 flow-*`（实测 `ls flow-kit-bundle/skills \| wc -l` = 17）、`--sub-goal-<n>` 不存在（实测实现只认 env `SUB_GOAL_4..7`） | 🟢（范围外残留在 M8 留痕） |

**L-031 独立全仓锚点扫描**（不信 DESIGN §0.5.1 清单；锚点 = 本轮改动涉及的旧口径串）：

| 锚点 | 本 change 声明域（指南四副本 + deck + 2 README） | 声明域外命中 | 判定 |
|---|---|---|---|
| `三轮审查` | 0（四副本 + deck 双查：pptx 文本与 `slides.json` 源） | `flow-kit-bundle/skills/flow-review/SKILL.md`、`flow-kit-bundle/flow-kit/README.md`、`templates/REVIEW.md` | 🟢 与 M8 一致（**范围外**，AC-9 冻结 `skills/**` 与 `prompts/**`；已登记跟进 change） |
| `2026-07-13` / `20260713` | 0（四副本；bats 里的命中是**断言字面量**，非文档内容） | `tools/pptx-light-sync.py:3,63-64` | 🟢 范围外（AC-9 白名单不含 `tools/`；该脚本是硬编码路径的一次性迁移脚本，IR-2 R22 已登记 `MINOR-DEFERRED M16`） |
| `.specs/lessons/` | 0（四副本） | 无 | 🟢 |
| `核心引擎 + skills + brooks-lint + hooks` | 0（四份） | 无 | 🟢 |
| `ARCHIVE.md` | 0（四副本；`slides.json` 亦 0，仅允许 `ARCHIVE-MANIFEST.txt`） | 无（`.git/index` 命中属版本库元数据） | 🟢 |

**独立复核结论（与 `REVIEW.md` 的对照）**：

- **主 agent 漏判**：`REVIEW.md` 未登记 R1（阶段 2/3/5 无 L3 段、无 `.done`、账本仍在阶段 1）。`REVIEW.md:24` 只写「AC-11 … 见本阶段与阶段 7」，`§6` 据此仍判 **pass**——但 AC-11 的 `.done` 与阶段 2/3/5 的 L3 段是**本轮就能核**的产物，不是「阶段 7 才可核」。这是本次 pass 判定唯一站不住的支撑点。
- **主 agent 漏判**：`REVIEW.md §4` 四条发现全部是记录型/范围外，**没有一条**指向本轮新写代码的缺陷——而 R2/R3（修复指引方向、镜像恒真比较）都落在本轮新增的 `test_guide_copy_parity.bats` 内，且 R3 恰好是 `REVIEW.md §2 R2 行`自称「已收敛」的那条边的守护。
- **主 agent 误判（轻量）**：`REVIEW.md:23`「6 用例全绿」（实测 7）；`REVIEW.md §4 F3` 记「Fixed in: T05（README 同步）」——`.specs/user-guide-deck-gen/README.md` 确在 diff 内（`:1` 版本行、`禁词` 段、页数断言段），此项**成立**，与我独立复核一致。
- **独立同结论项**（我先实跑后比对，非抄录）：四副本 md5 唯一值 = 1（`a78810f7…`）；`check-dist` rc=0；AC-9 白名单逐条 ⊆ 且禁动域 diff = 0；`deck_checks.py` rc=0（24 页 + BANNED 双查 + `by_title` 24 标题可寻址）；`verify-ac.sh` 86/0；`/usr/bin/time -f %e md5sum 四路径` **0.00s ×3**（NFR < 1s，独立复算；与 TEST.md §6 的 0.00s 口径一致）。
- **未能独立复核项（如实声明）**：`make check` 整体（按约束未跑；六门中 5 门已单点复现，仅 `make lint` 未跑）；AC-7 的人工目视半段（「文字溢出/CJK 缺字」无自动判据，M1 已登记）。

**Verdict**: fail
（依据：R1 = 🔴 Critical —— `REQUIREMENT.md:206-210` 的 AC-11 在阶段 2/3/5 未实现，且 `.flow-active` 账本与「阶段 6」不符。R2–R5 为 🟡，按 Severity Gating 入 fix loop/task 内解决；R6–R8 为 🟢，落 `MINOR-DEFERRED.md`。）

---

## 主 agent 响应（阶段 6 · L2 首轮 R1–R8 · 2026-09-21）

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R1 | 🔴 | **Fixed in: 逐阶段补 L3（已执行 2 个）+ `.flow-active` 账本对齐** | ① **阶段 1**：Stop hook 曾自动跑过 L3，但重审因 artifacts hash 变更判 fail（1 critical + 5 major + 2 minor）→ 已按 Remedy 逐条修 REQUIREMENT（D26 反例改段落级、D37/D38 明示「八串都要命中」、N10/N11 补后果句字面串、AC-6 固定四张专页标题+关键串、AC-7 改 4 张、兼容性 NFR 补 AC 落点 N13、D33 表外给未转义原文、AC-10 去写死行号）→ 重跑 L3 **pass**，`.done` 已写；② **阶段 2**：L2 第四轮 pass → `run-l3.sh 2` **pass**，`.done` 已写；③ **阶段 3/5**：L2 尚在 fix loop（本轮已派第四/三轮回审），通过后立即跑 L3；④ 账本已从 `phase=1` 推进到 **`phase=3`**（`phases_done=["0","1","2"]`、`gates 1→2 / 2→3 = passed`） |
| R2 | 🟡 | **Fixed in: `test/test_guide_copy_parity.bats` `guide_parity_report`** | 基准恒取 **bundle 底稿**（唯一维护源）：`ref="$root/flow-kit-bundle/…"`，根副本漂移时给出的修复命令方向正确（`cp <bundle> <根副本>`） |
| R3 | 🟡 | **Fixed in: 同一文件（`resolve_repo_root` + `setup()`）** | 仓库根按标记文件逐级上溯解析（兼容仓库根与 `flow-kit-bundle/test/` 两种落点）；**解析失败即显式失败**（不静默降级成"自己与自己比较"）。实测：从 `flow-kit-bundle/test/` 运行 **8/8 ok**；把标记改成不存在的文件后 **全部 not ok**（显式失败） |
| R4 | 🟡 | **已成立（时点差）** | 你的快照（22:33–22:34）早于我加用例 8（22:35）。当前文件有 **8 个 `@test`**，用例 8 直接调用 `.specs/user-guide-deck-gen/deck_checks.py` 并把 **title 级内容一致性**接进 `make test`；注入实测（改第 21 页标题 → `not ok` / `MISSING: …` → 还原复绿）。与 M2 不冲突：**未新增 Makefile target** |
| R5 | 🟡 | **Fixed in: TEST.md / UAT.md / REVIEW.md 全量计数回填** | 以实跑为准统一为：`verify-ac.sh` **103 通过 / 0 失败**、集合断言 **35 单元格 / 0 缺失**、`test_guide_copy_parity.bats` **8/8**；`UAT.md` 同步回填并把人工 triage 范围改为 **M1–M18** |
| R6 | 🟢 | **Fixed in: `verify-ac.sh`（N3 两条 + N10/N11 后果句 + N13 三平台）** | 你指出的 N3 缺口已补（`check-validate` / `check-test-sync`），并顺带补齐 N10 `前轮反馈`、N11 `不可信`、N13 三平台路径；通过数由 86 → **103** |
| R7 | 🟢 | **Fixed in: `render-preview/` 全量重渲** | 已删除并按**终态 pptx**（22:30:58）重新渲染 24 张 PNG（22:36:45），`pdfinfo` 页数 = 24 = pptx 页数 |
| R8 | 🟢 | **Fixed in: `DESIGN.md` 两处 + MINOR-DEFERRED M10 订正** | `Makefile:136-137` → **`:133-134`**（`DSH_PROFILE ?= web` 行）；`Makefile:6`（空行）→ **`:106`**（`check:` 依赖行）；M10 描述已按实测订正 |

**对 REVIEW.md 判定**：接受你的「主 agent 漏判 R1/R2/R3/R4」——REVIEW.md 是在这些产物（用例 8、L3 链路、账本对齐）落地前写的，其时点声明不足；本轮把上述每一项都落到产物后重跑。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-21 23:31）

> 自动生成于 2026-09-21 23:31。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": ".specs/CHANGELOG.md",
      "issue": "历史行被意外篡改：2026-06-10 fix-brooks-bundle-full 条目中的 '(1) installed_plugins.json 写 CC v2 格式' 被改为 '写 CC v59 检查格（跳过 21）式'，语义不通，明显是批量替换误伤。",
      "why": "破坏历史记录准确性，且此错误出现在本次变更的 diff 中，说明变更过程中存在文本替换未保护历史行的流程漏洞（与 L-105 同类）。",
      "fix": "恢复该行为 'CC v2 格式'，并在批量替换流程中强制排除历史 CHANGELOG 行或使用结构化编辑。"
    }
  ],
  "minor": [
    {
      "file": ".specs/user-guide-deck-gen/deck_checks.py",
      "issue": "版本号 'v0.2.0' 硬编码在断言中，未来插件版本升级会导致断言失败且需要同步修改。",
      "why": "版本号是外部事实，不应作为断言锚点；若版本未同步更新，可能出现假红。",
      "fix": "考虑从 package.json 读取版本号而非硬编码。"
    },
    {
      "file": ".specs/user-guide-deck-gen/README.md",
      "issue": "禁词列表新增的 '项目级 stop-hook.json' 与 slides.json 中的 '项目级配置' 可能被误匹配？实际未匹配。但 README 中的禁词列表与 deck_checks.py 的 BANNED 列表存在重复维护，容易遗漏。",
      "why": "同一份禁词列表在 README 和 Python 中各写一份，若日后变更需同步两处。",
      "fix": "将禁词列表单一源化，由 deck_checks.py 从 README 或单独配置文件读取。"
    }
  ],
  "verdict": "pass",
  "summary": "工件整体实现与文档同步基本一致，新增的 deck 断言与 slides.json 匹配，但 CHANGELOG 历史行被意外篡改属于文档破坏，需修复；无 critical 问题。"
}
```

L3_artifact_hash: ae510e3bb220a8c5400f1b308d58f1b18e94d08b96624c9ecf8cbef7b20abd39

<!-- /L3-SECTION -->
