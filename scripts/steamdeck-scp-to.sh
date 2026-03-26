#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <local-path> <remote-path>" >&2
  exit 1
fi

LOCAL_PATH="$1"
REMOTE_PATH="$2"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_steamdeck_env.sh"

export LOCAL_PATH
export REMOTE_PATH

expect <<'EOF'
set timeout -1
set host $env(STEAMDECK_HOST)
set user $env(STEAMDECK_USER)
set pass $env(STEAMDECK_PASS)
set local_path $env(LOCAL_PATH)
set remote_path $env(REMOTE_PATH)

spawn scp -r \
  -o StrictHostKeyChecking=accept-new \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -- $local_path "$user@$host:$remote_path"

expect {
  -re ".*assword:.*" {
    send "$pass\r"
    exp_continue
  }
  eof
}
EOF
