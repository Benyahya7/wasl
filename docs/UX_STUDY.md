# Store Delivery App — UX Study (Draft v0.1)
Date: 2026-11-06 | Owner: Soufiane Benyahya | Status: Study first, no build yet
Method: Google UX Design Certificate process — Empathize, Define, Ideate, Prototype, Test (same method as the Parent Clothing Resale App case study, 2026-11-04)
Previous idea (consumer driver marketplace) PAUSED 2026-11-06 — not deleted.

## How to read this study — please don't skip
- **This is a draft study, not finished research.** The personas, pain points and flows below are hypotheses built from (a) Soufiane's own experience as a delivery driver in Boston, (b) the Mira's Coffee and Chinese Dragon Boston order bots he already built, and (c) the Gopuff work-system research from 2026-11-04.
- **No real interviews have been done yet.** No interview quotes, counts or usability scores in this file are real. Anything marked **TO TEST** must be checked with real store owners and drivers before it is treated as fact — the same rule as the Parent Clothing case study, where findings were drafted from themes, not claimed study counts.
- **Scope decided by Soufiane on 2026-11-06:** restaurants, coffee shops and grocery stores. Any owner of those businesses can use it.
- **The key idea he clarified three times on 2026-11-06:** the store owner can use the app **and each store WILL have his own drivers in it**. The order still goes to the customer. So this is not a marketplace-only app and not a private-fleet-only app — it is a **hybrid fleet** app, own drivers first by default, marketplace only as backup. That is also why the cash rule works: the driver is the store's own trusted driver, so he returns all the cash to the store, gets paid later, and keeps the tip.

## 1. Overview

### One sentence
An app for restaurants, coffee shops and grocery stores in Boston and Morocco to get orders delivered to customers — using their own drivers first when they have them, and on-demand marketplace drivers when they don't.

### The system — three sides, one delivery
1. **Store app / dashboard** — for the owner and their staff. Create deliveries, manage their own drivers, call in marketplace drivers when needed, watch every order live.
2. **Driver app** — for two kinds of driver in the same app:
   - **Own driver:** works for one store (or a few regular stores), gets assigned jobs directly, has a shift/schedule.
   - **Marketplace driver:** independent, sees open offers from many stores on a list + map, accepts the ones they want.
3. **Customer tracking link** — no app to install. Text link: live map, driver name, ETA, delivered photo.

### Why this idea is stronger than the consumer marketplace
- **Stores = repeat volume.** One restaurant posts 10–20 deliveries a day. One random person posts once a month. That solves the chicken-and-egg problem.
- **Stores pay.** A store will pay per delivery or a monthly fee to stop losing orders. A random person will haggle over $3.
- **The hybrid fleet is the differentiator.** DoorDash Drive and Uber Direct only give a store strangers. Metrobi only gives a store strangers. No big competitor lets a small store run **its own trusted drivers in the same system as backup marketplace drivers** — own driver first, marketplace as overflow. That is what a small owner actually wants: keep control, never miss an order.
- **You already have pilot stores in mind:** Mira's Coffee and Chinese Dragon Boston already take orders through bots Soufiane built — but they have no driver system. They are the natural first pilots.
- **Drivers get steady work.** An own driver gets regular shifts. A marketplace driver can work for 2–3 regular stores in their area instead of waiting for a random offer.

### Launch scope — decided
- **Store types:** restaurants, coffee shops, grocery stores. Not pharmacies, retail or catering in v1.
- **Launch area:** East Boston first in Boston, then Greater Boston — and Morocco as well as Boston (Morocco launch area and pilot stores to decide, none named yet). Boston: USD, English. Morocco: MAD, Arabic/French. Density matters: the study target is 3–5 stores + 10 drivers in one small area to start (Boston target; Morocco target not set yet).
- **Pilot stores (proposed, not agreed):** Mira's Coffee, Chinese Dragon Boston.

## 2. Empathize — research plan

### Research questions (what we must learn before building)
**Store owners**
1. How do you deliver now — own driver, yourself, DoorDash, no delivery?
2. How many deliveries a day, at what times, how far?
3. What do you pay now per delivery / per hour, and what would you pay to never miss one?
4. Would you trust an outside driver with your food and your name? What would make you trust them?
5. If you have your own driver, what frustrates you about managing them — scheduling, no-shows, tracking, pay?
6. When your own driver is off / busy / sick, what happens to those orders today?

