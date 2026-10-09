FROM node:20-alpine AS builder

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@8.15.3 --activate

ENV NODE_ENV=development
ARG VITE_API_URL=https://api.laju.chat
ENV VITE_API_URL=${VITE_API_URL}

COPY package.json pnpm-workspace.yaml pnpm-lock.yaml* ./
COPY packages/shared-types ./packages/shared-types
COPY apps/backoffice ./apps/backoffice

RUN NODE_ENV=development pnpm install --frozen-lockfile=false --prod=false

WORKDIR /app/packages/shared-types
RUN pnpm build

WORKDIR /app/apps/backoffice
RUN pnpm build

FROM node:20-alpine AS runner

WORKDIR /app

RUN npm install -g serve

COPY --from=builder /app/apps/backoffice/dist ./dist

EXPOSE 3000

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
  CMD wget -q --spider http://127.0.0.1:3000/ || exit 1

CMD ["serve", "-s", "dist", "-l", "3000"]
