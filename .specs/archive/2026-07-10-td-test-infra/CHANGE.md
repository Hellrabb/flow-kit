# CHANGE: TD-010 jscpd 工具化 + TD-002 stop 链覆盖核实/补（测试基础设施收尾）

- **Change ID**: td-test-infra
- **创建日期**: 2026-07-09
- **状态**: draft
- **路径建议**: 完整 pipeline（0→1→2→3→4→5→6→7 · auto_advance · 全 independent review gate）
- **规模**: small（2 task · 纯 bash/test · 非前端 · 无 schema）

---

## Why（为什么做）

两条 🟢 技术债，CONTEXT 描述与实测不符，且都是"测试/巡检基础设施不可靠"：

- **TD-010**：CONTEXT 标「已纳入巡检 SOP」**是假的**——Makefile 无 `dup` target、`~/.bashrc`/`~/.profile`/`package-flow-kit.sh` 无 jscpd 包装。所谓 SOP 只存在于 `.specs/health/*.md` 文字里，靠人记忆维持；下次谁忘了 `--ignore brooks-lint/brooks-tools` 照样误报 0.91%。
- **TD-002**：17 个 stop 主脚本只 4 个被 test 提及（00-gate/28/29/30）。主脚本非纯协调层——含 Module C（C4 secrets detection）/ Module G（G1 artifact 验证）等真业务检查逻辑，13 个无 test 覆盖。**但**存在 `test_stop_chain.bats` / `test_stop_report_reminder.bats`，可能已覆盖部分链组装——需先核实再决定补不补。

## What（做什么）

1. **TD-010**：Makefile 加 `dup` target，固化 `jscpd --ignore '**/brooks-lint/**,**/brooks-tools/**,**/test/**,**/regression-demos/**'`；`check` 不强依赖（避免 jscpd 没装致 fail）。CONTEXT TD-010 校准（「已纳入 SOP」→「已固化为 `make dup`」）。
2. **TD-002**（调查驱动·按需补）：读 `test_stop_chain.bats` + `test_stop_report_reminder.bats` 确认链组装覆盖现状。若已覆盖 → TD-002 标 ✅ 不补；若有缺口 → 给无覆盖的关键主脚本补 smoke（`bash -n` + source 成功 + 代表性检查函数可调）。双源同步（test/ + flow-kit-bundle/test/）。

## 影响面

- [ ] 影响 `REQUIREMENT.md`（否·测试/工具基础设施）
- [ ] 影响 `DESIGN.md` / 新 ADR（否·0.4 未命中，无架构变更）
- [ ] 影响现有 AC（否）
- [ ] 影响数据模型 / 迁移（否）
- [ ] 影响外部 API 兼容性（否）
- [x] 仅测试/工具加固 + CONTEXT 校准

## 范围排除（这次不做）

- **TD-004**（prompt 重复·抽 `_shared/`）：等机会型，下次改 prompt 规则时顺手
- **TD-005**（jq pipeline goal 解析重复）：先重新核实重复程度，本次不做
- **TD-008**（l3-review 574 行拆分）：下次改 L3 审查逻辑时顺手
- **TD-002 若调查发现 test_stop_chain 已全覆盖**：不强补 smoke（YAGNI）

## 验收线（粗粒度）

1. `make dup` 跑通（或正确报告 jscpd 未装），jscpd 命令固化带正确 `--ignore`
2. TD-002 覆盖结论明确（test_stop_chain 覆盖了什么 + 缺口规模）；若补 smoke → bats 全绿
3. CONTEXT TD-010/002 校准 + `bats test/` 全绿 0 fail

## 风险与未知

- **TD-002 调查结果不确定**：test_stop_chain.bats 可能已覆盖链组装（工作量极小），也可能只覆盖 report 子集（缺口大）。调查后定。
- **jscpd 可选依赖**：`make dup` 在 jscpd 未装时 graceful skip（非硬 fail）。

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`。
> **本 change 走完整 pipeline（auto_advance=true）**：防上下文丢失。
