# SPT（塔科夫单机版） 构建脚本

+ [build-launcher.sh](build-launcher.sh) 用于在非docker环境中调用docker镜像构建启动器
+ [build.sh](build.sh) 是 [build-launcher.sh](build-launcher.sh)
  和 [BuildLauncher.yml](.github/workflows/BuildLauncher.yml) 中调用的脚本
+ [build-server.sh](build-server.sh) 用于构建服务端镜像，也是 [BuildServer.yml](.github/workflows/BuildServer.yml) 中调用的脚本
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

+ ./build-launcher.sh -z ./Managed.zip -a -c # 编译全部并压缩，-z 必须是第一个参数
+ ./build-launcher.sh -z ./Managed.zip -m -c # 只编译 modules 并压缩，-z 必须是第一个参数
+ ./build-launcher.sh -l -c # 只编译 launcher 并压缩，不需要 -z 

*`Managed.zip`为塔科夫目录下的`EscapeFromTarkov_Data/Managed`的zip压缩文件*

*编译后，把launcher解压，把解压后目录中launcher目录下的内容放到塔科夫根目录*

## [build-server.sh](build-server.sh) 构建说明

+ 如果提示无执行权限，需要先执行`sudo chmod a+x build-server.sh`赋权
+ macos或linux下需要先安装`docker-desktop`以使用`buildx`插件
+ windows下，先启用`wsl2`环境安装一个linux发行版，然后在`应用商店`下载`docker-desktop`，`docker-desktop`启动后才能执行
  `build-server.sh`，否则会提示`--platform`参数有问题

## Docker 镜像

[https://hub.docker.com/r/yhl452493373/spt-server](https://hub.docker.com/r/yhl452493373/spt-server)

```yml
services:
  spt-server:
    image: yhl452493373/spt-server:4.0.6-20251119-d13d2dd0
    container_name: spt-server
    restart: always
    volumes:
      - './data:/opt/spt-server/user'
    network_mode: host
    environment:
      - backendIp=192.168.31.244
      - backendPort=6969

```

## [BuildServer.yml](.github/workflows/BuildServer.yml) 工作流选项说明

+ 选择运行器系统
  - `ubuntu-latest`最新的 Ubuntu
  - `ubuntu-24.04`Ubuntu-24.04 LTS
  - `ubuntu-host`自建的运行器，如果你没自建运行器，不要选这个
+ 推送到 Docker Hub
  - 如果选中，则会尝试推送到 Docker Hub
  - 选中后，需要在项目的工作流中设置两个密钥`DOCKERHUB_USERNAME`和`DOCKERHUB_TOKEN`
    - `gitea`在 [这里](../../../settings/actions/secrets)
    - `github`在 [这里](../../../settings/secrets/actions)
+ 镜像输出路径
  - 如果提供了这个路径，服务端镜像构建完成后，会复制到这里
  - 如果你在自己的宿主机上的运行器中运行，可以在这个路径下复制导出的镜像进行本地测试
