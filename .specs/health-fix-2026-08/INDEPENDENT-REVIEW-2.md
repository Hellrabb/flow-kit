# Independent Review · Phase 2 (DESIGN) · health-fix-2026-08

**审查时间**: 2026-08-04
**gate_config**: `2-design: L2`
**Artifacts**: `.specs/health-fix-2026-08/DESIGN.md` (rev 1 → rev 2 post-fix)

---

## L2 盲审 · Oracle (bg_5aa6a574)

**Verdict**: FAIL (rev 1) → PASS (rev 2)
**Duration**: 2m 47s

### 5 条发现 + 修复状态

| # | 严重度 | 发现 | 修复 |
|---|---|---|---|
| F1 | **HIGH** | Fix B 与运行时矛盾: `common.sh:103-110` 回退 `${HOME}/.claude/stop-hook.json` · gate-integrity 注释"module_enabled 恒 false" · 移除致 user-scope hooks 静默失效 · risk 3 "无/无" 错误 | ✅ **删除 Fix B** · L97 保持两 scope 都装 · REQUIREMENT AC-C1 反向修正（断言 user-scope **正确写** stop-hook.json） |
| F2 | **MEDIUM** | Fix A 守卫在 install.sh 主路径提前触发（source L26 早于 resolve_paths L153）· "no-op"声明错 · FLOW_KIT_PLATFORM=auto 可在 set -e 下崩 install.sh | ✅ **守卫移入 install_hooks() 函数体** · install.sh:153 先于所有调用 → 真 no-op · `case` 校验平台值（拒绝 auto/非法） |
| F3 | LOW | FLOW_KIT_PLATFORM 新 env 接口未文档化 | ✅ Fix C header 注释增加 FLOW_KIT_PLATFORM 说明 |
| F4 | LOW | L190 PLATFORM 引用未在时序图枚举 | ✅ §1.1 时序图已补充（Fix A 覆盖 · 无修复缺口） |
| F5 | MEDIUM | 无主路径 (install.sh) smoke 测试 · AC-C2/D2 验证未接线 | ✅ §6 增加主路径 smoke（`install.sh --project --hooks-only` exit 0）· §5 step 3 接线 lint |

### 跨阶段反馈 (→ Phase 1 REQUIREMENT)

F1 发现 REQUIREMENT A5/US-4/AC-C1/in-scope 的"stop-hook.json 是项目级"前提与运行时矛盾。已修正:
- US-4: 从"user-scope 不写"改为"user-scope **正确写**"（保护运行时回退）
- AC-C1: 反向（断言 user-scope **写** stop-hook.json）
- In-scope (1): 删除 scope guard · 改为"不做 scope guard"
- A5: 删除"L97 语义不当"· 改为"仅 paths.sh 自加载"

---

## 综合裁决: **PASS**

DESIGN rev 2 满足全部 L2 要求:
- Fix A 方向正确 · 放置合理（函数体内 · 真 no-op）· 平台值已校验
- Fix B 已删（运行时证据充分）
- §6 覆盖全部 AC + 主路径 smoke
- 风险表修正（4 项均准确）
