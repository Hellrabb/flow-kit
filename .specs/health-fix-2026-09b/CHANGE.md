# CHANGE: 收口 4 个 🔴（eval RCE / 配置截断 / 泄漏重发路径 / 坏门禁）+ 隐私前向门禁 + 假绿测试

- **Change ID**: health-fix-2026-09b
- **创建日期**: 2026-09-22
- **路径建议**: 完整（0 → 1 → 2 → 3 → 4 → 5 → 6 → 7）—— 理由见文末「路径理由」
- **状态**: draft

---

## Why（为什么做）

2026-09-22 全量五维健康巡检（`.specs/health/2026-09-22-FULL-SWEEP.md`，54/100 · 13🔴/35🟡/23🟢）**首次把巡检面从 4 维扩到 5 维**（+隐私泄露 / +生产代码 R1-R6 / +测试 T1-T6 / +架构单一源）。**所有 13 个 🔴 均为存量**——无一由本周期 4 个 commits 引入；同轴指标（语法 0 错、shellcheck error 0、副本漂移 0、bash 重复 0.453%、973 测试全绿）显示仓库**并未退化**，只是此前没被看那么深。

本 change 只收口其中**风险最高的 4 个 🔴 + 3 组同根因项**：

### 1. PC1 🔴 任意代码执行 —— 安全守卫里的 RCE（**已独立复现**）

`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh:46`：
```bash
file_path=$(echo "$stdin_data" | jq -r '.tool_input.file_path // empty' ...)   # :33 载荷可控
real_path=$(eval echo "$file_path" 2>/dev/null) || real_path="$file_path"     # :46 eval
```
`file_path` 直接来自 hook stdin 的 JSON 载荷。**本次巡检以一个携带命令替换的 `file_path` 载荷复现成功：注入的命令实际执行、落盘文件生成**（PoC 原文见 `.specs/health/2026-09-22-FULL-SWEEP.md` PC1）。
- `2>/dev/null` 与 `|| real_path=...` **无法防护**：`eval` 先做命令替换，再谈退出码
- matcher `Write|Edit` → **每次写文件都触发**，且该行在所有 gate 判定（:48 起）**之前**
- 全仓 57 个 shell **唯一的 `eval`**，且位于**安全守卫**内部 —— 守卫赋予被守卫者任意代码执行

### 2. PC2 🔴 `settings.json` 被截断为 0 字节 —— 静默数据丢失（**代码路径已复现**）

`flow-kit-bundle/lib/install_hooks.sh:238-253`。`:211` 分支条件为 `[ -f "$settings_target" ] && command -v jq &>/dev/null`，故**「文件已存在 + jq 缺失」落入 `:238 else`（注释写 `# 新建`）**，`:251` 的 `jq -n … > "$settings_target"` **在 jq 执行前就把已有文件截断**。随后 `jq: command not found`（127）；`install.sh` 是 `set -euo pipefail` → 安装中断，**无备份、无回滚**。已复现 113 字节 → **0 字节**（`permissions.allow` 与既有 Stop hook 全毁）。触发场景：新机器未装 jq（全脚本无前置 jq 校验）。

### 3. P1 🔴 本地 `main` 仍携带前向脱敏前历史 —— 泄漏重新发布路径

`privacy-path-scrub-2026-09` 声称"develop 全历史重写（含已推送）"，**实测只对 `develop` 生效**：

```
ref                     commits   /home/<acct>
develop / origin/*         331        0  ✅
main（本地）                20        8  ❌
```

- `git merge-base main develop` → **rc=1**（无共同祖先）；本地 `main` 是**孤儿分支**、无 upstream
- `main` **tip 树**即命中 **2 个文件 / 6 行**（`.specs/CONTEXT.md:156` ×1 +
  `archive/2026-06-09-user-scope-install/TASK.md` ×5）—— 初版误记为「6 文件」（L2 R12）
- `git push --all` / `git push origin main` / `--mirror` / `git bundle --all` 任一执行即**重新发布用户名+雇主路径**

