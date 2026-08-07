# T12-SUMMARY · 双源同步 + 全量回归 + make check + AC-6 红线验证

Change：`l2l3-cross-platform`
任务：T12（TASK.md 定义块）· 2026-08-07

## 结论（TL;DR）

- ✅ 双源同步完成（`make test-sync`，exit 0），两个新 .bats 已镜像到 `flow-kit-bundle/test/`，`make check-test-sync` diff 零差异。
- ✅ AC-6 红线实质成立：**token 值模式（`sk-[A-Za-z0-9]{8,}`）全产物零命中（exit 1）；env 名模式在非审查者运行时产物零命中（exit 1）**。
- ⚠️ **全量回归 739/740**：1 个失败 `test_l3_async_dispatch.bats AC-4a`——**由本 change 自身引入**（T04 改 l3-review.sh 派发 box 时把 header 文本「L3 外部模型审查未完成」顺手改成「L3 审查未完成」，非 spec 要求），非 pre-existing。按任务边界约定（不静默改 write_files 之外文件）**上报主 agent，未自行修复**，给出最小修复建议。
- ⚠️ `make check` 因此被同一失败阻塞（test 前置步骤 739/740），其余三个 gate（lint / check-validate / check-test-sync）**独立全绿**。

---

## 1. 双源同步（make test-sync）

```bash
$ make test-sync
🔄 make test-sync: test/ → flow-kit-bundle/test/ ...
✅ test 双源已同步
=== exit: 0

$ ls flow-kit-bundle/test/test_l2_dispatch_mode.bats flow-kit-bundle/test/test_l3_credential_resolution.bats
flow-kit-bundle/test/test_l2_dispatch_mode.bats
flow-kit-bundle/test/test_l3_credential_resolution.bats
```

走 Makefile 既有机制（`test-sync` 目标 = `cp test/*.bats flow-kit-bundle/test/`），非手动 cp。

## 2. 全量回归 npx bats test/

