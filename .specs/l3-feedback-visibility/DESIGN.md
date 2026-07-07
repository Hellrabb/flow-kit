# DESIGN: L3 审查结果反馈可见性修复

- **Change ID**: `l3-feedback-visibility`
- **关联**: `@.specs/l3-feedback-visibility/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

CONTEXT.md 已锁定，无变更：

- **选定**：Bash（`set -euo pipefail`）— CLI/hook 脚本项目
- **运行时**：Claude Code hook 框架（PreToolUse + SessionStart + Stop）
- **关键依赖**：`jq`（JSON 处理）、`curl`（L3 API 调用）、`flow-kit-artifacts.sh`（共享 lib）、`done-validation.sh`（`.done` 真实性校验 lib）
- **测试框架**：bats-core 1.13.0（npx）
- **理由**：本 change 仅修改现有 hook 脚本，不引入新语言/框架/依赖
- **明确排除**：无需引入新工具或语言

---

## 0.5 既有架构对齐（brownfield · 来自 2-design 步骤 0.5）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/ls 确认的实际清单）：
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（342 行，L3 API 调用共享 lib）
  · l3_review_run() — L3 API 调用 + verdict 提取 + .done 写入（key=value 格式）
  · l3_review_with_timeout() — 30s 超时包装
  · l3_write_timeout_done() — 超时降级 .done 写入
  · .done 格式：cat > "$done_tmp" <<DONE_EOF ... key=value ... DONE_EOF（l3-review.sh:250-257）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（270 行，PreToolUse 门禁入口）
  · 第 228 行：l3_review_with_timeout ... 2>/dev/null || true  ← 需移除 2>/dev/null
- flow-kit-bundle/hooks/session-start/flow-kit-resume.sh（258 行，SessionStart resume 逻辑）
  · 第 133-143 行：ir_state_file 握手文件检测逻辑  ← 需替换为 .done 检测
- flow-kit-bundle/hooks/stop/lib/done-validation.sh（181 行，.done 真实性校验）
  · _fk_done_kvp() — key=value 解析函数（grep -E "^${key}="）
  · 第 139 行：L3_verdict 值域 = ^(pass|fail|timeout|error|skipped)$

新增模块：
- 无（CHANGE.md 已明确"不新增 hook 模块"）
- 新增共享函数 _l3_format_result() 放在 l3-review.sh 中（与既有 L3 逻辑同文件，不新建模块）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/stop/29-independent-review.sh（L3 Stop hook 兜底，仅调用 l3-review.sh）
- flow-kit-bundle/hooks/stop/lib/correction-file.sh（矫正文件 lib，无关）
- flow-kit-bundle/lib/flow-kit-artifacts.sh（产物管理共享 lib，fk_* 函数）
- package-flow-kit.sh（打包脚本，禁动清单已有）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| L3 API 调用 | `l3-review.sh` → `l3_review_run()` / `l3_review_with_timeout()` | 沿用，不改 API 签名 |
| verdict 提取 | `l3-review.sh:201-222` 三层提取（代码块→纯JSON→grep） | 沿用模式，summary 用同模式并行提取 |
| `.done` 读取 | `done-validation.sh` → `_fk_done_kvp()` KVP 解析函数 | 沿用——`.done` 是 key=value 格式（非 JSON），用 `grep -E "^${key}="` 解析 |
| `.done` 写入 | `l3-review.sh:250-257` `cat > "$done_tmp" <<DONE_EOF ... DONE_EOF` | 沿用 KVP 格式，扩展增加 `L3_summary=<value>` 行 |
| gate 激活检测 | `independent-review-gate.sh:151` `fk_independent_review_gate_active()` | 沿用 |
| done 真实性校验 | `done-validation.sh` → `fk_validate_done_marker()` / `_fk_done_kvp()` | 沿用 |
| SessionStart banner | `flow-kit-resume.sh` 现有 `║` 框线 banner 风格 | 沿用 banner 结构，新增 L3_RESULT 行 |
| 超时降级 | `l3-review.sh:304-336` `l3_write_timeout_done()` | 沿用，扩展增加 `L3_summary` 行 |
| verdict 值域校验 | `done-validation.sh:139` `^(pass\|fail\|timeout\|error\|skipped)$` | 沿用——本次不扩展 waiver（L3 prompt 当前仅产出 pass/fail） |

### 0.5.3 沿用模式 vs 引入新模式

```
- L3 API 调用：**沿用** `l3_review_with_timeout` 超时包装（30s + 降级）
- verdict 提取：**沿用** 三层 fallback 提取模式（代码块 → 纯 JSON → grep 正则）
- summary 提取：**沿用** 三层 fallback 模式（与 verdict 提取并列，同结构）
- .done 文件读写：**沿用** key=value 格式 + `_fk_done_kvp()` 解析（grep -E），不引入 JSON 序列化
- 故障降级：**沿用** 既有值域 `error`（`done-validation.sh:139` 已接受）→ 新增第四层提取失败降级分支
- 输出路由：**引入新模式** → `L3_RESULT:` 统一格式行 + 共享格式化函数 `_l3_format_result()`
  （理由：当前无 agent 可见输出机制，需新建；两条路径共用同一函数避免格式漂移）
