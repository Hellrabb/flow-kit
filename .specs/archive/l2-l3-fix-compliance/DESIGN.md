# DESIGN: L2/L3 review 发现强制代码修复

- **Change ID**: l2-l3-fix-compliance
- **关联**: `@.specs/l2-l3-fix-compliance/REQUIREMENT.md`、`@.specs/l2-l3-fix-compliance/CHANGE.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 已锁定（CONTEXT.md）。本 change 为 flow-kit 自身改进，技术栈无变化。

- **语言/运行时**: Bash（`#!/bin/bash`，`set -euo pipefail`）
- **工具链**: jq（JSON 处理）、git（diff 检测）
- **测试**: bats-core 1.13.0（`npx bats`）
- **部署**: 与 flow-kit 主分发流程一致（`package-flow-kit.sh` 打包）
- **关键依赖**: 无新增外部依赖——所有检测逻辑用 git + jq 实现
- **明确排除**: 不引入 Python/Node.js 等额外运行时；不做语义级 diff 分析（那是 v2）

---

## 0.5 既有架构对齐（brownfield）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（实际 grep/ls 确认）：
- flow-kit-bundle/flow-kit/prompts/5-test.md（既有 · 追加修代码优先协议段）
- flow-kit-bundle/flow-kit/prompts/6-review.md（既有 · 追加修代码优先协议段）
- flow-kit-bundle/flow-kit/prompts/7-integration.md（既有 · 追加修代码优先协议段）
- flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md（既有 · 追加各阶段 checklist 项）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（既有 · 扩展实效性校验）
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（既有 · 可复用函数签名，不改内容）

新增模块：
- flow-kit-bundle/hooks/stop/lib/fix-compliance.sh（新 · 实效性校验 helper 函数）
- flow-kit-bundle/test/test_l2_l3_fix_compliance.bats（新 · 测试文件）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/package-flow-kit.sh（打包脚本，与 review 行为无关）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（L3 兜底 hook — 不在此 change 范围）
- flow-kit-bundle/hooks/stop/32-fallback-guard.sh（auto_advance 兜底 — 无关）
- .specs/CONTEXT.md 禁动清单本身（不属于本 change 修改范围）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| .done 真实性校验 | `fk_validate_done_marker()` in flow-kit-artifacts.sh | 沿用（不修改） |
| gate_config 篡改检测 | `fk_check_gate_config_tamper()` in independent-review-gate.sh | 沿用（不修改） |
| L3 API 调用 | `l3_review_run()` in l3-review.sh | 沿用（不修改函数签名） |
| phase→name 映射 | case 1/2/3/5/6/7 in independent-review-gate.sh | 沿用现有映射 |
| transition 拦截点 | `is_phase_write()` → forward direction 分支 | **在此处插入实效性校验** |
| 测试框架 | bats-core 1.13.0 + test/ 目录 | 沿用，新增 test_l2_l3_fix_compliance.bats |
| 文件扩展名分类 | 没有 | 新建（理由：第一次有此需求）|

### 0.5.3 沿用模式 vs 引入新模式

