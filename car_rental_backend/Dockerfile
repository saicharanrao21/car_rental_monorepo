# Multi-Stage Production & Staging Dockerfile for DriveGo Backend
# Stage 1: Build & Prune
FROM node:20-alpine AS builder

WORKDIR /app

# Install build dependencies
COPY package*.json ./
COPY prisma ./prisma/

RUN npm ci
RUN npx prisma generate

# Copy source and build
COPY tsconfig*.json nest-cli.json ./
COPY src ./src

RUN npm run build
RUN npm prune --omit=dev

# Stage 2: Production / Staging Runner
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=staging \
    PORT=3000

# Security: run as non-root user
USER node

# Copy build artifacts and dependencies from builder stage
COPY --chown=node:node package*.json ./
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/prisma ./prisma
COPY --chown=node:node --from=builder /app/dist ./dist

EXPOSE 3000

# Health check probe
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/src/main.js"]
