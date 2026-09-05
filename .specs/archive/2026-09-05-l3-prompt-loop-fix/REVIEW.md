# REVIEW · l3-prompt-loop-fix

- **基线**：07eaf08…HEAD（6 commits：ae93163 / 3b70030 / b7e6cf9 / 12146a8 / 2420a5a / 5a2e542）
- **diff 面**：19 文件 +1965/−79——源 `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`（157→367 行）+ 部署副本 ×2（.claude/hooks、~/.claude）+ dist ×2（gitignore 本地再生）+ 测试双源（bats 8→40 用例 + 7 fixtures ×2）+ 漂移存档 patch
- **审查路径**：B（内置 6 维诊断；diff 聚焦单 lib + 测试，L2/L3 双层独立审查兜底）

---

## A. Spec 合规（AC-1~AC-7）

| AC | 实现位点 | 测试锚（TEST.md §1.1） | 判定 |
|---|---|---|---|
| AC-1 反馈段先于工件 + 满载存活 + 总输出≤cap | l3-prompt.sh:250-367（段序重排 + jq 指令前置 + `_l3_utf8_head_stream` 总封顶 :366） | T04「AC-1 ①」+ T05「AC-1 assembly ordering」 | ✅ |
| AC-2 checklist 对齐归档约定 | :359（D6 措辞：T0x-SUMMARY + CHANGELOG 标项目级） | T04「D6 checklist 措辞」固定行锚 | ✅ |
| AC-3 archive 布局注入成功 | :326-331（D5：`*/.specs/archive/*` → dirname×3；if/else 保 sed 提取契约） | T04「D5 双位点」CHANGELOG+LESSONS 双断言 | ✅ |
| AC-4 单行摘要 + 配额 (+k more) | :89-166（提取器）+ :175-245（600B 配额折叠 + 200B 响应） | T02×7 + T03 配额 + T05 e2e + T05fix ②③ | ✅ |
| AC-5 无响应段→标注未响应 + 摘要仍注入 | :175-245 象限矩阵 | T03「AC-5 no-response」+ T05 溢出 e2e | ✅ |
| AC-6 四副本 md5 一致 + 全局 cmp | T06 同步（漂移先存档 sync-drift-20260904.patch 再覆盖） | T06「AC-6 four copies」+「global cmp-identical when present」 | ✅ |
| AC-7 缺失/源空→静默 | :226（`[ -z … ] && return 0` 单行收敛） | T02「empty/verdict-only/missing」+ T05「AC-7 e2e」 | ✅ |

- **范围蔓延**：无。out-of-scope 项逐一核验：Claim 3（29 号 Gate 2 fail-open）未触碰 ✓；prompt 侧段头标准化未触碰 ✓；v2 项（smart_truncate 复用/env 配额）未实现 ✓
- **架构对齐**：禁动清单核验——`l3-review.sh` 仅原样调用（:79-81/:102-103 未改）✓；`fk_resolve_api_credentials` 未触碰 ✓；`.done` 写权未变 ✓；调用方 `l3-review.sh` 零改动（D1 段序在 build_prompt 内实现，生产拼接方不变）✓
- **设计偏差**（已记录于 T04-SUMMARY）：jq 模板指令前置——AC-1① 总输出≤cap 与 JSON 契约存活的联合约束所需，属 REQUIREMENT 隐含要求的实现自由度

## B. 代码质量（6 维衰退风险 · 路径 B）

**R1 Cognitive Overload — 🟢 F1**：`_l3_extract_prior_findings`（l3-prompt.sh:89-166，78 行）在单函数内承载 L2 markdown 行文法 + L3 围栏 JSON 文法双状态机。界面窄（review_md → 单行列表，深模块达标）、7 fixtures 全测，但双文法拆分（`_l3_parse_l2_lines` / `_l3_parse_l3_json`）可进一步降载。**Severity**: 🟢 Minor | **Source**: Ousterhout《A Philosophy of Software Design》Ch.4 deep module（达标）+ Fowler《Refactoring》Long Function（临界）| **Consequence**: 后续新增第三种审查文件格式时改动面集中 | **Remedy**: M10 登记，下一 l3 域 change 顺手拆