```
- hook 检测逻辑：**沿用** fail-close 策略（与 gate-integrity 一致）
- lib 抽取：**沿用** hooks/stop/lib/ 下独立 .sh 文件的组织模式
- Prompt 协议：**沿用** 现有"独立 review 调度"段的结构（追加子段，不改动现有格式）
- 文件分类：**引入新模式** → 理由：既无文件扩展名分类抽象。用 env var + fallback 的配置模式（与 l3-review.sh 的模型选择一致）
- .done 格式：**沿用** 6 键 KVP 格式，不新增字段（实效性校验结果不写入 .done，而是作为 gate 拦截条件）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **实效性校验插入点**：在 `independent-review-gate.sh`（PreToolUse hook）的 `is_phase_write` → forward direction 分支中，L3 完成后、exit 0 前插入 | ① 新增独立 Stop hook 模块（33-fix-compliance.sh）② 单独的 PreToolUse matcher ③ 在 Stop hook 中事后检测（session 结束后） | 选现有 PreToolUse 拦截点（`independent-review-gate.sh`）：复用现有 transition 拦截逻辑，无需新增 hook 模块或 matcher 配置；在 L3 写入 .done 后、gate exit 0 前执行，时序正确。备选①增加模块注册和 matcher 维护成本；备选③是事后检测，无法在 transition 时阻断 | 实效性校验仅对 phase 5/6/7 触发，与 1/2/3 的 gate 逻辑在同一文件内分叉——增加 `independent-review-gate.sh` 复杂度 ~60 行 |
| D2 | **文件扩展名分类**：硬编码源码扩展名白名单 + 环境变量 `L3_FIX_SOURCE_EXTS` 覆盖 | ① git attributes 文件 ② 全量文件扩展名统计自动判定 ③ 黑名单模式（排除 .md 即放行） | 选硬编码白名单：简单可控，与 flow-kit 的 Bash-only 技术栈一致。env var 覆盖支持非标项目。备选①增加配置复杂度；备选②不可靠（统计偏差）；备选③太宽泛（.json/.yaml 也可能是配置） | 白名单需维护（新增语言时更新），但 flow-kit 自身只涉及 .sh/.bats，影响极小 |
| D3 | **默认源码扩展名白名单**: `.sh`, `.bats`, `.js`, `.ts`, `.jsx`, `.tsx`, `.py`, `.go`, `.rs`, `.c`, `.h`, `.cpp`, `.hpp`, `.java`, `.rb`, `.php`, `.swift`, `.kt`, `.scala`, `.r`, `.sql`, `.graphql` | 更窄白名单（仅 .sh/.bats）| 适中覆盖主流语言——避免过于宽松（放过非源码格式），也避免过于狭窄（漏检）。用户可通过 env var 定制 | 对纯 .json/.yaml 配置项目可能误判，但这类项目通常不会开 5/6/7 gate |
| D4 | **逐发现文件校验**：从 INDEPENDENT-REVIEW-<N>.md 解析 `Fixed in: <filepath>` 声明，对每项检查文件是否在 git diff 中 | ① 不做逐发现校验（仅检测纯文档 diff）② 语义级 diff（检查修改行是否匹配发现描述）③ diff hunk 级校验 | 选①：AC-2b 要求文件级校验，本方案正好满足——轻量（grep + diff 文件列表比对）、不涉及语义分析。备选②是 v2 范围；备选③实现复杂度远高于收益 | 无法检测"改了文件但改了无关内容"的情况——但那是语义级问题，v2 再解决 |
| D5 | **Prompt 协议格式**：在 5/6/7 prompt 的"独立 review 调度"段后插入"修代码优先协议"子段，要求 agent 对每条发现输出分类标记 | ① 单独新建 reference 片段（@see 引用）② 在各 prompt 中直接写不用统一格式 ③ 使用 YAML frontmatter | 选②：直接在每个 prompt 中写（5/6/7 + L2-blind-review.md），保持各阶段自主性。备选①增加 reference 复杂度且 TD-004 已标记共享段重复问题；备选③引入新格式增加解析复杂度 | 四份文件内容有重复（~15 行/份），但总量小（60 行），不算显著技术债 |
| D6 | **Phase 1/2 不触发**：实效性校验硬编码仅对 phase 5/6/7 执行；phase 1/2 的 transition 走现有逻辑 | ① 所有阶段统一触发 ② 通过 stop-hook.json 配置触发阶段 | 选硬编码：1/2 阶段产物本就是文档（REQUIREMENT.md / DESIGN.md），"纯文档 diff"在这些阶段是正常的，强制源码变更不合理。备选①造成假阳性；备选②增加配置复杂度——当前 stop-hook.json 的 `independent_review.phases` 已够用 | 阶段白名单硬编码在 hook 脚本中，变更需改代码——但阶段编号体系稳定，风险低 |
| D7 | **fail-closed 容错**：实效性校验中任何错误（git diff 失败、jq 解析失败、文件不存在）→ 阻断 transition | fail-open（出错放行） | 选 fail-closed：与 gate-integrity 的 fail-close 策略一致，宁可误阻断不漏过。弱模型可能利用"制造 hook 错误"绕过检测 | 极端情况（git 仓库损坏）会误阻断——输出明确错误信息 + 提示管理员可临时 `/flow gate-config <phase>=off` 放行 |

---

## 2. 数据流 / 架构图

```
Phase 5/6/7 Transition 被拦截 (is_phase_write + forward direction)
         │
         v
  ┌─ 现有 gate-integrity 校验 ──────────────────┐
  │ 1. fk_validate_done_marker() — 真实性校验    │
  │ 2. fk_check_gate_config_tamper() — 篡改检测  │
  │ 3. L3 前置（l3_review_with_timeout）          │
  └──────────────────────────────────────────────┘
         │ .done 有效
         v
  ┌─ 新增实效性校验（仅 phase 5/6/7）────────────┐
  │                                               │
  │  ① 读取 INDEPENDENT-REVIEW-<N>.md            │
  │  ② 统计源码级发现数量（AC-2a 判定规则）        │
  │     ├─ 0 条源码级发现 → 放行                  │
  │     └─ ≥1 条 → 继续                           │
  │                                               │
  │  ③ git diff 获取变更文件列表                   │
  │  ④ 文件分类（AC-2 纯文档检测）                 │
  │     ├─ diff 含源码文件 → 继续                  │
  │     └─ diff 仅 .md → ⛔ 阻断 "纯文档响应"      │
  │                                               │
  │  ⑤ 逐发现文件校验（AC-2b）                    │
  │     解析 "Fixed in: <file>" 声明              │
  │     ├─ 所有声明的文件在 diff 中 → 放行         │
  │     ├─ < 50% 未通过 → 告警但放行               │
  │     └─ ≥ 50% 未通过 → ⛔ 阻断 "修复声明未验证" │
  │                                               │
  │  ⑥ 输出 L3_RESULT 到 stderr（agent 可见）     │
  └───────────────────────────────────────────────┘
         │ 放行
         v
     exit 0（transition 允许）
