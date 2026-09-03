# 独立审查 · 阶段 5

## L2 盲审

**Verdict 摘要**：pass（无 🔴 Critical；1 条 🟡 Important 需主 agent 在 task 内修复后复认）

### 交叉一致性核对（L-031 全仓锚点扫描）

- 锚点 `.goal.l{2,3}_default_model` / `FLOW_KIT_L{2,3}_DEFAULT_MODEL`：命中
  `dsh-flow-kit/lib/flow-state.js`、`flow-kit-bundle/hooks/stop/lib/common.sh`、
  `flow-kit-bundle/skills/flow/SKILL.md`、`test/test_fk_resolve_model.bats`、
  `flow-kit-bundle/test/test_fk_resolve_model.bats`、`dsh-flow-kit/test/flow-state.test.mjs`
  六处，字段名与五级链顺序一致，未发现 L-031 第 4 类漏改。
- 锚点 `.flow-active.correction` 类型串（l2-missing / l3-model-missing / state-integrity /
  foreign_state）：hooks（29/33 号）、`lib/correction-file.sh`、双侧 bats 与
  `flow-state.js` doctor 报告一致，无漏接线。

### 实测复现结果（本环境独立执行）

- `node --test dsh-flow-kit/test/*.test.mjs` → 20 tests / pass 20 / fail 0（实测 exit 0）。
- R1 回归断言真实存在于 `dsh-flow-kit/test/flow-state.test.mjs:148-154`：
  `assert.match(result.text, /L2 默认: deepseek-v4-lite/)`、
  `assert.match(result.text, /L3 默认: deepseek-v4-flash/)`、
  `assert.doesNotMatch(result.text, /L2 默认: \(未设置/)`、
  `✅ 已更新。` 计数 == 1。非 mock：tempProject 写真实临时目录、驱动真实
  `runFlowCommand` 文件 I/O。
- `make lint` → exit 0（shellcheck error 级 0 errors，实测）。
- `make check-test-sync` → exit 0（`diff -rq test/ flow-kit-bundle/test/` 空，实测）。
- `diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle` → 空输出（实测 exit 0）。
- `node --check dsh-flow-kit/lib/*.js` + `bash -n`（flow-kit-bundle/hooks、
  flow-kit-bundle/flow-kit 全量 *.sh）→ 0 失败（实测）。
- AC-4：`dsh-flow-kit/package.json` version=0.2.0，files 含
  vendor/skills/flow-kit/hooks/brooks-lint/docs（实测）。
- bats 全量：本环境无法执行（`bats` 未安装、apt 需 root、npm/网络不可达），故
  `770 ok / 0 fail` 仅做静态核验——`test/*.bats` 顶层 68 文件共 770 个 `@test`，
  与声明一致；子目录 `test/weak-model-robustness/`（8 个 `@test`）由非递归
  `bats test/` 排除，与声明口径自洽。

### 🟡 R1 · 定向回归计数「correction-hygiene 31」不可复现
**Severity**：🟡 Important
**Symptom**：`.specs/dsh-flow-kit-sync-2026-09/TEST.md:20`（同源
`dsh-flow-kit/VERIFY.md:102-103`）声明「correction-hygiene 31 ok / 31 项定向回归」。
实测 `test/test_correction_hygiene.bats` 仅有 10 个 `@test`；全部 *correction 命名文件
（test_correction_hygiene 10 + test_correction_file 10 + test-l2-first-correction 5）= 25；
加上 `test_flow_active_integrity.bats`（19）= 44。唯一凑出 31 的组合是
correction_hygiene(10)+flow_active_integrity(19)+install_dsh_platform(2)=31，但该组合
把语义无关的 install-dsh-platform 并入「correction-hygiene」，且同行的
`install-dsh-platform 2` 又单独列了 2，属双重计数/表述歧义。同行
`flow-active-integrity` 也未给出计数。
**Source**：AC-5 要求测试声明可机器复现（参考 REQUIREMENT.md AC-5、TASK.md T3/T5）；
本次审查重点「有无数字夸大、声明能否在仓库复现」。
**Consequence**：审查方按名重跑 `bats test/test_correction_hygiene.bats` 只能得到 10 ok，
与证据记录 31 对不上；补档文档的「可追溯」失效，后续审计会质疑整份 TEST.md 的计数可信度。
**Remedy**：把定向回归改为可复现的「命令 + 逐文件计数」，例如：
```markdown
- 定向：bats test/test_correction_hygiene.bats test/test_correction_file.bats     test/test_flow_active_integrity.bats test/test_install_dsh_platform.bats     test/test_fk_resolve_model.bats
  # 10 + 10 + 19 + 2 + 16 = 57 ok（或拆开逐文件注明 10/10/19/2/16）
```
若原意是 10+19+2=31，则必须删去「install-dsh-platform 2」的独立计数并改标签为
「correction-hygiene + flow-active-integrity + install-dsh-platform 31 ok」，消除歧义。
同步修正 `dsh-flow-kit/VERIFY.md:102-103` 的同源数字。

