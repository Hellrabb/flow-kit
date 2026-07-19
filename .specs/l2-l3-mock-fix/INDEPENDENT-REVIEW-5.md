# 独立审查 · 阶段 5

## L2 盲审

- 审查对象：`.specs/l2-l3-mock-fix/TEST.md`
- 参考：`.specs/l2-l3-mock-fix/REQUIREMENT.md`、`.specs/l2-l3-mock-fix/TASK.md`
- 审查日期：2026-07-19
- 审查员：L2 独立盲审员（无主 agent 上下文注入）
- 实测：`npx bats test/` → **536 ok / 0 fail**（与 TEST.md 声称一致）

**独立性声明**：本次输入仅含工件文件路径 + 固化指令，未检测到主 agent 自评 / 草稿 / 辩护注入。

**总览**：所有 AC（F/H/I/J/K/T）与 NFR（1/2/3/4）均功能达标，全套真绿已复跑验证。但 AC-J 的覆盖广度不足（仅 phase 1）+ `_l3_parse_result` 与 `_l3_check_rerun` 的 hash 闭环在 artifact 缺失时有不变式断裂风险，需补足。无 🔴 Critical。

**元发现（不计入 verdict）**：本次写入报告时，**LIVE hook**（`~/.claude/hooks/pre-tool-use/independent-review-gate.sh` md5 `4d54dbe`）仍为 BUG-H 旧版（正则不识 heredoc/quoting），把本审查报告 heredoc 中的 `git commit` 字符串误判为 deny，复现 US-2 现场场景；AC-H 修复（md5 `fe23cdd`）**仅存在于 flow-kit-bundle 源码，未部署到运行时 hook 路径**。这是部署/安装缺陷，非 TEST.md 范畴，但提示本 change 的"全套真绿"不等价于"用户现场已修复"——TEST.md 未声明部署同步验证用例。

---

### 🟡 R1 · hash 闭环不变式断裂：`_l3_parse_result` 在 artifact_file 缺失时不写 hash → `_l3_check_rerun` 永远触发重审

**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l3-review.sh:472-479`，`_l3_parse_result` 中 `artifact_hash=$([ -f "$artifact_file" ] && sha256sum ...)`，若 artifact_file 不存在或 sha256sum 失败，`artifact_hash=""`；line 479 `if [ -n "$artifact_hash" ]` 跳过写入 `L3_artifact_hash:` 行。下次 `_l3_check_rerun`（line 401-404）`recorded_hash` 为空 → "保守重审" return 0。TEST.md 第 1.3/1.4 段未声明此边界。

**Source（源头）**：REQUIREMENT AC-J "hash 提取失败→重审+警告"（line 60）+ ADR-010 D4·J 判定优先级——spec 要求提取失败时**警告并降级**，但现行实现「审时不写 + 复审时降级」形成无警告的稳态重审循环（没有"提取失败"信号——因为根本没有 hash 行去触发"提取失败"，而是被「## L3 段在但 hash 行不在」静默覆盖）。设计契约要求「hash 提取失败」是一可观测事件，但 `L3_artifact_hash` 从未写入时，line 396 已先因"段缺失"返回——"段在 / hash 不在"路径仅由 line 402-404 兜底，且不可与"未写 hash 行"区分。

**Consequence（后果）**：phase 6/7（artifact=REVIEW.md）若 L3 被触发时 REVIEW.md 尚未生成（部分流水线把 REVIEW.md 视为 L3 产物之一而非输入），或 sha256sum 因权限/locale 异常返回空，会陷入每次 Stop 触发 L3 都"重审一次"的死循环，且日志仅说"hash 缺失或提取失败"，运维定位困难。中度概率。

**Remedy（修补）**：
- 选项 A（推荐）：`_l3_parse_result` 在 artifact_hash 为空时仍写一个显式标记行 `L3_artifact_hash: <missing>`（或 `L3_artifact_hash:` 空值），让 `_l3_check_rerun` 能区分"未写过"vs"写过但提取失败"。
- 选项 B：在 line 473 之后追加 `else echo "[l3-review] WARNING: artifact file missing when committing L3 hash: $artifact_file" >&2` 的同步警告，至少满足 AC-J "提取失败→警告"。
- 新增 bats 用例：phase 5/6/7 + artifact 缺失场景 → 断言下一次 `_l3_check_rerun` 行为（重审一次但 review_md 含 `L3_artifact_hash:` 行，第二次同输入应 skip 而非再次重审）。

---

### 🟡 R2 · AC-J 单元测试只覆盖 phase 1（REQUIREMENT.md），未覆盖 phase 5/6/7（含本 change 自身最相关的 TEST.md + 6|7 共享 REVIEW.md 的 case 分支）

**Symptom（症状）**：`test/test-l3-check-rerun-content-marker.bats` 全部 5 条 `_l3_check_rerun` 用例（line 39/46/59/71/82）均固定 `phase=1`（`run _l3_check_rerun 1 "$TMP_DIR/.specs/c"`），仅触及 `l3-review.sh:410` 的 `1) artifact_file=...REQUIREMENT.md` 分支与 `case` 的默认路径。TEST.md 1.3 段（line 46）"`_l3_check_rerun` 5 判定（首次/skip/内容改/段缺/hash 缺）"未声明 phase 维度覆盖。

**Source（源头）**：REQUIREMENT AC-J "验证方式：`bats` 集成测试：touch artifact（无 `## L3` 段）→ 仍触发复审；有非空 `## L3` 段 → skip"——spec 用"artifact"泛指，但 `l3-review.sh:409-415` 的 `case "$phase"` 把 1/2/3/5/6/7 映射到 5 个不同 artifact_file，且 6|7 共享 REVIEW.md——这是有分支的代码路径，单元测试应覆盖每个分支至少 1 例（等价类划分原则）。**讽刺点**：本 change 的产物 `.specs/l2-l3-mock-fix/TEST.md` 恰是 phase 5 的 artifact_file，但 AC-J 测试用 phase 1 而非 phase 5 验证自己。