**Own drivers**
1. How do you get jobs today — phone call, text, paper list, app?
2. What do you need to see before you accept a job — address, pay, distance, items?
3. What goes wrong most often — wrong address, customer not answering, store not ready?
4. How do you want to be paid — per delivery, per hour, weekly?

**Marketplace drivers**
1. Would you take store jobs, or only rides / food apps? What pay per trip is worth it?
2. Open board or assigned jobs — which do you prefer, and why?
3. What makes you skip an offer — distance, pay, area, store reputation?

**End customers**
1. What matters most — speed, live tracking, knowing the driver, contactless, proof photo?
2. Would you open a tracking link, or do you just want a text when it arrives?

### Interview plan — TO DO, not done
- 5 store owners: 2 restaurants, 1 coffee shop, 2 grocery stores (East Boston / Boston)
- 3 own drivers (drivers who already work for one store)
- 3 marketplace drivers (independent, incl. delivery-app drivers)
- 3 end customers who order delivery weekly
- 30 minutes each, in person at the store where possible. Record what they say in their words. Do not lead them to the app — ask about today first, the app second.

### Competitive audit
| Competitor | What it does well | What it misses for a small Boston store |
|---|---|---|
| **Metrobi** | Built for local delivery, driver fleet on demand | Marketplace-only strangers; no own-driver management; store has no control over who delivers |
| **DoorDash Drive / Uber Direct** | Big driver pool, fast, known brand | High commission / per-delivery cost; strangers only; no own-driver mode; built for chains |
| **Circuit** | Multi-stop route optimisation | Route tool, not a store + driver marketplace; no customer tracking link for a small shop |
| **GoShare** | On-demand drivers for larger / same-day jobs | Geared to big / bulky jobs, not daily food + grocery runs |
| **Gopuff** | Vertically integrated: own stock, own drivers, fast | It *is* the store — a small independent store cannot use it. Proves the model, doesn't serve it |
| **Facebook Marketplace / Craigslist** | Free, local | No tracking, no payment, no proof, no trust — not a delivery system |

**Gap:** nobody gives a small independent restaurant, coffee shop or grocery store one place to run *their own drivers* and *borrow marketplace drivers* when they are short — with live tracking and photo proof for the customer.

### What we already know from Soufiane's experience (not a substitute for interviews)
- As a delivery driver: drop-offs run on in-app instructions, customer contact, and delivery photos. Wrong / missing instructions and unanswered customers are the daily friction.
- Mira's Coffee bot: 39 items, pickup + delivery, cash / pay at counter only in v1, no driver system. Chinese Dragon bot: 225 dishes, delivery fee was a $0 placeholder pending restaurant confirmation, tax assumed 7% unconfirmed — so delivery pricing is still unsettled in real stores.
- Gopuff research (2026-11-04): vertically integrated retailer, driver blocks, batched deliveries, pay figures conflicted between sources — do not quote a Gopuff pay number as fact.

## 3. Define — personas, pain points, problem statements

> **Draft personas — hypotheses to validate in interviews. Names, ages and details are illustrative, not real people.**

### Persona 1 — Amine, store owner (restaurant, 38, East Boston)
- Runs a Moroccan restaurant. Lunch + dinner rush, 10–20 deliveries a day. Has one own driver, evenings only.
- **Goals:** never lose an order because the driver is busy; know where every order is without phoning the driver; keep his name good with customers.
- **Frustrations:** when his driver is off, orders pile up or he delivers himself; DoorDash takes too much; he can't tell a customer where their food is.
- **Needs:** assign to his own driver in one tap; if his driver declines / is busy, broadcast to marketplace drivers automatically; see live status; pay drivers weekly in one place.

