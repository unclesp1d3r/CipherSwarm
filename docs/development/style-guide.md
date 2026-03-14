# CipherSwarm UI Style Guide

**Version:** 1.0\
**Last Reviewed:** 2025-10-12

This document defines the visual design and behavior standards for the CipherSwarm frontend. It ensures consistency across pages, components, and themes, while staying fully offline-capable and budget-friendly.

---

## 🎨 Color & Theme

### 🎨 Macchiato Palette Reference

| Role              | Token      | Hex       | Preview                                                                                                      |
| ----------------- | ---------- | --------- | ------------------------------------------------------------------------------------------------------------ |
| Text              | `text`     | `#cad3f5` | <span style="display:inline-block;width:1.5em;height:1.5em;background:#cad3f5;border:1px solid #ccc"></span> |
| Subtext           | `subtext0` | `#a5adcb` | <span style="display:inline-block;width:1.5em;height:1.5em;background:#a5adcb;border:1px solid #ccc"></span> |
| Surface           | `surface0` | `#363a4f` | <span style="display:inline-block;width:1.5em;height:1.5em;background:#363a4f;border:1px solid #ccc"></span> |
| Base              | `base`     | `#24273a` | <span style="display:inline-block;width:1.5em;height:1.5em;background:#24273a;border:1px solid #ccc"></span> |
| Mantle            | `mantle`   | `#1e2030` | <span style="display:inline-block;width:1.5em;height:1.5em;background:#1e2030;border:1px solid #ccc"></span> |
| Crust             | `crust`    | `#181926` | <span style="display:inline-block;width:1.5em;height:1.5em;background:#181926;border:1px solid #ccc"></span> |
| Overlay           | `overlay1` | `#5b6078` | <span style="display:inline-block;width:1.5em;height:1.5em;background:#5b6078;border:1px solid #ccc"></span> |
| Accent (lavender) | `lavender` | `#b7bdf8` | <span style="display:inline-block;width:1.5em;height:1.5em;background:#b7bdf8;border:1px solid #ccc"></span> |
| Accent (violet)   | `violet`   | `#a855f7` | <span style="display:inline-block;width:1.5em;height:1.5em;background:#a855f7;border:1px solid #ccc"></span> |

- **Base Theme**: Catppuccin **Macchiato**

  - Implemented via custom SCSS (`_catppuccin.scss`) with Bootstrap variable overrides
  - All 26 Macchiato palette colors defined as SCSS variables (e.g., `$ctp-violet`, `$ctp-text`)
  - Bootstrap theme variables (`$primary`, `$success`, etc.) mapped to Catppuccin colors before `@import "bootstrap"`

- **Accent Color**: DarkViolet lightened for dark-mode contrast (`#a855f7`)

  - Mapped as `$ctp-violet` in SCSS, assigned to Bootstrap's `$primary` variable
  - Used throughout UI for primary buttons, links, focus states, and highlights

- **Surface Hierarchy**: Creates visual depth via layered backgrounds

  - Crust (`#181926`): navbar
  - Mantle (`#1e2030`): sidebar, offcanvas
  - Base (`#24273a`): page background
  - Surface0 (`#363a4f`): cards, inputs, elevated surfaces

- **Component Overrides**: All Bootstrap components themed via `[data-bs-theme="dark"]` selector

  - Cards, tables, modals, dropdowns, list groups, form controls, Tom Select integration
  - See `application.bootstrap.scss` for full component theming rules

> Avoid true black. Ensure WCAG 2.1 AA contrast for all text-on-background combinations.

---

## 📐 Layout & Spacing

- Base layout follows a standard sidebar + navbar shell pattern

- Default spacing: use Bootstrap spacing utilities (`p-4`, `mb-3`, `gap-2`, etc.)

  - Avoid pixel units in layout code
  - Container: `.container-fluid` for full-width content areas

- Modals:

  - Bootstrap standard modal with centered backdrop
  - Use `.modal-dialog` with size modifiers (`.modal-lg`, `.modal-xl`) as needed

- Responsive sidebar:

  - Desktop: fixed sidebar (`.d-none .d-md-block`)
  - Mobile: off-canvas overlay triggered by navbar toggle

---

## 🖋 Typography

- **Headings**: Space Grotesk (variable, 300–700)

  - Geometric, technical aesthetic
  - Self-hosted via `@fontsource/space-grotesk`
  - Font files copied to `app/assets/builds/` by build script
  - Fallback: system-ui, sans-serif

- **Body Text**: IBM Plex Sans (400, 500, 600, 700)

  - Technical heritage, high legibility
  - Self-hosted via `@fontsource/ibm-plex-sans`
  - Fallback: system-ui, sans-serif

