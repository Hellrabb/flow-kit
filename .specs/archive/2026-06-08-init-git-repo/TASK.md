# TASK: 初始化 Git 仓库并建立脚本设计文档与技术债跟踪体系

- **Change ID**: `init-git-repo`
- **关联**: `@.specs/init-git-repo/REQUIREMENT.md`、`@.specs/init-git-repo/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P]
Wave 2:            T05    (depends on T01, T02, T03, T04)
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。
> Wave 1 全部文件落盘后，Wave 2 做一次性 git commit。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>初始化 Git 仓库并创建 .gitignore</name>
  <read_files>
    .specs/init-git-repo/DESIGN.md
    <!-- 读取 D3 .gitignore 策略 + D6 不用 LFS -->
  </read_files>
  <write_files>
    .gitignore
    <!-- git init 创建 .git/ 目录 -->
  </write_files>
  <action>
    1. git init（默认分支 main）
    2. 按 DESIGN.md D3 策略编写 .gitignore：
       - 排除生成文件：flow-kit-bundle.tar.gz, *.tar.gz
       - 排除敏感文件：.env, *.key, credentials*, *secret*
       - 排除系统文件：.DS_Store, Thumbs.db
       - 排除 IDE：.vscode/, .idea/
    3. git add -A && git commit -m "chore: init git repository with flow-kit packaging scripts"
       （首次 commit 仅含 git init 前的既有文件 + .gitignore，
        不含 README.md / LESSONS.md / STATE.md 变更——这些在 T05 提交）
  </action>
  <verify>git log --oneline | head -1 && echo "---" && git status --short</verify>
  <done>git log 有 commit，git status 不显示 flow-kit-bundle.tar.gz（被 .gitignore 排除）。对应 AC-1。</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>编写 README.md</name>
  <read_files>
    .specs/CONTEXT.md
    <!-- 读取项目概要 + 技术栈 + 命名约定 -->
    .specs/init-git-repo/CHANGE.md
    <!-- 读取 Why / What -->
    package-flow-kit.sh
    <!-- 了解核心脚本用途（只读） -->
  </read_files>
  <write_files>
    README.md
  </write_files>
  <action>
    编写 README.md，包含 ≥ 3 个二级标题：
    1. ## 仓库用途 — 一句话：flow-kit 分发包仓库，含打包脚本 + 生态文档
    2. ## 目录结构 — tree 或列表，标注关键文件用途
    3. ## 开发规范 — 三要素：
       - 命名约定：文件 kebab-case / 函数 snake_case（沿用 CONTEXT.md 已锁偏好）
       - 提交格式：Conventional Commits（feat:/fix:/docs:/chore:/refactor:）
       - 分支策略：main 直推（单人维护），禁止 force push

    可选额外段：## 快速开始（如何运行 package-flow-kit.sh 打出新 bundle）
  </action>
  <verify>grep -c "^## " README.md</verify>
  <done>README.md 存在，grep -c "^## " ≥ 3。对应 AC-4。</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>建立技术债基线（brooks-lint 扫描 + 手动补充）</name>
  <read_files>
    package-flow-kit.sh
    <!-- 核心脚本，brooks-lint 扫描对象 -->
    .specs/CONTEXT.md
    <!-- 读取既有抽象索引 + 禁动清单 + 命名约定 -->
    .specs/init-git-repo/DESIGN.md
    <!-- 读取 R2 风险：brooks-lint 对 Bash 产出可能薄 -->
  </read_files>
  <write_files>
    .specs/LESSONS.md
    <!-- 首次创建；后续 M-health 巡检追加 -->
  </write_files>
  <action>
    1. 调用 brooks-lint 全维度扫描（brooks-lint:brooks-sweep）。
       对 Bash 项目预期产出有限，但仍应尝试 review + debt 两个维度。
    2. 若 brooks-lint 产出 ≥ 3 条有效发现 → 写入 LESSONS.md，
       每条标注：严重程度（🔴🟡🟢）、位置、Symptom、建议修复方向。
    3. 若 brooks-lint 产出 < 3 条 → 强制手动补充 ≥ 3 条已知问题，
       例如：
       - 🟡 package-flow-kit.sh: L1-226 打包逻辑与 L227-498 安装逻辑耦合在同一文件，
         建议拆分为 build.sh + install.sh
       - 🟡 package-flow-kit.sh: 硬编码路径 ~/nanoclaw/.claude/hooks/
         （HOOK_SRC 变量），环境迁移时需手动改
       - 🟡 无测试覆盖：package-flow-kit.sh 590 行无任何自动化测试
       - 🟢 .specs/CONTEXT.md 既有抽象索引中「工具函数」段全为"未发现"，
         实际上 package-flow-kit.sh 内含内联辅助函数但未抽取
    4. LESSONS.md 格式参考 CONTEXT.md「技术债」段结构：
       严重程度 | 位置 | 问题 | 建议 | 状态
  </action>
  <verify>grep -c "🔴\|🟡\|🟢" .specs/LESSONS.md</verify>
  <done>LESSONS.md 存在，含 ≥ 1 条带严重程度标记的技术债条目。对应 AC-3。</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="done">
  <name>更新 CONTEXT.md 和 STATE.md 反映 Git 状态</name>
  <read_files>
    .specs/CONTEXT.md
    <!-- 需要更新的目标文件 -->
    .specs/STATE.md
    <!-- 需要更新 git_repo 字段 -->
    .specs/init-git-repo/DESIGN.md
    <!-- 读取 § 9.5 禁动清单变化 + D1/D2 决策 -->
  </read_files>
  <write_files>
    .specs/CONTEXT.md
    .specs/STATE.md
  </write_files>
  <action>
    1. STATE.md：
       - 改 git_repo: false → true
       - 添加 git_branch: main
       - 添加 commit_convention: Conventional Commits
    2. CONTEXT.md（在前面 REQUIREMENT 阶段已做部分更新，本次补全）：
       - 确认「已锁决策」段已有 [2026-06-08] Git 仓库初始化条目（前面已加）
       - 确认「默认偏好」段提交格式已更新（前面已加）
       - 追加禁动清单新增项（来自 DESIGN § 9.5）：
         flow-kit-bundle.tar.gz — .gitignore 已排除，永远不要 git add
       - 追加「项目结构」段：新增 .gitignore / README.md / .specs/LESSONS.md
  </action>
  <verify>grep "git_repo" .specs/STATE.md | grep "true"</verify>
  <done>STATE.md git_repo: true；CONTEXT.md 反映 Git 相关决策和禁动清单更新。对应 AC-5。</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="false" status="done">
  <name>最终提交：含所有新增文件的完整 commit</name>
  <read_files>
    README.md
    .specs/LESSONS.md
    .specs/CONTEXT.md
    .specs/STATE.md
    .gitignore
    <!-- 确认所有 Wave 1 产物已就位 -->
  </read_files>
  <write_files>
    <!-- 不写新文件。只做 git add + commit -->
  </write_files>
  <action>
    1. 确认所有 Wave 1 产物文件存在（T01 .gitignore / T02 README.md / T03 LESSONS.md / T04 STATE.md+CONTEXT.md）
    2. 确认 .gitignore 生效 —— flow-kit-bundle.tar.gz 未被 staged
    3. git add -A && git commit -m "chore: add README, tech debt baseline, and update project context"
    4. 确认 working tree clean
  </action>
  <verify>git status --short | wc -l</verify>
  <done>git status 输出 0（working tree clean），所有 AC 产物已提交。对应 AC-1~AC-5 综合验收。</done>
  <depends_on>T01, T02, T03, T04</depends_on>
</task>
```

---

## 状态字段说明

- `status="done"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（在「阻塞日志」记录）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加。

```xml
<!-- 占位 -->
```
