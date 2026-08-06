# DESIGN: L3 审查管线 + Stop Hook 性能修复

- **Change ID**: `l3-pipeline-fix-2026-07`
- **关联**: `@.specs/l3-pipeline-fix-2026-07/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目为 Bash 脚本项目（flow-kit 分发包仓库），属纯 CLI/lib 项目，跳过技术栈选型。

- **语言/运行时**: Bash 4.0+（`set -euo pipefail`）— 沿用现有
- **测试**: bats-core 1.13.0（`npx bats`）— 沿用现有
- **静态分析**: shellcheck（error 级别，`-e SC1091`）— 沿用现有
- **外部 API**: curl + `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` — 沿用现有
- **理由**: 本次是管线修复 + 性能优化，不更换运行时和工具链

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

> 以下路径基于实际 `grep` / `wc -l` 验证（证据链 L3）。

```
触碰模块（证据来自实际代码扫描）：
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（625 行 · L3 管线核心 · 主要修改目标）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（153 行 · L3 派发 + 积压扫描添加处）
- flow-kit-bundle/hooks/stop/lib/common.sh（263 行 · 可能的共享函数：耗时统计、token 估算）
- flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh（109 行 · 自引用竞态修复 · 已修）

会新增：
- 无新文件模块；将在 common.sh + l3-review.sh + 29-independent-review.sh 中新增函数（核心逻辑）
- D5 测量阶段将在最多 14 个 hook 模块入口/出口插入 `fk_perf_timing_start()` / `fk_perf_timing_end()` 探针调用（各 2 行，轻量修改）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/stop/lib/l2-detect.sh（L2 检测，与 L3 无关）
- flow-kit-bundle/hooks/stop/lib/correction-file.sh（矫正文件管理，与 L3 无关）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（gate 核心链 · 禁动清单保护 · **不触碰**）
- package-flow-kit.sh（打包脚本 · 禁动清单保护）

> ⚠️ 禁动清单异常声明：CONTEXT.md 禁动清单（行 383）将 `29-independent-review.sh` 列为 gate 校验核心链。
> 本次修改理由：积压扫描（D3）必须注入 29 号 hook 入口——这是 L3 补跑的唯一调度点。
> 触碰范围限定：仅在 `fk_independent_review_run()` 入口添加 `_l3_scan_backlog()` 调用 + 新增同文件内的 `_l3_scan_backlog()` 函数定义，不修改 L3 派发核心逻辑。
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| L3 API 调用 | `l3-review.sh::l3_review_run()` | **沿用** — 不新增调用路径 |
| L3 结果格式化 | `l3-review.sh::_l3_format_result()` | **沿用** — 不改变 `L3_RESULT:` 输出格式 |
| .done 写入 | `l3_review_run()` 内部 jq | **沿用** — 不绕过 `l3_review_run()` 封装 |
| phase 解析 | `common.sh::fk_resolve_phase()` | **沿用** — 禁动清单禁止直接 `jq -r '.phase'` |
| checkpoint 写入 | `checkpoint-lib.sh::checkpoint_write()` | **沿用** — 禁动清单禁止直接 jq write |
| diff 收集 | `l3-review.sh` phase 6 case | **修改** — 策略调整（见 D1） |
| 产物截断 | `l3-review.sh::smart_truncate()` | **修改** — 增强算法（见 D2） |
| token 估算 | 无 | **新建** — 轻量函数 `fk_estimate_tokens()`（见 D1） |
| 积压扫描 | 无 | **新建** — `_l3_scan_backlog()` 在 29 号 hook 中（见 D3） |
| 上下文注入 | 无 | **新建** — `_l3_inject_context()`（见 D4） |
| 耗时统计 | 无 | **新建** — `_perf_timing()` 在 common.sh 中（见 D5） |

### 0.5.3 沿用模式 vs 引入新模式

```
- L3 API 调用：**沿用** l3_review_run() 封装（禁动清单：禁止绕过直调 curl）
- .done 写入：**沿用** l3_review_run() 内部写入（禁动清单：仅 l3_review_run 有写权限）
- diff 收集：**修改** git diff HEAD → git diff --cached HEAD（策略调整，非新模式）
- smart_truncate：**增强** 既有算法（加 tail 保留 + token 感知，非新模式）
- 积压扫描：**引入新函数**（在既有 29 号 hook 内） → 理由：既有模块无此能力，新函数不破坏既有调度
- 上下文注入：**引入新函数**（在既有 l3-review.sh 内） → 理由：L3 prompt 构建无上下文能力
- 性能统计：**引入新函数**（在 common.sh 内） → 理由：全 hook 链共用的轻量基础设施
```

