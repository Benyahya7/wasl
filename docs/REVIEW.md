# Store Delivery App — Last Review (v2, final)
Date: 2026-11-06 ~15:46 | Reviewer: Raiss (self-review, not a real user test)
Scope reviewed: CONCEPT.md, UX_STUDY.md, IA.md v0.2, BACKEND.md, ADMIN_STUDY.md, USABILITY_TEST.md, wireframes artifact `store-delivery-app-wireframes`, high-fidelity prototype artifact `store-delivery-app-high-fidelity-prototype`, IA sitemap artifact `store-delivery-app-ia-sitemap`, Wasl logo (`workspace/your_files/wasl-logo/`), backend mind map (`workspace/your_files/wasl-backend-mindmap.png`), MEMORY.md

## Fix status — 2026-11-06 ~15:48, after the user's "Yes, fix N1–N4 now"
**N1–N4 FIXED and verified by grep.** N1: BACKEND.md now has `users.verificationStatus` (+ reason + submittedByStore), `stores.paymentMethods` (cash on / card off, never both off), the `markets` collection, Wasl revenue in `payouts`, and a full Admin section (approvals as a server transaction, admin-only writes). N2: CONCEPT.md + UX_STUDY.md now say BOTH everywhere, including the store interview question — no "OR monthly" remnants. N3: competitor admin comparison recorded in ADMIN_STUDY.md §1. N4: UX_STUDY.md "Admin basics" line replaced with a pointer to ADMIN_STUDY.md.
**Verdict after the fix: the documents now match the prototype and the decisions. The build blocker is gone — what blocks the build now is only the open decisions (payment, card fee, disputes, Morocco pricing).**

## Final verdict
**Ready to show. Ready to test (Round 2). NOT ready to build from as-is — one new drift (N1) plus the open money and dispute decisions.**
Since the first review: R1–R5 fixed and verified; the app is named Wasl with its logo in the prototype; Admin was studied (`ADMIN_STUDY.md`) and built (A1–A8 in the high-fi); revenue is decided (both); the global principle is decided and applied; IA §4 and the sitemap are synced to A1–A8; the backend mind map is made. What is new and broken: **BACKEND.md never caught up with the Admin decisions** — a developer building from it would miss approvals, payment switches and the revenue model entirely.

## What's new since the first review (all 2026-11-06)
- **Wasl name + logo** (`workspace/your_files/wasl-logo/`, SVG + PNG, brand sheet) and Wasl in the prototype — the real logo files copied in, brand card, favicon, market switch now a market selector.
- **Admin study + Admin screens A1–A8** — full web desktop surface in the high-fi (approvals queue, one-tap Approve/Reject, cash/card switches per store, revenue, live map of all deliveries), IA §4 and the sitemap Admin branch synced to match.
- **Revenue decided: BOTH** — a per-delivery fee AND a monthly subscription, set by the admin per store. Amounts still to test.
- **Global principle decided and applied** — Boston + Morocco are the launch markets, not the only markets. Markets, currencies, languages, zones and fees are admin-configurable; nothing assumes only two markets.
- **Backend mind map** — the entire backend as one image (`wasl-backend-mindmap.png`, zoomable HTML alongside): 9 branches from the Firebase centre.
- **Competitor admin comparison** — Metrobi, Onfleet, DoorDash Drive / Uber Direct, Gopuff. Lives only in chat so far (see N3).

## What is solid — keep it
1. **Hybrid fleet.** Own drivers first, marketplace as backup, escalation on decline. In the concept, study, IA, wireframes, high-fi and backend — the one thing no big competitor does for small stores.
2. **Cash rule.** Cash only at the start, driver returns all cash to the store, paid later, keeps the tip. Designed into the high-fi (COD badges, "Cash returned to store", store cash ledger, driver Earnings pay owed vs tips kept) and it works because the driver is the store's own trusted driver.
3. **Two markets, now global by design.** Boston USD/English + Morocco MAD/Arabic/French first, with a market selector that re-prices the prototype and an A8 that adds markets. A real differentiator, not a translation afterthought.
4. **Maps.** Driver navigation (D10, route + next-turn + Google Maps handoff), store live map (S10, all drivers, tap a driver, simulate-move), customer tracking (C1) live trip map, and now the Admin live map of all deliveries (A6) — real interactive maps on verified East Boston addresses, not panels.
5. **Profiles.** S9 store, D9 driver, C3 customer — with the right privacy split: the store sees rating / deliveries / on-time; only the driver sees pay owed, tips kept and cash to return; the customer's phone stays private.
6. **Backend plan.** Firebase, one central backend, one order under one ID, roles enforced by rules, photos in Storage, realtime listeners. The Blaze limit for the escalation timer is stated honestly.
7. **Admin (new).** Approvals queue with one-tap decisions, payment switch per store, revenue control, live map of all deliveries, full control for the platform owner. No competitor sells this as a product surface — at Metrobi and Onfleet the business is its own admin; at DoorDash and Uber the platform admin is internal and invisible.
8. **Brand.** Wasl name and logo, consistent deep teal + amber, in the prototype and on the mind map.

## New findings
### N1 — BACKEND.md is behind on Admin (High — blocks the build)
- BACKEND.md has no `users.verificationStatus` (pending / approved / rejected + reason + submittedByStore), no `stores.paymentMethods` (cash / card), no markets collection or config, no revenue model, and no approval flow.
- `users` / `drivers` mention verification status only in passing. The approval flow — pending blocks orders and jobs, a store submits its own driver, one-tap approve / reject — is nowhere in the backend plan.
- **Fix:** add the ADMIN_STUDY.md §10 backend changes to BACKEND.md (fields, admin-only rules, approval as a server transaction, payment switches, revenue fields, markets config).

