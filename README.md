# Wasl (وصل) — Store Delivery App

A delivery app for restaurants, coffee shops and grocery stores. The store creates a
delivery to the customer, using the store's **own drivers first** and marketplace
drivers as backup/overflow only when the own driver is busy, off, or declines
(hybrid fleet).

**Launch markets:** Boston (USD, English) and Morocco (MAD, Arabic/French).
**Payment:** cash only at the start — the app records cash instead of moving it.
The driver returns all cash to the store, gets paid later, and keeps any tip.
**By design:** Wasl is global — markets, currencies, languages, zones and fees are
admin-configurable, never hard-coded.

**Status (2026-11-06): design is ready to show and test, NOT ready to build.**
Usability test Round 2 is in progress (see `docs/USABILITY_TEST.md`).

## What's in this repo

| Folder | Contents |
|---|---|
| `docs/` | The full study: concept, UX study, information architecture, backend plan, usability tests, final review, admin study, high-fi self-test |
| `brand/` | Wasl logo (SVG + PNG, EN + AR wordmarks), brand sheet, PNG render script |
| `backend-mindmap/` | Backend system mind map (image + zoomable HTML + generator scripts) |

## Key documents

- `docs/CONCEPT.md` — the idea, hybrid fleet, cash rule, markets
- `docs/UX_STUDY.md` — Google UX process: competitive audit, personas, pain points, interview plan
- `docs/IA.md` — 23 phone screens (Store S1–S10, Driver D1–D10, Customer C1–C3) + Admin A1–A8
- `docs/BACKEND.md` — Firebase plan: Firestore collections, Auth & rules, Cloud Functions (needs Blaze)
- `docs/USABILITY_TEST.md` — Round 1 (expert walkthrough: 4 Pass, 2 Partial) + Round 2 (real test, in progress)
- `docs/ADMIN_STUDY.md` — admin approvals, payment switches, revenue, live map of all deliveries
- `docs/REVIEW.md` — final review v2: ready to show and test, not ready to build

## Honest limits

- Personas and interview plans are hypotheses — **no real interviews have been done yet**.
- Prototype data (orders, drivers, prices) is sample data, not real.
- The $4–$7 per-delivery figure is Boston only and still to test; Morocco pricing is undecided.
- Open decisions blocking the build: payment decision (cash first vs card now), card fee,
  disputes rule, Morocco pricing, store nav (Chat vs Profile), map-tile confirmation on a real phone.

## Prototype

High-fidelity clickable prototype (23 screens + Admin A1–A8, Wasl branding, real maps):
https://benyahya7.github.io/wasl/
(Mirror: https://muse.ai/s/store-delivery-app-high-fidelity-zd6xfxpxqnw77xx/isJE--6RAkmjNnmOjxEJol54zKMI9J7EgVFAH_2CTa8)

## Stack (planned, not built)

Firebase (Firestore + Auth + Storage + Cloud Functions on Blaze), Google Maps,
Stripe deferred (cash only in the MVP).