---

## 1. 决策清单

### D1 · git diff 策略：`--cached` + 动态上限

- **当前状态**（证据：`l3-review.sh:201-206`）：
  - Line 201: `git diff HEAD` — 含工作区 vs HEAD 的差异（含已 staged 且未再编辑的文件），**不含仅 index 中存在但工作区未体现的变更**（如 `git add` 后又被 `git reset` 的文件在 index 中残留）
  - Line 202-204: `git ls-files --others` 列出新文件，但内容用 `head -c 5000` 硬截断
  - Line 206: 整体 diff 再用 `head -c "$max_chars"` 硬截断
- **决策**: 
  1. **同时使用** `git diff HEAD`（工作区 vs HEAD）**和** `git diff --cached`（index vs HEAD），取并集（对重叠文件去重，按文件路径合并）。理由：仅用 `--cached` 会丢失 agent `git add` 后又编辑但未再 stage 的变更；仅用 `HEAD` 会丢失仅 index 独有的变更块
  2. 新文件内容截断从硬编码 `5000` → `max_chars / 4`（动态而非固定值）
  3. 整体 diff 截断从 `head -c` 字符截断 → `fk_estimate_tokens()` token 估算截断（字符数 / 4 ≈ token 数，上限 = context_window × 60%）
- **备选**: 纯 `git diff HEAD`（不做改动）/ 改用 `git diff --cached HEAD`（L2 审查指出会丢失 unstaged 变更）/ 用 `git show :0:<file>` 读 staged 版本
- **选择理由**: 并集策略是唯一覆盖全量变更的方式；token 估算用字符/4 近似（中英混合环境误差 < 15%），比硬编码字符上限更灵活
- **取舍代价**: 并集策略增加一次 git 调用（`git diff --cached`），延迟 ~50ms；`fk_estimate_tokens()` 是近似值非精确 token count（精确需调 API tokenizer，增加复杂度）；context_window 从配置读取（默认 100000）

### D2 · smart_truncate 增强：头+尾保留 + token 感知

- **当前状态**（证据：`l3-review.sh:44-144`）：
  - 已是两遍扫描算法：收集 `##`/`###` 标题 + `**Given**/**When**/**Then**` AC 行 → 按标题段填充至 `max_chars` 上限
  - **非** CHANGE.md 假设的纯 `head -c` 硬截断
  - 但尾部（风险段/决策段/ADR 段）可能因不匹配 header/AC 模式而被丢弃
- **决策**:
  1. 在填充逻辑中增加"尾部锚点"：识别 `## 5. 风险` / `## 风险` / `ADR-` / `已锁决策` 等尾部关键段 header
  2. 第三遍扫描：从文件末尾向前扫描，收集尾部关键段 → 确保留存
  3. 上限参数从 `max_chars` → `max_tokens`（token 估算值），内部转换回字符数
- **备选**: 保持现有算法不变（已比纯 head -c 好）/ 按比例截断（前 N/2 + 后 N/2）
- **选择理由**: 现有两遍扫描基础好，只需加第三遍（尾部锚点）；token 感知使上限与模型上下文窗口对齐
- **取舍代价**: 三遍扫描增加 ~0.1s 处理时间（text < 50K chars 可忽略）；尾部锚点关键词需维护但新增频率低；**fallback**：若尾部扫描未匹配到任何锚点 → 回退到保留文件最后 `max_chars / 4` 字符（通用尾部保留策略），并在截断元信息中标注 `[尾部保留: 0 段锚点匹配，已回退到通用保留]`

### D3 · 积压扫描器：`_l3_scan_backlog()`

