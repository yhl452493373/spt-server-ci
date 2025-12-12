#!/bin/bash

set -e

# 显示帮助信息
show_help() {
  cat << EOF
用法: $0 [选项]

选项:
    -z, --zip FILE        指定编译 modules 时的 Managed.zip 文件路径 (编译 modules 时必需)
    -m, --modules         只编译 modules
    -l, --launcher        只编译 launcher
    -a, --all             编译 modules 和 launcher (默认)
    -o, --output DIR      指定输出目录 (默认: ./build-output)
    -c, --compress        压缩输出为 7z 文件
    -h, --help            显示此帮助信息

示例:
    $0 -z ./Managed.zip -a -c                  # 编译全部并压缩
    $0 -z ./Managed.zip -m -c                  # 只编译 modules 并压缩
    $0 -l -c                                 # 只编译 launcher 并压缩
EOF
}

# 解析命令行参数
MANAGED_ZIP_FILE=""
BUILD_MODULES=false
BUILD_LAUNCHER=false
BUILD_ALL=true
OUTPUT_DIR="./build-output"
COMPRESS=false

while [[ $# -gt 0 ]]; do
  case $1 in
  -z|--zip)
    MANAGED_ZIP_FILE="$2"
    shift 2
    ;;
  -m|--modules)
    BUILD_MODULES=true
    BUILD_ALL=false
    shift
    ;;
  -l|--launcher)
    BUILD_LAUNCHER=true
    BUILD_ALL=false
    shift
    ;;
  -a|--all)
    BUILD_MODULES=true
    BUILD_LAUNCHER=true
    BUILD_ALL=true
    shift
    ;;
  -o|--output)
    OUTPUT_DIR="$2"
    shift 2
    ;;
  -c|--compress)
    COMPRESS=true
    shift
    ;;
  -h|--help)
    show_help
    exit 0
    ;;
  *)
    echo "未知参数: $1"
    show_help
    exit 1
    ;;
  esac
done

# 如果指定了 --all，则编译两者
if [ "$BUILD_ALL" = true ]; then
  BUILD_MODULES=true
  BUILD_LAUNCHER=true
fi

# 参数验证
if [ "$BUILD_MODULES" = true ] && [ -z "$MANAGED_ZIP_FILE" ]; then
  echo "错误: 编译 modules 需要指定 zip 文件，使用 -z 参数"
  exit 1
fi

if [ "$BUILD_MODULES" = true ] && [ ! -f "$MANAGED_ZIP_FILE" ]; then
  echo "错误: 找不到 zip 文件: $MANAGED_ZIP_FILE"
  exit 1
fi

# 自动获取版本信息
echo "正在获取版本信息..."
DATE_TIME=$(date +%Y%m%d)
SPT_SERVER_REPOSITORY="sp-tarkov/server-csharp"
SPT_SERVER_BRANCH="main"
SPT_MODULES_REPOSITORY="sp-tarkov/modules"
SPT_MODULES_BRANCH="master"
SPT_LAUNCHER_REPOSITORY="sp-tarkov/launcher"
SPT_LAUNCHER_BRANCH="master"
SPT_BUILD_BRANCH="main"

# 获取 SPT 版本
SPT_VERSION=$(git ls-remote --tags "https://github.com/$SPT_SERVER_REPOSITORY.git" | awk -F'/' '{print $NF}' | grep -v '\^{}' | sort -V | tail -1)
SPT_VERSION=$(echo "$SPT_VERSION" | cut -d'-' -f1)
echo "SPT 版本: $SPT_VERSION"

# 获取客户端版本
CLIENT_VERSION=$(wget -qO- "https://raw.githubusercontent.com/$SPT_SERVER_REPOSITORY/refs/heads/$SPT_SERVER_BRANCH/Libraries/SPTarkov.Server.Assets/SPT_Data/configs/core.json" | jq -r '.compatibleTarkovVersion')
echo "客户端版本: $CLIENT_VERSION"

# 获取 Modules Commit ID
MODULES_COMMIT_ID=$(git ls-remote "https://github.com/$SPT_MODULES_REPOSITORY.git" "refs/heads/$SPT_MODULES_BRANCH" | awk '{print $1}')
MODULES_COMMIT_ID=${MODULES_COMMIT_ID:0:8}
echo "Modules Commit: $MODULES_COMMIT_ID"

# 获取 Launcher Commit ID
LAUNCHER_COMMIT_ID=$(git ls-remote "https://github.com/$SPT_LAUNCHER_REPOSITORY.git" "refs/heads/$SPT_LAUNCHER_BRANCH" | awk '{print $1}')
LAUNCHER_COMMIT_ID=${LAUNCHER_COMMIT_ID:0:8}
echo "Launcher Commit: $LAUNCHER_COMMIT_ID"

# 生成压缩文件名
if [ "$BUILD_ALL" = true ]; then
  ARCHIVE_NAME="SPT-Launcher-${SPT_VERSION}-$DATE_TIME-${CLIENT_VERSION}-L${LAUNCHER_COMMIT_ID}-M${MODULES_COMMIT_ID}.zip"
else
  if [ "$BUILD_MODULES" = true ]; then
    ARCHIVE_NAME="SPT-Modules-${SPT_VERSION}-$DATE_TIME-${CLIENT_VERSION}-${MODULES_COMMIT_ID}.zip"
  else
    ARCHIVE_NAME="SPT-Launcher-${SPT_VERSION}-$DATE_TIME-${CLIENT_VERSION}-${LAUNCHER_COMMIT_ID}.zip"
  fi
fi

