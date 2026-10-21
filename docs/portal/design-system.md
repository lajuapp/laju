# Portal Design System & Layout Guidelines

The LAJU portal adheres to an editorial, serene aesthetic known as **"Calm by Design"**. The visual language avoids loud gamification, high-contrast borders, or cluttered boxy widgets. Instead, it employs breathable ivory canvases, deep pine greens, disciplined typography, and consistent architectural layout patterns.

---

## 1. Color Palette

| Token | Hex Value | Purpose |
| :--- | :--- | :--- |
| `warm-100` | `#F5F4EF` | Main page canvas / global background |
| `warm-200` | `#EAE8DE` | Section divider lines (`border-t border-[#EAE8DE]`) |
| `pine-800` | `#0D382C` | Primary brand green (buttons, badges, strong accents) |
| `pine-700` | `#134E3E` | Hover state for primary buttons |
| `stone-200` | `#E7E5E4` | Subtle borders for images and elevated elements (`border-stone-200/80`) |
| `slate-900` | `#0F172A` | Primary text and major headlines |
| `slate-700` | `#334155` | Secondary text / lead paragraphs |
| `slate-600` | `#475569` | Body text and descriptions |
| `slate-500` | `#64748B` | Captions, metadata, and category tags |

---

## 2. Standard Section Patterns

To ensure uniformity across all landing and subpages (`/`, `/about`, `/privacy`, `/terms`, `/help`), components must follow standardized section structures.

### A. Architectural Pillars Pattern
Used across `/privacy`, `/terms`, `/help`, and `/about` to display core principles, pillars, or support channels.

**Rules**:
1. **Unboxed Layout**: Do **not** wrap pillar items in separate heavy cards (`bg-white rounded-3xl border shadow`). Pillars sit directly on the `#F5F4EF` canvas to maintain an open, breathable editorial layout.
2. **Icon Container**: Standardized to `h-10 w-10 rounded-xl bg-[#0D382C]/8 text-[#0D382C] flex items-center justify-center` with an icon size of `h-5 w-5`.
3. **No Hardcoded Numbering**: Titles must not include manual numbering prefixes (e.g. `1. `, `2. `) in the rendered UI.
4. **Typography**:
   - Section Title: `text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight`
   - Section Subtitle: `mt-1.5 text-xs sm:text-sm text-slate-600`
   - Pillar Title: `text-base font-bold text-slate-900`
   - Pillar Body: `text-xs sm:text-sm text-slate-600 leading-relaxed`
5. **Grid Spacing**: Responsive grid `grid-cols-1 sm:grid-cols-2 lg:grid-cols-3` (or `lg:grid-cols-4` for 4 items) with `gap-8 lg:gap-10`.

```tsx
{/* Example Architectural Pillars */}
<section className="pt-12 sm:pt-16 border-t border-[#EAE8DE] text-left">
  <div className="mb-10">
    <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
      {t('pillars_title')}
    </h2>
    <p className="mt-1.5 text-xs sm:text-sm text-slate-600">
      {t('pillars_sub')}
    </p>
  </div>

  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8 lg:gap-10 text-left">
    <div className="space-y-3">
      <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
        <ShieldCheck className="h-5 w-5" />
      </div>
      <h3 className="text-base font-bold text-slate-900">{t('pillar1_title')}</h3>
      <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">{t('pillar1_desc')}</p>
    </div>
  </div>
</section>
```

---

### B. Standard Action / Contact Rows
Used at the end of content sections (e.g., GitHub open-source links, privacy inquiries, legal contacts, support channels).

**Rules**:
1. Section heading with an icon: `text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5` with a `h-5 w-5` icon.
2. Explanatory paragraph: `text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl`.
3. Horizontal action bar:
   - Monospace info badge: `p-3 rounded-xl bg-white border border-stone-200 text-xs font-mono text-slate-800 font-semibold shadow-2xs`
   - Primary action button: `px-4 py-2.5 rounded-xl bg-[#0D382C] text-white text-xs font-bold hover:bg-[#134E3E] transition-colors inline-flex items-center gap-1.5`

```tsx
{/* Example Action / Contact Row */}
<section className="pt-10 sm:pt-12 border-t border-[#EAE8DE] space-y-4 pb-8 text-left">
  <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
    <Icon className="h-5 w-5 text-[#0D382C]" />
    <span>{t('section_title')}</span>
  </h3>
  <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
    {t('section_desc')}
  </p>
  <div className="flex flex-wrap items-center gap-3 pt-1">
    <div className="p-3 rounded-xl bg-white border border-stone-200 text-xs font-mono text-slate-800 font-semibold shadow-2xs">
      contact@laju.chat
    </div>
    <a
      href="mailto:contact@laju.chat"
      className="px-4 py-2.5 rounded-xl bg-[#0D382C] text-white text-xs font-bold hover:bg-[#134E3E] transition-colors inline-flex items-center gap-1.5"
    >
      <span>{t('cta_button_text')}</span>
      <ExternalLink className="h-3.5 w-3.5" />
    </a>
  </div>
</section>
```

---

### C. Photography and Showcase Framing
For imagery (smartphones, scenery, workspaces):
- Container: `rounded-[2rem] sm:rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 bg-white`
- Overlay gradients: subtle black or slate overlays (`bg-gradient-to-r from-slate-950/90 ...`) when rendering white typography over image assets.
- Captions: `mt-3.5 text-xs sm:text-sm text-slate-500 italic text-left pl-1`.
