FROM node:20-alpine AS builder

WORKDIR /app

RUN apk add --no-cache openssl

RUN corepack enable && corepack prepare pnpm@8.15.3 --activate

# Explicitly ensure NODE_ENV is development during build so devDependencies (tsc, prisma, etc.) are installed
ENV NODE_ENV=development

# Copy workspace configuration
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml* ./
COPY packages/shared-types ./packages/shared-types
COPY apps/api ./apps/api

# Install all dependencies including devDependencies
RUN pnpm install --frozen-lockfile=false --prod=false

# Build shared types
WORKDIR /app/packages/shared-types
RUN pnpm build

# Build API & Worker
WORKDIR /app/apps/api
RUN rm -f tsconfig.tsbuildinfo && npx prisma generate && pnpm build
RUN test -s dist/main.js && test -s dist/worker/main.js

FROM node:20-alpine AS runner

WORKDIR /app

RUN apk add --no-cache openssl curl
RUN corepack enable && corepack prepare pnpm@8.15.3 --activate

ENV NODE_ENV=production

# Copy built application and dependencies with proper ownership
COPY --chown=node:node --from=builder /app/package.json /app/pnpm-workspace.yaml ./
COPY --chown=node:node --from=builder /app/packages/shared-types ./packages/shared-types
COPY --chown=node:node --from=builder /app/apps/api/dist ./apps/api/dist
COPY --chown=node:node --from=builder /app/apps/api/prisma ./apps/api/prisma
COPY --chown=node:node --from=builder /app/apps/api/package.json ./apps/api/package.json
COPY --chown=node:node --from=builder /app/apps/api/node_modules ./apps/api/node_modules
COPY --chown=node:node --from=builder /app/node_modules ./node_modules

WORKDIR /app/apps/api

USER node

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=10 \
  CMD curl -f http://127.0.0.1:3000/health || exit 1

CMD ["sh", "-c", "npx prisma db push --accept-data-loss --skip-generate || true; node dist/main.js"]
