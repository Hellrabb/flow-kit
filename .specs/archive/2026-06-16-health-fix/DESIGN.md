# DESIGN: 健康巡检修复 — 消除技术债 + 引入测试

- **Change ID**: `health-fix`
- **关联**: `@.specs/health-fix/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目为 Bash 元项目（flow-kit 分发包仓库），核心技术栈不变。仅新增测试框架。

- **选定**：bats-core（Bash Automated Testing System）
- **版本**：≥ 1.10.0（Ubuntu 22.04 apt 默认版本）
- **关键依赖**：bats-core 本身无运行时依赖，仅需 Bash ≥ 4.0
- **理由**：Bash 项目唯一成熟的测试框架；TAP 格式输出，CI 友好；apt/npm/静态二进制三种安装方式覆盖离线场景
- **明确排除**：shunit2（停止维护，文档少）、bats（旧版，bats-core 是其继任者）

---

## 0.5 既有架构对齐（brownfield · 适配 meta 项目）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块：
- flow-kit-bundle/install.sh（既有 · 拆分重构）
- flow-kit-bundle/hooks/stop/*.sh（既有 · 不变内容，仅确认路径引用）
- flow-kit-bundle/hooks/stop/lib/*.sh（既有 · 不变内容）
- flow-kit-bundle/hooks/session-start/*.sh（既有 · 不变内容）
- flow-kit-bundle/hooks/config/settings.json（既有 · 改为 cp 源）
- flow-kit-bundle/brooks-lint/plugin/.claude-plugin/plugin.json（既有 · 读版本号）
- package-flow-kit.sh（既有 · 外部路径 fallback + settings 去重）
- .claude/hooks/（删除 · 16 个文件）

新增模块：
- test/（新目录 · bats 测试文件）
- flow-kit-bundle/lib/（新目录 · install.sh 拆分出的模块）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/flow-kit/（上游 vendor 副本，改源码应在源 repo）
- flow-kit-bundle/brooks-lint/plugin/skills/（上游 vendor 副本）
- flow-kit-bundle/skills/flow-*/（skill 包装器，本次不涉及）
- .specs/archive/（历史归档，只读）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 测试框架 | 没有 | 引入 bats-core（理由：Bash 项目首次引入测试） |
| 函数复用（install.sh 拆分后） | `source` 机制 | 沿用 Shell `source` 而非引入模块加载器 |
| 错误处理 | `set -euo pipefail` | 沿用（全部脚本保持一致） |
| 版本号读取 | `jq` / `grep` | 沿用 jq（已有 fallback 逻辑） |
| 路径解析 | `SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)` | 沿用（全项目统一模式） |
| 常量定义 | 无既有约定 | 引入新模式 → `readonly CONST_NAME=value`（Bash 原生，零依赖） |

### 0.5.3 沿用模式 vs 引入新模式

```
- 脚本自定位：**沿用** SCRIPT_DIR 模式（package-flow-kit.sh:9, install.sh:17）
- 错误处理：**沿用** set -euo pipefail（全项目统一）
- 参数解析：**沿用** while/case 模式（install.sh 现有风格）
- 函数组织：**沿用** 单文件内函数定义（拆分后每个 lib 文件仍是函数集合）
- 测试组织：**引入新模式** → bats-core .bats 文件 + TAP 输出（Bash 项目首次引入）
- 常量定义：**引入新模式** → readonly 命名常量（Bash 原生，零依赖，替换裸数字）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | 测试目录结构：`test/` 根目录，每个被测模块一个 `.bats` 文件 | 与被测脚本同目录放 `.bats` | 集中管理便于 CI 发现；bats 默认递归 `test/` | 测试文件与源文件分离，需在测试中写清楚被测文件路径 |
| D2 | install.sh 拆分为 `lib/install_core.sh` + `lib/install_skills.sh` + `lib/install_brooks.sh` + `lib/install_hooks.sh` | 拆到 `lib/` 更细粒度（每个函数一个文件） | 5 个函数 → 4 个 lib 文件 + 1 个主脚本，粒度合理 | 4 个文件 → `source` 链管理需显式写在主脚本 |
| D3 | hooks 去重：保留 `flow-kit-bundle/hooks/`，删除 `.claude/hooks/` | 保留 .claude/hooks/，删 bundle/hooks/ | bundle 是分发源，install.sh 已从 `$SCRIPT_DIR/hooks/` 读（即 bundle/hooks），无需改 install.sh | 删除后本地开发时依赖 install.sh 安装 hooks 到项目或全局，或手动 source |
| D4 | 外部路径 fallback：优先级 `--brooks-src` > 本地缓存 > `flow-kit-bundle/` 本地副本 | 只用外部路径（需要时才装） | 已有 Part A/F 的多级 fallback 模式（package-flow-kit.sh L252-296），Part B skills 同理扩展 | fallback 链增加复杂度；bundle 需保持 flow-kit-bundle/flow-kit/ 副本与 ~/.claude/flow-kit/ 同步 |
| D5 | 魔法数字 → `readonly` 常量，文件顶部定义 | 用注释解释每个数字 | 常量可 grep、可复用、IDE 可跳转；注释在代码移动时容易丢失 | 需要在 4 个文件中各加 3-7 行常量定义 |
| D6 | settings.json 模板：`cp` 文件替代 heredoc | 保留 heredoc + 注释同步提示 | 单一源（`flow-kit-bundle/hooks/config/settings.json`），修改只需一处 | package-flow-kit.sh Part D 从"生成"变为"复制"，需确保源文件存在 |
| D7 | brooks-lint 版本号：从 `plugin.json` 的 `version` 字段动态读取 | 环境变量 `BROOKS_VERSION` 覆盖 | plugin.json 是唯一真实源，版本升级只改一处；环境变量可覆盖供调试 | 需要 jq 或 grep fallback；plugin.json 路径变化时需同步改 install.sh 的读路径 |

