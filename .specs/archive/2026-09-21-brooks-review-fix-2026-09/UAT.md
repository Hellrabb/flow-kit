# UAT · brooks-review-fix-2026-09

- **Change ID**: brooks-review-fix-2026-09
- **形态**: CLI / 工具类 change —— 无图形界面。UAT = 维护者的三个日常动作，全部**可脚本化**（TEST.md 1.2 已声明）。

## UAT 脚本与结果

| # | 步骤（可复制执行） | 期望 | 实测 | 判定 |
|---|---|---|---|---|
| UAT-1 | `make verify-claims` | exit 0；输出 `✅/❌/⏭` 三计数；三条工件断言**指名**核到的 change；无假 ✅ | `复验结果: ✅ 14  ❌ 0  ⏭ 0`（`.flow-active` 指向本 change 时）· exit 0 | ✅ 通过 |
| UAT-1b | 同上，但**无活跃 change**（`rm .flow-active` 后重跑） | 三条断言显式 `⏭ SKIP`（"未指定 change → 本项未核对"），且输出中**不出现**任何其他 change 的路径 | `复验结果: ✅ 11  ❌ 0  ⏭ 3` · exit 0 · `grep l3-review-defects` = 0 命中 | ✅ 通过 |
| UAT-2 | `make check` | 6 门全绿；bats 962 / 0 fail | exit 0 · 4m04s · `✅ make check: 全部通过` | ✅ 通过 |
| UAT-3 | `bash package-dsh-plugin.sh --check` | rc=0（`✅ dist 与源一致`）；故意改陈旧件时 rc=1 且**指名**文件 | 一致时 rc=0 / 0.60s；夹具内陈旧 → rc=1 + `❌ 陈旧: …` | ✅ 通过 |
| UAT-4 | `bash sync-hooks.sh --check` | 漂移 0；只对**真入口**报"不可执行" | `✅ hooks 副本一致（漂移 0）`（7 个副本目录） | ✅ 通过 |

## 人工确认

- 上述 5 条均为**命令级可复算**（无主观判断项），主 agent 已在 2026-09-21 会话内实跑并记录原始输出。
- 仍需**用户确认**的一项是产品口径：`verify-claims.sh` 在"未指定 change"时输出 `⏭ SKIP` 且**不影响退出码**（这是刻意设计：归档后 `make-verify-claims` 必须仍可用，否则门禁会被训练成噪声）。该口径已写入 `REQUIREMENT.md` AC-1 与 `DESIGN.md` D1/D6。
