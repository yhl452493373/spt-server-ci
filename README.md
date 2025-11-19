# SPT（塔科夫单机版） 构建脚本

+ [build-launcher.sh](build-launcher.sh) 用于构建启动器
+ [build-server.sh](build-server.sh) 用于构建服务端镜像
+ [bin](bin)目录下的[zip](bin/zip)和[unzip](bin/unzip)是ubuntu中使用的zip压缩和解压缩软件的二进制文件

## [build-launcher.sh](build-launcher.sh) 参数说明

参数列表：

+ -z, --zip FILE 指定编译 modules 时的 Managed.zip 文件路径 (编译 modules 时必需，且为第一个参数)
+ -m, --modules 只编译 modules
+ -l, --launcher 只编译 launcher
+ -a, --all 编译 modules 和 launcher (默认)
+ -o, --output DIR 指定输出目录 (默认: ./build-output)
+ -c, --compress 压缩输出为 7z 文件
+ -h, --help 显示此帮助信息

示例:

+ ./build-launcher.sh -z ./Managed.zip -a -c # 编译全部并压缩，-z必须是第一个参数
+ ./ -z ./Managed.zip -m -c # 只编译 modules 并压缩，-z必须是第一个参数
+ ./ -l -c # 只编译 launcher 并压缩，不需要-z

*`Managed.zip`为塔科夫目录下的`EscapeFromTarkov_Data/Managed`的zip压缩文件*

*编译后，把launcher解压，把解压后目录中launcher目录下的内容放到塔科夫根目录*

## [build-server.sh](build-server.sh) 构建说明

+ 如果提示无执行权限，需要先执行`sudo chmod a+x build-server.sh`赋权
+ macos或linux下需要先安装`docker-desktop`以使用`buildx`插件
+ windows下，先启用`wsl2`环境安装一个linux发行版，然后在`应用商店`下载`docker-desktop`，`docker-desktop`启动后才能执行
  `build-server.sh`，否则会提示`--platform`参数有问题