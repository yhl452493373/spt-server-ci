# ================================
# BUILD STAGE
# ================================
#FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS build
#FROM mcr.azure.cn/dotnet/sdk:9.0-alpine AS build
FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build

ARG SPT_VERSION
ARG SPT_BUILD_TYPE
ARG SPT_BUILD_CONFIG

RUN apk add --no-cache git git-lfs wget && \
    git clone -b develop --depth=1 https://github.com/sp-tarkov/server-csharp.git /src && \
    cd /src && git lfs pull

WORKDIR /src

RUN dotnet publish ./SPTarkov.Server/SPTarkov.Server.csproj \
    -c $SPT_BUILD_CONFIG \
    -f net9.0 \
    -r linux-musl-x64 \
    -p:PublishSingleFile=true \
    -p:IncludeNativeLibrariesForSelfExtract=true \
    --self-contained false \
    -p:SptBuildType=$SPT_BUILD_TYPE \
    -p:SptVersion=$SPT_VERSION \
    -p:SptBuildTime=$(date +%Y%m%d) \
    -p:SptCommit=$(git rev-parse --short HEAD) \
    -p:IsPublish=true && \
    -p:LangVersion=preview && \
    ls -l /src/SPTarkov.Server/bin/$SPT_BUILD_CONFIG/net9.0/linux-musl-x64/publish

# ================================
# RUNTIME STAGE
# ================================
#FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS final
#FROM mcr.azure.cn/dotnet/aspnet:9.0-alpine AS final
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS final

ARG SPT_BUILD_CONFIG

RUN apk add --no-cache bash coreutils sed gawk iproute2 ca-certificates

WORKDIR /opt/spt-server

COPY --from=build /src/SPTarkov.Server/bin/$SPT_BUILD_CONFIG/net9.0/linux-musl-x64/publish/ /app/spt-server/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 6969

ENTRYPOINT ["/entrypoint.sh"]
