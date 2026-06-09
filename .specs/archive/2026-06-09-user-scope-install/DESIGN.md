# DESIGN: 支持 flow-kit 核心引擎 user-scope 全局安装

- **Change ID**: `user-scope-install`
- **关联**: `@.specs/user-scope-install/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本 change 修改的是 flow-kit 分发机制本身。CONTEXT.md 已锁定 Bash-only 栈。

- **选定**: Bash（与项目一致，`set -euo pipefail`）
- **前端**: 无
- **后端**: 无
- **数据库**: 无
- **部署**: 纯 Shell 脚本分发（tar.gz + install.sh）
- **关键依赖**: `ln`（coreutils）、`rsync`（已在 install.sh 中使用）
- **理由**: Bash 是 flow-kit 分发的唯一运行时，不引入新语言或依赖
- **明确排除**: Python/Node.js 安装器（过度工程）；包管理器集成（npm/brew/apt — 在 out 范围）

---

## 0.5 既有架构对齐（brownfield）

> CONTEXT.md 存在且非空 → 必跑。

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块：
- flow-kit-bundle/install.sh（既有 · 修改：新增 --user flag + symlink 创建）
- flow-kit-bundle/skills/flow-go/SKILL.md（既有 · 修改：新增两级查找逻辑）
- flow-kit-bundle/INSTALL.md（既有 · 修改：更新文档）
- package-flow-kit.sh（既有 · 可能微调：生成 README 时包含 --user 用法）

新增模块：
- 无（纯修改既有文件）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/flow-kit/ 下所有核心文件（prompts/templates/references — 本次不改）
- flow-kit-bundle/skills/ 下除 flow-go 外的 15 个 skill（symlink 透明解析，无需改动）
- flow-kit-bundle/hooks/（hooks 不参与 user-scope 改造）
- flow-kit-bundle/config/（settings/stop-hook 配置不变）
- package-flow-kit.sh 中与 Part A/B/C/D/E 打包逻辑无关的部分
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| dry-run 模式 | install.sh 已有 `--dry-run` flag + `dry()` 函数 | 沿用，扩展 dry() 支持 symlink 打印 |
| 步骤化安装 | install.sh 已有 `step()` 函数（step "N/6"） | 沿用格式，--user 模式下修改步骤 1 描述 |
| 颜色输出 | install.sh 已有 info/warn/err 函数 | 沿用 |
| 幂等检查 | install.sh 步骤 1 已有 "already exists, skipping" | 沿用，--user 模式检查 ~/.claude/flow-kit/ |
| 终端验证 | install.sh 末尾已有 ok/fail 验证函数 | 沿用，增加 symlink 验证 |
| symlink 创建 | 没有（项目未用过 ln） | 新建（理由：user-scope 的核心机制） |
| 两级文件查找 | 没有（项目未有过此需求） | 新建 · 在 flow-go 入口实现 |

### 0.5.3 沿用模式 vs 引入新模式

```
- 安装流程控制：**沿用** step-based 结构（N/6）+ dry/warn/info/err 函数
- 幂等安装：**沿用** "file exists → skip or merge" 模式
- path 解析：**沿用** `${HOME}/.claude/...` 风格（已在 step 3 "skills → ~/.claude/skills/" 中使用）
- symlink 管理：**引入新模式** → 理由：user-scope 安装本质是"单份存储 + 多项目引用"，symlink 是 Unix 下最简洁的实现
- 两级文件查找：**引入新模式** → 理由：首次引入"先查项目再查用户目录"的读取策略，以前只有项目级
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **Symlink 方案**：项目 `flow-kit → ~/.claude/flow-kit`（绝对路径） | ① 改动 86 处 skill 内部路径引用为绝对路径 ② 相对路径 symlink ③ 硬拷贝 + 同步脚本 | 选 symlink 绝对路径：① 零 skill 代码改动（symlink 对 Read 工具透明）② 绝对路径不随项目移动断链 ③ 升级 `~/.claude/flow-kit/` 一处所有项目即时生效 | ① Windows 不支持（v2 处理）② Git 追踪 symlink 内容（而非目标），clone 到新机器需重跑 install.sh --user |
| D2 | **项目级优先（project-priority fallback）**：AI 先查项目 `flow-kit/GO.md`，存在就用项目级；不存在才查 `~/.claude/flow-kit/GO.md` | ① 全局强制（一律用 ~/.claude/） ② 全局优先（有 ~/.claude/ 时忽略项目级） | 选项目级优先：① 向后兼容（已有项目不受影响）② 允许项目锁定版本（项目放实体 `flow-kit/` 目录即锁定）③ 最小惊讶原则 | ① 增加 flow-go 入口处一次文件存在性检查（~10 tokens）② 新用户可能困惑"为什么改了全局但项目没变"——需要文档说明 |
| D3 | **install.sh 只改步骤 1/6**：`--user` 模式仅改变 flow-kit core 的安装目标（从 `<project>/flow-kit/` 改为 `~/.claude/flow-kit/` + symlink），步骤 2-6 完全不变 | 新增一个独立的 `install-user.sh` 脚本 | 选修改现有 install.sh：① 避免两份安装脚本的维护成本 ② 步骤 2-6（hooks/skills/config/RTK）user/project 模式完全一样 ③ 用户只需记住一个命令 | install.sh 增加 ~40 行，从 183 行变为 ~225 行（仍在可维护范围内） |
| D4 | **~/.claude/flow-kit/ 已存在时不覆盖**：仅创建 symlink，不重新 rsync | ① 强制覆盖（每次 --user 重新 rsync）② 版本比较后覆盖 | 选不覆盖：① 用户可能手动修改了 user-scope 的 flow-kit 核心（如定制 prompts）② 覆盖前需用户显式操作（--reinstall 在 v2）③ 减小数据丢失风险 | 初次安装后核心文件不再自动更新——要么等 v2 的 --update flag，要么手动 `rm -rf ~/.claude/flow-kit && install.sh --user` |
| D5 | **flow-go 两级查找**：在 flow-go SKILL.md 入口处添加 "确定 FLOW_KIT_ROOT" 段落 | ① 修改所有 16 个 skill ② 在 flow-go 动态重写路径 | 选 flow-go 入口处理：① 其他 15 个 skill 通过 symlink 透明解析，无需改动 ② 仅处理无 symlink 的边缘场景（手动装 skills 但忘做 symlink）③ 改动集中在 1 个文件 | 如果用户手动复制了某个 skill 到项目，该 skill 内部引用的 `flow-kit/` 路径不经过 flow-go 入口 → 依赖 symlink 存在。这是合理的——有 symlink 才叫 user-scope 安装 |

