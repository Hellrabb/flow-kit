#!/usr/bin/env bats
# test_fail_closed.bats — C12 门禁运行期 fail-closed（AC-8）注入测试
# 用法: npx bats test/test_fail_closed.bats
#
# AC-8 覆盖（health-fix-2026-09c · T01）:
#   ① jq 遮蔽（影子 PATH，L-127 定式：PATH 是查找序非白名单，前置目录遮不住 jq，
#      必须整体替换为「软链真实工具但排除 jq」的影子目录 + 前提自检）
#   ② .flow-active 非法 JSON
#   ③ 子库关键函数缺失（declare -f 断言面）
#   反向控制 ×3：正常 JSON + jq 在场 → exit 0 不误伤
#
# 注: 本文件与 flow-kit-bundle/test/test_fail_closed.bats 逐字节相同（手动双写镜像）。

setup() {
  TEST_DIR=$(mktemp -d)

  # 位置无关：向上查找 flow-kit-bundle 根目录（test/ 与 flow-kit-bundle/test/ 双镜像均可跑）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -f "$d/flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh" ]; do
    d="$(dirname "$d")"
  done
  BUNDLE_ROOT="$d/flow-kit-bundle"
  BASH_BIN="$(command -v bash)"

  # 复制必要文件到临时目录（沿 test_auto_checkpoint.bats flat layout 范式）
  cp "$BUNDLE_ROOT/hooks/pre-tool-use/auto-checkpoint.sh" "$TEST_DIR/"
  cp "$BUNDLE_ROOT/hooks/stop/lib/checkpoint-lib.sh" "$TEST_DIR/"
  chmod +x "$TEST_DIR/auto-checkpoint.sh"

  cd "$TEST_DIR"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# _make_shadow_bin — 构建排除 jq 的影子 PATH 目录（L-127）+ 前提自检：
# 影子下 jq 必须不可见、hook 顶层依赖的基础工具必须在场，否则本用例无效
_make_shadow_bin() {
  local shadow="$1" t real
  mkdir -p "$shadow"
  for t in dirname basename cat grep sed awk cut tr head tail wc date \
           mktemp mkdir rm mv cp ls ln sort find chmod env; do
    real="$(command -v "$t" 2>/dev/null || true)"
    [[ "$real" == /* ]] && ln -sf "$real" "$shadow/$t"
  done
  if PATH="$shadow" command -v jq >/dev/null 2>&1; then
    echo "precondition failed: jq still visible in shadow PATH" >&2
    return 1
  fi
  if ! PATH="$shadow" command -v dirname >/dev/null 2>&1; then
    echo "precondition failed: dirname missing in shadow PATH" >&2
    return 1
  fi
}

# ════════════════════════════════════════════════════════════════
# AC-8①: jq 遮蔽（影子 PATH）→ exit 2
# ════════════════════════════════════════════════════════════════

@test "AC-8① gate: jq 遮蔽 → exit 2 拒绝放行（具名报文）" {
  _make_shadow_bin "$TEST_DIR/shadow"
  gate_rc=0
  echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"cwd":"'"$TEST_DIR"'"}' \
    | PATH="$TEST_DIR/shadow" "$BASH_BIN" "$BUNDLE_ROOT/hooks/pre-tool-use/independent-review-gate.sh" 2>gate.err || gate_rc=$?
  [[ "$gate_rc" -eq 2 ]]
  grep -q "jq 不可用" gate.err   # 失败必须落在 jq 断言面（L-091: 探针落在判据域内）
}

@test "AC-8① auto-checkpoint: jq 遮蔽 → exit 2 拒绝放行（具名报文）" {
  _make_shadow_bin "$TEST_DIR/shadow"
  ck_rc=0
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/main.sh"}}' \
    | PATH="$TEST_DIR/shadow" "$BASH_BIN" "$TEST_DIR/auto-checkpoint.sh" 2>ck.err || ck_rc=$?
  [[ "$ck_rc" -eq 2 ]]
  grep -q "jq 不可用" ck.err
}

# ════════════════════════════════════════════════════════════════
# AC-8②: .flow-active 非法 JSON → exit 2
# ════════════════════════════════════════════════════════════════

@test "AC-8② gate: .flow-active 非法 JSON → exit 2 拒绝放行（具名报文）" {
  echo "not json {" > "$TEST_DIR/.flow-active"
  gate_rc=0
  echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"cwd":"'"$TEST_DIR"'"}' \
    | bash "$BUNDLE_ROOT/hooks/pre-tool-use/independent-review-gate.sh" 2>gate.err || gate_rc=$?
  [[ "$gate_rc" -eq 2 ]]
  grep -q "非法 JSON" gate.err
}

@test "AC-8② auto-checkpoint: .flow-active 非法 JSON → exit 2 拒绝放行（具名报文）" {
  echo "not json" > .flow-active
  ck_rc=0
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/main.sh"}}' \
    | bash "$TEST_DIR/auto-checkpoint.sh" 2>ck.err || ck_rc=$?
  [[ "$ck_rc" -eq 2 ]]
  grep -q "状态不可判" ck.err
}

# ════════════════════════════════════════════════════════════════
# AC-8③: 子库关键函数缺失 → exit 2
# ════════════════════════════════════════════════════════════════

@test "AC-8③ gate: 子库关键函数缺失（declare -f 断言面）→ exit 2 拒绝放行" {
  # 镜像目录结构（gate 顶层从 ../stop/lib/common.sh 加载 common.sh）
  mkdir -p "$TEST_DIR/mirror/pre-tool-use" "$TEST_DIR/mirror/stop"
  cp "$BUNDLE_ROOT/hooks/pre-tool-use/"*.sh "$TEST_DIR/mirror/pre-tool-use/"
  cp -r "$BUNDLE_ROOT/hooks/stop/lib" "$TEST_DIR/mirror/stop/"
  # 注入：改名 gate-checks-basic.sh 的 _gate_check_l2（模拟函数被删/改名）
  sed -i 's/_gate_check_l2()/_gate_check_l2_REMOVED()/' "$TEST_DIR/mirror/pre-tool-use/gate-checks-basic.sh"
  grep -q "_gate_check_l2_REMOVED()" "$TEST_DIR/mirror/pre-tool-use/gate-checks-basic.sh"  # 注入自检（L-090）

  gate_rc=0
  echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"cwd":"'"$TEST_DIR"'"}' \
    | bash "$TEST_DIR/mirror/pre-tool-use/independent-review-gate.sh" 2>gate.err || gate_rc=$?
  [[ "$gate_rc" -eq 2 ]]
  grep -q "_gate_check_l2 未定义" gate.err   # 具名报文点名缺失函数
}

# ════════════════════════════════════════════════════════════════
# 反向控制: 正常 JSON + jq 在场 → 不因新断言误伤 exit 0 路径
# ════════════════════════════════════════════════════════════════

@test "反向控制 gate: 正常输入 → exit 0（新断言不误伤）" {
  # (a) 无 .flow-active（非管辖契约 → 放行）
  echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"cwd":"'"$TEST_DIR"'"}' \
    | bash "$BUNDLE_ROOT/hooks/pre-tool-use/independent-review-gate.sh"
  [[ "$?" -eq 0 ]]

  # (b) 合法 .flow-active + phase=4（jq 校验通过 → phase filter skip → 放行）
  jq -n '{change_id:"ctl",goal:{current_phase:"4"},phase:"4",interrupt:null,updated_at:"2026-01-01T00:00:00+00:00"}' > "$TEST_DIR/.flow-active"
  echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"cwd":"'"$TEST_DIR"'"}' \
    | bash "$BUNDLE_ROOT/hooks/pre-tool-use/independent-review-gate.sh"
  [[ "$?" -eq 0 ]]
}

@test "反向控制 auto-checkpoint: Read 工具（非编辑）→ exit 0" {
  jq -n '{change_id:"ctl",phase:"4"}' > .flow-active
  echo '{"tool_name":"Read","tool_input":{}}' | bash "$TEST_DIR/auto-checkpoint.sh"
  [[ "$?" -eq 0 ]]
}

@test "反向控制 auto-checkpoint: Write + 合法 .flow-active → exit 0 且 checkpoint 正常写入" {
  jq -n '{change_id:"test-change",goal:{current_phase:"4"},phase:"4",interrupt:null,updated_at:"2026-01-01T00:00:00+00:00"}' > .flow-active
  echo '{"tool_name":"Write","tool_input":{"file_path":"src/main.sh"}}' | bash "$TEST_DIR/auto-checkpoint.sh"
  [[ "$?" -eq 0 ]]
  [[ "$(jq -r '.interrupt.active_file' .flow-active)" == "src/main.sh" ]]
}