**且该 change 自己的「权威验证」判据当前不通过**（比推送风险更直接）：

`HISTORY-REWRITE-FULL.md:120` 规定的权威验证是**仓库级**的（扫全部对象，期望 **0**）：

| 范围 | 对象库 `/home/<acct>` 命中 |
|---|---|
| `develop` 可达对象 | **0** ✅ |
| 本地 `main` 可达对象 | **8** ❌ |
| **全 refs 合计（逐字执行 `:120` 原文命令）** | **8** ❌ |

机制：本地 `main` 使这 8 个 blob **保持可达** → `gc --prune=now` 无法回收 → `--batch-all-objects`
照样枚举到。即文档承诺的「对象库里任何对象都不再含该串」**当前不成立**，且与 **L-110 ③**
（"安全网必须删除，否则它自己就是最大的泄露面"）的原则直接冲突 —— 本地 `main`
正是同一个角色：**一个未清理的、使旧对象存活的引用**。

- 根因：`HISTORY-REWRITE-FULL.md:32-33` 的论证基于 **`origin/main`**（命中 0），漏了本地 `main` 与它已分叉（20 vs 12）

### 4. AR2 🔴 仓库唯一存在的 prompt↔skill 门禁是坏的（**已独立运行复现**）

`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`：实测 **`exit 1`** 永久红，**未接入 `make check`**，其 bats 测试 `:30` 断言 `[ "$status" -ne 2 ]` **显式容忍 exit 1** → **净有效覆盖 = 14 对中 0 对**。

且判据本身有两层缺陷（**本次巡检纠正了先前版本的判断**）：

| 口径 | `4-dev.md` | `flow-dev/SKILL.md` | 结果 |
|---|---|---|---|
| 现状 `grep -c "^\| [0-9] \|"`（只匹配顶格行） | 2（仅未缩进的第 7/8 行） | 8 | **2≠8 → 永久假红** |
| **只修正则**为 `^[[:space:]]*\| [0-9] \|` | **8** | **8** | **8==8 → 假绿** ⚠️ |

**第二层更致命**：`flow-dev/SKILL.md:156-163` 那 8 行是 **§1.7.2 迁移框架探测表**（Prisma/Alembic/Rails/Knex/Flyway/Liquibase/裸项目），**与 PCSC 自检表毫无关系**。纯计数比较是**语义盲**的——两张不同的表只要行数相同就通过。**因此「只修正则」不是可接受方案**：它把看得见的假红换成看不见的假绿，而红灯会被人修、绿灯会永远藏住漂移。

> 注：TD-025 称此面"无任何机器一致性检查"，措辞不准确，应订正为"**1 个坏掉的、永久红灯且测试豁免失败的门禁**"。

### 3 组同根因项（用户确认并入）

- **P3 🟡 `chisel` 内部项目名随分发件出厂** —— 唯一**已经流出到用户**的泄漏：命中 `flow-kit-bundle/test/test_correction_hygiene.bats`、`test_l3_review_defects_2026_09.bats`，并经 `vendor/` 进入 **npm 包 `dist/dsh-flow-kit-0.2.0.tgz`（6 处）**；该包无 `"private": true`，`files` 含 `vendor`
- **P6 🟡 无任何前向防回归门禁** —— `Makefile` 无 path/privacy 目标；`verify-claims.sh` 无绝对路径检查；`.git/hooks/pre-commit` **内容只是 `make test`**，且是**指向仓库外**的机器本地符号链接 → 不随 clone 传播。当前唯一防线是 `.gitignore`（无法阻止有人把绝对路径粘进 `.md`）
- **TC3/TC4/TC5 🔴 4 处假绿测试** —— 绿灯被注水，与 AR2 同属"检查器自身不可信"

## What（做什么）

六组修复，**全部只碰"检查层 / 判据层 / 硬化层"，不改任何业务运行时语义**：

