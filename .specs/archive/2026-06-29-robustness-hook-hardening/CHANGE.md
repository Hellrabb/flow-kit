# CHANGE — 弱模型鲁棒性 Hook 化升级

> change-id: `robustness-hook-hardening`
> 创建: 2026-06-29
> 状态: proposed

## Why

`weak-model-robustness` 建立了 L1（规则护栏）+ L2（结构化自检）+ L3（证据链）三层 prompt 防线。但这些都是**模型自觉型**防御——弱模型可能：

- 读了 RULES.md 但仍然违反禁动清单（L1 失效）
- prompt 中有自检表但弱模型跳过不填或瞎填（L2 失效）
- 要求"引用前先 grep"但弱模型直接幻觉文件路径（L3 失效）

刚完成的 `weak-model-interactive-ui` 证明了 **Stop hook 系统级事后验证 + 矫正文件注入** 模式比纯 prompt 护栏有效得多。本 change 将同样的 hook 模式应用到弱模型鲁棒性的三层防线上。

## What

新增 Stop hook 模块 `28-weak-model-compliance.sh`，在每次会话停止时对模型回复做三层事后验证：

- **L1 规则合规**：grep 回复中是否触碰了 CONTEXT.md 禁动清单中的文件路径
- **L2 自检完整性**：grep 回复中的阶段自检表是否所有行都有 ✅/❌ 标记（无空白行）
- **L3 证据链真实性**：grep 回复中引用的文件路径/API/字段名，是否在 transcript 的工具调用历史中出现过（即模型真的 grep/read 了）

检测到违规 → 写入矫正文件 → SessionStart 注入矫正指令（复用 `interactive-ui-check` 已建立的矫正文件通道，统一为 `.flow-active.compliance-fix`）。

## 影响面

- [x] flow-kit-bundle/hooks/stop/（新增 28 号模块 + 扩展 lib）
- [x] flow-kit-bundle/hooks/session-start/flow-kit-resume.sh（扩展矫正注入，支持 compliance-fix 类型）
- [x] flow-kit-bundle/hooks/stop/lib/（新增 weak-model-compliance.sh 逻辑库）
- [x] .specs/CONTEXT.md（术语 + 禁动清单更新）
- [ ] 不改动现有 prompt 文件（prompt 护栏保持不变，hook 是额外兜底）
- [ ] 不改动 RULES.md / SYSTEM.md

## 范围排除

- ❌ 不改现有 prompt 文件的 L1/L2/L3 护栏（那是第一道防线，hook 是第二道）
- ❌ 不引入新依赖
- ❌ 不做 L4 伪双轨（仍是 v2 范围）
- ❌ 不修改 brooks-lint / gateflow 插件

## 验收线

1. `28-weak-model-compliance.sh` 通过 bats 测试（至少覆盖 L1/L2/L3 各 3 个场景）
2. 矫正文件 `.flow-active.compliance-fix` 能正确写入和清除
3. SessionStart 能识别 compliance-fix 并注入矫正指令
4. 现有 194 tests 全部通过（无回归）
5. 代码长度：hook 模块 ≤ 100 行 + lib ≤ 250 行（共 ≤ 350 行，可维护）
