# T04-SUMMARY · _l3_build_prompt 反馈优先重排 + D5/D6/D7

## 交付物
- `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`：phase 6/7 双位点 D5、phase 7 段序重排、D6 checklist、13 处 head -c 全替换、jq 模板重排 + 总输出截断
- `test/test_l3_pipeline_fix.bats`：5 个 T04 用例 + `_build_phase7_tree` helper（active/archive 两布局 × 7 工件 ≥3KB + CL/LESSONS ≥1500B）

## TDD 证据（fix_rounds = 1，含 1 次既有用例回归修复）
- RED：5/5 失败；GREEN 后 33/33 全绿；`make check` 全绿（bats + shellcheck + validate + 双源）

## 关键变更
1. **段序（D1/§2）**：phase 7 内 `=== CHANGELOG.md ===` → `=== LESSONS.md ===` → `=== 产物目录 ===` → 7 文件循环 → 总截断
2. **D5 双位点**：`*/.specs/archive/*` → dirname×3，否则 dirname×2（phase 6 与 7 同构）；实现用 `if [[ == */.specs/archive/* ]]` 而非嵌套 case——既有用例 AC-1(phase6) 的 sed 按「首个 esac」提取 case 块，嵌套 case 会截断提取范围
3. **D7**：10 文件形 → `_l3_utf8_head_bytes`；3 流形 → `_l3_utf8_head_stream`；`grep -o 'head -c' | wc -l` = 2（两 helper 体内各 1）
4. **jq 模板重排（对 REQUIREMENT AC-1① 字面合规的最小一致设计）**：固定指令（独立性声明 + checklist + JSON 回复契约）移到工件之前，`jq -nr … | _l3_utf8_head_stream "$max_chars"` 总输出封顶——截断只可能切工件尾部，永不切 JSON 契约；各 phase 统一受益
5. **D6 checklist**：`T0x-SUMMARY（如已生成）` + `项目级 .specs/CHANGELOG.md 是否更新（CHANGELOG 不入归档目录，勿因归档目录缺失报错）`

## 偏差记录（设计裁决）
- REQUIREMENT AC-1① 要求「总输出 ≤20000 字节」，但旧模板把 JSON 指令放工件之后——若只截工件，总输出恒超 max_chars ~700B；若截总输出则切掉 JSON 契约破坏 L3 解析。裁决：指令前置 + 总输出流式截断，两者兼得（见 T04-SUMMARY 关键变更 4）

## 六维自查
- ✅ verify：TASK.md T04 verify 双条件（bats + head -c 计数=2）均过
- ✅ diff ⊆ write_files：l3-prompt.sh + test_l3_pipeline_fix.bats
- ✅ 沿用抽象：T01 两 helper、T02 提取器、T03 注入；无新依赖
- ✅ 禁动清单：l3-review.sh 组装层 L81/L103 preamble 前置未动；29 号/common.sh 未触
- ✅ 既有锚全部存活：AC-1(phase6 git diff) / AC-5(inject disclaimer) / T01×7 / T02×7 / T03×6
- ✅ 注释：「反馈优先」「固定指令置于工件之前」两行 = 反自然顺序的架构意图锚（DESIGN D1 + 本任务裁决）
