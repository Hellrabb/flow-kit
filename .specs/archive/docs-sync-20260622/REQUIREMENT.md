# REQUIREMENT: 同步说明文档与近期修改

- **Change ID**: docs-sync
- **关联**: `@.specs/docs-sync/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想在用户指南中看到所有近期功能的完整说明，以便正确使用这些功能。
- **US-2**：作为新用户，我想 README.md 准确反映项目当前结构和快速开始步骤，以便顺利上手。
- **US-3**：作为维护者，我想 flow-kit-ecosystem-guide.md 列出所有生态组件（含近期新增），以便理解架构全貌。

## 验收准则（AC）

### AC-1 · brooks-tools 离线打包已写入用户指南

- **Given** 用户指南 §8 (brooks-lint) 已有基础内容
- **When** 阅读 §8 或新增的 brooks-tools 子节
- **Then** 读者能了解：brooks-tools 是什么（depcheck/jscpd/knip/ts-prune）| 为什么需要 npm pack 离线打包 | 扁平 node_modules 与 pnpm 虚拟存储的区别 | --no-brooks-tools flag 的用途
- **验证方式**: `grep -c "brooks-tools" FLOW-KIT-用户指南.md` ≥ 3

### AC-2 · 用户指南 Pipeline 执行链描述已更新

- **Given** 用户指南 §4.1.2 描述 Pipeline Goal
- **When** 阅读该节
- **Then** 明确说明 pipeline 支持 `--from 0` 从任意阶段起步（非仅 4→7），执行链为 0→1→2→2a→3→4→5→6→7
- **验证方式**: `grep -c "\-\-from 0\|start_phase\|0→1→2" FLOW-KIT-用户指南.md` ≥ 3

### AC-3 · README.md 项目结构已更新

- **Given** README.md 的项目结构树过时（显示 init-git-repo 为活跃 change）
- **When** 运行 `diff <(README 中的结构) <(实际 ls 输出)`
- **Then** 结构树与实际目录一致：含 `lib/`、`test/`、正确反映 `.specs/` 下的 CONTEXT/STATE/CHANGELOG/LESSONS/health/archive 结构
- **验证方式**: README 结构树中各目录项均存在于磁盘

### AC-4 · flow-kit-ecosystem-guide.md 补充新组件

- **Given** ecosystem-guide 缺少 PCSC/PG、pipeline goal、rollback、brooks-tools
- **When** 阅读更新后的 ecosystem-guide
- **Then** 层 1（核心引擎）提及 PCSC/PG 机制和 pipeline rollback | 层 5（brooks-lint）提及 brooks-tools 离线打包 | 术语与 CONTEXT.md 一致
- **验证方式**: `grep -cE "PCSC|PCG|rollback|brooks-tools" flow-kit-ecosystem-guide.md` ≥ 4

### AC-5 · 命令示例可执行

- **Given** 三份文档中含有命令示例
- **When** 逐条检查命令格式
- **Then** 所有示例命令的参数、路径与当前版本一致（无 `flow-kit-bundle.tar.gz` 直接 bash 执行这类错误写法）
- **验证方式**: 人工逐条审核（在 5-test 阶段执行）

### AC-6 · 过时内容已删除

- **Given** 文档中可能存在过时描述
- **When** grep 检查以下模式
- **Then** 无 `pipeline 仅覆盖 4→7`（现已支持 0→7）、无过时版本号 `20260615`（应 ≥ `20260622`）、无过时路径（如 `.specs/init-git-repo/` 作为当前活跃 change）
- **验证方式**: `grep -E "仅.*覆盖.*4.*7|20260615|init-git-repo.*活跃" *.md FLOW-KIT-用户指南.md` 返回空

---

## 范围切分

### v1（本次必做）

- FLOW-KIT-用户指南.md：新增 brooks-tools 子节（§8 下）、更新 pipeline 描述（已大部分完成，仅需小修）
- README.md：更新项目结构树、快速开始命令
- flow-kit-ecosystem-guide.md：补充 PCSC/PG、pipeline goal、rollback、brooks-tools
- 全局：修正版本号、过时路径、命令示例

### v2（下一轮考虑，不本次）

- FLOW-KIT-用户指南.md 拆分（当前 1122 行，再增 50+ 行可能过长；拆为"核心指南"+"高级特性"两文档）
- 英文版翻译

### out（永远不做）

- 修改 flow-kit-bundle/ 内的任何文件（分发包源码独立维护）
- 新建独立 CONTRIBUTING.md（当前项目单人维护，等有外部贡献者时再说）

---

## 非功能性需求

- **性能**: 无（纯文档变更）
- **可访问性**: 无
- **安全**: 无
- **兼容性**: Markdown 需兼容 GitHub Flavored Markdown 渲染
- **可观测性**: 无

## 依赖与假设

- 假设近期 git log 足以判断哪些功能已实现（无需逐行审计源代码）
- 假设 FLOW-KIT-用户指南.md §4.1.2-4.1.4 的 PCSC/PG/Rollback 内容准确，只需补充 brooks-tools 和 --from 0 细节
- 依赖 CONTEXT.md 术语表作为术语一致性参考

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
