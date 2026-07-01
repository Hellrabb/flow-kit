# CHANGE: 独立 review 模型配置化 + gate-config 预设

- **Change ID**: improve-independent-review
- **创建日期**: 2026-07-01
- **路径建议**: 中等
- **状态**: draft

---

## Why（为什么做）

1. **L3 独立 review 模型硬编码**：`29-independent-review.sh` 和 `30-ai-analyze.sh` 中模型名硬编码为 `deepseek-v4-flash`，无法跟随 session 环境变量（`ANTHROPIC_DEFAULT_HAIKU_MODEL`）自动切换。用户已在 `~/.claude/settings.json` 中配置了完整的 API 环境变量（`ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_DEFAULT_HAIKU_MODEL`），但 hook 脚本完全无视这些配置。

2. **API 路径依赖 onecli proxy**：hook 脚本优先走 `onecli proxy curl`，兜底才走直连。但当前环境通过 DeepSeek Anthropic 兼容 API（`$ANTHROPIC_BASE_URL`）直接访问，根本不经过 onecli，导致多一层不必要的间接调用。

3. **gate-config 手写 JSON 繁琐**：`/flow goal --gate-config` 需要完整 JSON 字符串（如 `'{"1-requirement":"independent","2-design":"independent","6-review":"independent"}'`），每次设定 goal 都要手敲，易出错、体验差。

## What（做什么）

- 修改 `29-independent-review.sh` 和 `30-ai-analyze.sh`：模型名从 `$ANTHROPIC_DEFAULT_HAIKU_MODEL` 环境变量读取，API 直连 `$ANTHROPIC_BASE_URL`（用 `$ANTHROPIC_AUTH_TOKEN` 鉴权），移除 onecli proxy 优先路径
- 更新 `stop-hook.json`：`ai.model` 和 `independent_review.model` 默认值指向环境变量，脚本层优先读 env var
- 扩展 `/flow goal --gate-config`：支持 8 种预设名（`full`/`code-only`/`design`/`requirement`/`review`/`plan`/`design-review`/`requirement-review`）+ 数字简写（`1`/`1,2`/`6`/`1,2,6` 等），保留完整 JSON 兼容

## 影响面

- [x] 影响 `REQUIREMENT.md`（新增 AC）
- [x] 影响 `DESIGN.md`（API 路径变更需设计文档）
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不改动 L2 盲审 prompt 本身（`L2-blind-review.md`）
- 不改动 `28-weak-model-compliance.sh`（弱模型合规检测）
- 不触及 onecli 在其他 hook 模块中的使用场景（如有）
- 不新增 hook 模块，只在现有脚本内修改

## 验收线（粗粒度，不是 AC）

- `29-independent-review.sh` 和 `30-ai-analyze.sh` 的 L3 模型名从环境变量 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 读取，不再硬编码
- API 调用直连 `$ANTHROPIC_BASE_URL`，onecli proxy 降级为可选（有则用，无则直连不报错）
- `/flow goal --gate-config full` 等价于手写三阶段全开 JSON
- `/flow goal --gate-config 6` 等价于 `{"6-review":"independent"}`

## 风险与未知

- 修改 hook 脚本可能影响 stop 链执行时序。需确保向后兼容：env var 未设置时回退到当前默认值 `deepseek-v4-flash`
- gate-config 预设名需与现有 `/flow` skill 解析逻辑兼容，不能破坏已有 JSON 格式

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
