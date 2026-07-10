#!/usr/bin/env bats
# test_auto_checkpoint.bats — auto-checkpoint.sh PreToolUse hook 集成测试
# 用法: npx bats test/test_auto_checkpoint.bats
#
# AC 覆盖: AC-1 (Write checkpoint) / AC-2 (Edit checkpoint) / AC-3 (无change跳过)
#          AC-4 (非Write/Edit不触发) / AC-5 (Fail-open) / AC-6 (恢复精度) / AC-9 (去重已移除)

setup() {
  TEST_DIR=$(mktemp -d)

  # 位置无关：向上查找 flow-kit-bundle 根目录
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -f "$d/flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh" ]; do
    d="$(dirname "$d")"
  done
  BUNDLE_ROOT="$d/flow-kit-bundle"

  # 复制必要文件到临时目录
  cp "$BUNDLE_ROOT/hooks/pre-tool-use/auto-checkpoint.sh" "$TEST_DIR/"
  cp "$BUNDLE_ROOT/hooks/stop/lib/checkpoint-lib.sh" "$TEST_DIR/"
  chmod +x "$TEST_DIR/auto-checkpoint.sh"

  cd "$TEST_DIR"

  # 创建测试用 .flow-active（有活跃 change, phase=4）
  jq -n '{change_id:"test-change",goal:{current_phase:"4"},phase:"4",interrupt:null,updated_at:"2026-01-01T00:00:00+00:00"}' > .flow-active
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# ════════════════════════════════════════════════════════════════
# AC-1: Write 前自动 checkpoint（有活跃 change）
# ════════════════════════════════════════════════════════════════

@test "AC-1: Write tool triggers auto checkpoint" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/main.sh"}}' | bash ./auto-checkpoint.sh
  [[ "$?" -eq 0 ]]

  active_file=$(jq -r '.interrupt.active_file' .flow-active)
  last_action=$(jq -r '.interrupt.last_action' .flow-active)
  checkpoint_at=$(jq -r '.interrupt.checkpoint_at' .flow-active)
  failing_check=$(jq -r '.interrupt.failing_check' .flow-active)

  [[ "$active_file" == "src/main.sh" ]]
  [[ "$last_action" == "编辑 src/main.sh" ]]
  [[ -n "$checkpoint_at" ]]
  [[ "$failing_check" == "" ]]
}

@test "AC-1: Write checkpoint updates updated_at" {
  old_ts=$(jq -r '.updated_at' .flow-active)
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/utils.sh"}}' | bash ./auto-checkpoint.sh
  new_ts=$(jq -r '.updated_at' .flow-active)
  [[ "$new_ts" != "$old_ts" ]]
}

# ════════════════════════════════════════════════════════════════
# AC-2: Edit 前自动 checkpoint（有活跃 change）
# ════════════════════════════════════════════════════════════════

@test "AC-2: Edit tool triggers auto checkpoint" {
  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/config.sh"}}' | bash ./auto-checkpoint.sh
  [[ "$?" -eq 0 ]]

  active_file=$(jq -r '.interrupt.active_file' .flow-active)
  last_action=$(jq -r '.interrupt.last_action' .flow-active)

  [[ "$active_file" == "src/config.sh" ]]
  [[ "$last_action" == "编辑 src/config.sh" ]]
}

# ════════════════════════════════════════════════════════════════
# AC-3: 无活跃 change 时静默跳过
# ════════════════════════════════════════════════════════════════

@test "AC-3: no .flow-active → exit 0, no file created" {
  rm .flow-active
  old_dir=$(ls)
  echo '{"tool_name":"Write","tool_input":{"file_path":"test.sh"}}' | bash ./auto-checkpoint.sh
  [[ "$?" -eq 0 ]]
  # .flow-active 不被创建
  [[ ! -f .flow-active ]]
}

@test "AC-3: change_id=null → interrupt unchanged" {
  # 预设 .flow-active 含 null change_id + 已有 interrupt 值
  jq -n '{change_id:null,phase:"4",interrupt:{active_file:"old.sh",last_action:"old",checkpoint_at:"2020-01-01T00:00:00Z"}}' > .flow-active
  echo '{"tool_name":"Write","tool_input":{"file_path":"new.sh"}}' | bash ./auto-checkpoint.sh
  [[ "$?" -eq 0 ]]
  active_file=$(jq -r '.interrupt.active_file' .flow-active)
  [[ "$active_file" == "old.sh" ]]  # 未被覆盖
}

# ════════════════════════════════════════════════════════════════
# AC-4: 非 Write/Edit 工具不触发
# ════════════════════════════════════════════════════════════════

@test "AC-4: Read tool does not trigger checkpoint" {
  # 预设初始 interrupt 值
  jq '.interrupt = {active_file:"before.sh",last_action:"编辑 before.sh",checkpoint_at:"2020-01-01T00:00:00Z"}' .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
  echo '{"tool_name":"Read","tool_input":{}}' | bash ./auto-checkpoint.sh
  [[ "$?" -eq 0 ]]
  active_file=$(jq -r '.interrupt.active_file' .flow-active)
  [[ "$active_file" == "before.sh" ]]  # 不变
}

@test "AC-4: Bash tool does not trigger checkpoint" {
  jq '.interrupt = {active_file:"before.sh",last_action:"编辑 before.sh",checkpoint_at:"2020-01-01T00:00:00Z"}' .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
  echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | bash ./auto-checkpoint.sh
  [[ "$?" -eq 0 ]]
  active_file=$(jq -r '.interrupt.active_file' .flow-active)
  [[ "$active_file" == "before.sh" ]]  # 不变
}

