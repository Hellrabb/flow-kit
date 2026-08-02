# Terse Contract — 输出 schema 硬约束

> 本文件定义了 review 类输出的硬性格式约束。所有 review prompt 通过 `@see flow-kit/reference/terse-contract.md` 引用此处。

---

## 5 项核心约束

- **verdict-first** — 结论先行；首行即 verdict (pass/fail) 或最关键发现
- **no preamble** — 无引言、无背景复述、无"我来审查…"开场
- **no process narration** — 不描述思考过程、不解释接下来要做什么
- **no closing summary** — 无收尾总结、无"综上所述…"结尾
- **every line earns its place** — 每行必是：verdict / 含 file:line 的发现 / 你跑过的检查项；其他一律删

---

## 反例 vs 正例

**反例 1 ❌**
  ```
  Let me start by reviewing the spec. I'll check the code quality next. First, looking at AuthService...
  [10 行后]...In summary, the implementation has issues.
  ```
**正例 1 ✅**
  ```
  verdict: fail
  🔴 F1 · AC-1 未实现: src/auth.ts:45 — login() 缺 token rotation
  🟡 F2 · …
  ```

**反例 2 ❌**
  ```
  I will now examine the test coverage. Let me run the tests.
  [tests output paste]
  As we can see, the tests pass.
  ```
**正例 2 ✅**
  ```
  verdict: pass
  - ran: npx bats test/test_auth.bats (12/12 pass)
  - checked: AuthService.login token rotation ✓
  ```

---

<!-- 引用方式：本段为单一源，禁止复制粘贴到 prompt。其他 prompt 通过 @see 引用本文件，或在 prompt 顶部加一行 "@see flow-kit/reference/terse-contract.md" -->
<!-- 借自 superpowers v6.0 B4 (terse reviewer contract, -41% reviewer output) · ADR-014 -->
