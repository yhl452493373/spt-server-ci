#!/bin/bash
SERVER_URL=https://github.com
REPOSITORY_SPT_SERVER=sp-tarkov/server-csharp
BRANCH=develop

latest_tag=$(git ls-remote --tags $SERVER_URL/$REPOSITORY_SPT_SERVER.git | awk -F'/' '{print $NF}' | grep -v '\^{}' | sort -V | tail -1)

SPT_BUILD_TYPE=RELEASE #LOCAL, DEBUG, RELEASE, BLEEDING_EDGE, BLEEDING_EDGE_MODS
SPT_VERSION=$(echo $latest_tag | cut -d'-' -f1)
SPT_COMMIT_ID=$(git ls-remote $SERVER_URL/$REPOSITORY_SPT_SERVER.git refs/heads/$BRANCH | awk '{print $1}')
SPT_COMMIT_ID=${SPT_COMMIT_ID:0:8}
CLIENT_VERSION=$(wget -qO- "https://raw.githubusercontent.com/$REPOSITORY_SPT_SERVER/refs/heads/$BRANCH/Libraries/SPTarkov.Server.Assets/SPT_Data/configs/core.json" | jq -r '.compatibleTarkovVersion')
DATE_TIME=$(date +%Y%m%d)

echo "SPT服务端构建类型：$SPT_BUILD_TYPE"
echo "SPT服务端版本：$SPT_VERSION"
echo "SPT服务端提交ID：$SPT_COMMIT_ID"
echo "适用客户端版本：$CLIENT_VERSION"
echo "构建日期：$DATE_TIME"

docker buildx build \
  --platform linux/amd64 \
  -t yhl452493373/spt-server:$SPT_VERSION-$DATE_TIME-$SPT_COMMIT_ID \
  --build-arg SPT_VERSION=$SPT_VERSION \
  --build-arg SPT_BUILD_TYPE=$SPT_BUILD_TYPE \
  --build-arg SPT_BUILD_CONFIG=Release \
  -f Dockerfile .

echo "AMD64镜像构建完毕，若无需ARM64镜像，则直接终止脚本，否则按任意键"

read -n 1 -s -r -p "按任意键继续构建ARM64镜像，或按 Ctrl+C 终止..."

echo "开始构建ARM64镜像"

docker buildx build \
  --platform linux/arm64 \
  -t yhl452493373/spt-server:$SPT_VERSION-$DATE_TIME-$SPT_COMMIT_ID-arm64 \
  --build-arg SPT_VERSION=$SPT_VERSION \
  --build-arg SPT_BUILD_TYPE=$SPT_BUILD_TYPE \
  --build-arg SPT_BUILD_CONFIG=Release \
  -f Dockerfile-arm64 .

echo "ARM64镜像构建完毕"