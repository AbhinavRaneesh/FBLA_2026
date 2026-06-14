# Design System — FBLA Member App

The shared visual language behind every screen. Centralizing these tokens kept the UI
consistent across 30+ screens and four platforms, and made the [mockups](WIREFRAMES.md) and
the shipped code agree. Constants live in [`lib/main.dart`](../lib/main.dart) (top of file).

---

## 1. Brand color palette

| Token | Hex | Swatch | Usage |
|---|---|---|---|
| `fblaNavy` | `#00274D` | 🟦 deep navy | Primary brand, button text on gold, headers |
| `fblaBlue` | `#1D4E89` | 🟦 mid blue | Secondary surfaces, glows |
| `fblaGold` | `#FDB913` | 🟨 gold | **Primary actions**, accents, coins, highlights |
| `accentBlue` | `#4D9DE0` | 🔵 bright blue | Focus rings, links, selection, info |
| `appBackground` | `#07111F` | ⬛ near-black navy | App background base |

**Login/sign-up backdrop** uses a richer 3-stop gradient (`#050E22 → #0E2A56 → #050E22`) and
is intentionally *not* reused elsewhere, to make the auth flow feel distinct.

### Semantic / state colors
| Purpose | Color |
|---|---|
| Success | `#1AA39A` (teal) / `#15803D` (light theme) |
| Warning / streak | `#FDB913` |
| Destructive | `#D9534F` / `#DC2626` |
| Error text | `#FF7A7A` |

### Course / category accents
Used for course levels, event types, and tour steps: `#2E6BC6` (blue), `#1AA39A` (teal),
`#6D5BD0` (violet), `#D9534F` (red), `#FFB300` (amber).

---

## 2. Typography

System font stack (San Francisco / Roboto / Segoe UI) for native feel and zero font payload.

| Role | Size | Weight | Notes |
|---|---|---|---|
| Display / splash | 40–44 | 900 | "FBLA" wordmark |
| Screen title | 20–22 | 800 | One per screen |
| Section header | 12–15 | 700–800 | Card and list headers |
| Body | 13–15 | 500 | 1.4–1.5 line height |
| Label / caption | 9–12 | 600 | Field labels, metadata |
| Button | 13–15 | 800 | Letter-spacing on the gold CTA |

Text honors the OS **text-scaling** setting (no hardcoded `textScaler` clamp) for accessibility.

---

## 3. Spacing & shape

- **Grid:** 4pt base; common steps 8 / 12 / 16 / 20 / 24.
- **Screen padding:** 24px horizontal (auth), 16–22px (content screens).
- **Corner radius:** 12–14 (fields/buttons), 16–20 (cards), 20+ (sheets/nav bar), full (chips/pills).
- **Elevation:** soft, colored shadows (e.g., gold glow under the primary button) instead of hard
  drop shadows — fits the dark theme.

---

## 4. Core components

| Component | Spec |
|---|---|
| **Primary button** | 52px tall, gold gradient (`#FFCE45→#FDB913→#E09A00`), navy 800 text, shimmer + press-scale (0.97) |
| **Text field** | 46–52px, translucent fill `white@4%`, animated focus ring in `accentBlue` + blue glow, left icon, inline error below |
| **Card** | `white@5%` fill, `white@10%` border, radius 20, optional 3px gradient top accent |
| **Chip / filter** | Pill; selected = gold (auth) or accent-blue (content) |
| **Bottom nav** | 5 tabs, floating rounded bar, active tab pill highlight + label |
| **Snackbar** | Floating; gold-on-navy for info/offline, red for errors |

---

## 5. Iconography & motion

- **Icons:** Material rounded set, consistently weighted; icon-only buttons always carry a
  `Tooltip` / `Semantics` label.
- **Motion:** purposeful and short — 150–240ms transitions, staggered card entrances, a breathing
  background glow, and a one-time press-scale on tappables. Nothing blocks input.

---

## 6. Accessibility tokens

- **Contrast:** body text targets WCAG AA on the dark surfaces; gold is reserved for large text /
  fills, not small body copy on light backgrounds.
- **Touch targets:** ≥ 44×44 logical px (verified by [`test/tap_target_probe_test.dart`](../test/tap_target_probe_test.dart)).
- **Labels:** every interactive control exposes a screen-reader label.
- **Text scaling:** layouts reflow with OS font-size settings.
- **Theme:** dark by default, with a light theme using the `fblaLight*` token set.

---

See it applied: [WIREFRAMES.md](WIREFRAMES.md) · token source: [`lib/main.dart`](../lib/main.dart)
