FROM mcr.microsoft.com/dotnet/sdk:9.0 AS server-builder
ARG SPT_VERSION
ARG SPT_BUILD_TYPE
ARG SPT_BUILD_CONFIG
RUN apt update && apt install -y git git-lfs wget && \
    git clone -b develop --depth=1 https://github.com/sp-tarkov/server-csharp.git /snapshot && \
    cd /snapshot && git lfs pull && \
    cd /snapshot && \
    dotnet publish ./SPTarkov.Server/SPTarkov.Server.csproj \
      -c $SPT_BUILD_CONFIG  \
      -f net9.0  \
      -r linux-x64  \
      -p:IncludeNativeLibrariesForSelfExtract=true  \
      -p:PublishSingleFile=true  \
      --self-contained false  \
      -p:SptBuildType=$SPT_BUILD_TYPE  \
      -p:SptVersion=$SPT_VERSION  \
      -p:SptBuildTime=$( date +%Y%m%d )  \
      -p:SptCommit=$(git rev-parse --short HEAD)  \
      -p:IsPublish=true && \
    rm SPTarkov.Server/bin/$SPT_BUILD_CONFIG/net9.0/linux-x64/publish/*.pdb && \
    rm -rf /var/lib/apt/lists/*

FROM mcr.microsoft.com/dotnet/aspnet:9.0-bookworm-slim
ARG SPT_BUILD_CONFIG
LABEL author="yhl452493373 <yhl452493373@gmail.com>"
ENV TZ=Asia/Shanghai
COPY --from=server-builder /snapshot/SPTarkov.Server/bin/$SPT_BUILD_CONFIG/net9.0/linux-x64/publish/ /app/spt-server/
VOLUME /opt/spt-server
WORKDIR /opt/spt-server
EXPOSE 6969
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
