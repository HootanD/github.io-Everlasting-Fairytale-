# Build stage
FROM node:26-slim AS build

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY app.js .

# Final stage
FROM node:26-slim

WORKDIR /app

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/app.js .
COPY --from=build /app/package*.json ./

EXPOSE 8080

ENV NODE_ENV=production
ENV PORT=8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

CMD ["node", "app.js"]