```

**Prompt 层数据流**（5/6/7 阶段内）：

```
  L2/L3 INDEPENDENT-REVIEW-<N>.md 写入
         │
         v
  主 agent 读取 review 发现
         │
         v
  对每条发现执行分类：
  ┌────────────────────────────────────┐
  │ Fixed in: <filepath>              │ → 代码已修复，标记目标文件
  │ Tech-debt: <reason>               │ → 技术债登记，含理由
  │ Not-applicable: <reason>          │ → 不适用（如纯文档发现）
  └────────────────────────────────────┘
         │
         v
  写回 INDEPENDENT-REVIEW-<N>.md 的 agent 响应段
         │
         v
  PCSC: "review findings addressed in code" ✓
```

---

## 3. 关键状态机

### 3.1 AC-2a Symptom 字段文件路径提取策略

> 补充 DESIGN 级实现规约（对应 REQUIREMENT AC-2a 的三级判定规则）。

从自由文本 Markdown（L2/L3 盲审的 Symptom 字段）中提取文件路径的 Bash 实现策略：

```
输入: "在 REQUIREMENT.md:45 的 AC-2 缺少验证方式"
      "hooks/stop/lib/l3-review.sh 第 42 行硬编码了模型名"
      "设计稿与代码不一致"（无文件路径）

策略（按优先级）:
1. 显式路径模式: grep -oP '(^|\s)([a-zA-Z0-9_/.~-]+\.(sh|bats|js|ts|py|go|rs|md|json|yaml))(\b|:|\s)' 
   → 匹配 .扩展名 结尾的路径段
2. 多行处理: 按段落（空行分隔）为单位解析，一个发现 = 一个段落
3. 多文件: 一个发现可能引用多个文件 → 只要任意一个匹配源码扩展名，即判定为源码级
4. 无匹配: 默认判定为源码级（AC-2a 规则 3 — 宁可多检不漏检）

