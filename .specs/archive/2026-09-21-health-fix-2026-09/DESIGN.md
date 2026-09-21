# DESIGN: 堵住三个门禁盲区（打包件新鲜度 / lint 文件域 / exec 判据）

- **Change ID**: health-fix-2026-09
- **关联**: `@.specs/health-fix-2026-09/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@.specs/ARCHITECTURE.md`、`@.specs/health/2026-09-20-HEALTH.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0₋. 架构级变更预检

**未命中**。依据 0-change 步骤 0.4.1 的 5 条判定逐条核对：

| 命中条件 | 本次 | 说明 |
|---|---|---|
| ① 影响项目级模块结构（新增/拆分/合并/删除模块） | ❌ | 不新增模块，只在既有 Makefile / `sync-hooks.sh` / `package-dsh-plugin.sh` 内加"检查"逻辑 |
| ② 影响 ADR（冲突或新增不可逆决策） | ❌ | 与 ADR-001…009 无冲突；本 change 新增的 ADR-010 是**门禁哲学**记录，不改架构拓扑 |
| ③ 改公共契约（API / 事件总线 / Schema） | ❌ | `make` target 面新增一个（`check-dist`），属仓内开发接口，非跨模块契约 |
| ④ 影响容量边界 | ❌ | 无 |
| ⑤ 跨服务编排（容器化 / 上云 / 多区域） | ❌ | 无 |

→ 直接进步骤 0。**CHANGE.md 中未出现「架构层影响声明」段，与此判定一致。**

---

## 0. 技术栈选定

> 由 2-design 步骤 0 锁定。变栈视为开新 CHANGE（R7.1）。

- **选定**：**沿用既有栈，不引入任何新依赖**（CONTEXT.md「技术栈（团队级默认 / 已锁定）」已锁）
- **语言/运行时**：Bash（`set -euo pipefail`）
- **构建**：GNU Make（`Makefile`）+ 既有 `package-dsh-plugin.sh`
- **测试**：bats-core 1.13.0（`npx bats`，基线 950 用例）
- **静态分析**：shellcheck 0.9.0（已装）
- **关键依赖**：仅用 **coreutils 既有命令**（`cmp` / `find` / `diff` / `comm`）与已装工具；**不引入 jscpd / knip / 任何 npm 包**
- **理由**：本 change 修的是"检查器判据"，属 Build/Verification 层，落点在既有三个脚本的内部。AC-1 的性能要求（≤2s）经实测余量极大（**13ms**，见 §2.3），无需引入新工具链。
- **明确排除**：
  - ❌ **引入通用"构建产物新鲜度"框架**（如 ninja / bazel 式依赖图）——杀鸡用牛刀，本仓只有一个 dist
  - ❌ **用 mtime 判新鲜度**——不可靠（`cp`/checkout 会改 mtime 而不改内容，本仓 2026-09-20 即被此误导一次），且 AC-1 的 Given 是"改源不重建"，mtime 与内容两条路都可行但内容更严格

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 出来的实际清单）：
- Makefile                              （既有 · 门禁总入口：lint / check / check-dist / check-hooks-sync …）
- sync-hooks.sh                         （既有 · hooks 副本漂移 + exec 判据实现；本次改动其 exec 判据域）
- package-dsh-plugin.sh                 （既有 · dist 组装；本次给它加 --check 模式）
- verify-claims.sh                      （既有 · 声明机械复验；**F6 新增触碰** —— L2 盲审 R3 查出它与本 change 强耦合，见 §5 R8）
- flow-kit-bundle/hooks/stop/lib/common.sh（既有 · 提供 HOOK_MODULE_NAMES 单一事实源，只读复用）

新增：
- 无新增**生产**脚本文件（见 D2：复用既有脚本承载新检查，避免跨文件重复映射表）
- `.specs/health-fix-2026-09/verify/ac*.sh`（**验证夹具**，非产品代码）—— REQUIREMENT AC-8 要求 AC-1/3/4/5/6 的验证脚本落盘，由 3-task 纳入 write_files

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/**         运行时逻辑（本 change 只碰检查层；hooks 内容零改动）
- flow-kit-bundle/flow-kit/prompts/** 提示词
- flow-kit-bundle/skills/**        双载体（TD-025，明确排除）
- flow-kit-bundle/brooks-lint/**  · brooks-tools/**  第三方，不检查不改动
- dsh-flow-kit/lib/*.js            插件运行时（只读用于比对，不修改）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 门禁入口 / target 编排 | `Makefile` | **沿用**：新增 `check-dist` target 并挂进 `check` |
| 内容比对 | coreutils `cmp` | **沿用**（零依赖、按字节） |
| 生产脚本枚举 | `find` + 既有排除惯例 | **沿用**（与 M-health 步骤 2.6 / jscpd ignore 同款排除集） |
| dist ↔ 源 映射表 | `package-dsh-plugin.sh` 第 1-5 步已有的 `cp` 映射 | **沿用**：`--check` 读同一份映射，**禁止另写一份**（见 D2/R4） |
| "哪些是真入口"清单 | `common.sh::HOOK_MODULE_NAMES`（stop 模块）+ pre-tool-use 3 入口 | **沿用 + 补白名单**（见 D6） |
| 告警输出体例 | `sync-hooks.sh` 既有 `⚠️/❌/✅` 前缀 + 「跑 install.sh 修」提示 | **沿用**风格 |
| 工具缺失优雅降级 | 既有惯例（工具未装 → 打印原因 + `exit 0`） | **沿用**（`make dup` 的 jscpd 处理为范式） |

### 0.5.3 沿用模式 vs 引入新模式

```
- 门禁实现载体：**沿用**「Makefile target → bash 脚本」两段式（check-validate / check-test-sync
  / check-hooks-sync 全是这形状）。本 change 的 check-dist 亦然。
