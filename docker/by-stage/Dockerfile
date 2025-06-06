FROM node:21-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run test:build

FROM node:21-alpine AS runtime
WORKDIR /app
COPY package*.json ./
RUN npm ci
# 从构建阶段复制构建产物
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/next.config.* ./

EXPOSE 3005
USER node
CMD ["./node_modules/.bin/next", "start", "-p", "3005"]
