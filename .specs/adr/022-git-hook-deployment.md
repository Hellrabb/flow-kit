# ADR-022 · git hook 部署策略（symlink to .git/hooks/）

> 来自 change `archive-commit-gate` 阶段 2 DESIGN D1

## Context

flow-kit 需部署 git pre-commit hook 实现 commit 时测试门禁（闭合 LESSONS L-023「commit-time 测试门禁缺失」）。

git hook 部署位置有三选：

1. `git config core.hooksPath <dir>`（全局覆盖 · git 只读该目录的 hook）
2. 直接复制 hook 文件到 `.git/hooks/`
3. symlink `.git/hooks/<hook-name>` → 源文件

## Decision

**选方案 3：symlink `.git/hooks/pre-commit` → 已安装 hooks 目录（user: `~/.claude/hooks/pre-commit/pre-commit.sh` / project: `.claude/hooks/pre-commit/pre-commit.sh`）**（L2 v2 F4 修复：原指 `flow-kit-bundle/` 源目录，目标项目无此目录→悬空 symlink）。

每项目部署（install.sh 按项目跑时执行）。

## Consequences

### 优点

- **最小侵入**：只注入 `pre-commit` 一个文件，不碰 `.git/hooks/` 下用户既有 hook（方案 1 core.hooksPath 会全局覆盖致用户自定义全失效）
- **版本同步**：symlink 指向 flow-kit 源，版本随 flow-kit 更新自动同步（方案 2 复制需重装）
- **幂等部署**：install.sh 重复跑检测 symlink 已存在则跳过（方案 2 需 diff 比对）

### 代价

- **每项目单独部署**：install.sh 已按项目跑，成本可接受；user-scope 安装时通过 `--project <path>` 参数指定目标项目（L2 v2 F4 修复：原 `--deploy-pre-commit` install.sh 零命中）
- **Windows 兼容**：Git for Windows 下 symlink 需开发者模式或管理员权限；install.sh 检测 `$OSTYPE` 含 msys → fallback 复制方案 + 文档标注

## Alternatives Considered

### 方案 1 · core.hooksPath（否决）

`git config core.hooksPath ~/.claude/hooks/`

- ❌ 全局覆盖：用户 `.git/hooks/` 下既有 hook 全失效（破坏性）
- ❌ flow-kit 的 Stop/SessionStart hook 也在 `~/.claude/hooks/`，git 不会调它们（git 只认 pre-commit/post-commit 等固定文件名），但混放增加认知负担

### 方案 2 · 直接复制（否决）

`cp flow-kit-bundle/hooks/pre-commit/pre-commit.sh .git/hooks/pre-commit`

- ❌ 版本失同步：flow-kit 更新后需重装
- ❌ 与用户 `.git/hooks/` 文件混在一起难管理

## References

- REQUIREMENT.md AC-2（pre-commit make test 硬门禁）
- REQUIREMENT.md AC-4（install.sh 部署 + 向后兼容）
- DESIGN.md D1

---

## Superseded-by（部分 · 2026-09-23 · change `health-fix-2026-09b`）

> **本段为追加**：ADR-022 上方 Context / Decision / Consequences / Alternatives Considered / References
> 的**全部原有正文一字不动**（不删除、不改写、不重排）。本段只**追加**一条**部分** supersede 声明。
> **判据出处**：`.specs/health-fix-2026-09b/DESIGN.md` 的 **D3 item 3**（声明口径与代价）·
> `.specs/health-fix-2026-09b/REQUIREMENT.md` 的 **AC-3**（含 R5 订正段）。

- **Superseded by**: **部分** —— change `health-fix-2026-09b` · **2026-09-23** · 理由：AC-3 要求推送拦截
  （`pre-push` 注入面）。**受影响的仅「Decision 的实现范围」一个维度**；
  **载体（symlink）与幂等部署语义不变**，ADR-022 的 Decision 其余部分继续有效。
  "部分"的确切边界见下 §超集范围 与 §不变项。

### ① 理由 · AC-3 要求推送拦截

- REQUIREMENT 的 **AC-3**（「泄漏分支无法被误推 · P1 · v1 范围」）要求对四种 push 形态
  （① 单 ref ② `--all` ③ `--mirror` ④ `--tags`）**在推送阶段拦截**含泄漏 ref 的推送，并给出可读原因；
  该 AC 把拦截载体**显式裁决为 `pre-push` 钩子**。
- 仅靠本 ADR 原 Decision 的 `pre-commit` 注入**无法满足 AC-3** —— `pre-commit` 只在本地提交时跑测试门禁，
  推送路径不经过它。⇒ 必须**新增 `pre-push` 注入面**，这正是本节要声明的对 ADR-022 的偏离。
