#!/usr/bin/env bash

# 从 MCPHub 源码构建并启动参数类型补丁版本。

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 独立仓库模式：通过 MCPHUB_SOURCE_DIR 指向 MCPHub 源码目录。
# 嵌入 MCPHub 源码的 patches/mcp-argument-coercion 目录时，自动回退到源码根目录。
REPO_ROOT="${MCPHUB_SOURCE_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PATCH_COMPOSE="$SCRIPT_DIR/docker-compose.patch.yml"
DEPLOY_DIR="${MCPHUB_DEPLOY_DIR:-/opt/mcphub}"
BASE_COMPOSE="$DEPLOY_DIR/docker-compose.yml"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
IMAGE_TAG="${MCPHUB_PATCH_IMAGE:-mcphub:patched-$(date +%Y%m%d-%H%M%S)}"

usage() {
  cat <<'EOF'
用法：
  ./build-and-run.sh             构建并启动补丁版本
  ./build-and-run.sh --build     只构建补丁镜像，不重启容器
  ./build-and-run.sh --rollback  恢复原 compose 中的官方镜像

环境变量：
  MCPHUB_DEPLOY_DIR=/opt/mcphub
  MCPHUB_SOURCE_DIR=/path/to/mcphub
  MCPHUB_PATCH_IMAGE=mcphub:patched-20260710
  DOCKER_PLATFORM=linux/amd64
EOF
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --rollback)
    [[ -f "$BASE_COMPOSE" ]] || { echo "找不到原始 compose：$BASE_COMPOSE" >&2; exit 1; }
    docker compose -f "$BASE_COMPOSE" up -d mcphub
    echo "已恢复原 compose 中的官方 MCPHub 镜像。"
    exit 0
    ;;
esac

[[ -f "$BASE_COMPOSE" ]] || { echo "找不到原始 compose：$BASE_COMPOSE" >&2; exit 1; }
[[ -f "$PATCH_COMPOSE" ]] || { echo "找不到补丁 compose：$PATCH_COMPOSE" >&2; exit 1; }
[[ -f "$REPO_ROOT/Dockerfile" ]] || { echo "找不到 MCPHub Dockerfile：$REPO_ROOT/Dockerfile，请设置 MCPHUB_SOURCE_DIR" >&2; exit 1; }

echo "构建补丁镜像：$IMAGE_TAG"
docker build --platform "$PLATFORM" --tag "$IMAGE_TAG" "$REPO_ROOT"

if [[ "${1:-}" == "--build" ]]; then
  echo "镜像构建完成：$IMAGE_TAG"
  exit 0
fi

echo "校验合并后的 Compose 配置……"
MCPHUB_PATCH_IMAGE="$IMAGE_TAG" docker compose \
  -f "$BASE_COMPOSE" -f "$PATCH_COMPOSE" config >/dev/null

echo "启动补丁版本 MCPHub……"
MCPHUB_PATCH_IMAGE="$IMAGE_TAG" docker compose \
  -f "$BASE_COMPOSE" -f "$PATCH_COMPOSE" up -d mcphub

docker inspect mcphub --format '当前镜像：{{.Config.Image}}'
echo "完成。原始 docker-compose.yml 和 .env 未被修改。"