**Verdict**: pass

---


---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-03 16:21）

> 自动生成于 2026-09-03 16:21。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "TEST.md",
      "issue": "AC-6 的覆盖证据仅是 INTEGRATION.md 的摘要转述，没有可复现的断言/命令输出记录，且 AC-6 本身要求 profile 集成，测试矩阵中无对应自动化用例或可回放脚本。",
      "why": "若 profile 集成存在问题，现有矩阵无法在回归中捕获；UAT 第 3 步声称 pnpm install 后 dump-config 含 id: flow-kit，但没有给出该命令的完整执行记录、期望字段断言或退出码，审查者无法独立复现。",
      "fix": "补充 profile 集成用例（如 bundle-test 或 INTEGRATION.md 中的可执行命令+期望输出），并给出实际运行输出摘要和退出码；或将 AC-6 的验证降级为人工检查并在矩阵中明确标注。"
    },
    {
      "file": "TEST.md",
      "issue": "覆盖率口径段落承认没有行覆盖率工具，只用 AC 映射表和 bats 数量作为覆盖率口径；但 AC→测试映射不能证明覆盖率达到量化标准，且部分 AC 的映射粒度不足以保证分支覆盖。",
      "why": "审查要求包括覆盖率是否达标；当前矩阵无法回答分支/语句覆盖比例，且若没有工具是既有工程结构，也应在阶段交付中至少提供可量化的覆盖方式（如 node --experimental-test-coverage 或 c8），否则门禁无法衡量未覆盖风险。",
      "fix": "在测试矩阵中增加 node --test --experimental-test-coverage 的实测结果和覆盖率百分比（或等价工具），并把 AC→映射表与覆盖率数据合并，明确每个 AC 的覆盖基线。"
    },
    {
      "file": "TEST.md",
      "issue": "回归测试的定向逐文件结果 10+19+2+16=47 ok 与全量 bats 770 ok 的关系未说明：定向 47 是否属于全量 770？未提供的 4 个定向文件是否在其他地方选择或属于独立套件？",
      "why": "回归门禁的可复现性依赖于测试套件边界明确；若定向 47 属于全量 770，额外列出容易造成双重计数或覆盖错觉；若不属于，则缺少这 4 个文件的顶层套件归属说明，审查者无法确认回归范围。",
      "fix": "明确说明定向 47 是从全量 770 中抽取的子集还是补充套件，并给出选择这 4 个文件的理由；或在矩阵中只保留全量 770 结果和必要子集用途。"
    }
  ],
  "minor": [
    {
      "file": "TEST.md",
      "issue": "单元测试数量 20 与 AC 映射中的文件、用例数没有对应清单（flow-state.test.mjs 模型/doctor 各多少用例未列出）。",
      "why": "增加可审计性需知道每个 AC 对应的具体用例数和断言点；当前只有总数字和文件引用。",
      "fix": "列出 flow-state.test.mjs 中的 test 名称或每个 AC 的断言计数。"
    },
    {
      "file": "TEST.md",
      "issue": "UAT 第 4 步引用提交哈希 868f362/0981bd7 作为 gate 提交通过证据，但未给出这些提交与当前测试矩阵的对应关系或验证日志。",
      "why": "UAT 回放要求可复现；仅凭哈希无法独立验证其通过情况，且提交可能已被后续变更覆盖。",
      "fix": "补充 PreToolUse 全链的日志片段或命令+退出码记录；或将该步改为可重放的 CI 命令。"
    }
  ],
  "verdict": "pass",
  "summary": "测试矩阵 AC→测试映射和真实执行证据基本充分，且无 mock 屏蔽和回归遗漏的 critical 问题；主要不足是 AC-6 可复现性、覆盖率量化口径和定向/全量回归边界说明，建议补齐后增强门禁可信度。"
}
```

L3_artifact_hash: 0e5417da358b172d4bcfd5d36d3e81d3da1bc1b487ac8eda3f5472d7e669c368