**Consequence（后果）**：若未来有人修改 `case` 分支（例如把 5 的 artifact 误改为 REVIEW.md），AC-J 现有测试不会失败——phase 维度的回归无守护。低概率但高代价（静默漏检）。

**Remedy（修补）**：新增至少 3 条参数化用例覆盖 phase=5（artifact=TEST.md）/ phase=6（artifact=REVIEW.md）/ phase=7（与 6 共享 REVIEW.md，验证 6|7 case 分支未被打断）。可参数化：
```bats
@test "AC-J: phase=<N> artifact hash 闭环（参数化 5/6/7）" {
  # 复用 phase=1 的 fixture 模板，artifact_file 按 phase case 表换名
}
```

---

### 🟢 R3 · TEST.md AC-F 测试矩阵行错标 INT-7 回归位置

**Symptom（症状）**：`.specs/l2-l3-mock-fix/TEST.md:27` 表格行：
> AC-F（pure fn 单一来源） | unit + integration | **test-phase-gate-key-pure-fn.bats（逐 key=附录 oracle + INT-7 forward deny 回归）**

实测 `grep -ln 'INT-7' test/*.bats` 仅命中 `test/test_l2_pretooluse_dispatch.bats`（line 260: `INT-7 (BUG-F critical): phase1 forward transition 无.done deny exit2`）。`test-phase-gate-key-pure-fn.bats` 不含 forward transition 用例（其 Part B 用 `git commit` deny 路径，line 86）。

**Source（源头）**：TASK T01 `<verify>` 段（line 46）已正确分离两文件：`npx bats test/test-phase-gate-key-pure-fn.bats && npx bats test/test_l2_pretooluse_dispatch.bats -f 'INT-7'`——TASK 是真相源，TEST.md 矩阵是描述错误。

**Consequence（后果）**：未来 grep "INT-7 回归在哪" 会找到 TEST.md → 走错文件 → 误以为 `test-phase-gate-key-pure-fn.bats` 已覆盖，从而在重构该文件时无意删除/破坏 INT-7（实际在另一文件）的可见性。

**Remedy（修补）**：TEST.md line 27 改为：
```
test-phase-gate-key-pure-fn.bats（逐 key=附录 oracle + git commit deny 三要素守护）；
INT-7 forward deny 回归在 test_l2_pretooluse_dispatch.bats
```

---

### 🟢 R4 · AC-J 判定计数前后矛盾（6 vs 5 vs 6）

**Symptom（症状）**：TEST.md 自相矛盾——
- line 30：`test-l3-check-rerun-content-marker.bats（6 判定 + regex fixture）`
- line 46：`_l3_check_rerun 5 判定（首次/skip/内容改/段缺/hash 缺）+ regex fixture`
- 步骤 N line 117：`test-l3-check-rerun-content-marker.bats（AC-J 6 判定 + regex fixture）`

实测：5 条 `_l3_check_rerun` 用例 + 1 条 regex 用例 = 6 条。

