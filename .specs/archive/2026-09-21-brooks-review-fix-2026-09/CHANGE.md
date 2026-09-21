# CHANGE: 修掉「门禁守卫自身」的三处假绿（+ 三处可维护性）

- **Change ID**: brooks-review-fix-2026-09
- **创建日期**: 2026-09-21
- **路径建议**: 中等（`REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION`；其中 0–5 为**回溯补齐**，见下）
- **状态**: active

---

## 登记形态（先说清楚，避免误读）

**触发**：2026-09-21 用 brooks-lint 的 `brooks-review` 技能对 `health-fix-2026-09`（已归档）的**终态 diff** 做独立复核，
产出 **3🟡 + 3🟢**（报告：`.specs/health/2026-09-21-BROOKS-REVIEW.md`；已计入 `.brooks-lint-history.json` 第 8 条）。
用户选择「**先修好、再登记为 flow change**」，故本 change 的 4-dev / 5-test 产物**先于** 0-change 存在：

- 修复记录（逐条处置 + 证据）：`.specs/health/2026-09-21-BROOKS-REVIEW-FIXES.md`
- 本目录的 CHANGE / REQUIREMENT / DESIGN / TASK / TEST 为**回溯补齐**；口径与实测数据全部取自当日实跑，
  含 L-090 要求的「**修复前实测行为**」取证（不做事后修饰）。

## Why（为什么做）

被审对象（`health-fix-2026-09`）自己就是"修门禁假绿"的 change，而独立复核发现：**它新装的守卫自身也有假绿**。
危害与它要修的完全同源 —— 制造"假安全感"：

1. **🟡1 工件解析会静默改核别的 change**：`verify-claims.sh` 在无活跃 change 时回退到写死的历史 id。
   实测：`resolve_spec_artifact DESIGN.md` → `.specs/archive/2026-09-18-l3-review-defects-2026-09/DESIGN.md`
   （rc=0），而当时被审的 change 是 health-fix-2026-09；§8/§9/§10c 三条断言据此输出 ✅，**文案不含 change id/路径**。
   这与该 change 刚修掉的"基线 sha 写死"是同一类错误：**工件 id 也被写死了**。
2. **🟡2 新门禁没有行为级回归保护**：`check-dist` / `is_real_entry` / `--check` 分流全部只有变更期夹具
   （`.specs/<id>/verify/`，随归档冻结、不进 `make test`）。`test/` 两侧各 70 个 `.bats` 中
   `grep -rl "package-dsh-plugin\|check-dist\|sync-hooks.sh --check"` = **0 命中**；唯一跨归档存活的 §10d 里
   ②④ 是**源码文本判据** —— 实测"只有函数定义、无任何调用点"的文件同样判通过（假绿）。
3. **🟡3 打包映射两份编码、缺失语义相反**：`check_dist` 的映射表与打包 `cp` 步骤是同一事实的两份拷贝，
   且对"源缺失"语义相反（打包 fail-closed / 检查静默跳过）。实测（HEAD 版脚本，夹具内）：
   移走 `dsh-flow-kit/lib` → **`✅ check-dist: dist 与源一致` rc=0**，而 `dist/dsh-flow-kit/lib` 仍是陈旧树。
4. **🟢1/🟢2/🟢3 可维护性**：同一理由被写两遍（3 处）；判据与白名单定义在 7 次迭代的循环体内（无法被外部直调 → 正是 🟡2 的根因）；
   `_changed` 叠三条 git 命令且 rename 行取到旧名。

**共性根因**：守卫类代码的判据用"存在性/文本"代替"行为"，且**核错对象也能通过**。修的是"守卫看见真相的能力"。

## What（做什么）

六处修复，**全部落在检查层/工具层**，不碰任何 hook 运行时逻辑：

1. **🟡1** `verify-claims.sh`：删隐式历史回退 → 三态解析（解析到 / 未指定 / 指定了找不到）；
   新增 `[<change-id>] [<base-ref>]` 两个参数；PASS/FAIL 文案**指名**解析到的路径；无法核对项计 `⏭ SKIP`（不入退出码）。
