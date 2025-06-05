#!/usr/bin/env bash

SERVER="root@47.107.49.154"
DEPLOY_PATH="/var/www/deploy-nextjs-ordinary"
DEPLOY_RESOURCE_UNZIP_PATH="/var/www/deploy-nextjs-ordinary/server"
DEPLOY_RESOURCE_PATH="/var/www/deploy-nextjs-ordinary/resource"
PORT=3004

# 检查是否安装unzip
if ! command -v unzip &> /dev/null; then
  echo "错误: unzip 命令未找到，请安装 unzip"
  exit 1
fi

# 确保清理并重新构建
rm -rf .next
npm cache clean --force
rm -rf node_modules
npm i
npm run test:build

# 验证构建是否成功
if [ ! -d ".next" ]; then
  echo "错误: 构建失败，.next 目录不存在"
  exit 1
fi

# 检查构建 ID 是否存在
if [ ! -f ".next/BUILD_ID" ]; then
  echo "错误: .next/BUILD_ID 不存在，构建可能不完整"
  exit 1
fi

echo "构建成功，BUILD_ID: $(cat .next/BUILD_ID)"

# 继续部署流程
# rm -fr node_modules
# npm init -y
# npm i next@14.2.5
# if [ $? -ne 0 ]; then
#   echo "Build failed, exiting."
#   exit 1
# fi

rm -fr dist.zip
sudo zip -r dist.zip ./public ./.next ./package.json ./next.config.mjs ./node_modules ./Dockerfile
# 检查 zip 文件中是否包含 .next 目录
if ! unzip -l dist.zip | grep -q ".next"; then
  echo "错误: .next 目录未包含在 dist.zip 中"
  exit 1
fi

ssh ${SERVER} "mkdir -p ${DEPLOY_PATH}; mkdir -p ${DEPLOY_RESOURCE_PATH}; rm -rf ${DEPLOY_RESOURCE_PATH}/dist.zip"

scp ./dist.zip ${SERVER}:${DEPLOY_RESOURCE_PATH}/dist.zip

ssh ${SERVER} "rm -rf ${DEPLOY_RESOURCE_UNZIP_PATH};
  mkdir -p ${DEPLOY_RESOURCE_UNZIP_PATH};
  unzip ${DEPLOY_RESOURCE_PATH}/dist.zip -d ${DEPLOY_RESOURCE_UNZIP_PATH};
  rm -f ${DEPLOY_RESOURCE_PATH}/dist.zip;
  cd ${DEPLOY_RESOURCE_UNZIP_PATH};

  # 验证.next目录是否存在
  if [ ! -d \".next\" ]; then
    echo \"错误: 服务器上的.next目录不存在\";
    exit 1;
  fi;

  # 检查端口是否被占用(ipv6)
  netstat -tuln | grep ${PORT}

  # 检查端口是否被占用(ipv4)
  PID=$(sudo lsof -t -i :$PORT)
  if [ -z "$PID" ]; then
    echo "没有找到占用端口 $PORT 的进程"
  else
    echo "占用端口 $PORT 的进程 PID: $PID"
    kill -9 $PID
    echo "进程已终止"
  fi

  # 启动 Next.js 应用
  NODE_ENV=production nohup ./node_modules/next/dist/bin/next start -p ${PORT} & > ./next.log 2>&1 &
  echo \"Next.js 应用已在端口 ${PORT} 上启动\";"
