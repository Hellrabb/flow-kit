# REQUIREMENT: auto-checkpoint 收尾——BW01/02/03 三项品质提升

- **Change ID**: `checkpoint-polish`
- **关联**: `@.specs/checkpoint-polish/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为测试开发者，我想在 bats 测试中直接 source 真实的 resume banner 生成函数，以便 AC-6 测试用真实输出验证而非 jq 模拟提取。
- **US-2**：作为项目维护者，我想 `.specs/CHANGELOG.md` 全文件使用统一格式，以便新条目追加时可预测、可解析。
- **US-3**：作为开发者，我想 `test/` 和 `flow-kit-bundle/test/` 的测试文件自动保持同步，以便修改一处后不必手动 `cp`。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · BW01 — 抽取 banner 生成函数

- **Given** `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh` 的 banner 构建逻辑（L201-L254）当前以内联方式嵌入主脚本
- **When** 将 banner 构建逻辑抽取为独立 sourceable 函数（如 `build_resume_banner()`），放入可 source 的 lib 文件
- **Then** `flow-kit-resume.sh` source 该 lib 后调用函数，SessionStart hook 输出的 banner **逐字符**与重构前一致
- **验证方式**: 运行重构前的 `flow-kit-resume.sh` 与重构后版本（传入相同 `.flow-active` 模拟数据），`diff` 比较二者 stdout；或通过 bats 测试对比

### AC-2 · BW01 — bats 测试调用真实函数

- **Given** AC-1 的 sourceable 函数已就位
- **When** 在 bats 测试中 `source` 该 lib 并调用 `build_resume_banner()`，传入模拟的 `.flow-active` 数据
- **Then** 测试可断言 banner 输出包含指定的 change_id / phase / goal / interrupt 字段，且格式与 SessionStart 实际输出一致
- **验证方式**: `npx bats test/test_resume_banner.bats`（或对应测试文件）全部通过

### AC-3 · BW01 — 全量回归不退化

- **Given** BW01 重构完成
- **When** 运行 `npx bats test/`
- **Then** 全量 bats 测试 0 fail（与重构前一致）
- **验证方式**: `npx bats test/` 退出码 0

### AC-4 · BW02 — CHANGELOG.md 格式统一

- **Given** `.specs/CHANGELOG.md` 当前混存两种格式：顶部单行 pipe 格式（`| 日期 | id | 摘要 | LESSONS |`）+ 下部标准表头格式（`| 日期 | Change ID | 摘要 | LESSONS |` 带独立表头行）
- **When** 将所有条目（含原标准表头格式段）统一为紧凑单行 pipe 格式，消除独立表头行，保留所有现有条目数据
- **Then** 全文件无独立表头行（`grep -c '^| 日期 | Change ID | 摘要 | LESSONS |$' .specs/CHANGELOG.md` 返回 0），所有条目行符合紧凑 pipe 格式
- **验证方式**: `grep -c '^| 日期 | Change ID | 摘要 | LESSONS |$' .specs/CHANGELOG.md` 返回 0；`grep -c '^| 202[0-9]' .specs/CHANGELOG.md` 前后一致

### AC-5 · BW02 — 格式统一后条目不丢失

- **Given** AC-4 格式统一完成
- **When** 统计统一前后的条目数
- **Then** 条目数量不变（每行 `| 日期 |` 对应一条记录，数量一致）
- **验证方式**: `grep -c '^| 202[0-9]' .specs/CHANGELOG.md` 前后一致

### AC-6 · BW03 — 双源测试自动同步

- **Given** `test/` 和 `flow-kit-bundle/test/` 各自包含 bats 测试文件，当前手动 `cp` 保持同步
- **When** 实现 Makefile target `make test-sync` 并在 `make check` 中集成调用
- **Then** 运行同步命令后 `diff -rq test/ flow-kit-bundle/test/` 无差异输出
- **验证方式**: 修改 `test/` 下某文件 → 运行同步 → `diff -rq test/ flow-kit-bundle/test/` 退出码 0

### AC-7 · BW03 — `make check` 检测不同步

- **Given** AC-6 同步机制已就位
- **When** `test/` 和 `flow-kit-bundle/test/` 内容不一致（模拟开发者改了一处忘同步）
- **Then** `make check`（或 `make test-sync-check`）检测到差异并以非零退出码报错
- **验证方式**: 手动制造差异 → `make check` 非零退出 → 运行同步 → `make check` 零退出

---

## 范围切分

### v1（本次必做）

- BW01：抽取 `flow-kit-resume.sh` banner 逻辑为 sourceable 函数 + 测试可调用
- BW02：统一 `.specs/CHANGELOG.md` 为紧凑单行 pipe 格式
- BW03：`test/` ↔ `flow-kit-bundle/test/` 自动同步机制（Makefile target `make test-sync`）
- 全量 bats 不退化（407 测试 0 fail）

### v2（下一轮考虑，不本次）

- BW04：`install_hooks.sh` 重复代码去重——等第三个 PreToolUse hook 出现时一并处理
- CHANGELOG.md 自动生成（从 git log 提取）

### out（永远不做）

- 测试框架迁移（bats → 其他框架）——bats-core 已是项目标准
- CHANGELOG.md 改为 JSON/YAML 结构化格式——markdown 可读性优先

---

## 非功能性需求

- **性能**: 无（banner 函数调用 < 10ms，session start 不增加可感知延迟）
- **可访问性**: 无
- **安全**: 无新增安全风险（纯重构 + 格式统一 + 文件同步）
- **兼容性**: BW01 重构后 SessionStart hook 输出必须逐字符不变；BW03 同步方案必须兼容现有 `make check` / `make test` 流程
- **可观测性**: 无
- **健壮性**: BW01 lib 文件缺失时 `flow-kit-resume.sh` 应以非零退出码 + 可读错误信息终止；BW03 同步失败时 `make test-sync` 应以非零退出码终止、不静默覆盖目标文件；`make check` 检测不同步时应在 stderr 提示用户运行 `make test-sync`

## 依赖与假设

- **依赖**：
  - `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`（BW01 重构源）
  - `.specs/CHANGELOG.md`（BW02 格式统一源）
  - `test/` + `flow-kit-bundle/test/`（BW03 双源目录）
  - `Makefile`（BW03 集成 `make check`）
- **假设**：
  - BW01 抽取的 lib 文件放在 `flow-kit-bundle/hooks/session-start/lib/` 或 `flow-kit-bundle/lib/` 下，与现有 lib 组织一致
  - BW02 统一为紧凑单行 pipe 格式（与 CHANGELOG.md 顶部新条目格式一致），不引入新表头
  - BW03 优先 Makefile target（`make test-sync`），不引入新依赖工具
  - 全量 bats 基准为 407 测试 0 fail（`make test` 实测 @ 2026-07-10）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