### Persona 2 — Lina, grocery store owner (42, Boston)
- Small grocery, daily orders, heavier bags, customers who order the same things weekly. No own driver yet.
- **Goals:** offer delivery without hiring a full-time driver; keep regulars loyal.
- **Frustrations:** hiring is a risk — what if there are no orders some days? A courier once left bags at the wrong door and she paid for it.
- **Needs:** start with marketplace drivers only, no commitment; later add her own driver when volume grows; photo proof on every drop; clear fee before she confirms.

### Persona 3 — Karim, own driver (34, Boston)
- Works for one restaurant, evening shifts. Knows the regular customers, the building codes, the shortcuts.
- **Goals:** steady shifts, clear pay per delivery, no wasted trips to a store that isn't ready.
- **Frustrations:** gets jobs by phone call / text, sometimes two at once; doesn't know if the order is ready until he arrives; customer not answering the door.
- **Needs:** a job list with pickup time, address, pay and notes (gate code, fragile); one tap "Picked up / Delivered" + photo; chat with the store in the app, not his personal number.

### Persona 4 — Sara, marketplace driver (29, Cambridge)
- Independent driver, works evenings for several apps. Wants to fill gaps between other jobs.
- **Goals:** pick jobs that pay fairly for the distance; work near home; build a reputation so stores favourite her.
- **Frustrations:** low-pay offers, long pickup waits, no idea if a store is reliable until she tries it.
- **Needs:** open offers on list + map with distance, pay, pickup store and drop-off area *before* she accepts; decline without penalty; ratings that stores can see; fast payout.

### Persona 5 — Yassine, end customer (41, Worcester — orders in Boston)
- Orders food / groceries 2–3 times a week. Doesn't want another app.
- **Goals:** know when it arrives; know who is bringing it.
- **Needs:** a text link, live map + ETA, driver first name, delivered photo. Nothing to install.

### Four pain points (the study's core findings to test)
1. **Trust & control.** A store will not hand its food and its reputation to a stranger. Own drivers are trusted; marketplace drivers are not — yet.
2. **The gap when the own driver is unavailable.** Sick, busy, off-shift, double-booked — today those orders are lost, late, or delivered by the owner himself.
3. **No live picture.** The store phones the driver, the customer phones the store. Nobody knows where the order is.
4. **Pay and proof are messy.** Per-delivery pay, who pays for late / cold / lost orders, and no delivery proof — the argument after the delivery is the real cost.

### Problem statements
- **Store owner:** "Amine needs a way to cover every delivery — with his own driver when available and a trusted backup driver when not — so he never loses an order or his reputation, without paying chain-level commission."
- **Own driver:** "Karim needs clear, ready jobs with address, pay and notes in one place, so he stops wasting trips and phone calls and gets paid fairly for every run."
- **Marketplace driver:** "Sara needs to see distance, pay and store reliability *before* she accepts, so she can choose jobs worth her time and build up favourite-store work."
- **Customer:** "Yassine needs to know who is bringing his order and when it will arrive, without installing another app."

### How Might We (HMW)
- HMW let a store use its own drivers *and* borrow marketplace drivers in one flow, without double work?
- HMW make a marketplace driver trustworthy enough for a store to hand them a first order?
- HMW make "no driver available" never mean "lost order" — backup, escalation, honest ETA?
- HMW prove every delivery with a photo + time, so late / lost arguments end?

## 4. Journey maps (draft)

### Store journey — Order ready → Delivered → Paid
| Stage | Store does | Thinks / feels | Pain |
|---|---|---|---|
| Order ready | Creates delivery: customer, address, items/order #, pickup time, fee, notes | "Get this out fast" | Typing the same address twice; <1 min target |
| Choose driver | Picks own driver (assign) or broadcasts (open offer) | "My driver first — but is he free?" | Own driver may decline / be busy; no fallback today |
| Waiting | Watches Accepted → Picked up → On the way | "Where is it? Customer is calling" | Blind spot; phoning the driver |
| Delivered | Sees photo + time | "Good, done" | If no photo, argument later |
| Paid | Pays driver, sees history / earnings | "Was that trip worth it?" | Pay split across cash, apps, memory |

### Own-driver journey — Shift on → Delivered
Shift on → sees assigned jobs → accepts / declines with reason → navigates to store → confirms pickup (order ready? items right?) → navigates to customer → confirms delivery + photo → next job / earnings update.

