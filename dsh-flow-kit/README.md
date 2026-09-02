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
export FLOW_KIT_L3_MODEL=<模型名>
export FLOW_KIT_L2_MODEL=<模型名>
```

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