**R2 Change Propagation — 🟢 F4**：l3-prompt.sh 五副本同步（bundle 源 / .claude 本地 / dist×2 / ~/.claude 全局）为结构性负担。已由 bats AC-6（仓内四副本 md5 唯一）+ cmp 存在性门控 + `make check-test-sync` 工具化守护；dist 属 gitignore 构建再生（package-dsh-plugin.sh）。**Severity**: 🟢 Minor | **Source**: Fowler《Refactoring》Shotgun Surgery（已被同步门控收敛）| **Consequence**: 误改部署副本时 bats 即刻红 | **Remedy**: M13 登记（保持「只改 bundle 源」纪律）

**R3 Knowledge Duplication — 🟢 F2**：T05 端到端用例复刻 `l3-review.sh:81-104` 组装逻辑作期望生成器——影子实现随实现漂移风险（phase 5 L3 已发现，M9 登记；T04 手写期望断言为独立纠错层）。**Severity**: 🟢 Minor | **Source**: Meszaros《xUnit Test Patterns》Fragile Test / Obscure Test | **Consequence**: 实现演化而复刻未同步时 e2e 锚定影子 | **Remedy**: 引用 M9（7-integration triage），不重复登记

**R4 Accidental Complexity — 🟢 F3**：:354 `echo -e "$artifact"` 解释工件内容中的字面 `\n`/`\t` 序列——含此类字面量的 CHANGELOG/REQUIREMENT 会被改写（低概率输入、无实际命中：现有 41KB CHANGELOG 无反斜杠序列）。UTF-8 边界扫描（:36-82 od 逐字节 + lead/continuation 窗口）复杂度不可约（字节语义 × 多字节安全），已封装 2 helper + 7 用例。**Severity**: 🟢 Minor | **Source**: Hunt《The Pragmatic Programmer》Tip 8 DRY 之反例外的「巧合编程」边界 | **Consequence**: 极端输入下 prompt 内容失真 | **Remedy**: M12 登记（改 awk/printf 组装）

**R5 Dependency Disorder — 无发现**：l3-prompt.sh 为叶子 lib（仅被 l3-review.sh source），提取器纯文件读取零新依赖；依赖流单向 ✓

**R6 Domain Model Distortion — 无发现**：四象限矩阵（findings×响应）+ 静默边界忠实建模审查反馈域；REQUIREMENT/DESIGN/实现三者语义一致 ✓

## C. UI 视觉审查

N/A（非前端项目）

## D. 综合评估

```
verdict: pass

🔴 Critical:  （无）
🟡 Important: （无）
🟢 Minor:
  F1 · R1 Cognitive Overload · lib/l3-prompt.sh:89-166 — 提取器双文法单函数（→ M10）
  F2 · R3 Knowledge Duplication · test/test_l3_pipeline_fix.bats T05 e2e — 组装复刻影子实现（→ M9 引用）
  F3 · R4 Accidental Complexity · lib/l3-prompt.sh:354 — echo -e 对字面转义序列的失真边界（→ M12）
  F4 · R2 Change Propagation · 五副本同步结构性负担（→ M13）
```

- **动态门禁判定（AC-9）**：spec 合规 critical 项 0 失败 ✓；brooks 🔴 0 ✓；🟡 0（无需 warn 记录）；spot-check 未触发（verdict=pass 且无 🔴）
- **修复任务**：0 条（无 🔴/🟡）——不回 4-dev
- **回归证据**：全量 800 pass + 1 既有 skip / 0 fail；`make check` 全绿（shellcheck + 双源 diff）

---

## 终态对账（归档补注 · L2 R1）

正文「800 pass + 1 skip」为 phase 6 写入时点值；phase 6 fix-loop（T06fix）与 phase 7 复核后**终态 = 803 ok / 0 fail / 1 既有 skip**（+T05fix×1 已计入 +T06fix×2）。CHANGELOG/PROGRESS/UAT 记载的 803 为终态口径，静态 grep 821 为 @test 声明数（含条件 skip 的声明体），以 TAP 实跑为准。
