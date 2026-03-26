#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.steamdeck.local"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

: "${STEAMDECK_HOST:=192.168.0.241}"
: "${STEAMDECK_USER:=deck}"
: "${STEAMDECK_PASS:?Set STEAMDECK_PASS in the environment or .env.steamdeck.local}"

export STEAMDECK_HOST
export STEAMDECK_USER
export STEAMDECK_PASS