---

## 2. 数据流 / 架构图

### 2.1 安装流程（--user vs 默认模式对比）

```
install.sh /path/to/project          install.sh --user /path/to/project
─────────────────────────────         ─────────────────────────────────────
Step 1: rsync flow-kit/ →             Step 1: rsync flow-kit/ →
        <project>/flow-kit/                   ~/.claude/flow-kit/
        (物理目录)                            (全局一份)
                                     Step 1a: ln -s ~/.claude/flow-kit
                                              → <project>/flow-kit
                                              (symlink 引用)

Step 2-6: 完全相同                   Step 2-6: 完全相同
  hooks    → <project>/.claude/        hooks    → <project>/.claude/
  skills   → ~/.claude/skills/         skills   → ~/.claude/skills/
  config   → <project>/.claude/        config   → <project>/.claude/
  RTK.md   → ~/.claude/RTK.md          RTK.md   → ~/.claude/RTK.md
```

### 2.2 运行时文件查找（AI 技能加载顺序）

```
AI 执行 /flow-go
    │
    ▼
flow-go SKILL.md 入口
    │
    ├── [ -f flow-kit/GO.md ]?
    │     YES → FLOW_KIT_ROOT="flow-kit"     ← 项目级（物理目录 或 symlink）
    │     NO  → 继续检查
    │
    ├── [ -f ~/.claude/flow-kit/GO.md ]?
    │     YES → FLOW_KIT_ROOT="~/.claude/flow-kit"
    │     NO  → 报错: "flow-kit 未安装，请运行 install.sh --user"
    │
    ▼
加载阶段 prompt: Read "${FLOW_KIT_ROOT}/prompts/<n>-*.md"
加载模板:        Read "${FLOW_KIT_ROOT}/templates/*.md"
加载参考:        Read "${FLOW_KIT_ROOT}/reference/*.md"
    │
    ▼
进入阶段 N 的 skill → 内部引用 flow-kit/ 路径
    │
    ├── 项目有 flow-kit/ → 通过 symlink 或物理目录透明解析 ✅
    └── 项目无 flow-kit/ → Read 工具在 FLOW_KIT_ROOT 基础上查找 ✅
```

