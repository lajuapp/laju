FROM node:20-alpine AS builder

WORKDIR /app

RUN apk add --no-cache libc6-compat
RUN corepack enable && corepack prepare pnpm@8.15.3 --activate

ENV NODE_ENV=development
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

WORKDIR /app
RUN pnpm --filter @secure-messenger/portal build

FROM node:20-alpine AS runner

WORKDIR /app

RUN apk add --no-cache libc6-compat

ENV NODE_ENV=production
ENV PORT=3002
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=builder /app/apps/portal/.next/standalone ./
COPY --from=builder /app/apps/portal/.next/static ./apps/portal/.next/static
COPY --from=builder /app/apps/portal/public ./apps/portal/public

EXPOSE 3002

CMD ["node", "apps/portal/server.js"]
