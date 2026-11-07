# Store Delivery App — Concept (v0.1)
Date: 2026-11-06 | Owner: Soufiane Benyahya | Status: Idea, study before build
Previous idea (consumer driver marketplace) PAUSED 2026-11-06 — not deleted.

## One sentence
An app for small stores to get their orders delivered: the store creates a delivery, then either lets any nearby driver accept it OR assigns it to a specific driver they trust. The driver picks it up, delivers to the address, and proves it with a photo.

Scope decided 2026-11-06: restaurants, coffee shops and grocery stores — any owner of those businesses can use it.
**Hybrid fleet (clarified 2026-11-06, three times): the store owner can use the app and each store WILL have his own drivers in it.** The order still goes to the customer. So the driver side has two kinds of driver in one app: the store's own drivers (assigned directly, the default) and marketplace drivers (open offers, used as backup/overflow only when the own driver is busy, off or declines). This is also why the cash rule works: the driver is the store's own trusted driver, so he returns all the cash to the store, gets paid later, and keeps the tip.

Two apps in one system:
1. **Store app / dashboard** — for the shop
2. **Driver app** — for the driver (own drivers + marketplace drivers)
Plus a tracking link for the end customer (no app needed).

## Why this one is stronger than the consumer marketplace
- **Stores = repeat volume.** One restaurant can post 10-20 deliveries a day. One random person posts once a month. That solves the chicken-and-egg problem.
- **Stores pay.** A store will pay a monthly fee + per delivery to stop losing orders. A random person will haggle over $3.
- **You already have the first customers in mind:** Mira's Coffee and Chinese Dragon Boston already take orders through bots you built — but they have no driver system. They are the perfect pilot stores.
- **Drivers get steady work.** Not waiting for a random offer — they can work for 2-3 regular stores in their area.

Competitors to learn from: Metrobi, DoorDash Drive / Uber Direct, Circuit, GoShare. They are built for big chains. The gap is small independent stores in Boston and Morocco — Moroccan / Arab / Asian restaurants, coffee shops, small groceries — who can't afford DoorDash's commission. Pharmacies, bakeries and retail are not v1.

**Design principle (decided 2026-11-06): Wasl is global — the app can be used around the world, so keep options open.** Boston + Morocco are the launch markets, not the only markets. Markets, currencies, languages, zones and fees are admin-configurable; nothing in the app assumes only two markets exist.

## How it works — the flow

**Store side:**
1. Store creates a delivery: customer name, phone, address, items / order #, pickup time, delivery fee, notes (gate code, fragile, etc.)
2. Store chooses a mode:
   - **Open offer:** broadcast to all nearby drivers, first to accept gets it
   - **Assign:** send it directly to one favourite driver
3. Store watches live: Accepted → Picked up → On the way → Delivered
4. Store sees proof: delivery photo + signature / time, and can chat with driver

**Driver side:**
1. Driver sees open offers on list + map: distance, pay, pickup store, drop-off area
2. Accepts an offer, or gets a direct assignment (can accept / decline)
3. Navigates to store → confirms pickup → navigates to customer → confirms delivery + photo
4. Earnings, history, ratings build up. Stores can favourite reliable drivers.

**Customer side:**
- Gets a text link: live map, driver name, ETA. No app to install.

## Must-have for MVP
- Store: create delivery in <1 min, assign or broadcast, live tracking, chat with driver, delivery history, cash ledger (cash collected / returned / owed, "Mark as paid in cash")
- Driver: job list + map, accept / decline, navigation, pickup / delivered buttons, photo proof, earnings
- Both: profiles + verification, ratings both ways, notifications, cash recording (no in-app payment in the MVP — decided 2026-11-06, Stripe deferred)
- Admin basics: stores, drivers, zones (start: East Boston in Boston + a Morocco zone to decide)

## Later (not MVP)
- Scheduled / recurring deliveries, large / catering orders
- (Multi-stop routes and batched jobs are already in the wireframes and high-fi — S7/D6/D7 — not "Later".)
- Customer ordering — **decided 2026-11-06: v2, after the delivery system is built and tested.** Two parts: (a) intake — orders placed in the store's own apps (Mira's Coffee, Chinese Dragon) flow into Wasl as deliveries, no re-typing; (b) storefront inside Wasl — the customer browses the store's products, picks items, orders. Delivery core first; the backend is designed now with orders and deliveries as separate things so v2 plugs in without a rebuild.
- Auto-dispatch: app suggests the best driver by distance + rating
- Insurance / damaged-package handling, promo / subscription plans for stores

## Business model — to test in the study
**Decided 2026-11-06: cash only at the start. No in-app payment in the MVP — most small stores pay their drivers cash, and the app will be used in Morocco as well as in Boston, so cash is fine.** The app records cash instead of moving it: who collected what, who is owed what. Cash-flow rule (decided 2026-11-06): the driver returns all the cash to the store, gets paid later, and keeps any tip. Stripe / in-app payment is deferred to later.
- Store pays BOTH: a per-delivery fee AND a monthly plan (decided 2026-11-06), both set by the admin per store. Amounts still to test (Boston $4–$7 per delivery, Morocco MAD fee, monthly plan price).
- Driver keeps most of the fee, app keeps a small cut
- Question for stores: what per-delivery fee and monthly price would you pay to never lose a delivery? (The model is decided — BOTH — only the amounts are still to test.)

## Biggest risks to check in the study
1. Will a store trust outside drivers with their food / reputation?
2. What happens when no driver accepts? Need a backup / guaranteed driver pool.
3. Who pays if food is late / cold / lost? Store, driver, or app?
4. Can we get 3-5 stores + 10 drivers in one small area to start? Without density it fails.
5. How is this cheaper / better for a store than DoorDash Drive?

## UX Study to do first (same method as before)
- Interview 3-5 store owners/managers: how do they deliver now? What do they pay? What frustrates them?
- Interview 5 drivers: would they take store jobs? What pay per trip is worth it? Open board or assigned?
- Map the journey: Order ready → Create delivery → Driver accepts → Pickup → Deliver → Paid
- Personas: Store Owner, Dispatcher / Staff, Driver, End Customer

## Open decisions
1. First stores: decided — restaurants, coffee shops, grocery stores. Pharmacies / retail are not v1.
2. Launch area: East Boston first in Boston, then Greater Boston; plus a Morocco launch area to decide (no Moroccan pilot stores named yet).
3. Start with your existing stores (Mira's / Chinese Dragon) as pilot, or find new stores?
