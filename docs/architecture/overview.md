# Architecture Overview

## Architecture style

- Modular Monolith
- Clean Architecture
- Use Case Pattern
- Event-driven internal lifecycle
- Transactional Outbox
- REST/HTTP for standard operations
- WebSocket/realtime where useful
- WebRTC for calls
- Docker Compose for deployment topology

## Trust boundaries

### Endpoint

The mobile application is the primary cryptographic endpoint.

### Backend

The backend is trusted to enforce business rules but is not normally trusted with message plaintext.

### Backoffice

Backoffice is trusted only according to explicitly assigned administrative permissions. It must not become a universal cryptographic authority.

### Infrastructure

PostgreSQL, Redis, Gotify, and SeaweedFS are treated as infrastructure components, not cryptographic endpoints.