### 2.3 多项目共享

```
~/.claude/
├── flow-kit/                 ← 全局一份（user scope）
│   ├── GO.md
│   ├── prompts/  (15 files)
│   ├── reference/  (7 files)
│   ├── templates/ (13 files)
│   └── ...
└── skills/
    └── flow-*/  (17 skills)

Project A/                     Project B/                     Project C/
├── flow-kit → symlink         ├── flow-kit → symlink         ├── flow-kit/  (物理目录
├── .specs/                    ├── .specs/                    │   锁定旧版)
├── src/                       ├── src/                       ├── .specs/
└── ...                        └── ...                        └── src/

共享 ~/.claude/flow-kit/      共享 ~/.claude/flow-kit/       项目级优先，
                                                               使用自己的 flow-kit/
```

---

## 3. ADR 索引

本 change 无高可逆性决策需要独立 ADR。D1（symlink 方案）和 D2（project-priority fallback）的选择理由和代价已在 §1 中充分记录。

---

## 4. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **Symlink 在新机器上断链**：Git clone 后 symlink 指向不存在的 `~/.claude/flow-kit/`，`/flow-go` 无法工作 | 用户在新机器首次使用时报错 | 高（clone 场景必现） | ① flow-go 入口检测到 flow-kit/ 断链时给出友好提示："flow-kit symlink 断链，请运行 install.sh --user" ② 在 INSTALL.md 明确写 "clone 后需重跑 install.sh --user" ③ 在 README.md 加环境 Setup 说明 |
| R2 | **~/.claude/ 被误删**：用户清理 `~/.claude/` 目录时同时删掉 `flow-kit/` 核心和所有 skills，所有项目受影响 | 所有项目 `/flow-go` 不可用 | 低（用户不会无故清理 ~/.claude/） | ① 重跑 install.sh --user 即可恢复（~15 秒）② 如果安装了 skills 到 ~/.claude/skills/，同样重跑恢复 |
| R3 | **项目级和 user-scope 版本不一致**：项目锁定旧版 flow-kit，但 user-scope 已升级。不同项目的 flow-kit 行为不同 | 团队协作时预期不一致 | 中 | ① 这是 feature（项目锁定版本），不是 bug ② 在 flow-go 入口加一行提示：`（使用项目级 flow-kit v<detected_version>）` 让用户明确知道用的是哪个版本 |
| R4 | **install.sh -u vs --user 歧义**：Bash 参数解析中 `-u` 可能与 `set -u` 或未来参数冲突 | 参数解析错误 | 低 | 只用长 flag `--user`，不注册短 flag `-u` |

---

## 5. 不在范围

- 不实现 `--update` flag（版本比较 + 条件更新 → v2）
- 不实现 `--reinstall` flag（先删后装 → v2）
- 不在 Windows 上支持 symlink（NTFS Junction / Developer Mode → v2）
- 不检测或自动修复断链 symlink（v1 只报错，v2 可以 `--repair`）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit-bundle/install.sh` 中的 `--user` 模式 | user-scope 安装 + symlink 创建 | 任何需要"全局一份 + 项目引用"的 flow-kit 组件分发 | 后续如果要把 templates 或 hooks 也做 user-scope，沿用同样的模式 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 安装模式 | 新增 `--user` 模式（核心到 ~/.claude/）+ 保留默认 project 模式 | 所有 flow-kit 新安装 + 跨项目共享 | 低——两种模式并存，随时可切换 |
| 文件查找策略 | project-priority fallback（项目级优先 → user-scope 回退） | flow-go 入口 + 所有 skill 的文件读取 | 低——回退逻辑仅在无项目级 flow-kit/ 时激活 |

### 9.5 禁动清单变化

```
- 新增禁动：无（本次不改动禁动清单）
```

---