1. **PC1** —— 消除 `eval`，改为**不执行任何命令替换的纯参数展开**方式完成 `~` 展开
   （具体写法由 DESIGN 决定并给出等价性论证）；同步 `dist/` 与已安装副本
2. **PC2** —— `install_hooks.sh` 入口加 `command -v jq` 硬校验；`:251` 写盘改 `mktemp` + `mv`；修正 `:211` 分支条件（"文件存在 + 无 jq"不得落入 `# 新建`）
3. **P1** —— **不动 `main`**（用户决策）：新增 `pre-push` 拦截（含 `--all`/`--mirror`/`--tags` 场景）+ 在 `HISTORY-REWRITE-FULL.md` §7 与 CONTEXT.md 加显式告警
4. **AR2** —— 判据从「比行数」升级为「**比内容**」；接入 `make check`；测试断言由 `-ne 2` 收紧为 `-eq 0`。
   **⚠️ 已撤回初版的「删 `4-dev.md` 内联 PCSC 表」指令（L2 R7/R3 证伪其依据）**：
   `reference/phase-prompt-template.md:144` 明写 PCSC 表格属「**结构性文档化（不抽取）**」
   （phase-specific 内容占比高），`:145` 方向是**参数化**而非单源化。
   故 **PCSC 表移出比较范围**；门禁的漂移比较对 `(P,S)` 由 **DESIGN 定义**，
   且须满足「两侧本应逐字一致」（合规候选：`sync-hooks.sh:57-62` 已枚举的镜像面）
5. **P3 + P6** —— 两份 bats 的 `chisel-*` 替换为中性占位 + 重建 npm 包并复扫；新增 `make check-path-privacy` 纳入 `make check` + pre-commit
6. **TC3/TC4/TC5** —— 修 4 处假绿测试（详见验收线）

## 视觉调性

不适用（非前端项目 —— 步骤 0.5 未命中）。

## 影响面

- [ ] 影响 `REQUIREMENT.md`（走增量，见路径理由）
- [ ] 影响 `DESIGN.md` / 引入新 ADR —— **需 DESIGN 说明两道新门禁的失败语义与豁免机制**
- [x] **影响现有 AC**：`test_lessons_cleanup.bats` AC-4 被永久 skip 且注释声称"由 AC-3 覆盖"，而 AC-3 断言的恰是**反面** → 需重新裁定 AC-4 的存废并回写
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] **仅修复 bug，无范围变化** —— 运行时行为不变（PC1/PC2 修的是缺陷；AR2 修的是检查器判据）
- [x] **影响 `make check` 的组成**（新增 `check-path-privacy`；`check-gate-sync` 首次接入）→ 门禁一旦变严**可能立刻变红**
- [x] **影响分发包内容**（P3 需重建 `dist/dsh-flow-kit-*.tgz`）→ 需 `make check-dist` 复核
- [x] **涉及安全**：PC1 是已复现的 RCE；PC2 是已复现的数据丢失

> ⚠️ **本次真正的风险点**：影响面第 2 与第 3 条叠加。新门禁 + 收紧后的断言**会立刻暴露既有漂移**
> （AR2 的 PCSC 内容差异、TC3 的 AC-4、以及 `make check-path-privacy` 首跑必然命中现存残留）。
> DESIGN 必须预先给出"新暴露项如何处置（修 / 登记豁免 / 降级为 note）"的决策，
> 否则 change 会在 5-test 阶段被**自己新增的门禁**挡住。

### 4b. 范围追加（**用户裁决 · 2026-09-23**）—— L3 提示词信封修复

