# Build stage
FROM node:26-alpine AS build

WORKDIR /app
COPY package*.json ./
RUN npm install --production --omit=dev --legacy-peer-deps

COPY app.js .

# Final stage
FROM node:26-alpine

WORKDIR /app
RUN addgroup -g 1001 nodejs && adduser -u 1001 -G nodejs -s /bin/sh -D nodejs
COPY --from=build --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nodejs:nodejs /app/app.js .
COPY --from=build --chown=nodejs:nodejs /app/package*.json ./

USER nodejs

EXPOSE 8080

ENV NODE_ENV=production
ENV PORT=8080
ENV NODE_OPTIONS=--no-warnings

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)}).on('error', () => process.exit(1))"

CMD ["node", "app.js"]
