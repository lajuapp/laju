FROM node:20-alpine AS builder

WORKDIR /app

RUN apk add --no-cache openssl

RUN corepack enable && corepack prepare pnpm@8.15.3 --activate

# Copy workspace configuration
COPY package.json pnpm-workspace.yaml ./
COPY packages/shared-types ./packages/shared-types
COPY apps/api ./apps/api

# Install dependencies across monorepo
RUN pnpm install

# Build shared types
WORKDIR /app/packages/shared-types
RUN pnpm build

# Build API & Worker
WORKDIR /app/apps/api
RUN npx prisma generate
RUN npx tsc

FROM node:20-alpine AS runner

WORKDIR /app

RUN apk add --no-cache openssl
RUN corepack enable && corepack prepare pnpm@8.15.3 --activate

ENV NODE_ENV=production

# Copy built application and dependencies
COPY --from=builder /app/package.json /app/pnpm-workspace.yaml ./
COPY --from=builder /app/packages/shared-types ./packages/shared-types
COPY --from=builder /app/apps/api/dist ./apps/api/dist
COPY --from=builder /app/apps/api/prisma ./apps/api/prisma
COPY --from=builder /app/apps/api/package.json ./apps/api/package.json
COPY --from=builder /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=builder /app/node_modules ./node_modules

WORKDIR /app/apps/api

USER node

EXPOSE 3000

CMD ["node", "dist/main.js"]