### Marketplace-driver journey — Open board → Delivered
Opens board (list + map) → filters by distance / pay → accepts one offer → pickup → delivery + photo → rating from store → payout balance grows → store can favourite her for next time.

## 5. Ideate — flows, information architecture, prioritisation

### The hybrid dispatch rule (the core design decision)
1. Store creates a delivery.
2. Store chooses: **Assign to my driver** (pick one own driver, they accept / decline) OR **Broadcast to marketplace** OR **Auto: my driver first, marketplace after 2 minutes if no accept — TO TEST the timeout with owners.**
3. If the own driver declines or times out, the offer escalates to the marketplace automatically — the store does not re-create it.
4. First marketplace driver to accept gets it. Store sees who accepted, their rating and distance.
5. Delivery runs the same after that, whoever the driver is: pickup → on the way → delivered + photo.

### Key user flows
**Flow A — Store creates a delivery (target <1 min)**
Dashboard → New delivery → customer + address (saved customers / recent addresses) → items / order # → pickup time → fee (suggested by distance, editable) → notes → choose driver mode (My driver / Marketplace / Auto) → confirm → live tracking card appears.

**Flow B — Own driver takes an assigned job**
Notification → job card (address, pay, pickup time, notes) → Accept / Decline (with reason: busy / off / too far) → if Decline, store is told at once and escalation starts → navigate → Picked up → Delivered + photo → earnings.

**Flow C — Marketplace driver takes an open offer**
Board list + map → offer card (distance, pay, store, drop-off area) → Accept → same pickup / delivery steps as Flow B → store rates driver → driver can be favourited.

**Flow D — Customer tracks**
Text link → live map + driver first name + ETA → "Delivered" + photo → rate / tip (v2, not MVP).