- resume 检测：**替换旧模式** → 从 `ir_state_file`（握手文件）改为 `.done` 存在性 + `INDEPENDENT-REVIEW-<N>.md` L3 段检测
  （理由：旧握手文件已被 29 号 hook 清理，新路径依赖 .done 直写机制）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | L3 反馈通过 hook stdout 输出 `L3_RESULT:` 格式行 | (a) 写入文件由 prompt 读取 (b) stderr 直出 (c) 环境变量注入 | (a) 需改 prompt 模板，耦合度高；(b) stderr 含内部日志噪声，安全风险；(c) Claude Code hook 不支持环境变量注入。stdout 是 hook 框架天然的输出通道 | stdout 是否被 agent 感知取决于 Claude Code hook 实现；若不可用需降级为方案(a)，在 4-dev 测试阶段验证 |
| D2 | SessionStart 路径从 `.done` 文件读取 L3 结果（替代旧 `ir_state_file` 握手文件） | (a) 保留握手文件双轨 (b) 仅读 INDEPENDENT-REVIEW md (c) 从 .done 读 | `.done` 是 key=value 格式（`l3-review.sh:250-257` 确认），通过既有 `_fk_done_kvp()` 函数（`grep -E "^${key}="`）可靠解析，比方案(b) 的 markdown 解析更稳定。不需引入 JSON/jq 依赖 | `.done` 不含 report 文件路径，需从已知命名规则推导（`INDEPENDENT-REVIEW-<N>.md`）；读取 `.done` 时需 `set +e` 容错（jq 解析失败会触发 `set -euo pipefail` 退出） |
| D3 | summary 提取采用与 verdict 相同的三层 fallback 模式 + 第四层故障降级 | (a) 仅 jq 提取 (b) 仅 grep 提取 (c) 三层 + 降级 | 与既有 verdict 提取保持一致，降低认知差异。三层覆盖：正常 JSON（代码块包裹）→ 裸 JSON → 畸形但可 grep 的文本。**第四层**：三层全失败 → `verdict=error` + `summary=L3 结果解析失败`（利用 `done-validation.sh:139` 已接受的 `error` 值域） | 代码重复（verdict 和 summary 提取逻辑高度相似），但 342 行 lib 中 ~30 行重复可接受；抽取公共函数为过度工程。v2 若增加 ≥2 个新字段再重构为 `l3_extract_field()` 通用函数 |
| D4 | 统一格式行 `L3_RESULT: verdict=<v> summary=<s> report=<p>`，verdict 值统一小写 | (a) JSON 格式 (b) 多行输出 (c) 大写 verdict | JSON 需 agent 解析才能阅读，违背"一眼可见"目标；多行占据过多 token。单行固定格式可 grep 自动化验证，人工也可一眼扫读。**小写 verdict** 与既有代码库全链路一致（`l3-review.sh:215,220,255,336` + `done-validation.sh:139` 均为小写） | 字段值中若含空格需约定：report 路径不含空格；summary 为最后一个自由文本字段。若 summary 含字面量 ` report=` 将导致字段边界歧义（概率极低——L3 summary 为中文总评），v2 可考虑 ` \| ` 分隔符或 base64 编码 |
| D5 | 安全过滤：仅输出 verdict + summary + report 相对路径 | 不过滤，依赖 l3-review.sh 自身不输出敏感信息 | 防御性设计：L3 API 响应原文可能含 token/内部路径/模型内部思考。安全 NFR 已约束三个字段白名单 | 若 L3 API 返回的 summary 自身含敏感信息（模型照抄了工件中的路径），无法在 Bash 层过滤——但这是 L3 prompt 设计问题，非本 change 范围 |
| D6 | 共享格式化函数 `_l3_format_result()` 放在 `l3-review.sh` 中 | (a) 新建独立 helper 文件 (b) 两处各自内联 echo | (a) 新建文件违反"不新增模块"约束，且仅 3 行函数不值得独立文件；(b) 两处内联违反 AC-3 的"同一格式化函数"验证要求。放在 l3-review.sh 中：F1（independent-review-gate.sh）已 source l3-review.sh；F2（flow-kit-resume.sh）在需要时 source l3-review.sh 即可复用 | flow-kit-resume.sh 当前不 source l3-review.sh，需加一行 `source` 引入（~20ms 开销，可接受） |