边界情况:
- 带行号的路径 ("file.sh:42") → 剥离 ":数字" 后缀后再分类
- 反引号包裹的路径 ("`file.sh`") → 剥离反引号后再分类
- 相对路径 vs 绝对路径 → 统一按扩展名判定，不关心路径深度
```

### 3.2 "Fixed in" 标记格式统一契约

> 修复 R3：prompt 层和 hook 层必须使用相同格式。

**统一格式**（prompt 层和 hook 层均使用）：
```
Fixed in: <relative/path/to/file>
```
- 前缀：`Fixed in:`（首字母大写，冒号+空格分隔）
- 路径：相对于项目根目录，如 `hooks/stop/lib/l3-review.sh`
- 每行一个文件（一个发现可能对应多个文件，多行列出）

**Prompt 层使用方式**：agent 在处理 review 发现后，在 INDEPENDENT-REVIEW-<N>.md 的 agent 响应段中输出：
```
### 发现 R1 处理
Fixed in: hooks/pre-tool-use/independent-review-gate.sh
Fixed in: hooks/stop/lib/fix-compliance.sh
```

**Hook 层解析方式**：
```bash
grep -oP '^Fixed in:\s+\K\S+' "$review_md" | while read -r f; do
  git diff --name-only HEAD | grep -qF "$f" || echo "MISSING: $f"
done
```

**禁止事项**：
- 不允许 `[FIXED in ...]` 方括号格式（不会被 hook 解析）
- 不允许 `fixed in:` 全小写（大小写敏感，简化解析）
- 不允许 `Fixed in: <描述>` 非路径文本（不会被 diff 匹配到）


---

## 4. ADR 索引

无不可逆架构决策。所有决策（D1-D7）均为 flow-kit 内部改进，不涉及项目级 ADR 变更。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **假阳性阻断**：源码扩展名白名单不覆盖用户项目的语言（如 .nim/.zig），导致有源码变更但被判定为"纯文档响应" | 正常 transition 被误阻断 | 低 | ① env var `L3_FIX_SOURCE_EXTS` 允许用户扩展白名单 ② 阻断时输出明确的"当前白名单 + 检测到的文件扩展名"，用户可立即定位 |
| R2 | **agent 重分类绕过**（REQUIREMENT 已知风险）：主 agent 将源码发现重新标记为 `[NOT-APPLICABLE]` 以绕过代码修复强制 | 实效性校验失效 | 中 | ① prompt 层约束：重分类需引用 review 原文证据 ② DESIGN 决定：分类标记的初始值由 review 报告原文决定，主 agent 只能追加不能修改 ③ hook 层检测：若 review 报告明确标记为源码问题但 agent 响应段全标记为 NOT-APPLICABLE → 告警 |
| R3 | **git diff 为空**：agent 声称修复但未产生任何 diff（如修复后又 revert）| 所有"已修复"声明的文件校验失败 | 低 | hook 检测 diff 为空 → 直接阻断（等同于纯文档响应），输出"diff 为空，无法验证修复" |
| R4 | **大 diff 性能**：大型 change 的 git diff 可能很大（>10MB），逐发现文件校验性能受影响 | transition 延迟增加 | 低 | git diff --name-only 提取文件列表（O(n) 文件名比对），不读 diff 内容 —— 性能影响 < 100ms |
| R5 | **与现有 gate 逻辑冲突**：在独立 review gate 中插入新校验可能意外改变现有行为 | 现有 change 的 transition 受影响 | 低 | ① 新增逻辑仅在 phase 5/6/7 + 源码发现 > 0 时触发 ② 现有 fk_validate_done_marker + gate_config 篡改检测逻辑不变 ③ 新逻辑在后、独立执行，前置条件不满足直接跳过（短路返回 exit 0） |

---

## 6. 不在范围

- 语义级 diff 校验（检查修改内容是否真的解决了发现描述的问题）→ v2
- 严重度分级响应（Critical 必须修 / Minor 可技术债）→ v2
- 自动修复建议生成（L2/L3 附带建议 patch）→ v2
- 修复覆盖率统计报告（FIX-COVERAGE.md）→ v2
- 跨 session 的修复追踪（"上轮没修完的这次继续修"）→ out
- 改动 L2/L3 审查内容生成逻辑 → out
- 修改 gate_config 预设体系 → out

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `hooks/stop/lib/fix-compliance.sh`（新增） | 实效性校验 helper：源码文件分类 + 纯文档 diff 检测 + 逐发现文件校验 | 任何需要校验"代码变更是否真的发生"的 gate 点 | 独立 lib，可被 PreToolUse hook（主路径）和未来 Stop hook 模块（兜底）复用 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 源码文件扩展名白名单 | 见 D3 列表 + env var `L3_FIX_SOURCE_EXTS` | 所有开启 5/6/7 gate 的 pipeline change | 低——env var 覆盖机制已就绪，改白名单仅影响新 change |
| fail-closed 容错策略（实效性校验层） | fail-closed（阻断），与 gate-integrity 一致 | 仅 phase 5/6/7 transition | 低——输出明确错误信息 + `/flow gate-config off` 紧急放行 |

### 9.3 新增 / 修改的跨模块契约

**`fix-compliance.sh` 函数签名与返回码**：

```bash
# fk_classify_source_files() — 按扩展名分类文件列表
# 输入: $1=文件列表（换行分隔）, $2=源码扩展名白名单（冒号分隔，默认从 env var 读取）
# 输出: stdout: "source:<count>" 换行 "doc:<count>" 换行 逐文件 "<type>:<path>"
# 返回: 0=成功, 1=jq 不可用, 2=输入为空
fk_classify_source_files() { ... }

