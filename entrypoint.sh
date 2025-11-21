#!/bin/sh

# 文件对比
if [ -f /opt/spt-server/SPTarkov.Server ]; then
  appHash=$(md5sum /app/spt-server/SPTarkov.Server | awk '{ print $1 }')
  exeHash=$(md5sum /opt/spt-server/SPTarkov.Server | awk '{ print $1 }')
  if [ "$appHash" = "$exeHash" ]; then
    echo "MD5 verification successful!"
  else
    echo "MD5 mismatch, copy files to /opt/spt-server."
    cp -r /app/spt-server /opt
    echo "Finished!"
  fi
else
  echo "Program is not found, copy files to /opt/spt-server."
  cp -r /app/spt-server /opt
  echo "Finished!"
fi

cd /opt/spt-server || exit

# IP 配置
IP="${ip:-0.0.0.0}"

# 自动获取IP,端口等配置
BACKEND_IP="${backendIp:-$(ip route get 1 | awk '{print $7}')}"
PORT="${backendPort:-6969}"
PINGDELAYMS="${webSocketPingDelayMs:-90000}"

# 配置文件替换
sed -Ei "s/\"ip\": \".*?\",/\"ip\": \"${IP}\",/g" SPT_Data/configs/http.json
sed -Ei "s/\"port\": [0-9]+,/\"port\": ${PORT},/g" SPT_Data/configs/http.json
sed -Ei "s/\"backendIp\": \".*?\",/\"backendIp\": \"${BACKEND_IP}\",/g" SPT_Data/configs/http.json
sed -Ei "s/\"backendPort\": [0-9]+,/\"backendPort\": ${PORT},/g" SPT_Data/configs/http.json
sed -Ei "s/\"webSocketPingDelayMs\": [0-9]+,/\"webSocketPingDelayMs\": ${PINGDELAYMS},/g" SPT_Data/configs/http.json

# 日志文件创建
if [ ! -f "sptLogger.json" ]; then
  if [ -f "sptLogger.Development.json" ]; then
    cp sptLogger.Development.json sptLogger.json
  fi
fi

chmod +x SPT.Server
exec ./SPT.Server
