# REQUIREMENT: package-flow-kit.sh 孤儿 fi 修复 + bash -n 门禁加固

> **Lite 版**（最短路径 · 纯 bug 修复）。完整 Why/What/范围排除见 `CHANGE.md`。本文件只补 AC（TEST 阶段派生用例的唯一来源）。

- **Change ID**: health-fix-2026-07
- **创建日期**: 2026-07-01

## 用户故事

作为 flow-kit 分发包的打包者，我希望 `package-flow-kit.sh` 语法合法、且仓库有 `bash -n` 全量门禁，以便：
- `./package-flow-kit.sh && deploy` 类自动化不再被孤儿 `fi` 阻断
- 未来的 shell 语法回归能被 bats 套件或健康巡检立即捕获，而不是漏到下次手动体检

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · package-flow-kit.sh 语法合法
- **Given** `package-flow-kit.sh` 已删除 581-587 残留碎片
- **When** 执行 `bash -n package-flow-kit.sh`
- **Then** 退出码 0，无「未预期的记号」类语法错误
- **验证方式**: `bash -n package-flow-kit.sh && echo OK`

### AC-2 · 正常打包退出码 0
- **Given** `package-flow-kit.sh` + `flow-kit-bundle/` 就绪，OUTPUT_DIR 指向临时目录
- **When** 执行 `./package-flow-kit.sh`（不带参数，mock 避免真打包）
- **Then** 退出码 0；末尾 stderr 无孤儿 `fi` 报错；stdout 不再出现假的「✅ 校验通过：所有文件均被 Part A~G 覆盖。」
- **验证方式**: `bats test/test_package_flow_kit.bats`

### AC-3 · --validate 仍可用
- **Given** 同 AC-2
- **When** 执行 `./package-flow-kit.sh --validate`
- **Then** 退出码 ∈ {0, 1}（0=通过，1=发现漏配，均属正常执行）；退出码 ≠ 2（脚本自身错误）
- **验证方式**: `bats test/test_package_flow_kit.bats`

### AC-4 · 全量 bash -n 门禁
- **Given** 仓库所有生产 `.sh`（`.claude/hooks/**/*.sh` + `flow-kit-bundle/**/*.sh` + `package-flow-kit.sh`，排除 `brooks-lint/` / `brooks-tools/` / `.claude/plugins/` 第三方）
- **When** 跑全量 smoke
- **Then** 每个文件 `bash -n` 退出码 0
- **验证方式**: `bats test/test_smoke_syntax.bats`

### AC-5 · flow-health 巡检补 bash -n 步骤
- **Given** flow-health SKILL.md（项目内源优先，否则全局 `~/.claude/skills/flow-health/SKILL.md`）
- **When** `grep -c 'bash -n' <skill 文件>`
- **Then** 命中 ≥ 1（巡检流程新增「全量语法检查」步骤）
- **验证方式**: 见 TASK T04 verify

## 范围切分

- **v1（本次必做）**: AC-1 ~ AC-5
- **v2（下一轮考虑，不本次）**: 引入 CI 时，把 `bats test/` + `bash -n **/*.sh` 纳入 CI 门禁
- **out（永远不做）**: 重构 `package-flow-kit.sh` 的 Part A~G 逻辑；修 `flow-kit-resume.sh:95` 的 jq 吞咽（Minor-1，已有兜底）

## 非功能性需求

- 无新增运行时依赖（纯 Bash + 既有 bats-core 1.13.0）
- 新增测试执行时间 < 10s（`bash -n` 极快）
- 不降低现有 176 bats 通过率

## 依赖与假设

- bats-core 1.13.0 已装（`npx bats`）
- 仓库无 CI/CD（门禁靠 bats + flow-health 落地）
- `flow-kit-bundle/hooks/` 与 `.claude/hooks/` 镜像同步（全量 smoke 扫两套，重复但无害）

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