# 显示构建信息
echo ""
echo "=== SPT 自动构建 ==="
echo "构建时间: $DATE_TIME"
echo "输出目录: $OUTPUT_DIR"
[ "$COMPRESS" = true ] && echo "压缩文件: $ARCHIVE_NAME"
[ "$BUILD_MODULES" = true ] && echo "编译: Modules ✓"
[ "$BUILD_LAUNCHER" = true ] && echo "编译: Launcher ✓"
echo "版本信息: SPT $SPT_VERSION, 客户端 $CLIENT_VERSION"
echo "=================="

# 清理和准备目录
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 构建 Docker 命令
DOCKER_CMD="docker run --rm"

# 添加必要的卷挂载
DOCKER_CMD="$DOCKER_CMD -v \"$(pwd)/$OUTPUT_DIR:/tmp/build/output\""
DOCKER_CMD="$DOCKER_CMD -v \"./build.sh:/build.sh:ro\""
DOCKER_CMD="$DOCKER_CMD -v \"./bin/zip:/usr/bin/zip:ro\""
DOCKER_CMD="$DOCKER_CMD -v \"./bin/unzip:/usr/bin/unzip:ro\""

# 只有编译 modules 时才挂载 Managed.zip
if [ "$BUILD_MODULES" = true ] && [ -n "$MANAGED_ZIP_FILE" ] && [ -f "$MANAGED_ZIP_FILE" ]; then
  MANAGED_ZIP_PATH=$(realpath "$MANAGED_ZIP_FILE")
  DOCKER_CMD="$DOCKER_CMD -v \"$MANAGED_ZIP_PATH:/Managed.zip:ro\""
  # 传递实际的文件路径给构建脚本
  MANAGED_ZIP_ARG="/Managed.zip"
else
  # 如果不编译 modules，传递空字符串
  MANAGED_ZIP_ARG=""
fi

# zip和unzip权限设置为可执行
chmod a+x bin/*

# 添加容器镜像和构建脚本
DOCKER_CMD="$DOCKER_CMD mcr.microsoft.com/dotnet/sdk:9.0"
DOCKER_CMD="$DOCKER_CMD /build.sh"
DOCKER_CMD="$DOCKER_CMD \"$DATE_TIME\""
DOCKER_CMD="$DOCKER_CMD \"$SPT_VERSION\""
DOCKER_CMD="$DOCKER_CMD \"$CLIENT_VERSION\""
DOCKER_CMD="$DOCKER_CMD \"$MODULES_COMMIT_ID\""
DOCKER_CMD="$DOCKER_CMD \"$LAUNCHER_COMMIT_ID\""
DOCKER_CMD="$DOCKER_CMD \"$BUILD_MODULES\""
DOCKER_CMD="$DOCKER_CMD \"$BUILD_LAUNCHER\""
DOCKER_CMD="$DOCKER_CMD \"$COMPRESS\""
DOCKER_CMD="$DOCKER_CMD \"$ARCHIVE_NAME\""
DOCKER_CMD="$DOCKER_CMD \"$MANAGED_ZIP_ARG\""
DOCKER_CMD="$DOCKER_CMD \"$SPT_MODULES_BRANCH\""
DOCKER_CMD="$DOCKER_CMD \"$SPT_LAUNCHER_BRANCH\""
DOCKER_CMD="$DOCKER_CMD \"$SPT_BUILD_BRANCH\""

# 执行 Docker 命令
echo "执行命令: $DOCKER_CMD"
eval $DOCKER_CMD

# 最终脚本示例
#docker run --rm \
#  -v "$(pwd)/$OUTPUT_DIR:/tmp/build/output" \
#  -v "$(realpath $MANAGED_ZIP_FILE):/Managed.zip:ro" \
#  -v "./build.sh:/build.sh:ro" \
#  -v "./bin/zip:/usr/bin/zip:ro" \
#  -v "./bin/unzip:/usr/bin/unzip:ro" \
#  mcr.microsoft.com/dotnet/sdk:9.0 \
#  /build.sh \
#  "$DATE_TIME" \
#  "$SPT_VERSION" \
#  "$CLIENT_VERSION" \
#  "$MODULES_COMMIT_ID" \
#  "$LAUNCHER_COMMIT_ID" \
#  "$BUILD_MODULES" \
#  "$BUILD_LAUNCHER" \
#  "$COMPRESS" \
#  "$ARCHIVE_NAME" \
#  "/Managed.zip" \
#  "$SPT_MODULES_BRANCH" \
#  "$SPT_LAUNCHER_BRANCH" \
#  "$SPT_BUILD_BRANCH"


echo ""
echo "=== 构建完成 ==="
if [ "$COMPRESS" = true ]; then
  echo "压缩文件: $OUTPUT_DIR/$ARCHIVE_NAME"
  if [ -f "$OUTPUT_DIR/$ARCHIVE_NAME" ]; then
    ls -lh "$OUTPUT_DIR/$ARCHIVE_NAME"
  else
    echo "错误: 压缩文件未生成"
  fi
else
  echo "输出目录: $OUTPUT_DIR"
  if [ -d "$OUTPUT_DIR" ]; then
    ls -la "$OUTPUT_DIR"
    [ -d "$OUTPUT_DIR/modules" ] && echo -e "\nModules 文件数量: $(find "$OUTPUT_DIR/modules" -type f | wc -l)"
    [ -d "$OUTPUT_DIR/launcher" ] && echo "Launcher 文件数量: $(find "$OUTPUT_DIR/launcher" -type f | wc -l)"
  else
    echo "错误: 输出目录未生成"
  fi
fi