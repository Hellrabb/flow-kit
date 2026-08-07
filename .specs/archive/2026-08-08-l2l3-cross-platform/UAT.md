# UAT: L2/L3 模型审查双平台兼容性彻底修复

## UAT-1：opencode 凭证配置拉起 L3（需带凭证新会话）
- **状态**: ⚠️ DEFERRED — 当前 opencode 会话无 FLOW_KIT_L3_* 凭证，hook 子进程继承启动 env（无 ANTHROPIC_* 注入），fk_resolve_model 返回空 → model-missing correction → 优雅降级不阻塞
- **补测条件**: 新 opencode 会话 `export FLOW_KIT_L3_BASE_URL=<endpoint> FLOW_KIT_L3_AUTH_TOKEN=<token> FLOW_KIT_L3_MODEL=<model>` 后跑 pipeline
- **预期**: L3 外部模型审查真实执行（`## L3` 段写入 INDEPENDENT-REVIEW-N.md + .done 6 键 + verdict/summary）

## UAT-2：本 pipeline 端到端（gate_config=all both）
- **状态**: ✅ PASS — 阶段 0→7 全走通（含 rollback 6→1→2→3→4→5→6→7 delta 修订），gate_config=all(both) 所有阶段 L2 盲审闭环（INDEPENDENT-REVIEW-1~6.md），L3 降级记录在案

## UAT-3：双平台派发冒烟
- **状态**: ✅ PASS — opencode 下 task(category=unspecified-high) 路由派发可用（本 change 全部 L2 盲审通过此路径）；claude code 下 subagent_type 派发模板保留（6 prompt 7 锚点 + l3-review.sh:215 + l2-detect.sh:110 双模式注释行）
