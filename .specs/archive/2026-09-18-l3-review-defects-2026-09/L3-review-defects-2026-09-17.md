# L3 审查链缺陷报告 · 2026-09-17

> **来源**：`chisel_env` 仓库的 change `verify-ac-env-fix`（阶段 7 / 7-integration）实际使用 flow-kit 时踩到的问题。
> **审查环境**：DSH 路径（`~/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle`），
> 外部模型 `deepseek-v4-flash-0731`（`max_tokens=128000` / `timeout=600` / `thinking=enabled`），
> 项目侧 `gate_config["7-integration"] = "both"`（L2+L3 都启用）。
> **本报告的对象是本仓库 `flow-kit-bundle/`**；行号均为本仓库相对路径。已在 commit `19b3463`（分支 `develop`）上核对。
> **不在范围内**：L2 派发链、gate/transition 逻辑、看板、安装器 —— 本次没有踩到，也没有系统审。

## 结论摘要

| ID | 缺陷 | 严重度 | 状态 | 一句话 |
|----|------|--------|------|--------|
| B1 | `fk_extract_l2_verdict` 抽错 verdict | 🔴 高 | **已实测复现**（真实故障） | 取"文件里最后一处 `verdict:`"，于是 L3 段会改写 L2 结论；大小写不归一 → `invalid L2_verdict: PASS` 直接卡死 L3 |
| B2 | L3 段重写按标题截断、无结束标记 | 🟡 中 | 代码可推演（本次未触发） | 载荷里出现行首 `## ` 时会错位，残留片段或吞掉后续内容 |
| B3 | `max_artifact_chars` 名为字符、实现是字节 | 🟡 中 | **已实测**（配置被误读） | `head -c` 是字节；对中文工件 60000 "chars" 实际只有 ~2 万汉字 |
| B4 | 阶段 7 产物清单 `head -30` 截断 + 硬编码 `INTEGRATION.md` | 🔴 高 | **已实测复现**（造成 L3 假 fail） | 顶层条目 > 28 时，清单漏文件 → L3 报"产物缺失"并 verdict=fail |
| B5 | 安装树不同步：`~/.claude/hooks` 缺 P0-1/P0-2 修复 | 🔴 高 | **已实测**（grep 计数 0） | 同一功能在两处安装，Claude Code 路径仍跑旧行为（工件上限静默 20000、无熔断） |

**修法优先级**：B5 → B1 → B4 → B3 → B2（理由见文末 §7）。

---

## B1 · `fk_extract_l2_verdict` 抽错 verdict

**位置**：`flow-kit-bundle/hooks/stop/lib/l2-detect.sh:36-53`（核心在 `:41`）
**调用方**：`flow-kit-bundle/hooks/stop/lib/l3-review.sh:61`（校验 `^(pass|fail|skipped)$`，不匹配即 `return 3`）

```bash
# l2-detect.sh:41
verdict=$(grep -iE 'verdict[^a-z]*[:：]' "$review_md" 2>/dev/null | tail -1 | grep -ioE 'pass|fail' | tail -1)
```

### 症状

1. **取整份文件最后一处**含 `verdict…:` 的行 —— 但 `INDEPENDENT-REVIEW-<N>.md` 里 L3 段是**后追加**的，
   而 L3 的 JSON 里就有 `"verdict": "pass"`。于是"L2 判定"被"L3 判定"改写。
2. **没有行首/行尾锚定** —— 表格行、JSON、散文全都命中。
3. **`grep -o` 保留原大小写** —— 命中 `PASS` 就返回 `PASS`，调用方要求小写 → 直接失败。

### 复现（自包含，可在本仓库直接跑）

```bash
cd <flow-kit 仓库根>
source flow-kit-bundle/hooks/stop/lib/l2-detect.sh
tmp=$(mktemp)
printf '%s\n' "## L2 盲审" "**Verdict**: fail" "" "### 结论" "第 2 轮复核后 Verdict: PASS" > "$tmp"
fk_extract_l2_verdict "$tmp"      # 实际输出：PASS   期望：fail
```