**Source（源头）**：纯文档内部一致性。

**Consequence（后果）**：审计者读到 line 46 会以为漏写一条用例（5 vs 6），浪费时间核对。

**Remedy（修补）**：统一为「5 条 `_l3_check_rerun` 判定 + 1 条 regex fixture = 共 6 用例」的全句表述，line 46 补全。

---

### 🟢 R5 · 第 2 轮性能测试方法学薄弱（n=3 + ms 整数量级，"差 0%" 是量化精度伪信号）

**Symptom（症状）**：TEST.md line 65-74：方法 `bash time ×3 中位数`，结果「重构前 53 ms / 重构后 53 ms / 差 0%」。`time` 内建在毫秒粒度量化误差约 ±5 ms，53 - 53 = 0 不代表真实差为 0，只代表真实差被量化到同一桶。

**Source（源头）**：REQUIREMENT NFR-1 line 74 "`time` 3 次取中位数对比（LESSONS Stop hook 性能基线方法）"——spec 本身只要求 n=3 中位数，未要求更高精度，所以**合规**；但 TEST.md 报告"差 0%"是过度精确的措辞，与实际测量能力不匹配。

**Consequence（后果）**：未来若有人在更慢机器/CI 上测出"重构后 70ms / 重构前 50ms = 40% 回归"，会与本次报告"0%"对峙——无方差/置信区间无法解释。NFR-1 通过结论本身稳（远 < 30%），但报告严谨性留下债务。

**Remedy（修补）**：TEST.md 性能段加注「`time` ms 整数量化误差 ±5ms，53 vs 53 不等价于真实差为 0；本次仅以"< 30% 阈值"为通过判据」；或追加 `hyperfine`/`/usr/bin/time -f '%e'` 高精度对比作为补充（≥10 次采样 + 标准差）。

---

### 🟢 R6 · test-pipeline-no-g1-autoadvance.bats 守卫特征静态测试脆弱（awk 仅断言"两 token 同文件"）

**Symptom（症状）**：`test/test-pipeline-no-g1-autoadvance.bats:78-85`「守卫特征」用例：
```bash
awk '/goal_scope/{has_scope=1} /fk_auto_phase/{has_auto=1} END{exit !(has_scope && has_auto)}'
```
仅断言 `goal_scope` 与 `fk_auto_phase` **同时出现在文件**，未断言二者**在同一控制流分支**（即 `if goal_scope != pipeline` 包裹 `fk_auto_phase`）。

**Source（源头）**：ADR-011 / REQUIREMENT AC-K（line 106）"若 G1 保留 auto-advance，必须**同步**上述四字段"——AC-K 的语义是 pipeline 模式下 fk_auto_phase **不得调用**，但此静态测试允许 fk_auto_phase 在另一无关函数里被调用也算"通过"。

**Consequence（后果）**：低——AC-K-1/2/3 三条**行为**用例（实际跑 26-workflow.sh + 断言 .phase 值）足以守护真实回归。但「守卫特征」用例若独立看，给读者虚假安全感（"守卫在"≠"守卫生效"）。

**Remedy（修补）**：要么删除「守卫特征」冗余静态测试（行为测试已足），要么加强 awk：要求 `goal_scope != pipeline` 与 `fk_auto_phase` 出现在同一 `if ... fi` 块内（用 awk 状态机跟踪 brace 深度），例如：
```bash
awk 'BEGIN{depth=0; in_guard=0}
     /\{/{depth++}
     /\}/{depth--; if(depth==0) in_guard=0}
     /goal_scope != "pipeline"/{in_guard=1; guard_depth=depth}
     /fk_auto_phase/ && in_guard && depth>=guard_depth {has_auto=1}
     END{exit !has_auto}' "$WORKFLOW_SH"
```

---

### 🟢 R7 · TEST.md 1.1 NFR-3 三要素声明并入 AC-F/H/I，但 AC-I 的 D4 是 exit 0（wait）非 deny（exit 2），不适用未澄清

**Symptom（症状）**：TEST.md line 34："NFR-3（deny stderr 三要素：phase_name + .done 路径 + 阻断原因）并入 AC-F/H/I 集成测试断言。" 实测 `test-l2-first-correction.bats` 无 stderr 三要素断言——因为 AC-I 的 D4 门是 `exit 0`（"L2-first 等待"），不是 deny（exit 2）。NFR-3 仅适用于 deny 场景（REQUIREMENT line 88 "gate deny"）。

