# UAT: weak-model-robustness

本 change 为 flow-kit 引擎 markdown 增强 + 静态 bats/check.sh 脚本，**无用户可交互 UI / 无手动操作场景**，全部 AC 由自动化测试覆盖（见 TEST.md）。

故无人工 UAT 脚本。验收以自动化为准：

- **bats**: 102 ok / 0 fail（94 既有 + 8 新增弱模型护栏结构测试）
- **regression-demo check.sh**: 3/3 PASS（hallucination-guard / scope-drift-guard / strong-model-verbosity）

**UAT 结论**：N/A（全自动化验收通过，无人工 UAT 适用项）。
