# Design Context

## Users

CipherSwarm serves red team operators, blue team analysts, infrastructure administrators, and project managers working in **air-gapped, non-Internet-connected lab environments**. They manage distributed hash-cracking campaigns across 10+ agents with ~25 RTX 4090 GPUs, using attack resources (word lists, rule lists, mask lists) that routinely exceed 100 GB. The primary job: orchestrate attacks, monitor progress in real time, and review results — often across long-running operations where checking in periodically matters more than constant attention. The UI must never depend on external resources (CDNs, web fonts, external APIs).

### Brand Personality

**Technical, clean, efficient.** The interface should evoke **control and confidence** — operators should feel they know exactly what's happening at all times. Not flashy, not playful. An engineering tool that respects the user's expertise and gets out of the way.

### Aesthetic Direction

- **Theme**: Catppuccin Macchiato dark palette with DarkViolet accents (planned in v2-upgrade-overview.md)
- **References**: Linear/Vercel (clean, minimal, fast developer tool aesthetic) + Grafana/Datadog (dense dashboards, real-time metrics, data-forward)
- **Anti-references**: Generic Bootstrap apps, AI-generated "dashboard" aesthetics (gradient text, glassmorphism, hero metrics), overly playful or consumer-oriented SaaS
- **Mode**: Dark-first (Catppuccin Macchiato). Light mode is a future consideration, not a priority.

### Design Principles

1. **Information density over decoration** — Show data, not chrome. Every pixel should earn its place. Dense is fine if it's scannable.
2. **Hierarchy through typography, not ornamentation** — Use weight, size, and spacing to create hierarchy. Avoid borders, shadows, and containers when whitespace will do.
3. **Status at a glance** — Campaign/task/agent state must be immediately readable. Color-coded status indicators are a core design element, not an afterthought.
4. **Motion for feedback, not flair** — Animate state changes and loading. No decorative animations. Respect `prefers-reduced-motion`.
5. **WCAG 2.1 AA compliance** — Accessibility is a hard requirement, not a goal. Skip links, proper ARIA, 4.5:1 contrast ratios, keyboard navigation.