- **决策**: 在 `29-independent-review.sh` 的 `fk_independent_review_run()` 入口加积压扫描
- **算法**:
  1. 读 `goal.phases_done[]` + `goal.gate_config`
  2. 对每个 `phases_done` 中的 phase N，查 gate_config 是否含 L3 或 both
  3. 检查 `.specs/<id>/.independent-review-{N}.done` 是否存在
  4. 缺失 → 加入补跑队列（按 phase 编号升序）
  5. **限流**：取队列前 3 个 phase 执行 `l3_review_run()`；超出部分记录到 hook 日志并推迟到下次 Stop hook
- **边界**: 只扫描 phase 1/2/3/5/6/7（与 gate_config 合法 key 一致）；回退方向不触发；已标记 skipped 的 phase 不重复跑；每次 Stop hook 最多触发 3 次 L3 API 调用（避免 hook 链超时）
- **备选**: 在 PreToolUse hook 做（transition 时同步补跑）/ 在 SessionStart 做（会话启动时补跑）
- **选择理由**: Stop hook 在每轮结束执行，是 L3 的自然调度点；异步不阻塞 transition；积压扫描是补充逻辑，不应阻塞正常 flow
- **取舍代价**: Stop hook 链增加积压扫描耗时（O(N) 文件存在性检查，< 100ms）；若积压量大（如 5 个 phase 全需补跑），单次 Stop hook 可能触发多次 L3 API 调用（每次 30s timeout）

### D4 · L3 上下文注入：`_l3_inject_context()`

- **决策**: 在 `_l3_build_prompt()` 的 prompt 构建阶段注入前次审查上下文
- **实现**:
  1. 检查 `INDEPENDENT-REVIEW-{phase}.md` 是否存在
  2. 若存在 → 提取 L2/L3 段：`grep -A5 'Verdict: pass\|Verdict: fail'` + 提取 `## 主 agent 反驳` 段（若有）
  3. 将摘要作为 prompt preamble 注入（在 system prompt 和审查内容之间）
- **格式**:
  ```
  [前次审查上下文]
  - L2 Verdict: pass（3 🟡 Major · 3 🟢 Minor）
  - L3 Verdict: fail（1 🔴 Critical: AC-1 上下文窗口未定义）
  - 主 agent 响应: AC-1 策略已选定（动态 token 估算），context_window 默认 100000
  ```
- **备选**: 仅在 L3 API 请求 body 中加 `previous_review` 字段 / 不做上下文注入，靠 L3 模型自身推理
- **选择理由**: 上下文注入消除假阳性反复出现的问题（L-040 限制⑤）；preamble 格式让外部模型在审查前了解历史，减少重复发现
- **取舍代价**: prompt 长度增加 ~200-500 chars（取决于前次审查复杂度）；旧审查的过时信息可能干扰新判断（缓解：仅注入最近一次审查）；**与 ADR-005 的张力**：ADR-005 定义 L3 为"跨模型独立视角"，D4 引入上下文感知——这是针对 L-040 限制⑤（假阳性反复出现）的工程权衡，非改变 ADR-005 架构意图。注入的 preamble 含免责声明：`[注意：以上为历史审查上下文，本次审查仍应基于工件本身独立判断]`

### D5 · Stop hook 性能优化：测量→定位→优化 三阶段

- **决策**:
  1. **Phase 1: 测量基线** — 在 `common.sh` 中添加 `fk_perf_timing_start()` / `fk_perf_timing_end()` 函数，用 `$SECONDS` 做轻量耗时统计；在各模块入口/出口插入调用
  2. **Phase 2: 定位瓶颈** — 收集一次 Stop hook 全链耗时分布，排序定位 Top 3 瓶颈
  3. **Phase 3: 优化** — 根据瓶颈类型选择策略：
     - L3 API 30s 同步等待 → 改 `l3_review_run()` 支持 `--background` flag（fire-and-forget），SessionStart 收割结果
     - lib source 串行化 → 识别可并行 source 的 lib，用 `&` + `wait` 并行加载
     - 14 模块串行化 → 独立的检查模块（如 `27-interactive-ui-check` / `28-weak-model-compliance` / `33-flow-active-integrity`）可后台并行跑
- **备选**: 不做测量直接猜测优化（风险：优化错误目标）/ 全量异步化（风险：复杂度爆炸，影响面大）
- **选择理由**: 测量驱动的优化保证收益；三阶段降低风险（每阶段可独立验证）；先测量再行动符合"不猜"原则
- **取舍代价**: 测量代码增加 ~30 行/common.sh + 14 处模块入口调用；优化阶段 3 的改动量取决于瓶颈类型，当前无法承诺具体行数

