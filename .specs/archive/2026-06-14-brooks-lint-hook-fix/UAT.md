# UAT — brooks-lint hook fix

## UAT-1：SessionStart hook 不再报错

**前提**：brooks-lint 已安装，`commands/` 目录为空（flow-kit 安装时排除）。

**步骤**：
1. 模拟 SessionStart hook 输入
2. 运行 hook 脚本
3. 检查 exit code 和输出

**结果**：
```
exit: 0
output: 有效 JSON，含 additionalContext
```

✅ **通过**

## UAT-2：package-flow-kit.sh 语法完整

**步骤**：`bash -n package-flow-kit.sh`

**结果**：
```
exit: 0
```

✅ **通过**

## UAT-3：已安装 hook 含修复行

**步骤**：grep `for f in.*brooks-\*\.md` 已安装的 session-start hook

**结果**：
```
/.../hooks/session-start:24:for f in "$plugin_dir"/commands/brooks-*.md; do
```

✅ **通过**

---

**结论**：3/3 通过。修复已生效，可归档。
