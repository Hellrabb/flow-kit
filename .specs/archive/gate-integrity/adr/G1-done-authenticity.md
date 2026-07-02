# ADR-G1: .done 真实性校验（KVP + D7 常见写向量握手锚点 + 两层时机）

- **Status**: Proposed（gate-integrity change · 2-design）
- **Date**: 2026-07-01 · 修订 2026-07-02a（L3 两层时机）/ 2026-07-02b（L2-R1 D7 握手）/ 2026-07-02c（L2-R2 D7 改 B' 常见向量挡 · R5b/R9）
- **关联 AC**: AC-1（.done 真实性 5 类威胁）

## Context

现状 `independent-review-gate.sh:54` 用纯 `[ -f "$done_marker" ]` 存在性检查 `.done`，agent `touch` 空文件即绕过。Phase 1 dogfood 实证 5 类威胁：

1. 空 `.done`（`touch`）
2. 含伪造 review 证据
3. 主 agent 用 Write 自产（未经子 agent）
4. 移花接木（复用旧阶段 / 其他 review 的合法 `.done` 到新 goal/session）
5. 混合篡改（改子 agent 产出的合法内容）

L2 两轮 + L3 均指出 AC-1 须依赖 agent 难伪造的外部锚点。**L2-R2 R1/R6 进一步证伪"绝对挡"**：单机单环境下 hook 能写的 agent 经 Bash 都能写（Write/Edit 不触发既有 PreToolUse matcher=Bash；Bash `echo >`/`tee`/`cp` 也能写），无 agent 不可访问锚点。故 v1 取 **B'**（挡常见写向量 + 诚实降级 L70，L103 重定义）。

## Decision

1. **`.done` 强制 KVP 格式**：
   ```
   phase=<N>
   change_id=<change-id>
   written_by=review-subagent
   written_at=<ISO8601>
   L2_verdict=<pass|fail>
   L3_verdict=<pass|fail|skipped|unknown>
   session_id=<CLAUDE_CODE_SESSION_ID>
   artifacts=<空格分隔文件列表 · L2-R1 R7>
   ```

2. **`fk_validate_done_marker` 四层校验 · 两层时机**（L3 critical#1/2/3）。函数签名 `fk_validate_done_marker <path> <phase> <change_id> <tier>`，`<tier>`=`write`（Tier 1）/`transition`（Tier 1+2）：

   **Tier 1 · Write Gate（元数据快校验 · 不依赖下游产物）**
   - T1 非空（`[ -s ]` + 行数 > MIN）
   - T2 KVP 匹配（phase / change_id / written_by 与当前上下文一致）

   **Tier 2 · Transition / Stop 后置（产物已齐）**
   - T3 **D7 常见写向量握手锚点（挡威胁③ + ⑤-L3 常见路径 · B'）**：`.flow-active.independent-review` 握手存在 + `written_by=stop-hook-29` + `verdict` 与 `.done` `L3_verdict` 一致 + `phase` 匹配。握手由 29 号独占写（agent 写被 D7 path-guard 拦常见向量）→ 主 agent 难自产合法握手 → 威胁③ + ⑤-L3 **常见路径挡**
   - T3b **SESSION_ID 跨会话锚点（挡威胁④）**：`.done` `session_id` 须与当前会话一致。session_id 是 env var agent 可读，**只挡跨会话复用④**；跨 session 合法推进由 phases_done 短路兜底
   - T4 **verdict 绑定（威胁⑤-L2）**：.done `L2_verdict` 与 .md L2 段 Verdict 行比对（.md agent 可写 → ⑤-L2 v1 仅靠比对，v2 加密补）

3. **phases_done 短路**：phase ∈ `goal.phases_done[]` → 放行（含历史 `written_by=main-agent` 的 .done）

