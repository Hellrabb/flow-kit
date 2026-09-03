# DESIGN — dsh-flow-kit-sync-2026-09（阶段 7 补审归档）

> 回顾补档（阶段 2 L2 盲审 R1-R4 已吸收：doctor rule 回退设计、对齐源声明
> 修正、四层义务表补全）。设计事实与 dsh-flow-kit/DESIGN.md §8（同步契约）
> 一致；本节只记录本 change 引入的两处 JS 侧实现设计。

## 1. 四层同步义务（内容/契约/版本/验证）

内容层自动（package-dsh-plugin.sh 从 flow-kit-bundle 重拷贝），契约层需核对
lib 侧读取方：

| 层 | 载体 | 本 change 动作 |
|---|---|---|
| 内容层 | package-dsh-plugin.sh 拷贝 skills/flow-kit/hooks/brooks-lint/vendor | 重跑打包脚本（自动） |
| 契约层：.flow-active.correction 结构 | flow-state.js doctor | 读 type + violations 去重摘要（check→rule 回退） |
| 契约层：fk_resolve_model tier-4/5 | flow-state.js /flow model | 写/清/显示 4 个模型字段 |
| 契约层：PRESET_MAP / gate_config | 无变化 | 只读核对 |
| 版本层 | package.json | 0.1.0 → 0.2.0（minor） |
| 验证层 | package-dsh-plugin.sh + vendor diff + node 单测 + root bats + make lint/test-sync | 20/20 + 770 ok + 逐字节 diff 空（TEST.md） |

## 2. /flow model 五级链实现（L2 phase 7 R1 修复后）

- render(g)：纯函数渲染（参数化 goal，不闭包捕获写前旧值；「✅ 已更新。」只作
  单行 header，见 phase 7 R1）
- fieldOf 映射：{l2→l2_model, l3→l3_model, l2-default→l2_default_model,
  l3-default→l3_default_model}；nextGoal = {...goal} 只改 4 键 → 不触碰
  condition/gates/gate_config（平行配置维度）
- --clear <target>：indexOf 后取后续 token 清对应键
- 展示优先级链文案与 SKILL.md L258 的优先级链**语义**一致（JS 用通配缩写
  `ANTHROPIC_* env > FLOW_KIT_*_MODEL env > .goal.l*_model …`；shell 注释为分
  L2/L3 两行完整字段版，非逐字同源——按 phase 2 R2 修正声明）
- 平台确认串：dsh JS 实现用「✅ 已更新。」+ 全量摘要；SKILL.md L257 的
  `✅ model[l3] = <value>` 为 claude 承载面确认串，两者输出契约有平台差异
  （声明于 dsh-flow-kit/DESIGN.md §8，phase 6 R3 处置）

## 3. doctor correction 报告

- 无文件 → ✅ 无待办纠正（卫生良好）
- violations>0 → ⚠️ type=…, violations=N (去重后的摘要列表)；摘要字段做
  check → rule 回退（state-integrity 类写 check，compliance 类写 rule——
  异质 schema，phase 2 R1），仍缺失才用 ?
- 无 violations 有 message（l2/l3-model-missing）→ ⚠️ type=… — message
- 解析失败 → ⚠️ 读取失败 — <原因>（fail-open，不影响诊断其余项）

## 4. 关键决策记录

- 降挡提交（gate off）只作为过渡，凭证就绪后恢复 gate_config=all 并逐阶段补审
- 归档产物按上游惯例补齐（archive-commit-gate 等 small change 均有全套文档）
- 上游内容层遗留（common.sh:238 注释头）登记 MINOR-DEFERRED.md，不混入本
  change 的「搬运不重写」边界
