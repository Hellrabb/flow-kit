#!/usr/bin/env bats
# test_l3_review_params.bats — l3-review-timeout-token change 的 AC-1~AC-7（env var 可配）
# Mock 策略（REQUIREMENT Mock 策略声明）：bats 定义 curl() shell 函数覆盖真实 curl，
# 用文件捕获命令行 + 请求体（绕过子 shell 作用域），不打真实网络。
# 禁止 stub 整个 _l3_call_api（那会让请求体断言同义反复）——只 stub 内部 curl。

setup() {
  TEST_TMP=$(mktemp -d)
  CAPFILE="${TEST_TMP}/curl_capture"
  STDERRFILE="${TEST_TMP}/stderr"

  # 宿主 env 隔离：本文件区分「默认值」（AC-1/AC-3/AC-5c）与「env var 覆盖」（AC-2/AC-4/AC-5a/5b）两条路径，
  # 宿主 shell 若 export 了站点级调优（如 ~/.bashrc 的 MAX_TOKENS=128000 / TIMEOUT=600），
  # 默认值断言会在开发者机器上假失败（pre-push make check 红）。覆盖路径由各用例内联赋值，不受影响。
  unset FLOW_KIT_L3_MAX_TOKENS FLOW_KIT_L3_TIMEOUT FLOW_KIT_L3_THINKING

  # 位置无关：查找 flow-kit-bundle/hooks
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  FK_ROOT="$d"
  L3_LIB="$FK_ROOT/flow-kit-bundle/hooks/stop/lib/l3-review.sh"

  # stub curl：捕获命令行到 CAPFILE，返回模拟 200 + text block 响应
  curl() {
    echo "ARGS:$*" >> "$CAPFILE"
    printf '{"content":[{"type":"text","text":"test verdict"}],"stop_reason":"end_turn"}\n200'
  }
  export -f curl
}

teardown() {
  rm -rf "$TEST_TMP"
}

# 辅助：source lib 并调 _l3_call_api，捕获 stderr
_call_and_capture() {
  # source l3-review.sh（stub curl 已在环境，_l3_call_api 内部 curl 用 stub）
  : > "$CAPFILE"
  : > "$STDERRFILE"
  # _l3_call_api 的 stderr 重定向到 STDERRFILE
  ( source "$L3_LIB" 2>/dev/null && _l3_call_api "test prompt" "test-model" 2>"$STDERRFILE" )
}

# ── AC-1: max_tokens 默认 32000（双路径）──

@test "AC-1 path1: default max_tokens=32000 (ANTHROPIC_AUTH_TOKEN path)" {
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  grep -qE 'max_tokens": ?32000' "$CAPFILE"
  grep -q -- '--max-time 300' "$CAPFILE"
}

@test "AC-1 path2: default max_tokens=32000 (ANTHROPIC_API_KEY path)" {
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  grep -qE 'max_tokens": ?32000' "$CAPFILE"
  grep -q -- '--max-time 300' "$CAPFILE"
}

# ── AC-2: FLOW_KIT_L3_MAX_TOKENS env var 覆盖（双路径）──

@test "AC-2 path1: FLOW_KIT_L3_MAX_TOKENS=16000 overrides default" {
  FLOW_KIT_L3_MAX_TOKENS=16000 \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  grep -qE 'max_tokens": ?16000' "$CAPFILE"
}

@test "AC-2 path2: FLOW_KIT_L3_MAX_TOKENS=16000 overrides default" {
  FLOW_KIT_L3_MAX_TOKENS=16000 \
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  grep -qE 'max_tokens": ?16000' "$CAPFILE"
}

# ── AC-3: timeout 默认 300（双路径 · 与 AC-1 合并验证 curl --max-time）──

@test "AC-3: default timeout=300 (covered in AC-1 path1/2 --max-time 300)" {
  # AC-1 path1/path2 已断言 --max-time 300，此测试验证 timeout 可被 env var 覆盖（AC-4）
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  _call_and_capture
  grep -q -- '--max-time 300' "$CAPFILE"
}

# ── AC-4: FLOW_KIT_L3_TIMEOUT env var 覆盖（双路径）──

@test "AC-4 path1: FLOW_KIT_L3_TIMEOUT=600 overrides default" {
  FLOW_KIT_L3_TIMEOUT=600 \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  grep -q -- '--max-time 600' "$CAPFILE"
}

@test "AC-4 path2: FLOW_KIT_L3_TIMEOUT=600 overrides default" {
  FLOW_KIT_L3_TIMEOUT=600 \
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  grep -q -- '--max-time 600' "$CAPFILE"
}

# ── AC-5a: FLOW_KIT_L3_THINKING=enabled 显式（双路径 · 请求体不含 thinking 字段）──

@test "AC-5a path1: FLOW_KIT_L3_THINKING=enabled → no thinking field" {
  FLOW_KIT_L3_THINKING=enabled \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  ! grep -q '"thinking"' "$CAPFILE"
}

@test "AC-5a path2: FLOW_KIT_L3_THINKING=enabled → no thinking field" {
  FLOW_KIT_L3_THINKING=enabled \
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  ! grep -q '"thinking"' "$CAPFILE"
}

# ── AC-5b: FLOW_KIT_L3_THINKING=disabled 显式（双路径 · 请求体含 thinking:{type:disabled}）──

@test "AC-5b path1: FLOW_KIT_L3_THINKING=disabled → thinking field present" {
  FLOW_KIT_L3_THINKING=disabled \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  grep -q '"thinking":{"type":"disabled"}' "$CAPFILE"
}