# fk_check_doc_only_diff() — 检测 diff 是否仅含文档文件
# 输入: $1=project_root, $2=phase (仅用于日志)
# 输出: stdout: 判定结果行 "DOC_ONLY:true|false"
# 返回: 0=含源码变更（放行）, 1=仅文档变更（阻断）, 2=diff 为空（阻断）, 3=内部错误（阻断 · fail-closed）
fk_check_doc_only_diff() { ... }

# fk_verify_finding_files() — 逐发现文件级校验
# 输入: $1=review_md 路径, $2=project_root
# 输出: stdout: 逐行 "<status>:<filepath>" (status=OK|MISSING|PARSE_ERROR)
# 返回: 0=全部通过或 <50% 未通过（告警但放行）, 1=≥50% 未通过（阻断）, 2=解析错误（阻断 · fail-closed）
fk_verify_finding_files() { ... }

# fk_fix_compliance_check() — 实效性校验主入口（被 independent-review-gate.sh 调用）
# 输入: $1=phase, $2=change_id, $3=specs_dir (.specs/<id>/), $4=project_root
# 返回: 0=通过, 1=阻断（纯文档响应）, 2=阻断（逐发现校验未通过）, 3=错误（阻断 · fail-closed）
fk_fix_compliance_check() {
  # 仅 phase 5/6/7 触发
  # ① 读取 review_md，用 fk_classify_source_files 统计
  # ② fk_check_doc_only_diff 检测纯文档响应
  # ③ fk_verify_finding_files 逐发现校验
}
```

**`independent-review-gate.sh` 插入点**：

```bash
# 在 forward direction 分支中，L3 完成后、exit 0 前插入：
if [[ "$phase" =~ ^(5|6|7)$ ]]; then
  fix_compliance_lib="${HOOK_BASE_DIR}/../stop/lib/fix-compliance.sh"
  if [ -f "$fix_compliance_lib" ]; then
    source "$fix_compliance_lib" 2>/dev/null || true
    if type fk_fix_compliance_check >/dev/null 2>&1; then
      fk_fix_compliance_check "$phase" "$change_id" "${cwd}/.specs/${change_id}" "$cwd" || exit 2
    fi
  fi
fi
```

### 9.4 新增 / 升级的依赖

无新增外部依赖。所有函数用 git + jq 实现。

### 9.5 禁动清单变化

```
- 新增禁动：independent-review-gate.sh 中 fk_validate_done_marker() → fk_fix_compliance_check() 调用段 —— 
  不允许在中间插入其他逻辑破坏校验顺序（真实性 → 实效性 → 放行）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
