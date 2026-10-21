# Portal Localization (i18n)

The portal implements client-side multi-language internationalization using React Context and centralized JSON dictionary files.

## Supported Locales

| Code | Language | Flag Emoji | Dictionary Path |
| :--- | :--- | :--- | :--- |
| `id` | Bahasa Indonesia (Default) | 🇮🇩 | `apps/portal/locales/id.json` |
| `en` | English | 🇬🇧 | `apps/portal/locales/en.json` |
| `zh` | 简体中文 (Simplified Chinese) | 🇨🇳 | `apps/portal/locales/zh.json` |
| `ja` | 日本語 (Japanese) | 🇯🇵 | `apps/portal/locales/ja.json` |
| `ru` | Русский (Russian) | 🇷🇺 | `apps/portal/locales/ru.json` |

---

## Architecture & Usage

### 1. Context Provider (`LanguageContext.tsx`)
The `LanguageProvider` wraps the application inside `apps/portal/app/layout.tsx`.
- Detects the initial locale from browser settings or `localStorage` (`laju_portal_lang`).
- Falls back to `id` (Bahasa Indonesia) if the user's language is unsupported.
- Exposes:
  - `locale`: current active language code.
  - `setLocale(code)`: switches language and persists preference to `localStorage`.
  - `t(key)`: translation helper returning the translated string, with fallback to Indonesian if a key is absent in the target language.

### 2. Consuming in Components
```tsx
'use client';

import { useLanguage } from '@/context/LanguageContext';

export function ExampleComponent() {
  const { t, locale } = useLanguage();

  return (
    <h2>{t('about_principles_title')}</h2>
  );
}
```

---

## Maintenance & Key Synchronization Rules

1. **Synchronous Updates**: Whenever a key is added, modified, or removed, changes must be mirrored across **all 5 language files** (`id.json`, `en.json`, `zh.json`, `ja.json`, `ru.json`).
2. **Clean Typography**: Do not embed hardcoded item numbering (e.g. `1. `, `2. `) into translation titles intended for pillar cards or section lists. The layout must control semantic presentation.
3. **Semantic Naming**: Follow the page-prefix naming convention:
   - `hero_*`: Main landing page hero
   - `about_*`: Editorial manifesto and principles
   - `privacy_*`: Privacy guarantees, pillars, and articles
   - `terms_*`: Terms of service clauses and pillars
   - `help_*`: Help center, FAQ, and support channels
   - `download_*`: APK versioning and installation guide
