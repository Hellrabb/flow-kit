# T06-SUMMARY — flow-kit-resume.sh 扩展收割（rm -f 条件化 + model-missing 分支）

## 做了什么
`flow-kit-resume.sh:89-128` 收割逻辑从「compliance / unknown」2 分支扩展为 4 分支 + **rm -f 条件化**（DESIGN §4.3）。附带修复既有 l2-missing 持久化 bug（L2 R1）。

## 改了哪些文件
- `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`（:95-128 重构为 4 分支 if/elif）

## verify 输出
```
T06_VERIFY_OK（l3-model-missing + l2-model-missing 分支存在）
rm -f 位置：line 122（compliance 读后清）+ line 155（unknown 异常清除）—— 均在分支内
顶层无条件 rm：0（条件化成功，原 :127 已移入分支）
```

## 关键设计（DESIGN §4.3）
- **4 分支**：compliance（banner + 删）/ l3-model-missing（配置 banner + **不删**）/ l2-model-missing（同）/ l2-missing（**不删**·修持久化 bug）/ unknown（删）
- **rm 条件化**：model-missing + l2-missing 保留（持续提示，caller write_model_missing_clear 清除）；compliance/unknown 删
- **附带修 bug**：l2-missing 此前被 :127 无条件删（与 _write_l2_missing_correction "持久化" 注释矛盾），现保留

## 越界检查（R6.5）
write_files: flow-kit-resume.sh | 实际 diff: flow-kit-resume.sh | 越界: 0 ✅

## LESSONS
- L-020 不适用（改既有 hook，非新模块）
