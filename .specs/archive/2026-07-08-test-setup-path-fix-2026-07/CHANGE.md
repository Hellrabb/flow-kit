# CHANGE: 修 10+ 测试 setup 路径缺 flow-kit-bundle/ 层 + Makefile test 管道漏洞（让 30+ 假绿测试真绿）

- **Change ID**: test-setup-path-fix-2026-07
- **创建日期**: 2026-07-08
- **路径建议**: pipeline goal --from 1（自主 1→7）· 纯 bug 修复，测试基础设施
- **状态**: draft

---

## Why（为什么做）

brooks-sweep + health-cleanup-2026-07-08 发现 **TD-012**：10+ 测试文件 setup 路径缺 `flow-kit-bundle/` 层（如 `$(dirname "$BATS_TEST_FILENAME")/../hooks/...` 指向不存在的 `<repo>/hooks/`，而 hooks 在 `flow-kit-bundle/hooks/`）→ `source ... 2>/dev/null || true` 静默吞错 → `fk_validate_done_marker` 等函数未定义 → 30+ 测试 BW01 127 fail。

**假绿根因（L-027）**：health-fix-2026-07-08 的"169→0 全绿"用 `bats test/ | tail` 验证，**管道 exit code 是 tail 的（0），bats 实际 exit 1 被掩盖** → 误判全绿。`make test`（直接用 bats exit 判定）一直 fail。这动摇了 health-fix-2026-07-08 成果的可信度，**必须修复让测试真绿**，否则整个测试套件不可信。

受影响文件（10+）：test_correction_file / test_dual_review_merge / test_flow_active_integrity / test_l2_l3_granular_gate / test_l2_l3_fix_compliance / test_l3_async_dispatch / test_checkpoint / test_setup_integrity / test_smoke_syntax / done-skip / l2-detect / l3-truncation / phase-resolution.bats

## What（做什么）

1. **修 10+ 测试 setup 路径**：改用**位置无关**（向上查找目标 lib，参照 health-cleanup T01 的 `test_package_flow_kit.bats` 根治模式）或正确的 `flow-kit-bundle/` 相对路径。逐个文件确认 source 目标（done-validation.sh / l3-review.sh / common.sh / correction-file.sh / checkpoint-lib.sh 等）
2. **修 Makefile test target 管道漏洞**：`line 12 npx bats test/ --formatter tap 2>&1 | tail -3` 的 exit code 被 tail 吃掉 → 加 `set -o pipefail` 或确保判定行（line 13 已直接用 bats exit）不受展示行影响。**复核 make test 判定逻辑**
3. **让 30+ 假绿测试真绿**：修路径后 source 成功 → 函数定义 → `run` 不再 127 → 测试真正验证
4. **验证 health-fix-2026-07-08 的"169→0"**：修路径后重跑全量，看实际通过率（可能暴露被假绿掩盖的真 fail）

## 影响面

- [ ] 影响 `REQUIREMENT.md`（否·纯 bug 修复）
- [ ] 影响 `DESIGN.md` / 引入新 ADR（否·0.4 未命中，无架构变更）
- [ ] 影响现有 AC（否）
- [ ] 影响数据模型 / 迁移（否）
- [ ] 影响外部 API 兼容性（否）
- [x] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **TD-011 gate:68 真 bug**：独立 change `refactor-independent-review-gate`（依赖本 change 让测试真绿后才能可信验证 gate 修复）
- **TD-008 l3-review 574 行拆分**：暂不做（用户决定）
- **shellcheck 117 warning/info**：记 TECH-DEBT，非本次
- **TD-004/005 prompt/jq 重复**：独立重构 change

## 验收线（粗粒度）

1. `make test` 全绿（414 测试 pass，**无 BW01 exit 127**）
2. `make check` 通过（test + lint + validate + sync 全门禁）
3. 30+ 假绿测试真绿：`fk_validate_done_marker` / `fk_independent_review_gate_active` / `write_correction_file` / `truncation` / pipeline mode / NFR 等
4. `make check-test-sync` 双源一致（test/ ↔ flow-kit-bundle/test/）
5. 复核 health-fix-2026-07-08 实际通过率（修路径后真实数字）

## 风险与未知

- **逐文件路径修法**：每个测试 source 的目标 lib 不同，需逐个确认正确路径（不能批量替换——health-cleanup T01 的双源矛盾教训）
- **可能暴露真 fail**：修路径后 source 成功，之前因函数未定义被掩盖的真 bug 会显现（如 fk_validate_done_marker 的实际逻辑）——这是好事（让测试真发挥作用），但可能增加修复量，需在 4-dev/5-test 迭代处理
- **双源一致性**：test/ 与 flow-kit-bundle/test/ 镜像，修一处要同步另一处（check-test-sync 强制）。位置无关修法双源都正确，是最优解
- **Makefile 改动**：确保不破坏 check 链（test→lint→validate→sync）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
> **本 change 走 pipeline goal --from 1 自主推进**（低风险，auto_advance=true）。
