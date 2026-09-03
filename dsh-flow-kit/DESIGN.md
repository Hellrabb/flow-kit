# dsh-flow-kit 技术设计（DSH 插件化 · 与 Claude Code 解耦）

> 状态：round 1 基线设计。所有 flow-kit 原有技术设计（L2/L3 四层独立审查、
> gate_config PRESET_MAP、.done 真实性校验、pipeline goal、interrupt/checkpoint）
> **原样保留**，本文只定义「如何从 Claude Code 承载面迁移到 dsh 承载面」。

## 1. 解耦原则

1. **内容零丢失**：`flow-kit-bundle/` 的 298 个文件原样打包进
   `vendor/flow-kit-bundle/`（含 install.sh、lib/、test/、specs-template/），
   同时把运行所需的 `skills/`、`flow-kit/`、`hooks/`、`brooks-lint/` 提升到
   npm 包顶层。
2. **壳层解耦**：shell hook 链不重写，只新增 `runtime-adapter.sh` 决定运行平台
   的目录与凭证优先级；dsh 插件用 `hook-bridge.js` 合成 Claude 形状的 JSON 事件
   喂给同一个 shell 链。
3. **无 Claude 运行时依赖**：插件不读 `~/.claude`、不读 `CLAUDE_PROJECT_DIR`、
   不写 Claude hooks JSON。项目根来自 `FLOW_KIT_PROJECT_DIR` → session.cwd →
   `process.cwd()`。
4. **状态文件契约不变**：`.flow-active` 与 `.specs/<id>/` 的 JSON/Markdown 契约
   是跨平台唯一事实源，Claude Code / opencode / dsh 三端共享同一套状态机。

## 2. 运行时目录映射（runtime-adapter.sh）

| 用途 | claude（legacy） | opencode | dsh |
|---|---|---|---|
| 项目配置目录 | `.claude/` | `.claude/`（opencode-claude-hooks 桥接兼容） | `.flow-kit/` |
| stop-hook 配置 | `.claude/stop-hook.json` | `.claude/stop-hook.json` | `.flow-kit/stop-hook.json`（由插件从包默认值落盘） |
| 项目记忆 MD | `CLAUDE.md` | `CLAUDE.md` | `AGENTS.md` |
| 用户 memory 根 | `~/.claude/projects<slug>/memory` | `~/.claude/projects<slug>/memory` | `~/.dsh/projects<slug>/memory` |
| 报告/建议/状态文件 | `.claude/stop-hook-*` | `.claude/stop-hook-*` | `.flow-kit/stop-hook-*` |

运行时检测优先级：`FLOW_KIT_RUNTIME`（dsh 插件注入 `dsh`）→
`OPENCODE_BIN/OPENCODE` → 默认 `claude`。所有历史测试在默认 claude 分支下
保持零回归。

## 3. L2/L3 独立审查机制（四层架构 · 原样保留 + dsh 派发面）

flow-kit 的独立审查是四层架构，dsh 化时**一层都不动**：

1. **PRESET_MAP 层**：`/flow goal --gate-config <preset>`。
   `flow-state.js` 内的 `PRESET_MAP` 与 shell `fk_normalize_gate_val()` 保持
   单一来源同步（`independent|true → both`；`L2|L3|both` 直通）。
2. **Prompt 层**：`flow-kit/prompts/independent/L2-blind-review.md` 与各阶段
   prompt 的「独立 review 调度」段照抄进包。
3. **Hook 层**：
   - `PreToolUse` = dsh `tools/pre-execute` 瀑布（同步否决，exit 2 → deny）。
     `independent-review-gate.sh` 的 7 道 gate（path-guard、phase filter、
     gate active、done validation Tier1+2、tamper detect、phase transition、
     deny reason）全量运行。
   - `Stop` = dsh `agent/status → idle`（主 agent 回合结束）。`00-gate.sh`
     分发 01-transcript-parse → 20..34 → 99-report 全链；dsh session 日志被
     `synthesizeTranscript()` 转成 Claude transcript 形状供 01 解析。
