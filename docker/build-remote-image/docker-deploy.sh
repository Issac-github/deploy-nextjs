#!/usr/bin/env bash

SERVER="root@47.107.49.154"
DEPLOY_PATH="/var/www/deploy-nextjs-docker"
DEPLOY_RESOURCE_UNZIP_PATH="/var/www/deploy-nextjs-docker/server"
DEPLOY_RESOURCE_PATH="/var/www/deploy-nextjs-docker/resource"
LOCAL_PORT="3007"

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
rm -fr node_modules
rm -fr next-package
mkdir next-package
cd next-package
npm init -y
npm i next@14.2.5
if [ $? -ne 0 ]; then
  echo "Build failed, exiting."
  exit 1
fi
cd ..
cp -r ./next-package/node_modules ./

rm -fr dist.zip
sudo zip -r dist.zip ./public ./.next ./next.config.mjs ./node_modules
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

    # 创建Dockerfile
    cat > Dockerfile << 'EOF'
FROM node:21-alpine
WORKDIR /app
COPY .next ./.next
COPY public ./public
COPY node_modules ./node_modules
# COPY next.config.mjs ./next.config.mjs

EXPOSE 3000
# CMD ["./node_modules/next/dist/bin/next", "start", "-p", "3000"]
CMD [\"./node_modules/next/dist/bin/next\", \"start\", \"-p\", \"3000\"]
EOF

  # 停止并删除已存在的容器
  docker stop nextjs-app 2>/dev/null || true
  docker rm nextjs-app 2>/dev/null || true

  # 构建并运行 Docker 容器
  docker build -t nextjs-app .
  docker run -d --name nextjs-app -p ${LOCAL_PORT}:3000 nextjs-app

  echo \"Next.js 应用已通过 Docker 在端口 ${LOCAL_PORT} 上启动\";
  
  # 等待容器启动并检查状态
  echo "等待容器启动...";
  sleep 3;

  # 检查容器是否正在运行
  if docker ps | grep -q nextjs-app; then
    echo "Next.js 应用已通过 Docker 在端口 ${LOCAL_PORT} 上启动";
    echo "容器状态: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep nextjs-app)";
    echo "访问地址: http://localhost:${LOCAL_PORT}";
  else
    echo "容器启动失败，查看日志:";
    docker logs nextjs-app;
    exit 1;
  fi
  "