阶段 2 的 L3 **连续两次 fail**，根因不在工件而在**提示词信封**：`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`
的 phase 2 ADR 纳入策略是 `find "$adr_dir" -type f -name '*.md' | head -3` —— 取**目录序前 3 份**，
实测恒为 **ADR-011 / ADR-015 / ADR-019**（与本 change 无关），而 DESIGN 实际引用的 **022 / 026 / 027 / 028**
（含本 change **新建的 ADR-028**）**永远不进提示词**；每份再经 2000 B **句中截断**且无标记 ⇒ 外部审查者据
**无关且残缺**的证据裁决（两轮 L3 的 critical① 均由此产生）。该缺陷会让阶段 3/5/6/7 的 L3 持续复现
（`gate_config=all` 下每个受门阶段都要过 L3）。

**用户裁决**：作**小范围补修**并入本 change（而非等熔断 `skipped` 放行，或另开 change）。登记 **TD-043**
（缺陷），本 change 落地后转为「已修」。**自我指涉披露**：这是「被审门禁修改自身」——缓解见 `DESIGN.md`
§0.5.1 该行（只**减少**提示词噪声、**不放宽任何判据**、实测证据齐备、5-test 留双态 verify）。

### 4c. 范围追加（**阶段 4 发现 · 2026-09-23**）—— 机器绝对路径的入档纪律（SUMMARY 面）

阶段 4 执行 DEV 时，**每个 task 的 SUMMARY 会把本机原始输出原样贴入**，其中含真实账号绝对路径：
实测 `T04-SUMMARY.md` **9 行**（`:297` `:300`-`:305` `:314` `:316`）+ `T11-SUMMARY.md` **1 行**（`:56`）；
`.specs/health/2026-09-22-FULL-SWEEP.md` 另有 **3 行**（`:126` `:242` `:255`）；`DESIGN.md:215` **1 行**
（自造 fixture 字面 `/home/<acct>`）。两个后果：(a) AC-6 的基线「清单外命中 = 0」**无法归零**（这些行在 tracked 面内）；
(b) 这些路径**随提交进入 git 历史**（历史重写不在本 change 范围 ⇒ 只能在提交层面止损）。

**同批修正的判据缺陷（L-122 / L-123 族，主 agent 实测后改写）**：T13 原 verify 只扫 `git ls-files`（tracked）
＋手写枚举的五份工件 ⇒ 对**未 tracked** 的 `.specs/health/*.md` 与本 change 新建的 `.specs/adr/*.md` **完全失明**
（实测对 FULL-SWEEP 的 3 处命中一无所见）；且 `$FACE` 越界断言写在 `[ "$n" -eq 0 ] || exit 1` **之后** ⇒
**永不可达**（死判据）。改写后：补扫面 = `git ls-files -o --exclude-standard`（**空集显式处理**、`grep -H` 保 `file:line` 归因），
FACE 判定**前置**并区分报文（命中全在授权面内 ⇒ 就地脱敏后重跑；落在面外 ⇒ 停止并升级为新 task）。
实测（修复前态）报 `🔴 清单外命中=14（全部落在脱敏授权面内 …）`、rc=1。

**决策（豁免 vs 脱敏的分界）**：**审查档**（`INDEPENDENT-REVIEW-*.md`）原文受协议保护、**禁改** ⇒
由 D10′② 排除表**逐条精确路径**豁免（存量 40 行 = IR-1 22 + IR-2 18）；**SUMMARY 是执行者自撰散文** ⇒
**就地脱敏、不豁免、不入排除表**。前向规则 = **L-129**（粘贴前把机器路径写成 `<repo>` / `$HOME` / `/home/<acct>/` 形态；
**只替换路径字面**，rc/命令/输出文本/数字等证据保持原样），经「必读 LESSONS」条款被后续 task 继承；
T13 写面随之扩为 ③b（`T*-SUMMARY.md`），DESIGN D10′① 同步追加该面（**阶段 4 追加，已披露**）。

### 4d. 范围追加（**用户裁决 · 2026-09-24**）—— 常设回归网与阶段门有效性

阶段 5（5-test）外部 L3 审查**连续两轮 fail**（3 major + 2 minor / 3 major + 3 minor），第 7 轮明确把
「只记技术债而结论仍判 pass」判为不一致。两条 major 是**实质性缺口**而非措辞：