4. **L2-blind-review 层**：dsh 下首选 `/flow l2-review <phase>` 命令
   （`lib/l2-review.js` → `ctx.subagents.start(provider="spawn", …)`），prompt
   原样注入 `L2-blind-review.md` 全文 + 阶段/change_id/工件/输出路径；子代理
   结束后校验 `.specs/<id>/INDEPENDENT-REVIEW-<phase>.md` 真实落盘，未写
   `## L2 盲审` 段则 L2-first 契约报错。无 subagents 服务时回退 `subagent`
   tool 手动派发模板；`l2_dispatch_prompt()` 已输出 dsh 专用派发模板；
   `l2_dispatch_agent()` 在 dsh 下沿用 `FLOW_KIT_L3_BASE_URL/FLOW_KIT_L3_AUTH_TOKEN`
   Path3 凭证链。

**L2-first 契约不变**：`gate_config=both` 时先 L2 段（`## L2 盲审`）再 L3，
缺失时写 `.flow-active.correction`（`type=l2-missing`），L3 跳过。
**.done 真实性校验不变**：`.specs/<id>/.independent-review-<phase>.done` 是
作者性锚点；`l3_review_run` 在 hook 进程写 done 不经 PreToolUse（架构天然隔离），
agent 直写被 path-guard 拦截；Tier1/Tier2 校验 + D8 篡改检测 + `.goal-snapshot.json`
全部保留。

## 4. Hook 事件映射（hook-bridge.js）

| Claude Code hook | dsh 事件 | 模式 | 对应 shell 入口 |
|---|---|---|---|
| PreToolUse（Bash\|Write\|Edit） | `tools/pre-execute` | 同步瀑布，可 deny | `hooks/pre-tool-use/independent-review-gate.sh` |
| PreToolUse（Write\|Edit） | `tools/pre-execute` | 同步瀑布，可 deny | `auto-checkpoint.sh`、`runtime-edit-guard.sh` |
| Stop（主 agent 回合结束） | `agent/status` → `{status:"idle"}` 且非 subagent | 异步链 | `hooks/stop/00-gate.sh`（→01..99 全模块） |
| SessionStart（startup） | `agent/created` 且非 subagent | 同步（保证首轮 prompt 可见） | `stop-report-reminder.sh`、`flow-kit-resume.sh`；stdout → `ctx.systemPrompt.context` 一次性 banner |
| PostToolUse（未来扩展） | `tools/post-execute` | 异步 | `hooks/post-tool-use/*.sh`（若存在，按名排序） |

dsh 工具名映射：`bash→Bash`、`write→Write`、`edit→Edit`、`read→Read`。
PreToolUse JSON 合成：`hook_event_name/session_id/cwd/tool_name/tool_input`。
Stop JSON 合成：额外生成 `transcript_path`（dsh session.events → Claude 形状
JSONL：`user/message`→user、`assistant/message`→assistant、`tool/call`→tool_use、
`tool/result`→tool_result）。

## 5. 凭证与模型解析（多平台）

`fk_resolve_api_credentials()`：
- claude：`ANTHROPIC_AUTH_TOKEN`（Path1）> `FLOW_KIT_L3_*`（Path3）> `ANTHROPIC_API_KEY`（Path2）
- opencode / dsh：`FLOW_KIT_L3_*`（Path3）> `ANTHROPIC_AUTH_TOKEN`（Path1）> Path2
- rc 语义不变：0 就绪 / 1 无凭证 / 2 Path3 不完整；AC-6 红线（凭证值不落盘）不变。

`fk_resolve_model()` 优先级链不变（env > `.flow-active.goal.l2_model/l3_model`）；
`/flow model` 命令写入持久化兜底。

## 6. 插件结构

