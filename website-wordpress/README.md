# Wasl — WordPress website

Modern American-style website for **Wasl** (store delivery, Boston + Morocco),
built as a native WordPress **block theme** — full-site editing, no page builder,
no paid plugins.

## What it is

- **Theme:** `wasl/` — block theme (theme.json v3, WordPress 6.5+)
- **Design language:** modern American delivery-app style (Uber / DoorDash):
  white canvas, near-black ink, bold display type (Sora + Inter), pill buttons,
  soft cards. Wasl teal `#0C4A4E` + amber `#F2A81D` as brand accents.
- **Front page sections** (each a reusable pattern in `wasl/patterns/`):
  hero with live delivery card (#1044, Mira's Coffee), pilot stores,
  how it works (3 steps), interactive pickup-code demo (try **K7M2**),
  for stores, for drivers, pricing ($4–7/delivery Boston), coverage
  (Boston live, Morocco soon), FAQ, final CTA.
- **Templates:** front-page, index, page, single, 404, archive, search,
  plus a no-title page template. Header + footer template parts.
- **Extras:** `Midnight` dark style variation (`styles/midnight.json`),
  K7M2 demo script (`assets/js/demo.js`), extra CSS (`assets/css/extra.css`).
- **Demo bundle:** `blueprint.json` + `wasl.zip` — one click runs the whole
  site in WordPress Playground (see below).

## Install on real WordPress

1. Zip the `wasl/` folder (or use the ready `wasl.zip`).
2. WordPress admin → **Appearance → Themes → Add New → Upload Theme** →
   choose the zip → **Install** → **Activate**.
3. **Settings → Reading → Your homepage displays:** choose **A static page**,
   Homepage: **Home** (create it if missing — the front-page template
   renders the patterns automatically, the page itself stays empty).
4. Optional: **Appearance → Customize → Styles** → pick **Midnight** for the
   dark variation. Edit any section in **Appearance → Editor** (patterns are
   reusable blocks).

Requirements: WordPress 6.5+, PHP 7.4+. No plugins required.
Fonts load from Google Fonts (Inter + Sora) with a system-ui fallback.

## Try it in WordPress Playground (no install)

Online: upload this folder's `blueprint.json` + `wasl.zip` as a bundle, or run
locally with the Playground CLI (Node 20.18+):

```bash
cd wasl-website-wordpress
npx @wp-playground/cli@latest server --blueprint=./ --blueprint-may-read-adjacent-files
```

The blueprint installs + activates the theme, names the site "Wasl",
creates the Home page and sets it as the front page. Log in as
`admin` / `password` if you need the dashboard.

## Editing the content

- All copy lives in the patterns (`wasl/patterns/*.php`) — edit the text
  there, or override in the Site Editor (editor changes win over theme files).
- Prices, pilot stores and coverage are real Wasl facts as of Nov 2026:
  $4–7/delivery Boston, East Boston launch, Mira's Coffee + Chinese Dragon.
- The K7M2 demo code is in `assets/js/demo.js` (`CODE = 'K7M2'`).

## Files

```
wasl-website-wordpress/
├── blueprint.json          Playground demo bundle manifest
├── wasl.zip                Ready-to-upload theme zip
└── wasl/                   Theme source
    ├── style.css           Theme header (required)
    ├── theme.json          Design tokens (colors, type, spacing)
    ├── functions.php       Fonts, demo script, pattern categories
    ├── templates/          front-page, index, page, single, 404, archive, search
    ├── parts/              header, footer
    ├── patterns/           hero, logos, how-it-works, tracking, stores,
    │                       drivers, pricing, coverage, faq, cta
    ├── styles/             midnight.json (dark variation)
    └── assets/             css/extra.css, js/demo.js
```
