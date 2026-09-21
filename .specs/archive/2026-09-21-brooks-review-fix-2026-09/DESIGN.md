# DESIGN: 修掉「门禁守卫自身」的三处假绿（+ 三处可维护性）

- **Change ID**: brooks-review-fix-2026-09
- **关联**: `@.specs/brooks-review-fix-2026-09/REQUIREMENT.md`（7 条 AC）、`@.specs/health/2026-09-21-BROOKS-REVIEW.md`（诊断）、`@.specs/health/2026-09-21-BROOKS-REVIEW-FIXES.md`（处置记录）
- **形态**: 回溯登记（代码先于本文件存在，见 CHANGE.md「登记形态」）

---

## 0. 技术栈选定

沿用既有：Bash + coreutils（`cmp`/`find`/`mktemp`）+ `git` + `jq`（仅 `.flow-active` 读取）+ `node`/`npx bats`（测试）。
**不引入任何新依赖**；不新增门禁；不改 `make check` 的组成。

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（实际改动清单 · §10c 据此核对）：
- Makefile                              （既有 · 门禁总入口：仅删除 check-dist 段一行重复注释）
- package-dsh-plugin.sh                 （既有 · dist 组装：拷贝映射单一化 + 缺失语义对齐）
- sync-hooks.sh                         （既有 · 副本镜像 + exec 判据：判据提到文件作用域 + --entry-class 出口）
- verify-claims.sh                      （既有 · 声明机械复验：工件解析三态化 + §10c/§10d 判据改造）
- test/test_gate_freshness.bats         （**新增** · 14 例行为回归：check-dist 7 例 + 打包与参数 fail-closed 2 例 + 真入口判据 3 例 + `<base-ref>` fail-closed 1 例 + 用例自检 1 例）
- flow-kit-bundle/test/test_gate_freshness.bats（**新增** · 上者的双源镜像，由 `make test-sync` 生成）