```
dsh-flow-kit/
├── package.json            # dsh.bundle.patch → cordis.patch.yml
├── cordis.patch.yml        # - insert: id=flow-kit, inject=[commands]
├── lib/
│   ├── index.js            # apply(): 注册 skills + /flow + 挂 hook bridge
│   ├── flow-state.js       # /flow 状态机（.flow-active 全子命令 + PRESET_MAP）
│   ├── l2-review.js        # /flow l2-review：dsh 子代理 L2 盲审派发 + 契约校验
│   ├── hook-bridge.js      # dsh 事件 → Claude 形状 JSON → shell hook 链
│   └── skill-loader.js     # 扫描 SKILL.md frontmatter → ctx.skills.register()
├── skills/                 # flow-kit 17 个 skill（原样）
├── flow-kit/               # GO/RULES/prompts/templates/reference/scripts（原样）
├── hooks/                  # 全量 shell hook 链（含 runtime-adapter.sh 解耦层）
├── brooks-lint/            # 代码审查插件（原样）
├── docs/                   # FLOW-KIT-用户指南 / 生态指南
└── vendor/flow-kit-bundle/ # 完整原始 bundle（零丢失，含 install.sh+test）
```

## 7. 验证策略

- `bash package-dsh-plugin.sh`：组装 `dist/dsh-flow-kit` + node 单测 + `node --check` + `bash -n` 全量扫描
- 单元：`node --test dsh-flow-kit/test/*.test.mjs`（flow-state / hook-bridge /
  skill-loader；round 2 共 14 用例全绿，含 Stop 链端到端：合成 transcript →
  00-gate → `.flow-kit/stop-hook-state.json`）
- 回归：`make test`（root `test/` 770 用例全绿）+ `make lint` + `make check-test-sync`
- 集成：`dsh --profile flowkit-test --dump-config` 确认 `flow-kit` 行挂载
  （inject: commands+skills）；apply() smoke 验证 23 skills + /flow 注册

## 8. 与 flow-kit 的同步契约（flow-kit 更新 → 插件更新）

flow-kit 的唯一维护源是仓库根 `flow-kit-bundle/`。flow-kit 更新后，插件按
四层义务跟进：

1. **内容层（自动）**：重跑 `bash package-dsh-plugin.sh` —— skills/flow-kit/
   hooks/brooks-lint 与 `vendor/` 全部从 `flow-kit-bundle/` 重新拷贝。
   correction 卫生、状态守卫、lint 清零等纯内容更新无需改动插件代码。
2. **契约层（手动核对）**：flow-kit 改动的对外契约若触及插件 JS 侧需同步：
   - `.flow-active` / `.flow-active.correction` 契约 → `lib/flow-state.js`
     （`/flow doctor` 等读这些文件的入口）
   - hook JSON 事件形状 → `lib/hook-bridge.js`
   - skills frontmatter → `lib/skill-loader.js`
   - PRESET_MAP → `flow-state.js` 与 `fk_normalize_gate_val()` 双源同步
3. **版本层**：`package.json` 语义化递增（纯内容同步 = minor）。
4. **验证层**：`bash package-dsh-plugin.sh`（内置单测 + 语法全量扫描）、
   vendor 逐字节 diff、`make test` 回归、profile `pnpm install` 重装 +
   `--dump-config` 挂载确认。

最近一次同步（2026-09 → v0.2.0）：correction-hygiene-state-guard（ADR-024：
correction-file.sh 去重/FIFO/类型剥离 + 9 项状态完整性检查白名单 +
l2/l3-model-missing 类型）、shellcheck 清零（TD-023）、install.sh dsh 平台分支、
hooks/config/README.md；`/flow doctor` 同步新增 correction 卫生报告；
L2/L3 站点级默认模型 tier（五级解析链）：`/flow model` 同步 l2-default=/
l3-default=/--clear <target>，写 `.goal.l{2,3}_default_model` 与
`fk_resolve_model` tier-4/5 对齐（显式压过默认；默认不改变无凭证跳过语义）。

平台确认串声明（phase 6 L2 R3 处置）：SKILL.md L257 的 `✅ model[l3] = <value>`
确认串为 claude 承载面契约；本插件 JS 实现（flow-state.js）采用「✅ 已更新。」+
全量五级配置摘要作为 dsh 平台差异（语义一致：写入后回显新值），后续审查不应
重复按 SKILL.md 逐字比对该行。
