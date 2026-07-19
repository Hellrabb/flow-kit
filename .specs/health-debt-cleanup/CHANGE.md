# CHANGE — health-debt-cleanup

> 2026-07-20 · M-health 巡检遗留 4 项修复

## Why

2026-07-20 健康巡检（内置回退 · 92/100）发现 4 项遗留技术债（2 🟡 + 2 🟢），全部来自之前 Full Sweep（2026-07-10 · 65/100）的未修复项。上次 2 项 🔴 Critical（l3_review_run 307 行 / is_gh_pr_create 290 行）已在 sweep-fix + l2-l3-mock-fix 中修复，剩余这 4 项为低优先级结构改进，本次一次性消除。

**场景**：定期巡检 → 发现遗留技术债 → 集中清理

**触发原因**：健康报告显示 2 🟡 Scheduled + 2 🟢 Monitored 自 2026-07-10 延续至今未处理。

## What

一次性修复 2026-07-20 健康巡检的 4 项遗留：

1. **🟡 R6 · 命名约定统一**：三套命名风格（`check_g*` / `_gate_*` / `fk_*`）合并为两套（公共 `fk_*` + 私有 `_*`），全仓 grep 替换，消除风格割裂
2. **🟡 R1 · install_hooks() 测试补齐**：195 行函数暂不拆分（安装脚本非热路径，长度容忍度高于运行时 hook），改为补单元测试覆盖 + CONTEXT.md 标注
3. **🟢 T5 · install 函数测试覆盖**：为 `install_hooks()` / `install_brooks_lint()` 等安装函数新增 bats 单元测试
4. **🟢 R4 · `_grep` 兼容层决策标注**：确认保留 `_grep` wrapper（ugrep/grep 自适应跨平台兼容，成本收益合理），在 CONTEXT.md 标注决策 + 理由

## 影响面

- [x] 影响既有代码（R6 全仓重命名 · 估计触及 10-15 个 .sh 文件）
- [x] 需要新增测试（T5 install 函数测试 · 估计 +20-30 bats cases）
- [ ] 影响架构/ADR（纯代码风格/测试补齐，不改架构）
- [ ] 影响 API / 公共契约（`fk_*` 是公共 API 前缀，已稳定，不破坏）
- [ ] 涉及数据库/Schema 变更
- [ ] 涉及 UI/UX 变更（非前端项目）

## 范围排除

- ❌ **不拆** `install_hooks()`（用户确认暂不拆分——安装脚本非热路径，195 行可接受）
- ❌ **不动** brooks-lint/plugin/ 第三方代码（README 翻译文档重复属预期）
- ❌ **不碰** regression-demos/ 下的 check.sh（它们是独立测试夹具，命名自成体系）
- ❌ **不改** `_grep` wrapper 本身（保留，仅标注决策）

## 验收线

1. 全仓 `check_g*` 函数重命名为 `_fk_check_*` 私有前缀，`grep -r 'check_g[0-9]' flow-kit-bundle/` 零命中（仅定义处 + bats 测试用例名保留）
2. install 函数新增 ≥ 15 个 bats 测试用例，覆盖 `install_hooks()` / `install_brooks_lint()` 的关键路径
3. CONTEXT.md 追加命名约定段 + `_grep` 保留决策，LESSONS.md 对应条目标 resolved
4. `make test` 全绿（543+ tests · 0 fail），`bash -n` 63 脚本全过
