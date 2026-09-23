# T10-SUMMARY — AC-7(b)：`test_independent_review_model.bats` 先断言文件存在 + `test_lessons_cleanup.bats` 去过期 skip

- **Change ID**: health-fix-2026-09b
- **Task**: T10（阶段 4 · DEV）
- **完成日期**: 2026-09-23
- **执行模型**: standard（MODEL-TIER hint）
- **成果**：AC-7「四假绿不再假绿」中的两处 —— ①`test_independent_review_model.bats` 的两条反向断言（AC-9 + stop-hook.json）在断言前先 `[ -f ]` 判被检文件存在，消除「文件缺失 ⇒ 反向断言恒真」；②`test_lessons_cleanup.bats` 的 AC-4 测试**去过期 skip** 并断言 `exit 0`。双源逐字同步。

---

## 1. 做了什么

### ① `test/test_independent_review_model.bats`：两条反向断言前补「文件存在」守卫

- **AC-9 测试（@test "AC-9: AUTH_TOKEN only in assignment and curl header, not in echo/module_output"）**：在既有两条反向 grep 断言（`[ "$status" -ne 0 ]`）之前，新增
  ```bash
  [ -f "$HOME/.claude/hooks/stop/29-independent-review.sh" ]
  [ -f "$HOME/.claude/hooks/stop/30-ai-analyze.sh" ]
  ```
  消除「文件缺失 ⇒ 两条反向断言恒真为绿」的假绿。
- **stop-hook.json 测试（@test "stop-hook.json still has plain model string (not env var placeholder)"）**：在 `model_val=$(jq -r '.ai.model' "$HOME/.claude/stop-hook.json")` 之前新增
  ```bash
  [ -f "$HOME/.claude/stop-hook.json" ]
  ```
  消除「stop-hook.json 缺失 ⇒ `run bash -c "echo '$model_val' | grep -c '^\\$'"` 反向断言恒真」的假绿。
- 两处均按**测试名/文件内锚点**定位，不依赖漂移行号。

### ② `test/test_lessons_cleanup.bats`：AC-4 测试去过期 skip 并断言 `exit 0`

- **按测试名引用**（`AC-4: 模拟全量覆盖场景下 --validate exit = 0`），不引行号。
- 移除原 `skip "AC-4 需要全量覆盖环境；当前仓库已知有 gap，exit=1 是正确的"`（原 gap 已在此前修复，实测干净态 `--validate` exit=0 ⇒ 属「过期 skip」）。
- 替换为唯一可机器验证分支：
  ```bash
  source "$(pwd)/flow-kit-bundle/lib/validate_staging.sh"
  run validate_staging_coverage "$TEST_ROOT/flow-kit-bundle"
  echo "AC-4 validate exit=$status" >&3
  echo "AC-4 validate tail: $output" >&3
  [ "$status" -eq 0 ]
  ```
  - 显式传临时 bundle 目录（`$TEST_ROOT/flow-kit-bundle`，AC-4 测试段已构造的全量迷你 bundle），不触碰真实 `flow-kit-bundle/`。
  - `source` 直接测试 SUT 的 `validate_staging.sh`（干净态 `--validate` exit=0 已实测，工具自报期望覆盖 308 / 实际 314 / 漏配 ERROR=0 / 源缺失 WARNING=0）。

### 双源

`test/` ↔ `flow-kit-bundle/test/` 两份同名 bats 逐字同步（`cp` 后 `cmp` 校验一致）。

## 2. 改了哪些文件

| 文件 | 改动 |
|---|---|
| `test/test_independent_review_model.bats` | AC-9 测试 +5 行守卫；stop-hook.json 测试 +2 行守卫 |
| `test/test_lessons_cleanup.bats` | AC-4 段：`skip` 行替换为 source+run+断言 exit 0（+10/−3） |
| `flow-kit-bundle/test/test_independent_review_model.bats` | 与 `test/` 逐字一致 |
| `flow-kit-bundle/test/test_lessons_cleanup.bats` | 与 `test/` 逐字一致 |

