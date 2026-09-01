# REQUIREMENT · correction-hygiene-state-guard

> change-id: correction-hygiene-state-guard · 阶段 1（REQUIREMENT）· 2026-08-31

## 用户故事

作为 flow-kit 用户在混合工具链环境（flow-kit + 其他流程系统如 chisel-skill 共存）的维护者，
我想 correction 文件（`.flow-active.correction`）不再无限累积陈旧 violation、外来状态文件不再导致 hook 静默短路或刷屏，
以便每次查看 stop-hook-report 时看到的是真实当前状态（而非「L2 缺失」误判表象）。

## 验收准则（AC · Given/When/Then）

### AC-1 · 去重（同 check+field 收敛为最新一条）

- **Given** 33 号 `_fai_append_violation` 写入路径，且 correction 中已存在 `check=X, field=Y` 的 state-integrity 类 violation
- **When** 再次写入同 `check=X, field=Y` 的 violation
- **Then** violations 数组中该 check+field 只保留最新一条（旧条目被替换，数组长度不增加）

### AC-2 · 容量上限（防御性 backstop · >10 FIFO）

- **Given** 33 号写入路径，且 correction 中 state-integrity 类 violation 已达 10 条
- **When** 写入第 11 条 state-integrity 类 violation
- **Then** 数组最多保留 10 条（最旧一条被淘汰），compliance 类条目（28 号写入）不受影响
- **说明**：当前 9 种 check 名的 field 实参全为常量 → 去重后最多 9 个互异键，AC-2 触发条件（第 11 条）在当前场景**不可达**。本 AC 保留为**防御性 backstop**（防未来引入动态 field 时的无界增长），bats 用合成 fixture（同 check 不同 field 构造 11+ 条）验证；去重与容量执行顺序：先 AC-1 去重、后 AC-2 FIFO

### AC-3 · 健康清零（state-integrity 类清空）

- **Given** `.flow-active` 为合法 flow-kit JSON 且本轮 33 号全部检查通过（无新 violation）
- **When** 33 号执行健康清零
- **Then** correction 中的 state-integrity 类 violation 全部清空（枚举：corrupt_json / change_id_dangling / change_id_null_with_dirs / phase_artifact_missing / pipeline_phase_artifact_missing / pipeline_gate_not_passed / pipeline_gate_phase_mismatch / stale_updated_at / token_spent_unmaintained），l2-missing / model-missing / foreign-state / compliance 条目保留

### AC-4 · l2-missing 退场

- **Given** correction 中存在 type 含 `l2-missing` 的条目（`type=l2-missing` 独立条目，或与 state-integrity 合并的标签 `l2-missing+state-integrity`——33 号 merge 逻辑会产出后者）
- **When** 29 号检测到对应 IR 文件已含 `## L2 盲审` 段（或 gate_config 非 both）
- **Then** 清除 l2-missing 语义：type 为纯 `l2-missing` → 整文件清除（对齐 `write_model_missing_clear` 文件级 rm 范式）；type 为合并标签 `l2-missing+state-integrity` → **剥离 l2-missing 段**（type 改回 `state-integrity`，violations[] 原样保留）——**匹配用 `contains("l2-missing")` 而非精确相等**（合并标签会破坏精确匹配）
- **And** 清除动作写一行 stderr 审计（记录清除前 type 标签）
- **And（盲审 R2）** 退场检测置于 29 号 Gate 3（`fk_independent_review_gate_active L3` early-exit，L47-50）**之前**执行、与 L3 激活判定解耦——保证 gate_config 非 both（如 both→L2 切换）时退场仍可达
- **And（盲审 R1）** 29 号的 l2-missing **写入**（`_write_l2_missing_correction`）同步改 compliance-priority 条件写（对齐 `write_model_missing_correction` correction-file.sh:116-123 范式：`.type=="compliance" and violations>0 then . else $new end` + mktemp 原子写），correction 已有 compliance 条目时不得被 l2-missing 覆写摧毁

### AC-5 · 外来状态判定与让位

- **Given** `.flow-active` 存在但 `jq empty` 解析失败（非 flow-kit JSON，如 chisel-skill 写入的 YAML）
- **When** 33 号执行完整性检查
- **Then** 判定为「非 flow-kit 状态文件」→ 跳过 pipeline 检查 + 不再追加 corrupt_json + correction 写一条去重后的 `foreign-state` note（同 check 只写一次）+ stop-hook-report 提示一次
- **And** 29 号同条件下静默退出（不写任何 correction），31/32/34 号保持既有静默跳过行为（pipeline 专用模块，不写 note）

### AC-6 · 外来接管时清空陈旧 state-integrity

- **Given** 判定为外来状态文件，且 correction 中残留既有 state-integrity 类 violation（源自对非 JSON 文件的误判）
- **When** 33 号执行外来让位处理
- **Then** 既有 state-integrity 类 violation 一并清空（外来接管后全部失效），**保留集合显式如下：l2-missing / model-missing / compliance / foreign-state 条目全部保留**；若 type 为合并标签（如 `l2-missing+state-integrity`），清空后剥离为 `l2-missing`（violations[] 清空），correction 中恰好新增 1 条去重后的 foreign-state note