- **Monospace**: JetBrains Mono (variable, 100–800)

  - For hashes, masks, technical data, code blocks
  - Self-hosted via `@fontsource/jetbrains-mono`
  - Fallback: SFMono-Regular, Menlo, monospace

- **Font Loading**: All fonts use `font-display: swap` to prevent blocking

- **Sizing**: Use Bootstrap typography utilities

  - Headings: `.h1` through `.h6` or semantic `<h1>`–`<h6>`
  - Body: default size, `.small` for meta text
  - Display: `.display-1` through `.display-6` for hero text

> All fonts are air-gap safe — no CDN dependencies. Fonts are bundled in the asset pipeline.

---

## 🧱 Components & Architecture

### Component Architecture

- **Railsboot abstraction layer completely removed** (117 files deleted in PR #706)
- All views use plain ERB templates with Bootstrap utility classes directly
- No custom wrapper components — follow standard Bootstrap HTML patterns

### HTML & Bootstrap Patterns

- **Buttons**: Use Bootstrap classes directly

  - Primary: `.btn .btn-primary`
  - Secondary: `.btn .btn-outline-primary`
  - Danger: `.btn .btn-danger`

- **Modals**: Standard Bootstrap modal structure

  - Use `.modal`, `.modal-dialog`, `.modal-content`, `.modal-header`, `.modal-body`, `.modal-footer`
  - Size modifiers: `.modal-sm`, `.modal-lg`, `.modal-xl`

- **Toasts**: Bootstrap toast component

  - Danger toasts persist (no auto-hide)
  - Success/info toasts auto-dismiss after 5 seconds
  - Container: `#toast_container` with `.toast-container` class

- **Tables**: Standard Bootstrap table

  - Wrap in `.table-responsive` for horizontal scroll on mobile
  - Use `.table`, `.table-striped`, `.table-hover` as needed

- **Cards**: Bootstrap card component

  - Structure: `.card` > `.card-header`, `.card-body`, `.card-footer`
  - Themed via Catppuccin surface hierarchy

### Tooltip & Validation States

| Context        | Bootstrap Classes                    | Notes                                                        |
| -------------- | ------------------------------------ | ------------------------------------------------------------ |
| Tooltip (info) | `.tooltip` (Bootstrap JS component)  | Use data-bs-toggle="tooltip" for hover-based help            |
| Input (error)  | `.is-invalid` + `.invalid-feedback`  | Bootstrap validation classes; show error message below input |
| Toast (error)  | `.toast .border-danger .text-danger` | Used for system errors or failed actions                     |
| Toast (info)   | `.toast .border-info .text-info`     | Used for cracked hashes, import/export confirmations         |

Use Bootstrap's built-in tooltip component for any inline rule help or config explanations.

### Button & Badge Color Reference

| Element Type | State     | Bootstrap Classes                | Catppuccin Variable |
| ------------ | --------- | -------------------------------- | ------------------- |
| Button       | Primary   | `.btn .btn-primary`              | `$ctp-violet`       |
| Button       | Secondary | `.btn .btn-outline-primary`      | `$ctp-violet`       |
| Badge        | Success   | `.badge .bg-success`             | `$ctp-green`        |
| Badge        | Warning   | `.badge .bg-warning`             | `$ctp-yellow`       |
| Badge        | Error     | `.badge .bg-danger`              | `$ctp-red`          |
| Badge        | Info      | `.badge .bg-info`                | `$ctp-blue`         |

All colors are mapped in `_catppuccin.scss` and applied via Bootstrap's theming system.

---

## ♿ Accessibility

CipherSwarm targets WCAG 2.1 AA compliance for keyboard navigation, screen readers, and contrast.

### Skip Links

- Skip link added as first child of `<body>`: `<a href="#main-content" class="visually-hidden-focusable">Skip to main content</a>`
- Targets `<main id="main-content">` element
- Visible on keyboard focus

### Keyboard Navigation

- **Navbar dropdowns**: Use `<button type="button">` instead of `<a href="#">` to prevent scroll-to-top
- **Tab controller**: Enhanced with arrow-key navigation (left/right to navigate tabs)
- All interactive elements must be keyboard-accessible (focus states visible)

### ARIA Labels & Roles

- Navigation landmarks:
  - Sidebar `<ul>` has `aria-label="Main navigation"`
  - Navbar toggle has `aria-label="Toggle navigation"` or `aria-controls="sidebarOffcanvas"`
- Tab panels:
  - Use `role="tablist"`, `role="tab"`, `role="tabpanel"`
  - Active tab gets `aria-selected="true"`, inactive tabs `aria-selected="false"`
  - Inactive tabs set `tabindex="-1"`, active tab `tabindex="0"`
- Empty state icons:
  - Use `aria-hidden="true"` on decorative SVGs
  - Provide text alternatives for meaningful icons

### Semantic HTML

- Use semantic heading hierarchy (`<h1>` for page title, `<h2>` for major sections, etc.)
- Error pages use `<h1>` for error title
- Forms use `<label>` elements associated with inputs via `for` attribute
- Avoid inline styles for sizing — use CSS classes (e.g., `.empty-state-icon` instead of `style="font-size:64px"`)

### Color & Contrast

- Text color: `text-body-secondary` (Bootstrap 5.3 semantic class) instead of deprecated `text-muted`
- All text-on-background combinations meet WCAG 2.1 AA contrast ratio (4.5:1 for body text, 3:1 for large text)
- Focus states use high-contrast `$ctp-violet` outline

---

## 🧠 Behavioral Expectations

- Use async requests for fragment-based flows
- Use debounced input handlers (300ms delay) for live estimation
- Modal form actions must submit asynchronously and return partial HTML to update UI
- Real-time updates must trigger targeted data refreshes using appropriate state management
- Turbo morphing enabled via `turbo_refreshes_with(method: :morph, scroll: :preserve)` for smooth updates

---

## 🐝 Branding Motif

- Hexagons may be used as:

  - Low-opacity background overlays
  - Card or modal decoration

- Should not be bright yellow or overwhelming

- Must be inline SVG or local asset — no external fetch

---

### 🛠 Attack Type Icon Mapping (Bootstrap Icons)

| Attack Type               | Icon Name (Bootstrap Icons) | Rationale                           |
| ------------------------- | --------------------------- | ----------------------------------- |
| Dictionary                | `book`                      | Implies a wordlist or data set      |
| Mask (Manual)             | `terminal`                  | Symbolizes pattern-based input      |
| Brute Force (Incremental) | `hash`                      | Represents raw cryptographic attack |
| Previous Passwords        | `arrow-counterclockwise`    | Visual shorthand for reuse/history  |
| Hybrid (Dict + Mask)      | `puzzle-fill`               | Conveys two strategies joined       |
| Rule-based only           | `sliders`                   | Represents configurable modifiers   |
| Toggleable Modifiers      | `puzzle`                    | Abstracts modifiers as rule pieces  |

> Icons use Bootstrap Icons font loaded via `@import "bootstrap-icons"`. All icons are available offline via the asset pipeline.

---

## 🖥️ Viewport & Small Window Considerations

CipherSwarm is not designed for mobile-first usage but must remain usable in constrained browser windows (e.g., side-by-side dev consoles or dashboards).

- Minimum target resolution: 768px width (Bootstrap `md` breakpoint)

- Avoid horizontal scroll on core views like Campaign Detail and Agent List

- Overflowing tables or charts must:

  - Scroll horizontally inside `.table-responsive` wrapper
  - Provide pinned headers or key columns if feasible

- Toasts and modals must anchor to the viewport rather than parent containers

  - Toasts use `.position-fixed` and `.z-3` utility
  - Modals use Bootstrap's built-in viewport anchoring

- Responsive sidebars:

  - Desktop: `.d-none .d-md-block` sidebar visible
  - Mobile: `.d-md-none` offcanvas sidebar triggered by navbar toggle

---

## 📱 Responsive & Layout Guidance

- All views must be usable on a minimum screen width of 768px (tablet)
- Campaign and agent views should gracefully wrap or scroll
- Avoid fixed widths unless needed for modal constraints
- Use Bootstrap grid (`.row`, `.col-md-*`, `.col-lg-*`) for responsive layouts
- Don't use pixel units — use Bootstrap spacing utilities (`.p-4`, `.mb-3`, `.gap-2`, etc.)
- Sidebar must collapse below `md` breakpoint using standard responsive patterns

---

## 🧾 Max Width & Wrapping Conventions

- Modals: use `.modal-lg` or `.modal-xl` as needed; centered with backdrop
- Toasts: Bootstrap default width; pinned top-right via `.toast-container .position-fixed .top-0 .end-0`
- Tables: wrap in `.table-responsive` to prevent layout breakage
- Sidebar: fixed 2-column width (`.col-md-2`) on `md+`, offcanvas on mobile
- Cards/blocks: use `.container-fluid` or grid columns to control width
- Never hard-code pixel widths for primary layout regions — use Bootstrap utilities

---

## 📦 Offline & Zero-Budget Constraints

- All fonts, icons, and assets must work offline
- Fonts: self-hosted via `@fontsource` packages (Space Grotesk, IBM Plex Sans, JetBrains Mono)
- Icons: Bootstrap Icons font loaded via asset pipeline
- Do **not** rely on Google Fonts, CDN icons, or paid icon libraries
- All assets copied to `app/assets/builds/` by build scripts and served via Propshaft

