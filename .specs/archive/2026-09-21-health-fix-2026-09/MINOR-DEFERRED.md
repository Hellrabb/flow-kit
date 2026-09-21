# Minor Findings Deferred · health-fix-2026-09

> 单一路径（ADR-017）。🟢 Minor 不入 fix loop，phase 7-integration 由用户 triage。
> 本 change 的 L2 盲审（阶段 1，2026-09-20）产出 🟢 2 条；🔴 3 条与 🟡 5 条**已当场修复**，见下方"已闭环"表。

## 延后 triage（🟢）

| # | Task | Finding ID | Description | Deferred reason | Date |
|---|------|------------|-------------|-----------------|------|
| M1 | TBD | L2-R9 | **NFR 性能的取证理由错位**：REQUIREMENT 非功能性需求段写「`make check` 被 **pre-commit** hook 调用」，实测 pre-commit 只跑 `make test`，`make check` 由 **pre-push** 调用（`.git/hooks/pre-push:8`）。结论（新门禁必须快）不变，但依据写错 | Minor（文档口径），不影响任何 AC | 2026-09-20 |
| M2 | TBD | L2-R10 | **AC-5 的 Given 对"5 个告警"的成因描述不完整**：实测 5 = vendor 4 个（`package-dsh-plugin.sh:54` 的 `chmod` 只作用于包顶层，vendor 副本未覆盖）+ `.claude/hooks` 1 个。REQUIREMENT 未区分这两类来源 | Minor（描述精度），AC-5 的 Then（告警归零）不受影响 | 2026-09-20 |

## 已当场闭环（🔴/🟡 均不入本文件）

| Finding | Severity | 处置 | 证据 |
|---|---|---|---|
| L2-R1 · AC-6 探针落在判据域之外（源不在 `DEST_ROOTS`） | 🔴 | AC-6 探针改打**镜像副本**；F3 范围收敛为「收窄判据 + 逐条指名」，不扩张判据域 | 实测镜像副本 5→6，判据可见 |
| L2-R2 · AC-2 断言 dist 与源一致不实 + 用 git 代理新鲜度（循环论证） | 🔴 | AC-2 去掉 git 代理；重建 dist 使 Given 真实成立 | `vendor ↔ bundle` 差异 = 0 |
| L2-R3 · `verify-claims` 基线不实（实为 11✅/2❌）+ 与本 change 强耦合 | 🔴 | 纳入 v1 的 **F6**：三处硬编码路径改 live→archive 解析；门数从 `Makefile check:` 动态推导 | `bash verify-claims.sh` → exit 0 · **13✅/0❌** |
| L2-R4 · AC-2/AC-4 无命令与期望输出；「4 个漏扫」实为 **7** | 🟡 | AC-4 补可执行脚本 + 路径级集合差（禁 basename 去重）；全文统一为 7；CHANGE.md 同步 | 路径级枚举：66 − 59 = **7** |
| L2-R5 · F5（理由注释 / US-4）无 AC 覆盖；F5 漏列 `package-dsh-plugin.sh` | 🟡 | F5 补 `package-dsh-plugin.sh`；由 AC-1/AC-2/AC-6 的失败信息质量间接覆盖 | DESIGN D2 载体 = `package-dsh-plugin.sh` |
| L2-R6 · `check-dist` 比对域未在需求定案（vendor/tarball/docs 无 AC） | 🟡 | 由 DESIGN D3 定案（含 `vendor/test/`）；需求侧经 AC-1「任一进入 dist 的源文件」泛化覆盖 | DESIGN D3 |
| L2-R7 · 「dist 缺失」分支无 AC/NFR 覆盖 | 🟡 | 由 NFR「兼容性」条目覆盖（工具缺失/产物缺失一律优雅降级 exit 0 + 提示） | DESIGN `:136/:230` |
| L2-R8 · NFR「不调用 npm/node」与 D2 落点冲突（`package-dsh-plugin.sh:19` 顶层 `node -p`） | 🟡 | 约束表述为「`--check` **模式**内不调用」；实现时 `--check` 须在 `node -p` 之前分流 | 待 TEST 阶段验证 |
