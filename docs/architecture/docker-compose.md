# Docker Compose

```text
api
worker
backoffice
postgres
redis
gotify
seaweedfs-master
seaweedfs-volume
seaweedfs-filer
```

## Exposure

Public:
- reverse proxy
- API HTTPS
- Backoffice HTTPS
- Gotify only when operationally required

Internal:
- PostgreSQL
- Redis
- SeaweedFS
- worker

Backoffice should reach NestJS through a controlled API path and must never reach PostgreSQL directly.

## Container controls

- non-root
- minimal images
- pinned production versions/digests
- no privileged containers
- no Docker socket
- dropped capabilities
- health checks
- resource limits
- secrets outside Git
- internal network for stateful services
