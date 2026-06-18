# REVIEW: pipeline-goal

- **Change ID**: pipeline-goal
- **审查日期**: 2026-06-18
- **审查范围**: 10 files, +396/-15

---

## 第一轮 · Spec 合规审查 ✅

逐条 AC 对照：

| AC | 描述 | 实现位置 | 判定 |
|---|---|---|---|
| AC-1 | 设定 Pipeline Goal | SKILL.md (--pipeline) + GO.md (展示) | ✅ |
| AC-2 | 4→5 Toll-gate 暂停 | 4-dev.md §6.1 | ✅ |
| AC-3 | 5→6 Toll-gate 暂停 | 5-test.md Toll-gate 段 | ✅ |
| AC-4 | 6→7 Toll-gate 暂停 | 6-review.md Toll-gate 段 | ✅ |
| AC-5 | 关键门禁失败暂停 | 6-review.md Gate 失败段 | ✅ |
| AC-6 | 向后兼容（单阶段 goal） | 所有 prompt 的 `scope // "phase"` 守卫 | ✅ |
| AC-7 | Pipeline 状态恢复 | GO.md Goal 注入段（current_phase + phases_done） | ✅ |
| AC-8 | Pipeline 完成 | 7-integration.md Pipeline 完成段 | ✅ |
| AC-9 | 动态门禁配置 | SKILL.md (--gate-config) + 6-review.md (gate_config 判定) | ✅ |
| AC-10 | Phase 回退 | 5-test.md (回退入口) + 6-review.md (回退执行) | ✅ |
| AC-11 | Toll-gate 批量确认 | 4-dev.md (auto_advance 入口) + 5-test.md + 6-review.md (auto_advance 判定) | ✅ |
| AC-12 | Sub-goal 自动提取 | 4-dev.md §6.2 + 5-test.md + 7-integration.md (汇总) | ✅ |

**合规率**: 12/12 (100%)

## 第二轮 · 代码质量审查 ✅

### 正面发现

- ✅ jq 表达式全部验证通过（5-test 第 1 轮）
- ✅ 协议一致性：toll-gate / auto_advance / phases_done / rollback 在 4 个 prompt 中一致
- ✅ 禁动清单严格遵守：0-3 阶段 prompt 未修改
- ✅ 无硬编码路径
- ✅ Markdown 结构完整
- ✅ jq 原子写入模式延续使用（`.tmp && mv`）
- ✅ 向后兼容：所有新字段都有 `//` 默认值守卫

### 建议（非阻塞）

| # | 建议 | 严重度 | 说明 |
|---|---|---|---|
| S1 | 5-test/6-review 的 jq read 命令与 write 命令混在同一代码块中 | 🟢 Minor | 可读性略差，但功能正确。改为分两个代码块（"检测"和"写入"）更清晰 |
| S2 | T04-T06 缺少独立 SUMMARY.md | 🟢 Minor | T03 有 SUMMARY，T04-T06 合并提交无独立 SUMMARY。建议后续补上 |
| S3 | gate_config 默认级别表在 6-review.md 中硬编码 | 🟡 Major | 未来新增检查项需手动更新默认表。建议提取为独立 reference 文件 |

## 第三轮 · UI（跳过）

非前端项目。

---

## 审查结论

**✅ 通过** — 无 Critical 问题。12/12 AC 覆盖，协议一致性验证通过，向后兼容。

### 待处理

- [ ] S3 (🟡): 考虑将 gate_config 默认级别表提取为独立 reference 文件（可在后续 change 处理）
- [ ] S2 (🟢): 补 T04-T06 SUMMARY.md（nice-to-have）
