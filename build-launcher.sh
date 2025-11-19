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
SPT_SERVER_BRANCH="develop"
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
  ARCHIVE_NAME="SPT-Launcher-${SPT_VERSION}-$DATE_TIME-${CLIENT_VERSION}-L${LAUNCHER_COMMIT_ID}-M${MODULES_COMMIT_ID}.7z"
else
  if [ "$BUILD_MODULES" = true ]; then
    ARCHIVE_NAME="SPT-Modules-${SPT_VERSION}-$DATE_TIME-${CLIENT_VERSION}-${MODULES_COMMIT_ID}.7z"
  else
    ARCHIVE_NAME="SPT-Launcher-${SPT_VERSION}-$DATE_TIME-${CLIENT_VERSION}-${LAUNCHER_COMMIT_ID}.7z"
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

# 创建构建脚本
BUILD_SCRIPT="/tmp/spt-build-$$.sh"
cat > "$BUILD_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
set -e

# 参数
DATE_TIME="$1"
SPT_VERSION="$2"
CLIENT_VERSION="$3"
MODULES_COMMIT_ID="$4"
LAUNCHER_COMMIT_ID="$5"
BUILD_MODULES="$6"
BUILD_LAUNCHER="$7"
COMPRESS="$8"
ARCHIVE_NAME="$9"
MANAGED_ZIP_FILE="${10}"
SPT_MODULES_BRANCH="${11}"
SPT_LAUNCHER_BRANCH="${12}"
SPT_BUILD_BRANCH="${13}"
echo "开始执行构建脚本..."

# 工作目录
WORKSPACE="/tmp/build"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

echo "工作目录: $(pwd)"

# 保存版本信息
cat > "version.info" << VER_EOF
构建时间: $DATE_TIME
SPT版本: $SPT_VERSION
客户端版本: $CLIENT_VERSION
VER_EOF

# 根据编译的组件添加相应信息
if [ "$BUILD_MODULES" = "true" ]; then
    cat >> "version.info" << VER_EOF
Modules分支: $SPT_MODULES_BRANCH
Modules Commit: $MODULES_COMMIT_ID
VER_EOF
fi

if [ "$BUILD_LAUNCHER" = "true" ]; then
    cat >> "version.info" << VER_EOF
Launcher分支: $SPT_LAUNCHER_BRANCH
Launcher Commit: $LAUNCHER_COMMIT_ID
VER_EOF
fi

echo "版本信息已保存"

