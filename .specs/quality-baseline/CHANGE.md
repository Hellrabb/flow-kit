# CHANGE: 质量基础设施补强

- **Change ID**: `quality-baseline`
- **创建日期**: 2026-06-29
- **路径建议**: 中等（REQUIREMENT 增量 → DESIGN 轻量 → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

项目健康分已达 92/100（brooks 97），但质量基础设施仍有几块短板：

1. **E - 协议双入口漂移风险**：toll-gate 协议在 `prompts/` 和 `skills/` 两处重复（如 4-dev 131 行），改一处忘另一处会导致 prompt↔skill 行为漂移。brooks-health R3 明确标记。
2. **F - 无自动化验证入口**：94 个 bats 测试全在本地手动跑，无 shellcheck，无一键 check。每次改完要手动记着跑哪些验证。
3. **G - stop 链主脚本盲区**：`hooks/stop/` 协调层（22-git/24-session/26-workflow/99-report）无直接 smoke test，核心 lib 已覆盖但主脚本仍是盲区。健康报告 T6 残留观察。
4. **H - bash 无静态分析**：shellcheck 未装，bash 脚本无静态分析。健康报告列为 🟢 Monitored 改进项。
5. **I - test 双源同步无校验**：`test/` 与 `flow-kit-bundle/test/` 是同一份 bats 文件两份拷贝，打包时手动同步，无自动化 diff 确认一致性。

五项都是小投入、低风险的补强，合在一个 change 里不会互相冲突。

## What（做什么）

- **E**：提取 `flow-kit/reference/pipeline-gates.md` 共享片段，各 prompt/skill 的 toll-gate 协议段改为 `@see reference/pipeline-gates.md` 引用（纯 markdown 约定，不引入模板引擎）
- **F**：创建 `Makefile`（targets: `test` / `lint` / `check` / `all`）+ `.git/hooks/pre-push` 自动跑 `make check`
- **G**：为 `hooks/stop/` 链主脚本（22-git/24-session/26-workflow/99-report）编写 bats smoke test
- **H**：安装 shellcheck，集成到 `make lint`，先只开 error 级别（`-e SC1091` 忽略未跟踪 source），warning 逐步修
- **I**：`make check` 中包含 test 双源 diff 校验——确认 `test/` 与 `flow-kit-bundle/test/` 内容一致

## 影响面

- [x] 影响 `REQUIREMENT.md`（五个子项各有验收准则）
- [x] 影响 `DESIGN.md`（pipeline-gates.md 共享片段设计 + Makefile 结构设计）
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不装 GitHub Actions / 外部 CI（F 限定为本地 pre-push + Makefile，零外部依赖）
- 不做 markdown 结构性模板 DRY（18.41%，两套评分都认定 ROI 低）
- shellcheck warning 级别不在此次范围（仅修 error 级别）
- 不引入 npm/JS 工具链（ts-prune/knip/depcheck 对此项目 N/A）

## 验收线（粗粒度，不是 AC）

1. 改 toll-gate 协议只需改 `reference/pipeline-gates.md` 一处，prompt 和 skill 两边自动一致（通过 diff 校验脚本验证）
2. `make check` 一键跑完 test + lint + 打包校验 + test 双源一致性，全部通过
3. `git push` 前自动跑 `make check`，失败阻止 push

## 风险与未知

- E 的 `@see` 纯约定方案依赖 AI 自觉遵守，无编译器/模板引擎强制。如果弱模型不跟约定可能仍会漂移。需要配合 lint 校验脚本（diff prompt vs skill 的 toll-gate 段）做硬兜底
- pre-push hook 在 `flow-kit-bundle/hooks/` 下新增，需确认 install.sh 的 hook 安装逻辑不受影响
- smoke test 覆盖协调层，但协调层逻辑薄（主要是编排调用），测试的 ROI 边界需拿捏

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
