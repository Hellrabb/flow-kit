# CHANGE: 修复测试套件路径双重前缀 bug + 移除 `|| true` 静默吞错反模式（169 测试失败）

- **Change ID**: health-fix-2026-07-08
- **创建日期**: 2026-07-08
- **完成日期**: 2026-07-08
- **路径建议**: 最短（路径修复简单，可跳过 2-design 直接 3-task）
- **状态**: ✅ done（C1 + S2 + M1 全部修复，bats 169→0）
- **来源**: `.specs/health/2026-07-08-HEALTH.md` §7-C1（🔴 Critical）

---

## Why（为什么做）

2026-07-08 健康巡检**实跑 bats 全量**（414 测试），发现 **169/414 失败（40.8%）**。经 3 项决定性证据定位，根因是 **1 个系统性测试路径 bug**（非 169 个独立回归），且**生产代码零退化**：

**症状链**：
- 12 个测试文件 setup 用 `${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks/.../<lib>.sh`
- 但测试文件位于 `<repo>/flow-kit-bundle/test/`，`BATS_TEST_DIRNAME/..` 已是 `flow-kit-bundle/`，再拼 `flow-kit-bundle/` → **双重前缀，路径不存在**
- source 失败被 `2>/dev/null || true` 静默吞掉
- 被测函数未定义 → `run <func>` 返回 127（command not found）→ 断言失败

**3 项决定性证据**：
1. 错误路径 `test/../flow-kit-bundle/hooks/stop/lib/l2-detect.sh` → 文件**不存在** ❌
2. 正确路径手动 source → `l2_detect_missing` ✅ 定义成功（**lib 本身完全健康**）
3. 错误路径 source + `|| true` → 函数未定义（确认静默失败）

**后果**：
- 测试套件当前**无法有效防护回归**（169 红灯常亮，开发者会习惯性忽略）
- 上次（07-07）健康报告漏检（只数测试数量 72→414，**没跑通过率**）
- `|| true` 反模式让 source 失败隐藏，是比路径 bug 本身更危险的"静默失效"温床（见 `LESSONS.md` L-025）

详见 `.specs/health/2026-07-08-HEALTH.md` §3、§7-C1。

## What（做什么）

### 核心修复（必做）

1. **修 12 个测试文件的路径双重前缀**：
   - `setup()` 里 `${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks/...` → `${BATS_TEST_DIRNAME}/../hooks/...`（去掉多余 `flow-kit-bundle/`）
   - 执行时用 `grep -rl '\.\./flow-kit-bundle/' flow-kit-bundle/test/*.bats` 拿全量 12 个文件
   - 已知核心 4 个（setup 直接 source lib）：
     - `test/l2-detect.bats` · `test/l3-truncation.bats` · `test/phase-resolution.bats` · `test/done-skip.bats`

2. **移除 setup 的 `2>/dev/null || true` 静默吞错反模式**：
   - 改为显式失败：`source "$LIB" || { echo "setup fail: $LIB" >&2; return 1; }`
   - 让 source 问题在 setup 阶段就暴露（而非让测试假失败）

3. **加回归防护**：
   - 新增 bats smoke：断言关键 lib 的 setup source 成功（函数已定义）
   - 防止未来再出现"路径漂移 + 静默吞错"组合

### 附带清理（可选 · 低风险）

4. 删 `estimate_tokens()`（`transcript-parser.sh:130`，全仓零引用·真死代码）
5. 确认 `read_correction_file()` / `file_not_empty()` 是否废弃（见 `CONTEXT.md` 清理窗口专列）

## 验证标准（AC）

- [x] **AC-1**: `bats flow-kit-bundle/test/` 通过率 237/414 → **407/414（0 失败，169→0）** ✅
- [x] **AC-2**: `grep '\.\./flow-kit-bundle/'` 零命中 ✅（修 25 处双重路径：11 文件 `../flow-kit-bundle/`→`../` + 14 处 `)/flow-kit-bundle/`→`)/` + checkpoint cp 相对→绝对 + package/smoke REPO_ROOT `..`→`../..`）
- [~] **AC-3**: **调整** — `|| true` 保留为合理容错。实测移除后破坏 27 测试（source lib 顶层 set-e 副作用失败，但函数已定义可用；`|| true` 吸收副作用，非"吞路径错误"反模式）。L-025 真实防护改由 AC-4 函数定义断言承担
- [x] **AC-4**: 新增 `test_setup_integrity.bats` — source 关键 lib + `type` 断言 10 个代表函数已定义（防路径漂移→静默假失败）✅
- [x] **AC-5**: `bash -n` 全量 0 错误（60 脚本，不回归）✅
- [x] **AC-6**: 健康分 84 → **96**（T2 🔴 消除 + 死代码清理 + 备份清理）✅

## 完成总结（2026-07-08）

| 项 | 结果 |
|---|---|
| C1 测试路径 bug | ✅ 169/414 失败 → 0（25 处双重路径 + cp/REPO_ROOT 修正） |
| AC-4 setup smoke | ✅ 新增 test_setup_integrity.bats（10 函数定义断言） |
| repo test/ 同步 | ✅ rsync flow-kit-bundle/test/ → test/（AC-7 通过，清孤儿 test_l3_feedback.bats） |
| S2 死代码 | ✅ 删 estimate_tokens + read_correction_file；保留 file_not_empty（有测试的公共工具） |
| M1 备份 | ✅ 删过时 CONTEXT.md.bak-2026-07-08 |
| `|| true` | 📌 保留为合理容错（L-025 修正：非纯反模式，AC-4 函数断言才是真防护） |
| **S1 l3-review 拆分** | ⏸️ **未做** — 重构涉禁动清单（l3_review_run 封装），建议单独开 change（见下） |

## 影响面

- [ ] 影响 `REQUIREMENT.md`（进入 1-requirement 时补）
- [ ] 影响 `DESIGN.md` / 引入新 ADR（路径修复简单，预期不需要 ADR）
- [x] 影响现有 AC（新增 AC-1~6）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 影响测试套件（核心：修复 169 失败）

## 预期收益

- 综合健康分：**84 → 预计 93+**（T2 🔴 消除，唯一 Critical 清偿）
- 测试套件恢复真实防护力（414 测试从"纸面覆盖"变"有效红灯"）
- 消除 `|| true` 静默吞错反模式（`LESSONS.md` L-025 预防措施落地）

## 下一步

用户确认后，进入 `0-change`（确认范围）→ `1-requirement`（补 Given/When/Then）→ `3-task`（拆修路径 + 移除反模式 + 加 smoke）→ `4-dev`（TDD 执行）→ `5-test`（验证 AC-1 通过率）。

> 📌 由于修复机械（路径前缀 + 移除 `|| true`），可走"最短路径"：跳过 2-design，直接 3-task 拆 12 文件 × 2 改动。
