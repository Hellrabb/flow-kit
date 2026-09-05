# CHANGE: 修复 L3 审查 prompt 假阳性循环（截断顺序 + 反馈缺失 + 归档布局解析）

- **Change ID**: l3-prompt-loop-fix
- **创建日期**: 2026-09-04
- **路径建议**: 完整（用户指定 · gate-config=all）
- **状态**: active

---

## Why（为什么做）

~/chisel_env 的 INDEPENDENT-REVIEW-7.md（2026-08-29 traceweave-skill-mining change）登记了 3 条 flow-kit 缺陷，phase 7 的 L3 外部审查连续 3 轮误报「归档目录缺 CHANGELOG.md」后走人工放行。2026-09-04 本仓核查裁定：

1. **Claim 1（真问题，机制诊断有误）**：登记说法「phase 7 分支未用 project_root」不成立（L126-147 实际在用）。真因经真实归档目录模拟确认：① CHANGELOG/LESSONS/INTEGRATION 段追加在 7 文件循环**之后**，`head -c max_chars` 按**字节**截断（默认 20000B；ls ~1.8KB + 6 文件×3000B 即超限）→ 尾部注入段被确定性切掉；② checklist 要求「归档产物齐全（…SUMMARY…）+ CHANGELOG 是否更新」与归档约定矛盾（SUMMARY.md 不在工件模板、CHANGELOG 约定不入归档目录），弱模型按字面读 ls -la 必然误报。
2. **Claim 2（真缺陷）**：`_l3_inject_context` 仅注入两行 verdict + 一句「主 agent 已响应」指针，前轮 findings 与主 agent 处置意见从不进入下一轮 L3 prompt（外部 API 模型也读不到指针指向的文件）→ prompt 诱导的假阳性每轮确定性复现。`.bak-20260824` 中存在提取 `## 主 agent 响应` 的死代码，证明该功能曾被计划但未接线。
3. **Claim 3（误判，不修）**：Gate 2 `jq empty` 对 YAML `.flow-active` 静默让位是注释明文的既定设计（33 号单一 actor 负责），`fk_resolve_phase` 本身也纯 jq，重排 Gate 2 无法处理 YAML。
4. **新发现（潜伏 bug，纳入本 change）**：artifacts_dir 为 `.specs/archive/<id>/` 归档布局时，`dirname ×2` 把 project_root 解析成 `.specs` 而非仓库根 → CHANGELOG/LESSONS 注入路径 `.specs/.specs/…` 静默失效。

## What（做什么）

修复 `l3-prompt.sh` 文件簇的四个缺陷点：① CHANGELOG/LESSONS 注入段移到 7 文件循环之前（或预留预算），保证字节截断优先切文件正文而非反馈段；② phase 7 checklist 措辞对齐归档约定（去掉 SUMMARY、注明 CHANGELOG 为项目级不入归档）；③ project_root 解析兼容归档布局（`.specs/archive/<id>/` → 仓库根）；④ `_l3_inject_context` 注入前轮 L3 findings 摘要 + `## 主 agent 响应` 段，保留独立性声明。改完 flow-kit-bundle 唯一源 + bats 回归测试，全同步部署副本（`~/.claude/hooks` 全局运行时 + `.claude/hooks` 本地 + `dist/dsh-flow-kit` 两份）。

## 影响面

- [ ] 影响 `REQUIREMENT.md`
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **Claim 3 不修**：Gate 2 `jq empty` fail-open 让位是既定防御设计，33 号 hook 已有 correction-file 信号路径
- 不改 L3 模型选择链 / API 调用层（l3-api.sh / l3-review.sh 的调用逻辑）
- 不重构 7 文件循环为「智能截断」（smart_truncate 已存在于其他路径，本次仅调整注入顺序，避免扩大 blast radius）
- 不处理 chisel_env 项目侧的任何文件（问题登记在彼，根因修复在此）

## 验收线（粗粒度，不是 AC）

1. 用满尺寸归档目录构建 phase 7 L3 prompt，CHANGELOG/LESSONS 段可见（bats 回归测试断言）
2. 第二轮 L3 重审 prompt 中包含前轮 findings 摘要与主 agent 响应段（bats 断言）
3. 全量 bats 绿（现有 770 + 新增回归用例），五处副本（bundle 源 + 本地 + dist×2 + 全局运行时）byte-level 一致

## 风险与未知

- 字节 vs 字符预算交互：注入段前移后 7 文件可用预算减少，需测试确认大产物下正文截断行为可接受（截正文不截反馈是本 change 的设计立场）
- `~/.claude/hooks` 是全局运行时（其他项目共用），同步时机放在全量测试绿之后
- dist/dsh-flow-kit 两份拷贝若由 package-dsh-plugin.sh 生成，同步方式需在 DESIGN 阶段确认（手改 vs 重跑打包）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
