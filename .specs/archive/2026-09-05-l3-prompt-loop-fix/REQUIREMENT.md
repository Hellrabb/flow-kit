# REQUIREMENT: 修复 L3 审查 prompt 假阳性循环（截断顺序 + 反馈缺失 + 归档布局解析）

- **Change ID**: l3-prompt-loop-fix
- **关联**: `@.specs/l3-prompt-loop-fix/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想让 phase 7 的 L3 外部审查在满尺寸产物下也能看到 CHANGELOG/LESSONS 注入段，以便弱模型审查不再误报「归档目录缺 CHANGELOG」。
- **US-2**：作为 flow-kit 用户，我想让 L3 重审 prompt 携带前轮发现摘要与主 agent 响应，以便 prompt 诱导的假阳性不会每轮确定性复现、不再需要人工三轮放行。
- **US-3**：作为 flow-kit 维护者，我想让归档布局（`.specs/archive/<id>/`）下的 L3 prompt 构建与活动布局行为一致，以便归档后补跑审查不静默丢失项目级注入。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 反馈段优先于工件正文（截断顺序）

- **Given** fixture 目录含 6 个 ≥3000B 的标准产物（CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW.md，合计 ≥18000B），项目级 `.specs/CHANGELOG.md` ≥1500B 与 `.specs/LESSONS.md` ≥1500B（合计使总注入字节确定 >20000，截断必然发生）
- **When** 调用 `_l3_build_prompt 7 <fixture_dir> 20000`
- **Then** ① 输出以字节计确实被截断（总输出 ≤20000 字节，截断前置事实成立）；② `=== CHANGELOG.md ===` 与 `=== LESSONS.md ===` 段标记仍出现在输出中（反馈段先于工件正文承受截断）
- **验证方式**: `npx bats test/` 新增用例（source lib 后 grep 段标记 + 字节计数断言）

### AC-2 · phase 7 checklist 对齐归档约定

- **Given** 同 AC-1 场景
- **When** 构建 phase 7 prompt
- **Then** checklist 不再出现「SUMMARY」作为归档齐全性要求；CHANGELOG 要求显式标注为项目级 `.specs/CHANGELOG.md`（不要求出现在归档目录）
- **验证方式**: bats 断言锚定 checklist 的固定完整行文案（归档齐全行 + CHANGELOG 说明行各为一整行，非「项目级」子串匹配）；实现文案变更须同步用例

### AC-3 · 归档布局 project_root 解析

- **Given** `artifacts_dir` 为 `<repo>/.specs/archive/<id>/` 形态（含标准产物），`<repo>/.specs/CHANGELOG.md` 存在
- **When** 调用 `_l3_build_prompt 7 <archive_dir> 20000`
- **Then** `=== CHANGELOG.md ===` 与 `=== LESSONS.md ===` 注入段均出现（同一 dirname 解析缺陷对两者同时生效，归档布局断言覆盖两段；当前因 `dirname ×2` 解析到 `.specs` 而静默丢失）
- **验证方式**: bats 用例（fixture 采用 archive 嵌套布局，断言两段标记）

### AC-4 · 前轮发现注入（单行摘要粒度）

- **Given** 前轮审查文件位于 artifacts_dir 内（与产物同目录），命名 `INDEPENDENT-REVIEW-<phase>.md`（多轮重审追加段，不换文件名）；已含前轮发现（提取源两类，至少一类非空：`## L2 盲审` 段的 🔴/🟡 Severity 条目；`## L3` 段的 critical/major JSON 数组项）与 `## 主 agent 响应` 段
- **When** 构建重审 prompt（注入逻辑的函数归属与提取实现由 DESIGN 定）
- **Then** prompt 包含前轮发现摘要 + 主 agent 响应要点，粒度与配额规则：① 摘要为 `severity|file|issue` 单行，按 critical > major（🔴 > 🟡）优先级排序，在 ≤600 字节配额内取前 N 条，溢出时末尾追加 `(+k more)` 标记（配额优先于全量，「每条注入」仅在配额内成立）；② 响应要点为逐条 `Fixed in:` / `Tech-debt:` / `Not-applicable:` 分类标记行，配额 ≤200 字节，同规则裁剪；③ 前轮反馈注入总量 ≤800 字节
- **验证方式**: bats 断言（fixture 审查文件两类提取源各备一份 + grep 摘要行 + 字节计数 + 溢出 fixture 验证 `(+k more)` 裁剪标记）

