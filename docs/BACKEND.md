# Store Delivery App — Backend System
Date: 2026-11-06 | Owner: Soufiane Benyahya | Status: Plan, not built yet
Companion files: `UX_STUDY.md`, `IA.md`, `USABILITY_TEST.md`, wireframes `store-delivery-app-wireframes`

## Short answer
**Firebase — the same backend pattern as Hanimo, Mira's Coffee and Chinese Dragon.**
No server for you to run. It is mostly config: collections, sign-in, storage and rules — the same pattern as the other apps, not a big server to code. Start on the free Spark plan; billing (Blaze) is only needed later, for Cloud Functions and at real launch scale.

## The idea in one picture
**One backend, four windows into it.** The store app, driver app, customer tracking link and admin dashboard do NOT talk to each other directly. They all read and write the same order in the same backend, in real time. One order — #1044 in the prototype — flows:

Create delivery (store) → Assign / Broadcast / Auto (dispatch) → Accept (driver) → Picked up → On the way → Delivered + photo → Paid

That is why the store, the driver and the customer all see the same status words at the same moment, and why the store never has to phone the driver to ask where an order is.

## What lives in the backend

### Firestore collections
| Collection | What it holds | Who can read / write (rules) |
|---|---|---|
| `users` | Every account: role (store / own-driver / marketplace-driver / admin), name, phone, photo, language, `verificationStatus` (pending / approved / rejected + `verificationReason` + `submittedByStore` when a store submits its own driver) | Own profile only; admin reads all; pending accounts cannot post orders or see jobs |
| `stores` | Business name, address, contact, `market`, zone, `paymentMethods` (cash on by default, card off by default — card needs a payout account + fee agreement; never both off), fee settings (per-delivery fee + monthly plan, both set by the admin), favourite / blocked drivers, payout account | That store only; drivers read name + address of stores they serve; payment switches are admin-only writes |
| `drivers` | Vehicle, ID verification status, rating, on/off now, home zone, payout account | That driver only; stores read rating + distance of drivers on their orders |
| `deliveries` | **The core of v1.** Customer name/phone/address, items/order #, pickup time, fee, notes, driver mode (my-driver / marketplace / auto), status, driver, timestamps, photo proof. In v1 the store creates it directly; in v2 it is created from an `orders` doc (see "Orders vs deliveries" below) | Store that created it + assigned driver + admin. Customer reads only their own order via the tracking link (token, no login) |
| `orders` | **v2 — the order, separate from the delivery.** What the customer bought: items + options, order total, customer, source (manual store entry / store app / Wasl storefront), status (received → confirmed → preparing → ready → out for delivery), linked `deliveryId` once a delivery is created | Store that owns it + admin. The store app that sent it can read its own orders. A delivery is created from an order, never the other way round |
| `menus` | **v2 — per-store menu for the Wasl storefront.** Items (name, price, options, sold-out flag) owned by a store | That store writes; public read of a store's own menu; admin reads all |
| `runs` | Batched runs: list of delivery IDs, sequenced stops, total pay, miles, status, driver | Same as deliveries — store + assigned driver + admin |
| `chats` / `deliveries/{id}/messages` | One thread per order: store ↔ driver, text + quick replies + photo in-thread | Only the store and driver on that order. Thread closes after delivery. No phone numbers stored or shown |
| `ratings` | Store → driver and driver → store, per delivery | Both sides read their own; admin reads all |
| `payouts` | Per-trip pay, weekly totals, payout status, for stores and drivers; Wasl revenue per store (per-delivery fees + monthly plan owed, in local currency) | Own payouts only; admin reads all |
| `zones` | Boundaries and fees, inside a market (East Boston first in Boston, then Greater Boston; Morocco zones to decide) | Public read; admin write |
| `markets` | One doc per market (currency, language, zones, per-delivery fee, monthly plan). Boston + Morocco are the first two; the admin adds more — Wasl is global by design, nothing assumes only two markets | Public read; admin write |