---

## 2. 数据流 / 架构图

### F1 · PreToolUse 路径（transition 时同步执行）

```
agent 执行 transition jq
         │
         v
PreToolUse hook: independent-review-gate.sh
         │
         ├── gate_config["<phase>"] ∈ {both, L3-only}?
         │      │
         │      └── YES
         │           │
         │           v
         │     source l3-review.sh  # 获取 l3_review_with_timeout + _l3_format_result
         │     l3_review_with_timeout(phase, change_id, spec_dir, l2_verdict, 30)
         │           │                              ┌─ 移除 2>/dev/null
         │           v                              v
         │     l3_review_run() ──curl──> L3 API ──> 响应 JSON
         │           │
         │           ├── 三层提取 verdict  ──> L3_verdict (pass|fail)
         │           ├── 三层提取 summary  ──> L3_summary           ← F3 新增
         │           ├── 第四层故障降级: 三层全失败 → verdict=error ← F3 新增
         │           ├── l3_write_done_marker() → .done (key=value 格式):
         │           │     L2_verdict=pass|fail
         │           │     L3_verdict=pass|fail|timeout|error
         │           │     L3_summary=一句话总评                       ← F3 新增
         │           │
         │           v
         │     _l3_format_result "$l3_verdict" "$l3_summary" \
         │       ".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
         │           │
         │           └── stdout → agent 下一轮对话可见
         │
         └── fk_validate_done_marker() → transition 放行/拦截
```

### F2 · SessionStart 路径（新 session resume）

```
session 启动
    │
    v
SessionStart hook: flow-kit-resume.sh
    │
    ├── change_id=$(jq -r '.change_id' .flow-active)
    ├── phase=$(jq -r '.goal.current_phase // .phase' .flow-active)
    │
    ├── 旧逻辑（已失效，本次替换）:
    │   ir_state_file=".flow-active.independent-review"
    │   [[ -f "$ir_state_file" ]] → NEVER TRUE (29号hook已清理)
    │
    └── 新逻辑（F2）:
        done_file=".specs/${change_id}/.independent-review-${phase}.done"
        review_md=".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
        │
        ├── [[ -f "$done_file" ]] && grep -q "## L3 外部模型审查" "$review_md"
        │      │
        │      └── YES
        │           │
        │           v
        │     source .../l3-review.sh  # 获取 _l3_format_result()
        │     source .../done-validation.sh  # 获取 _fk_done_kvp()
        │     set +e  # .done 解析容错
        │     l3_verdict=$(_fk_done_kvp "$done_file" "L3_verdict")
        │     l3_verdict="${l3_verdict:-unknown}"
        │     l3_summary=$(_fk_done_kvp "$done_file" "L3_summary")
        │     l3_summary="${l3_summary:-}"
        │     set -e
        │     report=".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
        │           │
        │           v
        │     _l3_format_result "$l3_verdict" "$l3_summary" "$report"
        │     → SessionStart banner 内嵌行（沿用现有 ║ 框线风格）
        │
        └── NO → 跳过，不产生 L3_RESULT 行
```

### F3 · Summary 提取 + 故障降级（l3-review.sh 内部改动）