### D6 · L3 API 降级行为形式化

- **当前状态**（证据：`l3-review.sh` 已有 `timeout 30s` + `verdict=timeout` 降级）:
  - curl 超时 (`--max-time 30`) → `verdict=timeout`
  - 但 HTTP 4xx/5xx 错误码处理未显式定义
- **决策**:
  1. 修改 `_l3_call_api()` 的 curl 调用：添加 `-w '\n%{http_code}'` 输出 HTTP 状态码；接口约定改为 `<response_body>\n<http_code>`（`_l3_parse_result()` 用 `tail -1` 取状态码，其余行作为 body）
  2. 扩展 `_l3_parse_result()` 的 HTTP 状态码处理：200 → 正常解析；4xx → `verdict=error` + 记录 HTTP 状态码；5xx → `verdict=error` + 记录 HTTP 状态码
  3. `verdict=error` 行为同 `verdict=timeout`：不写 `.done`，不阻塞 pipeline，在 INDEPENDENT-REVIEW-{N}.md 记录失败原因
- **备选**: 对 5xx 做重试（最多 2 次，指数退避）/ 失败时回退到 prompt 指令（让主 agent 自己审查）
- **选择理由**: 最小改动扩展现有降级逻辑；不引入重试（增加延迟 + 复杂度）；保持 fail-open（不阻塞 pipeline）
- **取舍代价**: 无重试意味着临时网络故障也可能跳过 L3（缓解：下次 Stop hook 会补跑——积压扫描 D3 恰好覆盖此场景）；curl timeout 90s（`_l3_call_api` 内部）与 `l3_review_with_timeout` wrapper 的 30s 关系：wrapper timeout 先触发，但若直接调用 `l3_review_run()` 则 90s 生效

---

## 2. 数据流 / 架构图

### 2.1 修复前 vs 修复后 L3 管线

```
修复前:
  Stop hook 29-independent-review.sh
  │
  ├─ fk_resolve_phase() → current_phase
  ├─ 仅审 current_phase
  ├─ _l3_build_prompt(phase, artifacts_dir, max_chars=20000)
  │   ├─ git diff HEAD            ← 不含 staged
  │   ├─ git ls-files --others    ← 新文件内容 head -c 5000 截断
  │   ├─ head -c "$max_chars"     ← 整体 diff 字符截断
  │   └─ smart_truncate(artifacts) ← AC+header 保留，尾部可能丢弃
  └─ l3_review_run() → curl → L3 API → parse → write .done

修复后:
  Stop hook 29-independent-review.sh
  │
  ├─ _l3_scan_backlog()                    ← 新增：积压扫描
  │   ├─ 读 phases_done[] + gate_config
  │   ├─ 逐 phase 检查 .independent-review-{N}.done
  │   └─ 缺失 → l3_review_run(phase=N)
  │
  ├─ fk_resolve_phase() → current_phase
  ├─ _l3_build_prompt(phase, artifacts_dir, max_tokens=60000)
  │   ├─ _l3_inject_context(phase)         ← 新增：上下文注入
  │   ├─ git diff --cached HEAD            ← 修复：含 staged
  │   ├─ git ls-files --others            ← 保留：新文件
  │   │   └─ head -c max_chars/4           ← 修复：动态上限（非固定 5000）
  │   ├─ _estimate_tokens()               ← 新增：token 估算截断
  │   └─ smart_truncate(artifacts)         ← 增强：+尾部锚点
  └─ l3_review_run() → curl → L3 API → parse
      ├─ HTTP 200 → verdict = pass/fail
      ├─ HTTP 4xx/5xx → verdict = error   ← 形式化
      └─ timeout → verdict = timeout       ← 已有
```

### 2.2 性能优化三阶段流程

```
Phase 1: 测量
  _perf_timing_start("00-gate")
  ... gate 逻辑 ...
  _perf_timing_end("00-gate")

  每个模块重复 → 收集全链耗时分布 → Top 3 瓶颈

Phase 2: 定位
  瓶颈确认后选优化策略:
  - L3 API 30s → async fire-and-forget
  - lib source 串行 → 并行加载
  - 独立检查模块 → 后台并行跑

Phase 3: 优化实施 → 复测 → 验证 ≥ 30% 降幅
```