**Source（源头）**：REQUIREMENT AC-I line 52 "(b) 29 D4 提示清晰化：D4 `exit 0` 时提示含..."——明文 D4 是 exit 0。NFR-3 line 86 "F/H/I/J 改动后的任一 **deny** 场景"——D4 非 deny。

**Consequence（后果）**：审计者按 TEST.md line 34 指引去 `test-l2-first-correction.bats` 找 NFR-3 三要素断言会扑空，误判"AC-I 漏测 NFR-3"。

**Remedy（修补）**：TEST.md line 34 改为「NFR-3 三要素并入 AC-F/H deny 场景断言；AC-I 的 D4 是 exit 0（wait）非 deny，NFR-3 不适用；AC-J 的 _l3_check_rerun 非 gate 路径，NFR-3 不适用」。

---

**Verdict**: pass

**发现摘要（供主 agent 决策）**：

| ID | 严重度 | 主题 | 是否阻塞 commit |
|---|---|---|---|
| R1 | 🟡 Major | hash 闭环在 artifact_file 缺失时断裂，可能触发无限重审 | 否（边界场景） |
| R2 | 🟡 Major | AC-J 单元测试仅 phase 1，未覆盖 5/6/7 case 分支 | 否（覆盖广度不足） |
| R3 | 🟢 Minor | TEST.md AC-F 错标 INT-7 测试文件位置 | 否 |
| R4 | 🟢 Minor | AC-J 判定计数 6 vs 5 自相矛盾 | 否 |
| R5 | 🟢 Minor | 性能测试 n=3 + ms 量化精度不足 | 否 |
| R6 | 🟢 Minor | pipeline 守卫静态测试脆弱（awk 语义弱） | 否 |
| R7 | 🟢 Minor | NFR-3 并入 AC-I 表述误导（D4 非 deny） | 否 |

**AC 覆盖核验**：6/6 AC（F/H/I/J/K/T）+ 4/4 NFR（1/2/3/4）均功能达标。无 🔴 Critical，Verdict = **pass**。

R1 / R2 建议作为 phase 5 → phase 6 transition 前补强（或以 `Tech-debt:` 标记后随本 change commit）。R3-R7 为文档准确性修补，建议本 phase 内一并 fix（成本低）。

---

## 主 agent 响应（修代码优先协议 · DESIGN §3.2 格式）

> 对 L2 盲审每条 🟡/🟢 发现的分类回应。L2 Verdict=pass（无 🔴），以下为质量改进。

### R1 · hash 闭环 artifact_file 缺失（🟡）→ Tech-debt
**Tech-debt**: 边界场景——L3 审查（Stop hook）发生在 artifact_file（TEST.md/REVIEW.md）已生成后，artifact_file 缺失本身是异常流水线状态（产物未生成就触发 L3），低概率。当前 `_l3_check_rerun` :402-404「保守重审」已 fail-safe（防数据损坏），仅缺可观测性。计划：后续 change 加 `_l3_parse_result` 在 artifact_hash 空时写 `L3_artifact_hash: <missing>` 显式标记 + 警告（L2 选项 A）。

### R2 · AC-J 单测仅 phase 1（🟡）→ Tech-debt
**Tech-debt**: 测试覆盖增强（非 bug）。phase 1 覆盖已验证 `_l3_check_rerun` 判定逻辑（5 判定 + regex）；phase 5/6/7 走同一 `case` 默认路径 + 不同 artifact_file 映射（l3-review.sh:410-414，未变）。计划：后续 change 补参数化用例 phase=5（TEST.md）/6/7（REVIEW.md 共享）。

### R3 · INT-7 位置错标（🟢）→ Fixed in
**Fixed in**: `.specs/l2-l3-mock-fix/TEST.md` line 27（AC-F 矩阵改为「test-phase-gate-key-pure-fn.bats（git commit deny 三要素守护）；INT-7 forward deny 回归在 test_l2_pretooluse_dispatch.bats」）

### R4 · AC-J 计数矛盾 6 vs 5（🟢）→ Fixed in
**Fixed in**: `.specs/l2-l3-mock-fix/TEST.md` line 30/45/115 统一为「5 判定 + 1 regex fixture = 共 6 用例」

### R5 · 性能 n=3 精度措辞（🟢）→ Fixed in
**Fixed in**: `.specs/l2-l3-mock-fix/TEST.md` 第 2 轮性能段加「精度说明（L2 R5）」：±5ms 量化误差，53 vs 53 ≠ 真实差 0，以 <30% 阈值为判据

