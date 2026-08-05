# TEST.md — 阶段 5 测试执行记录

- **change**: l2-l3-subagent-fix · 阶段 5 · 2026-08-05
- **目标**: 调查解决 L2/L3 拉起 subagent 双平台失败问题
- **性质**: 纯调查 + 3 项 low 风险修复（.flow-active 配置 / qa-expert agent 声明 / l2-detect.sh 提示路径）
- **平台**: opencode 1.18.9（本机实测环境）；claude code 2.1.71（对照环境，无法本机运行）

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由（如跳过） |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | AC-1..AC-5 全部（派生用例见下） | — |
| 第 2 轮 · 性能 | ❌ 跳过 | — | Bash 脚本 + agent 配置，无 Lighthouse/bundle；L2 派发耗时已实测（4s vs 30min 超时） |
| 第 3 轮 · 安全 | ⚠️ 部分 | 凭证脱敏 + 禁动清单 diff 边界 | 内部工具；OWASP 减项；凭证值全程脱敏 ***（AC-2） |
| 第 4 轮 · 兼容 | ⚠️ 部分 | 双平台差异矩阵（opencode 实测 / claude code 静态对照） | 本机无 claude code 运行时，e2e 归 v2；双平台 agent 定义 diff 已静态验证 |
| 第 5 轮 · 可观测 | ⚠️ 部分 | 降级路径可观测性（l2-dispatch 日志 + 平台探测提示） | CLI 工具无运行时指标；修复③新增提示已实测输出 |

## 第 1 轮 · 功能测试（AC 派生用例）

### AC-1 根因报告五段 + 四环节实测
| 用例 | 预期 | 结果 |
|---|---|---|
| ROOT-CAUSE.md 五段齐全 | grep -cE '^## (现象矩阵\|根因链\|双平台差异矩阵\|风险分级修复方案\|受影响模块清单)' ≥ 5 | ✅ 5 段（T06 verify） |
| 四环节锚点 | grep -cE 'l2-detect\|independent-review-gate\|prompt 派发段\|env var 透传\|l3-review' ≥ 4 | ✅ 7 锚点（T06 verify） |
| 环节① 派发模板生成 | l2_dispatch_prompt 3 → subagent_type=architect-reviewer | ✅ exit 0（EVIDENCE-1） |
| 环节② gate 触发链路 | opencode 零触发（结构性根因） | ✅ 三侧实测（EVIDENCE-2） |
| 环节③ task 路由 | category 4s / subagent_type 30min 超时 | ✅ 鉴别实验（EVIDENCE-3） |
| 环节④ env 透传 | fk_resolve_model 空串 → 修复①后 deepseek-v4-flash | ✅ 前后对照（EVIDENCE-4） |

### AC-2 双平台证据 + 脱敏
| 用例 | 预期 | 结果 |
|---|---|---|
| 双平台各 ≥1 实测/对照 | opencode 实测 + claude code 静态对照 | ✅（EVIDENCE-5 可达性表 + diff 表） |
| 凭证脱敏 | env 值一律 ***，只显示变量名+状态 | ✅（EVIDENCE-1..5 无凭证值） |
| 不可复现标注 | claude code e2e 不可本机复现 → 标注 | ✅ DEV-SUMMARY「不可行/未实施项」 |

### AC-3 risk 分级
| 用例 | 预期 | 结果 |
|---|---|---|
| 每条修复方案 risk 标注 | grep -cE 'risk: (low\|high)' ≥ 1 | ✅ 7 方案全标（ROOT-CAUSE 风险表） |
| high 触禁动归 v2 | D5-③/④/⑤ 标注 high + v2 | ✅ |

### AC-4 修复实施 + opencode 实测拉起
| 用例 | 预期 | 结果 |
|---|---|---|
| 修复① /flow model 配置 | fk_resolve_model L2/L3 = deepseek-v4-flash | ✅ 实测（PROJECT_ROOT=$PWD） |
| 修复② qa-expert sonnet→inherit | 文件已改 + 双平台对齐 | ✅ 但鉴别实验证明不解决 subagent_type 路由 |
| 修复③ 凭证缺失提示 | opencode 探测 + category= 指引 | ✅ 实测输出 |
| category 路由拉起 | 4s 完成 | ✅（阶段 2/3 L2 盲审真实运行佐证） |
| 真实运行时（非 mock） | task 工具真实调用 | ✅（mock 边界合规） |