2. **🟡2** 新增 `test/test_gate_freshness.bats`（14 例真跑）+ 双源同步；`§10d` 删掉可被注释骗过的 ②，
   ④ 改为**行为断言**（走新增的 `sync-hooks.sh --entry-class` 自检出口）。
3. **🟡3** `package-dsh-plugin.sh`：`COPY_DIRS` / `COPY_FILES` / `COPY_OPTIONAL` 三张表成为**唯一映射**，
   打包与 `--check` 同读；目录对源缺失不再静默跳过，与打包侧同语义（必需项缺失 = 错误）。
4. **🟢1** 三处重复注释去重（Makefile / verify-claims.sh / sync-hooks.sh）。
5. **🟢2** `sync-hooks.sh`：`PTU_ENTRIES` + `is_real_entry()` **提到文件作用域**；新增无副作用的 `--entry-class <rel>`。
6. **🟢3** `_changed` 收敛为 `git diff --name-only HEAD` + `git ls-files --others --exclude-standard`（+ 可选 `<base-ref>` 区间）。

## 影响面

- [ ] 影响 `REQUIREMENT.md`（既有）
- [x] 影响 `DESIGN.md` / 引入新 ADR —— **无新 ADR**；维持 ADR-027（门禁只保证"看不见的变可见"，不改变红绿语义）
- [x] 影响现有 AC —— `verify-claims.sh` 的 §8/§9/§10c 口径变更（无活跃 change → `⏭ SKIP`；新增两个位置参数）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 仅修复判据缺陷，**被测对象的运行时行为不变**（无 hook 逻辑改动）
- [x] 影响测试面：`make test` 的 bats 由 950 → **964**

## 范围排除（这次不做）

- ❌ **不引入**"每个 change 的专属断言都进 verify-claims"的新机制 —— 上轮 R6 的 (a)/(b) 决策维持 **(b)**（保留 + 生命周期注释 + 维护提示）
- ❌ **不改** `install_hooks.sh` 的 chmod 行为（仍对 pre-tool-use/*.sh 一律 `+x`；白名单只服务 exec 位判据）
- ❌ **不改** `hooks/**` 运行时逻辑（本 change 只碰 Makefile / 4 个根脚本 / test）
- ❌ **不给** `check-dist` 加"自动重建"或任何写操作（只读契约不变）
- ❌ **不把** DESIGN §0.5.1 从自然语言改为结构化 schema（文本提取脆弱，收益不足）

## 验收线（粗粒度，不是 AC）

1. 无活跃 change 时，`verify-claims.sh` 的三条工件断言**显式声明"未核对"**，且**不再**核任何别的 change。
2. 新门禁的最关键行为可在 `make test` 里被复算：陈旧 dist → 红且指名；库文件不误报、真入口缺 exec 必报。
3. `make check` 6 门全绿，且**打包产物与修复前逐字节等价**（重构不改变产物）。

## 风险与未知

- **R1（中）`<change-id>` 参数是新契约**：老调用方式（无参）的语义从"核某个历史 change"变成"⏭ SKIP"。
  这是**有意的语义修正**（原来核的是错的），但需在用法段/CHANGELOG 写明，避免被读成"少核了三项"。
- **R2（低）新 bats 依赖 node**：夹具会复制 `package-dsh-plugin.sh` 造最小树，打包脚本本身要求 node（跑 node 单测），
  故不新增环境依赖；但 `npx bats` 不可用时会整体跳过（既有行为）。
- **R3（低）本次代码先于登记存在**：git 上的"改动集"跨了登记边界，TASK 的 `write_files` 属**回溯声明**，
  非事前约束；`git diff` 无法区分"修复前/后"两次改动，故所有 before/after 证据都落在夹具与「修复前实测行为」表里。
- **未知**：`verify-claims.sh` 的 SKIP 计数（`⏭`）是否会被下游解析器误读 —— 已确认归档夹具 `ac7.sh:38` 的正则
  `复验结果: ✅ [0-9]+  ❌ [0-9]+` 为非锚定匹配，追加 ` ⏭ N` 仍命中。

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
