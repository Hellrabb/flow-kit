# T01-SUMMARY · UTF-8 安全截断 helper 两变体

## 做了什么
在 `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` 新增两个 helper（DESIGN D7，置于 `_l3_inject_context` 之前）：
- `_l3_utf8_head_bytes(max_bytes, file)` — 文件路径形，委托流形实现
- `_l3_utf8_head_stream(max_bytes)` — stdin 流形：head -c 取字节 → od 字节级扫描尾部续字节（0x80-0xBF，窗口 ≤5）→ lead 判定回退。三态：lead 本身被截（back=0 尾字节 ∈ 194-244 → 回退 1）/ 续字节被截（back < expect-1 → 回退 back+1）/ 序列完整（back == expect-1 → 不回退）

## 改动文件
- flow-kit-bundle/hooks/stop/lib/l3-prompt.sh（+61 行，纯新增）
- test/test_l3_pipeline_fix.bats（+77 行：7 个 T01 用例）
- flow-kit-bundle/test/test_l3_pipeline_fix.bats（镜像同步——AC-7 commit gate 强制，非独立编辑）

## TDD 证据
- RED：7 用例先写，全红（`_l3_utf8_head_bytes: 未找到命令`，tap 12-18）
- 首版 GREEN 15/15 中 2 用例仍红 → 定位切点恰在 lead 后的漏判（尾字节非续字节时未查 lead）→ 补 back=0 lead 检查 → 全绿
- verify 输出：`bats test/test_l3_pipeline_fix.bats` → 15 ok, 0 fail；全量 `npx bats test/` → all passed（commit gate 证实）

## 6 维自查（内置快查 · 生产代码改动）
- R1 认知过载：流形 ~55 行（边界三态密度必要，线性无深嵌套）✅
- R2 变更传播：零既有代码改动（纯新增函数）✅
- R3 知识重复：bytes 委托 stream，核心逻辑单点 ✅
- R4 偶然复杂：无投机扩展点 ✅
- R5 依赖混乱：N/A（lib 内部）✅
- R6 领域扭曲：命名即领域（utf8_head_bytes/stream）✅

## 沿用既有抽象 grep（R6.4）
- `grep -rn 'utf8|UTF-8' flow-kit-bundle/hooks/stop/lib/` → 0 命中 → 新建（DESIGN D7 已批准）
- `smart_truncate`（l3-truncate.sh:57）= 字符级语义，与字节预算语义不匹配 → DESIGN D7 裁定不沿用
- LESSONS 扫描：L-342/344（head -c 截断丢尾部）——本 change 正是该教训的修复，方案一致非撞车

## 越界检查（R6.5）
- TASK write_files：2 项；实际 diff：3 文件（第 3 项 = flow-kit-bundle/test/ 镜像，同内容同步，AC-7 commit gate 强制）
- 越界：0（镜像同步在 TASK T06 语义内提前执行）

## 已知接受
- 孤立续字节（lead 非法/ASCII 前缀）→ 丢弃孤立续字节（垃圾进垃圾出兜底，测试未覆盖非法序列——fixtures 均合法 UTF-8）
- commit ae93163
