# Next.js Public Portal & Landing Page

`apps/portal` is the public-facing web presence for LAJU Messenger. It provides the landing page, product philosophy and manifesto, legal compliance documents, user help center, APK distribution gateway, and web-to-app smart deeplinks.

## Core Responsibilities

1. **Brand Showcase & Manifesto**: Articulates LAJU's "Calm by Design" and zero-knowledge privacy ethos.
2. **Product Transparency**: Discloses end-to-end encryption specs, privacy guarantees, and open-source licensing under GNU AGPLv3.
3. **Legal & Compliance**: Hosts living Privacy Policy, Terms of Service, and Community Guidelines.
4. **Distribution**: Serves the official Android `.apk` binary with dynamic versioning, file sizes, SHA-256 checksums, and download tracking.
5. **Smart Deep Linking**: Facilitates invitations and profile links (`/join/[code]`, `/u/[username]`) with fallback web interfaces.
6. **Multilingual Accessibility**: Comprehensive internationalization (i18n) across 5 languages (ID, EN, ZH, JA, RU).

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Styling**: Tailwind CSS 3.4
- **Icons**: Lucide React
- **Language**: TypeScript 5.4
- **Port**: `3002`

## Documentation Index

- [Design System & Layout Consistency](./design-system.md)
- [Pages and Routing Architecture](./pages-and-routing.md)
- [Localization & Multilingual Architecture](./localization.md)
