# 独立审查 · 阶段 5

## L2 盲审

### 🟡 R1 · AC-1 字符级一致性测试未自动化，与 1.2 节声明矛盾
**Symptom（症状）**：TEST.md 1.1 矩阵中 AC-1 的测试用例描述为 `bash -n banner.sh + bash -n resume.sh + diff 验证`。`bash -n` 仅执行语法检查，不验证 banner 输出内容；`diff 验证` 为手工步骤，未纳入任何 .bats 文件或 Makefile target。与此同时，TEST.md 1.2 节声称"全部 AC 均可自动化验证，无手工 UAT 场景"。
**Source（源头）**：阶段 5 审查标准"UAT 可执行：Given/When/Then 是否可脚本化（非手工步骤描述）"；REQUIREMENT.md AC-1 要求"逐字符与重构前一致"。
**Consequence（后果）**：AC-1 的字符级一致性回归无法通过 `make test` 或 CI 自动覆盖，依赖开发者记住手工执行 diff。若后续修改 banner 格式（如调整框线宽度），回归将逃逸自动化检测。
**Remedy（修补）**：二选一：(a) 将 diff 验证脚本化，写入 `test/test_resume_banner.bats` 为额外 @test（预先录制重构前输出为 golden file，测试输出 diff 退出码为 0）；(b) 在 TEST.md 1.1 矩阵中明确标注 AC-1 为"间接覆盖"（由 AC-2 的 7 条字段测试 + bash -n 语法检查共同保证），并修正 1.2 节措辞为"除 AC-1 的 diff 比对为手工验证外，其余 AC 均可自动化"。

### 🟡 R2 · make check 全链路验证缺口已标注但未闭合或纳入技术债
**Symptom（症状）**：TEST.md 回归保护表（L174）标注 `make check` 验证状态为"⚠️ lint/validate 未跑（仅验证 test-sync 不破坏）"。Makefile 中 `check` 链为 `test lint check-validate check-test-sync`（L64），BW03 修改了 `.PHONY` 行和新增了 `test-sync` recipe。lint 和 check-validate 子目标未验证即宣告回归安全，形成已标注但未处理的测试缺口。
**Source（源头）**：REQUIREMENT.md 非功能性需求"兼容性：BW03 同步方案必须兼容现有 `make check` / `make test` 流程"；TEST.md 1.5 自检 T1-T6 声明"0 项命中"，但未将 `make check` 链路验证缺口识别为测试覆盖风险。
**Consequence（后果）**：BW03 修改 Makefile 后，若 `.PHONY` 行格式或新增 recipe 的缩进意外影响 `lint` 或 `check-validate` 目标的解析，回归将逃逸检测，直到后续变更触发 `make check` 时才暴露。
**Remedy（修补）**：至少执行一次 `make lint && make check-validate` 并将结果记录到回归保护表，将状态从 ⚠️ 更新为 ✅。若 lint/validate 确实未跑，在 1.6 测试质量记事中加一条技术债条目："BW03 make check 全链路验证：lint/validate 子目标待补充执行验证"。

### 🟢 R3 · 测试数量基线突变（407→462）未在 TEST.md 中说明来源
**Symptom（症状）**：REQUIREMENT.md L110 声明全量 bats 基准为 407 测试 0 fail，TEST.md 报告全量测试数为 462。差异 55 条（远超本次新增的 7 条 test_resume_banner.bats）未在 TEST.md 中做任何解释。
**Source（源头）**：REQUIREMENT.md 范围切分 v1 明确"全量 bats 不退化（407 测试 0 fail）"；阶段 5 审查标准"回归安全：全量 bats 是否不退化"。
**Consequence（后果）**：审查者无法判断 462 测试中是否混入了非本变更引入的测试（可能来自其他已合并变更），回归基准的可审计性降低。不影响测试有效性，但影响变更粒度的追溯能力。
**Remedy（修补）**：在 TEST.md 1.3 节或回归保护表末尾加一行注解，说明 407→462 的增幅来源（如"增量来自 checkpoint、l3-gate、td-test-infra 等前序变更的新增测试"）。

