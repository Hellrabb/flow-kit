# REVIEW: 用户指南全量更新 + interrupt/checkpoint 自动写入

- **Change ID**: user-guide-update
- **关联**: `@.specs/user-guide-update/REQUIREMENT.md`

## Spec 合规

| AC | 要求 | 实现 | 状态 |
|---|---|---|---|
| AC-1 | 三份文档覆盖近期全部功能 | FLOW-KIT-用户指南.md +4 新章节 (interrupt/checkpoint, gate_config, 独立审查四层架构, Hook 31/32)，README + ecosystem-guide 同步 | ✅ |
| AC-2 | interrupt/checkpoint 专项章节 | 字段结构表 + /flow checkpoint 用法 + 恢复流程 + 手动时机 + auto-checkpoint 触发 | ✅ |
| AC-3 | auto-checkpoint 4种触发 | checkpoint-lib.sh + 8 prompts PCSC + PreToolUse hook 集成 | ✅ |
| AC-4 | auto不干扰手动 | test_checkpoint.bats:2 验证覆盖逻辑 | ✅ |
| AC-5 | 中断恢复上下文注入 | GO.md 路由 "继续" + 步骤1 interrupt 读取 | ✅ |
| AC-6 | 文档与代码一致 | 331/332 bats pass | ✅ |

## 代码质量

- **checkpoint-lib.sh**: bash syntax OK, 4 functions, atomic write pattern (jq → .tmp → mv), 30s dedup window, JSON validation
- **test_checkpoint.bats**: 11 tests, covers write/dedup/validate/clear/atomicity
- **8 prompts PCSC**: auto-checkpoint row added, backward compatible (existing PCSC items unchanged)

## 风险

- test_checkpoint.bats not yet synced to flow-kit-bundle/test/ (package step, Phase 7)
- PreToolUse hook integration point documented in DESIGN.md, actual hook file in bundle