@test "AC-5b path2: FLOW_KIT_L3_THINKING=disabled → thinking field present" {
  FLOW_KIT_L3_THINKING=disabled \
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  grep -q '"thinking":{"type":"disabled"}' "$CAPFILE"
}

# ── AC-5c: FLOW_KIT_L3_THINKING 未设（基线 · 双路径 · 等同 enabled）──

@test "AC-5c path1: FLOW_KIT_L3_THINKING unset → no thinking field (baseline)" {
  unset FLOW_KIT_L3_THINKING
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  ! grep -q '"thinking"' "$CAPFILE"
}

@test "AC-5c path2: FLOW_KIT_L3_THINKING unset → no thinking field (baseline)" {
  unset FLOW_KIT_L3_THINKING
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  ! grep -q '"thinking"' "$CAPFILE"
}

# ── AC-6: Fail-safe 非法值回退默认 + 警告（双路径 × 6 非法值）──

@test "AC-6 path1: FLOW_KIT_L3_MAX_TOKENS=abc → fallback 32000 + warning" {
  FLOW_KIT_L3_MAX_TOKENS=abc \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  grep -qE 'max_tokens": ?32000' "$CAPFILE"
  grep -q "FLOW_KIT_L3_MAX_TOKENS='abc' 非法" "$STDERRFILE"
}

@test "AC-6 path1: FLOW_KIT_L3_MAX_TOKENS=空 → fallback 32000 + warning" {
  FLOW_KIT_L3_MAX_TOKENS="" \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  grep -qE 'max_tokens": ?32000' "$CAPFILE"
  grep -q "FLOW_KIT_L3_MAX_TOKENS='' 非法" "$STDERRFILE"
}

@test "AC-6 path1: FLOW_KIT_L3_TIMEOUT=xyz → fallback 300 + warning" {
  FLOW_KIT_L3_TIMEOUT=xyz \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  grep -q -- '--max-time 300' "$CAPFILE"
  grep -q "FLOW_KIT_L3_TIMEOUT='xyz' 非法" "$STDERRFILE"
}

@test "AC-6 path1: FLOW_KIT_L3_THINKING=yes → fallback enabled + warning" {
  FLOW_KIT_L3_THINKING=yes \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  ! grep -q '"thinking"' "$CAPFILE"
  grep -q "FLOW_KIT_L3_THINKING='yes' 非法" "$STDERRFILE"
}

@test "AC-6 path2: FLOW_KIT_L3_MAX_TOKENS=abc → fallback 32000 (path2)" {
  FLOW_KIT_L3_MAX_TOKENS=abc \
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  grep -qE 'max_tokens": ?32000' "$CAPFILE"
  grep -q "FLOW_KIT_L3_MAX_TOKENS='abc' 非法" "$STDERRFILE"
}

@test "AC-6 path2: FLOW_KIT_L3_THINKING=yes → fallback enabled (path2)" {
  FLOW_KIT_L3_THINKING=yes \
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  ! grep -q '"thinking"' "$CAPFILE"
  grep -q "FLOW_KIT_L3_THINKING='yes' 非法" "$STDERRFILE"
}

@test "AC-6 path1: FLOW_KIT_L3_TIMEOUT=空 → fallback 300 + warning (R1 补)" {
  FLOW_KIT_L3_TIMEOUT="" \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  grep -q -- '--max-time 300' "$CAPFILE"
  grep -q "FLOW_KIT_L3_TIMEOUT='' 非法" "$STDERRFILE"
}

@test "AC-6 path2: FLOW_KIT_L3_TIMEOUT=空 → fallback 300 + warning (R1 补)" {
  FLOW_KIT_L3_TIMEOUT="" \
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  grep -q -- '--max-time 300' "$CAPFILE"
  grep -q "FLOW_KIT_L3_TIMEOUT='' 非法" "$STDERRFILE"
}

@test "AC-6 path1: FLOW_KIT_L3_THINKING=空 → fallback enabled + warning (R1 补)" {
  FLOW_KIT_L3_THINKING="" \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  ! grep -q '"thinking"' "$CAPFILE"
  grep -q "FLOW_KIT_L3_THINKING='' 非法" "$STDERRFILE"
}

@test "AC-6 path2: FLOW_KIT_L3_THINKING=空 → fallback enabled + warning (R1 补)" {
  FLOW_KIT_L3_THINKING="" \
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  ! grep -q '"thinking"' "$CAPFILE"
  grep -q "FLOW_KIT_L3_THINKING='' 非法" "$STDERRFILE"
}

# ── AC-7: 可观测性 stderr 配置记录行（双路径）──

@test "AC-7 path1: stderr contains 'using max_tokens=X timeout=Y thinking=Z'" {
  FLOW_KIT_L3_MAX_TOKENS=16000 FLOW_KIT_L3_TIMEOUT=600 FLOW_KIT_L3_THINKING=disabled \
  ANTHROPIC_AUTH_TOKEN="fake-token" ANTHROPIC_BASE_URL="https://fake.example.com" \
  ANTHROPIC_API_KEY="" \
  _call_and_capture
  grep -q '\[l3-review\] using max_tokens=16000 timeout=600 thinking=disabled' "$STDERRFILE"
}

@test "AC-7 path2: stderr contains config record line" {
  FLOW_KIT_L3_MAX_TOKENS=16000 FLOW_KIT_L3_TIMEOUT=600 FLOW_KIT_L3_THINKING=disabled \
  ANTHROPIC_AUTH_TOKEN="" \
  ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  grep -q '\[l3-review\] using max_tokens=16000 timeout=600 thinking=disabled' "$STDERRFILE"
}