```
L3 API 响应 content（JSON 文本，可能含 markdown 代码块包裹）
    │
    ├── 已有：三层提取 verdict
    │   1. 提取 JSON 代码块 → jq -r '.verdict'
    │   2. 裸 JSON → jq -r '.verdict'
    │   3. grep 正则 → grep -oP '"verdict"\s*:\s*"\K(pass|fail)(?=")'
    │   └──> l3_verdict
    │
    ├── 新增：三层提取 summary（同模式并列）
    │   1. 提取 JSON 代码块 → jq -r '.summary'
    │   2. 裸 JSON → jq -r '.summary'
    │   3. grep 正则 → grep -oP '"summary"\s*:\s*"\K[^"]+'
    │   └──> l3_summary（未提取到则默认 ""）
    │
    └── 新增：第四层故障降级（三层均失败后执行）
        if [ -z "$l3_verdict" ] || [ "$l3_verdict" = "unknown" ]; then
          l3_verdict="error"
          l3_summary="L3 结果解析失败（verdict 不可用）"
        fi
        └──> 利用 done-validation.sh:139 已接受的 error 值域

l3_write_done_marker() 扩展（key=value 格式，非 JSON）:
  cat > "$done_tmp" <<DONE_EOF
  phase=${phase}
  change_id=${change_id}
  written_by=${written_by}
  L2_verdict=${l2_verdict}
  L3_verdict=${l3_verdict}
  L3_summary=${l3_summary}           ← 新增行
  artifacts=${artifacts_list}
  DONE_EOF

l3_write_timeout_done() 同样扩展:
  ...
  L3_verdict=timeout
  L3_summary=L3 API 调用超时（30s）   ← 新增行
  ...
```

---

## 3. 关键状态机

本 change 不引入新状态机。两条路径的触发条件：

```
PreToolUse 路径:
  IDLE → [transition jq 被拦截] → CHECK_GATE
    → gate_config[phase] ∈ {both, L3-only}? ─NO→ SKIP_L3 → transition 放行
    → YES → RUN_L3 → [L3 API 返回] → EXTRACT(三层+第四层降级) → WRITE_DONE → EMIT_L3_RESULT → transition 放行
    → [超时 30s] → TIMEOUT_DONE → EMIT_L3_RESULT(verdict=timeout) → transition 放行

SessionStart 路径:
  IDLE → [session 启动] → CHECK_DONE
    → .done 存在 + review md 含 L3 段? ─NO→ SKIP_BANNER
    → YES → READ_DONE(_fk_done_kvp) → FORMAT(_l3_format_result) → BANNER_OUTPUT
```

verdict 值域（全链路统一小写）：

| 值 | 含义 | 产出方 |
|---|---|---|
| `pass` | L3 审查通过，无 critical | L3 API 正常返回 |
| `fail` | L3 审查不通过，有 critical | L3 API 正常返回 |
| `timeout` | L3 API 调用超时（30s） | `l3_write_timeout_done()` |
| `error` | L3 响应 JSON 无法解析 | 第四层故障降级 |
| `skipped` | L3 被跳过（如 gate_config=L2） | 上游调用方 |

---

## 4. ADR 索引

无可逆性低的决策需要独立 ADR。D1-D6 均为可逆的实现选择（输出格式可后续调整，检测逻辑可回退）。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | PreToolUse hook stdout 不被 agent 感知——Claude Code hook 框架可能只捕获 stderr 或完全隔离 stdout | F1 修复无效，L3 反馈在 PreToolUse 路径仍然静默 | 中 | 4-dev 阶段首 task 验证 stdout 可见性；若不可用，降级为方案(a)：写入临时文件 + prompt 模板注入读取指令 |
| R2 | SessionStart banner 格式变更破坏现有 resume UX——改动 banner 输出可能与其他 hook 模块的输出冲突或被覆盖 | resume 时 agent 看到格式混乱的 banner | 低 | 复用现有 banner 的 `║` 框线风格；`L3_RESULT:` 行放在独立 review 报告段（已有占位），不新增 banner section |
| R3 | summary 提取失败率高——L3 外部模型可能不返回 `summary` 字段（尤其弱模型不遵循 JSON 格式指令） | agent 只看到 verdict 无 summary，与 AC-1/AC-2 要求不完全匹配 | 中 | summary 提取失败时降级为空字符串（`summary=`），不阻塞流程；第四层故障降级覆盖 verdict 不可用场景 |
| R4 | `.done` KVP 格式被非本次修改的代码路径覆写——其他 hook 模块或手动操作可能写入不兼容的行 | `L3_summary` 行缺失导致 `_fk_done_kvp` 返回空 | 低 | `_fk_done_kvp` 对缺失 key 返回空字符串自然降级；`l3_summary="${l3_summary:-}"` 兜底；写入时用追加行方式不覆写已有 key |
| R5 | 改动引入回归——`l3-review.sh` 的 verdict 提取或 `.done` 写入逻辑被误改 | 现有 L3 功能（超时降级、done 真实性校验）失效 | 低 | 4-dev 完成后全量 bats 回归；F1/F2/F3 各对应独立 task，分步验证 |
| R6 | `_fk_done_kvp` 在 SessionStart 中 source 引入新依赖——`flow-kit-resume.sh` 当前不依赖 `done-validation.sh` | 若 `done-validation.sh` 路径变更，resume 逻辑失效 | 低 | 使用与 `independent-review-gate.sh` 相同的 source 路径解析方式（相对 hooks/ 目录）；在 4-dev 中加断言验证 source 成功 |

