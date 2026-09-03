# REQUIREMENT — dsh-flow-kit-sync-2026-09

> 阶段 7 补审归档产物（2026-09-03 回顾补档）。本 change 走降挡 hotfix 路径，
> 原无逐阶段文档；此处按实际完成的工作如实记录，供独立审查证据链闭环。

## 1. 背景与动机

flow-kit 在 2026-09 更新了 hook 链与技能契约，而 dsh 插件 dsh-flow-kit 的
打包产物仍停留在 2026-08-16（v0.1.0）：

- correction-hygiene-state-guard（ADR-024）：correction-file.sh 去重/FIFO/类型剥离 +
  9 项状态完整性检查白名单 + l2/l3-model-missing 类型（commit 9a81098 等）
- shellcheck 清零 TD-023（47c68ef）
- install.sh/paths.sh dsh 平台分支 + hooks/config/README.md（76261dc）
- L2/L3 站点级默认模型 tier：fk_resolve_model 五级链 tier-4/5（2999024，同步期间落地）

目标：把插件与 flow-kit 最新内容对齐并发布 v0.2.0。

## 2. 范围（In scope）

- 插件包版本 0.1.0 → 0.2.0
- lib/flow-state.js：/flow doctor 增 .flow-active.correction 卫生报告
- lib/flow-state.js：/flow model 对齐五级链（l2-default=/l3-default=/--clear）
- 单测：doctor + model 五级链断言（19→20 用例）
- 文档：DESIGN §8 同步契约 / README 同步流程 / VERIFY round 5
- 重打包 dist + web/flowkit-test 两 profile 重装并验证挂载
- 独立审查补审：L2 盲审子代理 + L3 外部模型（2026-09-03，用户配置凭证后）

## 3. 范围外（Out of scope）

- flow-kit 核心引擎语义（correction 卫生、五级链、hook lint）属上游 commit
  范围（9a81098/2999024 等已由其自身流程审查），本 change 只搬运不重写。
- L2/L3 审查机制本身的行为修改。

## 4. 验收准则（AC）

- AC-1：dist/dsh-flow-kit 由 flow-kit-bundle HEAD 重打包；vendor 逐字节一致
  （diff -rq 空输出）。
- AC-2：/flow model l2-default=/l3-default= 写入 .goal.l{2,3}_default_model，
  --clear <target> 清除对应字段；仅触碰 4 个模型字段；设置后回显显示**新值**
  （L2 R1 回归断言覆盖）。
- AC-3：/flow doctor 在 .flow-active.correction 存在时输出
  type=…, violations=N（去重 check 摘要）；无文件时提示卫生良好。
- AC-4：package.json version=0.2.0；files 字段含 vendor/skills/flow-kit/hooks/
  brooks-lint/docs。
- AC-5：插件单测 20/20；root test/ bats 770/770；make lint + check-test-sync 通过。
- AC-6：web 与 flowkit-test 两 profile node_modules 刷新为 0.2.0，
  --dump-config 均含 id: flow-kit（inject: commands+skills+systemPrompt）。

## 5. 版本

2026-09-02 提交（868f362 前身）→ 2026-09-03 补审（L2 一次 pass + L3 一次 fail
后补齐归档再重审）。
