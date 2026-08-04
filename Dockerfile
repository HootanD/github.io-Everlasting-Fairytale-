# Build stage
FROM node:22.23-alpine3.23 AS build

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY app.js .

# Final stage
FROM node:22.23-alpine3.23

WORKDIR /app

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