- 判据实现位置：**沿用**「与它守护的产物同源」原则 —— dist 的检查放进负责组装 dist 的
  package-dsh-plugin.sh（同 sync-hooks.sh 自己检查自己的副本一样）。
- 比对语义：**沿用** `sync-hooks.sh --check` 的「内容漂移 + 反向残留」双判据，不另立语义。
- 权限位（mode）：**引入新约定** —— 本 change 明确**不比对 mode**，只比内容与存在性。
  理由：构建时**有意** chmod（package-dsh-plugin.sh:135-138），源与 dist 的 mode 本就不同；
  比对 mode 会制造永久假红。这条要写进脚本注释，否则后来者会"顺手补上"。
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| **D1** | **新鲜度判据 = 内容比对（`cmp`），不依赖时间戳** | ① mtime 比对 ② 全量重建后 diff ③ 记录构建时 HEAD sha | ① mtime 不可靠：`cp`/checkout 改 mtime 不改内容——**本仓 2026-09-20 正是被它误导**（17 个源文件 mtime 新于 dist 但内容全等）；② 重建有副作用（改工作区）且慢，违反"NFR 性能"；③ `dist/` 被 gitignore，构建时 HEAD 需额外落盘一个状态文件，引入新状态面。`cmp` 直击本质："dist 里这份内容是不是当前源的那份" | 需遍历比对（实测 13ms，可忽略）；无法回答"dist 是几次构建前生成的"（不需要） |
| **D2** | **`--check` 模式加在 `package-dsh-plugin.sh` 内，不新建脚本、不在 Makefile 里重写映射** | ① 新建 `check-dist.sh` ② Makefile inline 写映射 | ①/② 都会把"哪个源目录 → dist 哪个子目录"这份**映射表复制成第二份**；映射一变两份就漂移，直接违反 R2（变更传播）。放进组装脚本内 = **单一事实源**，且镜像 `sync-hooks.sh --check` 的既有形状 | `package-dsh-plugin.sh` 变长（+约 60 行）；Makefile target 只是薄壳（`@bash package-dsh-plugin.sh --check`） |
| **D3** | **`vendor/` 的比对包含 `test/`** | 排除 `vendor/**/test/**` | 包含才能覆盖 2026-09-20 真实发生的"vendor 测试快照陈旧"（6 改 + 1 缺失）。排除等于留一个已知会发霉的角落 | `test/` 双源由 `make test-sync` 维护 → **操作顺序变为"先 test-sync 再重建 dist"**；顺序错时 check-dist 会红（**这正是想要的提醒**，且失败信息会指名文件，不会误导到无关处） |
| **D4** | **exec 判据：只对"真入口"要求 `-x`；且检出时逐条指名路径** | ① 保持按目录判定（现状） ② 直接删掉该检查 | ①是**判据过宽**：`pre-tool-use/` 下 4 个库只被 `source`（实测零直接调用点），却要求 `-x` → 长期 1 条假告警，训练人忽略它。②更糟：真入口丢 exec 位将无人发现。"按契约判定 + 指名"同时消灭假阳性与假阴性 | 需要维护"真入口"清单（缓解见 D6） |
| **D5** | **exec 告警维持 advisory（不升级为 fail），但必须逐条指名文件** | 升级为 `root_fail=1`（非零退出） | AC-6 的预检实测：当前告警**连文件名都没有**（只有 `⚠️ 5 个 hook 入口缺可执行位`），维护者拿到计数也无法处置 → **先补"指名"这个信息缺口**。至于是否 fail：`check-hooks-sync` 比对的 7 个镜像根里含 `~/.claude/hooks`、`~/.config/opencode/hooks` 等**用户环境目录**，其权限受 install.sh 与用户操作影响；升级为 fail 会让"用户环境权限差异"阻塞本仓 CI，**误红风险高于收益**。故保持 advisory，把"能否修"留给维护者判断 | 真入口丢 exec 位**不会**让 CI 变红（依赖维护者看告警）。**补偿**：因 D4 消除了假阳性，此时"出现告警"本身就是强信号（从"常态噪声"变为"罕见事件"） |
| **D6** | **"真入口"清单的单一事实源 = `common.sh::HOOK_MODULE_NAMES` + 显式 pre-tool-use 入口白名单（写在 `sync-hooks.sh` 内）** | ① 新增一个独立清单文件 ② 按"是否有 exec 位"反推 | ①多一个会漂移的文件；②循环论证（用被检查对象的属性定义判据）。`HOOK_MODULE_NAMES` 已是 stop 模块的既有单一源（`install_hooks.sh` 也用它），pre-tool-use 只有 3 个稳定入口，直接在白名单里列名并在注释里写明"新增入口必须登记此处"，与 R4 风险缓解对应 | 拆分/新增 pre-tool-use 入口时需同步白名单（**已在注释里显式要求**，且 §5 R4 登记） |
| **D7** | **`make lint` 文件域：`find` 枚举全部生产 `.sh`，排除集显式可读** | ① 手工补 4 个路径到既有 glob ② 用 `$(shell find …)` | ①下次再加目录又会漏（**判据过窄的复发模式**）；②`make` 的 `$(shell)` 展开与转义脆弱、难维护。改为 recipe 内 `find` 循环，排除集写成一个可见清单 | recipe 变长；`find` 每次执行有开销（实测毫秒级） |
| **D8** | **error 级门禁语义不变：扩面后仍只拦 error，warning 不升级为 fail** | 把 warning 也设为 fail | 见 CONTEXT「已锁决策 2026-09-20」：warning 池含 22 处 SC1090（shellcheck 无法跟踪动态 `source`）等 known-acceptable；升级为 fail → 门禁长期红 → 被绕过 → **可信度归零，比没有更糟**（承接 TD-023 既定判定） | 扩面带来的 5 处 warning 只"可见"不"阻塞"。**收益仍在**：它们从"从不被扫描"变为"每次 lint 都出现在输出里" |

