# T13-SUMMARY — AC-6 前置（D10′①）：工件脱敏（真实账号绝对路径 → `/home/<acct>/` 等）

- **状态**：DONE（文档脱敏完成；verify 判据双态实测 rc=1 → rc=0；门禁全绿）
- **修复后成果**：授权面外命中 = 0（tracked + 未 tracked 两面均已扫描）；真实账号路径在本 change 工件与台账中 **0 处残留**（独立复扫佐证）。

## 一、任务理解

本 task 是 AC-6 基线冻结的前置步骤（D10′ 排序①「工件脱敏必须先于基线冻结」）：把本 change 工件与同批健康档中**真实账号绝对路径**（本机 `/home/<acct>/…` 形态，此处已 de-shape）替换为不命中 AC-6 检测 pattern 的脱敏占位（`/home/<acct>/` / `$HOME` / `<repo>` 形态）。判定口径（排除表 + `$FACE` 授权面）来自 T13 verify，权威副本仅存在于工件一处。

## 二、边界复述

- **静态写面**（精确路径，本 task 实际落笔）：`.specs/health-fix-2026-09b/DESIGN.md`、`.specs/health/2026-09-22-FULL-SWEEP.md`、`.specs/health-fix-2026-09b/T04-SUMMARY.md`、`.specs/health-fix-2026-09b/T11-SUMMARY.md`（③b SUMMARY 面）。
- **条件写面**（④，未触发额外写入）：仅当复扫命中 `$FACE` 中其他类工件（REQUIREMENT/CHANGE/MINOR-DEFERRED/TASK、各 task 的 `T*-SUMMARY.md`、`.specs/health/*.md`、`.specs/adr/*.md`）时才允许就地脱敏。
- **契约边界（零写入）**：`INDEPENDENT-REVIEW-{1,2,3}.md` 审查员原文受协议禁改，由 D10′② 排除表逐条精确路径豁免（存量 40 行 = IR-1 22 + IR-2 18）。本 task 对审查档 **0 处写入**。
- **当面外命中**（代码/测试/门禁本体、禁动清单内、其他健康档/台账之外）：**停止、不就地修改**，上报 file:line + 判断。本次**未出现**面外命中（见 verify 双态）。
- 未触碰 `.specs/CONTEXT.md` / `.specs/LESSONS.md` / `.specs/STATE.md`（不在写面）。

## 三、改动清单（file:line → 替换后；只做路径字面替换，不涉 rc/命令/输出/数字/判据/AC 语义）

| 文件:行 | 替换前（真实账号路径，已 de-shape） | 替换后 |
|---|---|---|
| DESIGN.md:215 | `HOME=<acct>` fixture 字面（字面 `/home/<acct>` 曾命中 PAT） | `HOME=/home/<acct>`，`~ ⇒ /home/<acct>`，`~/x.sh ⇒ /home/<acct>/x.sh` |
| T04-SUMMARY.md:297 | `源: /home/…/unisoc/flow-kit/flow-kit-bundle/hooks` | `源: <repo>/flow-kit-bundle/hooks` |
| T04-SUMMARY.md:300 | `✅ /home/…/.claude/hooks` | `✅ $HOME/.claude/hooks` |
| T04-SUMMARY.md:301 | `✅ /home/…/unisoc/flow-kit/dist/dsh-flow-kit/hooks` | `✅ <repo>/dist/dsh-flow-kit/hooks` |
| T04-SUMMARY.md:302 | `✅ /home/…/unisoc/flow-kit/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks` | `✅ <repo>/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks` |
| T04-SUMMARY.md:303 | `✅ /home/…/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` | `✅ $HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` |
| T04-SUMMARY.md:304 | `✅ /home/…/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks` | `✅ $HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks` |
| T04-SUMMARY.md:305 | `✅ /home/…/.config/opencode/hooks` | `✅ $HOME/.config/opencode/hooks` |
| T04-SUMMARY.md:314 | `/home/…/.claude/hooks/stop/lib/l3-prompt.sh  1` | `$HOME/.claude/hooks/stop/lib/l3-prompt.sh  1` |
| T04-SUMMARY.md:316 | `/home/…/.config/opencode/hooks/stop/lib/l3-prompt.sh  1` | `$HOME/.config/opencode/hooks/stop/lib/l3-prompt.sh  1` |
| T11-SUMMARY.md:56 | `== [T11 verify] path=/home/…/unisoc/flow-kit/flow-kit-bundle/hooks/pre-push/pre-push.sh ==` | `== [T11 verify] path=<repo>/flow-kit-bundle/hooks/pre-push/pre-push.sh ==` |
| FULL-SWEEP.md:126 | `→ /home/…/unisoc/flow-kit/` | `→ <repo>/` |
| FULL-SWEEP.md:242 | 符号链接指向仓库外 `/home/…/.claude/hooks/pre-commit/pre-commit.sh` | `$HOME/.claude/hooks/pre-commit/pre-commit.sh` |
| FULL-SWEEP.md:255 | `cd /home/…/unisoc/flow-kit || exit 1` | `cd <repo> || exit 1` |

