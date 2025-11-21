#!/bin/bash
SPT_SERVER_REPOSITORY=sp-tarkov/server-csharp
SPT_SERVER_BRANCH=develop

SPT_BUILD_TYPE=RELEASE #LOCAL, DEBUG, RELEASE, BLEEDING_EDGE, BLEEDING_EDGE_MODS
SPT_VERSION=$(git ls-remote --tags "https://github.com/$SPT_SERVER_REPOSITORY.git" | awk -F'/' '{print $NF}' | grep -v '\^{}' | sort -V | tail -1)
SPT_VERSION=$(echo $SPT_VERSION | cut -d'-' -f1)
SPT_COMMIT_ID=$(git ls-remote "https://github.com/$SPT_SERVER_REPOSITORY.git" refs/heads/$SPT_SERVER_BRANCH | awk '{print $1}')
SPT_COMMIT_ID=${SPT_COMMIT_ID:0:8}
CLIENT_VERSION=$(wget -qO- "https://raw.githubusercontent.com/$SPT_SERVER_REPOSITORY/refs/heads/$SPT_SERVER_BRANCH/Libraries/SPTarkov.Server.Assets/SPT_Data/configs/core.json" | jq -r '.compatibleTarkovVersion')
DATE_TIME=$(date +%Y%m%d)

echo "SPT服务端构建类型：$SPT_BUILD_TYPE"
echo "SPT服务端版本：$SPT_VERSION"
echo "SPT服务端提交ID：$SPT_COMMIT_ID"
echo "适用客户端版本：$CLIENT_VERSION"
echo "构建日期：$DATE_TIME"

IMAGE_TAG="yhl452493373/spt-server:$SPT_VERSION-$DATE_TIME-$SPT_COMMIT_ID"

echo "开始构建镜像"

# 先删除可能存在的旧标签文件
rm -rf image_tag.txt

docker buildx build \
  --platform linux/amd64 \
  -t $IMAGE_TAG \
  --build-arg SPT_VERSION=$SPT_VERSION \
  --build-arg SPT_BUILD_TYPE=$SPT_BUILD_TYPE \
  --build-arg SPT_BUILD_CONFIG=Release \
  -f Dockerfile .

# 检查上一个命令的退出状态
if [ $? -ne 0 ]; then
  echo "错误：Docker 镜像构建失败！"
  exit 1
fi

echo "镜像构建完毕"

# 构建成功后，将镜像标签保存到文件
echo "$IMAGE_TAG" > image_tag.txt
echo "镜像标签已保存到 image_tag.txt: $IMAGE_TAG"
