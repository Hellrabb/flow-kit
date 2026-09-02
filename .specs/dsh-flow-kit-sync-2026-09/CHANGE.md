# CHANGE — dsh-flow-kit-sync-2026-09

> 状态：done（phase 7 · 降挡提交，见「独立审查」段）

## 背景

flow-kit 在 2026-09 完成一轮更新：

- correction-hygiene-state-guard（ADR-024）：`correction-file.sh` 去重/FIFO/类型
  剥离 + 9 项状态完整性检查白名单 + l2/l3-model-missing 类型；29/33 号 hook 更新
- shellcheck 清零（TD-023，64→28）
- install.sh/paths.sh 增加 dsh 平台分支；hooks/config/README.md
- L2/L3 站点级默认模型 tier：`fk_resolve_model` 五级解析链新增 tier-4/5
  （`FLOW_KIT_L{2,3}_DEFAULT_MODEL` env + `.goal.l{2,3}_default_model` 字段），
  `/flow model` 新增 l3-default=/l2-default=/--clear（commit 2999024，同步期间落地）

dsh 插件 `dsh-flow-kit` 打包产物仍停留在 2026-08-16 的 0.1.0，需要同步。

## 范围

- 版本 0.1.0 → 0.2.0
- `lib/flow-state.js`：`/flow doctor` 新增 `.flow-active.correction` 卫生报告
  （type + violations 去重摘要，对齐 ADR-024）
- `lib/flow-state.js`：`/flow model` 同步五级解析链——l2-default=/l3-default=
  写站点默认字段，`--clear <l2|l3|l2-default|l3-default>` 清对应字段，仅触碰
  4 个模型字段
- 测试：doctor correction 报告 + model 五级链断言（19→20 用例）
- 文档：DESIGN.md 新增 §8 同步契约；README.md 新增「同步 flow-kit 更新」流程；
  VERIFY.md round 5 记录
- 重打包 dist/dsh-flow-kit（vendor 逐字节一致）+ web / flowkit-test 两 profile
  重装并确认挂载

## 验证

- `bash package-dsh-plugin.sh`：单测 20/20 + node --check + bash -n 全量扫描
- vendor 零丢失 diff 通过；root test/ bats 全量 770 ok / 0 fail
  （含 test_fk_resolve_model 五级链 +6 用例）
- make lint（shellcheck error 级）通过；make check-test-sync 通过
- 两 profile `--dump-config` 确认 flow-kit 行挂载（commands+skills+systemPrompt）

## 独立审查（降挡）

- 本变更 = 内容同步 + 文档 + 测试，无新流程逻辑
- 运行环境未配置 FLOW_KIT_L3_* 凭证，L3 外部模型审查无法执行（仅能降级为
  l3-model-missing 纠正）
- 按 gate 脚本 hotfix 路径处理：gate_config 7-integration=off（记录于
  .specs/CHANGELOG.md）
- 如需补审：/flow l2-review 7 可随时派发 L2 盲审

---
created: 2026-09-02T18:12:02.482Z
