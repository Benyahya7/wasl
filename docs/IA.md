# Store Delivery App — Information Architecture (IA)
Date: 2026-11-06 | Owner: Soufiane Benyahya | Status: Draft v0.2, follows UX Study + 23 numbered phone screens (S1–S10, D1–D10, C1–C3) + Admin A1–A8 in the high-fidelity prototype
Source: `UX_STUDY.md` §5, `USABILITY_TEST.md`, prototype `store-delivery-app-high-fidelity-prototype` (23 numbered phone screens + Admin; low-fi wireframes `store-delivery-app-wireframes` are 18 screens, S1–S8, D1–D8, C1–C2, and do not yet include profiles or maps)

## IA principles
1. **One job per screen.** A store creates a delivery on one screen. A driver accepts or advances a job with one big button. No nested menus on the road.
2. **Three apps, one order.** Store app, driver app and customer tracking all show the same order (#1044 in the prototype) with the same status words: Accepted → Picked up → On the way → Delivered.
3. **Own drivers first, marketplace as backup.** The IA puts "My drivers" next to "Marketplace" everywhere, so the hybrid choice is always visible, never buried in settings.
4. **No dead ends.** Every delivery card links to its live status, its chat, and its history. Every driver job links to navigation, chat and photo proof.
5. **Depth max 2 taps** from a home screen to any core action (create, accept, track, pay).

## 1. Store app — bottom nav, 5 tabs
Home is the Dashboard. Bottom nav (phone): **Home / New delivery / My Drivers / Jobs / More**

### 1.1 Home — Dashboard (S1, tablet dashboard)
- Today's deliveries as cards: status, customer, driver name, ETA, fee
- Counts: active now, delivered today, unassigned / waiting for a driver
- Batched runs surfaced: Run R-7, "Stop 2 of 3"
- Big "+ New delivery" button (always visible)
- Tap a card → Live status (S5)

### 1.2 New delivery (S2)
- One screen, top to bottom — no second screen:
  - Customer (name, phone) — saved customers / recent addresses [F4 fix, to add]
  - Address (with notes: gate code, floor, fragile)
  - Items / order #
  - Pickup time
  - Delivery fee (suggested by distance, editable — $4–$7 to test)
  - Notes
  - Driver mode — 3 big choices: My driver / Marketplace / Auto
- Confirm → live tracking card appears on Home

### 1.3 Who delivers (S3)
- Pick a driver: My driver list (on/off now) / Marketplace / Auto
- Auto rule: own driver first, marketplace after timeout (2 min — to test, with visible countdown)
- If own driver declines: banner shows the exact reason, escalation auto-runs to marketplace (Sara in the prototype)
- No re-creating the order — escalation is the same order

### 1.4 My Drivers (S4)
- Roster: each own driver with on/off now, today's jobs, rating
- Tap a driver → assign, see their jobs, weekly pay
- Add driver / invite, shifts (on/off, not full block scheduling in v1)

### 1.5 Live status (S5)
- One order: timeline Accepted → Picked up → On the way → Delivered
- Driver name, live map position, ETA, fee
- Pickup code shown on the order (store side only — the store puts it on the label and can read it out if the label is unreadable; it never appears on the driver's screens before pickup)
- Buttons: Chat (S8), Call (masked, later), Problem / support
- Delivered state: photo + time

### 1.6 History & pay (S6) — cash ledger at launch
- Past deliveries: date, customer, driver, fee, status, photo, **cash badge: Cash on delivery / Paid in cash**
- Weekly cash summary: cash collected, cash returned to the store, cash owed, what is settled — with a "Mark as paid in cash" action. No card / in-app payment in the MVP (decided 2026-11-06). Cash-flow rule: driver returns all cash to the store, gets paid later, keeps any tip — driver earnings show pay owed + tips kept.
- Currency follows the store's market: USD in Boston, MAD in Morocco. Language: English / Arabic / French from the start, because the app launches in Morocco as well as Boston. Markets are admin-configurable — add a market with its own currency and language — because Wasl is designed global; Boston + Morocco are the first two markets only.
- Filter by driver, by day, by status

### 1.7 Build a Run — multi-stop (S7)
- Group 3 ready orders into one run (5-stop cap — open question)
- "Optimise route" re-sequences stops (5.9 mi → 4.6 mi in the prototype), manual override
- One batch total ($18.50 in the prototype — pricing rule open)
- Send via My driver / Marketplace / Auto, like any delivery

### 1.8 Chat — per order (S8, new in F3 fix)
- Same thread as the driver's D8, mirrored
- Pinned order context at the top: order #, customer, address
- Quick replies + Send box, no phone numbers shared
- Thread closes after delivery

### 1.9 More / Settings
- Store profile (S9): business name, type, logo, address, phone, hours, market, zone — East Boston first in Boston, Morocco zone to decide
- Fees & cash: per-delivery fee, monthly plan (to test); no payout account in the MVP — cash ledger only, Stripe deferred
- Favourite / blocked marketplace drivers
- Notifications, language (English / Arabic / French — to test)

### 1.10 Live map (S10, new in high-fi)
- All the store's drivers on one real interactive map, with status and order per driver
- Tap a driver in the list → his pin lights up, with live badge, order and ETA
- Location is trip-only: a driver is shared only while on an active job
- Live map is also embedded in Live status (S5); dashboard has a Live Map button

## 2. Driver app — bottom nav, 4 tabs
Bottom nav (phone): **Jobs / Map / Earnings / Profile**
One app for both driver types. Assigned jobs are pinned at the top; open offers are below. A driver is never in two modes at once on the same screen.

### 2.1 Jobs — Job board (D1 list, D2 map)
- Toggle: List / Map — D2 is a real interactive map in the high-fi, with job pins (own store's job first, backup offers as pins)
- Filter chips (F1 fix): $6+, ≤3 mi, Clear — plus sort: Pay / Distance / Soonest pickup, with live result count and an empty state
- Each card: pay (big), distance, store, drop-off area, pickup time
- Batched runs shown as one card: total pay, miles, time, number of stops
- Assigned jobs pinned at top, open offers below
- Tap a card → offer detail → Accept / Decline

### 2.2 Incoming assignment (D3)
- Assigned job card: address, pay, pickup time, notes (gate code, fragile)
- Accept / Decline — decline asks for a reason (Busy on another job / Off / Too far)
- Declining with a reason drives the store-side escalation (F2 fix) — it is the same event, not a separate demo
- Buttons: Chat (D8), Navigate

### 2.3 Active job (D4) — single delivery
- Big status button, one thumb: Picked up → On the way → Delivered
- **Pickup needs the 4-character pickup code from the order label (decided 2026-11-06):** the driver types the code to confirm pickup — no code, no pickup. The code is NEVER shown on the driver's screens before he has the bag; he can only get it from the physical label at the store. Wrong code → pickup rejected, stays Accepted.
- Navigate, Chat (D8), customer notes
- Delivered step: photo proof (+ retake), then next job / earnings update
- Problem path: customer not answering / wrong address / order not ready [F5 fix, to add — mirror D7]

### 2.4 Batched offer (D6) and Active multi-stop run (D7)
- D6: total pay, miles, time, all sequenced stops before accepting. Whole-batch-only rule stated clearly.
- D7: big button advances stop by stop, photo at each stop, problem-at-stop path, batch progress ("Stop 2 of 3") — pickup code per stop, one code per order, entered at each pickup

### 2.5 Earnings (D5)
- Per-trip pay, today's total, weekly total
- Payout status, history per trip

### 2.6 Chat — per order (D8, new in F3 fix)
- Mirror of S8: same thread, pinned order context, quick replies, Send box, no phone numbers

### 2.7 Profile (D9, new in high-fi) & verification
- Type badge front and centre: Own driver vs Marketplace driver — the badge is what makes the cash rule work
- Name, photo, private phone (stores never see the number), vehicle, zone, languages
- Verification status: ID / phone / vehicle (exact checks to confirm with local rules)
- Store-visible stats: rating, deliveries done, on-time rate
- Driver-only section ("Only you see this"): pay owed not yet paid, tips kept, cash still to return, weekly earnings
- Ratings from stores, favourite stores, settings, shift on/off

### 2.8 Navigate (D10, new in high-fi)
- Real interactive map: driver position, route to the store for pickup, then route to the customer
- Next-turn card, route steps, live ETA and distance, one-tap "Directions in Google Maps" handoff
- Same pattern on each stop of a run (D7) and on the active job (D4) and assignment preview (D3)

## 3. Customer — tracking link needs no account; a profile is optional
### 3.1 Tracking (C1)
- Text link → live map, driver first name, ETA, order status
- No install, no login
### 3.2 Delivered (C2)
- "Delivered ✓" + photo + time
- Rate / tip — v2, not MVP
### 3.3 Profile (C3, new in high-fi) — optional, for repeat customers only
- Saved Home / Work addresses, order history with cash-at-the-door badges and ratings, favourite store, cash payment preference, language, tracking-link notifications, private phone note
- Tracking (C1) still works with no account and no profile — the profile only adds saved addresses and history for customers who want them

## 4. Admin — web only, not in the phone apps (A1–A8, built in the high-fi prototype; see ADMIN_STUDY.md)
- A1 Dashboard: approvals waiting, live orders, exceptions, Wasl fees today (per market, local currency), quick links
- A2 Approvals queue: stores + drivers in one filterable list (All / Stores / Drivers, pending-only), type badges, submitted-by-store tags, wait times
- A3 Review detail: all proof on one screen + Approve / Reject with reason; decisions update the queue and counts everywhere
- A4 Store detail: business, market/zone, drivers, orders, ratings, Payment (Cash on / Card off by default — card needs payout account + fee agreement; never both off), Block
- A5 Driver detail: verification status, vehicle, rating, deliveries, on-time, cash still to return, pay owed, Block
- A6 Live orders: all orders, live status, exceptions highlighted, reassign — plus a live map of all deliveries and drivers
- A7 Payouts & disputes: cash per store, per-delivery fee + monthly plan per store (both, decided 2026-11-06), payout status, dispute list + decision record (who pays if late / cold / lost — rule to decide before launch)
- A8 Markets, zones & fees: markets the admin adds (Boston + Morocco first), zones within each market, per-delivery fee and monthly plan per market in local currency — global by design, nothing assumes only two markets
- Flows: store approval, driver approval, store submits its own driver, payment control per store, exception + dispute, block (ADMIN_STUDY.md §5)

## Sitemap (text tree)
```
Store app
├── Home / Dashboard (S1)
│   └── Live status (S5) → Chat (S8)
├── New delivery (S2) → Who delivers (S3)
│   ├── My driver → My Drivers (S4)
│   ├── Marketplace → Job board (driver side)
│   └── Auto → escalation
├── Build a Run (S7)
├── My Drivers (S4)
├── History & pay (S6)
├── Chat (S8)
├── Live map (S10) — all drivers on one real map, tap a driver for his order and ETA
├── Profile (S9) — business details, market, cash ledger, trust, settings
└── Settings
Driver app
├── Jobs / Board list (D1) ↔ Map (D2, real map with job pins)
│   ├── Offer detail → Accept
│   └── Batched offer (D6)
├── Incoming assignment (D3) → Active job (D4) / Active run (D7)
├── Navigate (D10) — real map, route, next-turn card, ETA, Google Maps handoff
├── Earnings (D5)
├── Chat (D8)
└── Profile (D9) — type badge (Own / Marketplace), verification, store-visible stats, driver-only pay/tips/cash
Customer (tracking link needs no account; profile optional)
├── Tracking (C1, live trip map)
├── Delivered + photo (C2)
└── Profile (C3, optional) — saved addresses, order history, favourite store
Admin (web)
├── Dashboard (A1)
├── Approvals queue (A2) → Review detail (A3)
├── Store detail (A4) — payment switches, Block
├── Driver detail (A5) — verification, cash to return, Block
├── Live orders (A6) — live map of all deliveries
├── Payouts & disputes (A7) — revenue, who pays
└── Markets, zones & fees (A8) — add a market, fees per market
```

## Labelling — why these words
- "My Drivers" not "Fleet" — owners say "my driver", not "my fleet".
- "Build a Run" not "Batch" — a run is what a driver does; batch is backend language.
- "Who delivers" not "Dispatch" — dispatch is the store's job in plain words.
- Status words are the same everywhere: Accepted, Picked up, On the way, Delivered. No synonyms.
- Pay is always shown before accept, never after. That was Sara's core need in the study.

## What is NOT in the IA (deliberately)
- Rides for people — parcels / food / groceries only. The paused consumer marketplace covered rides.
- Customer ordering / menus — **not in v1; decided 2026-11-06 as v2, after the delivery system is built and tested.** v2 adds: (a) intake from the store's own apps (Mira's Coffee, Chinese Dragon) — their orders flow into Wasl as deliveries; (b) one Wasl customer app with multiple stores, like Uber Eats — customer picks a store, browses its products, orders (new customer screens, C4+). Not one app per store. The backend split (orders vs deliveries) is designed now in BACKEND.md so v2 plugs in without rebuilding the delivery core.
- Auto-dispatch by algorithm (best driver by distance + rating) — "Could, later". Auto today means own driver first, then broadcast.
- Alcohol / tobacco delivery, insurance claims in-app.

## Open IA questions (to decide / test)
1. Does the store need a separate "Marketplace" tab, or is Who delivers (S3) enough?
2. Saved customers on S2 — recent list, favourites, or both?
3. 2-minute Auto timeout — show a countdown, test if it feels right.
4. Batch pricing rule — how is $18.50 calculated? Show the breakdown on D6 once decided.
5. Chat: store ↔ driver only in v1, or also customer ↔ store in the same thread? (Gopuff work, 2026-11-04, had all three in one thread — test whether stores want that.)
6. Store bottom nav: Profile or Chat? The high-fi swapped the Chat tab for Profile to fit Profile in; chat is still reachable from Live status and the screen index. Decide before the build — do not guess.