## 2. 数据流 / 架构图

### 2.1 三个门禁的落点（本 change 后）

```
                     ┌──────────────────── make check ────────────────────┐
                     │                                                    │
  make test ─────────┤  （既有 · 950 用例）                                │
  make lint ─────────┤  （F2 改：find 枚举全部生产 .sh · error 级门禁）      │
  make check-validate┤  （既有 · 打包覆盖对账）                            │
  make check-test-sync┤ （既有 · test/ ↔ bundle/test/）                    │
  make check-hooks-sync┤（F3 改：exec 判据按真入口 + 逐条指名）             │
  make check-dist ───┘  （F1 新增 · 新鲜度）                              │
                     └────────────────────────────────────────────────────┘

  check-dist 数据流（F1）：
    package-dsh-plugin.sh --check
       │
       ├─ 读「构建时同一份映射」（第 1-5 步的 cp 列表）  ← 单一事实源（D2）
       │
       ├─ 正向：源 → dist   逐文件 cmp
       │     lib/ ← dsh-flow-kit/lib/
       │     skills/ flow-kit/ hooks/ brooks-lint/ ← flow-kit-bundle/<同名>/
       │     docs/ ← bundle 两份 md + 仓根 ecosystem-guide
       │     package.json cordis.patch.yml README.md DESIGN.md ← dsh-flow-kit/
       │     vendor/flow-kit-bundle/ ← flow-kit-bundle/（含 test/ · D3）
       │        │
       │        └─ 任一处内容不等 → 「陈旧」+ 指名路径 → exit 1
       │
       └─ 反向：dist 有、源已无 → 「反向残留」+ 指名路径 → exit 1
                                        （沿用 sync-hooks.sh 既有语义）
    不比对：mode/权限位（构建时有意 chmod · D5/0.5.3）
    dist 不存在 → 提示「请先跑 package-dsh-plugin.sh」→ exit 0（优雅降级）
```

