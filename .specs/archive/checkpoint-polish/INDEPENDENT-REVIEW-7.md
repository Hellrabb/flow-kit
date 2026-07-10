# 独立审查 · 阶段 7

## L2 盲审

> 审查日期：2026-07-10
> 审查员：L2 独立盲审 agent
> 审查范围：`.specs/checkpoint-polish/` 下全部产物 + `.specs/LESSONS.md` + `.specs/CHANGELOG.md`

---

### 0. 阶段 7 集成审查矩阵（逐条对照）

| 准则 | 状态 | 证据 |
|---|---|---|
| 产物齐全 | ✅ | CHANGE / REQUIREMENT / DESIGN / TASK / SUMMARY / TEST / REVIEW 全部存在 |
| LESSONS 同步 | ⚠️ | CHANGELOG LESSONS 列标记 `—`，但 Phase 6 L2 🔴 R1（Makefile lint glob 系统性盲区）有提取教训价值——见下文 R1 |
| CHANGELOG 更新 | ✅ | `.specs/CHANGELOG.md:5` 已追加 checkpoint-polish 条目，格式紧凑 pipe |
| 归档清洁 | ⚠️ | `.specs/checkpoint-polish/` 自身无残留；但 T04 创建的 `.specs/CHANGELOG.md.bak`（BW02 操作备份）仍存在于 .specs 根目录——见下文 R2 |
| done 标记 | ⚠️ | `.independent-review-7.done` 尚未创建（本轮审查进行中，pass 后由主 agent 写入） |
| 修代码优先 | ✅ | Phase 6 L2 全部 🔴🟡 发现均已有代码变更或显式技术债登记（含理由），无推迟到下一轮 change |

---

### 🟡 R1 · LESSONS.md 未从 checkpoint-polish 各阶段独立审查发现中提取经验教训

**Symptom（症状）**：`.specs/CHANGELOG.md:5` 的 checkpoint-polish 条目 LESSONS 列标记为 `—`，`.specs/LESSONS.md` 全文无 checkpoint-polish 相关内容（grep `checkpoint-polish|banner.sh|test-sync|BW01|BW02|BW03` 零命中）。

但 Phase 6 L2 独立审查发现了一条具有跨 change 复用价值的系统性发现：
- **🔴 R1**：`make lint` 的 for-loop glob `hooks/stop/*.sh` 遗漏 `hooks/stop/lib/` 子目录，导致 12 个 lib 文件（含本次新增的 `banner.sh`）绕开自动化 shellcheck 门禁。这是一个"当在 hooks/ 下新增子目录时，Makefile 门禁 glob 需同步更新"的通用教训。

另外，Phase 5 L2 🟡 R2（make check 全链路验证缺口——lint/validate 子目标未验证即宣告回归安全）也反映了"修改 Makefile 后必须验证 check 全链路"的测试卫生问题，可一并提炼为教训。

**Source（源头）**：阶段 7 集成审查准则——"是否从本次 REVIEW 中提取了新教训并写入 LESSONS.md？"SUMMARY.md 的「Lessons 候选」段列出了两条实施笔记（banner.sh 打包覆盖自动纳入、check-test-sync 已有检测逻辑），但遗漏了 L2 独立审查发现的系统性问题。

**Consequence（后果）**：Makefile lint glob 盲区的教训未被固化，未来开发者在 hooks/ 下新增子目录添加脚本时可能重复同样的错误（忘记更新 Makefile glob），导致新脚本绕开自动化 lint。该教训仅在 CHANGELOG 不可见（LESSONS 列 `—`），后续 M-health 巡检也不会发现。

