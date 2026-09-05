# UAT · l3-prompt-loop-fix

## UAT 策略声明（TEST.md §1.2）

全部 AC（AC-1~AC-7）为 bats 可自动化断言（fixture 驱动 + 真实函数调用 + 字节位/cmp 断言），无手工 UI 面 → 不设 manual UAT 脚本。

## 等价真实面验证（real-surface evidence）

| # | 面向 | 证据 | 结果 |
|---|---|---|---|
| 1 | 部署一致性（AC-6） | 五副本 md5 同值 `96e9e8f0…`（bundle/.claude/dist×2/~/.claude 全局，2026-09-05 实测） | ✅ |
| 2 | 生产运行路径 | phase 5/6 的 L3 外部盲审由**部署版** `~/.claude/hooks/stop/29-independent-review.sh` + 部署 lib 真实执行（真实网关 glm-5.3-flash，2 次 pass）——inject/build 重排后的 prompt 在生产路径端到端运行 | ✅ |
| 3 | 反馈注入实效 | phase 6 L3 重审 prompt 已含前轮发现注入段（R1 修复后 L3 确认「前轮两项 major 已实质修复」——反馈闭环生效的直接证据） | ✅ |
| 4 | 全量回归 | 803 ok / 0 fail / 1 既有 skip；`make check` 全绿（2026-09-05） | ✅ |
