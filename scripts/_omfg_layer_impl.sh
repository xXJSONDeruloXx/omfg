#!/usr/bin/env bash
set -euo pipefail

: "${OMFG_LAYER_IMPL:=mvp}"

case "${OMFG_LAYER_IMPL}" in
  mvp|cpp)
    export OMFG_LAYER_IMPL="mvp"
    export OMFG_LAYER_BUILD_SUBDIR="vk-layer-mvp"
    export OMFG_LAYER_NAME="VK_LAYER_OMFG_mvp"
    export OMFG_LAYER_ENABLE_ENV="ENABLE_OMFG_MVP"
    export OMFG_LAYER_DISABLE_ENV="DISABLE_OMFG_MVP"
    export OMFG_LAYER_LIB_BASENAME="libVkLayer_OMFG_mvp.so"
    export OMFG_LAYER_MANIFEST_BASENAME="VkLayer_OMFG_mvp.json"
    export OMFG_LAYER_REMOTE_BASE_DEFAULT="/home/deck/post-proc-fg-research/deploy/vk-layer-mvp"
    export OMFG_LAYER_ARTIFACT_ROOT_REL="artifacts/steamdeck"
    export OMFG_LAYER_SOURCE_DIR="implementation/vk-layer-mvp"
    export OMFG_LAYER_BUILD_SYSTEM="cmake"
    ;;
  rust)
    export OMFG_LAYER_IMPL="rust"
    export OMFG_LAYER_BUILD_SUBDIR="vk-layer-rust"
    export OMFG_LAYER_NAME="VK_LAYER_OMFG_rust"
    export OMFG_LAYER_ENABLE_ENV="ENABLE_OMFG_RUST"
    export OMFG_LAYER_DISABLE_ENV="DISABLE_OMFG_RUST"
    export OMFG_LAYER_LIB_BASENAME="libVkLayer_OMFG_rust.so"
    export OMFG_LAYER_MANIFEST_BASENAME="VkLayer_OMFG_rust.json"
    export OMFG_LAYER_REMOTE_BASE_DEFAULT="/home/deck/post-proc-fg-research/deploy/vk-layer-rust"
    export OMFG_LAYER_ARTIFACT_ROOT_REL="artifacts/steamdeck/rust"
    export OMFG_LAYER_SOURCE_DIR="implementation/vk-layer-rust"
    export OMFG_LAYER_BUILD_SYSTEM="cargo"
    ;;
  *)
    echo "Unsupported OMFG_LAYER_IMPL=${OMFG_LAYER_IMPL}. Expected one of: mvp, rust" >&2
    exit 1
    ;;
esac