**Remedy（修补）**：在 LESSONS.md 技术债清单追加一条（例如编号 L-033）：
```
### L-033 · Makefile for-loop glob 必须覆盖所有 hooks 子目录中的 shell 脚本

**严重程度**: 🟡 Major
**来源**: `checkpoint-polish` change（2026-07-10 · Phase 6 L2 独立审查 R1）
**发现**: `make lint` 的 shellcheck for-loop glob `hooks/stop/*.sh` 仅匹配 `stop/` 直属文件，遗漏 `stop/lib/` 下 12 个 lib 文件。本次新增的 `banner.sh` 落入此盲区。shellcheck 手动通过了但 `make check` 自动化门禁不会复现——任何对 lib 文件的修改合入前都不会被 lint。
**教训**: 在 Makefile 中设计文件扫描 glob 时，必须覆盖已存在和规划中的所有子目录；新增子目录后立即检查所有 Makefile target 的 glob 是否涵盖新路径。
**建议**: Makefile lint target 的 for-loop 改为 `find flow-kit-bundle/hooks/ -name '*.sh'`（递归），消除手工维护 glob 列表的遗漏风险。
**状态**: ✅ 已修复（Makefile L23 追加 `flow-kit-bundle/hooks/stop/lib/*.sh`）
```
同时更新 CHANGELOG.md 该条目的 LESSONS 列：`—` → `L-033`。

---

### 🟡 R2 · `.specs/CHANGELOG.md.bak` 操作残留未清理

**Symptom（症状）**：`.specs/CHANGELOG.md.bak`（664 bytes）仍存在于 `.specs/` 根目录。该文件由 T04（BW02 CHANGELOG 格式统一）action 第 1 步创建：`cp .specs/CHANGELOG.md .specs/CHANGELOG.md.bak`，但在 T04 完成且 AC-5（条目数不变）验证通过后未被删除。

**Source（源头）**：TASK.md T04 `<action>` 包含创建备份的步骤，但 `<verify>` 和 `<done>` 均未包含清理备份的操作。备份文件的创建是防御性措施（DESIGN.md R2 缓解：`git 版本控制可回滚`），但完成后应清理——git 本身已提供回滚能力，`.bak` 文件是冗余且非规范化的残留物。

**Consequence（后果）**：轻微——一个孤立的 `.bak` 文件会增加仓库噪音（`git status` 显示 untracked file），但不会影响功能。若后续 CHANGELOG.md 被大幅修改，该 `.bak` 内容会过时，成为误导性的"伪备份"。更重要的是，它违反了"归档清洁"原则——change 的副作用应在集成阶段完全清理。

**Remedy（修补）**：删除该文件：`rm .specs/CHANGELOG.md.bak`。TASK.md T04 `<action>` 末尾追加"第 7 步：清理备份 `rm .specs/CHANGELOG.md.bak`"（文档修正留到下次触及 TASK.md 时顺手补）。

---

### 🟢 R3 · `banner.sh:53` 残留 `local int_ts` 声明——Phase 6 R2 修复不彻底

**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/banner.sh:53` 仍保留 `local int_file int_action int_ts` 声明。Phase 6 L2 R2 要求删除未使用的 `int_ts` 变量，主 agent 的响应为"Fixed in: banner.sh L62"——删除了 L62 的 `int_ts=$(jq -r ...)` 赋值行（独立确认：该赋值已删除），但 L53 的 `local int_ts` 声明被遗漏。`int_ts` 在函数体内既无赋值也无读取，属于"已声明但从未使用"的死代码残留。

**Source（源头）**：shellcheck SC2034 针对的是"变量已赋值但未读取"的场景。当赋值被删除后，`local` 声明本身不会触发 SC2034（未赋值的 `local` 声明被 shellcheck 视为正常），因此 Makefile lint 不会报警。需要人工审查才能发现此类残留。

**Consequence（后果）**：极轻微——`local int_ts` 声明无任何运行时副作用（不产生子进程、不分配额外内存、bash 不报错）。仅在代码阅读时产生轻微困惑（"int_ts 声明了但后面怎么没用？"）。不影响功能正确性、性能或安全性。

**Remedy（修补）**：将 L53 改为 `local int_file int_action`（删除 `int_ts`）。可在下次触及该文件时顺手清理，无需单独 commit。

---

### 🟢 R4 · 测试数量基线偏差已标记为 Tech-debt 但未在文档中 reconcile

**Symptom（症状）**：REQUIREMENT.md L110 声明全量 bats 基准为"407 测试 0 fail"，TEST.md 报告全量测试数为"462"。偏差 +55 tests（+13.5%），其中仅 +7 来自本次新增的 test_resume_banner.bats，其余 +48 来自其他 change（td-test-infra 等）。Phase 6 L2 R6 已发现此偏差，主 agent 归类为"Tech-debt: 文档偏差"，但既未在 REQUIREMENT.md 中更新基线数字，也未在 TEST.md 中加注释说明偏差来源。

**Source（源头）**：REQUIREMENT.md 基线 407 来自 M-health 2026-07-08 实测。后续 change（td-test-infra、fix-l3-gate 等）在 checkpoint-polish 之前合入并增加了测试文件，导致基线自然增长。Phase 5 L2 R3 亦独立发现了相同问题。

**Consequence（后果）**：轻微。REVIEW.md（AC-3 行）直接使用 462 作为当前值，与 REQUIREMENT.md 407 基线不一致——读者无法从文档中判断 +55 是本次贡献还是基线漂移。不影响 AC 合规判断（AC-3 只要求"0 fail"不要求特定数量）。

**Remedy（修补）**：二选一：(a) 在 TEST.md 1.3 节或 REVIEW.md AC-3 行追加一句说明：`基线 REQUIREMENT.md:407 → 实测 462（+55），其中本次 +7，其余来自前序 change 的新增测试`；(b) 将 REQUIREMENT.md L110 基线更新为 462。方案 (a) 更轻量且保留了基线变更历史。

---

### 独立确认项

以下为主 agent REVIEW.md 的判定项，本审查通过独立阅读全量工件确认一致：

| 项 | 判定 | 独立确认 |
|---|---|---|
| 7/7 AC 全部合规 | ✅ | 逐 AC 对照 TEST.md 1.1 矩阵，均有自动化可验证覆盖（除 AC-1 diff 为一次性重构验证） |
| 范围蔓延检查 | ✅ | BW04 未实现，无 REQUIREMENT.md 之外的额外功能，无禁动清单外的文件变更 |
| Phase 6 L2 全部 🔴🟡 发现已修复/登记 | ✅ | R1 Makefile glob fixed、R2 int_ts 赋值 removed、R3 Tech-debt: accepted、R4 Tech-debt: low prio、R5 source 错误处理 fixed、R6 Tech-debt: 文档偏差 |
| CHANGELOG 格式统一 | ✅ | `grep -c '^\| 日期 \| Change ID'` = 0，38 entries 紧凑 pipe，条目数不变 |
| 双源同步机制 | ✅ | `make test-sync` recipe 正确，`make check-test-sync` 检测 + 提示脚本存在 |
| done 标记质量 | ✅ | Phase 1/2/3/5/6 五个 .done 文件均含完整 KVP（phase / change_id / written_by / L2_verdict / L3_verdict / artifacts），非空文件，非 touch |
| 全量 bats 0 fail | ✅ | 462 tests 0 fail（独立实测确认） |

---

**Verdict**: pass

不存在 🔴 Critical 发现。两条 🟡 Major 发现（R1 LESSONS 同步缺失、R2 CHANGELOG.md.bak 残留）均不构成阻塞——可在 pass 后由主 agent 同步修复（追加 L-033 教训条目 + 删除 .bak 文件）。两条 🟢 Minor 发现（R3 int_ts local 残留、R4 基线偏差未 reconcile）可在后续变更中顺手处理，不阻塞归档。

**pass 后需执行**：
1. 追加 L-033 教训到 LESSONS.md（内容见 R1 Remedy）
2. 更新 CHANGELOG.md checkpoint-polish 条目 LESSONS 列：`—` → `L-033`
3. 删除 `.specs/CHANGELOG.md.bak`
4. 写入 `.specs/checkpoint-polish/.independent-review-7.done`（主 agent 调用合法 review 子进程写入，格式对齐前序阶段）
