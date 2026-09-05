# T06-SUMMARY · 全量同步：四副本一致 + 漂移存档 + 全局部署 + AC-6 硬断言

## 交付物
- 漂移存档：`.specs/l3-prompt-loop-fix/sync-drift-20260904.patch`（380 行 diff，.claude/hooks 旧副本 → bundle 新源；含已知历史漂移=旧版死代码 agent_response 残留 + 本次 T01-T05 全部增量）
- 同步：bundle 源 → `.claude/hooks/stop/lib/` + `dist/dsh-flow-kit/hooks/stop/lib/` + `dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/stop/lib/` + `~/.claude/hooks/stop/lib/`（全局部署，D8）
- AC-6 bats 硬断言 ×2：仓库内四处 md5 `sort -u` 唯一值=1；`~/.claude` 全局副本存在性门控 cmp（无 skip 语义——缺失时平凡通过，可证伪面保留）

## 验证（TASK verify 硬 gate 逐条）
- ✅ md5 四处唯一值 = 1（实测含 ~/.claude 共五处同值）
- ✅ `make check` 全绿（bats + shellcheck + validate + check-test-sync 双源收口）
- ✅ `cmp -s` 全局副本 gate PASS
- ✅ 全量 801 ok / 0 fail / 0 skip（T05 基线 799 + T06×2）
- ✅ 双源一致：bats + 7 fixtures 均已镜像（fixtures 走显式 cp，make test-sync 不含子目录）

## 六维自查
- ✅ diff 边界 ⊆ write_files：3 副本 + patch + bats（+镜像）
- ✅ 存档先于覆盖（R3 缓解）：漂移 patch 在 cp 之前生成
- ✅ AC-6 用例双源同步在本任务内闭环（T05 全量跑时不红）
- ✅ 全局部署 = 发布清单人工步骤的仓库内可证伪投影（cmp gate）
- ✅ 禁动清单：未触碰 l3-review.sh / done 文件 / l3-truncate.sh / 29 号 / common.sh

## 残留
- 无。Claim-1/2 修复链（反馈优先 + 反馈注入 + 截断安全 + 四副本一致）全部落地，待 phase 5 测试矩阵与 phase 6/7 审查归档。
