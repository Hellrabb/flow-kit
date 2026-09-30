# ADR-032: 门禁依赖统一 fail-closed 语义

- **状态**: Proposed（随 health-fix-2026-09c 落地后 Accepted）
- **日期**: 2026-09-29
- **关联**: health-fix-2026-09c DESIGN D4（C12/TD-135）· CONTEXT 已锁决策「门禁依赖统一 fail-closed」

## 背景

2026-09-29 巡检 C12 实证同一依赖（jq / `.flow-active` 合法性）在不同层的失败语义不一致：安装期 `install_hooks.sh:189-192` fail-closed ✅；运行期 PreToolUse `independent-review-gate.sh:65,113`、`auto-checkpoint.sh:64` 为 `|| exit 0` fail-open ❌ —— jq 缺失或状态文件损坏时 hook **静默放行**，门禁形同虚设。`common.sh:226` 有 jq 依赖断言、`independent-review-gate.sh:33-37` 有 source 后 declare -f 断言（范式皆在），但 **pre-tool-use 三子库（gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh，被 independent-review-gate.sh:42-46 source）与 auto-checkpoint.sh 无任何断言**。

## 决策

1. **统一语义**：门禁依赖缺失/非法时门禁必须失败，不得降级放行。注入面共三类：① jq 缺失；② `.flow-active` 非法 JSON；③ **source 后关键函数缺失/半安装**（declare -f 断言覆盖）。注：「函数遮蔽/重定义为空体」显式移出注入面——declare -f 只证存在不证行为，遮蔽注入按本机制不产生 rc≠0，不承诺做不到的反向控制（DESIGN D4 对齐）。
   - PreToolUse hook：`exit 2`（block 该次工具调用）+ stderr 修复指引（装 jq / 修 .flow-active / 重装 flow-kit）；
   - Stop 链检查器：`exit 1` + `module_output "error"` 告警；
   - make check 判据：`exit 1`（既有二值约定）。
2. 推广既有断言范式：pre-tool-use 三子库（gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh）source 后补 declare -f 断言（对齐 independent-review-gate.sh:33-37 范式）；jq 存在性断言对齐 common.sh:226 范式；stop/lib l3-* 三库（l3-review.sh / l3-prompt.sh / l3-section.sh）作为 AC-8 字面之外的纵深一并补齐（超出部分在 CHANGE 显式注明）。
3. 反向控制入 bats：PATH shim 隐藏 jq / 注入非法 JSON / 删函数·改名注入（如将 `_fk_check_gate_config_tamper` 改名使其 source 后缺失），断言各注入面 rc≠0（fail-closed 可测）。

## 备选与理由

- **维持 fail-open + 告警**：已实证静默放行风险（门禁在缺依赖环境退化为无门禁）；「方便」不构成理由。
- **仅安装期拦截**：挡不住运行时环境漂移（卸载 jq / 状态文件损坏发生在安装之后）。

## 后果

- 正面：门禁语义全层一致；依赖缺失从静默降级变显式阻断。
- 负面：无 jq 环境用户体验变硬（hook block）——以错误信息指引 + 安装期前置暴露缓解。
- 推翻代价：中（逐门禁回退语义 + bats 反向控制同步改）。
