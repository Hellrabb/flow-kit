#!/usr/bin/env bats
# test_install_dsh_platform.bats — install.sh dsh 平台分支（dsh-flow-kit 插件化）
# dsh 平台 install.sh 不落盘，打印插件安装指引并 exit 0。

setup() {
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -f "$d/flow-kit-bundle/install.sh" ]; do
    d="$(dirname "$d")"
  done
  INSTALL_SH="$d/flow-kit-bundle/install.sh"
  [ -f "$INSTALL_SH" ] || skip "install.sh not found"
}

@test "install.sh --platform dsh prints plugin guidance and exits 0" {
  run bash "$INSTALL_SH" --platform dsh --global
  [ "$status" -eq 0 ]
  [[ "$output" == *"dsh-flow-kit"* ]]
  [[ "$output" == *"dsh plugin --profile"* ]]
  [[ "$output" == *".flow-kit"* ]]
}

@test "paths.sh resolve_paths dsh sets .flow-kit project dir" {
  local paths_sh
  paths_sh="$(dirname "$INSTALL_SH")/lib/paths.sh"
  run bash -c "source '$paths_sh' && resolve_paths dsh && echo \"\$PROJECT_DIR_NAME|\$PLATFORM_CONFIG_DIR|\$USER_AGENTS_MD\""
  [ "$status" -eq 0 ]
  [[ "$output" == *".flow-kit|"* ]]
  [[ "$output" == *"$HOME/.dsh"* ]]
}