**未改动**：`package-flow-kit.sh`（只读）、产品代码、其他 `test`/`flow-kit-bundle` 文件。

## 3. verify 真实输出

判据按主 agent 授权做了两处**改写**（理由见 §5），落地为 `/tmp/t10v.sh`。`bash -n` rc=0，实跑 rc=0，关键输出如下：

```
═══ [T10-1] 健康态（沙箱内文件齐全）应绿 ═══
✅ 健康态绿 (rc=0)
═══ [T10-2] 沙箱内删掉被检文件 29 ⇒ 该 bats 必红且给 file:line ═══
删除后 rc=1（期望非 0 = 红）
not ok 7 AC-9: AUTH_TOKEN only in assignment and curl header, not in echo/module_output
not ok 10 API fallback: 29 script sources l3-review.sh shared lib (pipeline-fallback-fix: 迁移到共享lib)
✅ 删除被检文件后必红且给出 file:line
═══ [T10-3] 还原 → 健康态仍绿 ═══
✅ 还原后绿 (rc=0)
═══ [T10-4] AC-4 段存在性前置（防 sed 无匹配静默通过） ═══
✅ AC-4 测试段存在
✅ AC-4 测试段无真 skip
═══ [T10-5] 产品 --validate 干净态 exit=0 ═══
   ✅ 校验通过：所有文件均被 Part A~G 覆盖。
✅ --validate exit=0
═══ [T10-6] 双源逐字一致 ═══
✅ 双源逐字一致（两份 bats 各含 bundle 镜像）
═══ 🎉 T10 verify 全绿 ═══
rc=0
```

