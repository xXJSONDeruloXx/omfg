#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_TAG="ppfg-linux-amd64-builder:latest"
SRC_DIR="${ROOT_DIR}/implementation/vk-layer-mvp"
BUILD_DIR="${ROOT_DIR}/build/linux-amd64/vk-layer-mvp"

mkdir -p "${BUILD_DIR}"

docker build \
  --platform linux/amd64 \
  -t "${IMAGE_TAG}" \
  -f "${ROOT_DIR}/docker/linux-amd64-builder.Dockerfile" \
  "${ROOT_DIR}"

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