### 🟢 R4 · AC-4/AC-5 CHANGELOG 验证未纳入 bats 测试套件，与 `make test` 解耦
**Symptom（症状）**：AC-4 和 AC-5 的测试用例均为 shell 一行命令（`grep -c 'header'` / `grep -c '^| 202[0-9]'` 计数比对），未写入任何 .bats 文件。TEST.md 1.1 矩阵将其类型标注为 "unit"，但实际执行方式与单元测试框架解耦。
**Source（源头）**：阶段 5 审查标准"UAT 可执行：Given/When/Then 是否可脚本化"；`make test` 目标仅执行 `npx bats test/`，不覆盖 CHANGELOG 格式验证。
**Consequence（后果）**：CHANGELOG.md 格式回归（如误加回独立表头行）不会被 `make test` 捕获，需开发者记住手工运行 AC-4/AC-5 的验证命令。风险较低——CHANGELOG 为人工维护文件，修改频率低。
**Remedy（修补）**：将 AC-4/AC-5 验证放入 .bats 文件（如 `test/test_changelog_format.bats`），或纳入 Makefile 的 `check` 链作为独立 target（如 `check-changelog`），与现有 `check-test-sync` 并列。

### 🟢 R5 · BW03 test-sync 健壮性边界用例缺失
**Symptom（症状）**：REQUIREMENT.md NFR 健壮性要求"BW03 同步失败时 make test-sync 应以非零退出码终止、不静默覆盖目标文件"。TEST.md 未包含对此路径的边界测试用例（如 `flow-kit-bundle/test/` 目录不存在时的退出行为、目标文件只读时的 cp 失败处理、磁盘空间不足场景）。1.4 边界/错误路径表仅覆盖 banner.sh 相关场景，未覆盖 test-sync。
**Source（源头）**：REQUIREMENT.md 非功能性需求·健壮性——三条明确要求（非零退出、不静默覆盖、stderr 提示）。
**Consequence（后果）**：test-sync 在异常条件下的行为未经自动化验证。当前 Makefile recipe 包含 `[ ! -d flow-kit-bundle/test ]` 目录检查（覆盖缺失目录场景）和 `cp ... || { echo ...; exit 1; }` 错误处理（覆盖 cp 失败场景），基础健壮性已内联于 recipe。边界用例缺失的剩余风险较低。
**Remedy（修补）**：可接受当前状态。如需加固：在 Makefile 中增加 `test-sync-self-check` target 验证异常路径，或在 1.6 测试质量记事中记录"test-sync 边界用例（目录只读/磁盘满）未覆盖，依赖 recipe 内联错误处理"。

### 🟢 R6 · shellcheck 手动执行与 `make lint` 集成声明之间存在未验证差距
**Symptom（症状）**：TEST.md 3.3 节展示 shellcheck 手动执行结果为 0 errors，同时声称"shellcheck 静态分析在 `make lint` 中覆盖"。但回归保护表 L174 明确标注 lint 未跑。这意味着 shellcheck 作为独立命令通过了，但其在 `make lint` 集成路径中的行为未被验证。
**Source（源头）**：TEST.md 内部矛盾——3.3 节声称 `make lint` 覆盖，回归保护表标注 lint 未跑。
**Consequence（后果）**：极低风险——shellcheck 已在新增文件上手动验证通过（0 errors），且 `make lint` recipe 对 shellcheck 的参数化调用与手动执行等效。不一致仅影响文档可信度，不影响实际安全质量。
**Remedy（修补）**：修正 3.3 节措辞为"shellcheck 手动验证通过（0 errors）；`make lint` 集成路径未在本轮测试中验证，但 recipe 逻辑等效"。

---

**Verdict**: pass
