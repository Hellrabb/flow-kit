# REQUIREMENT: 更新说明文档以同步近期修改

- **Change ID**: docs-update
- **关联**: `@.specs/docs-update/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想阅读一份准确的用户指南，以便快速了解 flow-kit 的完整功能和使用方法。
- **US-2**：作为 flow-kit 维护者，我想用户指南与代码实际行为一致，以便减少用户困惑和支持负担。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · Pipeline goal 全链路文档

- **Given** `FLOW-KIT-用户指南.md` 存在
- **When** 用户搜索 "pipeline" 或 "--from"
- **Then** 文档包含：`/flow goal --pipeline --from <n>` 用法、全链路执行链（0→…→7）、toll-gate 暂停模型、auto_advance 模式
- **验证方式**: `grep -c "pipeline" FLOW-KIT-用户指南.md` 返回 ≥ 3 的匹配数（含 pipeline goal 专节）

### AC-2 · PCSC/PG 双层防护文档

- **Given** `FLOW-KIT-用户指南.md` 存在
- **When** 用户搜索 "双层防护" 或 "PCSC" 或 "PCG"
- **Then** 文档包含：PCSC（Phase Completion Self-Check）定义、PCG（Phase Completion Gate）定义、双层防护工作原理、各阶段产物清单
- **验证方式**: `grep -c "PCSC\|PCG\|双层防护\|Phase Completion" FLOW-KIT-用户指南.md` 返回 ≥ 4 的匹配数

### AC-3 · Pipeline rollback 文档

- **Given** `FLOW-KIT-用户指南.md` 存在
- **When** 用户搜索 "rollback" 或 "回退"
- **Then** 文档包含：失败分类表、动态下界、jq 通用化方案
- **验证方式**: `grep -c "rollback\|回退" FLOW-KIT-用户指南.md` 返回 ≥ 2 的匹配数

### AC-4 · Goal 自动提取文档

- **Given** `FLOW-KIT-用户指南.md` 存在
- **When** 用户搜索 "goal" 或 "自动提取"
- **Then** 文档包含：goal 自动提取机制（从 REQUIREMENT.md AC 生成）、native vs fallback 模式、goal 生命周期
- **验证方式**: `grep -c "goal.*自动\|auto.*extract\|goal.*提取" FLOW-KIT-用户指南.md` 返回 ≥ 2 的匹配数（不区分大小写）

### AC-5 · 术语一致性

- **Given** `FLOW-KIT-用户指南.md` 和 `.specs/CONTEXT.md` 均存在
- **When** 提取 CONTEXT.md 术语表中的 10 个核心术语（toll-gate / PCSC / PCG / pipeline goal / auto_advance / start_phase / --from / phase transition / gate condition / cross-phase condition）
- **Then** 用户指南中使用这些术语时，含义与 CONTEXT.md 一致（无自相矛盾的定义）
- **验证方式**: 人工对照 CONTEXT.md 术语表抽查 5 个术语在用户指南中的使用

### AC-6 · 无过时内容

- **Given** `FLOW-KIT-用户指南.md` 存在
- **When** 用户搜索已被替换的旧机制名称
- **Then** 文档不再将旧行为描述为当前行为（如 "goal 仅支持单阶段" 等已被 pipeline goal 替代的描述）
- **验证方式**: 人工通读确认

---

## 范围切分

### v1（本次必做）

- 在 `FLOW-KIT-用户指南.md` 中新增 pipeline goal 专节（--from 0 / toll-gate / auto_advance）
- 在 `FLOW-KIT-用户指南.md` 中新增 PCSC/PG 双层防护专节
- 在 `FLOW-KIT-用户指南.md` 中新增 pipeline rollback 专节
- 在 `FLOW-KIT-用户指南.md` 中新增 goal 自动提取专节
- 修正/删除已过时的旧行为描述
- 同步术语使用，确保与 CONTEXT.md 一致
- 如有必要，更新 `README.md` 概要描述

### v2（下一轮考虑，不本次）

- 为每个 `/flow` 子命令编写独立的命令参考页
- 翻译用户指南为英文
- 生成 CLI 命令的 `--help` 输出嵌入文档

### out（永远不做）

- 不将用户指南转换为 man page 格式
- 不生成视频/动图教程
- 不自动从代码注释生成文档（代码注释不面向终端用户）

---

## 非功能性需求

- **性能**: 无
- **可访问性**: 无
- **安全**: 无
- **兼容性**: Markdown 格式，兼容 GitHub/GitLab/任意 Markdown 渲染器
- **可观测性**: 无

## 依赖与假设

- **假设**：`FLOW-KIT-用户指南.md` 是唯一面向终端用户的说明文档；其他 docs 为内部参考
- **假设**：近期 change 的 DESIGN.md § 9 内容准确，可作为文档更新的依据
- **依赖**：`.specs/CONTEXT.md` 术语表（2026-06-17 更新版）作为术语权威源
- **依赖**：`.specs/archive/` 下近期归档 change 的 CHANGE.md / DESIGN.md 作为功能描述源

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
