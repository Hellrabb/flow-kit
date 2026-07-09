# CHANGE: 修 TD-009 + TD-011 + TD-015 + TD-016（gate regex 治理 + 死代码清理 + 测试断言债裁定）

- **Change ID**: td-gate-cleanup
- **创建日期**: 2026-07-09
- **状态**: ✅ done（实施完成 · 归档）
- **关联 TD**: TD-009 / TD-011 / TD-015 / TD-016（均 🟡 → ✅）
- **设计授权**: `.specs/archive/2026-07-09-refactor-independent-review-gate-discovery/DESIGN.md` v4 D1+D8（TD-011/015）

---

## Why

4 条 🟡 技术债，分属 3 个区域，一并清理（承接同日 TD-014 gate phase 检测修复）：

- **TD-011+TD-015**（gate regex 治理）：`independent-review-gate.sh` L69 `&&` 被 `[[ ]]` 当逻辑与（SC2157）；L30/L71 `\>[^=]` 变量化会踩 GNU 单词边界。
- **TD-009**（死代码）：未引用函数。
- **TD-016**（测试断言债）：3 个 skip 测试断言了实现没有的字符串。

## What

### TD-011+TD-015（gate regex 变量化 · D1+D8）
- L69 `[[ "$c" =~ \.tmp...&&...mv ]]` → 变量 `re_tmp_mv`（修 `&&` 被当逻辑与）
- L30/L71 `\>[^=]` → 变量 `re_redirect='[>][^=]'`（字符类，防 GNU 单词边界）
- 去 L68 `shellcheck disable=SC1026,SC2203,SC2157` + TODO（L69 变量化后 `&&` 不再触发）

### TD-009（死代码清理）
- `file_not_empty`（common.sh）：删定义 + 3 个 test（双源同步）。生产零调用。
- `estimate_tokens` / `read_correction_file`：**前序 change 已清**（全仓 grep 零匹配），CONTEXT TD-009 描述过时。

### TD-016（删 3 过时断言）
- AC-3 #11/#12（断言 flow-kit-artifacts.sh 含 `^(1|2|3|5|6|7)$` 正则 + `"3-task"` case）：文件已改 PHASE_ARTIFACTS 查表驱动（L-016）。gate.sh #9/#10 已覆盖 phase 检测 → 删
- AC-6 #23（断言 F29 含 sha256sum）：`l3_token`/`sha256` 全仓未实现。AC-6 #22 仍覆盖 F29 → 删

## 影响面

- [x] gate 行为不变（变量化后逐函数复测 13 case 全 ✅，TD-014 不回归）
- [x] 测试覆盖不丢（删的是过时实现细节断言；行为由 gate.sh #9/#10 + AC-6 #22 + test_flow_artifacts 覆盖）
- [ ] 无新 ADR / 无 REQUIREMENT 影响

## 验收

见 `DEV-SUMMARY.md`「最终验证」。
