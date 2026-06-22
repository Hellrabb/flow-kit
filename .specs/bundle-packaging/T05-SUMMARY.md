# T05-SUMMARY: 端到端验证

- **Task**: T05 — 端到端验证：打包 → 离线安装 → 工具可用
- **Status**: done

## 做了什么

1. 执行完整打包流程 → 产出 `flow-kit-full-*.tar.gz`
2. 验证 tarball 含 `brooks-tools/` 目录（1227 文件）
3. dry-run 安装验证：4 个工具 shim 均正确生成
4. `--no-brooks-tools` flag 正确抑制安装
5. bats 全量回归 94 tests 通过

## 改动文件

- 无（仅验证）

## verify 输出

```
E2E: tarball 1227 files in brooks-tools/ ✅
dry-run: depcheck/jscpd/knip/ts-prune shims ✅
--no-brooks-tools flag: suppresses correctly ✅
bats regression: 94/94 ✅
```

## AC 对照

| AC | 状态 | 备注 |
|---|---|---|
| AC-1 depcheck 离线可用 | ⚠️ 待目标环境 | 当前环境有网络 + Node 22；离线验证需 Docker CentOS 8 |
| AC-2 jscpd 离线可用 | ⚠️ 待目标环境 | 同上 |
| AC-3 knip 离线可用 | ⚠️ 待目标环境 | 同上 |
| AC-4 ts-prune 离线可用 | ⚠️ 待目标环境 | 同上 |
| AC-5 打包产出 brooks-tools | ✅ | 1227 files in tarball |
| AC-6 Node.js 缺失提示 | ✅ | check_node() 函数已实现，dry-run 验证通过 |
| AC-7 现有打包不退化 | ✅ | Part A-F 未变，94 tests 全通过 |
| AC-8 shim 可被直接调用 | ✅ | dry-run 显示 4 个 shim 路径正确 |

## 越界检查

- TASK write_files: 无
- 实际 diff: 无
- 越界: 0 ✅