### AC-5 · 无主 agent 响应段的标注行为

- **Given** 前轮审查文件无 `## 主 agent 响应` 段
- **When** 构建重审 prompt
- **Then** prompt 含明确的「主 agent 未响应」标注，且 AC-4 的发现摘要仍注入
- **验证方式**: bats 断言（fixture 无响应段 + grep 标注）

### AC-6 · 副本同步与回归基线

- **Given** 修复完成并同步
- **When** 对仓库内四处 `l3-prompt.sh`（`flow-kit-bundle/hooks/` + `.claude/hooks/` + `dist/dsh-flow-kit/hooks/` + `dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/`）做 `md5sum`，并运行 `npx bats test/`
- **Then** 仓库内四处副本内容一致（自动化断言，计入 bats 用例）；全量 bats 无 fail/skip（不硬编码基线总数——770 为依赖假设中的参考值，见下）；`~/.claude/hooks/` 全局运行时副本同步为**发布清单人工步骤**，不计入 bats 用例（home 路径在 CI/新环境不可移植）
- **验证方式**: 仓库内 `md5sum` 一致性 + `npx bats test/` 无 fail/skip；全局副本同步列入发布清单

### AC-7 · 前轮审查文件缺失/为空的静默行为

- **Given** artifacts_dir 内不存在 `INDEPENDENT-REVIEW-<phase>.md`，或该文件存在但两类提取源皆空（首轮审查场景）
- **When** 构建 prompt
- **Then** prompt 不含发现摘要段，也不含「主 agent 未响应」标注（无前轮上下文时静默，不产生误导性标注）
- **验证方式**: bats 断言（fixture 无审查文件 / 空提取源两份，grep 反向断言）

---

## 范围切分

### v1（本次必做）

- AC-1 ~ AC-7 全部：l3-prompt.sh 文件簇修复 + bats 回归用例 + 仓库内四处副本同步（全局运行时副本为发布清单步骤）

### v2（下一轮考虑，不本次）

- 7 文件循环工件正文启用 smart_truncate（头+尾保留，已存在于其他路径的 `smart_truncate()` 复用）
- 前轮反馈注入量上限可经 env var 配置（当前固定 800B）

### out（永远不做）

- Claim 3（Gate 2 `jq empty` 对非 JSON `.flow-active` 的 fail-open 让位）——既定防御设计，33 号 hook 已承担信号职责
- L3 模型选择链 / API 调用层（l3-api.sh、fk_resolve_model 五级链）行为变更

---

## 非功能性需求

- **性能**: 前轮反馈注入总量 ≤ 800 字节（AC-4 断言），注入逻辑为纯文本提取（sed/awk 级），不引入子进程 API 调用
- **可访问性**: 无
- **安全**: 注入内容仅来自项目内 `.md` 文件，沿用 jq `--arg` / heredoc 现有转义路径，不新增命令拼接
- **兼容性**: `max_chars` 字节语义不变；`L3_MAX_ARTIFACT_CHARS` env 覆盖行为不变；`.done` 6 键 KVP 格式不变
- **健壮性**: 反馈注入与工件截断须落在 UTF-8 字符边界（截断点为多字节序列中间时回退到前一完整字符；注入段整体必须为合法 UTF-8——中文摘要截断产生非法字节序列会重新引入弱模型误读风险）
- **可观测性**: 无新增日志要求（维持现状）

## 依赖与假设

- l3-prompt.sh 当前结构已核查（本会话 2026-09-04，含 `.bak-20260824` 对照）
- dist 两份副本的再生方式（手改 cp vs 重跑 package-dsh-plugin.sh）在 DESIGN 阶段确认
- 假设 bats 基线 770 全绿（STATE.md 2026-09-03 记录；仅参考值，AC-6 断言为「无 fail/skip」非固定总数）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