---

## 2. 架构图

### 修复前（AS-IS）

```
package-flow-kit.sh
  ├── Part A: git archive ~/.claude/flow-kit/         ← 外部路径依赖
  ├── Part B: cp ~/.claude/skills/flow-*/              ← 外部路径依赖
  ├── Part C: cp flow-kit-bundle/hooks/ → staging
  ├── Part D: heredoc settings.json                     ← 重复定义
  ├── Part E: cp flow-kit-bundle/install.sh → staging
  └── Part F: rsync ~/.claude/plugins/cache/...         ← 外部路径依赖

.claude/hooks/          ← 与 bundle/hooks 100% 相同（双重维护）
flow-kit-bundle/hooks/  ← 同上

flow-kit-bundle/install.sh  ← 517 行单体
  ├── install_flow_kit_core()
  ├── install_skills()
  ├── install_brooks_lint()    ← 硬编码 1.3.0
  ├── install_hooks()           ← 设置写入逻辑
  ├── install_specs_template()
  └── main (参数解析 + 调度)

(无 test/ 目录)
```

### 修复后（TO-BE）

```
package-flow-kit.sh
  ├── Part A: flow-kit-bundle/flow-kit/ (fallback: ~/.claude/flow-kit/)
  ├── Part B: flow-kit-bundle/skills/ (fallback: ~/.claude/skills/)
  ├── Part C: cp flow-kit-bundle/hooks/ → staging       ← 不变（已是本地）
  ├── Part D: cp flow-kit-bundle/hooks/config/settings.json → staging  ← 去重
  ├── Part E: cp flow-kit-bundle/install.sh → staging    ← 不变
  └── Part F: flow-kit-bundle/brooks-lint/ (fallback: ~/.claude/plugins/)

flow-kit-bundle/hooks/  ← 唯一源（.claude/hooks/ 已删除）

flow-kit-bundle/
  ├── install.sh               ← ≤ 150 行（CLI + 调度）
  ├── lib/
  │   ├── install_core.sh      ← install_flow_kit_core()
  │   ├── install_skills.sh    ← install_skills()
  │   ├── install_brooks.sh    ← install_brooks_lint() + 动态版本号
  │   └── install_hooks.sh     ← install_hooks() + install_specs_template()
  └── hooks/                   ← 唯一源

test/
  ├── test_common.bats         ← common.sh 6 函数测试
  └── test_install.bats        ← install.sh 10 参数测试
```

