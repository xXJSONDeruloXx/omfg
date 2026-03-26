#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_steamdeck_env.sh"

REMOTE_CMD="${*:-bash -l}"
REMOTE_CMD_QUOTED="$(REMOTE_CMD="$REMOTE_CMD" python3 -c 'import os, shlex; print(shlex.quote(os.environ["REMOTE_CMD"]))')"
REMOTE_SHELL_CMD="bash -lc ${REMOTE_CMD_QUOTED}"
export REMOTE_SHELL_CMD

expect <<'EOF'
set timeout -1
set host $env(STEAMDECK_HOST)
set user $env(STEAMDECK_USER)
set pass $env(STEAMDECK_PASS)
set remote_shell_cmd $env(REMOTE_SHELL_CMD)

spawn ssh -tt \
  -o StrictHostKeyChecking=accept-new \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  "$user@$host" \
  $remote_shell_cmd

expect {
  -re ".*assword:.*" {
    send "$pass\r"
    exp_continue
  }
  eof
}
EOF