### AC-5 基线
| 用例 | 预期 | 结果 |
|---|---|---|
| npx bats 0 fail | `[ "$(npx bats test/ 2>&1 \| grep -c '^not ok')" = "0" ]`（L2 盲审 N2 假绿缓解：本次实测补断言 `npx bats` 退出码 = 0 且 `^ok ` 计数 692 非空，三证合一防 bats 启动失败误判） | ✅ 692 ok / 0 not ok（T08，退出码 0 + plan 1..692 独立复核） |
| 非 0 时归因 | 不适用（全绿） | — |

### 边界用例（≥3）
1. 凭证缺失（无 ANTHROPIC_*）→ 降级 return 1 + 平台提示（实测）
2. subagent_type 路由（inherit 对照）→ 30min 超时（鉴别实验，边界=与 model 值无关）
3. gate 双引号 transition 绕过（_fk_phase_direction 转义）→ 漏检（EVIDENCE-2 附加发现）
4. mock 路径（FLOW_KIT_L2_MOCK=1）→ return 0 + mock 段写入（EVIDENCE-1）

## 第 3 轮 · 安全（部分）

- 凭证扫描：EVIDENCE/SUMMARY/ROOT-CAUSE/DEV-SUMMARY 全部 grep 确认无 `ANTHROPIC_AUTH_TOKEN`/`API_KEY` 值（只出现变量名）
- 禁动清单 diff 边界：`git diff --stat` 无 independent-review-gate / 29-independent-review / l3-review / checkpoint-lib / done-validation / gate-helpers 命中（✅ 0 命中）
- 变更文件仅 3：.flow-active（配置）/ ~/.config/opencode/agents/qa-expert.md（agent 声明）/ l2-detect.sh（提示路径，非禁动）

## 第 4 轮 · 兼容（部分）

- 双平台差异矩阵 6 维（ROOT-CAUSE）：hook 事件 / gate 注册 / agent 模型声明 / 认证方式 / 派发语法 / L2L3 审查
- 双平台 agent diff：74 交集 agent 仅 qa-expert model 分歧（EVIDENCE-5 表）
- 修复① 平台无关（.flow-active 双平台同读）；修复② 对齐 claude code 侧；修复③ 平台探测双分支（opencode/claude code 提示）

## 第 5 轮 · 可观测（部分）

- 修复③新增可观测输出：[l2-dispatch] no API credentials + [l2-dispatch] opencode 检测到：…（实测）
- L2 派发耗时差异：category 4s vs subagent_type 30min 超时（可观测指标）
- l2-dispatch 日志路径 ${specs_dir}/.l2-dispatch-${phase}.log（既有机制，未改动）

## 回归测试登记（R5.2）

- 本次修复产生的行为变更已通过以下既有测试覆盖（npx bats 全量 692 通过）：
  - l2-detect.sh 修改（凭证提示）→ test/ 中 l2-dispatch 相关用例全绿
  - 无新 bug 产生，无需新增回归用例；鉴别实验结论已入 EVIDENCE-3/ROOT-CAUSE
- LESSONS 建议：subagent_type 路由 agent=undefined（opencode 平台）→ L2 派发走 category 路由

## 测试质量 6 维自检（第 1 轮）

- 可读性 ✅ / 确定性 ✅（全部基于实测输出与文件断言）/ 快速 ✅（5 轮均在 T06-T08 verify 内完成）
- 隔离 ✅（task 路由测试用最小 prompt）/ 无共享状态 ✅ / 覆盖率：AC-1..AC-5 全覆盖（表逐行）

## 结论

- 全部 AC 通过；5 轮状态已声明（功能必跑，性能跳过，安全/兼容/可观测部分）
- 无 🔴 问题 → 无需回退 4-dev
- 测试新增用例已登记（上表）