实测输出：`[PASS]`。调用方随即打印 `[l3-review] invalid L2_verdict: PASS` 并 `return 3` —— **L3 从此不再运行**，
而 Stop hook 不写 `.done`，阶段推进/commit 全被 PreToolUse 守卫挡住；从工件上完全看不出原因。

> 这就是 `chisel_env` 里 `skill-trust-hardening`（2026-09-10）那次"L3 死活不跑"的成因；
> 当时的绕过办法是在工件**末尾**追加一行干净的 `**Verdict**: pass`，且**每次 L3 写入后都必须重新追加**。

### 第二条实测证据：握手记录不可复现

拿 `chisel_env` 归档工件调同一个函数：

| 工件 | `.done` 里记录的 `L2_verdict` | 今天函数返回 |
|---|---|---|
| `INDEPENDENT-REVIEW-3.md` | `fail` | **`pass`** |
| `INDEPENDENT-REVIEW-5.md` | `fail` | **`pass`** |
| `INDEPENDENT-REVIEW-7.md` | `pass` | `pass` |

阶段 3/5 今日返回的其实是文件里最后一处 `verdict:`——**L3 的 JSON**。同一工件、同一函数、不同时点给出不同结论，
`.done` 因此不可复现，且它与"两阶段 L2 末轮 pass"的事实不符。事后也无法修正：
PreToolUse 守卫禁止主 agent 改 `.done`（防绕过设计是对的，但这里放大了 B1 的后果）。

### 建议修法

```bash
fk_extract_l2_verdict() {
  local review_md="${1:-}" verdict=""
  [ -f "$review_md" ] || { echo ""; return 1; }
  # 只在 L2 段内取（'## L2 盲审' → 下一个 '^## ' 为止），并锚定 verdict 行
  verdict=$(awk '/^## L2 /{f=1;next} f&&/^## /{exit} f' "$review_md" 2>/dev/null \
            | grep -iE '^\**[[:space:]]*Verdict[[:space:]]*\**[:：]' | tail -1 \
            | grep -ioE 'pass|fail' | tail -1 | tr 'A-Z' 'a-z')
  # 兜底：全文件锚定式（不含 L3 段）
  [ -n "$verdict" ] || verdict=$(awk '/^## L3 /{exit} {print}' "$review_md" \
            | grep -iE '^\**[[:space:]]*Verdict[[:space:]]*\**[:：]' | tail -1 \
            | grep -ioE 'pass|fail' | tail -1 | tr 'A-Z' 'a-z')
  echo "$verdict"; [ -n "$verdict" ]
}
```

要点：**限定在 L2 段** + **锚定行首** + **大小写归一**。修完请把 `l3-review.sh:61` 的校验保留（它是最后一道闸）。

---

## B2 · L3 段重写按标题截断、无结束标记

**位置**：`flow-kit-bundle/hooks/stop/lib/l3-api.sh:174`

```bash
awk '/^## L3 (盲审|重审)/ { skip=1; next } /^## / && skip { skip=0 } !skip' "$review_md" > "$tmp_review" ...
```

### 症状

删除旧 L3 段时，用"碰到下一个二级标题"当结束条件，**没有显式结束标记**。
若 L3 载荷里出现行首 `## `（模型返回多行 markdown 时很常见），截断点就会错位：
要么留下上一轮的碎片，要么把紧随其后的内容一起吞掉。

**验证状态**：代码可推演，**本次未实际触发**（phase 7 第 2 轮 L3 的 JSON 是单行）。

### 建议修法

写入时加显式结束标记并用它切分：

```bash
# 写：
{ echo "## L3 重审（…）"; cat "$content"; echo "<!-- /L3-SECTION -->"; } >> "$review_md"
# 删（awk 按标记切，而不是按标题）：
awk '/^## L3 (盲审|重审)/{skip=1} skip&&/^<!-- \/L3-SECTION -->$/{skip=0;next} !skip' "$review_md"
```

