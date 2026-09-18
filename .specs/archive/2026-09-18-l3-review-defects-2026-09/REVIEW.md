# REVIEW · l3-review-defects-2026-09

> 本目录的 `REVIEW.md` 是**修复后自检证据**，不是独立审查结论
> （本 change 未走 pipeline，无 L2 盲审 / L3 外部模型审查 —— 见 `CHANGE.md` §4）。

## 1 · 逐条缺陷的验证方式与结果

| 缺陷 | 验证方式 | 结果 |
|---|---|---|
| B1 | 报告 §B1 自包含复现 → 期望 `fail` | ✅ `fail` |
| B1 | 222 份归档工件提取覆盖率 | ✅ 空值 0、非枚举 0 |
| B1 | `PASS` / `- **Verdict**: Pass` / `### Verdict: FAIL` / `## Verdict`+次行 | ✅ 全部归一为小写枚举 |
| B1 | 与 `.done` 记录值三方对照 | ✅ 修对 18 处、覆盖零回归（无一份从"有值"退化为"空值"） |
| B2 | 4 轮连写（载荷含行首 `## `） | ✅ L3 段 1 / 标记 1 / `---` 1 / 残留 0 / 围栏配平 |
| B2 | **生产链路** `_l3_parse_result` 连跑 5 轮（2 轮载荷带行首 `## `） | ✅ 与单轮同形：段 1 / 标记 1 / 分隔 1 / 围栏 2 / 空行 7（不增长）/ 残留 0 |
| B2 | 历史无标记工件（兼容路径） | ✅ 仍按标题法清除；标记之后的内容不误删 |
| B3 | cap=60000 对 CJK 文件（90000 字节 / 30000 汉字） | ✅ 输出 60000 字节 = 20000 汉字（已断言） |
| B3 | 新键 / 旧键 / 历史 env / 缺省 四级解析 | ✅ 60000 / 60000（带 DEPRECATED 提示）/ 333 / 20000 |
| B4 | 41 条目目录 → `_l3_build_prompt 7` | ✅ 41/41 名字在清单内；`INTEGRATION.md === MISSING` 计数 0 |
| B4 | 删掉必备 `TASK.md` | ✅ 仍严格输出 `=== TASK.md === MISSING`（门禁未削弱） |
| B4 | 存在的可选产物 / 缺失的可选产物 | ✅ `UAT.md` 列出；`MINOR-DEFERRED.md` 不列 |
| B5 | `./sync-hooks.sh --check` | ✅ 6/6 副本漂移 0 |
| B5 | 漂移检测自证（伪造成缺失副本） | ✅ 能报出漂移并非零退出（非恒真断言） |
| B5 | 同步不产生无关权限变更 | ✅ `git diff --summary` 零 mode change |

## 2 · 门禁结果

| 门 | 命令 | 结果 |
|---|---|---|
| 全量测试 | `npx bats test/` | **854 / 854，0 fail**（基线 826，净增 28） |
| 静态分析 | `make lint`（shellcheck error 级） | 0 error（8 个改动/新增脚本） |
| 打包完整性 | `package-flow-kit.sh --validate` | 312 文件全覆蓋，漏配 0 / 源缺失 0 |
| 测试双源 | `make check-test-sync` | `test/` ↔ `flow-kit-bundle/test/` 一致 |
| 副本漂移 | `make check-hooks-sync` | 6/6 漂移 0 |
| 合计 | `make check` | ✅ 五门全绿 |

## 3 · 副本落地核实

修复后逐个确认关键标记在**运行时会真正加载**的副本中存在：

| 副本 | 说明 | 状态 |
|---|---|---|
| `flow-kit-bundle/hooks/` | 唯一维护源 | ✅ |
| `.claude/hooks/`（仓库级） | claude/opencode 安装 | ✅ |
| `~/.claude/hooks/`（用户级） | **§B5 的历史漂移点**（原停在 2026-09-03） | ✅ P0-1/P0-2/B3 标记就位 |
| `dist/dsh-flow-kit/hooks` | dsh 插件包顶层 | ✅ |
| `dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks` | 包内 bundle 副本 | ✅ |
| `~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` | **DSH 会话实际执行**（`hook-bridge.js`：`this.hooks = join(packageRoot, "hooks")`） | ✅ |
| `~/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/…/hooks` | 包内 bundle 副本 | ✅ |

## 4 · 未做独立审查的说明

本 change 未运行 L2 盲审与 L3 外部模型审查。因此：

- 上述结论均为**自检**，不存在"第二意见"交叉验证；
- 不写 `.independent-review-*.done` 锚点，`gate_config` 未启用；
- 若需独立复核，最省成本的切入点是 `test/test_l3_review_defects_2026_09.bats`
  的 28 例断言 + `L3-review-defects-2026-09-18-retest.md` §6 的验证矩阵。
