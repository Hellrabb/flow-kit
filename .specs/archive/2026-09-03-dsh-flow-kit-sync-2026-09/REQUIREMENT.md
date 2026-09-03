# REQUIREMENT — dsh-flow-kit-sync-2026-09

> 阶段 7 补审归档产物（2026-09-03 回顾补档；阶段 1 L2 盲审 R1-R4 已吸收：
> AC 改 Given/When/Then、补 v2 与 NFR 段、验证证据落点标注）。本 change 原走
> 降挡 hotfix 路径，无逐阶段文档；此处按实际完成的工作如实记录。

## 1. 背景与动机

flow-kit 在 2026-09 更新了 hook 链与技能契约，而 dsh 插件 dsh-flow-kit 的
打包产物仍停留在 2026-08-16（v0.1.0）：

- correction-hygiene-state-guard（ADR-024）：correction-file.sh 去重/FIFO/类型剥离 +
  9 项状态完整性检查白名单 + l2/l3-model-missing 类型（commit 9a81098 等）
- shellcheck 清零 TD-023（47c68ef）
- install.sh/paths.sh dsh 平台分支 + hooks/config/README.md（76261dc）
- L2/L3 站点级默认模型 tier：fk_resolve_model 五级链 tier-4/5（2999024，同步期间落地，
  其自身流程已审查；本 change diff 基线为 2999024..HEAD）

目标：把插件与 flow-kit 最新内容对齐并发布 v0.2.0。

## 2. 范围切分（v1 / v2 / out）

### v1（本次交付）

- 插件包版本 0.1.0 → 0.2.0
- lib/flow-state.js：/flow doctor 增 .flow-active.correction 卫生报告（含
  compliance 类 rule 字段回退）
- lib/flow-state.js：/flow model 对齐五级链（l2-default=/l3-default=/--clear，
  写入回显新值）
- 单测：doctor（state-integrity + compliance + model-missing 三形状）+ model
  五级链断言（19→20 用例）
- 文档：dsh-flow-kit/DESIGN §7 计数修正 + §8 同步契约 + 平台确认串声明；
  README 同步流程；VERIFY round 5
- 重打包 dist + web/flowkit-test 两 profile 重装并验证挂载
- 独立审查补审：L2 盲审（1/2/3/5/6/7）+ L3 外部模型（1/2/3/5/6/7），
  gate_config=all（2026-09-03，用户配置凭证后）

### v2（暂缓，后续 round）

- dsh headless 全链路真机 boot 验证（node-pty 嵌套限制，沿用 VERIFY「未完成」项）
- Stop 链（synthesizeTranscript → 00-gate → 01..99）真机触发验证（本补审用
  直调 l3_review_run 完成审查语义；全链 smoke 待后续）
- brooks-lint 的 dsh 命令化（当前随包分发 skill/scripts，未注册 dsh 命令）
- flow-kit-bundle/hooks/stop/lib/common.sh:238 注释头 3-tier→5-tier（上游内容层
  修正，见 MINOR-DEFERRED.md）

### out（明确不做）

- flow-kit 核心引擎语义的修改（correction 卫生、五级链、hook lint 属上游 commit
  范围，本 change 只搬运不重写）
- L2/L3 审查机制本身的行为修改

## 3. 非功能性需求（NFR）

- 兼容性：.flow-active / .flow-active.correction / .done 状态契约三端
  （claude/opencode/dsh）不变；vendor 零丢失（dist 内 bundle 与源逐字节一致）
- 安全：凭证值不落盘到运行时文件（沿袭上游 AC-6 红线；hook 侧凭证经 env
  注入，FLOW_KIT_L3_* 不在 .flow-active/.specs 落盘）
- 性能/容量/可观测性：无新增（doctor/model 为本地文件 I/O）

## 4. 验收准则（AC · Given/When/Then）

- AC-1（打包一致性）：Given flow-kit-bundle 为当前 HEAD；When 执行
  bash package-dsh-plugin.sh；Then exit 0，且 `diff -rq flow-kit-bundle
  dist/dsh-flow-kit/vendor/flow-kit-bundle` 空输出（证据：脚本日志 +
  TEST.md 记录）。
- AC-2（/flow model 五级链）：Given 一个已 /flow goal 的活跃 flow；When 执行
  /flow model l2-default=X l3-default=Y；Then .goal.l2_default_model=X 且
  .goal.l3_default_model=Y，仅 4 个模型键被触碰，回显含新值（非「未设置」），
  「✅ 已更新。」恰 1 次；When 执行 /flow model --clear l2 l3-default；Then
  .goal.l2_model=null 且 .goal.l3_default_model=null（断言见
  dsh-flow-kit/test/flow-state.test.mjs）。
- AC-3（doctor correction 报告）：Given .flow-active.correction 存在（三类形状：
  state-integrity violations[].check / compliance violations[].rule / 无 violations
  有 message）；When 执行 /flow doctor；Then 输出含 type 原样、violations 数、
  check 或 rule 去重摘要或 message；无文件时提示卫生良好（断言同上）。
- AC-4（版本与 files）：Given dsh-flow-kit/package.json；Then version=0.2.0 且
  files 含 vendor/skills/flow-kit/hooks/brooks-lint/docs。
- AC-5（回归门禁）：Given 本仓库源码树；When 执行 node --test
  dsh-flow-kit/test/*.test.mjs（20/20）、bats test/（770 ok / 0 fail）、
  make lint、make check-test-sync；Then 全部 exit 0（TASK T5 Verify 命令化）。
- AC-6（profile 集成）：Given ~/.dsh/profiles/{web,flowkit-test}；When pnpm
  install 后执行 dsh --profile <p> --dump-config；Then node_modules/dsh-flow-kit
  为 0.2.0 且 dump 含 `- id: flow-kit` / inject: [commands, skills, systemPrompt]
  （证据：INTEGRATION.md 输出摘要；profile 属机器本地状态，不入 git diff）。

## 5. 版本

2026-09-02 提交（868f362 前身）→ 2026-09-03 补审（L2 全阶段 pass ×7 阶段维度；
L3 逐阶段执行，7 首审 fail→归档补齐→重审 pass；1/2/3/5/6 见各 INDEPENDENT-REVIEW-N.md）。