### Information architecture (draft)
- **Store:** Dashboard (today's deliveries, live status) / New delivery / My drivers (roster, shifts, pay) / Marketplace (open offers, favourites) / History & payments / Settings (store profile, zones, fees)
- **Driver:** Jobs (assigned + open board) / Map / Earnings / Profile & verification / Ratings
- **Customer:** Tracking link only — no account, no app.

### Feature prioritisation (MoSCoW — for MVP)
**Must (MVP)**
- Store: create delivery in <1 min, assign to own driver, broadcast to marketplace, auto-escalation, live tracking, chat with driver, delivery history, cash ledger (cash collected / returned / owed, "Mark as paid in cash")
- Own driver: assigned job list, accept / decline with reason, navigation, pickup / delivered buttons, photo proof, earnings, shift on/off
- Marketplace driver: open job list + map, accept / decline, navigation, pickup / delivered, photo proof, earnings, ratings
- Both sides: profiles + verification, ratings both ways, notifications, cash recording (no in-app payment in the MVP — decided 2026-11-06, Stripe deferred)
- Customer: tracking link (live map, driver name, ETA, delivered photo); optional profile (C3) for repeat customers — saved addresses, order history
- Admin: see ADMIN_STUDY.md — approvals queue (A2), review detail (A3), payment switch per store (A4), live map of all deliveries (A6), revenue (A7), markets / zones / fees (A8)
**Should (v1.1)**
- Saved customers / addresses, recurring / scheduled deliveries, favourite drivers, store rating of drivers, driver rating of stores
**Could (later)**
- Large / catering orders, auto-dispatch (best driver by distance + rating), customer ordering built-in (connects to Mira / Chinese Dragon bots), promo / subscription plans
- (Multi-stop routes and batched jobs are already in the wireframes and high-fi — S7/D6/D7 — not "later".)
**Won't (not MVP)**
- Rides for people (this is parcels / food / groceries only — the paused consumer marketplace covered rides; do not re-add them here)
- Alcohol / tobacco delivery, insurance claims handling in-app

### What success looks like (to measure in the test, §7)
- Store creates a delivery in <2 minutes on first try, <1 minute on second try
- Own driver accepts / declines in <30 seconds from notification
- Marketplace driver finds and accepts a worthwhile offer in <2 minutes on the board
- Store can tell, without phoning anyone, where an order is at any moment
- Customer opens the tracking link and finds ETA + driver name without help

## 6. Prototype — wireframes (low-fidelity description, to draw / build next)
1. **Store dashboard:** today's deliveries as cards (Accepted / Picked up / On the way / Delivered), each with driver name, ETA, fee. Big "+ New delivery" button.
2. **New delivery form:** one screen, top to bottom: customer, address, items/order #, pickup time, fee (suggested), notes, driver mode (3 big choices: My driver / Marketplace / Auto) — no second screen.
3. **My drivers:** roster list with on/off now, today's jobs, weekly pay. Tap a driver → assign.
4. **Driver job list + map:** toggle List / Map. Each card: pay (big), distance, store, drop-off area, pickup time. Assigned jobs pinned at top, open offers below.
5. **Driver active job:** big status button (Picked up → Delivered), navigation button, chat button, photo button at delivery.
6. **Customer tracking:** map with driver dot, ETA in big type, driver first name, "Delivered ✓ + photo" state.
7. **Earnings / pay:** driver sees per-trip pay + weekly total; store sees per-trip cost + weekly payout.

> No high-fidelity mockups in this study. Next step after interviews: paper / Figma low-fi wireframes of screens 1–6, then a clickable prototype for the usability test in §7.

## 7. Test — usability test plan (to run, not run yet)
**Participants:** 3 store owners (1 restaurant, 1 coffee, 1 grocery), 2 own drivers, 2 marketplace drivers. 30–45 min each, on a clickable prototype, in person where possible.
**Tasks**
1. Store: create a delivery for a regular customer, assign it to your own driver.
2. Store: your own driver declines — get the order covered by a marketplace driver without re-creating it.
3. Own driver: accept an assigned job, mark pickup, mark delivered with a photo.
4. Marketplace driver: find an offer worth $6+ within 3 miles and accept it.
5. Store: find where an order is right now and what the customer sees.
**Measures:** task success (yes / no / with help), time on task, errors, post-task rating (1–5, easy–hard). Success bar: 4 of 5 tasks completed without help by 4 of 5 participants; create-delivery in <2 min first try.
**Findings table — empty on purpose, fill after testing:**

| Task | Success | Time | Errors / quotes | Fix |
|---|---|---|---|---|
| 1. Create + assign to own driver | — | — | — | — |
| 2. Decline → marketplace cover | — | — | — | — |
| 3. Own driver pickup → delivered + photo | — | — | — | — |
| 4. Marketplace driver finds + accepts | — | — | — | — |
| 5. Store finds live status | — | — | — | — |

## 8. Business model — DECIDED 2026-11-06: cash only at the start
- **Cash only in the beginning. No in-app payment in the MVP.** Most small stores pay their drivers cash, and the app will be used in **Morocco as well as in Boston**, so cash is fine. The app records cash instead of moving it: cash collected, cash owed, "mark as paid in cash".
- **Two markets from the start:** Boston (USD, English) and Morocco (MAD, Arabic/French). The $4–$7 per-delivery figure is Boston only, still to test; the Morocco fee in MAD is still to test. Launch is no longer East Boston only — East Boston first in Boston, plus a Morocco launch area to decide (no Moroccan pilot stores named yet). **Design principle (2026-11-06): Wasl is global — Boston + Morocco are the launch markets, not the only markets. New markets (currency, language, zones, fees) are added by the admin, never hard-coded.**
- Store pays BOTH: a per-delivery fee AND a monthly plan (decided 2026-11-06), both set by the admin per store. Amounts still to test (Boston $4–$7 per delivery, Morocco MAD fee, monthly plan price).
- Driver keeps most of the fee; the app keeps a small cut — in cash terms, that means the store settles it in cash, and the app records what is owed. Own-driver trips pay the app too — BOTH the per-delivery fee and the monthly plan apply (decided 2026-11-06).
- **Cash-flow rule — DECIDED 2026-11-06:** when the customer pays cash on delivery, the driver returns **all** the cash to the store, gets paid later by the store, and **keeps any tip**. The app records: cash collected by the driver, cash returned to the store, driver pay owed, tip kept by the driver.
- Questions for stores: per-delivery or flat monthly — which would you rather pay? What is the most you would pay to never lose a delivery? Would you pay extra for guaranteed cover (a driver promised in X minutes)?
- Questions for drivers: what pay per trip makes a 2-mile food run worth it? Per delivery or per hour for own drivers?

## 9. Risks & mitigations (to check in interviews)
1. **Store won't trust outside drivers.** Mitigation: ratings, verification, photo proof, favourite drivers, first-order limit (small orders first). Test: what proof would make you try one marketplace driver?
2. **No driver accepts.** Mitigation: auto-escalation, wider radius after timeout, guaranteed-driver pool for pilot, honest "no driver yet" state + store notified — never silent.
3. **Who pays if late / cold / lost?** Mitigation: decide the rule *before* launch and show it in the app; test who owners and drivers think should pay.
4. **Density.** Without 3–5 stores + 10 drivers in East Boston, wait times kill it. Mitigation: launch in one small area only, pilot stores first.
5. **Beating DoorDash Drive on price / value.** Mitigation: the own-driver mode costs the store less than a marketplace-only trip; test the real price gap with owners.
6. **Own-driver management friction.** Scheduling, no-shows, pay disputes. Mitigation: shift on/off, decline reasons, weekly pay summary, store sees it all in one place.

## 10. Trust, safety & accessibility
- Verification for both sides: store (business name, address, contact), driver (ID, phone, vehicle — exact checks to confirm with local rules, not invented here).
- Ratings both ways; stores can favourite / block drivers; drivers can rate stores (ready on time? accurate address?).
- In-app chat only — no personal numbers shared (same rule as the Gopuff delivery-platform messaging work, 2026-11-04).
- Delivery photo + time on every order; customer sees driver first name only.
- Accessibility (from the Parent Clothing study): big touch targets for drivers on the road / on a bike, high contrast, one-hand use, large status button, text + icons (not colour alone), English + Arabic + French where the store needs it — Soufiane's users are trilingual, test language needs in interviews.

## 11. Next steps & open decisions
**Next step, in order:**
1. **Soufiane approves this study** (or corrects scope / personas).
2. **Real interviews** — 5 owners + 3 own drivers + 3 marketplace drivers + 3 customers (§2). This is the step that turns the draft into real research.
3. **Low-fi wireframes** (screens in §6) → clickable prototype → usability test (§7) → revise.
4. **Then** build decision: MVP scope, pricing, pilot stores.

**Open decisions (not decided yet)**
1. Pilot stores: start with Mira's Coffee + Chinese Dragon Boston, or find new stores? (proposed: Mira's + Chinese Dragon)
2. Auto-escalation timeout: how long to wait for the own driver before broadcasting — 2 minutes? 5? Ask owners.
3. Own-driver trips: decided — BOTH per-delivery fee and monthly plan apply (2026-11-06); amounts still to test.
4. Launch area: East Boston first in Boston, then Greater Boston; plus a Morocco launch area to decide (no Moroccan pilot stores named yet).
5. App name: decided 2026-11-06 — Wasl (وصل). Logo at `workspace/your_files/wasl-logo/`.

## Appendix — interview script (first 5 questions per group)
**Store owner:** How do deliveries work today? / How many a day, when? / What happens when your driver is busy or off? / What do you pay now, and what would you pay to never miss one? / What would make you trust an outside driver?
**Own driver:** How do you get jobs today? / What do you need to see before you accept? / What goes wrong most often? / How do you want to be paid? / What would make the app better than a phone call?
**Marketplace driver:** Would you take store jobs? What pay is worth it? / Open board or assigned — which and why? / What makes you skip an offer? / What do you need to trust a new store?
**Customer:** What matters most when you order delivery? / Do you open tracking links? / What would you do if the order is late and nobody tells you?

---
*Sources used for this draft: `workspace/store-delivery-app/CONCEPT.md` (2026-11-06); Soufiane's delivery-driver experience; Mira's Coffee bot (@Mira_coffee_bot) and Chinese Dragon Boston bot (@Chinese_dragon_boston_bot); Gopuff work-system research, 2026-11-04; Parent Clothing Resale App case study method (Google UX Design Certificate), 2026-11-04. No real interviews, quotes or test scores exist yet — fill §7 after testing.*
