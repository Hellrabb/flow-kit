# DESIGN: 质量基础设施补强

- **Change ID**: `quality-baseline`
- **关联**: `@.specs/quality-baseline/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）

---

## 0. 技术栈选定

> 纯 CLI / Bash / Makefile 项目，跳过技术栈卡片。

- **语言**: Bash 4.0+ / GNU Make
- **新增依赖**: shellcheck (≥0.9，系统包管理器安装)
- **理由**: 与项目既有栈一致；Makefile 是 Unix 标准，零额外依赖

---

## 0.5 既有架构对齐（brownfield）

### 0.5.1 触碰模块

```
触碰模块：
- flow-kit-bundle/flow-kit/prompts/4-dev.md（E：加 @see pipeline-gates 引用）
- flow-kit-bundle/skills/flow-dev/SKILL.md（E：加 @see pipeline-gates 引用）
- flow-kit-bundle/hooks/stop/22-git.sh（G：smoke test 覆盖）
- flow-kit-bundle/hooks/stop/24-session.sh（G：smoke test 覆盖）
- flow-kit-bundle/hooks/stop/26-workflow.sh（G：smoke test 覆盖）
- flow-kit-bundle/hooks/stop/99-report.sh（G：smoke test 覆盖）

新增模块：
- flow-kit-bundle/flow-kit/reference/pipeline-gates.md（E：共享 toll-gate 片段）
- flow-kit-bundle/flow-kit/reference/check-gate-sync.sh（E：diff 校验脚本）
- Makefile（F：项目根）
- .git/hooks/pre-push（F：pre-push hook）
- test/test_stop_chain.bats（G：smoke test）

禁动清单（禁碰）：
- flow-kit-bundle/flow-kit/GO.md
- flow-kit-bundle/lib/install_*.sh
- package-flow-kit.sh（本次不改打包逻辑）
```

### 0.5.2 沿用模式

| 本次需要 | 既有 | 决定 |
|---|---|---|
| 引用共享 markdown | 无（首次）| 新建 pipeline-gates.md + @see 注释约定 |
| Makefile | 无 | 新建（Unix 标准，零依赖）|
| bats 测试 | bats 1.13.0 (npx) | 沿用 |
| 错误处理 | set -euo pipefail | 沿用 |
| shell 静态分析 | 无 | 新引入 shellcheck |

### 0.5.3 沿用 vs 引入新模式

```
- 测试：**沿用** bats-core，不引入新测试框架
- 构建：**引入新模式** GNU Make → 理由：Unix 标准，比手写 shell alias 更规范
- 静态分析：**引入新模式** shellcheck → 理由：bash 生态标准工具
- 协议共享：**引入新模式** @see 引用约定 → 理由：纯 markdown，不引入模板引擎
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **E：提取 pipeline-gates.md 片段 + check-gate-sync.sh 校验，双管齐下** | 仅 @see 引用（纯约定）或仅校验脚本 | @see 降低维护成本，check-gate-sync.sh 硬兜底防止漂移。双管弥补纯约定的不可靠性 | 维护两份（共享片段 + 校验脚本），但总维护成本仍低于修复漂移 |
| D2 | **E：首批仅同步 4-dev prompt+skill 的 toll-gate 协议段** | 全量同步所有 phase 的 prompt↔skill 对 | 4-dev 是最大块（131行重复），ROI 最高；全量同步触及面太大，risk 高 | 其他 phase 按需分批迁移（v2） |
| D3 | **F：Makefile 方案 A（细粒度 targets）** | 方案 B（极简单 target） | Q5 确认方案 A；test/lint/check/all 分层让用户按需选择（快速 test vs 全量 check） | 多 3 个 target，维护成本可忽略 |
| D4 | **F：pre-push hook 内容为 `make check`，安装方式为手动拷贝** | install.sh 自动安装 | 手动安装简单可控；install.sh 改动有风险（影响所有用户） | v2 考虑 install.sh 集成 |
| D5 | **G：smoke test 覆盖目标：source 不报错 + 关键函数存在** | 端到端测试（mock git 状态 + 实际调用） | smoke test 轻量低成本，抓"脚本语法错误/函数缺失"类低级问题；E2E 测试 ROI 低（协调层逻辑薄） | 不覆盖运行时行为（留给 integration test） |
| D6 | **H：shellcheck 仅 error 级别，`-e SC1091` 忽略未跟踪 source** | 全量零容忍 | Q4 确认渐进式；先修 error（真正的 bug），warning/style 逐步修 | 潜在 warning 级问题暂时放过 |