### 2.2 exec 判据的契约边界（F3）

```
pre-tool-use/ 目录（7 个 .sh）
  ├── 真入口（要求 -x）：
  │     independent-review-gate.sh   ← 被 settings.json 直接 bash 调用
  │     auto-checkpoint.sh           ← 同上
  │     runtime-edit-guard.sh        ← 同上
  └── 库（不要求 -x · 只被 source）：
        gate-helpers.sh          ← 被 independent-review-gate.sh source
        gate-helpers-types.sh    ← 被 gate-helpers.sh source
        gate-checks-basic.sh     ← 被 independent-review-gate.sh source
        gate-checks-review.sh    ← 被 independent-review-gate.sh source

stop/ 目录：主模块 = 真入口（HOOK_MODULE_NAMES 单一源）；stop/lib/** = 库（豁免）
session-start/ · pre-commit/：全部为真入口
```

### 2.3 实测预检（本设计的可行性依据）

| 项 | 实测 | 对应 |
|---|---|---|
| `cmp` 能否发现"改源不重建" | ✅ 能（改 README 后 `cmp` 立即不等） | D1 |
| 全量内容比对耗时 | **13ms**（4 条 `diff -rq` 覆盖 vendor/lib/hooks/skills） | NFR 性能 ≤2s，余量 ~150× |
| `make check`（含 `make test`）总耗时 | 约 60–120s（**pre-commit hook 会调它**） | NFR 性能：新门禁不得成为可感知负担 → 13ms 可忽略 |
| 假设 A1（dist 纯派生） | ✅ 成立：`package-dsh-plugin.sh` 全是 `cp` + `chmod` + `.DS_Store` 删除，**0 处内容改写**（`grep -cE 'sed -i|awk …>'` = 0） | REQUIREMENT 假设 A1 确认 |
| 真入口 exec 判据现状 | 摘掉真入口 exec 位后：退出码 0 · 文件名字出现 **0** 次 · 计数仍 5 | D4/D5 的直接依据 |

---

## 3. 关键状态机（如有）

**无新增状态机。** 三个门禁均为无状态的一次性判定（跑完即退出），不引入跨调用持久状态 —— 这也是刻意选择：`dist/` 被 gitignore、无状态文件可存，且 D1 已排除"记录构建时 sha"的方案（那会引入状态面）。

**唯一的状态耦合**：`check-dist` 的通过与否依赖"`test-sync` → 重建 dist"的操作顺序（D3）。这不是状态机，是**线性前置条件**，在失败信息中显式提示。

---

## 4. ADR 索引

| ADR | 标题 | 状态 | 对应决策 |
|---|---|---|---|
| **ADR-010** | 门禁只保证「看不见的变可见」，不改变红绿语义 | 新增（accepted） | D8（并约束 D5 选择 advisory 而非 fail） |

**未新增 ADR 的决策及理由**：D1（内容比对 vs mtime）、D2（`--check` 放哪）、D3（vendor test 是否纳入）、D4/D6（exec 判据与单一源）、D7（find 枚举）均为**本 change 内可逆的实现取舍**，推翻成本低（改一个脚本的几十行），按"大的或可逆性低的决策才有 ADR"的标准不必立 ADR。D8 例外 —— 它锁定的是**判据哲学**，会被后续 health-fix 反复引用，且推翻意味着重新辩论门禁语义，故立 ADR-010。

**与既有 ADR 的关系**：与 ADR-001…009 **无冲突、无 supersede**。ADR-010 与 ADR-005（独立审查体系 L2+L3）正交：后者管"审查强度"，前者管"检查器把什么当失败"。

---

## 5. 风险

