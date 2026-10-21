# Monorepo

One Git repository contains all applications and documentation.

```text
apps/api          NestJS
apps/worker       NestJS worker runtime
apps/mobile       Flutter Android
apps/backoffice   Next.js
apps/portal       Next.js Public Portal & Landing Page
packages/*        shared contracts/types/UI
docs/*            system documentation
```

No separate microservice repository is required.

Worker and API can use the same NestJS source tree/image while running different entry points.