---

## 2. 数据流 / 架构图

### E：协议双入口 DRY 流程

```
  维护者改 toll-gate 协议
        │
        ├── ① 编辑 pipeline-gates.md（单一源）
        │
        ├── ② prompt/skill 文件中 @see 引用自动指向最新版
        │     （纯 markdown 约定，AI 读 prompt 时按 @see 加载）
        │
        └── ③ 运行 check-gate-sync.sh 验证
              ├── diff prompt 和 skill 的 toll-gate 段
              ├── 一致 → ✅ exit 0
              └── 漂移 → 🔴 exit 1 + 列出差异行
```

### F：Makefile 执行链

```
  make all
    └── make check
          ├── make test       → npx bats test/
          ├── make lint       → shellcheck *.sh lib/ hooks/
          ├── validate-pkg    → bash package-flow-kit.sh --validate
          └── check-test-sync → diff -r test/ flow-kit-bundle/test/

  .git/hooks/pre-push → make check（失败阻止 push）
```

---

## 3. 风险

| # | 风险 | 概率 | 缓解 |
|---|---|---|---|
| R1 | **E：@see 纯约定弱模型不跟**：弱模型读到 @see 可能忽略或不加载 | 中 | check-gate-sync.sh 硬校验 + PCSC 自检 gate |
| R2 | **H：shellcheck 误报 error**：某些 shellcheck error 级规则在项目上下文是 false positive | 低 | `-e SC1091` 已忽略最大 false positive 源；其他 error 逐个评估 disable |
| R3 | **F：pre-push hook 打扰工作流**：每次 push 都跑全量 check，网络慢时 push 变慢 | 低 | `make test` 秒级完成；可 `git push --no-verify` 跳过 |
| R4 | **G：smoke test 假安心**：只测 source 不报错+函数存在，不测实际行为，给人"测试过了"的错觉 | 中 | 测试命名明确标 "smoke"，注释说明覆盖范围；核心 lib 已有深度测试 |
| R5 | **I：test 双源 diff 在并行开发时误报**：两个分支同时改了 test/ 和 bundle/test/，diff 不一致但都不是错误的 | 低 | 校验仅在 `make check` 时跑，不在 pre-commit 自动触发 |

---

## 6. 不在范围

- 不引入外部 CI
- 不迁移其他 phase 的 prompt↔skill 对（v2）
- 不写 E2E integration test（仅 smoke test）
- shellcheck warning/style 级别不在此次修复

---

## 9. 架构沉淀建议

### 9.1 新增可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit/reference/pipeline-gates.md` | toll-gate 协议共享片段 | 任何 phase 的 prompt↔skill 双入口 | 后续 phase 迁移时先改引用 |
| `flow-kit/reference/check-gate-sync.sh` | 协议漂移检测 | 改完 prompt 或 skill 后 | 每次改 gate 协议后跑 |
| `Makefile` | 一键质量检查 | 日常开发 + pre-push | 后续可加更多 target |

### 9.2 新增项目级决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 协议共享机制 | @see reference/pipeline-gates.md + check-gate-sync.sh | 所有 prompt↔skill 双入口 | 低 |
| 构建入口 | GNU Makefile（test/lint/check/all） | 项目根 | 低 |
| 静态分析 | shellcheck error 级别，-e SC1091 | 所有 .sh 文件 | 低 |

### 9.3 禁动清单变化

```
- 新增禁动：无（不创建需保护的新模块）
```
