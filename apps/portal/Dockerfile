FROM node:20-slim AS builder

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@8.15.3 --activate

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

ARG NEXT_PUBLIC_API_URL=https://api.laju.chat
ARG NEXT_PUBLIC_APP_URL=https://laju.chat
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_APP_URL=${NEXT_PUBLIC_APP_URL}

COPY package.json pnpm-workspace.yaml pnpm-lock.yaml* ./
COPY packages/shared-types ./packages/shared-types
COPY apps/portal ./apps/portal

# Force development install so all build tools are installed
RUN NODE_ENV=development pnpm install --frozen-lockfile=false --prod=false

WORKDIR /app/packages/shared-types
RUN pnpm build || true

WORKDIR /app/apps/portal
RUN NODE_ENV=production pnpm run build

FROM node:20-slim AS runner

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable && corepack prepare pnpm@8.15.3 --activate

ENV NODE_ENV=production
ENV HOSTNAME="0.0.0.0"
ENV PORT=3002
ENV NEXT_TELEMETRY_DISABLED=1

COPY --chown=node:node --from=builder /app/package.json /app/pnpm-workspace.yaml ./
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/packages/shared-types ./packages/shared-types
COPY --chown=node:node --from=builder /app/apps/portal ./apps/portal

WORKDIR /app/apps/portal

EXPOSE 3002

HEALTHCHECK --interval=5s --timeout=3s --start-period=15s --retries=5 \
  CMD curl -f http://127.0.0.1:3002/ || exit 1

CMD ["node_modules/.bin/next", "start", "-H", "0.0.0.0", "-p", "3002"]