或把 L3 载荷放进 fenced 区块（```），并在 fenced 内忽略标题语义。

---

## B3 · `max_artifact_chars`：名字是"字符"，实现是"字节"

**位置**：`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:23-31`（`_l3_utf8_head_bytes`，`:30` 用 `head -c`）、`:33-45`（流形，`:40` 同）

```bash
# l3-prompt.sh:30
head -c "$max_bytes" "$file" | _l3_utf8_head_stream "$max_bytes"
```

只做了"别在 UTF-8 多字节序列中间截断"的边界回退，**截断单位是字节**。
项目侧把它配成 `60000` 时想的是"6 万字符"；对中文工件，实际只有 **60000 B ≈ 2 万汉字**。

### 影响（已实测）

`chisel_env` 的 `verify-ac-env-fix` 阶段 1 出现过"L3 报 NFR 章节缺失"的假阳性，
根因正是 `REQUIREMENT.md`（38 KB）被截断——当时的有效上限还是 20000 B，只装得下约 1/3 文件。
配置名 `max_artifact_chars` 会让人按字符估算，低估截断风险。

### 建议修法

三选一（推荐前两个）：

1. **改名** `max_artifact_bytes`（并保留旧名兼容读取），让配置语义与实现一致；
2. **真按字符截断**：用 `python3 -c` 或 `cut -c` 之类按字符/字素裁；
3. 至少在文档里写明"单位=字节，CJK 请按 ÷3 估算"。

---

## B4 · 阶段 7 产物清单被 `head -30` 截断 + 硬编码 `INTEGRATION.md`

**位置**：`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:348-350`

```bash
artifact+="=== 产物目录 ===\n$(ls -la "$artifacts_dir" 2>/dev/null | head -30)"
for f in CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md REVIEW.md INTEGRATION.md; do
  if [ -f "${artifacts_dir}/$f" ]; then ... else artifact+="\n\n=== $f === MISSING"; fi
done
```

### 症状与复现

`ls -la | head -30` 对"顶层条目 > 28"的 change 会**截掉名序靠后的文件**。实测（`chisel_env` 的 phase-7 工作目录当时 33 条）：

```bash
comm -13 <(ls -la .specs/<id> | head -30 | awk '{print $NF}' | sort) \
         <(ls -la .specs/<id> | awk '{print $NF}' | sort)
# → T07-SUMMARY.md
#   TASK.md
#   TEST.md
#   UAT.md
```

L3 看到的清单里确实没有它们，于是第 1 轮给出 **2 critical + 2 major、verdict=fail**：

* "归档产物目录中未列出 `TASK.md`"（critical）
* "归档产物目录中未列出 `TEST.md`"（critical）
* "TASK.md 定义了 T07，但产物目录仅有 T01-T06-SUMMARY"（major）
* "工件末尾明确标记 `INTEGRATION.md` MISSING"（major）

**第三条是同一截断的连带**；**第四条则由 `:349` 的硬编码造成**——本项目不产出 `INTEGRATION.md`，
但提示词里必然出现 `=== INTEGRATION.md === MISSING`，模型如实报了出来。四条都**对提示词为真、对仓库为假**。

处置（change 侧，不改 flow-kit）：把逐轮审查记录与握手文件归入 `reviews/` 子目录（**内容零改动、零删除**），
顶层回到 30 行以内 → 第 2 轮 L3 立刻 `verdict=pass`（0 critical / 0 major / 1 minor）。

### 建议修法

```bash
# 1) 清单全量（或按类型分组），不要用固定行数截断
artifact+="=== 产物目录 ===\n$(ls -la "$artifacts_dir" 2>/dev/null)"
#    担心提示词膨胀时，改为列名字而非 ls -la：
#    artifact+="=== 产物目录 ===\n$(ls -1 "$artifacts_dir" 2>/dev/null | sed 's/^/  /')"
# 2) INTEGRATION.md 改为"存在才列"，并把它从"必备"语义里摘出（多数项目该阶段不产出独立文件）
for f in CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md REVIEW.md; do ... done
for f in INTEGRATION.md UAT.md; do
  [ -f "${artifacts_dir}/$f" ] && artifact+="\n\n=== $f ===\n$(...)"