4. **D7 29 号独占写握手 + PreToolUse 常见写向量拦（B' · L2-R2 R1/R6）**：
   - **matcher 扩面**：`install_hooks.sh:136/153` 的 PreToolUse matcher 从 `"Bash"` 扩到 `["Bash","Write","Edit"]`（或 `""` 全匹配）
   - **path-guard（is_handshake_write）覆盖三类写向量**：
     - Write tool：`tool_input.file_path` 含 `.flow-active.independent-review` → deny
     - Edit tool：同上 → deny
     - Bash：命令匹配写该路径正则（`>`/`>>`/`tee`/`cp ... path`/`mv`/`sed -i`/`dd of=path`/heredoc）→ deny
   - **29 号 hook 子进程 bash 直写不经 agent tool → PreToolUse 不拦 → 独占写**
   - 29 号写：`{phase, status:"done", verdict, l3_token:hash(L3响应), written_by:"stop-hook-29", written_at}`
   - **fail-open（R9）**：path-guard 与 is_handshake_write 在 lib source 失败 / jq 不可用时 **exit 0**（matcher 扩面后不能卡死 agent 正常 Write/Edit）
   - **诚实边界**：exotic Bash（`python -c 'open(...)'`/`dd`/变量间接/base64 解码）可逃 → v1 **非绝对挡**，留 v2 加密（L70 已 L103 重定义）

5. **is_phase_write 扩展（L2-R2 R5b）**：除 `.phase =` / `.goal.current_phase =`，**也拦 `.goal.phases_done` 写信号**——agent 不能 jq 把当前 phase 塞进 phases_done 触发短路绕过

6. **v1 用 D7 常见向量握手（③⑤-L3 常见路径）+ session 锚点（④）+ 字符串绑定（⑤-L2）**；绝对挡留 v2 加密
7. **fail 策略区分（D9 · L2-R3 R3）**：Tier 1/2 校验（T1-T4）+ ⑥检测 = **fail-close**（jq 不可用 / source 失败 / 解析异常 → exit 2 deny + 可读错误——agent 不能靠制造 hook 内部错误放行）；D7 path-guard = **fail-open**（拦不住 Bash 写保护路径不卡 agent 工具流）。两者不可笼统合并
8. **phases_done 合法写入通路（D10 · L2-R3 R9）**：`is_phase_write` 扩拦 `.goal.phases_done` 写信号——agent 经 Bash/Write/Edit 写该字段一律 deny；只有 transition hook 子进程能写（与 29 号独占写握手同模式）。合法 phase 推进走 hook 子进程，dogfood 本 change 自身 transition 也走此通路（不自卡）

## Consequences

- **正**：
  - 威胁①②④ 完全挡（空 / KVP 伪造 / 跨会话移花接木）
  - **威胁③ + ⑤-L3 v1 挡常见写向量**——D7 path-guard 拦 Write/Edit tool + Bash 重定向/cp/mv/sed/tee，主 agent 难以常规手段自产合法握手（守 L70 重定义后的 v1 立场）
  - 统一校验函数三处入口复用；phases_done 短路避免回溯历史
- **负**：
  - **威胁③ v1 非绝对挡**——exotic Bash 逃逸向量（python -c/dd/变量间接）可伪造握手；完全挡需 v2 加密签名（R5 · L70 已诚实降级）
  - 威胁⑤-L2（.md L2 verdict agent 可同篡）v1 不完全挡，靠 T4 比对，v2 加密补（R5）
  - matcher 扩面引入 fail-open 风险（R9）——hook 挂了必须放行而非卡死
- **残留威胁⑥（R8）**：agent 篡 `gate_config[phase]=false` 跳 gate。**v1 不防**（.flow-active gitignored，原"纳 git 跟踪"载体不存在），强防留 v1.5（`.specs/<id>/.goal-snapshot.json` 入库 + transition diff）
- **历史 .done 处理（R11）**：phases_done 短路 + archive 不校验 + 新规范仅约束上线后新写
- **后续**：v2 加密签名完全挡 ③ exotic + ⑤-L2 + 强化 ⑥（R5/R8）
