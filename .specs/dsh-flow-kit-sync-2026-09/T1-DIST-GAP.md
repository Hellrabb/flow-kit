# T1-DIST-GAP — flow-kit 增量与 dist 差距盘点（dsh-flow-kit-sync-2026-09）

基线：dist/dsh-flow-kit 打包于 2026-08-16（v0.1.0，对应上游 76261dc）。

| commit | 内容 | 对 dist 的影响 | 状态 |
|---|---|---|---|
| 76261dc | install.sh/paths.sh dsh 平台分支 | hooks/install 内容 | 已包含（打包基线） |
| 9a81098 | correction 卫生 + 外来状态守卫（ADR-024） | hooks/stop/lib/correction-file.sh 等 | 0.2.0 已同步 |
| 47c68ef | shellcheck 清零 TD-023 | 18 个 hook 文件 lint 修复 | 0.2.0 已同步 |
| 2999024 | L2/L3 站点默认模型五级链 | common.sh fk_resolve_model tier-4/5 | 0.2.0 已同步 |

验证：diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle → 空输出
（vendor 逐字节一致 = 四个 commit 全部进入打包产物）。