---

## 6. 不在范围

- L3 审查内容生成逻辑（prompt 构建、模型选择、checklist 内容）— out
- L3 API 超时/重试策略调整 — out
- `.done` 文件格式变更（保持 key=value，仅新增 `L3_summary` 行）— out
- 新 hook 模块 — out
- L3 反馈的结构化详情（具体 FAIL 条目）— v2
- L3 审查历史面板 — v2
- `L3_RESULT:` 行的国际化/多语言支持
- WAIVER 判决值——当前 L3 prompt 仅产出 pass/fail，WAIVER 留 v2（若 L3 prompt 增加了 waiver 输出再同步扩展提取逻辑 + 值域校验）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `l3-review.sh` → `_l3_format_result()` | 统一格式化 L3 反馈输出行 | F1(PreToolUse) + F2(SessionStart) 两条路径共用 | 若未来增加新 L3 反馈通道（如 PR comment），直接调用此函数 |
| `l3-review.sh` → 第四层故障降级分支 | 三层提取全失败时产出 `verdict=error`（利用 `done-validation.sh` 已接受的 error 值域） | L3 模型返回非标准格式时 | 若 v2 增加更多提取字段，也应遵循"N 层提取 + 1 层降级"模式 |
| `l3-review.sh` → verdict + summary 三层提取（并列结构） | 从 L3 API 响应 JSON 中可靠提取字段 | 未来若 L3 prompt 增加新字段（如 `risk_level`） | 建议下次重构（v2，非本次）——当需提取 ≥3 个字段时，抽取 `l3_extract_field()` 通用函数。本次（v1）保持 D3 的显式重复策略，仅 2 个字段不值得抽象 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| L3 反馈统一格式 | `L3_RESULT: verdict=<v> summary=<s> report=<p>`（全小写 verdict） | 所有依赖 L3 反馈的流程（PreToolUse + SessionStart） | 低——格式变更仅影响 grep 验证脚本和人工阅读习惯 |
| L3 反馈输出通道 | PreToolUse: hook stdout; SessionStart: banner 内嵌行 | L3 反馈可见性 | 中——若换通道需改两处代码 + 更新 AC |
| `.done` 序列化格式 | key=value（非 JSON）— 已确认且不变更 | `.done` 文件读写（l3-review.sh, done-validation.sh, independent-review-gate.sh, flow-kit-resume.sh） | 高——改 JSON 需同步更新 4+ 个文件 |

### 9.3 新增 / 修改的跨模块契约

```
- 新增 .done 文件键：L3_summary=<value>（key=value 格式行）
  - 写入方：l3_write_done_marker() / l3_write_timeout_done()（l3-review.sh）
  - 读取方：independent-review-gate.sh（F1）、flow-kit-resume.sh（F2）
  - 解析函数：_fk_done_kvp()（done-validation.sh）
- 新增 stdout 输出契约：
  - _l3_format_result() 格式化函数（l3-review.sh）
  - independent-review-gate.sh 在 L3 完成后调用 _l3_format_result 输出到 stdout
  - flow-kit-resume.sh 在 resume banner 中调用 _l3_format_result 输出 L3_RESULT 行
- flow-kit-resume.sh 新增 source 依赖：
  - source l3-review.sh（获取 _l3_format_result()）
  - source done-validation.sh（获取 _fk_done_kvp()）
```

### 9.4 新增 / 升级的依赖

无。本 change 不引入新依赖。

### 9.5 禁动清单变化

```
- 新增禁动：无
- 解禁：无
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