1. **TD-053 · 常设回归网缺口**：`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`、
   `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` 与 NFR 三态判据（`Makefile` 的
   `check-nfr-portability-internals` 与包装层）三件的判定力**只由本 change 的 change 期判据承载**
   —— 实测 `test/` 树对三者的引用数均为 0 ⇒ 归档后其内部逻辑退化不会被常设测试捕获
   （「门禁失效而 `make check` 仍绿」）。阶段 5 原处置把长期回归保护声明为「未达标」并留阶段 7 triage，
   L3 判定该处置与 `pass` 结论不可并存。
2. **TD-059 · 阶段门有效性**：`independent-review-gate.sh` 的 Gate3 经 `fk_independent_review_gate_active`
   把完成标记的**存在**当作完成（门禁强度 = 最早返回的判定 · L-152）⇒ 标记为空（`touch`）/ 缺键 /
   与 `INDEPENDENT-REVIEW-<N>.md` 的 verdict 相悖时仍放行（阶段 5 沙箱 B2/B3 实测 rc=0）；
   其内容校验（`fk_validate_done_marker` 的 Tier-1/Tier-2）在 commit 路径上不可达。

**用户裁决**：**回退 4-dev，两条都修后重跑阶段 5**（`ask_user_question` id `phase5_l3_fail_triage` · option 1）。
落地 = `TASK.md` 的 `T-FIX-01`（三件生产件补常设双态 bats + `make test-sync` + 重建 `dist/` + 基线更新）
与 `T-FIX-02`（Gate3 语义改为「存在**且有效**」+ 新增 `ADR-029` + `./sync-hooks.sh` + 双态 bats）。
两条均**不改变 AC-1..AC-8 的验收范围**，属「使既有交付可信」的置信度补强；`TD-053` / `TD-059` 在
`.specs/CONTEXT.md` 的状态同步改为「本 change 内修复」。

## 范围排除（这次不做）

- ❌ **不删除、不重写本地 `main` 分支**（用户明确决策：先只加防护）—— 但**必须承认**：在防护生效前，
  泄漏分支仍留在本地，且 `:120` 的权威验证持续为 **8 ≠ 0**。
  **注（本次已核实，避免误判）**：`HISTORY-REWRITE-FULL.md` §7 列的三处安全网（裸包 / `refs/backup/*` /
  远端旧历史）**已被按设计删除** —— `:104` 明写「强推确认无误后应删除」，`LESSONS.md` **L-110 ③**
  给出理由（安全网本身即最大泄露面）。故"不可逆"是**预期终态、非缺陷**；
  本次不重建安全网（重建等于把泄露面请回来），残留仅为 P1 的推送旁路风险
- ❌ **不做 `prompts ↔ skills` 14 对双载体的实质同步**（TD-025）—— 已量化：**3 对仅差平台 front-matter（`diff` 恒为 6 行：`A-evolve`↔`flow-evolve` / `I-intel-scan`↔`flow-intel` / `L-restyle`↔`flow-restyle`）、11 对实质分叉**（初版写作「0 对逐字相同」——按 raw `diff` 字面成立但**误导**，据 L2 第 2 轮 N2 订正）（最惨 `6-review ↔ flow-review` 仅 28 行交集，**Jaccard 7.67%（28/365）**）。这是**产品判断**
  **F6 订正**：初版写「Jaccard 1.0%」**不可复算**；实测 28/365 = **7.67%**（交集 28 行不变）
  （镜像 or 允许差异的精简版），塞进来会让范围失控。本 change 只**修门禁让它能看见**，不**裁决内容**
- ❌ **不改** `pipeline-gates.md` 之外的其它 reference 内联（`flow-dev/SKILL.md` 静默内联
  `tdd-workflow.md` 等 ~290L，AR3；`L2-blind-review.md` 的第三载体，AR4）—— 同属散文层裁决，独立处理