### Firebase Auth
- Sign-in: Google + phone (same as Hanimo / Mira's / Dragon).
- Roles live in `users.role` and are enforced by Firestore rules on the server, not just in the app — a driver cannot read another store's orders even if they try, and a store cannot read another store's drivers.
- Customer tracking needs **no account**: a link with a per-order token opens that one order only. A customer profile (C3) is optional, for repeat customers only — saved addresses, order history, favourite store — and is a separate account from the tracking link.

### Firebase Storage
- Delivery photos (one per stop, linked to the delivery ID), driver/store profile photos.
- Photos are proof: photo + time on every delivery, shown to the store and to the customer on Delivered.

### Realtime
- Firestore listeners: live status, driver location (trip-only — location is shared only while a driver is on an active job, never all day), chat messages, job board.
- When Karim accepts, the store's dashboard updates without refresh. When he marks Delivered + photo, the customer link updates at the same moment.

### Cloud Functions — the honest limit
These jobs need a small server function, not just the app:
1. **Auto-escalation timer:** own driver has not accepted in 2 minutes → broadcast to marketplace automatically.
2. **Notifications:** push to driver on assignment, push to store on decline / delivered, text/email to customer with the tracking link.
3. **Payout math:** batch total, per-trip pay, weekly totals — calculated on the server so nobody can edit their own pay in the app.

**Limit:** Cloud Functions need the Blaze (pay-as-you-go) plan — Spark free has no scheduled / background functions, same as Hanimo's auto-push function which was written but not deployed. For the MVP you can start on Spark with the timer + notifications done in the app as a workaround, but it is not reliable (it stops when the phone sleeps). The real version needs Blaze. Do not pretend otherwise.

### Shared services (outside Firebase)
| Service | For | When |
|---|---|---|
| Google Maps (Directions, Distance, geocoding) | Route optimisation on Build a Run, ETA, driver navigation, distance-based fee | Real launch — needs an API key + billing |
| Stripe (DEFERRED — cash only at the start, decided 2026-11-06) | In-app payment / payouts, later only | Not in MVP. The backend records cash instead: `payouts` holds cash collected, cash returned to the store, cash owed, and "paid in cash" marks — no money moves through the app at launch. Cash-flow rule (decided 2026-11-06): driver returns ALL cash to the store, gets paid later, keeps any tip. |
| FCM push notifications | Assignment, decline, delivered | With Cloud Functions (Blaze) |
| Resend (already set up) | Order / delivery emails | Anytime — email only, not SMS |
| SMS provider (to decide — Twilio or similar) | Tracking link by text to the customer | Real launch — Resend does not do SMS |

### Admin — approvals, payments, revenue (added 2026-11-06, from ADMIN_STUDY.md)
- **Approvals:** every store and driver signs up as `verificationStatus: pending` (with `verificationReason` on rejection and `submittedByStore` when a store submits its own driver). Pending accounts cannot post orders or see jobs. The admin approves or rejects with one tap (A3); the decision is a server transaction — no self-approval — and the applicant sees the reason.
- **Payments per store:** `stores.paymentMethods` — cash on by default, card off by default. Card can only be switched on when a payout account + fee agreement are recorded. Never both off. The cash ledger keeps working the same way; card orders are recorded separately.
- **Revenue (decided 2026-11-06):** stores pay BOTH a per-delivery fee AND a monthly plan, both set by the admin per store. `payouts` records Wasl fees owed per store alongside driver pay and cash. Amounts still to test (Boston $4–$7 per delivery, Morocco MAD fee, monthly plan price).
- **Markets (global by design):** `markets` — one doc per market (currency, language, zones, per-delivery fee, monthly plan). Boston + Morocco are the first two; the admin adds more. `zones` belong to a market; `stores.market` points at their market.
- **Rules:** admin-only writes on approvals, payment switches, fees and markets. Admin reads all; a store reads only its own payment and revenue records; a driver reads only their own.

### Orders vs deliveries — the split (decided 2026-11-06: v2, after the delivery system is built and tested)
An **order** is what the customer buys; a **delivery** is the trip that carries it. They are two different docs, on purpose — so ordering can be added later without rebuilding the delivery core.
- **v1 (now):** the store creates a `deliveries` doc directly (typed in by hand, e.g. a phone order). There is no `orders` doc yet. This stays as the manual fallback even in v2.
- **v2, part A — intake from the store's own apps:** orders placed in Mira's Coffee / Chinese Dragon apps (Mini App or bot) flow into Wasl instead of being re-typed. Each store app sends its order to one intake endpoint (a Cloud Function, Blaze) in one agreed format, with a per-store secret: store, items + options, order total, customer name/phone/address, pickup/delivery, time. Wasl validates it, writes `orders/{id}`, the store confirms it, and a `deliveries` doc is created from it. The store's apps need a small change to also send the order to Wasl — today they send orders to Telegram only.
- **v2, part B — one Wasl customer app, multiple stores (Uber Eats style):** the customer picks a store, browses its `menus`, picks items, orders. Not one app per store. The order lands as an `orders` doc and follows the same path: store confirms → delivery created. New customer screens (C4+) in the IA.
- **Cash with orders:** the driver collects the **order total** at the door (cash on delivery), not just a delivery fee. The ledger in `payouts` splits it: order total to the store, delivery fee / driver pay, tip kept by the driver. The v1 cash rule still holds — driver returns ALL cash to the store, gets paid later, keeps any tip.
- **Order states:** received → confirmed (store) → preparing → ready → out for delivery (delivery created) → delivered + photo. The customer tracking link follows the delivery; the order status is shown on the same page.

## How the key flows run on this backend
- **Assign to my driver:** store writes `deliveries/{id}` with `driverMode: my-driver, driverId: karim, status: offered`. Karim's app gets a push + sees it on D3. Accept → `status: accepted`. Decline + reason → function (or app, on Spark) writes `status: escalated` and broadcasts to marketplace.
- **Order → delivery (v2):** an `orders` doc arrives (intake from a store app, or the Wasl storefront). Store confirms it on S1 → a `deliveries` doc is created from the order (customer, address, items/order #, order total), linked by `deliveryId` on the order. From there the flow above runs unchanged — assign / broadcast / accept / pickup / delivered + photo. A manual store-created delivery skips the order step entirely.
- **Broadcast / Auto:** store writes `driverMode: marketplace` (or Auto with a deadline). The delivery appears on the open board (D1/D2) for nearby drivers. First accept wins — the accept is a server transaction, so two drivers cannot take the same order.
- **Multi-stop run:** store writes a `runs` doc with 3 delivery IDs in optimised order. Driver accepts the run (whole batch only), D7 advances stop by stop, each stop writes its delivery's status + photo.
- **Chat:** messages go to `deliveries/{id}/messages`. Both phones listen to the same collection, so S8 and D8 are the same thread mirrored.
- **Pay (cash only at launch):** the driver returns all cash to the store, gets paid later, keeps any tip. The app records it in `payouts` — cash collected / returned / owed, and "Mark as paid in cash". Driver sees pay owed + tips kept on D5; store sees the cash ledger on S6. No money moves through the app at launch; Stripe is deferred.

## What the backend does NOT do
- No ordering in v1 — that lives in the Mira's / Chinese Dragon bots for now. Customer ordering is **v2, decided 2026-11-06**: after the delivery system is built and tested. The `orders` / `menus` collections and the intake above are designed now so v2 plugs in without rebuilding the delivery core.
- No rides for people — parcels / food / groceries only.
- No driver background checks or insurance by itself — verification status is stored here, the check itself is an outside process.
- No SMS by itself — needs an SMS provider (see above).

## Alternative (noted, not recommended)
Supabase (Postgres, open source) or a Node.js + PostgreSQL + S3 backend would also work. The reason to stay with Firebase here: it is the same pattern as Hanimo, Mira's and Chinese Dragon, the Flutter SDK is already proven on this VM, offline cache works for drivers on the road, and there is no server to keep running. Switching would be a new stack for no gain at MVP size.

## Build order (when he says build)
1. Firebase project (new project, Spark, Google + phone sign-in, Firestore in production mode)
2. Collections + rules (deliveries first, then users/stores/drivers, then chats/ratings/payouts)
3. Storage (photos) + Auth roles
4. App reads/writes deliveries end to end (create → accept → delivered + photo)
5. Then: escalation function, notifications, Maps — Blaze when the timer has to be reliable. Stripe test mode is deferred with in-app payment, not in the MVP.
6. v2, only after the delivery system is built and tested: `orders` + `menus` collections, the order-intake function for store apps (Mira's / Dragon), and the Wasl storefront. No rebuild of the delivery core — an order just becomes a delivery.
