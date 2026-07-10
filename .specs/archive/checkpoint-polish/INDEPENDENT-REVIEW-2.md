# 独立审查 · 阶段 2

## L2 盲审

### 🟡 R1 · 打包覆盖验证缺位：banner.sh 的 Part D 注册以"需确认"递延到实现阶段

**Symptom（症状）**：DESIGN.md §5 R5 的缓解列写道 `BW01 新 lib 需确认 Part D 覆盖 hooks/stop/lib/`，将打包脚本对新 lib 文件的覆盖验证从设计阶段推迟到实现阶段。

**Source（源头）**：ADR-001（`package-flow-kit.sh` 为唯一打包入口，Part A-G 每段有明确的目录覆盖范围）。DESIGN 作为设计文档，其职责之一就是确认新增文件是否落在既有打包覆盖范围内，而非将此类验证留到实现时"确认"。CONTEXT.md 禁动清单亦明确 `package-flow-kit.sh（打包脚本核心逻辑，改动影响分发流程）`，更应该在 DESIGN 阶段就把覆盖问题问清楚。

**Consequence（后果）**：若 Part D 实际不覆盖 `hooks/stop/lib/`（概率低，因该目录已有 11 个 lib 文件被正常打包），则 `banner.sh` 不会被纳入分发包。运行时 `flow-kit-resume.sh` 的 `source hooks/stop/lib/banner.sh` 失败，触发 R4 的 graceful-fail 路径——SessionStart 无法展示 resume banner，用户丢失跨 session 恢复上下文。虽非致命崩溃，但属于可预防的功能退化。

**Remedy（修补）**：在 DESIGN 中追加一段显式验证（而非"需确认"），具体做法：grep `package-flow-kit.sh` Part D 段中 `hooks/stop/lib/` 的引用（cp/rsync 指令），确认其覆盖方式（通配 `hooks/stop/lib/*` 或显式文件列表），将结果写进 R5 的缓解列。示例：
```
R5 缓解（修正后）:
- BW03: package-flow-kit.sh Part F 通配 `flow-kit-bundle/test/*` 已验证覆盖新测试文件（grep 确认）。
- BW01: package-flow-kit.sh Part D 已验证通配覆盖 `hooks/stop/lib/*`（grep 确认），banner.sh 自动纳入 —— 无需额外注册。
```

---

### 🟢 R2 · BW03 同步方向不处理目标目录中孤立文件

**Symptom（症状）**：DESIGN.md §2 BW03 数据流中标明的同步命令是 `cp -r test/*.bats flow-kit-bundle/test/`，这只会新增/覆盖文件，不会删除 `flow-kit-bundle/test/` 中存在于目标但已从源移除的孤立 `.bats` 文件。

**Source（源头）**：D5 决策单向同步 `test/ → flow-kit-bundle/test/`，专注避免双向冲突，但未覆盖"源删除 → 目标残留"的维护场景。`diff -rq` 可检测此类残留（`make check` 会报不同步），但修复动作 `make test-sync` 无法消除。

**Consequence（后果）**：若 `test/` 中某 `.bats` 文件被重命名或删除，`flow-kit-bundle/test/` 会残留旧文件。`make check` 持续报错，用户运行 `make test-sync` 后发现问题依然存在，陷入"检测报错但修复无效"的困惑循环。实际影响低——场景触发频率低，且残留文件不影响测试执行（bundle 中该文件不会被 bats 自动发现）。

**Remedy（修补）**：两种可选方案：(a) 同步前先清空目标目录 `rm -f flow-kit-bundle/test/*.bats && cp test/*.bats flow-kit-bundle/test/`；(b) 用 `rsync --delete test/ flow-kit-bundle/test/` 替代 cp。方案 (a) 更简单且不引入新依赖。若选择不做（因为场景罕见），应在 DESIGN §5 增加一条风险记录说明此已知局限。

---

### 🟢 R3 · D1 依存的 ADR-003 未显式引用

**Symptom（症状）**：DESIGN.md §1 D1 的"选择理由"写道 `ARCHITECTURE.md §2.1 明确此为三者共用层`，指向模块文档，但未引用 ADR-003（Hook 系统模块化架构，明确 SessionStart + PreToolUse 共享 `hooks/stop/lib/` 层）。DESIGN §4 声明"本次不涉及不可逆架构决策"，但 D1 的选址决策直接依赖 ADR-003 的既有架构判断。

**Source（源头）**：ARCHITECTURE.md ADR-003 状态为 accepted，决定 "SessionStart + PreToolUse 共享同一 lib 层"。ARCHITECTURE.md § 前言定义 `ARCHITECTURE.md` 为 structure 层、ADR 为不可逆决策清单。DESIGN 引用结构层文档合理，但若 ADR-003 未来被 deprecate/supersede，仅引用 §2.1 的读者可能不知道 D1 依赖的是不可逆决策还是可变的模块描述。

**Consequence（后果）**：纯文档追溯性问题。ADR-003 若未来被推翻（推翻成本被评为"高"），D1 的选址逻辑需重新评估，但缺少 ADR 引用会让这一追溯链断裂。当前无实际风险——ADR-003 远未被推翻。

**Remedy（修补）**：D1 的"选择理由"补充 ADR 引用：
```
hooks/stop/lib/ 已是 SessionStart + Stop + PreToolUse 的共享 lib 目录（11 个既有 lib），
ARCHITECTURE.md §2.1 + ADR-003 明确此为三者共用层。
```

---

### 🟢 R4 · BW02 格式统一后下游消费者影响未经评估

**Symptom（症状）**：DESIGN.md §2 BW02 描述了 CHANGELOG.md 格式变更前后的结构差异，但未评估是否有任何工具/脚本/hook 解析或消费 CHANGELOG.md 的内容（如 changelog 自动提取、LESSONS 汇总脚本、health 报告生成）。D4 的"取舍代价"仅提及新读者理解成本，遗漏了工具兼容性。

**Source（源头）**：AC-4 的验证方式仅限于 `grep -c` 检查表头行消失 + 条目数一致。若存在以旧表头行为锚点的解析脚本（如依赖 `| 日期 | Change ID |...` 表头行后紧跟条目行的消费逻辑），格式统一会静默破坏此类解析。

**Consequence（后果）**：当前无已知工具解析 CHANGELOG.md（CONTEXT.md 禁动清单和既存抽象索引中均无此类工具注册）。实际风险极低。但 DESIGN 应显式声明"已确认无下游消费者"而非默认假设没有。

**Remedy（修补）**：DESIGN §5 追加一条轻量风险记录或 D4 的取舍代价列补充一句话：
```
已确认：全仓 grep 无脚本/hook 以旧 CHANGELOG 表头行为解析锚点，
格式统一不破坏任何既有工具链。
```

---

**Verdict**: pass

不存在 🔴 Critical 发现。四条发现中一条 🟡 Major（打包覆盖验证递延）、三条 🟢 Minor，均不构成阻塞。DESIGN 整体质量良好：D1-D6 六个决策均有备选对比和取舍代价分析；§0.5 既有架构对齐做得细致（触碰模块清单 + 禁动清单 + 沿用对照表）；R1-R6 风险识别覆盖了实现风险、上线风险和长期债务三个维度。三条 BW 均为既有模式的增量应用，不引入新抽象，不撞跨模块契约。
