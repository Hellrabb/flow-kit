# dsh-flow-kit 验证清单（round 1 基线）

## 一键验证

```bash
# 1) 打包（内部跑 node 单测 + node --check + bash -n 全量）
bash package-dsh-plugin.sh

# 2) 单测（flow-state / hook-bridge / skill-loader）
node --test dsh-flow-kit/test/*.test.mjs

# 3) claude 分支回归（默认 runtime 零回归；round1 基线 751 ok / 9 pre-existing fail）
bats --recursive flow-kit-bundle/test

# 4) 完整性：vendor 必须与 flow-kit-bundle 逐字节一致
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle

# 5) dsh profile 挂载（test profile 位于 ~/.dsh/profiles/flowkit-test）
dsh --profile flowkit-test --dump-config | grep -A 7 'dsh-flow-kit'
# 期望: - id: flow-kit / inject: [commands, skills]
```

## round 1 已验证

- `flow-state.js`：gate_config 三段式解析、PRESET_MAP、--l2-only/--l3-only、
  pipeline goal 快照、start/stop/phase/task/checkpoint/model 全部通过（7 用例）
- `hook-bridge.js`：PreToolUse git-commit deny（L3 .done 缺失 → exit 2 → deny）、
  普通 bash 放行、.flow-kit/stop-hook.json 落盘（3 用例）
- `skill-loader.js`：发现并注册 23 个 flow-*/brooks-* skill（2 用例）
- `runtime-adapter.sh`：默认 claude 零回归；FLOW_KIT_RUNTIME=dsh → .flow-kit /
  ~/.dsh / AGENTS.md 路径正确
- dsh 配置树：`flow-kit` 插件行已挂载（commands + skills inject）
- apply() smoke：/flow 注册 + 23 skills 注册 + 事件监听挂载成功

## 未完成（后续 round）

- dsh headless 全链路真机 boot（node-pty native 二进制 + 嵌套 dsh 限制；当前用
  dump-config + apply smoke 替代）
- Stop 链端到端（synthesizeTranscript → 00-gate → 01..99）真机触发验证
- install.sh 增加 dsh 平台分支（当前 dsh 安装走 pnpm + cordis patch，无需 install.sh）
- brooks-lint 的 dsh 命令化（当前随包分发 skill/scripts，未注册 dsh 命令）

## round 2 新增验证

- `make test` 全绿（root test/ 760 用例）——修掉 2 个既有失败：
  - test 324 改为源码树读取（旧测试依赖陈旧的 ~/.claude 安装副本）
  - 4-dev.md 恢复内联「非每操作」声明（技术设计未丢，原本只在 reference）
- Stop 链端到端：`runStopChain(假 agent)` 验证 transcript 合成 → 00-gate →
  `.flow-kit/stop-hook-state.json`（stop_count≥1）
- 提示词 L2/L3 检测块已 dsh 化：`gate_config` 或运行时 stop-hook.json
  （dsh `.flow-kit/`，claude `.claude/`）双源
- `flow-go` / `flow` / `flow-kit-install` skill 已加 dsh 路径说明
- `20-claude-md` 输出按运行时显示 AGENTS.md / CLAUDE.md；25/26 的
  worktree、hook-conflict 检查 dsh 感知

## round 2 · dsh 真机验证

- 测试 profile 加入 `@deepseek-ai/dsh-headless` bundle 后，`dsh --profile flowkit-test "<prompt>"`
  真实 headless 启动成功（首个 smoke：模型回复 `flowkit-ok`，exit 0）
- headless 会话内 `/flow`（无参）交互返回预期：`当前没有活跃的 flow。用 /flow start 开始。`
- headless 会话内 `/flow start` 后项目根出现合法 `.flow-active`（JSON 有效，
  change_id=null / goal=null / phase=0）
- 曾暴露并被修复：runtime skill 注册缺少 `source` 字段导致 dsh 启动报
  `loaded skill "flow" source must be a string` → `skill-loader.js` 已补
  `source: "bundled"`，修复后 headless 启动零报错

## round 3 新增验证

- `/flow l2-review`：dsh 原生 L2 派发（ctx.subagents provider=spawn）
  - mock：真机 headless 执行后落盘 `## L2 盲审（mock）`，exit 0
  - 真实：真机 headless 派发 L2 子代理，子代理独立审查并写出
    `## L2 盲审` + 4 项四要素 finding + **Verdict: fail**，父命令校验
    契约满足后报告结论（真实演示了独立性硬约束 #2 的污染标注）
- node 单测增至 18/18（新增 l2-review 4 用例）
- make check 持续全绿

## round 4 新增验证

- SessionStart hook stdout 注入：hook-bridge 同步执行 SessionStart 脚本
  （agent/created 回调内），banner 写入 `ctx.systemPrompt.context`
  （flow-kit:session-banner），真机 headless 模型在 system prompt 中
  原样引用「上次 Stop Hook 报告待 Review」banner，exit 0
- 修复真机暴露的 `cannot get property "systemPrompt" without inject`：
  cordis inject 增加 systemPrompt
- codegraph 已 sync 到最新插件源码：32 files / 407 nodes / 1011 edges，
  `query runL2Review` / `explore "L2 review dispatch"` 可查到 l2-review.js
  全部符号与调用点
- node 单测 19/19

## round 5 · flow-kit 2026-09 同步（v0.2.0）

- 同步内容：correction-hygiene-state-guard（ADR-024）、shellcheck 清零（TD-023）、
  install.sh dsh 平台分支、hooks/config/README.md、L2/L3 站点级默认模型
  tier（五级解析链，`fk_resolve_model` tier-4/5 + `/flow model`
  l2-default=/l3-default=/--clear）
- `flow-state.js` doctor 新增 `.flow-active.correction` 卫生报告
  （type + violations 去重摘要）；单测新增 doctor 用例 19→20
- `bash package-dsh-plugin.sh` 重打包 → `dist/dsh-flow-kit-0.2.0.tgz`；
  内置单测 20/20 全绿 + node --check + bash -n 全量扫描通过
- vendor 零丢失：`diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle`
  逐字节一致；新内容（correction-file.sh、hooks/config/README.md）已在包内
- 回归：root `test/` 全量 bats 770 ok / 0 fail（phase 5 L2 R1 修正表述——
  定向逐文件计数：correction_hygiene 10 + flow_active_integrity 19 +
  install_dsh_platform 2 + fk_resolve_model 16 = 47 ok，命令见 TEST.md）
- profile 重装：web + flowkit-test `pnpm install` → node_modules 刷新为 0.2.0
  （flowkit-test 顺带把 pnpm 10 allowBuilds 四条目置 true，node-pty 等原生
  构建恢复）；两 profile `--dump-config` 均确认
  `id: flow-kit` 行挂载（inject: commands + skills + systemPrompt）；
  dsh 重启后生效