| # | 风险 | 类型 | 缓解 |
|---|---|---|---|
| **R1** | **门禁变严立刻变红**：`make lint` 扩面后，4 个此前漏扫文件中的 5 处 warning 会首次出现在输出里。若误把 warning 也当失败，`make check` 当场红 | 实现风险 | D8 已定案：**保持 error 级语义**，扩面只影响"看得见"不影响"红绿"。AC-7 显式要求 `make lint` error=0 且 `make check` 全绿。测试阶段必须实测"扩面后仍绿" |
| **R2** | **`check-dist` 造成永久假红**：dist 与源的 `mode` 本就不同（构建时有意 `chmod +x`，`package-dsh-plugin.sh:135-138`），若比对权限位则永远不等 | 上线风险 | 0.5.3 + D5 已锁定**只比内容不比 mode**，并**要求在脚本内写注释说明为何不比**（防止后来者"顺手补上"）。AC-2 就是这个风险的验收线 |
| **R3** | **`check-dist` 纳入 `make check` 拖慢提交**：`make check` 由 pre-commit hook 调用 | 上线风险 | 实测全量比对 **13ms**（vs `make test` 的 60–120s），占比可忽略。AC/NFR 已设 ≤2s 门槛，实测有 ~150× 余量 |
| **R4** | **"真入口"清单漂移**：后续拆分/新增 `pre-tool-use` 入口却忘了登记白名单 → 新入口丢 exec 位不被发现（判据过窄复发） | 长期债务 | D6：白名单内嵌 `sync-hooks.sh` 并**在注释中显式写"新增入口必须登记此处"**；同时该文件的 exec 检查逻辑集中在 `:184-193` 单点，便于 review。**残余风险如实登记**（见 §6） |
| **R5** | **D3 的操作顺序耦合**：改了 `test/` 但没跑 `test-sync`、或跑了 `test-sync` 但没重建 dist → `check-dist` 红，而失败信息可能被误读为"dist 坏了" | 实现风险 | 失败信息**逐条指名文件路径**（含 `vendor/.../test/`），并在输出末尾提示正确顺序「先 `make test-sync`，再 `bash package-dsh-plugin.sh`」。TEST 阶段专门造这个场景验证提示可读 |
| **R6** | **`cmp` 在不同平台的行为差异**（GNU vs BSD coreutils） | 兼容性 | 仅用 `cmp -s`（POSIX，两平台语义一致），不用 GNU 专属选项。本仓既有 `sync-hooks.sh` 已用 `cmp -s`（`:180,225,290`），**沿用同款**即有先例背书 |
| **R7** | **扩面后 `find` 把非生产脚本扫进来**（如 `.specs/` 下的 `probe-cross-env.sh`、`.claude/skills/` 下第三方脚本）→ 引入无关 error，门禁被噪声污染 | 实现风险 | 排除集显式可读（D7），与 M-health 步骤 2.6 / jscpd ignore 的**既有排除集对齐**（`node_modules`/`.git`/`brooks-lint`/`brooks-tools`/`.claude/plugins`/`dist`/`.omo`/`.specs`）。TEST 阶段用"扫描清单快照"断言：既断言 **7 个**漏扫脚本（路径级，勿用 basename 去重，见 R10）**进来了**，也断言排除项**没进来** |
| **R8** | **`verify-claims.sh` 与本 change 强耦合**（L2 盲审 R3 追加）：其 `:165` 硬编码断言「make check 五门全绿」，F1 加门后**必然变假** → 脚本必红 → AC-7 的 F4 按现范围不可达。且它已因 2026-09-20 归档动作**处于失败态**（`:123`/`:137`/`:158` 三处硬编码已归档的 change 目录 → 实测 11✅/2❌） | 实现风险 → 已消解 | 已纳入 v1 的 **F6**：(a) 三处路径改 live→archive 解析；(b) 门数从 `Makefile check:` 依赖动态推导。**已实测**：exit 0 · 13✅/0❌ · 输出「make check 5 门全绿」（加门后自动变 6，无需改脚本） |
| **R9** | **F3 的 exec 判据域与本 change 自述不符**（L2 盲审 R1 追加）：`sync-hooks.sh` 的 `DEST_ROOTS` 只含 7 个**镜像根**，exec 判据只作用于镜像副本；**源 bundle 不在判据域内**。而 AC-6 初稿把探针指向**源** → 该 AC 按 v1/F3 范围**永远不可能通过**，照此实现会交付一个"改了但 AC 仍红"的门禁 | 实现风险 → 已消解 | ① AC-6 探针改打**镜像副本**（实测 5→6，判据确实看得见）；② F3 范围**收敛**为「收窄判据域 + 检出时逐条指名」，**不扩张判据域到源**（那属未登记的范围扩张）。见 §6 遗留登记 |
| **R10** | **需求文本的"文件计数"被 basename 去重污染**（L2 盲审 R4）：`regression-demos/*/check.sh` 是 4 个同名文件，按 basename 去重会压成 1 个 → "7 个漏扫脚本"被误写成 "4 个"。该误已污染 CHANGE.md 与 US-2 | 长期债务（文档口径） | AC-4 改为**路径级集合差**验证，并显式警示"不得用 basename 去重"；REQUIREMENT 正文统一为 **7 个**。**通用教训**：涉及"同名多份"的计数一律用路径级，不用 basename |
| **R11** | **写需求时引用了已被自己破坏的基线**（L2 盲审 R2/R3）：AC-2 用 `git status --porcelain` 代理 dist 新鲜（git 对 dist 结构性失明 = 本 change 要堵的盲区，属循环论证）；AC-7 抄了本会话早期输出当 `verify-claims` 基线（该输出在归档后已失效） | 实现风险 → 已消解 | AC-2 去掉 git 代理 + 实施前先重建 dist 使 Given 真实成立（**已完成**，vendor↔bundle 差异 0）；AC-7 基线修正为实测值。**通用教训**：跨动作的基线必须**当场重测**，不得转抄早期输出 |

