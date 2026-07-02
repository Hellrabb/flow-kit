# SUMMARY: T09 - gate_config 篡改检测 + .goal-snapshot.json（D8/G3）

- **Change ID**: gate-integrity
- **Task ID**: T09
- **完成时间**: 2026-07-02 13:45
- **AI 角色**: Dev

## 做了什么

(1) gate.sh 加 `fk_check_gate_config_tamper(flow_file, snapshot_file)`：diff `.goal.gate_config` 与 `.goal-snapshot.json`，快照中 independent/true → false/缺失 → return 1（deny fail-close）；新增 key 不触发。主逻辑 review gate 段（done_marker 后）调此函数；(2) SKILL.md pipeline goal 创建段两处（:126/:163）加 `jq` 写 `.specs/<id>/.goal-snapshot.json`（gate_config 副本 + created_at，入库受 git 跟踪）。

## 改动文件

| 文件 | 性质 | 说明 |
|---|---|---|
| flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh | 修改 | guard 外加 fk_check_gate_config_tamper + 主逻辑调 |
| flow-kit-bundle/skills/flow/SKILL.md | 修改 | pipeline goal 创建时写 .goal-snapshot.json（2处）|

## verify

```text
bash -n ✅
gate-config-tamper/check.sh ✅（6-review independent→false 检测到篡改）
部署 L-015 一致 ✅（SKILL.md 手动 cp·install.sh 跳过既有 skill）
bats stop_chain 13/0 ✅
```

## 完成判定

- TASK.md 已勾选：是
