# dsh-flow-kit

flow-kit 的 DeepSeek Harness（dsh）插件：把完整 flow-kit 生态（17 个 skills、
15+ 阶段 prompts、13 个 templates、reference、L2/L3 独立审查 hook 链、
brooks-lint）打成一个可 `dsh plugin add` 的包，**与 Claude Code 解耦**。

> 当前版本 v0.2.0（2026-09 同步 flow-kit：correction 卫生/状态守卫 ADR-024、
> shellcheck 清零 TD-023、install.sh dsh 平台分支、L2/L3 站点级默认模型
> 五级解析链）。

## 特性

- `/flow` 命令：start / stop / phase / task / checkpoint / goal（含 `--pipeline`、
  `--from`、`--gate-config` 预设与 L2/L3 细粒度开关）/ gate-config / model /
  **l2-review（dsh 子代理 L2 盲审派发）** / doctor
- Hook 桥：dsh `tools/pre-execute`（原 PreToolUse 硬拦截）→ shell gate 链；
  `agent/status → idle`（原 Stop）→ 00-gate 全模块链；
  `agent/created`（原 SessionStart）→ resume/reminder
- L2/L3 独立审查：`L2|L3|both` gate_config、L2-first 契约、`.done` 真实性校验、
  `.goal-snapshot.json` 篡改检测、多平台凭证链全部保留
- correction 卫生（ADR-024）：`.flow-active.correction` 去重/FIFO 容量治理 +
  9 项状态完整性检查白名单；`/flow doctor` 直接报告 correction 类型与待办规模
- 五级模型解析链：`/flow model` 支持 l2=/l3= 显式 + l2-default=/l3-default=
  站点级默认 + `--clear`（与 shell `fk_resolve_model` tier-4/5 对齐）
- 内容零丢失：完整 `flow-kit-bundle` 原样在 `vendor/` 内

## 安装

```bash
# 方式 1：本地构建包
bash package-dsh-plugin.sh
dsh plugin --profile web add file:/path/to/dist/dsh-flow-kit

# 方式 2：npm 发布后
dsh plugin --profile web add dsh-flow-kit
```

首次在项目里运行时，插件会把默认 `stop-hook.json` 落盘到
`<项目>/.flow-kit/stop-hook.json`（不写 `.claude`）。

## 配置

插件行可通过 profile 的 `cordis.patch.yml` 覆盖默认配置：

```yaml
- insert:
    - id: flow-kit
      name: 'dsh-flow-kit'
      inject: [commands]
      config:
        hooks:
          preToolUse: true
          stop: true
          sessionStart: true
        timeoutMs:
          preToolUse: 20000
          stop: 600000
          sessionStart: 30000
```

L2/L3 凭证（dsh 下 Path3 优先）：

```bash
export FLOW_KIT_L3_BASE_URL=<anthropic 兼容端点>
export FLOW_KIT_L3_AUTH_TOKEN=<token>
# 模型两级（fk_resolve_model · common.sh:242-243）：
#   FLOW_KIT_L3_MODEL         —— 具体模型，最高优先（逐次覆盖）
#   FLOW_KIT_L3_DEFAULT_MODEL —— 站点级默认，较低优先（/flow model l3-default= 同源）
export FLOW_KIT_L3_DEFAULT_MODEL=<模型名>
export FLOW_KIT_L2_DEFAULT_MODEL=<模型名>
```

> 完整模板（含 systemd drop-in 安装步骤、可选调优项、工件截断上限说明）见仓库根
> [`.claude/l3.env.example`](../.claude/l3.env.example)。**L3 凭证缺失会导致门禁死锁**：
> hook 不写 `.done`，而 PreToolUse 守卫禁止主 agent 自产 → commit / 阶段推进全部阻塞。

**工件截断上限**（`max_artifact_chars`，缺省 20000）**不在环境变量里配**：由项目级
`<项目>/.flow-kit/stop-hook.json` 的 `independent_review.max_artifact_chars` 决定，
代码自动导出给 L3。大工件项目（如 27KB REQUIREMENT.md）务必提高，否则 L3 只看前
20000 字符，反复报「NFR 缺失 / 锚点表被截断」假阳性。

## 与 Claude Code / opencode 共存

三个承载面共享同一份 `.flow-active` / `.specs` 状态契约。claude 分支保持
`.claude` 默认路径零回归；dsh 分支使用 `.flow-kit`。详见 `DESIGN.md`。

## 同步 flow-kit 更新

flow-kit 内容（hooks / skills / flow-kit / brooks-lint）的唯一维护源是仓库根的
`flow-kit-bundle/`。flow-kit 更新后按以下流程刷新插件：

```bash
# 1) 按语义化递增 package.json 版本号；若契约变化同步 lib/（见 DESIGN.md §8）
# 2) 重打包（脚本内部自动跑 node 单测 + node --check + bash -n 全量扫描）
bash package-dsh-plugin.sh

# 3) 校验 vendor 零丢失
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle

# 4) 重装 profile（file: 依赖需 pnpm install 刷新副本；dsh 重启后生效）
cd ~/.dsh/profiles/<profile> && pnpm install

# 5) 验证挂载
dsh --profile <profile> --dump-config | grep -A 7 flow-kit
```
