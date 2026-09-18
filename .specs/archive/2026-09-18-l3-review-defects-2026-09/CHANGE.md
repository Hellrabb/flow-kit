# CHANGE · l3-review-defects-2026-09

- **change-id**: `l3-review-defects-2026-09`
- **日期**: 2026-09-18
- **类型**: 缺陷修复型（**直接修复，未走 7 阶段 pipeline** —— 见 §4 声明）
- **来源**: chisel-skill 开发过程中在 `chisel_env` 的 change `verify-ac-env-fix`（阶段 7）
  踩到的 flow-kit 缺陷，由报告方整理为 `L3-review-defects-2026-09-17.md`（本目录内，内容零改动）

## 1 · 为什么做

报告方对 commit `19b3463`（`develop`）提出 5 条 L3 审查链缺陷（§B1~§B5）。
由于报告距今有时日，**先重新实测与过滤，再决定修什么**：

**过滤结论：5 条全部成立（0 条失效 / 0 条误报），另新增 1 条报告未列出的缺陷。**

| ID | 缺陷 | 原报告验证状态 | 本次复测 |
|----|------|--------|------|
| B1 | `fk_extract_l2_verdict` 抽错 verdict（取 L3 段 JSON / 无锚定 / 大小写不归一） | 已实测复现 | ✅ 成立（并量化出 18 处提取错误） |
| B2 | L3 段重写按标题截断、无结束标记 | 代码可推演（未触发） | ✅ 成立（**本次实际触发**） |
| B3 | `max_artifact_chars` 名"字符"实"字节" | 已实测 | ✅ 成立 |
| B4 | 阶段 7 产物清单 `head -30` + 硬编码 `INTEGRATION.md` | 已实测复现 | ✅ 成立 |
| B5 | 安装树不同步（`~/.claude/hooks` 缺 P0-1/P0-2） | 已实测 | ✅ 成立 |
| **新增** | 防漂移断言只覆盖 `l3-prompt.sh` 单文件 → 副本真漂移时测试仍绿 | — | ➕ 已修 |

完整证据链与判定依据见本目录 `L3-review-defects-2026-09-18-retest.md`。

## 2 · 范围（做了什么）

- §B1 → `hooks/stop/lib/l2-detect.sh`：`fk_extract_l2_verdict` 重写（行首锚定 + 排除围栏
  JSON 引号键 + 取最后一轮 L2 结论 + 大小写归一）
- §B2 → 新增 `hooks/stop/lib/l3-section.sh`；`l3-api.sh` / `l3-done.sh` / `l3-prompt.sh` 接线
  （段尾落 `<!-- /L3-SECTION -->`；删除侧按标记精确切分，历史工件走原标题法兼容）
- §B3 → `max_artifact_chars` → `max_artifact_bytes`（单位=字节），旧键/旧 env 兼容读取 +
  DEPRECATED 提示；README ×2 / 配置模板 / `l3.env.example` 写明 CJK ÷3
- §B4 → 阶段 7 产物清单改全量（去 `head -30`）；`INTEGRATION.md` 改"存在才列"，
  必备清单保留严格 MISSING 语义
- §B5 → 新增 `sync-hooks.sh`（唯一源 → 6 副本内容镜像，含 `--check`）+ Makefile
  `hooks-sync` / `check-hooks-sync`（后者纳入 `make check` 门禁）
- 新增回归 `test/test_l3_review_defects_2026_09.bats`（28 例，B1×8 / B2×6 / B3×6 / B4×4 / B5×4）

## 3 · 验收

| 项 | 结果 |
|---|---|
| 全量 bats | **854 / 854，0 fail**（基线 826，净增 28） |
| `make check`（test + lint + check-validate + check-test-sync + check-hooks-sync） | ✅ 五门全绿 |
| shellcheck（8 个改动/新增脚本，error 级） | ✅ 0 error |
| 打包完整性 `--validate` | ✅ 312 文件，漏配 0 / 源缺失 0 |
| hooks 副本漂移 | ✅ 6/6 漂移 0 |
| `test/` ↔ `flow-kit-bundle/test/` 双源 | ✅ 一致 |

逐条验证方式见本目录 `REVIEW.md`。

## 4 · 声明：为什么没有七件套

本次是**对一份外部缺陷报告的直接响应**，没有走 flow-kit 的 0→7 阶段 pipeline，
因此本目录**不产出** `REQUIREMENT.md` / `DESIGN.md` / `TASK.md` / `TEST.md`，
也没有 L2 盲审 / L3 外部模型审查记录与 `.done` 锚点。

理由：为一份已经完成、已验证的缺陷修复倒推补齐七件套与审查记录，属于**事后补账**，
会让归档看起来比实际过程更完备。宁可留白 + 显式声明。

若需要走完整 pipeline（含 L2+L3 独立审查）重做一遍本 change，请另立 change-id。

## 5 · 已知遗留（有意不动）

1. **12 份历史 `.done` 的 `L2_verdict` 与新提取结果不一致** —— 那些值是 §B1 缺陷的产物。
   未回溯修改：PreToolUse 守卫本就禁止主 agent 改 `.done`，且新 change 起自洽。
2. **`.claude/hooks/pre-tool-use/gate-checks-review.sh` 缺可执行位** —— 修复前就存在
   （git 记录即为 644，同目录其余 7 个文件为 755）。`sync-hooks.sh` 只做只读提示，
   不改权限；跑 `install.sh` 可修。
3. **§B1 的语义取舍已按 L2 独立性契约定案** —— 取"审查员原文结论"而非主 agent 修复后的
   复述（依据 `flow-kit/prompts/independent/L2-blind-review.md:142`）。该值在任何地方
   都不被要求等于 `pass`，故只影响审计记录的准确性，不影响放行判定。

## 6 · 未覆盖

- 报告 §8 已声明不覆盖的范围未重新审查：L2 派发/子 agent 生命周期、gate 与 transition
  逻辑、`31-auto-advance.sh`、看板、安装器与打包脚本。
- `l3-prompt.sh` 的 `head -8`（前轮发现配额）/ `head -3`（ADR 取样）经核查是**刻意配额**
  且有专门断言，未改动。
