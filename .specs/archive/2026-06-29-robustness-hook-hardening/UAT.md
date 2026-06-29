# UAT: 弱模型鲁棒性 Hook 化升级

- **Change ID**: `robustness-hook-hardening`
- **测试日期**: 2026-06-29

---

## UAT-1 · AC-5 SessionStart 合规矫正 banner

**步骤**：
1. 手动写入 mock `.flow-active.correction` JSON
2. 将模拟 hook input 传入 `flow-kit-resume.sh`
3. 观察输出 + 验证文件清除

**结果**：✅ 通过

**证据**：
- 矫正 banner 正确显示：`⚠️ 合规矫正：上轮弱模型违规`，含 `[L1]` 层级标记 + 违规描述 + 修复指令
- 矫正文件在 banner 输出后被自动 `rm` 清除
- 不影响标准 resume banner 的正常显示

---

## 汇总

| UAT | 描述 | 结果 |
|---|---|---|
| UAT-1 | SessionStart 合规矫正注入 | ✅ 通过 |
