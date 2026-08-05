# T04-SUMMARY — opencode 环节④实测：env 透传 + L3 API 直连 + 模型绑定层

- **任务**: T04 · status: done · 2026-08-05
- **verify**: `test -s EVIDENCE-4-opencode-env-model.md` → PASS (60 lines)
- **self-review (6 维快查)**:
  - 可读性: 三部分（(a) env 链 / (b) 模型绑定层 / 现象 / 结论）✓
  - 证据链: 每结论附实测命令+输出（env 扫描 NONE / fk_resolve_model 空串 / opencode models 列表 / task 路由对照）✓
  - 范围: 仅写 EVIDENCE-4，未触代码/禁动清单 ✓
  - 脱敏: 凭证未涉及（无 env 可泄露）✓
  - 真实性: 全部实测（env grep / fk_resolve_model 执行 / models 列表 / dry 解析）✓
  - diff 边界: 单一新文件 ✓
- **关键发现**:
  1. **根因 #3**: L3 API 直连（l3-api.sh env-var-first 直连 anthropic.com）是 claude code 架构；opencode 用 auth.json provider 认证，不注入 ANTHROPIC_* env → _l3_call_api 无凭证、fk_resolve_model 空 → L3 return 3 降级（v2 修复方向，触 l3 链禁动）
  2. **根因 #2 实证升级**: 模型绑定三层中「子 agent 覆盖层」model: sonnet 不可解析 → qa-expert 挂起；「Category 路由层」正常（quick→deepseek-v4-flash 4s）。模型由 Category 路由层或子 agent 覆盖层决定
  3. opencode 可用模型无 sonnet/无 anthropic provider（全为 opencode/*、alibaba-token-plan-cn/*、deepseek/* 等）
  4. ADR-020 三层模型选择实测成立（Harness 未配置 / Category 生效 / 覆盖层失败点）
- **deferred**: 无
- **fix_rounds**: 0
