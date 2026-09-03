# DESIGN — dsh-flow-kit-sync-2026-09（阶段 7 补审归档）

> 回顾补档。设计事实与 dsh-flow-kit/DESIGN.md §8（同步契约）一致；本节只记录
> 本 change 引入的两处 JS 侧实现设计。

## 1. 四层同步义务（内容/契约/版本/验证）

内容层自动（package-dsh-plugin.sh 从 flow-kit-bundle 重拷贝），契约层需核对
lib 侧读取方：

| flow-kit 契约变化 | lib 同步点 | 本 change 动作 |
|---|---|---|
| .flow-active.correction 结构（violations[].check 白名单、合并 type 标签） | flow-state.js doctor | 读 type + violations 去重摘要输出 |
| fk_resolve_model tier-4/5（l2/l3_default_model 字段） | flow-state.js /flow model | 写/清/显示 4 字段 |
| PRESET_MAP / gate_config 语义 | 无变化 | 只读核对 |

## 2. /flow model 五级链实现（L2 R1 修复后）

- render(g)：纯函数渲染（参数化 goal，不再闭包捕获写前旧值）
- fieldOf 映射：{l2→l2_model, l3→l3_model, l2-default→l2_default_model,
  l3-default→l3_default_model}；nextGoal = {...goal} 只改 4 键 → 不触碰
  condition/gates/gate_config（平行配置维度，与 SKILL.md 字段边界一致）
- --clear <target>：indexOf 后取后续 token 清对应键
- 展示优先级链文案与 shell fk_resolve_model 注释逐字一致

## 3. doctor correction 报告

- 无文件 → ✅ 无待办纠正（卫生良好）
- violations>0 → ⚠️ type=…, violations=N (去重后的 check 逗号列表)
- 无 violations 有 message（l2/l3-model-missing）→ ⚠️ type=… — message
- 解析失败 → ⚠️ 读取失败 — <原因>（fail-open，不影响诊断其余项）

## 4. 关键决策记录

- 降挡提交（gate off）只作为过渡，凭证就绪后恢复 both 并补审（见 REVIEW.md）。
- 归档产物按上游惯例补齐（archive-commit-gate 等 small change 均有全套文档）。
