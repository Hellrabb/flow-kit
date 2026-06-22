# CHANGE: 同步说明文档与近期修改

- **Change ID**: docs-sync
- **创建日期**: 2026-06-22
- **路径建议**: 中等
- **状态**: draft

---

## Why（为什么做）

自上次 `docs-update`（2026-06-22，仅新增 Goal/Pipeline 两节）以来，仓库又经历了多项重要变更：`--from 0` pipeline 扩展、PCSC/PG 双层防护审计与修复、pipeline 智能回退、brooks-tools 离线打包、多项 M-health 技术债修复。FLOW-KIT-用户指南.md（1122行）中许多内容已过时或不完整，README.md（72行）未反映最新项目结构，flow-kit-ecosystem-guide.md（189行）缺少最新组件。

## What（做什么）

以 FLOW-KIT-用户指南.md 为主目标，全面审计并更新三个说明文档：
1. **新增**：PCSC/PG 双层防护机制、`--from 0` pipeline 支持、智能回退方案、brooks-tools 离线打包流程
2. **删除**：已过时的描述（如"仅覆盖 4→7"的 pipeline 说明、旧 CONTEXT.md 条目）
3. **修正**：版本号、文件路径、命令示例中的不一致
4. **README.md**：更新项目结构树，补充最新特性摘要
5. **flow-kit-ecosystem-guide.md**：补充 PCSC/PG、rollback、brooks-tools 等新组件

## 影响面

- [x] 影响 `REQUIREMENT.md`（需明确哪些文档改什么）
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不新建文档（如不创建独立的 CONTRIBUTING.md、CHANGELOG 格式规范等）
- 不翻译为英文（保持中文）
- 不调整文档视觉排版/样式（非 UI 项目）
- 不修改 flow-kit-bundle/ 内的任何文件（分发包源码由打包流程独立维护）

## 验收线（粗粒度，不是 AC）

- FLOW-KIT-用户指南.md 准确反映当前版本的所有核心功能，无遗漏、无过时描述
- README.md 的项目结构树与 `ls` 实际输出一致
- 三份文档中引用的命令示例均可直接执行，无路径/参数错误

## 风险与未知

- FLOW-KIT-用户指南.md 已达 1122 行，再增可能过长；考虑是否需要拆分（在 REQUIREMENT 阶段决定）
- 部分近期 change（如 pcsc-audit-v2）的细节较多，需判断哪些写入用户指南、哪些留在 CHANGELOG

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
