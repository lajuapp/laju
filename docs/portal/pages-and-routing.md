# Portal Pages and Routing

The portal uses Next.js 14 App Router under `apps/portal/app`.

## Route Directory

| Route | Indonesian Alias | Component / Page | Purpose |
| :--- | :--- | :--- | :--- |
| `/` | — | `app/page.tsx` | Main landing page: Hero, Features, Security, Disappearing Messages, Download CTA |
| `/about` | `/tentang` | `app/about/page.tsx` | Brand manifesto, editorial background, Core Principles, GNU AGPLv3 open-source link |
| `/privacy` | — | `app/privacy/page.tsx` | No-PII guarantees, zero-knowledge architecture, 4 pillars, full policy articles |
| `/terms` | — | `app/terms/page.tsx` | Terms of service, acceptable use, copyleft terms, data sovereignty |
| `/help` | `/bantuan` | `app/help/page.tsx` | User help center, FAQ, backup PIN/key management, technical support channels |
| `/download` | — | `app/download/page.tsx` | Direct APK download, live version resolution, SHA-256 hash, installation guide |
| `/join/[code]` | — | `app/join/[code]/page.tsx` | Group invitation smart redirector (launches app or falls back to download) |
| `/u/[username]` | — | `app/u/[username]/page.tsx` | User profile / direct chat invite smart redirector |

---

## Page Anatomy

### 1. Main Landing Page (`/`)
Structured as a sequence of full-bleed or container-bound sections:
- **`HeroSection`**: Headlines, direct APK download button, secondary features link, and quick horizontal value props.
- **`FeaturesSection`**: Dual phone mockup showcasing chat & group interfaces alongside 5 itemized capabilities.
- **`SecuritySection`**: Background notebook photography with 4 sleek glassmorphic overlay cards.
- **`DisappearingMessagesSection`**: Twilight lake scenic image illustrating ephemeral messaging and peace of mind.
- **`DownloadCTA`**: Workspace device layout prompting download of mobile app.

### 2. Editorial Manifesto (`/about` & `/tentang`)
Presents the philosophical foundation of LAJU:
- Back button to home (`/`).
- Editorial header (Tag: "MANIFESTO", H1 headline, and lead paragraph).
- Full-width serene atmospheric photo (`disappearing-lake.jpg`).
- Editorial prose body (Sections 1 & 2 analyzing digital noise and the longing for peace).
- Core Principles section (unboxed architectural pillars pattern).
- Open Source closing note with AGPLv3 statement and direct GitHub repository link.

### 3. Legal & Policy Pages (`/privacy` & `/terms`)
Formal compliance and technical transparency:
- Hero with core guarantees grid (2x2 with checkmarks).
- 4 Architectural Pillars defining data sovereignty and cryptographic rights.
- Numbered policy articles with collapsible / sectioned technical clauses.
- Dedicated inquiries action row (email + copyable badge).

### 4. Smart Redirectors (`/join/[code]`, `/u/[username]`)
Client components that detect user-agent and deep-link protocol (`laju://`):
- Attempts to launch the installed native application via intent / URI scheme.
- Displays fallback web card with QR code, invitation details, and direct APK download link if app is not installed.
