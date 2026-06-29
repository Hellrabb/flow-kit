# REQUIREMENT: 消除 LESSONS.md 三条活跃技术债

- **Change ID**: `lessons-cleanup`
- **关联**: `@.specs/lessons-cleanup/CHANGE.md`、`@.specs/CONTEXT.md`、`@.specs/LESSONS.md`

---

## 用户故事

- **US-1 (L-013)**：作为 flow-kit 维护者，我希望归档脚本在归档完成后自动清理工作目录并扫描遗漏的未归档 change，以便 `.specs/` 目录保持整洁，不用手动发现和清理空壳或遗忘的归档。
- **US-2 (L-012)**：作为 flow-kit 打包者，我希望 `package-flow-kit.sh` 能自动校验其 staging 指令（Part A~F 的 cp/rsync）是否覆盖了 `flow-kit-bundle/` 的实际目录结构，以便结构变更后不会漏配导致 bundle 安装报缺文件。
- **US-3 (L-010)**：作为 flow-kit 开发者，我希望触发 1.8 破坏性变更协议后 bats 测试自动运行且 0 fail 才放行，以便破坏性操作不会在不知情的情况下破坏既有功能。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 归档完成自动清理工作目录

- **Given** 一个 change `test-demo` 已完成全部阶段（REVIEW✅、TASK 全 done、CHANGELOG 已记），且 PROGRESS.md 已确认写入 archive
- **When** 执行 7-integration 归档流程完成
- **Then** `.specs/test-demo/` 工作目录被删除（`test -d .specs/test-demo/` 返回非 0）
- **验证方式**: 创建临时 change → 跑完归档流程 → `test ! -d .specs/<id>/`

### AC-2 · 归档完成扫描未归档已完成 change

- **Given** `.specs/` 下存在一个已完成但未归档的 change 目录 `orphan-demo`（含 REVIEW✅ + TASK 全 done + CHANGELOG 已记），且该 change 不在 `archive/` 中
- **When** 任意一个 change 的 7-integration 归档流程完成
- **Then** 归档脚本输出一条警告，包含 `orphan-demo` 的 change-id 和"已完成但未归档"的提示
- **验证方式**: 创建孤儿 change → 归档另一个 change → `grep "orphan-demo"` 归档输出

### AC-3 · 打包校验检测漏配

- **Given** `flow-kit-bundle/` 下新增了目录 `flow-kit-bundle/new-module/`（含文件），但 `package-flow-kit.sh` Part A~F 的 cp/rsync 指令未覆盖 `new-module/`
- **When** 运行 `bash package-flow-kit.sh --validate`（或等效校验命令）
- **Then** 校验输出报错，指出 `new-module/` 未被任何 staging 指令覆盖，exit code 非 0
- **验证方式**: 临时加目录 → 跑校验 → `echo $?` ≠ 0 且 stderr 含 `new-module`

### AC-4 · 打包校验通过

- **Given** `flow-kit-bundle/` 的当前目录结构与 `package-flow-kit.sh` Part A~F 的 cp/rsync 覆盖范围一致（正常状态）
- **When** 运行打包校验命令
- **Then** exit code = 0，输出"校验通过"或等效确认
- **验证方式**: 在干净仓库跑校验 → `echo $?` = 0

### AC-5 · 1.8 协议触发后自动跑 bats

- **Given** 4-dev 阶段执行过程中触发了 1.8 破坏性变更协议（如修改了 `flow-kit-bundle/hooks/` 下的共享 lib）
- **When** 1.8 协议的确认步骤完成
- **Then** 自动执行 `npx bats test/`（或等效命令），并输出测试结果
- **验证方式**: 模拟触发 1.8 → 检查输出中是否包含 bats 测试摘要（"N tests, 0 failures"）

### AC-6 · bats 失败时阻止继续

- **Given** 1.8 协议触发后，`npx bats test/` 运行结果有 ≥ 1 个 failure
- **When** bats 测试完成
- **Then** 4-dev 流程暂停，输出"bats 测试失败，修复后再继续"类阻断提示，不进入下一步
- **验证方式**: 临时引入一个失败测试 → 触发 1.8 → 确认流程阻断

---

## 范围切分

### v1（本次必做）

- L-013：归档脚本加双向校验（清理工作目录 + 扫描未归档 change）
- L-012：`package-flow-kit.sh` 加 `--validate` 完整校验模式
- L-010：1.8 协议段加自动 bats 执行 + 失败阻断

### v2（下一轮考虑，不本次）

- L-013：独立的定期扫描脚本（cron / Makefile target），不依赖归档触发，周期性巡检 `.specs/` 卫生
- L-012：校验失败时自动建议修复补丁（如自动生成缺失的 cp 指令）
- L-010：1.8 后的回滚验证（确认 rollback 能回到破坏前状态，而非仅跑 bats）

### out（永远不做）

- 不引入外部 CI 系统（GitHub Actions / Jenkins 等）——那是 `quality-baseline` change 的事
- 不重构 `package-flow-kit.sh` 的 Part A~F 结构（仅在现有结构上加校验层）
- 不自动修复任何校验失败（L-012 校验只报错不自动改，人工确认后再修）

---

## 非功能性需求

- **性能**: 无（校验脚本在秒级完成，不涉及性能敏感路径）
- **可访问性**: 无（CLI 工具，无 UI）
- **安全**: 归档清理 `rm -rf .specs/<id>/` 必须在确认 PROGRESS.md 已入 archive 后才执行，防止误删（双重确认：先检查 archive 中存在该目录，再 rm）
- **兼容性**: 兼容 Bash 4.0+（与项目现有脚本基线一致）；bats 1.13.0（npx）；jq 1.6+
- **可观测性**: 所有校验命令输出到 stderr/stdout，exit code 明确（0=通过，1=校验失败，2=脚本错误）

## 依赖与假设

- **依赖**: `bats-core` 1.13.0（通过 npx）、`jq` 1.6+、`git`
- **假设**: 
  - `.specs/archive/` 目录结构不变（仍按 `<change-id>/` 组织）
  - `package-flow-kit.sh` Part A~F 的 staging 指令格式保持稳定（可 grep 解析）
  - 1.8 协议在 4-dev prompt 中的触发条件不变
  - `PROGRESS.md` 在归档前已由 7-integration 写入 archive 目录（当前流程已有此步骤，本次加校验不改变该假设）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