> 上表 `…` 代指被缩减的真实账号路径（原样为本机账号绝对路径，按 L-129 前向规则 de-shape）。替换原则：`<repo>` = 仓库根（原 `…/unisoc/flow-kit/`），`$HOME` = 家目录（原 `…/.claude/`、`…/.dsh/`、`…/.config/`），`/home/<acct>/` = 自造 fixture 中的家目录字面（原为 `test`），此处以 `<acct>` 占位以不命中 PAT。`rc`、命令文本、输出数字未被改动。

## 四、verify 双态真实输出（判据从工件 TASK.md T13 原样抽取，L-128）

从工件抽取并原样执行：

```
flow-kit-bundle/flow-kit/scripts/task-brief .specs/health-fix-2026-09b/TASK.md T13 \
 | awk '/^  <verify>$/{f=1;next} /^  <\/verify>$/{f=0} f' > /tmp/t13v-artifact.sh \
 && bash -n /tmp/t13v-artifact.sh && bash /tmp/t13v-artifact.sh; echo "rc=$?"
```

**修复前**（脱敏前基线）：
```
🔴 清单外命中=14（全部落在脱敏授权面内 ⇒ 就地脱敏后重跑本判据；禁止冻结基线）
rc=1
```
（命中明细 = 基线 14 行：DESIGN:215 / T04:297,:300,:301,:302,:303,:304,:305,:314,:316 / T11:56 / FULL-SWEEP:126,:242,:255）

**修复后**：
```
✅ 脱敏完成：授权面外命中 = 0（tracked + 未 tracked 两面均已扫描）
rc=0
```

**D10′③ 冻结排序复扫**（`git add` 工件集入索引后重跑同判据）：
```
✅ 脱敏完成：授权面外命中 = 0（tracked + 未 tracked 两面均已扫描）
rc=0
```

## 五、反恒真自查（L-121 / L-123）—— 独立二次计算命中集

用与工件判据**互不依赖**的两路独立复算，逐一对照 14 处原始命中是否已去真：

1. **tracked 面独立复算**：`LC_ALL=C git grep -HnE "$PAT"`（指定 4 个目标文件）→ **0 命中**；全仓 `git ls-files -z | xargs -0 grep -HnE "$PAT"`，剔除 IR 排除面与通用占位符后 → **0 命中**。仅剩的两条非排除命中为：
   - `DESIGN.md:242`：行内含 PAT 定义字面与 `/home/<user>` 占位符 → 被判据 `grep -vE '/home/(user|ubuntu|\.\.\.)/'` 排除（良性，非真实账号）。
   - `.specs/archive/…/INDEPENDENT-REVIEW-1.md:630`：行内含 `/home/user/.dsh/…` 占位符 → 同一排除规则滤除。
   - 即时核对：**无 `/home/<acct>*` 真实账号残留**（独立 grep，见下）。
2. **未 tracked 面独立复算**：`git ls-files -o --exclude-standard -z | xargs -0 -r grep -HnE "$PAT"`，剔除 IR 排除面与通用占位符后 → 仅 `.specs/health-fix-2026-09b/REQUIREMENT.md:390` 一项，其行内为 `/home/user/` 占位符（排除表吸收），**非真实账号**。
3. **真实账号字面直接验证**：`grep -nE '/home/<acct>/'` 于 4 个目标文件 → **0 处**（rc=1）。

**结论**：判据 rc=0 非「扫不到」假绿 —— 独立复算在脱敏前能抓到全部 14 处（与本判据一致），脱敏后均不可命中，且全仓无真实账号路径残留。

## 六、逐行对照表（原命中 14 处 → 为何不再命中）