红态 `file:line` 精确输出（`t10_red.out`）：
```
not ok 7 AC-9: AUTH_TOKEN only in assignment and curl header, not in echo/module_output
# (in test file test/test_independent_review_model.bats, line 83)
#   `[ -f "$HOME/.claude/hooks/stop/29-independent-review.sh" ]' failed
not ok 10 API fallback: 29 script sources l3-review.sh shared lib (pipeline-fallback-fix: 迁移到共享lib)
# (in test file test/test_independent_review_model.bats, line 128)
#   `[ "$status" -eq 0 ]' failed
```
> 注：`not ok 10`（line 128）是被检 29 文件缺失时 `grep` 类断言的崩溃，属反向断言对「文件存在」的**第二重非恒真证据**（独立于新增守卫）。

## 4. L-119/L-120 双态对照证据（必做）

| 态 | 驱动 | 结果 | rc |
|---|---|---|---|
| 健康态（沙箱 HOME 文件齐全） | `HOME=$sbx npx bats test/test_independent_review_model.bats` | **12 ok / 0 not ok** | 0 |
| 红态（沙箱内 `rm` 29 副本，不碰真实 HOME） | 同上（HOME 沙箱内删除） | **10 ok / 2 not ok**（AC-9 + API fallback，均给 file:line） | 1 |
| 还原态（重新复制 29 进沙箱） | 同上 | 12 ok / 0 not ok | 0 |

**关键点**：红态在**沙箱 HOME** 内验证，`rm` 副本而非 `mv` 真实 29 脚本 —— 真实 `$HOME/.claude/hooks/stop/29-independent-review.sh` 是本机**正在运行的 Stop hook（L3 门禁）**，全程未被移动/修改（见 §5/①）。

**AC-4 锚定 skip 检查双态**（见 §5/② 的锚定形态）：
- 注入态：往 AC-4 段临时加 `skip "临时注入"`（用 `/tmp/ac4_scratch.bats` 副本注入，不改工作区）⇒ **锚定检查抓到**（红）。
- 还原态：工作区原文件 ⇒ AC-4 段无 `skip`（绿）。
- 前置 `grep -q 'AC-4: 模拟全量覆盖场景下 --validate exit = 0'`：确认锚点存在，防 sed 无匹配静默通过。

## 5. 反向对照（L-123：非「无命中即绿」构造性假绿）

**改前旧断言为何恒真（已被实验证实）**：改造前仅在临时迷你 bata 副本中观测到 —— 文件存在与文件缺失两态下，反向 grep 断言 **均判 ok**（两态同为绿）⇒ 对「文件存在与否」无判定力，是构造性恒真。改造后：
| 证据 | 内容 |
|---|---|
| A | 健康态 rc=0（12 ok）vs 删除 29 后 rc=1（2 not ok）——两态结果不同 ⇒ 非恒真（恒真则两态必同） |
| B | `[ -f 29 ]` 两态求值：文件存在 ⇒ **TRUE**，文件被删 ⇒ **FALSE**（机器 echo `true`/`false` 实测两值不同）⇒ 断言对文件存在性有判定力 |
| C | 改前 minibats 两态同为绿（恒真）；改后文件缺失 ⇒ not ok 7 红（见 §3 输出）——新形式**能区分**两态 |

**无 `|| true` 兜底**：verify/测试均未使用任何兜底兜绿；红态是真实失败（断言返回非 0），非被吞掉。

## 6. 越界检查（R6.5）

`git status --porcelain` + `ls-files -o --exclude-standard` 仅列出本次 4 个目标 files 的改动（`test/`×2 + `flow-kit-bundle/test/`×2）。仓库中另有的 `.specs/CONTEXT.md`/`.specs/LESSONS.md`/`.specs/STATE.md` 改动与若干未跟踪 `.specs/health-fix-…` 档**非本次范围**（其他任务/归档产物），**不纳入本 commit（不 git add）**。提交仅含 4 个目标 bats。

## 7. 沿用了哪些既有抽象（R6.4）

- `validate_staging_coverage`（`flow-kit-bundle/lib/validate_staging.sh`）—— 直接测试 SUT 真实抽象，不用 mock。
- bats `setup()`/`teardown()`（`TEST_ROOT=$(mktemp -d)` + `rm -rf`）—— 沿用既有夹具生命周期，不新增约定。
- 测试名（AC-9 / AC-4 / stop-hook.json）—— 按名引用，不依赖行号（抗 L-125 漂移）。

## 8. 两条主 agent 授权判据改写（记录偏离与理由）

> 任务 §4 明示：按下面执行并在 SUMMARY 记录偏离与理由。

**① 不得对真实 `$HOME` 执行 verify 的 `mv "$F" "$F.zz-bak"`（VERIFY 偏离）**
- **原 XML 动作**：`mv "$HOME/.claude/hooks/stop/29-independent-review.sh" "$F.zz-bak"` 临时移走再移回，以制造「文件缺失」红态。
- **偏离**：改为 **HOME 沙箱** —— `sbx=$(mktemp -d)`；`mkdir -p "$sbx/.claude/hooks/stop"{,/lib}` 与 `"$sbx/.claude"`；把真实 `29-independent-review.sh`、`30-ai-analyze.sh`、`lib/l3-review.sh`、`lib/l3-api.sh`、`stop-hook.json` **复制**进沙箱对应路径；用 `HOME="$sbx" npx bats …` 驱动；「删被检文件必红」在沙箱内 `rm` 副本验证；`trap 'rm -rf "$sbx"' EXIT` 收尾。
- **理由**：真实 29 脚本是本机**正在运行的 Stop hook / 当前流水线的 L3 门禁**；若在两个 `mv` 之间被中断（kill/断电/pre-commit 钩子并发），则永久移走运行中门禁 → **全机门禁损坏**。沙箱方案句间风险窗口为 0，且**判据语义完全保留**（文件缺失 ⇒ 反向断言必须变红，见 §4 红态 rc=1）。
- **验证不触碰真实 HOME 的机器证据**：`mv` 从未执行；verify 全程用 `$sbx/.claude/...` 路径；`trap EXIT rm -rf "$sbx"`（无残留）。

**② skip 检查不得用裸 `grep -q 'skip'`（VERIFY 偏离）**
- **原 XML 动作**：`… | grep -q 'skip' && { echo "🔴 AC-4 测试仍含 skip"; … }`。
- **偏离**：改为**行级锚定形态**（且保留 XML 的 AC-4 存在性前置断言）：
  ```bash
  AC4=$(sed -n '/AC-4: 模拟全量覆盖场景下 --validate exit = 0/,/^}/p' test/test_lessons_cleanup.bats)
  grep -q 'AC-4: 模拟全量覆盖场景下 --validate exit = 0' <<<"$AC4" || { echo "🔴 AC-4 测试段不存在"; exit 1; }
  echo "$AC4" | grep -qE '^[[:space:]]*skip([[:space:]]|$)' && { echo "🔴 AC-4 测试仍含真 skip"; exit 1; }
  ```
- **理由**：AC-4 段去 skip 后我已在注释里书面解释「原过期 skip 已移除」（见 §1/② 的注释块），裸 `grep -q 'skip'` 会把**注释里的字样**读成残留 skip ⇒ **假红**（L-125 同族）。行级锚定 `^[[:space:]]*skip([[:space:]]|$)` 只匹配真实 `skip` 调用形态，不匹配注释文本。
- **反假红机器证据（§4）**：AC-4 段含「原过期 skip」注释仍为绿；注入真 `skip "临时注入"` 才红。

## 9. TDD 声明

本任务是**测试侧加固**（消除假绿），非新增产品功能，**没有新的产品代码可实现**，故不套用常规「先红后绿」的开发循环；等价的红→绿如下：
- **RED（改前）**：①旧反向断言在文件缺失时**仍绿**（恒真假绿，§5/C 已用 minibats 证实）；②AC-4 被 `skip` 从未真跑。
- **GREEN（改后）**：新守卫使文件缺失 ⇒ 该测试**真红**（§4），彻底移除恒真；AC-4 取消 skip 后 `run validate_staging_coverage` 干净态返回 exit 0（§3 T10-5），断言 `[ "$status" -eq 0 ]` 通过。
- 被测集成（`validate_staging_coverage` / 产品 `package-flow-kit.sh --validate`）**不修改**；本测试变更不引入新可测试的产品行为。

## 10. 质量门禁（默认环境）

- `make test`（`npx bats test/ --formatter tap`）：**973 ok / 0 not ok / rc=0**（计数 `grep -cE '^ok [0-9]+'` = 973；`grep -cE '^not ok'` = 0）。
- `make check-test-sync`：**rc=0**（`✅ test 双源一致`）。
- pre-commit：自然跑绿（无 `--no-verify`、无环境变量覆盖）。
- `make check-dist`：**预期为红（待 T24 收口），未修、未据此判失败**。

## 11. 遗留 / 说明

- AC-4 测试段仍保留改前那段关于 `BUNDLE_DIR` override 策略的死注释/`local tmp_script`/`cp` 脚手架（被 skip 掩盖时即存在）。它在测试现在真跑时算轻微 dead code，但**非 T10 目标**，且无害（`TEST_ROOT` 由 teardown 清理、未用变量不影响断言）——留给后续 cleanup task，避免 T10 越界。
- `.specs/CONTEXT.md`/`LESSONS.md`/`STATE.md` 的改动与未跟踪归档档非本次提交范围，未纳入 commit。
- 双源同步在 `make check-test-sync` 之外另经 `cmp` 逐字确认。

## 12. 6 维自查（R1–R6）

- **R1 认知过载**：两处守卫均为单行 `[ -f ]`，测试函数体未超 50 行、嵌套未增 ⇒ ✅
- **R2 变更传播**：写面严格封闭，仅 4 个目标 bats + 可写 spec 档；`git add` 仅 4 个 bats ⇒ ✅
- **R3 知识重复**：无跨文件重复逻辑块新增 ⇒ ✅
- **R4 偶然复杂**：守卫最小化、无 `|| true`、无兜底；AC-4 收敛为单一可机器验证分支 ⇒ ✅
- **R5 依赖混乱**：`source validate_staging.sh` 直测 SUT 真实抽象，无 mock/依赖反转新增 ⇒ ✅
- **R6 领域扭曲 / R6.4 / R6.5**：按测试名引用不引行号；沿用具名测试抽象；无越界改动 ⇒ ✅