### N2 — Revenue wording: "OR" vs decided "BOTH" (Low)
- CONCEPT.md line 60 and UX_STUDY.md §8 (lines 238–239, open decision 3) still frame per-delivery **OR** monthly, and ask whether own-driver trips pay the app at all. The decision (2026-11-06) is **BOTH**.
- **Fix:** change both to BOTH; the remaining question is amounts only.

### N3 — Competitor admin comparison lives only in chat (Low)
- Metrobi (the business is its own admin; preferred + ban drivers), Onfleet (dispatcher Command Center, exceptions surface, analytics), DoorDash / Uber (platform admin exists but is hidden; merchant sees a simple portal), Gopuff (no external admin). None of it is recorded in any doc.
- **Fix:** add a short section to ADMIN_STUDY.md (or the UX_STUDY.md competitive audit).

### N4 — UX_STUDY.md §5 "Admin basics" is superseded (Low)
- One line (stores, drivers, zones) against the full ADMIN_STUDY.md (A1–A8, 6 flows, MoSCoW).
- **Fix:** replace the line with a pointer to ADMIN_STUDY.md.

## Old findings — status
- **R1–R5 FIXED** (verified by grep + builder handoffs; count corrected to 23 numbered phone screens + Admin — the earlier 24 double-counted D2).
- **R6 still open** — store bottom nav: Chat or Profile? Needs Soufiane's call.
- **R7 fixed** — MEMORY.md is current (Wasl, Admin study + screens, revenue both, global principle, mind map).

## Open decisions — updated (nothing here blocks a test; the starred ones block a build)
1. **\* Payment:** cash first with card switchable later (recommended) vs card now vs approval-only? — unanswered since 2026-11-06 14:40.
2. Approval proof: exact documents per role, Boston vs Morocco (rules differ).
3. Approval speed: same-day promise? What does the applicant see while waiting?
4. Rejection: fixed reason list or free text? Can they resubmit, how many times?
5. **\* Card fee:** who pays — store, customer, or Wasl? What payout account is needed before card can be switched on?
6. **\* Disputes:** who pays if late / cold / lost — store, driver, or Wasl?
7. **\* Morocco pricing:** per-delivery fee in MAD + monthly plan price (Boston $4–$7 still to test).
8. Batch pricing: how is $18.50 calculated? Show the breakdown on D6 once decided.
9. 5-stop cap for a run.
10. Auto timeout: 2 minutes, with a visible countdown in the high-fi. Does it feel right? Test it.
11. Morocco pilot stores: none named yet (Boston pilots proposed — Mira's Coffee + Chinese Dragon — not agreed).
12. Driver verification, exact checks (ID / phone / vehicle).
13. Guaranteed driver pool: what happens when no driver accepts?
14. Admin on phone: web-only (IA v0.2) or a phone view for approvals on the go?
15. Bottleneck plan: at what size does one admin stop coping — second admin, or auto-approve trusted stores' drivers?
16. Map tiles: D10, S10 and A6 — the builders verified code and addresses but could not visually confirm the tiles render. Soufiane still needs to open them on his phone and confirm the maps draw.
17. R6: store nav — Chat or Profile?

## Not yet done — the honest list
- **No real interviews.** Personas, pain points and flows are hypotheses from Soufiane's driving experience and the two bots. 5 owners + 3 own drivers + 3 marketplace drivers + 3 customers, still to do.
- **No real usability test.** Round 1 was an expert walkthrough by Raiss only (4 Pass, 2 Partial, 0 Fail). Round 2 on the high-fi, with real people, has not happened. The blank score sheet is in USABILITY_TEST.md. Round 2 should now also cover the 5 Admin tasks (ADMIN_STUDY.md §8: approve a store, reject a driver, approve a store-submitted driver, turn card on, settle a dispute — target: approval under 30 seconds, under 3 taps, still to test).
- **Remaining Round-1 fixes F4–F8 not yet in any prototype:** saved customers on S2, problem path on a single delivery (D4), batch pay breakdown (D6), Auto countdown (already in the high-fi escalation — verify in Round 2).
- **No build started.** No Firebase project, no Flutter app, no APK.
- **Low-fi wireframes (18 screens) are intentionally behind the high-fi** (23 + Admin A1–A8) — by design, not drift. Do not "fix" this by mistake.

## What is ready, in one line each
- Show to a store owner: **yes** — high-fi + Admin + cash + maps + Wasl brand.
- Test with real users (Round 2): **yes** — including the Admin tasks.
- Build the MVP: **not yet** — fix N1, answer decisions 1, 5, 6, 7 (payment, card fee, disputes, Morocco pricing), then build the backend first (Firebase, deliveries end to end).

## Recommended next step (in order)
1. Fix N1–N4 in the documents (BACKEND.md admin fields first — it is the build blocker).
2. Soufiane answers the payment decision (1) + R6 + confirms the maps draw on his phone (16).
3. Round 2 real test on the high-fi — owner + driver + admin tasks.
4. Then build: Firebase backend first, deliveries end to end.

## History — first review (2026-11-06 ~13:31)
Original verdict: ready to show and test, NOT ready to build — the documents had drifted behind the prototypes (18 vs the then-claimed 24 screens, cash vs Stripe in 3 places, Boston-only vs Boston + Morocco, customer no-account vs C3 profile, multi-stop listed as "Later" though built). R1–R5 were fixed the same day at his yes ("Yes, fix the drift now") and verified by grep; the count was corrected to 23 + Admin after the fix. R6 and R7 are carried above.
