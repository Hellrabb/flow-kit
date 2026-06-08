# Stop Hook 模块想法

> 本文档记录核心模块 (A/B/C) 之外的扩展想法。
> Phase 1 (A/B/C): ✅ 已完成 · Phase 2 (D/E): ✅ 已完成 · Phase 3 (F/G): ✅ 已完成
>
> **实现日期**: 2026-06-02

---

## 模块 D：代码质量守卫 ✅ `23-quality.sh`

**优先级**: 高 | **复杂度**: 中 | **依赖**: transcript 解析 | **状态**: 已实现

| # | 功能 | 触发条件 | 实现思路 |
|---|------|----------|----------|
| D1 | 测试纪律检查 | `src/*.ts` 变更但 transcript 中无 test 调用 | grep bash-commands.txt 匹配 test patterns，若无则引用「全量测试纪律」memory 警告 |
| D2 | 类型检查提醒 | 同 D1，但提醒 typecheck 命令 | 根据变更路径判断：host 用 `pnpm exec tsc --noEmit`，container 用 `bun run typecheck` |
| D3 | 构建验证提醒 | 关键文件变更但未 build | 检测 Dockerfile、package.json、src/index.ts 变更，提醒对应构建命令 |
| D4 | lint 检测 | 大量代码变更未跑 lint | 变更行数 > 50 且无 lint 命令 → 提醒 |

## 模块 E：Session 分析 ✅ `24-session.sh`

**优先级**: 中 | **复杂度**: 低 | **依赖**: transcript 解析 | **状态**: 已实现

| # | 功能 | 触发条件 | 实现思路 |
|---|------|----------|----------|
| E1 | 工具使用统计 | 每次 Stop | 已有 tool-counts.txt，加上耗时分析（从 transcript timestamp 算） |
| E2 | rtk 优化机会 | Bash 调用中可被 rtk 代理的命令 | grep bash-commands.txt 匹配 `git|docker|cargo|npm|pnpm|kubectl`，对比 rtk 代理列表，估算 token 节省 |
| E3 | subagent 效率 | 本 session 用了 Agent tool | 统计 subagent 种类、数量、失败率（从 tool_result 判断） |
| E4 | session 时长统计 | 每次 Stop | start_time - end_time，轮次，估算 token |
| E5 | context-mode 趋势 | 每次 Stop | 调用 ctx_stats MCP 工具（如果可用），记录到 state file 做趋势图 |

### rtk 优化检测详情 (E2)

```bash
# rtk 代理的命令列表（来自 RTK.md）
RTK_COMMANDS=(git docker cargo npm pnpm kubectl terraform aws gcloud)
# 对每个 bash 命令，检查首词是否在 RTK_COMMANDS 中
# 如果是且没有 rtk 前缀 → 建议优化
# 估算节省: 每次调用节省 ~60-90% token
```

## 模块 F：项目特定守卫 ✅ `25-project.sh`

**优先级**: 中 | **复杂度**: 中 | **依赖**: 项目知识 | **状态**: 已实现

| # | 功能 | 触发条件 | 实现思路 |
|---|------|----------|----------|
| F1 | 容器构建缓存 | `container/` 下文件修改 | 提醒 `docker builder prune` + `./container/build.sh` |
| F2 | pnpm 供应链 | `package.json`/`pnpm-lock.yaml` 变更 | 检查是否新增了 `onlyBuiltDependencies` 或 `minimumReleaseAgeExclude` 条目 |
| F3 | migration 检测 | `src/db/migrations/` 下新文件 | 提醒命名规范（`NNNN-description.ts`）和测试要求 |
| F4 | hook 冲突 | `settings.json` 变更 | diff 分析新增的 hook matcher 是否和已有冲突 |
| F5 | 工作树残留 | `.claude/worktrees/` 非空 | `git worktree list`，列出 stale worktrees，建议 `git worktree remove` |

### 工作树残留检测详情 (F5)

```bash
# 检查 .claude/worktrees/ 下是否有未清理的工作树
WORKTREE_DIR="${PROJECT_ROOT}/.claude/worktrees"
if [[ -d "$WORKTREE_DIR" ]]; then
  for wt in "$WORKTREE_DIR"/*/; do
    # 检查对应的 git worktree 是否还在
    if ! git worktree list | grep -q "$wt"; then
      echo "stale: $wt"
    fi
  done
fi
```

## 模块 G：工作流状态 ✅ `26-workflow.sh`

**优先级**: 低 | **复杂度**: 低 | **依赖**: 文件系统检查 | **状态**: 已实现

| # | 功能 | 触发条件 | 实现思路 |
|---|------|----------|----------|
| G1 | flow-kit 状态 | `.flow-active` 存在 | 解析 JSON，显示 change_id + phase，根据 phase 提示下一步操作 |
| G2 | 暂存文件 | `*.patch`/`*.diff`/`.todo` 存在 | 列出文件，提醒清理 |
| G3 | 临时文件清理 | plan/report 文件残留 | 引用「临时文档不进 git」memory，建议删除超过 N 天的临时文件 |
| G4 | PUA Loop | `~/.claude/pua/loop-*.md` 存在 | 检查是否活跃（heartbeat 时间 < 5min），显示状态 |

### Flow-kit 状态提示详情 (G1)

```bash
# 根据 phase 给出下一步提示
declare -A PHASE_HINTS=(
  [0]="建议 /flow-change 创建变更提案"
  [1]="建议 /flow-design 进行技术设计"
  [2]="建议 /flow-task 拆解任务"
  [3]="建议 /flow-dev 开始开发"
  [4]="建议 /flow-test 执行测试"
  [5]="建议 /flow-review 代码审查"
  [6]="建议 /flow-integration 集成发布"
  [7]="完成！建议 /flow stop"
)
```

---

## 实现优先级

```
Phase 1: ✅ A (CLAUDE.md) + B (Memory) + C (Git) + AI + SessionStart — 2026-06-02
Phase 2: ✅ D (Quality) + E (Session) — 2026-06-02
Phase 3: ✅ F (Project) + G (Workflow) — 2026-06-02
```

## 设计原则

1. **不阻塞**: 任何检查的失败不应阻止 Stop hook 完成
2. **不自动修改**: 建议永远通过 report 文件传递，不直接改源码
3. **不重复提醒**: 同一个建议提醒 N 次后自动静默
4. **可配置**: 所有模块/检查可通过 stop-hook.json 独立开关
5. **快速**: 单个检查 < 500ms，整个 hook < 3s（AI 模块除外，异步不阻塞）
