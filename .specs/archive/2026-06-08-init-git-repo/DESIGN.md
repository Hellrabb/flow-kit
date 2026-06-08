# DESIGN: 初始化 Git 仓库并建立脚本设计文档与技术债跟踪体系

- **Change ID**: `init-git-repo`
- **关联**: `@.specs/init-git-repo/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> CLI Bash 项目 — 跳过技术栈选型（2-design 步骤 0 例外条款）。直接锁定既有栈。

- **语言/运行时**: Bash 4+（`#!/bin/bash`，`set -euo pipefail`）
- **构建/打包**: tar + gzip（`tar -czf`），无外部构建工具
- **文件同步**: rsync（跨机器部署 flow-kit 核心）
- **版本控制**: Git 2.x（本次引入）
- **代码质量**: brooks-lint（已装，本次用于基线扫描）
- **理由**: 延续 CONTEXT.md 已锁决策。本项目是纯 Shell 脚本分发工具，无前端/后端/数据库，无需引入新语言或框架。
- **明确排除**: Docker 容器化部署（v2 考虑，v1 无此需求）、GitHub Actions CI（v2 考虑）

---

## 0.5 既有架构对齐（brownfield · B2 护栏）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（实际文件清单）：
- package-flow-kit.sh（只读 · 分析结构后写入 DESIGN.md，不修改代码）
- .specs/CONTEXT.md（更新 · git 信息 + 提交规范）
- .specs/STATE.md（更新 · git_repo: true）
- flow-kit-bundle.tar.gz（不触碰 · .gitignore 排除）

新增文件：
- .git/（git init 创建）
- .gitignore
- README.md
- .specs/init-git-repo/DESIGN.md（本文件）
- .specs/LESSONS.md（首次创建 · 技术债基线）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- package-flow-kit.sh 代码（本次只读不写）
- flow-kit-bundle.tar.gz（不重新打包）
- flow-kit-ecosystem-guide.md（不改动）
- ~/.claude/flow-kit/（运行环境，不是仓库资产）
- ~/nanoclaw/.claude/hooks/（Hook 源文件，不触碰）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 脚本架构文档 | 无 — 首次建立 | 新建 DESIGN.md（理由：此前无任何设计文档） |
| 技术债跟踪 | `.specs/CONTEXT.md` § 技术债 已有空位 | 沿用 CONTEXT.md 的技术债段 + 新建 LESSONS.md |
| 版本控制 | 无 — `git_repo: false` | 引入新模式（理由：首次建立版本控制） |
| 提交规范 | 无 — 未建立 | 引入 Conventional Commits（理由：业界标准，brooks-lint 兼容） |
| 错误处理 | `set -euo pipefail`（CONTEXT.md 已锁） | 沿用 — 不影响脚本内部 |
| 命名风格 | kebab-case 文件 / snake_case 函数（CONTEXT.md 已锁） | 沿用 — README / .gitignore 等新文件遵循此约定 |

### 0.5.3 沿用模式 vs 引入新模式