# ════════════════════════════════════════════════════════════════
# AC-5: Fail-open — hook 异常不阻断工具调用
# ════════════════════════════════════════════════════════════════

@test "AC-5: corrupt .flow-active JSON → exit 0, Write tool-side not blocked (Write path)" {
  echo "not json" > .flow-active
  # 模拟 Write 工具：先写入一个目标文件，hook 不阻断
  echo "content" > write_target.sh
  echo '{"tool_name":"Write","tool_input":{"file_path":"write_target.sh"}}' | bash ./auto-checkpoint.sh
  hook_rc=$?
  [[ "$hook_rc" -eq 0 ]]  # fail-open: hook 不阻断
  [[ -f write_target.sh ]]  # AC-5 (a): 目标文件仍存在（Write 未被阻断）
}

@test "AC-5: corrupt JSON → exit 0, Edit tool-side not blocked (Edit path)" {
  echo "not json" > .flow-active
  # 模拟 Edit 工具：先写入初始内容，hook 不阻断后续修改
  echo "original" > edit_target.sh
  echo '{"tool_name":"Edit","tool_input":{"file_path":"edit_target.sh"}}' | bash ./auto-checkpoint.sh
  hook_rc=$?
  [[ "$hook_rc" -eq 0 ]]  # fail-open: hook 不阻断
  [[ -f edit_target.sh ]]  # AC-5 (b): 目标文件仍存在（Edit 未被阻断）
  content=$(cat edit_target.sh)
  [[ "$content" == "original" ]]  # AC-5 (b): 内容未被 hook 意外修改
}

# ════════════════════════════════════════════════════════════════
# AC-6: 恢复精度 — interrupt 三字段可被 resume 路径读取
# ════════════════════════════════════════════════════════════════

@test "AC-6: interrupt fields correctly written for resume consumption" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"hooks/checkpoint.sh"}}' | bash ./auto-checkpoint.sh

  # ── 写入侧验证：interrupt 三字段非空且格式正确 ──
  active_file=$(jq -r '.interrupt.active_file' .flow-active)
  last_action=$(jq -r '.interrupt.last_action' .flow-active)
  checkpoint_at=$(jq -r '.interrupt.checkpoint_at' .flow-active)

  [[ -n "$active_file" ]]
  [[ -n "$last_action" ]]
  [[ -n "$checkpoint_at" ]]
  [[ "$active_file" == "hooks/checkpoint.sh" ]]
  [[ "$last_action" == *"hooks/checkpoint.sh"* ]]
  [[ "$checkpoint_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]

  # ── 读取侧验证：模拟 flow-kit-resume.sh 的 jq 提取模式（L175-177）──
  # 验证 resume 脚本能成功提取中断信息用于 banner 展示
  int_file=$(jq -r '.interrupt.active_file // ""' .flow-active)
  int_action=$(jq -r '.interrupt.last_action // ""' .flow-active)
  int_ts=$(jq -r '.interrupt.checkpoint_at // ""' .flow-active)

  [[ "$int_file" == "hooks/checkpoint.sh" ]]
  [[ -n "$int_action" ]]
  [[ "$int_action" != "null" ]]
  [[ -n "$int_ts" ]]
  [[ "$int_ts" != "null" ]]
}

@test "AC-6: resume banner interrupt output contains required fields" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/resume-test.sh"}}' | bash ./auto-checkpoint.sh

  # 模拟 flow-kit-resume.sh 的 banner 生成逻辑（L231-234）
  int_action=$(jq -r '.interrupt.last_action // ""' .flow-active)
  int_file=$(jq -r '.interrupt.active_file // ""' .flow-active)

  [[ -n "$int_action" && "$int_action" != "null" ]]
  [[ "$int_file" == "src/resume-test.sh" ]]

  # 验证 banner 所需的三字段均可被 jq 正确提取
  int_ts=$(jq -r '.interrupt.checkpoint_at // ""' .flow-active)
  failing_check=$(jq -r '.interrupt.failing_check // ""' .flow-active)
  [[ -n "$int_ts" ]]
  [[ "$failing_check" == "" ]]
}

# ════════════════════════════════════════════════════════════════
# AC-9: checkpoint-lib 去重已移除 — 连续写入必定更新
# ════════════════════════════════════════════════════════════════

@test "AC-9: two consecutive Writes both succeed (no dedup)" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"a.sh"}}' | bash ./auto-checkpoint.sh
  ts1=$(jq -r '.interrupt.checkpoint_at' .flow-active)

  # 极小间隔后再次触发
  sleep 1
  echo '{"tool_name":"Write","tool_input":{"file_path":"a.sh"}}' | bash ./auto-checkpoint.sh
  ts2=$(jq -r '.interrupt.checkpoint_at' .flow-active)

  # 两次都成功（exit 0）
  [[ "$?" -eq 0 ]]
  # checkpoint_at 不同（每次必定更新）
  [[ "$ts1" != "$ts2" ]]
}

@test "AC-9: two consecutive Edits both succeed (no dedup)" {
  echo '{"tool_name":"Edit","tool_input":{"file_path":"b.sh"}}' | bash ./auto-checkpoint.sh
  ts1=$(jq -r '.interrupt.checkpoint_at' .flow-active)

  sleep 1
  echo '{"tool_name":"Edit","tool_input":{"file_path":"b.sh"}}' | bash ./auto-checkpoint.sh
  ts2=$(jq -r '.interrupt.checkpoint_at' .flow-active)

  [[ "$?" -eq 0 ]]
  [[ "$ts1" != "$ts2" ]]
}
