# 独立审查 · 阶段 3

## L2 盲审

### 🟡 R1 · AC-3 混合场景测试缺失：无法验证两层校验共存
**Symptom（症状）**：TASK.md T07 action 明确列出测试覆盖 AC-2/AC-2a/AC-2b/AC-5，但未覆盖 AC-3。T08 verify 仅执行 `npx bats flow-kit-bundle/test/`（回归），不构造新场景。然而 AC-3 的验证方式明确要求 _两层_ 验证：第一层"构造混合场景（假 .done + 纯文档 diff）→ 两层均报错且信息不重叠"，第二层"`npx bats test/` 现有 gate-integrity 测试全部通过"。第二层由 T08 覆盖，第一层无任何 task 负责。

**Source（源头）**：REQUIREMENT.md AC-3 验证方式原文（line 67），要求构造特定混合场景验证两层校验互不干扰。DESIGN §2 架构图中步骤③-⑤仅描述 fix-compliance 层自身的数据流，未描绘与 gate-integrity 层的交互场景。T07 测试列表遗漏此场景。

**Consequence（后果）**：实现完成后无法机器验证 AC-3 的核心语义——"两层校验互不干扰、各自输出独立错误信息、信息不重叠"。如果 fix-compliance 校验代码意外修改了 gate-integrity 的中间状态（如全局变量污染、exit code 吞噬），测试套件不会发现。风险在后续 change 改动 gate hook 时被放大——任何对 independent-review-gate.sh 的修改都可能打破两层共存契约。

**Remedy（修补）**：在 T07 action 的测试列表末尾追加 AC-3 混合场景：
  - "AC-3 两层共存：构造假 `.done`（L3_verdict=pass 且格式合法）+ git diff 仅含 .md → 验证 fix-compliance 阻断（exit 2）且 stderr 不含 gate-integrity 的错误前缀（如 `⛔ 独立 review gate（D8`），同时 gate-integrity 层的 `fk_validate_done_marker` 对该假 .done 返回 0（放行）"
  同时在 T07 的 `<done>` 文本中追加 "AC-3 混合场景测试通过"。

---

### 🟡 R2 · T08 verify 命令对 AC-4/AC-5 的验收检查缺失
**Symptom（症状）**：TASK.md T08 action 段明确列出验收步骤（line 211-217）：AC-1 用 grep、AC-2/AC-2b 依赖 T07、AC-3 回归测试、AC-4 用 grep、AC-5 用 grep。但 T08 的 `<verify>` 命令仅执行 `npx bats flow-kit-bundle/test/ && echo "AC-1:" && for f in ... done`（line 219）。AC-4（`grep` 确认 prompt 含 50% 阈值约束）和 AC-5（`grep` 确认 hook 硬编码 phase 5/6/7 白名单）的检查未出现在 verify 命令中，只能靠人工在终端阅读 echo 输出来判断。

**Source（源头）**：阶段 3 审查 checklist 第 3 项——"每条 verify 是否可机器执行（非'人工确认'空话）"。当前 verify 中 AC-4/AC-5 的机器可验证性缺失，沦为行动描述中的 prose-only 承诺。

**Consequence（后果）**：T08 标记 done 时，verify 命令可成功运行（bats 通过 + echo 输出）但实际 AC-4/AC-5 的约束可能未实现。若实现者漏写了 50% 阈值约束或阶段白名单，verify 不会报错。中等影响——T03/T04/T05/T06 各自的 verify 已通过 grep 单独验证了部分内容，T08 是集成验收的最后一道防线，缺失会增加遗漏概率。

**Remedy（修补）**：扩展 T08 `<verify>` 命令，追加：
  ```bash
  && echo "AC-4:" && grep -q "50%" flow-kit-bundle/flow-kit/prompts/5-test.md && echo "AC-4 50% threshold found"
  && echo "AC-5:" && grep -qE "phase.*=~.*\^\(5\|6\|7\)" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && echo "AC-5 phase whitelist found"
  ```
  并用 `grep -q ... || exit 1` 替代 `echo` 以确保失败时退出。

---

### 🟢 R3 · T06 插入点描述未提及 gate hook 双出口结构
**Symptom（症状）**：TASK.md T06 action（line 148）描述"在 forward direction 分支、L3 完成后、exit 0 前"。independent-review-gate.sh 在 forward direction 分支中存在 _两个_ 独立的 L3 完成后 exit 0 出口：both 模式路径（line 262）和 L3-only 模式路径（line 302）。两个路径代码结构几乎镜像（L3 调用 → handshake → _l3_format_result → fk_validate_done_marker → exit 0），但 T06 和 DESIGN §9.3 均仅描述一处插入点，未提及需要适配两处。

