#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_TAG="omfg-linux-amd64-builder:latest"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/_omfg_layer_impl.sh"

BUILD_DIR="${ROOT_DIR}/build/linux-amd64/${OMFG_LAYER_BUILD_SUBDIR}"
mkdir -p "${BUILD_DIR}"

"${ROOT_DIR}/scripts/compile-rust-shaders.sh"

docker build \
  --platform linux/amd64 \
  -t "${IMAGE_TAG}" \
  -f "${ROOT_DIR}/docker/linux-amd64-builder.Dockerfile" \
  "${ROOT_DIR}"

if [[ "${OMFG_LAYER_BUILD_SYSTEM}" == "cmake" ]]; then
  docker run --rm \
    --platform linux/amd64 \
    -v "${ROOT_DIR}:/workspace" \
    -w /workspace \
    "${IMAGE_TAG}" \
    bash -lc '
      set -euo pipefail
      cmake -S implementation/vk-layer-mvp -B build/linux-amd64/vk-layer-mvp -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
      cmake --build build/linux-amd64/vk-layer-mvp --verbose
      ls -lah build/linux-amd64/vk-layer-mvp/out
    '
  exit 0
fi

docker run --rm \
  --platform linux/amd64 \
  -v "${ROOT_DIR}:/workspace" \
  -w /workspace \
  "${IMAGE_TAG}" \
  bash -lc '
    set -euo pipefail
    cd implementation/vk-layer-rust
    cargo test --locked --offline
    cargo build --release --locked --offline
    mkdir -p /workspace/build/linux-amd64/vk-layer-rust/out
    cp target/release/libVkLayer_OMFG_rust.so /workspace/build/linux-amd64/vk-layer-rust/out/libVkLayer_OMFG_rust.so
    cp layer/VkLayer_OMFG_rust.json /workspace/build/linux-amd64/vk-layer-rust/out/VkLayer_OMFG_rust.json
    ls -lah /workspace/build/linux-amd64/vk-layer-rust/out
  '