未触碰（明确排除，见 §6）：
- flow-kit-bundle/hooks/**              运行时逻辑（零改动）
- flow-kit-bundle/lib/install_hooks.sh  安装器行为（仅上轮已加的交叉引用注释，本 change 不动）
- flow-kit-bundle/flow-kit/prompts/**  提示词
- dsh-flow-kit/lib/*.js                 插件运行时
- .brooks-lint-history.json · .specs/** 账本与工件（非产品代码）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 门禁 target 形态 | `Makefile` 的 `check-dist` 薄壳 | **沿用**（不新增 target，不改组成） |
| 只读新鲜度检查 | `package-dsh-plugin.sh --check` | **沿用**（仅把映射改为单一来源） |
| 真入口判定 | `sync-hooks.sh::is_real_entry()` | **沿用**（仅移动位置 + 开自检出口） |
| bats 夹具还原 | 既有 AC-8 的 `trap` 还原惯例 | **沿用 + 改进**：本 change 的破坏性用例全部打在 `$BATS_TEST_TMPDIR` 的**最小夹具**上，**不碰仓库工作区**（比 trap 还原更强） |
| 双源测试镜像 | `make test-sync` / `check-test-sync` | **沿用**（新 bats 自动进双源） |
| 计数现场复算 | 本仓既有原则（不抄快照） | **沿用**：`⏭ SKIP` 也现场计数，不写死 |

### 0.5.3 沿用模式 vs 引入新模式

```
- 判据实现位置：**沿用**「与它守护的产物同源」—— `--check` 的映射与打包步骤同源（本次把它从"两份"变成"一份"）。
- 新增模式（1 处，最小）：**判据自检出口** `sync-hooks.sh --entry-class <rel>`（无副作用、exit 0/1）。
  为什么必须新增：判据此前埋在循环体内，外部只能用"grep 源码文本"验它 —— 那正是 🟡2 的假绿来源。
  这是把"不可测"变成"可测"的最小改动；不引入配置文件、不引入插件机制。
- 新增模式（1 处，最小）：**SKIP 语义**（⏭，不计入 ✅/❌）。
  为什么必须新增：原实现"核不到对象就换一个对象"，把"无法核对"伪装成"核对通过"。
  ⏭ 让"未核对"成为**可见的第三态**，且不影响退出码（保持 `make verify-claims` 在归档后仍可用）。
```

## 1. 决策清单

| # | 决策 | 备选与理由 |
|---|---|---|
| **D1** | 工件解析改为**三态**：解析到 / 未指定（SKIP）/ 指定了找不到（FAIL）；**删除隐式历史回退** | 备选(a) 保留回退但把路径打进文案 —— 仍有"核错对象报 ✅"的实质风险；(b) 直接 FAIL —— 归档后 `make verify-claims` 每跑必红，会把门禁训成噪声。**选三态**：错的绝不冒充对，未核对明确可见，退出码语义不变 |
| **D2** | 判据自检走 **`--entry-class` 出口**，不把判据抽成新文件 | 备选(a) 抽 `hooks/pre-tool-use/entries.sh`：新增部署面（7 个副本 + 打包），且要改 `install_hooks.sh`；(b) 继续 grep 源码文本：正是被证伪的假绿。**选出口**：零部署面变化、零运行时影响、可被 bats 与 §10d 直调 |
| **D3** | 打包映射**单一来源**（`COPY_DIRS`/`COPY_FILES`/`COPY_OPTIONAL`），打包循环与 `check_dist` 同读 | 备选：保留两份 + 加一致性断言 —— 仍需维护两份，且断言只能查"表与表"、查不出"表与 cp 步骤"漂移。**选单一来源**：结构性消除，且产物等价已于实测证明（整树哈希不变） |
| **D4** | 缺失语义**与打包侧对齐**：必需项源缺失 = 错误；可选项源缺失 = 合法；任一情况下"源已删 + dist 仍有副本" = 反向残留 | 备选：保持静默跳过 —— 实测假绿（移走 `dsh-flow-kit/lib` → rc=0）。**选对齐**：检查器与执行器表达同一契约 |
| **D5** | §10d 的 ② 删除、④ 改行为断言 | ② `grep -qE '^check-dist:' Makefile` 与 ① `make -n check` 表达同一事实（且 ① 更强：target 未定义时 `make -n` 直接报错）；④ 的文本 grep 可被"死定义"骗过 |
| **D6** | §10c 的空集语义从 `✅ 跳过` 改为 **`⏭ SKIP`** 并写明核对范围 | "0 项"不是"核过了"；原实现（pass）与更早实现（报"1 个都合规"）都是空集恒真 |
| **D7** | `_changed` = `git diff --name-only HEAD`（已含 staged+unstaged）+ `git ls-files --others --exclude-standard`，并支持 `<base-ref>` 区间 | 原三条命令同一信息写三遍，且 rename 取旧名；`<base-ref>` 给归档后复算留出口（不自动猜基线，避免重蹈"基线写死"） |

## 2. 数据流 / 架构图

### 2.1 门禁链（本 change 触及的两个环）

```
                    ┌───────────────────────────────┐
   make check ──────┤ test lint check-validate      │
                    │ check-test-sync check-hooks-sync check-dist
                    └───────────────┬───────────────┘
                                    │
        ┌───────────────────────────┴────────────────────────────┐
        │ check-dist                                             │ check-hooks-sync
        ▼                                                        ▼
  package-dsh-plugin.sh --check                            sync-hooks.sh --check
        │ 读                                                    │ 读
        ▼                                                       ▼
  COPY_DIRS / COPY_FILES / COPY_OPTIONAL  ◄── 唯一映射 ──►  is_real_entry()（文件作用域）
        ▲                                                       ▲
        │ 同一份表被【打包循环】与【检查循环】各读一次              │ --entry-class <rel>（判据自检出口）
        │                                                       │
        └────────── 打包（无参数）──────────────────────────────┘
                                                                ▲
                        verify-claims.sh §10d ④ ────────────────┘（行为断言，非 grep）
                        test/test_gate_freshness.bats ──────────┘（14 例真跑）
```

### 2.2 verify-claims 的工件解析（AC-1 的三态）

```
  bash verify-claims.sh [<change-id>] [<base-ref>]
        │
        ├─ 有 <change-id> ──► 找 .specs/<id>/<name> ──► 找 .specs/archive/*<id>/<name>
        │                        │命中 → rc=0（SPEC_PATH）      │未命中 → rc=2 → ❌ FAIL
        │
        └─ 无 <change-id> ──► 读 .flow-active.change_id
                                 │有 id → 同上（命中 rc=0 / 未命中 rc=2）
                                 └─ 无 id → rc=1 → ⏭ SKIP（"未指定 change → 本项未核对"）
```

## 3. 关键状态机

`spec_target()` 的三态是本 change 的核心语义（原实现只有"命中"与"回退换对象"两态）：

| 态 | 触发 | 输出 | 退出码影响 |
|---|---|---|---|
| **解析到**（0） | 指定/活跃 change 的工件存在 | `✅ …（核的是 <path>）` | 计入 ✅ |
| **未指定**（1） | 无 `<change-id>` 且 `.flow-active` 无 change_id | `⏭ …：未指定 change → 本项未核对` | 计入 ⏭，**不影响退出码** |
| **找不到**（2） | 指定了 id（或活跃 id）但 live/archive 都没有该工件 | `❌ …：change '<id>' 的 <name> 未找到` | 计入 ❌（非零退出） |

## 4. ADR 索引

- **无新增 ADR**。
- 维持 **ADR-027**（门禁只保证"看不见的变可见"，不改变红绿语义）：本 change 的三处 🟡 都是**判据可见性**修复，
  没有把任何 warning 升级为 fail，`make lint` 仍是 error 级门禁。
- 维持 **ADR-010**（门禁语义不动）。
- 与 **ADR-017**（Minor 单一路径）无冲突：本 change 的 🟢 项已在本次修掉，不入 MINOR-DEFERRED。

## 5. 风险

| # | 风险 | 类型 | 缓解 / 处置 |
|---|---|---|---|
| **R1** | `<change-id>` 无参语义从"核历史 change"变成 SKIP，被误读为"少核了三项" | 契约变更 | 用法段 + CHANGELOG + AC-1 文案三处写明；SKIP 行**显式**说明原因与补救方式（传 `<change-id>`） |
| **R2** | 打包映射重构可能改变 dist 产物 | 回归 | 重构后**立即**重建 dist 并与重构前基线整树哈希比对（实测：`9c0b7b1e…` **逐字节相同**，525 文件） |
| **R3** | 新 bats 夹具依赖 `node`/`npx bats` | 环境 | 打包脚本本就要求 node（跑 node 单测）；夹具为最小树，单文件运行 ~10s；不新增依赖 |
| **R4** | `--entry-class` 成为新对外接口（未来可能被误用/改名） | 接口 | 出口只读、无副作用；契约写在 sync-hooks.sh 头部；`test_gate_freshness.bats` 与 §10d 两处守护 |
| **R5** | §10d ② 删除后"check-dist target 定义存在"少了显式断言 | 判据强度 | ① `make -n check \| grep check-dist` 在 target 未定义时**必失配**（make 直接报错），断言强度不低于原 ②；已实测 |
| **R6** | 本次为回溯登记，`git diff` 无法区分"修复前/后" | 流程 | 所有 before/after 证据落在夹具与 REQUIREMENT 的「修复前实测行为」表；CHANGE.md 显式声明登记形态 |

## 6. 不在范围

- ❌ 不引入"每 change 专属断言进 verify-claims"的新机制（维持上轮 R6 的 (b) 决策）
- ❌ 不改 `install_hooks.sh` 行为（仍对 pre-tool-use/*.sh 一律 `chmod +x`）
- ❌ 不改 `hooks/**`、`prompts/**`、`dsh-flow-kit/lib/**`
- ❌ 不给 `--check` 任何写操作/自动重建
- ❌ 不把 §0.5.1 结构化（列入 v2）

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象（建议 append 到 CONTEXT 「既有抽象索引」段）

- **`sync-hooks.sh --entry-class <rel>`**：hook「真入口 / 库」分类的**无副作用自检出口**。
  凡"判据埋在脚本内部、只能靠 grep 源码文本验证"的场景，应优先开一个这样的出口，而不是在测试里 grep 源码。
- **`⏭ SKIP` 第三态**（verify-claims.sh）：适用于一切"依赖外部对象（change / 分支 / 环境）才能核对的断言"。
  规则：**核不到对象 → SKIP 并写明原因**，绝不"换一个对象继续核"；只有"指定了却找不到"才是 FAIL。
- **`COPY_*` 单一映射**（package-dsh-plugin.sh）：打包器与校验器同读一份映射，
  缺失语义必须一致（必需 fail-closed / 可选 skip / 源删 dist 留 = 反向残留）。

### 9.2 建议写入 LESSONS 的条目

- **守卫必须可被行为验证**：任何"检查器代码"（gate / verifier）若只能通过 grep 源码文本来验证，
  它就已经是假绿的候选 —— 判据要么可直调（如 `--entry-class`），要么由真跑命令的 bats 覆盖。
- **核错对象 = 假绿的高发形态**：`verify-claims` 的两次返工（基线写死 → 工件 id 写死）同源，
  共性判据：**任何"回退到某个默认对象"的解析逻辑，都要问"它会不会核到别的对象上"**。