## 6. 不在范围

**与 REQUIREMENT「v2 / out」一致，此处只补充实现层不解决的问题：**

- **不做** `prompts ↔ skills` 同步门禁（TD-025）—— 需先定产品判断（镜像 or 允许差异）
- **不做** `test/**.bats` 硬编码 `.specs/<change-id>/` 的 lint 告警（2026-09-20 `ac47f85` 沉淀的候选）
- **不做** `corpus-count.sh:22` 默认输出路径修正（已记 LESSONS）
- **不做** 任何 warning → fail 的升级（ADR-010 + D8）
- **不做** 对第三方目录的检查
- **不做** dist 的清理类装饰项（v0.1.0 历史 tarball、vendor mode 逐位对齐）
- **明确遗留（如实登记，不假装解决）**：**R4 的"真入口清单漂移"本 change 只做缓解不做根除** —— 根除需要一个"从 hook 调用点自动反推真入口"的机制（读 `settings.json` / `hook-bridge.js` 的调用清单），成本远超本 change 范围。**本 change 交付的是"判据正确 + 假阳性消除 + 检出时指名"，不是"清单永不漂移"。** 后续若发生 R4，应作为独立 change 处理。

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

**不入选**。本 change 未新建 `lib/`-类可复用文件（D2 刻意不新建脚本）。`package-dsh-plugin.sh --check` 与 `sync-hooks.sh` 的 exec 判据都是**单一消费者**的专用逻辑，写不出 2 个其他使用场景。按 §9.1 阈值不入选。

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 建议写入 |
|---|---|
| **ADR-010 · 门禁只保证「看不见的变可见」，不改变红绿语义** | ARCHITECTURE.md §3 ADR 列表（编号 010，最大编号 009 → 010）+ CONTEXT.md「已锁决策」 |
| **派生产物新鲜度必须机器可验**（新增任何 `dist/`-style 生成物时，必须同步提供新鲜度门禁） | CONTEXT.md「已锁决策」 |

### 9.3 新增 / 修改的跨模块契约（API / Schema / 事件总线）

| 契约 | 内容 | 建议写入 |
|---|---|---|
| `make check-dist` | 新增 target，**已纳入 `make check`**；退出码 1 = dist 陈旧或有反向残留；dist 不存在时 exit 0 + 提示 | CONTEXT.md「既有抽象索引」+ ARCHITECTURE.md（若描述构建流程） |
| `package-dsh-plugin.sh --check` | 新增模式：只读检查，不重建、不改工作区 | 同上 |
| "真入口"契约 | `pre-tool-use/` 下 3 入口要求 `-x`；被 source 的库豁免。**新增入口必须登记 `sync-hooks.sh` 白名单** | CONTEXT.md 域语言（已加「真入口」术语）+ 禁动清单旁注 |

### 9.4 新增 / 升级的依赖

**无。** 刻意零新依赖（§0），符合本仓"纯 bash + 已装工具"的既有约束。

### 9.5 禁动清单变化

| 变化 | 内容 |
|---|---|
| **建议新增（禁动）** | `dist/**` 视为**只读派生产物** —— 禁止手工编辑 dist 内任何文件；一切改动必须改源后重建。理由：本 change 的 check-dist 会把它当"必须与源一致"的产物，手改 dist 会立刻红且无法通过重建修复 |
| **建议新增（提醒）** | 修改 `flow-kit-bundle/hooks/pre-tool-use/` 的**新增入口**必须同步 `sync-hooks.sh` 真入口白名单（否则 exec 判据漏检） |
| 解禁 | 无 |

---

> 后续 TASK 拆解与实现细节以本文件为准；本文件不再扩展。
