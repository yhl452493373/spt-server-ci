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
  unzip -q -o "$MANAGED_ZIP_FILE"
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
    cp -r Build "$WORKSPACE/output/modules"
    echo "复制 Build 目录到 $WORKSPACE/output/modules"
  else
    mkdir -p "$WORKSPACE/output/modules"
    find bin/Release -name '*.dll' -o -name '*.exe' -o -name '*.config' | xargs -I {} cp --parents {} "$WORKSPACE/output/modules/" 2>/dev/null || true
    echo "复制 bin/Release 文件到 $WORKSPACE/output/modules"
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
    cp -r Build "$WORKSPACE/output/launcher"
    echo "复制 Build 目录到 $WORKSPACE/output/launcher"
  else
    mkdir -p "$WORKSPACE/output/launcher"
    find bin/Release -name '*.dll' -o -name '*.exe' -o -name '*.config' | xargs -I {} cp --parents {} "$WORKSPACE/output/launcher/" 2>/dev/null || true
    echo "复制 bin/Release 文件到 $WORKSPACE/output/launcher"
  fi

  mkdir "$WORKSPACE/output/launcher/SPT"
  mv "$WORKSPACE/output/launcher/SPT_Data" "$WORKSPACE/output/launcher/SPT/SPT_Data"
  mv "$WORKSPACE/output/launcher/SPT.Launcher.exe" "$WORKSPACE/output/launcher/SPT/SPT.Launcher.exe"
  mv "$WORKSPACE/output/launcher/LICENSE-Launcher.txt" "$WORKSPACE/output/launcher/SPT/LICENSE-Launcher.txt"

  cd "$WORKSPACE"
  echo "=== Launcher 编译完成 ==="

  echo "=== 克隆 build 仓库并复制静态资源 ==="

  # 克隆 build 仓库
  echo "克隆 build 仓库..."
  git clone https://github.com/sp-tarkov/build.git --branch "$SPT_BUILD_BRANCH" --depth 1 build-repo

  # 复制整个 static-assets-csharp 目录到 launcher
  if [ -d "build-repo/static-assets-csharp" ]; then
    echo "复制 static-assets-csharp 到 launcher..."
    cp -r build-repo/static-assets-csharp/* "$WORKSPACE/output/launcher/"
    echo "静态资源复制完成"
  else
    echo "警告: static-assets-csharp 目录不存在"
  fi

  cd "$WORKSPACE"
  echo "=== 静态资源复制完成 ==="
fi

# 复制版本信息
echo "复制版本信息文件..."
cp "version.info" "$WORKSPACE/output/"

# 如果是构建全部，将 Modules 整合到 Launcher 中
if [ "$BUILD_MODULES" = "true" ] && [ "$BUILD_LAUNCHER" = "true" ]; then
  echo "=== 整合 Modules 到 Launcher ==="
  cd "$WORKSPACE/output"

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
    cd "$WORKSPACE/output"
    echo "压缩目录: $(pwd)"
    echo "压缩文件: $ARCHIVE_NAME"

    zip -r -9 "$ARCHIVE_NAME" .

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
    cd "$WORKSPACE/output"
    echo "压缩目录: $(pwd)"
    echo "压缩文件: $ARCHIVE_NAME"

    zip -r -9 "$ARCHIVE_NAME" .

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