- **偏离必须显式声明而不能默默发生**：`ADR-022` 原文（`022-git-hook-deployment.md:25`，`### 优点` 小节首条）
  写的是「**最小侵入**：只注入 `pre-commit` 一个文件，**不碰 `.git/hooks/` 下用户既有 hook**」。
  新增 `pre-push` 注入 = **该优点被部分削弱**。若照 REQUIREMENT 初版的字面禁令（「不得采用同类
  不可复现载体」）执行，等于**未经声明地** supersede `ADR-022` ⇒ 故 REQUIREMENT 的 **R5 订正段**
  已把口径改为与 `ADR-022` 一致（`pre-push` **沿用** symlink 机制；"可复现"重定义为
  「`install_hooks.sh` 部署 + `sync-hooks.sh --check` 校验」，**不是**"clone 即有"），
  并由**本段**把该偏离落成一条可检索的 `Superseded-by` 声明。

### ② 范围 · 仅扩展「注入面」

- **被扩展的**：注入面从 `pre-commit` **一个**文件扩展到 `pre-commit` + `pre-push` **两个**文件
  （`symlink .git/hooks/pre-push` → **已安装** hooks 目录，由 `install_hooks.sh` 部署、
  `sync-hooks.sh --check` 校验；依据 `DESIGN.md` 的 **D3** 决策行与 **D3 item 6** 的落地触点）。
- **不变的（ADR-022 原有承诺继续有效，逐条对应原文）**：

  | ADR-022 原有承诺 | 本 change 后 | 说明 |
  |---|---|---|
  | **方案 3 = symlink 载体**（原文 `## Decision`，`022-git-hook-deployment.md:17`） | **不变** | `pre-push` **沿用**同一 symlink 机制，不改为复制、不引入 `core.hooksPath` |
  | **版本同步**（symlink 指向 flow-kit 源 ⇒ 随更新自动同步） | **不变** | 新增的 `pre-push` 同为 symlink ⇒ 享有同一性质 |
  | **幂等部署**（重复跑检测 symlink 已存在则跳过） | **不变** | 幂等条件仍是「按**载体语义**判定是否已安装位 symlink」，非按内容 grep |
  | **Windows fallback**（`$OSTYPE` 含 msys ⇒ fallback 复制 + 文档标注） | **不变** | 未新增平台假设 |
  | **不采用方案 1 / 方案 2** | **不变** | 两个已被否决的方案**不因本 change 复活** |

- ⇒ 本节**只** supersede 上表以外的那**一个**维度（"只注入一个文件、不碰既有 hook"）。除此之外，
  `ADR-022` 的 Decision 与 Alternatives Considered **继续有效**，本 change 未静默推翻任何一条。

### ③ 代价 · 必然触碰 `.git/hooks/` 下用户既有 hook ⇒ 备份 + 告知 + 可回滚

- **代价是必然的**：新增注入面即意味着部署时要**在 `.git/hooks/` 下落 `pre-push`** ——
  而该路径**可能已被用户自己的 hook 占用**（本仓即为活例：`.git/hooks/pre-push` **已存在**为
  373 B 的**普通文件**（非 symlink），内容为 `make check`）。这与 ADR-022 原文的「不碰用户既有 hook」
  直接冲突，**故必须显式承担**：安装器在任何非 flow-kit 载体上落 `pre-push` 前
  **先备份**（`cp <hook> <hook>.bak.<ts>`），并在**安装输出中告知备份路径**，使用户可回滚。
- **"告知"必须是可观测的输出而非文档承诺**：依据 `DESIGN.md` 的 **D3 item 2**，
  该 `echo`（打印备份路径）**落在定稿代码块里**；备份/覆盖失败**不得静默**
  （`|| { echo …; return 1; }`）。
- **回滚路径**：用户以告知的备份路径恢复原 `pre-push` 即回到本 change 之前的行为
  （幂等判据只认「已安装位 symlink」，故恢复后的普通文件不会被二次覆盖 —— 再次安装时会重新走"备份 + 覆盖"分支）。
- **本节的边界（不夸大）**：本段是**声明**，不是实现 —— 备份/告知/回滚的**实现与实跑验证**
  由 change `health-fix-2026-09b` 的对应 task 落地；本段只负责让「`ADR-022` 被**部分** supersede」
  这件事**在 ADR 层可见、可检索、可审计**。

### 依据与核对

- **依据**：`.specs/health-fix-2026-09b/DESIGN.md` 的 **D3**（决策行 + item 3「显式声明对 ADR-022 的
  部分 supersede」）· `.specs/health-fix-2026-09b/REQUIREMENT.md` 的 **AC-3**（含 R5 订正段）。
- **行号核对**：本段引用的 `022-git-hook-deployment.md:17`（`## Decision` 内「选方案 3：symlink」句）
  与 `022-git-hook-deployment.md:25`（`### 优点` 内「最小侵入：只注入 `pre-commit` 一个文件」句）
  已**实测核对**（行号与内容锚点成对）。**未核实的行号一律不写** —— 需要指称其它位置时只给
  **小节名 + 文件路径**（如「`## Decision`」「`### 优点`」「`### 代价`」「`## Alternatives Considered`」）。
- **本 ADR 的 `Status` 字段**：`ADR-022` 头部**原本没有** `**Status**` / `**Superseded by**` 字段
  （其头部形态为标题 + `> 来自 change …` 引用行），故本段以**文末小节**形式承载该语义，
  而**不**回头向上改写头部（改写头部即违反「只追加」约束）。