- ❌ **不修** PC3（pre-tool-use 子库 fail-open）—— 虽同为 🔴，但 3 个子库**当前均在**，
  属"已知缺陷类的修复不完整"（`common.sh` 侧已修过），**潜在**而非现网断裂，降级到下一批
- ❌ **不改** `unisoc` 存量（88 行 / 34 文件）—— `HISTORY-REWRITE-FULL.md:136` 已声明为已知残留，
  需产品决策"接受 or 改目录名"，本 change 不替用户决定
- ❌ **不引入** `make lint` warning 棘轮（G1，233 条 warning 级发现，抽样显示多为风格/假阳性）
- ❌ **不修**任何与本次无关的 🟡/🟢（PC4-PC15、G2-G5、TD-036 等）—— 已登记 TD-026~038

## 验收线（粗粒度，不是 AC）

1. **PC1**：`grep -rn 'eval ' flow-kit-bundle/hooks/ | wc -l` = **0**；
   且以原 PoC（`file_path='$(touch /tmp/PWNED)~/.claude/hooks/x.sh'`）驱动修复后的 hook，
   **`/tmp/PWNED` 不得生成**。（复现原 RCE 形态，证明修复有效而非静默绕过）
2. **PC2**：在**无 jq** 的 PATH 下，对已存在的 `settings.json`（含 `permissions.allow`）跑安装 →
   **文件内容与字节数不变**（当前行为：被截断为 0 字节）。（用 `PATH` 遮蔽 jq 模拟，无需卸载）
3. **P1**：构造含**畸形探针**（拼接构造，字面脱形见 REQUIREMENT AC-6）的提交并尝试 `git push --all` / `--mirror` → **必须被拦截并给出可读原因**；
   **F6 订正**：初版写 `/home/<user>`，已被 AC-6 的 ⚠️ 禁令废止（该形态被 9 个 tracked 文件用作脱敏占位符）
   对不含泄漏的正常推送 → **不得误拦**。（证明是拦截而非阻断一切推送）
4. **AR2**：修复后 `check-gate-sync.sh` 在健康仓库上 **`exit 0`**；
   且 `make -n check | grep -q 'check-gate-sync'` 通过（**接线证据须来自先决条件、不得来自注释** —— L2 R1）；
   **对 DESIGN 定义的比较对 `(P,S)` 之一做「仅内容、行数不变」的漂移仍必须报红** ——
   这一条是最关键的验收线，直接证伪「只修正则造成的假绿」。
   **注**：初版此处写「把 `pipeline-gates.md` 源表某行文案改掉」，**不可满足**（L2 R3）——
   该脚本从不读 `pipeline-gates.md` 作比较对象，只把它当**引用串**比对（`:56-67`）。
5. **P3**：`chisel` 在 `test/`、`flow-kit-bundle/test/`、**重建后的 `dist/dsh-flow-kit-*.tgz`** 三处计数均为 **0**；
   且这两份 bats 仍全绿（证明是字面替换而非删测试）。
6. **P6**：`make check-path-privacy` 存在并接入 `make check`；**人为在 tracked 文件里插入 `/home/<user>`
   **F6 订正**：初版写「首跑必须报出已知残留」—— 该判据**不可复算**（首跑只发生一次），已被 AC-6 改为
   「与**落档允许清单**比对 + 差分数断言（改清单必须改变门禁输出）」
   必须 fail**；仓库当前状态下**首跑必须报出已知残留**（证明它真的在工作，而不是空转返回 0）。
7. **TC3/TC4/TC5**：4 处假绿测试修复后**仍全绿**（不是靠删测试变绿）：
   `test_combined_metric.bats:31-32` 恒真断言 → 精确断言；
   `test_auto_checkpoint.bats:208,221` → 断言 SUT 而非 jq；
   `test_independent_review_model.bats:81-89,136-141` → 先断言文件存在；
   `test_lessons_cleanup.bats:137` 的 AC-4 → 去 skip 或删除并开显式已知-gap 工单（**不得继续用 skip 把失败说成正确**）