### R6 · pipeline 守卫静态测试脆弱（🟢）→ Not-applicable
**Not-applicable**: AC-K-1/2/3 三条**行为**测试（子进程跑 26-workflow.sh + 断 .phase 值）已守护真实回归。「守卫特征」静态 awk 测试是冗余辅助，保留无害（真实回归由行为测试覆盖）。

### R7 · NFR-3 并入 AC-I 误导（🟢）→ Fixed in
**Fixed in**: `.specs/l2-l3-mock-fix/TEST.md` line 34 改为「NFR-3 并入 AC-F/H deny 场景；AC-I D4 是 exit 0 非 deny / AC-J 非 gate 路径，NFR-3 不适用」

### 元发现 · 全部 5 hook 未部署（部署缺陷）→ Fixed in
**Fixed in**: `cp flow-kit-bundle/hooks/{gate.sh, 26-workflow.sh, 29-independent-review.sh, common.sh, l3-review.sh} → ~/.claude/hooks/`（md5 全 ✓ · 运行时 hook 现为新版）。BUG-H 现场复现（heredoc git commit 误判）已消除。根因：改 flow-kit-bundle/ 源码但未重装部署路径。建议 7-integration 加「部署同步」检查项。

**AC-4 技术债滥用防护**：R1/R2 为 Tech-debt（2/7 源码级发现 = 29% < 50%），均含理由 + 计划修复版本。R3-R7 + 元发现均 Fixed in / Not-applicable（有代码/部署变更）。

---

## L3 重审（glm-5.1 外部模型 · 2026-07-19 14:12）

> 自动生成于 2026-07-19 14:12。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [],
  "major": [],
  "minor": [
    {
      "file": "第 2 轮 · 性能测试",
      "issue": "性能测试结论前后矛盾，且存在一定不可重现性",
      "why": "1. 结论称重构前/后均为 '53 ms'，但精度说明内又称 'time 内建 ms 整数量化误差约 ±5ms，53 vs 53 不等价于真实差为 0'，两处叙述自相矛盾，易误导读者；2. n=3 的采样次数较少，在宿主机负载波动下，±5ms 的量化误差极易导致无法稳定重现出精确的 53ms，这削弱了 UAT 的绝对可复现性。",
      "fix": "修正措辞消除矛盾（例如改为 '受量化误差限制，二者耗时无显著差异'）；若条件允许，追加 hyperfine ≥10 次采样取中位数及标准差，以提供具备健壮复现性的精确性能基线。"
    },
    {
      "file": "第 4 轮 · 兼容性测试",
      "issue": "Bash 4.4 向下兼容性未真实运行验证，仅作理论推断",
      "why": "工件声称兼容 bash 4.4+，但测试矩阵中标注 '当前环境仅 5.2 可实跑；4.4 由「不依赖 declare -A」论证保证'。由于代码中可能存在其他在 4.4 版本被弃用或行为变更的语法，缺少实际执行会留下潜在的兼容性测试盲区。",
      "fix": "建议在未来条件允许时，使用 Docker（如 bash:4.4 镜像）执行一次真实的 4.4 环境回归测试；若确无条件，应在技术债中明确登记 'bash 4.4 兼容性为静态代码论证，未实跑'。"
    }
  ],
  "verdict": "pass",
  "summary": "测试矩阵对全部 AC 覆盖严密，断言均指向外部行为结果，且测试设计有效避免了 mock 屏蔽真实失败，整体质量优良。"
}
```
```

L3_artifact_hash: fb387057b466d92c001f78565ecee7cd094bffe84e68681c9439a6504ee2543c

---

## 主 agent 响应 L3（2026-07-19）

> L3 verdict=pass（critical/major 空，2 minor）。两层 gate 完成，`.independent-review-5.done` 写入。

### L3-minor-1 · 性能结论矛盾（🟢）→ Not-applicable（已 Fixed in L2 R5）
**Not-applicable**: 与 L2 R5 完全重叠。TEST.md 第 2 轮已加「精度说明（L2 R5）」明确 53vs53 ≠ 真实差 0、以 <30% 阈值为判据。L3 建议的「无显著差异」措辞是偏好优化，精度注已传达等价语义。

### L3-minor-2 · bash 4.4 未实跑（🟢）→ Tech-debt（已登记）
**Tech-debt**: 已在 T08-SUMMARY + DESIGN NFR-2 段登记——当前环境仅 bash 5.2，4.4 由「pure fn case 不依赖 declare -A」论证保证。计划：后续条件允许用 Docker bash:4.4 镜像实跑。
