# Store delivery app — hi-fi self-test (12 minutes, phone + desktop)

Use this on the Wasl-branded prototype (landed 2026-11-06 ~14:28 ET) with the
Admin screens A1–A8 (built 2026-11-06 ~15:15 ET). It covers what the
old 6-task list does not: the 3 new profile screens, the real maps, the
cash rule, and the new Admin surface. Give yourself the goal, not the steps
— note where you get stuck, in your own words.

## 0. Maps actually draw? (1 min — the open check)
- Open D10 Navigate and S10 Live Map.
- Do the map tiles draw, or is it a blank/grey box? Note phone + connection.
- If a map is blank, tap its written fallback list — is it usable without the map?

## 1. Driver: get to the customer (2 min)
- As a driver, take a job and follow D10 Navigate: pickup route, then
  customer route. Is the next-turn card, distance and ETA clear at a glance?
- Tap "Directions in Google Maps" — does the handoff open with the right place?

## 2. Store: watch your drivers live (2 min)
- Open S10 Live Map. Tap a driver in the list — does his pin light up with
  his order and ETA?
- Tap the simulate button (moves Karim closer) — does the ETA follow?
- Check S5: is the live map there too, or do you have to go to S10?

## 3. Cash end to end (2 min)
- Driver: complete a delivery, mark "Cash returned to store".
- Driver Earnings (D9): pay owed (not yet paid) is separate from tips kept?
- Store ledger (S9): collected / returned / still with drivers / pay owed —
  do the numbers match the delivery you just finished?

## 4. Profiles (2 min)
- S9 Store profile: business details, market, My Drivers summary, cash
  at a glance, trust (favourite / blocked marketplace drivers).
- D9 Driver profile: "Own driver — Mira's Coffee" badge, private phone,
  verification status, stats the store sees vs. the "Only you see this" section.
- C3 Customer profile: saved addresses, order history with cash-at-the-door
  badges. Does it feel optional — i.e. is it clear the tracking link still
  needs no account?
- One design question from the build: the store bottom nav swapped Chat for
  Profile — chat is still reachable from Live status. Is that fine, or do
  you want Chat back in the nav?

## 5. Morocco switch (1 min)
- Flip Boston USD ⇄ Morocco MAD. Do prices, pay (60 MAD) and the run
  (185 MAD) change everywhere, including profiles and the ledger?
- Does the status bar / place names switch to Casablanca sensibly?

## 6. Admin A1–A8 (2 min — desktop, not phone)
- The Admin surface is a web desktop surface, not a phone screen — open it
  on the laptop/desktop.
- A6 Live orders: does the Admin map of *all* deliveries draw? (Same open
  point as D10/S10 — not visually confirmed yet.) Do the pins match the
  order rows, and does Reassign clear an exception?
- A3 Review detail: approve one, reject one with a reason — do the queue
  and the counts update everywhere?
- A4 Store detail: Mira's Coffee and Chinese Dragon show Cash on / Card
  off. Try turning Card on — does it demand the payout account and fee
  agreement first? Can Cash be switched off? (It shouldn't be — a store
  must never be left with no payment method.)
- A7 Revenue: per-delivery fee AND monthly plan, editable per store — do
  the live owed totals make sense?
- A8 Markets: try adding a market — does it join the selector and re-price
  the prototype?

## Score sheet (one line per task)
| Task | Done? | Stuck where? (your words) | Fix |
|---|---|---|---|
| 0 Maps draw | | | |
| 1 Driver navigate | | | |
| 2 Store live map | | | |
| 3 Cash end to end | | | |
| 4 Profiles S9/D9/C3 | | | |
| 5 Morocco switch | | | |
| 6 Admin A1–A8 | | | |

## What this does NOT cover (still open)
- F4 saved customers on the new-delivery form, F5 problem path on a single
  delivery, F6 batch pay breakdown (pricing rule undecided), F8 live
  2-minute Auto countdown — all still to fix, then re-test.
- The real test with 3 owners, 2 own drivers, 2 marketplace drivers
  (30–45 min each) — this self-test is tester 1 only.

Sources: `workspace/store-delivery-app/USABILITY_TEST.md` (6 tasks, blank score
sheet, F4–F8); hi-fi prototype as delivered 2026-11-06 18:13–18:26 UTC
(23 numbered phone screens + Admin — S1–S10, D1–D10, C1–C3 — profiles
S9/D9/C3, maps D10/S10/D2/S5/C1, cash rule: driver returns all cash, paid
later, keeps tip; each store will have his own drivers); Wasl branding
landed 2026-11-06 19:28 UTC; Admin screens A1–A8 built 2026-11-06 20:15 UTC
(approvals queue, one-tap approve/reject, cash/card switches per store with
never-both-off rule, per-delivery fee + monthly plan, live map of all
deliveries on A6 — A6 map tiles not yet visually confirmed). Run this on the
Wasl-branded prototype with Admin included.
