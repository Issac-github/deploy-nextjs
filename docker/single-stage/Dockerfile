FROM node:21-alpine
# Install dependencies only when needed
# Check GitHub - nodejs/docker-node at b4117f9333da4138b03a546ec926ef50a31506c3 to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
RUN mkdir -p /app
COPY .next /app/.next
COPY public /app/public
COPY node_modules /app/node_modules

WORKDIR /app
CMD ["npx", "next", "start", "-p", "3004"]