# 编译 Modules
if [ "$BUILD_MODULES" = "true" ]; then
    echo "=== 开始编译 Modules ==="

    # 克隆 Modules 仓库
    echo "克隆 Modules 仓库..."
    git clone https://github.com/sp-tarkov/modules.git --branch "$SPT_MODULES_BRANCH" --depth 1 modules

    # 解压 Managed.zip 文件
    echo "解压 Managed.zip 文件..."
    mkdir -p modules/project/Shared/Managed
    cd modules/project/Shared/Managed
    7z x "$MANAGED_ZIP_FILE" -aoa
    echo "Managed.zip 解压完毕."

    # 检查解压后是否有子目录，如果有则移动文件到当前目录
    if [ "$(ls -A | wc -l)" -eq 1 ] && [ -d "$(ls)" ]; then
        SUBDIR="$(ls)"
        echo "检测到子目录: $SUBDIR，移动文件到当前目录..."
        mv "$SUBDIR"/* . 2>/dev/null || true
        rmdir "$SUBDIR" 2>/dev/null || true
        echo "文件移动完成"
    fi

    # 编译 Modules
    echo "编译 Modules..."
    cd "$WORKSPACE/modules/project"
    dotnet build -c Release -p:Version="$SPT_VERSION"
    echo "Modules 编译完成!"

    # 复制编译结果
    echo "复制编译结果..."
    if [ -d 'Build' ]; then
        cp -r Build /output/modules
        echo "复制 Build 目录到 /output/modules"
    else
        mkdir -p /output/modules
        find bin/Release -name '*.dll' -o -name '*.exe' -o -name '*.config' | xargs -I {} cp --parents {} /output/modules/ 2>/dev/null || true
        echo "复制 bin/Release 文件到 /output/modules"
    fi

    cd "$WORKSPACE"
    echo "=== Modules 编译完成 ==="
fi

# 编译 Launcher
if [ "$BUILD_LAUNCHER" = "true" ]; then
    echo "=== 开始编译 Launcher ==="

    # 克隆 Launcher 仓库
    echo "克隆 Launcher 仓库..."
    git clone https://github.com/sp-tarkov/launcher.git --branch "$SPT_LAUNCHER_BRANCH" --depth 1 launcher

    # 编译 Launcher
    echo "编译 Launcher..."
    cd launcher/project
    dotnet build -c Release
    echo "Launcher 编译完成!"

    # 复制编译结果
    echo "复制编译结果..."
    if [ -d 'Build' ]; then
        cp -r Build /output/launcher
        echo "复制 Build 目录到 /output/launcher"
    else
        mkdir -p /output/launcher
        find bin/Release -name '*.dll' -o -name '*.exe' -o -name '*.config' | xargs -I {} cp --parents {} /output/launcher/ 2>/dev/null || true
        echo "复制 bin/Release 文件到 /output/launcher"
    fi

    mkdir /output/launcher/SPT
    mv /output/launcher/SPT_Data /output/launcher/SPT/SPT_Data
    mv /output/launcher/SPT.Launcher.exe /output/launcher/SPT/SPT.Launcher.exe
    mv /output/launcher/LICENSE-Launcher.txt /output/launcher/SPT/LICENSE-Launcher.txt

    cd "$WORKSPACE"
    echo "=== Launcher 编译完成 ==="

    echo "=== 克隆 build 仓库并复制静态资源 ==="

    # 克隆 build 仓库
    echo "克隆 build 仓库..."
    git clone https://github.com/sp-tarkov/build.git --branch "$SPT_BUILD_BRANCH" --depth 1 build-repo

    # 复制整个 static-assets-csharp 目录到 launcher
    if [ -d "build-repo/static-assets-csharp" ]; then
        echo "复制 static-assets-csharp 到 launcher..."
        cp -r build-repo/static-assets-csharp/* /output/launcher/
        echo "静态资源复制完成"
    else
        echo "警告: static-assets-csharp 目录不存在"
    fi

    cd "$WORKSPACE"
    echo "=== 静态资源复制完成 ==="
fi

# 复制版本信息
echo "复制版本信息文件..."
cp "version.info" /output/

# 如果是构建全部，将 Modules 整合到 Launcher 中
if [ "$BUILD_MODULES" = "true" ] && [ "$BUILD_LAUNCHER" = "true" ]; then
    echo "=== 整合 Modules 到 Launcher ==="
    cd /output

    # 如果存在 launcher 目录，将 modules 内容复制到 launcher 中
    if [ -d "launcher" ] && [ -d "modules" ]; then
        echo "将 Modules 文件整合到 Launcher 中..."

        # 复制 Modules 的所有文件到 launcher/Modules
        cp -r modules/* launcher/

        echo "Modules 文件已整合到 Launcher 目录"

        # 删除原始的 modules 目录
        rm -rf modules
    fi

    # 如果启用压缩，使用整合后的 launcher 目录进行压缩
    if [ "$COMPRESS" = "true" ]; then
        echo "=== 开始压缩整合后的文件 ==="
        cd /output
        echo "压缩目录: $(pwd)"
        echo "压缩文件: $ARCHIVE_NAME"

        7z a -mx=9 -md=128m -mfb=273 -ms=on -mmt=on "$ARCHIVE_NAME" .

        # 计算文件信息
        FILE_SIZE=$(stat -c %s "$ARCHIVE_NAME")
        FILE_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $FILE_SIZE / 1024 / 1024}")
        FILE_HASH=$(md5sum "$ARCHIVE_NAME" | awk '{print $1}' | xxd -r -p | base64)

        echo "压缩完成: $ARCHIVE_NAME"
        echo "文件大小: ${FILE_SIZE_MB} MB"
        echo "文件哈希: $FILE_HASH"

        # 清理未压缩的文件
        echo "清理原始文件..."
        find . -maxdepth 1 ! -name "$ARCHIVE_NAME" -type f -delete
        rm -rf launcher
        echo "=== 压缩完成 ==="
    fi
else
    # 单个组件压缩
    if [ "$COMPRESS" = "true" ]; then
        echo "=== 开始压缩 ==="
        cd /output
        echo "压缩目录: $(pwd)"
        echo "压缩文件: $ARCHIVE_NAME"

        7z a -mx=9 -m0=lzma2 "$ARCHIVE_NAME" .

        # 计算文件信息
        FILE_SIZE=$(stat -c %s "$ARCHIVE_NAME")
        FILE_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $FILE_SIZE / 1024 / 1024}")
        FILE_HASH=$(md5sum "$ARCHIVE_NAME" | awk '{print $1}' | xxd -r -p | base64)

        echo "压缩完成: $ARCHIVE_NAME"
        echo "文件大小: ${FILE_SIZE_MB} MB"
        echo "文件哈希: $FILE_HASH"

        # 清理未压缩的文件
        echo "清理原始文件..."
        find . -maxdepth 1 ! -name "$ARCHIVE_NAME" -type f -delete
        rm -rf modules launcher
        echo "=== 压缩完成 ==="
    fi
fi

echo "所有操作完成!"
SCRIPT_EOF

# 设置脚本权限
chmod +x "$BUILD_SCRIPT"

echo "临时构建脚本已创建: $BUILD_SCRIPT"

# 单次 Docker 运行执行所有操作
echo "启动构建容器..."
docker run --rm \
  -v "$(pwd)/$OUTPUT_DIR:/output" \
  -v "$(realpath $MANAGED_ZIP_FILE):/Managed.zip:ro" \
  -v "$BUILD_SCRIPT:/build.sh:ro" \
  refringe/spt-build-dotnet:2.1.0 \
  /build.sh \
  "$DATE_TIME" \
  "$SPT_VERSION" \
  "$CLIENT_VERSION" \
  "$MODULES_COMMIT_ID" \
  "$LAUNCHER_COMMIT_ID" \
  "$BUILD_MODULES" \
  "$BUILD_LAUNCHER" \
  "$COMPRESS" \
  "$ARCHIVE_NAME" \
  "/Managed.zip" \
  "$SPT_MODULES_BRANCH" \
  "$SPT_LAUNCHER_BRANCH" \
  "$SPT_BUILD_BRANCH"

# 清理临时脚本
rm -f "$BUILD_SCRIPT"
echo "临时构建脚本已清理"

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