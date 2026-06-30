# CHANGE: 修复 package-flow-kit.sh 孤儿 fi 语法错误 + 加固 bash -n 门禁

- **Change ID**: health-fix-2026-07
- **创建日期**: 2026-07-01
- **路径建议**: 最短
- **状态**: draft

---

## Why（为什么做）

2026-07-01 健康巡检发现 `package-flow-kit.sh` 末尾（581-587 行）存在孤儿 `fi` + `}` —— 本周某个 package commit 编辑时把 `validate_staging_coverage()` 函数的中段尾巴误粘到了文件末尾。后果：

- `bash -n` / shellcheck / CI lint 立即失败
- 正常打包（不带 `--validate`）执行到末尾触发语法错误，**退出码非 0** → 阻断 `&& deploy` 类自动化
- 末尾还打印假的「✅ 校验通过」，掩盖问题
- `--validate` 路径仅因 `exit $?` 早退而偶然可用，是定时炸弹

更关键：**上次（2026-06-30）健康报告 89/100 漏检了这个 Critical**，根因是巡检流程和测试套件都没有 `bash -n` 全量语法门禁。同类回归会反复漏到下次手动巡检。

详见 `.specs/health/2026-07-01-HEALTH.md` 的 Critical-1。

## What（做什么）

1. **删死代码**：移除 `package-flow-kit.sh:581-587`（孤儿 `fi` + `}` + 假"校验通过"输出 + 残留注释）。顶部 19-139 行的 `validate_staging_coverage()` 是完整正确的定义，**不动**。
2. **加回归测试**：在 `test/` 下新增 bats 用例，覆盖：
   - `bash -n package-flow-kit.sh` 通过
   - `./package-flow-kit.sh`（mock OUTPUT_DIR，不真打包）退出码 0，末尾不再出现孤儿 `fi` 报错或假"校验通过"
   - `./package-flow-kit.sh --validate` 退出码 0（保持可用）
3. **加固全量语法门禁**：新增 `bash -n` 全量 smoke（扫所有 `**/*.sh` 生产脚本），纳入 bats 套件 —— 每次跑 bats 即等于跑门禁。同时在 `flow-health` skill 增补「bash -n 全量语法检查」步骤，堵住巡检盲区。

> **CI 落地说明**：CONTEXT.md 记录"构建/部署：纯 Shell 脚本打包，无 CI/CD"。故"门禁"落地形式 = **bats smoke**（本地 + 任何未来 CI 都跑）+ **flow-health 巡检步骤**，而非新建 CI 配置文件。如未来引入 CI，再单独开 change。

## 影响面

- [ ] 影响 `REQUIREMENT.md`
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 仅修复 bug，无范围变化（+ 测试加固 + flow-health 流程文档增补）

## 范围排除（这次不做）

- **不动顶部 `validate_staging_coverage()` 函数**（19-139 行）—— 它是完整正确的，`--validate` 功能必须保留
- **不修 `flow-kit-resume.sh:95` 的 jq 错误吞咽**（🟢 Minor-1，已有 else 兜底分支，非本 Critical 范围）
- **不重构 package-flow-kit.sh 其他部分** —— 仅删残留，不顺手改别的
- **不改 flow-kit-bundle/ 镜像** —— `package-flow-kit.sh` 是打包工具本身，不在被打包的 bundle 内，无镜像需同步
- **不新增 CI 配置文件** —— 仓库无 CI，门禁靠 bats + flow-health 落地

## 验收线（粗粒度，不是 AC）

1. `bash -n package-flow-kit.sh` 零语法错误
2. `./package-flow-kit.sh`（mock OUTPUT_DIR）退出码 0，末尾不再出现孤儿 `fi` 报错或假"校验通过"
3. bats 全量套件通过（原 176 + 新增 bash -n 门禁用例）
4. flow-health skill 文档已增补 bash -n 全量检查步骤（下次巡检不再漏此类问题）

## 风险与未知

- **全量 bash -n 门禁可能暴露其他脚本的潜在语法问题**：已知 6 个核心脚本（27/28/lib×2/resume + package）语法 OK，且现有 176 bats 含 smoke 语法检查覆盖核心 hook。全量扫到 `.claude/hooks/**/*.sh` + `package-flow-kit.sh` + `install.sh` + `lib/*.sh` 等，预期全过；若有个别边角脚本暴露问题，作为本 change 的附带修复项处理（不另开 change）。
- **正常打包验收的 mock 方式**：`package-flow-kit.sh` 真跑会生成 tar + 写 `$HOME/flow-kit-export`。测试需用临时 OUTPUT_DIR + 可能 mock rsync/npm。具体 mock 策略在 TASK 阶段定。

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
