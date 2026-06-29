# CHANGE: 消除 LESSONS.md 三条活跃技术债

- **Change ID**: `lessons-cleanup`
- **创建日期**: 2026-06-29
- **路径建议**: 中等（REQUIREMENT 增量 → DESIGN 轻量 → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

LESSONS.md 当前有 3 条活跃技术债长期未关闭：

1. **L-013**：归档流程两种遗漏模式——change 已归档但工作目录未清理（留空壳），或 change 已完成但从未归档（工件散落）。2026-06-24 和 2026-06-25 两次发现同类问题。
2. **L-012**：`flow-kit-bundle/` 目录结构变更后，`package-flow-kit.sh` 的 staging 逻辑（Part A~F 的 cp/rsync 范围）未同步更新，导致 bundle 安装时报缺文件。已发生过一次并修复，但缺少自动化防护。
3. **L-010**：破坏性变更（1.8 协议）触发后缺少自动化恢复验证。当前纯依赖人工记忆跑 bats，易遗漏。

三条都是"已知问题 + 已有修复经验 + 缺少自动化兜底"模式。一次性修掉，让 LESSONS.md 归零 active 项。

## What（做什么）

- **L-013**：7-integration 归档脚本增加双向校验——① 归档完成自动清理 `.specs/<id>/` 工作目录（PROGRESS.md 先确认已入 archive）；② 归档完成自动扫描 `.specs/` 下非 archive 目录，检出 REVIEW✅ + TASK 全 done 的未归档 change 并提示
- **L-012**：`package-flow-kit.sh` 增加完整打包校验——比对 `flow-kit-bundle/` 实际目录结构与 Part A~F 的 cp/rsync 指令覆盖范围，逐项对账，不一致时报错并列出缺失项
- **L-010**：1.8 破坏性变更协议触发后自动跑 `bats test/`，确认 0 fail 后才允许继续

## 影响面

- [x] 影响 `REQUIREMENT.md`（三个子项各有验收准则）
- [x] 影响 `DESIGN.md`（7-integration 归档脚本改动 + package-flow-kit.sh 校验逻辑设计）
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不碰 L-004（合理 deferred，共享函数仍 < 3 阈值）
- 不引入新的 CI/CD 系统（那是 quality-baseline change 的事）
- 不重构 `package-flow-kit.sh` 的整体结构（仅加校验层，不改现有 Part A~F 逻辑）

## 验收线（粗粒度，不是 AC）

1. 归档一个 change 后，其 `.specs/<id>/` 工作目录被自动清理，且未归档的已完成 change 被自动提示
2. 修改 `flow-kit-bundle/` 目录结构后跑打包校验，漏配的 cp/rsync 范围被精确报错
3. 1.8 破坏性变更协议触发后，bats 自动跑且 0 fail 才放行

## 风险与未知

- L-013 自动清理 `.specs/<id>/` 存在误删风险：需确认 PROGRESS.md 确已入 archive 后才执行 rm
- L-012 完整校验需要维护一份"期望覆盖清单"，清单本身的维护成本需评估
- L-010 的 1.8 触发检测依赖 4-dev prompt 中的既有协议段，改动范围需精确控制

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
