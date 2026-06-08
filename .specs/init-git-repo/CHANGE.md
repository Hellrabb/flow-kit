# CHANGE: 初始化 Git 仓库并建立脚本设计文档与技术债跟踪体系

- **Change ID**: `init-git-repo`
- **创建日期**: 2026-06-08
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

- 项目当前无版本控制（`STATE.md` 记录 `git_repo: false`），`package-flow-kit.sh`（28KB）的任何修改都无法回溯、无法 diff、无法回滚
- `package-flow-kit.sh` 已积累 28KB 核心逻辑但无任何设计文档，后续维护者对脚本架构、关键决策、数据流一无所知
- 无技术债跟踪机制——脚本里的临时代码、硬编码路径、未抽取的重复逻辑不会被人注意到，直到炸了才知道
- 用户暂时不改脚本，先把基础设施建好，为后续规范维护铺路

## What（做什么）

1. **初始化 Git 仓库**：`git init` + `.gitignore` + 首次 commit（含现有全部文件）
2. **编写 `package-flow-kit.sh` 设计文档**：产出 `DESIGN.md`，记录架构、模块/函数职责、数据流、关键决策与取舍
3. **建立技术债基线**：跑 `brooks-lint` 全维度扫描（或手动建立 `TECH-DEBT.md` 基线），写入 `.specs/LESSONS.md`
4. **编写 README.md**：说明仓库用途、目录结构、开发规范（命名/提交格式/分支策略）
5. **更新 CONTEXT.md**：补充 git 仓库信息、提交规范、测试策略等新决策

## 影响面

- [x] 影响 `REQUIREMENT.md`（新建，定义本次 change 的详细需求与 AC）
- [x] 影响 `DESIGN.md`（新建，为 `package-flow-kit.sh` 编写设计文档基线）
- [ ] 影响现有 AC（无现有 AC）
- [ ] 影响数据模型 / 迁移（不涉及）
- [ ] 影响外部 API 兼容性（不涉及）
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不修改** `package-flow-kit.sh` 代码本身
- **不新增**打包脚本或功能脚本
- **不设置** CI/CD pipeline
- **不改变** `flow-kit-bundle.tar.gz` 的分发包内容
- **不迁移**已有历史改动（改了就改了，从这次开始记）

## 验收线（粗粒度，不是 AC）

1. `git log` 可见首次 commit，`.gitignore` 生效（`flow-kit-bundle.tar.gz` 等产物不被追踪）
2. `package-flow-kit.sh` 有对应的 `.specs/init-git-repo/DESIGN.md`，覆盖架构 + 关键决策
3. 技术债基线已建立——brooks-lint 扫描结果或手动 `TECH-DEBT.md` 已写入 `.specs/LESSONS.md`
4. `README.md` 存在，包含仓库用途、目录结构、开发规范三要素

## 风险与未知

- **brooks-lint 对 Bash 项目覆盖有限**：brooks-lint 主要面向 JS/TS/Python/Java 等传统代码项目。对纯 Bash 脚本项目，其架构审计/代码审查维度可能产出较少。若扫描结果过薄，需手动补充技术债条目
- **设计文档倒写风险**：`package-flow-kit.sh` 是既有代码，从代码反推设计可能遗漏原始意图。需标注哪些是「从代码推断」、哪些是「确认为原始意图」

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
