# CHANGE: l3-review.sh 加固——修复 6 项缺陷

- **Change ID**: l3-review-hardening
- **创建日期**: 2026-07-03
- **路径建议**: 中等（跳过 DESIGN，直接 REQUIREMENT → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

在 `flow-active-integrity` change 的 L3 执行过程中发现 `l3-review.sh` 存在 6 项缺陷，导致 L3 在 DeepSeek 端点上部分阶段无法工作、verdict 误判、输出文件污染。

**发现场景**：手动运行 L3 时，6 个阶段中 4 个返回 "no content in response"，2 个返回 "invalid L3 verdict: unknown"。排查后发现根因分布在 4 个层面。

## What（做什么）

修复 `l3-review.sh` 的 6 项缺陷：

| # | 发现 | 根因 | 修复 |
|---|---|---|---|
| F1 | Phase 6 L3 误报"核心文件缺失" | `git diff HEAD` 不含 untracked 新文件 | diff + `git ls-files --others` 追加新文件内容 |
| F2 | Phase 7 L3 误报"归档产物不齐全" | 只传 REVIEW.md + CHANGELOG.md，其他 6 个产物不可见 | 传目录清单 + 各产物摘要（各 ≤3000 chars） |
| F3 | L3 段重复追加，旧段不清理 | `>>` 无条件追加，幂等性缺失 | 写入前 `awk` 剥离已有 L3 段，再追加新段 |
| B1 | "no content in response" | 只读 `content[0].text`；DeepSeek 返回 `[0].thinking + [1].text` | 遍历所有 block 找 `type=="text"` |
| B2 | thinking block 吃光 token budget | `max_tokens=2000`；DeepSeek thinking 消耗大部分 | → 8000 |
| B3 | 大 prompt 超时 | `--max-time 25s` 不够 DeepSeek 处理大 artifact | → 90s |
| B4 | verdict 提取失败 | 只认 markdown code block 格式；DeepSeek 返回 raw JSON 或 mixed text+JSON | 3 层提取（code block → JSON → regex） |

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [ ] 影响 `DESIGN.md` / 引入新 ADR（不涉及——纯 bugfix，不改变架构）
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不重构 l3-review.sh 架构（保持单文件）
- 不改变 L3 prompt 模板（只改参数传递）
- 不变更 L3 模型选择逻辑

## 验收线

- 6 项修复全部在 `l3-review.sh` 中实现
- bats 测试覆盖 F1/F2/F3/B1/B4 的修复逻辑
- L3 对 `flow-active-integrity` 全 6 阶段重跑，verdict 不再有误报

## 风险与未知

- DeepSeek API 行为可能变更（thinking block 格式非 Anthropic 标准）
- max_tokens=8000 + timeout=90s 增加每次 L3 调用的资源消耗约 4×

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
