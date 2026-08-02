# Loading Artifacts — 工件加载操作手册

<!-- 迁移自 GO.md 第四步「加载工件」段，本段为单一源。GO.md 仅保留 @see 引用。
     来自 superpowers-v6-absorb Phase 2 · ADR-018 -->

> **核心原则**：严格区分必读 / 按需。grep 后再 read，read 用 offset/limit 切片，单 phase 总 read ≤150 行。

---

## 1. 必读 vs 按需严格区分

**语义约定**：

| 符号 | 含义 | 何时用 |
|---|---|---|
| `⚡︎ 全读` | 进阶段首轮必须 read_file 整个文件 | 仅 SPEC / TEMPLATE 工件（REQUIREMENT.md / DESIGN.md 等） |
| `⚡︎ 查表` | 只 grep 指定节 或 read offset/limit | 所有 reference/* 文件，**禁止默认整读** |
| `⚡︎ 按需` | 首轮不读，里面某个决定点需要时才 grep | 附加参考、外部扩展查询 |

## 2. grep + read + offset/limit 操作范例

```bash
# 先 grep 定位
grep -n "Toll-Gate" .specs/<id>/REQUIREMENT.md
# 输出: 187:## Pipeline Toll-Gate

# 再 read 该段（offset + limit）
# Read 工具: offset=187, limit=50
```

> ⚠️ 严禁未 grep 直接 read 整个文件（CONTEXT.md ~530 行 = ~30KB 浪费）。

## 3. reference 某一节的实际动作示例

```bash
# 想读 GO.md 的 Token 预算段
grep -n "^##" flow-kit-bundle/flow-kit/GO.md | grep -i token
# 输出: 5:## 红线·Token 预算（必读）
#       12:### Token 预算估计 · 进阶段前必跑

# 取到 line 12 的段，limit 30 行
# Read: offset=12, limit=30
```

不要「为了保险」一上来就整读。不仅费 token，还让后续推理被无关节况干扰。

## 4. 150 行 cap per phase

每个 phase 总 read 量（除必读工件）≤150 行。

- 超出 → 用更细的 grep 收窄查询范围，或拆分到子 task
- 实际成本：150 行 ≈ 6-9K tokens，可接受

---

<!-- 引用方式：phase prompts 通过 @see flow-kit/reference/loading-artifacts.md 引用本段。
     本文件本身 ≤60 行，避免引入新 token 负担。-->