8. **不退化**：全量 bats ≥ **973 ok / 0 not ok**；`make check` 全绿（含两道新门禁）；
   `make check-test-sync` / `check-hooks-sync` / `check-dist` 仍 0 漂移。

## 风险与未知

- **R1（最高）新门禁立即变红**：`make check-path-privacy` 首跑必然会命中现存残留（`.specs/` 下 `unisoc` 88 行等）。
  ~~**未决**：是把首跑基线冻结为「允许清单 + 只降不升」，还是先清残留再启用？~~ → **已在 REQUIREMENT AC-6 裁决**：
  v1 采用**允许清单 + 棘轮**（不采用「先清残留」，因实测残留含本 change 自身新写的文件 ⇒ 不可复算）。
  仍留 DESIGN 的只有「允许清单落档路径与豁免边界」。
- ~~**R2 AR2 的内容合并可能丢校验**~~ → **已解除**（L2 R7/R3）：初版假设「必须先把 `4-dev.md` 的 2 处差异
  合并进 `pipeline-gates.md` 再删内联表」，其两条依据**均被证伪** ——
  ① `phase-prompt-template.md:144` 明确 PCSC 表格「**不抽取**」（故 PCSC 本就不该逐字一致）；
  ② `check-gate-sync.sh` **从不读** `pipeline-gates.md` 作比较对象
  （`:19-20` 的比较对象是 `prompt_file` / `skill_file`）。
  **替代风险**：比较对改由 DESIGN 定义 —— 须在 DESIGN 明确「哪两个载体本应逐字一致」，
  否则 AC-4 无判定对象 → 转入 DESIGN 待决项
- **R3 P1 只防护不清理的残余**：push 拦截只堵住"误推"路径，`git bundle` / 手工 `git push <url> <ref>` /
  拷贝 `.git` 目录等旁路**不在拦截范围**；且泄漏分支长期留在本地。**未决**：是否需要更强的兜底
  （如 `pre-push` 之外再加 `git config` 层面的 remote 限制）→ 需 DESIGN 评估
- **R4 PC1 修复的同步面**：`runtime-edit-guard.sh` 存在多份副本（`dist/`、`flow-kit-bundle/`、已安装 hooks 目录）。
  只改一处会造成新的漂移 → 必须走 `sync-hooks.sh` 并 `make check-hooks-sync` 验证
- **R5 AC-4 的存废是产品判断**：`test_lessons_cleanup.bats` 注释称"当前仓库有已知 gap，exit=1 是预期行为"。
  若确实存在未修 gap，则正确做法是**修 gap** 而非删测试；若 gap 已不存在，则应去 skip。
  ~~**未决**：需先核实该 gap 现状 → REQUIREMENT 阶段确认~~ → **已于 REQUIREMENT 阶段实跑确认**：
  `package-flow-kit.sh --validate` 干净态 **rc=0**（308/314/0/0）⇒ 原 skip 所称「已知 gap」**已不存在**；
  AC-7 已收敛为唯一分支「去 skip 并断言 exit 0」。
- **未知**：`chisel` 替换是否会与其它测试的期望字符串耦合（需 grep 全仓 `chisel` 消费方后确认）

---

## 路径理由

**建议走完整路径（0 → 1 → 2 → 3 → 4 → 5 → 6 → 7）**，而非"最短"：

- 表面像"纯 bug 修复"，但实际**引入两道新门禁 + 改动既有 AC**（AC-4 存废）+ **改变分发包内容**（npm 包重建）
  → 按本仓惯例（参照 `health-fix-2026-09`）这类"检查层"变更仍需 REQUIREMENT 把验收线固化为 AC
- **R1/R3/R5 三处未决项**必须在 DESIGN 前拍板，跳过 1/2 会把它们拖到 DEV 期才暴露
- AR2 的"先合并再删除"顺序约束需要 TASK 阶段拆成**两个各自可 verify 的步骤**，不能一步到位

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