**Source（源头）**：DESIGN §9.3 代码骨架展示的插入点仅覆盖 both 模式路径（`if [ -f "$review_md" ] && grep -q "^## L2 盲审"` 分支内），未覆盖 `elif [[ "$gate_val" == "L3" ]]` 分支。

**Consequence（后果）**：实现者可能仅在一处插入 fix-compliance 校验，导致 L3-only 模式的 phase 5/6/7 transition 不触发实效性校验。影响范围：仅使用 L3-only gate_config 的 change 会漏检——发现概率低（大多数项目用 both 模式）。触发条件窄，影响可控。

**Remedy（修补）**：在 T06 action 末尾追加一句："注意：forward direction 中 L3-only 路径（`elif [[ "$gate_val" == "L3" ]]` 分支，约 line 300）也有 exit 0 出口，同样需要插入实效性校验调用。"

---

### 🟢 R4 · T02 verify 未检查 checklist 项插入位置准确性
**Symptom（症状）**：TASK.md T02 action（line 62-63）要求将 checklist 项追加到"阶段 5/6/7 checklist 中各追加一项"和"「与主 agent 的关系」段追加"——共两个不同的插入位置。但 T02 `<verify>` 仅执行 `grep -q "Fixed in:"` 和 `grep -q "纯文档敷衍"`（line 70）——确认关键词存在，不确认关键词出现在正确的 checklist 段落中。若实现者将所有内容错误地全部塞入阶段 1 的 checklist 段（该段不适用于修代码优先逻辑），verify 仍能通过。

**Source（源头）**：阶段 3 审查 checklist 第 4 项——"覆盖完整性"。verify 对"覆盖的精确性"（位置正确性）不做区分。

**Consequence（后果）**：低风险。L2-blind-review.md 全文仅 ~110 行，人工 review 容易发现位置错误。但 verify 的机器判断力存在虚假阳性窗口。

**Remedy（修补）**：增强 verify 命令：
  ```bash
  grep -A5 "阶段 5.*测试审查" flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md | grep -q "Fixed in:" &&
  grep -A5 "与主 agent 的关系" flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md | grep -q "纯文档敷衍"
  ```
  若增强 grep 过于脆弱（段落结构可能变化），至少明确标注 T08 中人工验收需覆盖位置检查。

---

### 🟢 R5 · T03-T05 read_files 缺少 REQUIREMENT.md 引用
**Symptom（症状）**：T03/T04/T05 的 action 分别引用 AC-4（"若 ≥50% 发现被标记为 Tech-debt，需输出显式说明"）和 6-review/7-integration 的特殊处理逻辑。但 `<read_files>` 仅列出目标 prompt 文件和 DESIGN.md，未列出 REQUIREMENT.md（line 80/101/122）。实现者无法直接从 read_files 对照 AC 原文验证协议文本是否准确覆盖了每条 AC 的细节。

**Source（源头）**：任务拆解最佳实践——task 的 read_files 应包含实现所需的所有规格文档。DESIGN.md 是设计参考，但 AC 原文在 REQUIREMENT.md 中。

**Consequence（后果）**：轻微。有经验的实现者会自行查阅 REQUIREMENT.md；且 DESIGN.md 转述了 AC 要点。不会导致功能遗漏，但可能造成协议文本与 AC 原文的细微偏差（如措辞不够精确）。

**Remedy（修补）**：在 T03/T04/T05 的 `<read_files>` 中追加 `.specs/l2-l3-fix-compliance/REQUIREMENT.md`。

---

**Verdict**: pass

---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 15:17）

> 自动生成于 2026-07-07 15:17。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[{"file":"T08 verify 命令","issue":"grep 正则 `[5|6|7]` 会匹配字符 `5`、`|`、`6`、`7` 中的任意一个，而非期望的 `5` 或 `6` 或 `7` 的字符串模式，可能导致错误匹配或漏匹配。","why":"verify 命令用于确认 AC-5 阶段白名单在 gate 脚本中，但该正则写法不严谨，可能产生假阳性或假阴性。","fix":"改用 `grep -Eq '(^|[^0-9])(5|6|7)([^0-9]|$)'` 或更精确的行匹配，确保仅匹配阶段数字本身。"}],"verdict":"pass","summary":"任务拆解覆盖了 REQUIREMENT 全部 AC（AC-1~AC-5），depends_on 无环，verify 可执行且可证伪（除 T08 正则小瑕疵外），write_files 边界清晰不越界。无 critical 问题，整体工件合规。"}
```
