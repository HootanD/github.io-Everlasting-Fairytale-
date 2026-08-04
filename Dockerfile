# Build stage
FROM ubuntu:26.04 AS build

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends nodejs npm && rm -rf /var/lib/apt/lists/*
COPY package*.json ./
RUN npm install --production

COPY app.js .

# Final stage
FROM ubuntu:26.04

WORKDIR /app
RUN addgroup -g 1001 nodejs && adduser -u 1001 -G nodejs -s /bin/sh -D nodejs
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/app.js .
COPY --from=build /app/package*.json ./

EXPOSE 8080

ENV NODE_ENV=production
ENV PORT=8080
ENV NODE_OPTIONS=--no-warnings

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)}).on('error', () => process.exit(1))"

CMD ["node", "app.js"]