---

## 4. ADR 索引

本次 change 不引入新的不可逆架构决策。所有改动都在既有 ADR-003（Hook 系统架构）、ADR-005（独立审查体系）框架内，属于**管线修复 + 性能优化**，不 supersede 任何现有 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | `git diff --cached HEAD` + token 估算截断可能丢弃关键变更 | L3 审查质量下降（假阴性） | 中 | `fk_estimate_tokens()` 设保守上限（context_window × 60%）；`smart_truncate()` 尾部锚点保留关键段（风险/ADR）作为兜底 |
| R2 | 积压扫描触发多轮 L3 API 调用，Stop hook 链超时 | 单轮 Stop hook 延迟显著增加（N × 30s） | 中 | 补跑队列限制 ≤ 3 个 phase/次；超过则推迟到下次 Stop hook；积压扫描结果在 hook 日志中可见 |
| R3 | `_l3_inject_context()` 注入的旧审查信息干扰新判断 | L3 审查被过时上下文误导 | 低 | 仅注入最近一次审查；preamble 标注时间戳和审查编号；context 段与审查内容用 `---` 分隔 |
| R4 | 性能优化改变 L3 API 调用时序（async），pipeline transition 时 L3 结果尚未返回 | transition 死锁（L3 verdict 缺失）| 中 | async 模式仅在 Stop hook 兜底路径启用；PreToolUse transition 主路径保持同步；SessionStart 收割 async 结果后写 .done |
| R5 | 既有 `smart_truncate()` 的"标题段填充"逻辑与新增的"尾部锚点"可能产生重叠/冲突 | 截断结果重复或顺序错乱 | 低 | 尾部锚点扫描放在前两遍之后；尾部段去重（已在前两遍包含的 header 不重复追加）；bats 测试覆盖重叠场景 |

---

## 6. 不在范围

- L3 API 异步化作为 v1 默认行为（仅作为 Stop hook 兜底的优化选项，v2 全面启用）
- lib 懒加载/按需 source（v2，需改造整个 Stop hook 加载框架）
- `l3_review_run()` 307 行主函数拆分（TD-008，独立 change）
- 引入 L3 API tokenizer 精确计数（成本高，字符/4 近似足够）
- Stop hook 模块并行化框架（v2，需要各模块声明依赖关系）
- 分模块耗时持续监控面板（v2，需要存储 + 可视化）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `hooks/stop/lib/common.sh::_estimate_tokens()` | 轻量 token 估算（字符数 / 4） | 任何需要估算 prompt token 数的 hook/lib | 统一 token 估算入口，避免各处硬编码字符上限 |
| `hooks/stop/lib/common.sh::_perf_timing_start()` / `fk_perf_timing_end()` | 轻量耗时统计（基于 `$SECONDS`） | 任何需要性能测量的 hook 模块 | 用 `declare -A _PERF_TIMINGS` 全局存储，hook 链末尾统一输出 |

### 9.2 新增/改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| L3 diff 收集策略 | `git diff --cached HEAD` + token 估算截断 | 所有 L3 phase 6 审查的 diff 完整性 | 低（改回 `git diff HEAD` 仅需一处修改） |
| L3 上下文注入 | 前次审查 verdict + 反驳摘要注入 prompt | 所有 L3 审查的上下文质量 | 低（移除注入段即可回退到独立审查） |

### 9.3 新增/修改的跨模块契约

```
- l3-review.sh::smart_truncate() 签名不变，行为增强（+尾部锚点保留）
- l3-review.sh::_l3_build_prompt() 新增可选调用 _l3_inject_context()
- 29-independent-review.sh 入口新增 _l3_scan_backlog() 调用
- common.sh 新增 _estimate_tokens() / _perf_timing_start() / _perf_timing_end()
```

### 9.4 新增/升级的依赖

无。不引入新的外部依赖。

### 9.5 禁动清单变化

```
- 新增禁动：l3-review.sh::l3_review_run() 的 L3 API curl 调用 —— 禁止绕过 _estimate_tokens() 直接传 diff
- 新增禁动：29-independent-review.sh 入口 —— 禁止在 _l3_scan_backlog() 之前 return（必须跑积压扫描）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