```
- 文件组织：**沿用** `.specs/<id>/` 按 change 归档模式（已有 CHANGE.md / REQUIREMENT.md）
- 错误处理：**沿用** `set -euo pipefail`（所有新增 Shell 逻辑遵循）
- 版本控制：**引入新模式** Git + Conventional Commits → 理由：首次建立，项目无既有 git 模式可沿用
- 文档格式：**沿用** Markdown（所有既有产物均为 .md）
- 命名约定：**沿用** kebab-case（文件）+ snake_case（函数/脚本内标识符）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | 默认分支名 `main` | `master` | 业界迁移趋势；GitHub/GitLab 默认均为 main | 无实际代价，本项目从未有过 git 历史 |
| D2 | 提交格式 Conventional Commits（`feat:` / `fix:` / `docs:` / `chore:` / `refactor:`） | 自由格式 / Gitmoji | 结构化日志可被工具解析（brooks-lint / changelog 自动生成）；不引入 emoji 依赖 | 提交时多写一个前缀词，边际成本极低 |
| D3 | `.gitignore` 策略：排除生成文件 + 敏感文件 | 只排除 bundle / 全量追踪 | 安全底线（防凭据泄露）+ 避免大二进制文件污染 git history | 新增生成文件时需手动更新 .gitignore（频率极低） |
| D4 | DESIGN.md 采用逆向分析模式（从代码反推设计） | 跳过设计文档 / 要求原作者口述 | 原作者不在此上下文；代码即事实源，从代码反推 + 标注"推断"比空文档好 | 部分原始意图可能推断错误，每条推断标注置信度 |
| D5 | 技术债基线用 brooks-lint 自动扫 + 手动补充 | 纯手动盘点 / 纯自动扫描 | brooks-lint 覆盖 review/audit/debt/test 四维度，但对 Bash 项目可能产出偏薄；手动补充确保不遗漏 | brooks-lint 对 Bash 项目的有效发现可能 < 5 条 |
| D6 | 不使用 Git LFS | 使用 Git LFS 管理 flow-kit-bundle.tar.gz | bundle 已被 .gitignore 排除，不需要 LFS；当前无大文件需要追踪 | 若未来需要追踪大二进制文件需重新评估 |

---

## 2. 数据流 / 架构图

### 2.1 package-flow-kit.sh 既有架构（逆向分析 · 本次不对其做任何修改）

```
                         package-flow-kit.sh
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ╔══════════════════════════════════════════════════════════════╗ │
│  ║  PHASE 1: BUNDLE BUILD（打包阶段 · L1-226）                 ║ │
│  ║                                                              ║ │
│  ║  Config Vars                                                  ║ │
│  ║  (OUTPUT_DIR, TIMESTAMP, STAGING)                             ║ │
│  ║        │                                                      ║ │
│  ║        ▼                                                      ║ │
│  ║  mkdir staging/                                               ║ │
│  ║    ├─ flow-kit/        ← git archive (flow-kit repo)         ║ │
│  ║    ├─ skills/          ← cp SKILL.md per skill               ║ │
│  ║    ├─ hooks/           ← cp ~/nanoclaw/.claude/hooks/stop/*   ║ │
│  ║    │   ├─ stop/            + session-start/*                  ║ │
│  ║    │   └─ session-start/   + config/settings.json (heredoc)  ║ │
│  ║    ├─ brooks-lint/     ← git clone (full repo)               ║ │
│  ║    ├─ specs-template/  ← cp STATE.md template                ║ │
│  ║    ├─ README.md        ← heredoc generated                   ║ │
│  ║    └─ install.sh       ← heredoc generated (self-extracting) ║ │
│  ║        │                                                      ║ │
│  ║        ▼                                                      ║ │
│  ║  tar -czf flow-kit-bundle.tar.gz staging/                     ║ │
│  ╚══════════════════════════════════════════════════════════════╝ │
│                                                                  │
│  ╔══════════════════════════════════════════════════════════════╗ │
│  ║  PHASE 2: INSTALLER（安装阶段 · L227-498 · 嵌入 install.sh）║ │
│  ║                                                              ║ │
│  ║  main()                                                       ║ │
│  ║    │                                                          ║ │
│  ║    ├─ MODE=global                                             ║ │
│  ║    │   ├─ install_flow_kit_core()  → rsync → ~/.claude/flow-kit/
│  ║    │   ├─ install_skills()         → cp per skill             ║ │
│  ║    │   └─ install_brooks_lint()    → npm install + build      ║ │
│  ║    │                                                          ║ │
│  ║    ├─ MODE=project                                            ║ │
│  ║    │   ├─ install_hooks()          → cp hooks → .claude/     ║ │
│  ║    │   │   └─ 合并 settings.json hooks 配置                  ║ │
│  ║    │   └─ install_specs_template() → cp .specs template       ║ │
│  ║    │                                                          ║ │
│  ║    └─ HOOKS_ONLY=true                                         ║ │
│  ║        ├─ install_hooks()                                     ║ │
│  ║        └─ install_specs_template()                            ║ │
│  ║                                                              ║ │
│  ║  Helper: install_file() — cp wrapper with dry-run + chmod    ║ │
│  ╚══════════════════════════════════════════════════════════════╝ │
│                                                                  │
│  关键数据流:                                                      │
│    ~/nanoclaw/.claude/hooks/  ──cp──▶  staging/hooks/  ──tar──▶  bundle
│    ~/nanoclaw/.claude/flow-kit/ ──rsync──▶ staging/flow-kit/     │
│    ~/nanoclaw/skills/  ──cp──▶  staging/skills/                  │
│    brooks-lint repo  ──clone──▶  staging/brooks-lint/            │
│                                                                  │
│  边界:                                                            │
│    依赖 ~/nanoclaw/ 本地仓库（源，不可缺失）                      │
│    依赖 ~/.claude/ 目录结构（目标安装路径）                       │
│    不涉及网络（全离线操作，除 brooks-lint git clone）             │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 本次 change 新增结构

```
本次新增:
  .git/                     ← git init 创建（不跟踪自身）
  .gitignore                ← 排除 bundle + 敏感文件
  README.md                 ← 仓库说明
  .specs/LESSONS.md         ← 技术债基线（首次创建）
  .specs/init-git-repo/     ← 本 change 完整产物目录
    ├── CHANGE.md           ✅
    ├── REQUIREMENT.md      ✅
    ├── DESIGN.md           ← 本文件
    ├── TASK.md             （3-task 阶段生成）
    ├── TEST.md             （5-test 阶段生成）
    └── REVIEW.md           （6-review 阶段生成）

现有不变:
  package-flow-kit.sh       ← 只读，不改
  flow-kit-bundle.tar.gz    ← .gitignore 排除
  flow-kit-ecosystem-guide.md ← 不改
  .specs/CONTEXT.md         ← 增量更新（git 信息）
  .specs/STATE.md           ← 更新 git_repo 字段
```

---

## 3. 关键状态机

无。本次 change 不引入运行时状态机。Git 本身的状态模型（working tree → staging → committed）是外部依赖，不属于本次设计范围。

---

## 4. ADR 索引

本次 change 无可逆性低到需要独立 ADR 的决策：
- D1（main 分支）：可逆，`git branch -m` 即可
- D2（Conventional Commits）：可调整，历史 commit message 不改
- D3（.gitignore 策略）：可随时增删
- D6（不用 LFS）：可逆，随时启用

**无 ADR 产出**。

---

## 5. 风险

| # | 风险 | 类型 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|---|
| R1 | `package-flow-kit.sh` 逆向分析出的设计文档与原始意图不符 | 实现风险 | 后续维护者基于错误理解改脚本 | 中 | 每条推断显式标注"从代码推断"，由用户 review 后确认或修正 |
| R2 | brooks-lint 对 Bash 项目扫描产出过薄（< 3 条有效发现），技术债基线形同虚设 | 实现风险 | 技术债跟踪从一开始就失准 | 高 | 若 brooks-lint 产出 < 3 条，强制手动补充 ≥ 3 条已知问题（硬编码路径/重复逻辑/错误处理缺口） |
| R3 | `.gitignore` 遗漏敏感文件模式，导致凭据或密钥被 commit | 上线风险 | 安全事件 | 低 | 使用标准 gitignore 模板（GitHub Bash 模板）+ 追加 `*.key` / `.env` / `credentials*` / `*secret*` |
| R4 | 首次 commit 包含 `flow-kit-bundle.tar.gz`（253KB），污染 git history | 实现风险 | 仓库体积膨胀 | 低 | AC-1 验证方式已覆盖：`git status --short` 确认 bundle 不在 tracked files 中 |
| R5 | 后续维护者不遵守 Conventional Commits，提交历史混杂 | 长期债务 | changelog 自动生成失效，brooks-lint 提交分析不准 | 中 | README 明确写清规范；v2 可加 commitlint hooks 强制执行 |

---

## 6. 不在范围

- 不设置 Git remote（如 GitHub/GitLab）—— v1 纯本地仓库
- 不配置 pre-commit hooks（commitlint / brooks-lint auto-scan）—— v2
- 不生成 CHANGELOG.md（需 commit 历史积累后才值得做）—— v2
- 不修改 `package-flow-kit.sh` 任何代码逻辑
- 不建立分支策略（如 Git Flow / trunk-based）—— 当前单人维护，main 直推即可；多人协作时再定
- 不引入 CI/CD pipeline

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

本 change 无新增可复用代码抽象（仅新增配置文件和文档）。
`N/A`

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| Git 默认分支 | `main` | 所有分支操作 | 低 — `git branch -m` 即可改名 |
| 提交格式 | Conventional Commits | 所有 commit message | 低 — 历史 message 不追溯修改 |
| 敏感文件排除策略 | `.gitignore` 含 `*.key` / `.env` / `credentials*` | 所有 git add 操作 | 低 — 随时编辑 .gitignore |

### 9.3 新增 / 修改的跨模块契约

`N/A` — 本 change 不修改任何跨模块 API / Schema / 事件。

### 9.4 新增 / 升级的依赖

`N/A` — 无运行时依赖变动。Git 是开发环境工具，不在依赖清单。

### 9.5 禁动清单变化

```
新增禁动（建议 append 到 CONTEXT.md「禁动清单」段）：
- flow-kit-bundle.tar.gz — 已由 .gitignore 排除，永远不要 git add
- .gitignore 本身不自动生成 — 手动维护，禁 AI "顺手重写"
```

---

> 本文件不包含完整代码实现。`.gitignore` 模板、README 内容等在 DESIGN 层仅描述策略，具体内容在 4-dev 阶段产出。