| 文件:行 | 替换后文本 | 为何不再命中 PAT |
|---|---|---|
| DESIGN.md:215 | `HOME=/home/<acct>`（`/home/<acct>/x.sh`） | `<` 不在 PAT 字符类 `[a-z_]` ⟹ `[a-z_]` 拒绝 `<`，`/home/<` 不匹配 |
| T04:297 | `源: <repo>/flow-kit-bundle/hooks` | 无 `/home/` 前缀 |
| T04:300 | `✅ $HOME/.claude/hooks` | 无 `/home/` 前缀 |
| T04:301 | `✅ <repo>/dist/dsh-flow-kit/hooks` | 无 `/home/` 前缀 |
| T04:302 | `✅ <repo>/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks` | 无 `/home/` 前缀 |
| T04:303 | `✅ $HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` | 无 `/home/` 前缀 |
| T04:304 | `✅ $HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks` | 无 `/home/` 前缀 |
| T04:305 | `✅ $HOME/.config/opencode/hooks` | 无 `/home/` 前缀 |
| T04:314 | `$HOME/.claude/hooks/stop/lib/l3-prompt.sh` | 无 `/home/` 前缀 |
| T04:316 | `$HOME/.config/opencode/hooks/stop/lib/l3-prompt.sh` | 无 `/home/` 前缀 |
| T11:56 | `path=<repo>/flow-kit-bundle/hooks/pre-push/pre-push.sh` | 无 `/home/` 前缀 |
| FULL-SWEEP:126 | `→ <repo>/` | 无 `/home/` 前缀 |
| FULL-SWEEP:242 | `$HOME/.claude/hooks/pre-commit/pre-commit.sh` | 无 `/home/` 前缀 |
| FULL-SWEEP:255 | `cd <repo> || exit 1` | 无 `/home/` 前缀 |

## 七、门禁输出

- `make check-test-sync` → `✅ test 双源一致`，rc=0
- `make check-hooks-sync` → `✅ hooks 副本一致（漂移 0）`，rc=0（本 task 文档脱敏不影响 hooks 产物）
- `make lint` → `✅ shellcheck: no errors found`（67 文件），rc=0
- `make test` → **973 ok / 0 not ok / rc=0**（见提交段实测输出）
- `make check-dist`：预期红（T24 收口），未修、不计失败。

## 八、越界检查（L-121 / DESIGN D10′ 边界）

- 全仓 PAT 复扫中，命中文件仅剩：IR 排除面（协议禁改，精确路径豁免）+ `DESIGN.md:242` / `.specs/archive/…/INDEPENDENT-REVIEW-1.md:630` / `REQUIREMENT.md:390`（各自行内含 `/home/user/` 占位符，被通用占位符排除表滤除）。**无任何命中落在 `$FACE` 授权面之外的代码/测试/门禁/禁动清单内** ⇒ 无越界，无需 STOP/BLOCKED。
- 未向 `INDEPENDENT-REVIEW-*.md` 写入（契约边界零写入）。

## 九、6 维自查

1. **双态证据**：修复前 rc=1 `🔴 清单外命中=14`，修复后 rc=0 `✅ 脱敏完成`，两次均实测（§四）。✅
2. **命令 ≠ 断言（L-121）**：判据的 ⊁`$n` 断言与 `$FACE` 越界判定不可通过空值/漏扫绕过；未 tracked 面 `git ls-files -o` 空集显式处理（判据内 `if [ -n "$uf" ]`）。✅
3. **反恒真（L-123）**：§五 两路独立复算 + 逐行对照表证明 0 命中非「扫不到」假绿。✅
4. **只做路径字面替换**：rc/命令/输出数字/判据/决策与 AC 语义全部原样保留（§三表仅改路径字面）。✅
5. **冻结排序（D10′③）**：脱敏 → `git add` 工件集 → 复扫 rc=0（非 0 即中止，未触发）。✅
6. **禁止 `--no-verify`（L-126）**：提交不使用；pre-commit 门禁自然跑绿。✅

## 十、TDD 声明（本 task 可 N/A，理由如下）

本 task 是**纯文档脱敏**（Markdown 工件中的路径字面替换），不涉及任何代码/逻辑/接口行为变更；无「实现 → 测试」闭环可供 TDD 承载，测试面亦无随之变化的行为可断言。按 flow-kit「纯文档 task 可跳过 TDD 并说明理由」的约定，**TDD N/A**。脱敏正确性由「工件判据双态实测 + 两路独立复算」承载（等效于验收断言），且由 AC-6 基线冻结阶段的 make check 复扫兜底。

## 十一、遗留项

- `.specs/CONTEXT.md` / `.specs/LESSONS.md` / `.specs/STATE.md` 含在途改动，本 task 未触碰（也不应触碰）—— 由主 agent 阶段收口处理。
- L-129 前向规则：本 task 之后每一 task 的 SUMMARY 定稿前需就地 de-shape（不积压到 T13）。本 SUMMARY 自身已按 `<repo>` / `$HOME` / `/home/<acct>/` 形态书写，未写真账号。
- AC-6② 的基线文件 `.specs/health-fix-2026-09b/path-privacy-allowlist.txt` 尚不存在（4-dev 显式依赖缺口），由后续冻结阶段建立。