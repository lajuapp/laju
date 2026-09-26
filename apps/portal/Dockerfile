FROM node:20-alpine AS builder

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@8.15.3 --activate

ENV NODE_ENV=development
ARG NEXT_PUBLIC_API_URL=https://api.laju.chat
ARG NEXT_PUBLIC_APP_URL=https://laju.chat
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_APP_URL=${NEXT_PUBLIC_APP_URL}

COPY package.json pnpm-workspace.yaml pnpm-lock.yaml* ./
COPY packages/shared-types ./packages/shared-types
COPY apps/portal ./apps/portal

RUN pnpm install --frozen-lockfile=false --prod=false

WORKDIR /app/packages/shared-types
RUN pnpm build || true

WORKDIR /app/apps/portal
RUN pnpm build

FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3002

COPY --from=builder /app/apps/portal/.next/standalone ./
COPY --from=builder /app/apps/portal/.next/static ./apps/portal/.next/static
COPY --from=builder /app/apps/portal/public ./apps/portal/public

EXPOSE 3002

CMD ["node", "apps/portal/server.js"]