```bash
$ npx bats test/   # 740 用例：739 ok / 1 not ok
...
ok 739 CF-02: write_compliance_correction merges with existing + dedup
ok 740 CF-03: clear_compliance_correction removes the file
=== bats exit: 1   （单文件失败导致退出 1）

$ npx bats test/test_l3_async_dispatch.bats   # 隔离复现，确认与运行顺序无关
1..9
not ok 1 AC-4a: l3_dispatch_prompt outputs box header with phase and gate_val
# (in test file test/test_l3_async_dispatch.bats, line 39)
#   `[[ "$output" == *"L3 外部模型审查未完成"* ]]' failed
```

**失败详情（唯一失败）**

- 文件：`test/test_l3_async_dispatch.bats`（**既有 tracked 文件**，本 change 未改它）
- 用例：`AC-4a: l3_dispatch_prompt outputs box header with phase and gate_val`（L36-42）
- 断言：`[[ "$output" == *"L3 外部模型审查未完成"* ]]`（L39）
- 根因：`flow-kit-bundle/hooks/stop/lib/l3-review.sh` 的 `l3_dispatch_prompt` DISPATCH_EOF 模板 header 行被本 change 改动：

```diff
-║  ⚠️ L3 外部模型审查未完成（阶段 ${phase} · gate_config=${gate_val}） ║
+║  ⚠️ L3 审查未完成（阶段 ${phase} · gate_config=${gate_val}） ║
```

- **证据链**：
  - `git show HEAD:.../l3-review.sh | grep -c '外部模型审查未完成'` → **1**（HEAD 存在旧文本）→ HEAD 下该测试通过。
  - 本 change 工作区删除该串 → 测试失败。**即：回归由本 change 引入，非 pre-existing**。
  - spec 全文（REQUIREMENT.md / DESIGN.md / TASK.md）**无任何**「审查未完成」文本变更要求——T04 任务 action 只要求 box 双模式分支 + 边框对齐 + 文件头 env 注释，文本改动属 T04 顺手修改（未经授权）。
  - 反向检查：全仓测试文件（test/ + flow-kit-bundle/test/）**只有** `test_l3_async_dispatch.bats` 断言该 header，且断言的是**旧文本**；无任何测试断言新文本 → **恢复旧文本零破坏**。

**回归锚点 25/25（隔离运行）**

```bash
$ npx bats test/test_model_degradation.bats test/test_fk_resolve_model.bats test/test_independent_review_model.bats
1..25    # 25/25 ok，exit 0
```

**新文件 24/24（隔离运行）**

```bash
$ npx bats test/test_l3_credential_resolution.bats test/test_l2_dispatch_mode.bats
# 24/24 ok（17 + 7），零 heredoc 警告，exit 0
```

## 3. AC-6 红线双 grep 断言

### ① token 值模式（`sk-[A-Za-z0-9]{8,}`）扫全部产物（含审查报告）

```bash
$ grep -rsE 'sk-[A-Za-z0-9]{8,}' .flow-active .specs/l2l3-cross-platform/INDEPENDENT-REVIEW-*.md flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null
（零输出）
=== exit=1   ✅ 零命中
```

### ② env 名模式只扫非审查者产物

```bash
$ grep -rsE 'FLOW_KIT_L3_(AUTH_TOKEN|BASE_URL)' .flow-active flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null
（零输出）
=== exit=1   ✅ 零命中
```

### verify 字面命令的实测行为（documented deviation）

```bash
$ grep -rsE 'FLOW_KIT_L3_(AUTH_TOKEN|BASE_URL)|sk-[A-Za-z0-9]{8,}' .flow-active .flow-active.correction .flow-active.interactive-ui-fix .specs/l2l3-cross-platform/INDEPENDENT-REVIEW-*.md flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null; echo $?
exit=2   # 13 行命中——全部是 INDEPENDENT-REVIEW-{1,2,3}.md 正文中的 env 名（引用 REQUIREMENT AC-3/AC-6 原文），sk- token 值零命中
```

```bash
$ grep -rsE 'FLOW_KIT_L3_(AUTH_TOKEN|BASE_URL)' .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null; echo $?
exit=2   # 零命中；exit 2 纯为缺失文件错误（.flow-active.correction / .flow-active.interactive-ui-fix 不存在）
```

**判定（按任务上下文预授权 + INDEPENDENT-REVIEW-2.md 自身分析）**：

- 审查报告中的 env **名**命中属**良性豁免**：审查者产物必须引用 REQUIREMENT.md AC-3/AC-6 的字面串（"降级提示必须包含 `export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN`"），**无任何 token 值伴随**（全范围 `sk-[A-Za-z0-9]{8,}` 零命中已证）。
- verify ② 的 exit 2 是缺失文件（`.flow-active.correction` / `.flow-active.interactive-ui-fix` 不存在 = 当前无 correction 活动，**absence 即最强证明**）触发的 GNU grep 错误码，非内容命中。
- 红线实质（任务原话）"**no token values anywhere in runtime artifacts, no env names in non-reviewer runtime artifacts**" → 两条都成立，实测 exit 1。

## 4. make check 全量门禁

```bash
$ make lint                → ✅ shellcheck: no errors found            (exit 0)
$ make check-validate      → ✅ 校验通过：298 项实际文件全覆盖，漏配 0 / 源缺失 0  (exit 0)
$ make check-test-sync     → ✅ test 双源一致                            (exit 0)
$ make test                → ❌ bats: some tests failed（739/740，即 §2 同一回归）  (exit 2)
$ make check               → ❌ 中止于 test 前置（Makefile:11 错误 1）      (exit 2)
```

`make check` 在 test 前置失败即中止（make 默认行为），lint/validate/diff 三项独立跑全部绿。

## 5. 其他观测

- **heredoc stderr 噪音（pre-existing）**：全量跑时 bats 输出约 48 行 `command substitution: 1 unterminated here-document` 警告（test_functions.bash:471）。来源定位：**tracked 既有文件** `test/test-is-git-commit-structural.bats`（隔离跑 23 条警告，exit 0，不影响结果）；本 change 两个新文件隔离跑**零警告**。属既有 stderr 噪音，不修（非本 change 范围）。
- `.flow-active.correction` / `.flow-active.interactive-ui-fix` 当前不存在（无 correction / 无 UI-fix 活动），`ls .flow-active*` 仅 `.flow-active`。

## 6. 修复建议（上报主 agent，T12 未越界修改）

最小修复（一行，零破坏已验证）：恢复 `l3-review.sh` DISPATCH_EOF header 行为 HEAD 原文：

```bash
git show HEAD:flow-kit-bundle/hooks/stop/lib/l3-review.sh | sed -n '/L3 外部模型审查未完成/p'
# ║  ⚠️ L3 外部模型审查未完成（阶段 ${phase} · gate_config=${gate_val}） ║
```

保留 T04 全部合法改动（`category: "unspecified-high"` 双模式分支 / 边框对齐 / 文件头 FLOW_KIT_L3_* env 注释）。修复后 `make check` 预期全绿。若主 agent 倾向更新测试断言为新文本，亦可（等价），但改 spec 未授权的运行时文本需先确认 T04 意图。

## 7. 6 维自检

- **R1 认知过载**：本任务零实现，纯执行验证——每个 gate 单命令 + 真实输出归档；根因定位用最小证据链（git show HEAD vs 工作区 diff + spec 全文 grep）。
- **R2 变更传播**：write_files 仅 `flow-kit-bundle/test/` 下两个镜像 .bats（经 make test-sync 产生，与 test/ 字节一致，check-test-sync 证实）。**未修改**任何 write_files 之外文件——包括发现 l3-review.sh 回归后（按任务边界约定上报不静默修）。
- **R3 知识重复**：AC-6 判定不重复实现逻辑——红线 = 两条 grep 的退出码事实 + 命中行逐条分类（13 行全部为审查报告 env 名引用，0 行 token 值）；未引入新断言逻辑。
- **R4 意外复杂度**：无新增抽象；对 verify 字面命令的缺失文件 quirk（grep -s 下缺失文件仍 exit 2）采用任务上下文预授权的"缺文件即无产物"语义，用既有路径实测红线上。为论证完整性保留字面命令实测记录。
- **R5 依赖混淆**：全部验证针对 repo 内路径（test/ / flow-kit-bundle/ / .specs/l2l3-cross-platform/ / .flow-active），不依赖安装副本或外部环境；bats 结果与隔离/全量一致，无顺序耦合。
- **R6 域命名**：T12-SUMMARY.md 位于 `.specs/l2l3-cross-platform/`（既有约定）；grep 模式与 REQUIREMENT AC-6 原文逐字一致；命令输出原样粘贴未润色。

## 8. 偏离记录

1. **verify 未全绿**（`npx bats test/` 739/740）：唯一失败为 T04 引入的 header 文本回归（§2），按任务约定上报，T12 不越界修复——修复建议见 §6。
2. **make check 未通过**：同一回归阻塞 test 前置；lint/validate/check-test-sync 三项独立全绿。
3. **verify 字面 grep ① 实测 exit 2 而非 1**：13 行命中均为审查报告 env 名（良性豁免，INDEPENDENT-REVIEW-2.md 自身预言的必然性），sk- token 值零命中——红线实质成立（§3 判定）。
4. **verify 字面 grep ② 实测 exit 2 而非 1**：零命中，exit 2 纯为 `.flow-active.correction`/`.flow-active.interactive-ui-fix` 缺失文件的 grep 错误码——absence 即零泄漏证明。
5. 无 commit（任务要求）；未动 write_files 之外任何文件。
