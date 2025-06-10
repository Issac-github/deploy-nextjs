#!/usr/bin/env bash

# # 配置参数
SERVER="root@47.107.49.154"
IMAGE_NAME="nextjs-app-docker"
IMAGE_TAG="latest"
CONTAINER_NAME="nextjs-ssr-container"
DEPLOY_PATH="/var/www/deploy-nextjs-docker"
PORT=3005

echo "=== 开始 Docker 镜像构建与部署过程 ==="

# 构建 Docker 镜像
echo "正在构建 Docker 镜像..."
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ./
if [ $? -ne 0 ]; then
  echo "错误: Docker 镜像构建失败"
  exit 1
fi
echo "Docker 镜像构建成功"

# 保存镜像为 tar 文件
echo "正在将镜像保存为 tar 文件..."
TARFILE="${IMAGE_NAME}-${IMAGE_TAG}.tar"
docker save ${IMAGE_NAME}:${IMAGE_TAG} -o ${TARFILE}
if [ $? -ne 0 ]; then
  echo "错误: 保存 Docker 镜像失败"
  exit 1
fi
echo "Docker 镜像已保存为 ${TARFILE}"

# 将镜像上传到服务器
echo "确保服务器部署目录 ${DEPLOY_PATH} 存在..."
ssh ${SERVER} "mkdir -p ${DEPLOY_PATH}"
if [ $? -ne 0 ]; then
  echo "错误: 无法在服务器上创建或确认目录 ${DEPLOY_PATH}"
  exit 1
fi
echo "服务器目录已确认/创建。"

echo "正在上传镜像 ${TARFILE} 到服务器 ${SERVER}:${DEPLOY_PATH}/ ..."
echo "这可能需要一些时间，具体取决于镜像大小和网络速度。"
# 使用 -v 参数增加 scp 的详细输出，帮助诊断问题
scp -v ${TARFILE} ${SERVER}:${DEPLOY_PATH}/${TARFILE}
if [ $? -ne 0 ]; then
  echo "错误: 上传 Docker 镜像到服务器失败"
  exit 1
fi
echo "Docker 镜像已成功上传到服务器"

# 在服务器上加载镜像并运行容器
echo "正在远程服务器上部署 Docker 容器..."
ssh ${SERVER} "
  # 加载 Docker 镜像
  echo '正在加载 Docker 镜像...'
  docker load -i ${DEPLOY_PATH}/${TARFILE}
  if [ \$? -ne 0 ]; then
    echo '错误: 加载 Docker 镜像失败'
    exit 1
  fi
  echo 'Docker 镜像已成功加载'

  # 停止并删除旧容器（如果存在）
  echo '检查并停止现有容器...'
  if docker ps -a | grep -q ${CONTAINER_NAME}; then
    docker stop ${CONTAINER_NAME} || true
    docker rm ${CONTAINER_NAME} || true
    echo '已停止并删除旧容器'
  fi

  # 运行新容器
  echo '启动新容器...'
  docker run -d --name ${CONTAINER_NAME} \
    -p ${PORT}:3004 \
    --restart unless-stopped \
    -e NODE_ENV=production \
    ${IMAGE_NAME}:${IMAGE_TAG}

  if [ \$? -ne 0 ]; then
    echo '错误: 启动 Docker 容器失败'
    exit 1
  fi

  # 清理
  echo '清理临时文件...'
  rm ${DEPLOY_PATH}/${TARFILE}

  echo '检查容器状态...'
  docker ps | grep ${CONTAINER_NAME}
"

echo "=== 部署完成! ==="
echo "容器应该现在正在运行，可通过 http://47.107.49.154:${PORT} 访问"

# 删除本地 tar 文件
rm ${TARFILE}
