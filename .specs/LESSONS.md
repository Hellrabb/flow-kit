# LESSONS — 项目经验教训与技术债

> 本文件跨 change 累积。M-health 巡检 + 各 change 的 brooks-lint 结果 + 人工标注都写入此处。
> 格式：严重程度 | 位置 | 问题 | 建议 | 状态 | 来源

---

## 技术债清单

| # | 严重程度 | 位置 | 问题 | 建议 | 状态 | 来源 |
|---|---|---|---|---|---|---|
| L-004 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh` | 辅助函数 `install_file()` 已从 install.sh 抽出到 lib/，但独立工具库 `lib/utils.sh` 尚不必要（当前 1 个共享函数，阈值 ≥ 3）。debt-cleanup 确认保持推迟。 | 等新增 ≥ 2 个共享辅助函数时再建 `lib/utils.sh`，避免只有一个函数的过度抽象 | deferred | `init-git-repo` T03 手动基线 |
| L-005 | 🟡 | `package-flow-kit.sh` L20 | STAGING 前置校验已添加（debt-cleanup） | `[[ -n "$STAGING" && "$STAGING" != "/" ]]` guard 已生效 | resolved | `init-git-repo` T03 手动基线 |
| L-013 | 🟢 | `.specs/` 归档流程（7-integration） | 归档流程两种遗漏模式：① **归档未清理**——change 已归档但 `.specs/<id>/` 工作目录未删，留只剩 PROGRESS.md 的空壳（2026-06-24 发现 bundle-packaging / docs-sync / fix-pcsc-gaps）；② **完成未归档**——change 100% 完成（REVIEW✅ / TASK 全done / CHANGELOG 已记）却没走归档，完整工件散落 `.specs/`（2026-06-25 发现 security-privacy-audit） | 归档脚本（7-integration）加双向校验：a) 归档完成后 rm 工作目录（PROGRESS.md 先确认入 archive）；b) 定期扫描 `.specs/` 下非 archive 目录，凡 REVIEW✅ + TASK 全done 的 change 提示归档 | resolved | `lessons-cleanup` T01 / T04 / T06 |

---

## 已解决

> 已修复或不再适用的条目移至此段，保留溯源。

| # | 原状态 | 位置 | 问题 | 修复提交 | 解决日期 |
|---|---|---|---|---|---|
| L-002 | 🟡 | `package-flow-kit.sh` L56 | 硬编码 `~` 路径 | `7b1ae91` fix(package): 用 SCRIPT_DIR 替换 | 2026-06-15 |
| L-006 | 🟡 | `install.sh` L243 + brooks-lint hooks | 空 commands 目录导致 hook exit 1 | `47d80f6` fix(brooks-lint): SessionStart hook 空 commands 容错 | 2026-06-14 |
| L-001 | 🟡 | `package-flow-kit.sh` | 打包与安装逻辑耦合 → install.sh 已拆分为独立文件 | `e1ea7b9` refactor package-flow-kit.sh | 2026-06-15 |
| L-003 | 🔴 | `package-flow-kit.sh` | 零测试覆盖 → bats-core 28 tests | `2e745b7` feat(health-fix) | 2026-06-17 |
| L-007 | 🟢 | `package-flow-kit.sh` L104-143 | settings.json 模板 heredoc 重复 → cp 文件替代 | `2e745b7` feat(health-fix) T08 | 2026-06-17 |
| L-008 | 🟢 | `install.sh` L194 | brooks-lint 版本号硬编码 → plugin.json 动态读取 | `2e745b7` feat(health-fix) T09 | 2026-06-17 |

---

| L-009 | 🟡 | `common.sh:10` | CONFIG_FILE 覆盖调用方 → 已改为 `: "${CONFIG_FILE:=}"`（debt-cleanup） | 仅在未设时赋默认值 | resolved | 2026-06-16 health-fix |
| L-010 | 🟡 | T02 流程 | 破坏性变更后未立即验证恢复 → 已记入流程规范 | 1.8 协议后必须立即跑恢复验证 | resolved | `lessons-cleanup` T03 / T04 / T06 |
| L-011 | 🟢 | `common.sh:22-39` | jq key 连字符→减法 → 已改为 bracket 引用 `.modules["${mod}"]`（debt-cleanup） | bracket 引用防止 jq 解析错误 | resolved | 2026-06-16 health-fix |
| L-012 | 🟡 | `package-flow-kit.sh` Part E | **结构变更后打包脚本未同步**：install.sh 拆分为 `lib/` 模块后，`package-flow-kit.sh` Part E 只 `cp install.sh` 忘了 `cp -r lib/`，导致 bundle 安装报 `No such file: lib/install_hooks.sh`。E2E 验证环节才发现。 | 任何改变 `flow-kit-bundle/` 目录结构的修改，必须同步检查 `package-flow-kit.sh` 的 staging 逻辑（Part A~F 的 mkdir/cp/rsync 范围） | resolved | `lessons-cleanup` T02 / T06 |

## 元数据

- **最近更新**: 2026-06-16（health-fix 归档）
- **下次复查**: 2026-07-16（建议每月一次 M-health）
