#!/usr/bin/env bats
# test_makefile_gates.bats — Makefile 门禁机检（health-fix-2026-09c · T08 · AC-10）
#
# 判据：make test「单跑不重复」（C7）经 PATH shim 计数钉死：
#   shim 目录前置 PATH，内含假 npx / 假 bats 计数器脚本——每次被调即向计数文件追加
#   一行（内容 = 该工具收到的参数形态），并秒回最小 TAP（真跑全量要几分钟，shim 让
#   make test 毫秒级返回）。旧实现（tap|tail 展示一遍 + >/dev/null 重跑一遍取 rc）
#   = npx 被调 2 次 → 计数 2 行；C7 合并后单次执行 → 恰 1 行。
# 命令行形态：recipe 以 `npx bats test/ --formatter tap` 调 bats ⇒ 假 npx 收到
#   `bats test/ --formatter tap`；假 npx **不得**转调 bats（PATH 上假 bats 会再计一行
#   → 计数=2 假红），假 bats 仅防御 recipe 直呼 bats 的形态变化。计数行以工具名开头，
#   断言 `^npx bats` 即同时钉住「经 npx 调用」这一形态。
# 失败透传（C7 配套）：假 npx rc=1 时 make test 必须非 0——recipe 用
#   ${PIPESTATUS[0]} 取 bats 真实 rc（防 tee/tail 吃 rc，L-098 管道吞 rc 反模式）。
# 并发闸配合（C1）：make test recipe 持 flock；FLOW_KIT_TEST_LOCK 指向沙箱私有锁
#   ——否则与外层已持默认锁的全量 make test 互等（自死锁）。TMPDIR 一并指向沙箱，
#   隔离 mktemp 唯一日志（失败路径保留的 TAP 日志随沙箱清理，不留残渣）。
# 镜像：flow-kit-bundle/test/test_makefile_gates.bats 内容逐字节相同（手动双写，不跑 make test-sync）。

setup() {
  SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/mkfg-XXXXXX")"
  mkdir -p "$SANDBOX/tmp-ok" "$SANDBOX/tmp-fail"
  COUNT_OK="$SANDBOX/count-ok.log"
  COUNT_FAIL="$SANDBOX/count-fail.log"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

teardown() {
  [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
  return 0
}

# 造 shim 目录：$1=目录 $2=计数文件 $3=假退出码（npx/bats 双写同款）
make_shim() {
  mkdir -p "$1"
  for tool in npx bats; do
    cat > "$1/$tool" <<SHIM
#!/usr/bin/env bash
echo "$tool \$*" >> "$2"
printf '1..1\nok 1 shim-$tool\n'
exit "$3"
SHIM
    chmod +x "$1/$tool"
  done
}

@test "make test 单跑执行：npx bats 恰被调一次（AC-10 shim 计数 = 1）" {
  make_shim "$SANDBOX/shim-ok" "$COUNT_OK" 0
  cd "$REPO_ROOT"
  run env \
    FLOW_KIT_TEST_LOCK="$SANDBOX/lock-ok" \
    FLOW_KIT_TEST_LOCK_WAIT=30 \
    TMPDIR="$SANDBOX/tmp-ok" \
    PATH="$SANDBOX/shim-ok:$PATH" \
    make test
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ bats: all tests passed"* ]]
  [ -f "$COUNT_OK" ]
  [ "$(wc -l < "$COUNT_OK")" -eq 1 ]
  grep -q '^npx bats' "$COUNT_OK"
}

@test "make test 失败透传：bats rc=1 → make test 非 0（PIPESTATUS 不被 tee 吃）" {
  make_shim "$SANDBOX/shim-fail" "$COUNT_FAIL" 1
  cd "$REPO_ROOT"
  run env \
    FLOW_KIT_TEST_LOCK="$SANDBOX/lock-fail" \
    FLOW_KIT_TEST_LOCK_WAIT=30 \
    TMPDIR="$SANDBOX/tmp-fail" \
    PATH="$SANDBOX/shim-fail:$PATH" \
    make test
  [ "$status" -ne 0 ]
  [[ "$output" == *"❌ bats: some tests failed"* ]]
  [ "$(wc -l < "$COUNT_FAIL")" -eq 1 ]
}