### AC-7 · 绝不转换/覆盖/删除外来文件

- **Given** 外来状态文件（YAML）
- **When** 本 change 的 hook 逻辑执行
- **Then** 不产生任何对该文件的写入/删除/转换动作（文件 mtime 与内容不变），不引入 YAML 解析依赖（不引 yq/pyyaml）

### AC-8 · 既有全量回归不劣化

- **Given** 本 change 全部实现落地
- **When** 运行全量 bats + make check
- **Then** bats 全绿（基线 752+，实测当前 772，新增用例全过）+ make check 四门（test/lint/check-validate/check-test-sync）通过 + test/ 与 flow-kit-bundle/test/ 双源一致（diff -rq 零差异）

### AC-9 · chisel_env 场景模拟收敛

- **Given** 输入 = YAML `.flow-active`（外来）+ 陈旧 correction（50 条，含 43 条重复 corrupt_json + 6 条陈旧 artifact_missing + **1 条 l2-missing**）
- **When** 新 hook 链首次执行
- **Then** 首轮收敛：state-integrity 类清空（43+6 条消失）+ correction 中 l2-missing 保留（type 剥离为 `l2-missing`）+ 恰好新增 1 条 foreign-state note（violations 数组终态 = 1 条 foreign-state note + l2-missing 独立条目）；后续 Stop 零新增（数组长度不变）

### AC-10 · compliance 条目不受本 change 影响（沿 ADR-013 精神）

- **Given** correction 中混有 28 号写入的 compliance 类 violation（type=compliance 或同文件 violations[] 中的 compliance 条目）
- **When** 本 change 的去重/容量/健康清零/外来清空任一逻辑执行
- **Then** compliance 类条目被原样保留（不参与去重、不被 FIFO 淘汰、不被清空）
- **依据注**：沿 ADR-013 的 compliance 优先精神（该 ADR 只定义文件级 type 覆盖优先级）；**violations[] 数组级条目保留为本 change 新决策**，2-design 需独立论证（不假设 ADR-013 已背书）

## 范围切分

### v1（本次必做）

- 33 号：去重（同 check+field）+ 容量上限（state-integrity 类 10 条 FIFO）+ 健康清零（9 种 check 名枚举）+ 外来让位（yield + foreign-state note 单条化 + 清空陈旧 state-integrity）
- 29 号：jq 失败 yield 改造（静默退出，不写 correction）+ l2-missing 退场（对齐 write_model_missing_clear）
- correction-file.sh：新增共享去重 helper（不改既有 4 函数签名）
- 新增 bats：test_correction_hygiene.bats（AC-1~AC-7/AC-9/AC-10 全覆盖）+ 双源同步
- 部署：CC + opencode 双平台运行时 hooks 更新（integration 阶段 md5 双侧校验）

### v2（下次再说）

- 30-ai-analyze.sh 凭证链（不同域，维持既有 v2 候选）
- 多模块 foreign-state note 统一去重（若未来 29/31/32/34 也需写 note 时的跨模块去重设计）
- correction 按类型分段存储（替代当前 violations[] 混写，彻底消除作用域判定复杂度）
- YAML 写入源核实后的正式格式协商（与 chisel-skill 生态对接，需对方配合）

### out（永远不做）

- 不支持 YAML 解析/转换（不引 yq/pyyaml 依赖进 hook 链）——外来格式一律让位，不解读
- 不改 chisel-skill 的状态约定，不触碰 chisel_env 仓库任何文件
- 不改 `.flow-active` 的 JSON schema
- 不动 gate 核心链语义（independent-review-gate.sh / fk_validate_done_marker / 00-gate.sh 的 .done 校验与 gate 判定逻辑）
- 不改 31-auto-advance.sh / 32-fallback-guard.sh / 34-archive-commit-check.sh 的静默跳过行为

## 非功能性需求

- **性能**：全部逻辑为纯 env/文件读取 + jq 操作，零网络调用；延续既有 hook 链性能基线（无新网络/子进程开销，不设数值硬门槛）
- **安全**：绝不触碰外来状态文件（无写/删/转）；凭证类内容不落盘（延续 l2l3-cross-platform 红线，本 change 无新凭证处理）
- **兼容性**：CC + opencode 双平台行为一致（部署 md5 双侧校验）；既有 .flow-active JSON schema 不变
- **可观测性**：外来让位时 stop-hook-report 提示一次；note 保留原始错误文本供人工判断；健康清零/l2-missing 退场动作写 stderr 审计行

## 依赖假设

- 33 号实际写入的 check 名集合 = 9 种（AC-3 枚举，2-design 需以源码核实）
- `.flow-active.correction` 的 violations[] 数组由 33 号（state-integrity）与 28 号（compliance）混写（AC-10 依据，ADR-013）
- chisel_env YAML 写入源未定（2-design 必查项：auto-checkpoint.sh / chisel-skill 运行时 / 外部流程）