---

## 3. 关键状态机

不适用（Bash 脚本无状态机）。

---

## 4. ADR 索引

本 change 无不可逆架构决策，所有决策均为项目内工具链优化（可随时 revert）。不单独写 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **install.sh 拆分后 source 路径错误**：`lib/` 相对路径在 `--project` 模式（CWD ≠ bundle 目录）下解析失败 | `install.sh` 无法运行 | 中 | 所有 lib source 使用 `$SCRIPT_DIR/lib/` 绝对路径；bats 测试覆盖各模式 |
| R2 | **bats 不可用**：目标离线机器未装 bats，且无 npm | 测试无法运行，但生产脚本不受影响 | 中 | 测试为开发态工具，非运行时依赖；bundle 可选附带 `bats` 静态二进制；`install.sh` 不依赖 bats |
| R3 | **外部路径 fallback 到过时副本**：`flow-kit-bundle/flow-kit/` 长期未更新，打包出旧版 flow-kit | 用户拿到过时功能 | 低 | package-flow-kit.sh 打印源路径日志（`echo "源:本地副本"`），用户可见；定期同步 bundle 副本 |
| R4 | **删除 .claude/hooks/ 后本地开发不便**：每次改 hook 需跑 install.sh --project . 或手动复制 | 开发体验下降 | 低 | 提供 `make dev-hooks` 或文档说明开发流程；这是"唯一源"策略的固有取舍 |
| R5 | **bats 测试依赖 jq**：`test_common.bats` 中 setup 需要 jq 构造临时 stop-hook.json | 无 jq 的环境测试全部 skip | 低 | 测试文件顶部 `bats_require_minimum_version` + jq 检测，无 jq 时 skip 并输出原因 |

---

## 6. 不在范围

- CI/CD 自动运行 bats（v2）
- `package-flow-kit.sh` 的完整测试覆盖（v2）
- stop hook 各模块的集成测试（v2）
- `flow-kit-bundle/flow-kit/` 改为 git submodule（v2）
- `.claude/hooks/` 删除后的 gitignore 更新（git status 变化）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `test/` | bats-core 测试目录结构 | 后续新增 Bash 脚本时 | 每个新脚本在 `test/` 加对应 `.bats` 文件 |
| `flow-kit-bundle/lib/install_core.sh` | flow-kit 核心安装逻辑 | 安装流程变更 | 独立模块，不影响其他安装步骤 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 测试框架 | bats-core ≥ 1.10.0 | 所有 Bash 脚本 | 低（替换框架仅需重写 .bats 文件） |
| hooks 唯一源 | `flow-kit-bundle/hooks/` | package + install 流程 | 低（改一个常量指向即可） |
| 常量命名规范 | `readonly UPPER_SNAKE_CASE` | 所有 shell 脚本 | 低（重命名即可） |

### 9.3 新增 / 修改的跨模块契约

```
- install.sh 拆分后，lib/install_*.sh 的公共函数签名保持兼容：
    install_flow_kit_core()     # 无参数
    install_skills()            # 无参数
    install_brooks_lint()       # 无参数，内部读 $SCRIPT_DIR
    install_hooks(project, scope)  # 参数不变
```

### 9.4 新增 / 升级的依赖

| 包 | 版本 | 用途 | 是否替换既有 |
|---|---|---|---|
| bats-core | ≥ 1.10.0 | Bash 测试框架 | 否（首次引入） |

### 9.5 禁动清单变化

```
- 新增禁动：flow-kit-bundle/lib/install_*.sh 不允许被外部脚本直接 source（只允许 install.sh 主脚本 source）
- 新增禁动：test/ 目录不允许放入非 .bats 文件
```