done
```

同理建议检查其它阶段分支是否有等价的固定截断。

---

## B5 · 安装树不同步：`~/.claude/hooks` 缺 P0-1/P0-2 修复

**背景**：同一套 hook 存在多处副本 —— 本仓库 `flow-kit-bundle/hooks/`、
DSH 侧 `~/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks/`、
以及 Claude Code 侧 `~/.claude/hooks/`。

### 实测对比（2026-09-17）

| 对比 | 结果 |
|---|---|
| 本仓库 bundle ↔ DSH vendor | **hooks 代码完全一致**；仅 3 个测试文件不同：`test/test_go_routing.bats`、`test/test_l3_lifecycle_wiring.bats`、`test/test_model_tier.bats` |
| 本仓库 bundle ↔ `~/.claude/hooks` | **3 个功能性文件陈旧**：`stop/29-independent-review.sh`、`stop/lib/l3-review.sh`、`stop/lib/l3-done.sh` |

陈旧副本缺失的正是 2026-09-11 的 P0-1/P0-2 修复（grep 计数实测）：

| 检查点 | 本仓库 bundle | `~/.claude/hooks` |
|---|---|---|
| `FLOW_KIT_L3_MAX_ARTIFACT_CHARS`（把项目级 artifact 上限真正传给 `l3_review_run`） | `l3-review.sh` 2 处 / `29-independent-review.sh` 1 处 | **0 / 0** |
| `l3_write_bypass_done`（熔断降级出口，防"修一轮→重审→再 fail"无界循环） | `l3-done.sh` 3 处 | **0** |

### 影响

在 **Claude Code 路径**下跑时拿到的是旧行为：

* `max_artifact_chars` 项目配置被静默丢弃 → 上限恒为 **20000 字节** → 中文长工件被截 → 复现 B3 描述的一类"NFR/章节缺失"假阳性；
* 没有熔断写 `.done` 的出口 → L3 不收敛时只能一直循环（或人工绕过）。

DSH 路径（本次实测所用）**不受影响**，这样才出现"同一 change 换条路径结论不同"的现象。

### 建议修法

重新安装/同步 bundle 到 `~/.claude/hooks`（该目录下还留着一个 `stop/lib/l3-prompt.sh.bak-20260824`，
说明它经历过手工改动，建议先 diff 再覆盖）。同步后建议加一条**机器检查**：
比对三处副本的 hooks 树哈希（排除 `test/`、`config/`），不一致就告警——否则这个坑会随每次修复重演。

---

## 7 · 建议修复顺序与验证方式

| 顺序 | 缺陷 | 为什么排这个位置 | 修完怎么验（最小） |
|---|---|---|---|
| 1 | **B5** 同步安装树 | 不先做，后面所有结论都可能因为跑的是旧代码而对不上；成本≈0 | 三处 hooks 树哈希比对一致；旧树 grep `FLOW_KIT_L3_MAX_ARTIFACT_CHARS` ≥1 |
| 2 | **B1** verdict 提取 | 直接决定门禁是否卡死/结论漂移，改动 <10 行 | §B1 的自包含复现 → 期望 `fail`；归档工件上复算 → 期望等于 `.done` 记录值 |
| 3 | **B4** 清单全量 + INTEGRATION 按需 | 条目数一多就重演假 fail；改动小 | 造一个 33 条目的临时 change 目录，`_l3_build_prompt 7 <dir> 60000` 输出应含全部文件名且无 `INTEGRATION.md === MISSING` |
| 4 | **B3** 改名/换算 | 影响中文长工件的审查完整性 | 用 38 KB 中文 md 调 `_l3_build_prompt`，确认截断边界与文档描述一致 |
| 5 | **B2** L3 段结束标记 | 健壮性，未实际触发 | 构造含行首 `## ` 的 L3 载荷，连续写两轮，确认无残留、无误吞 |

建议给 B1/B4 各补一条 `test/*.bats`（本仓库 `test/` 已有 L3 生命周期相关用例可挂靠），
这样 §B5 的"副本漂移"也能被 CI 顺带发现。

## 8 · 未覆盖声明

本报告**没有**审查：L2 派发/子 agent 生命周期、gate 与 transition 逻辑、
`31-auto-advance.sh`、看板、安装器与打包脚本、其它阶段的 prompt 分支（仅阶段 7 分支被实际使用过）。
B2/B3 为代码层推演（未实际触发），其余三条均有实测证据。
