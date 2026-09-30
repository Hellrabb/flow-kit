# ADR-030: reference/ 可执行检查器豁免与「数据化解析」边界

- **状态**: Proposed（随 health-fix-2026-09c 落地后 Accepted）
- **日期**: 2026-09-29
- **关联**: health-fix-2026-09c DESIGN D1（C5/C11）· ARCHITECTURE.md §2.2 · TD-134

## 背景

ARCHITECTURE.md §2.2 规定 `flow-kit/reference/` 为纯文档目录，禁止 reference → 任何代码的依赖方向。但仓库现实：两个**可执行**检查器长期住在 reference/ —— `check-gate-sync.sh`（15KB，make check-gate-sync 判据承载）与 `check-path-privacy.sh`（61KB，make check-path-privacy 判据承载）。2026-09-29 巡检（C5/C11）实证 check-gate-sync 的解析对象取自 mock 而非生产 .sh，门禁「更绿不更红」；修复要求它读生产源（common.sh / SKILL.md / prompts），与 §2.2 文字冲突。

## 决策

1. **豁免正式化**：reference/ 允许存放「独立可执行的检查器脚本」，条件是：
   - 零 source 依赖（不 source hooks/stop/lib、不 source lib/）；
   - 只把生产代码/文档**当作数据（文本）读取**，不做代码级依赖；
   - 判据二值（rc=0 / rc≠0），fail-closed（解析失败 ≠ 通过）。
2. **数据化解析边界**：检查器从生产 .sh 提取契约（如 `fk_normalize_gate_val` 值域、gate_config 预设行）时，用文本提取（grep/sed/awk 定位 + 锚点注释），**不用** source。生产侧在关键契约处加锚点注释（如 `# contract: gate-values`）供提取器定位。
3. ARCHITECTURE.md §2.2 增补一行说明该豁免（本 change 7-integration 阶段同步）。

## 备选与理由

- **挪目录**（check-* → lib/ 或 tools/）：牵动 Makefile 两个 target、install 路径、dist 打包清单、bats 引用四面；churn 大且与「门禁判据随 reference 文档走」的既有直觉相反。
- **source common.sh 复用解析**：直接违反 §2.2 禁止方向，且把 hook 热路径 lib 拖进门禁依赖。

## 后果

- 正面：门禁与生产真源对齐（C5/C11 修复落地）；豁免规则成文，后来者不再「违例而不自知」。
- 负面：提取器对源码文本格式敏感（格式漂移须转红）；reference/ 不再「纯文档」，目录语义弱化——用 §2.2 增补行约束。
- 推翻代价：中（需挪目录 + 改 Makefile/install/dist 四面 + 豁免行删除）。
