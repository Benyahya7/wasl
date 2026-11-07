# Wasl — Admin UX Study (Draft v0.1)
Date: 2026-11-06 | Owner: Soufiane Benyahya | Status: Study first, no build yet
Method: Google UX Design Certificate process — Empathize, Define, Ideate, Prototype, Test (same method as `UX_STUDY.md` and the Parent Clothing Resale App case study)
Companion files: `UX_STUDY.md`, `IA.md`, `BACKEND.md`, `REVIEW.md`

## How to read this study — please don't skip
- **This is a draft study, not finished research.** The Admin persona is Soufiane himself — the platform owner and the only admin at launch — built from his own decisions on 2026-11-06, not from interviews with other admins (there are none). **Admin account (decided 2026-11-06): raiss95@gmail.com**, Google sign-in — the same account as his Hanimo admin and Firebase login. Anything marked **TO TEST** must be checked before it is treated as fact.
- **Decided by Soufiane on 2026-11-06:** the admin approves stores and drivers; the admin controls cash or card per store; a store can submit its own drivers to the admin, and the admin decides to approve or not.
- **Payment decision still open:** cash first with card switchable later (recommended) vs card now vs approval-only. The user has not picked one. This study is written so the payment switch works either way — cash on by default, card off until the admin turns it on.
- **No real test has been done yet.** No admin has used an Admin prototype — there is no Admin prototype yet. The test plan in §8 is TO DO.

## 1. Overview

### One sentence
The admin is the platform owner who decides who can use Wasl and how each store gets paid.

### The system — four sides, one delivery
1. **Store app** — creates deliveries, manages its own drivers.
2. **Driver app** — own drivers + marketplace drivers, one app.
3. **Customer tracking link** — no app, no account (profile optional).
4. **Admin (web)** — decides, watches, and steps in when something goes wrong. The admin does not deliver; the admin is the trust layer.

### Why the admin matters
- **Trust:** only real stores and real drivers get in. One fake store or one bad driver hurts every store's name.
- **Money:** cash or card is decided per store, by the admin — not by each store on its own.
- **Order:** zones, fees, payouts, disputes. When an order goes wrong, someone has to decide, and that someone is the admin.

### Competitors — how other admins work (researched 2026-11-06)
- **Metrobi:** the business is its own admin. The store's dashboard manages its own driver pool — preferred drivers who see jobs first, ban drivers who fall short — plus routes, live tracking, proof of delivery and billing. Metrobi charges per driver (from $2.99/month per driver). There is no platform admin above the stores.
- **Onfleet:** the dispatcher is the admin. A Command Center with a live map, exception flagging, auto-dispatch to the nearest driver, in-app chat, proof of delivery and an analytics console (on-time %, route duration, driver idle). From $619/month for 2,500 tasks. Built for one business's fleet, not for many stores.
- **DoorDash Drive / Uber Direct:** a platform admin exists but is hidden. They onboard merchants and couriers centrally, run background checks, set pricing and handle payouts — but the merchant never sees it; the merchant only gets a simple portal (create a delivery, track it). All the power stays inside DoorDash / Uber.
- **Gopuff:** no external admin at all — fully internal operations.
- **What Wasl does differently:** the platform owner is a real, designed role — approvals, payment control per store, revenue control, and a live map of all deliveries. None of the competitors sells this as a product surface.
- *Honest limit: from the competitors' public pages and review sites (GetApp, Capterra, Onfleet's own pages), not from sitting inside their dashboards. The DoorDash / Uber internal admin is not public at all — that part is from how their merchant side works.*

### Revenue model (decided 2026-11-06)
- **The admin app is how the admin makes money: stores pay to use Wasl.** Anyone using the app pays — the stores pay, the drivers get paid by the stores. The admin controls all of it: fees, plans, payouts.
- **Full control:** the admin sees and controls everything — who is in, how each store pays, what each store pays, and what is happening live.
- **Fee shape decided 2026-11-06: BOTH** — a per-delivery fee AND a monthly subscription. The admin sets both per store (A8 Zones & fees, A7 Payouts). Amounts still to test: Boston per-delivery $4–$7, Morocco MAD fee, and the monthly plan price in both markets.

## 2. Empathize — research plan

### Research questions (the admin is Soufiane — answer from his own workflow, then test with him)
**Approvals**
1. When a store signs up, what do you need to see before you say yes — business name, type, address, phone, hours, photos?
2. When a driver signs up, what proves he is who he says he is — ID photo, phone, vehicle, a photo of him?
3. How fast should approval be — same day? What does the store or driver see while they wait?
4. When a store submits its own driver, what do you check differently from a marketplace driver who applies alone?

**Money**
5. Cash or card per store — what makes you turn card on for a store? What would you need to see first (a payout account, a fee agreement)?
6. Who pays the card fee — the store, the customer, or Wasl?

**When things go wrong**
7. What does a bad day look like — no driver accepts, a late / cold / lost order, a driver who keeps the cash, a fake store? What do you do first?
8. How do you want to be told — a push, a list, an email? How often do you check?

### Interview plan — TO DO, not done
- 1 admin (Soufiane, 60 minutes): walk through 5 tasks on paper first — approve a store, reject a driver, approve a store-submitted driver, turn card on for a store, settle a dispute.
- 2 store owners: would you wait for approval? What proof would you send? What would you want to know while waiting?
- 1 own driver + 1 marketplace driver: what would you send to prove yourself? Is it clear what happens while you wait?
- No interviews with other admins — he is the only admin at launch.

## 3. Define — persona

### Persona: Soufiane, platform owner / Admin
- 30s, Boston + Morocco. Runs Wasl alone at launch. A delivery driver himself; built the Mira's Coffee and Chinese Dragon order bots; knows both pilot stores personally.
- **Goals:** only real stores and real drivers on Wasl; approve fast so nobody waits; know where the money is (cash per store); step in fast when an order goes wrong.
- **Frustrations:** being the bottleneck — every approval waits on him; fake sign-ups; cash that doesn't come back to the store; disputes with no rule (who pays if late / cold / lost?).
- **Needs:** one queue, one tap to approve or reject with a reason; the proof (ID, business details) on the same screen as the button; a payment switch per store; a live view of orders and exceptions; block in one tap.
- **Quote (hypothesis, TO TEST):** "If I can't approve someone in 30 seconds from my phone, the queue will pile up and stores will leave."

### Secondary people the admin deals with
- **Store owner submitting a driver:** needs to know the driver is pending, approved, or rejected — and why.
- **Driver applying:** needs to know what to send and how long approval takes.
- **No support staff at launch** — the admin is one person.

## 4. Pain points (the admin's, 5)
1. **Bottleneck:** every store and driver waits on one person. At 3–5 stores it is fine; at 30 it breaks.
2. **Trust:** fake stores, fake drivers, stolen photos. One bad delivery hurts every store's name.
3. **Money:** cash per store is simple. Card adds fees, payout accounts, chargebacks — and card setup in Morocco differs from Boston.
4. **Disputes:** late / cold / lost — no rule yet on who pays. The admin decides case by case today; that does not scale.
5. **Blind spots:** orders with no driver, drivers keeping cash, stores going quiet — the admin finds out late unless exceptions surface on their own.

## 5. Ideate — admin flows (the core of this study)

### Flow A — Store sign-up approval
Sign up (business name, type, address, phone, hours, market) → **Pending** → Admin queue → Review (proof on the same screen) → **Approve** (store can post orders) / **Reject with reason** (store sees the reason, can fix it and resubmit).

### Flow B — Driver sign-up approval
Sign up (name, photo, phone, vehicle, zone, languages, ID photo) → **Pending** → Admin queue → Review → **Approve** (driver sees jobs, with Own-driver or Marketplace badge) / **Reject with reason**. A driver cannot see jobs or accept anything while pending.

### Flow C — Store submits its own driver
Store (My Drivers → Add driver / Submit) → driver gets a link to complete ID + vehicle → **Pending in the admin queue, tagged "submitted by [store]"** → Admin approves / rejects → the store is told. A store cannot assign a driver who is not approved yet.

### Flow D — Payment control per store
Admin opens Store detail → Payment: **Cash (on by default) / Card (off by default — needs a payout account + fee agreement, TO DECIDE)** → toggle → the store and the customer see the change on the next order. The cash ledger keeps working exactly the same way; card orders are recorded separately.

### Flow E — Exception + dispute
Order late / no driver / customer reports a problem → appears in Admin exceptions with the order, driver, store, timeline and photo → Admin decides: reassign, refund (card orders only), warn or block the driver, or rule on who pays → the decision is recorded and both sides are told.

### Flow F — Block
Admin blocks a driver or a store in one tap, with a reason → the blocked account sees a plain message + how to appeal (contact the admin). Blocked drivers disappear from the job board; blocked stores cannot post orders.

## 6. Admin screens (A1–A8, web — phone question open)
- **A1 Dashboard:** approvals waiting (count), live orders, exceptions, cash collected today (per market, in local currency), quick links.
- **A2 Approvals queue:** stores + drivers in one list; filter (store / driver, submitted-by-store); each row: name, type, what was submitted, how long it has waited. Tap → A3.
- **A3 Review detail:** all proof on one screen (ID photo, business details, vehicle, which store submitted them) + **Approve / Reject with reason + note**. One tap, no second screen.
- **A4 Store detail:** business, market / zone, drivers, orders, ratings, **Payment (cash / card switches, fee)**, Block.
- **A5 Driver detail:** verification status, vehicle, rating, deliveries, on-time rate, cash still to return, pay owed, Block.
- **A6 Live orders:** all orders, live status, exceptions highlighted, reassign — plus a **live map of all deliveries and drivers** (the admin sees every trip on one map, unlike the store which only sees its own drivers on S10).
- **A7 Payouts & disputes:** cash per store, payout status, dispute list + decision record.
- **A8 Zones & fees:** markets the admin adds (Boston + Morocco first — East Boston first in Boston, Morocco zone to decide), zones within each market, per-delivery fee and monthly plan per market in local currency. Nothing assumes only two markets exist — Wasl is designed global.
- **Open question:** Admin is web-only in IA v0.2. Approvals from a phone would be faster for one admin — test whether Admin needs a phone view too, or web-only is fine.

## 7. MoSCoW
**Must (MVP)**
- Approvals queue (A2) + review detail with one-tap approve / reject + reason (A3); pending state blocks orders and jobs.
- Store submits its own driver (Flow C).
- Payment switch per store — cash on, card off by default (A4).
- Block in one tap (A4 / A5).
- Exceptions list (A6).
**Should (v1.1)**
- Dashboard counts (A1); payout summary (A7); zones & fees editor (A8); search / filter in the queue; rejection templates (common reasons).
**Could (later)**
- Analytics (approval time, top stores / drivers, dispute rate); bulk approve; audit log (who approved what, when); a second admin role.
**Won't (not MVP)**
- Full background checks / automated approval; in-app card onboarding (Stripe Connect) until card is switched on; multi-admin permissions.

## 8. Test plan — TO DO, not done
- **1 admin (Soufiane):** 5 tasks on the future Admin prototype — approve a store, reject a driver with a reason, approve a store-submitted driver, turn card on for one store, settle a late-order dispute. Measure: time per approval, taps, mistakes. Target (TO TEST): approval in under 30 seconds, under 3 taps.
- **1 store owner:** submit a driver, read the pending / rejected state — is it clear what happens next?
- **1 driver:** apply, read the pending state — is it clear what to send and how long it takes?
- No real test done yet. A blank score sheet goes in when the Admin prototype exists.

## 9. Open decisions (not decided yet)
1. **Payment:** cash first with card switchable later (recommended) vs card now vs approval-only? — the user has not picked.
2. **Approval proof:** exactly what must a store send (business licence? just name / address / photo?) and a driver send (ID + vehicle photo? licence?) — in Boston and in Morocco (rules differ).
3. **Approval speed:** same-day promise? What does the applicant see while waiting?
4. **Rejection:** fixed reason list or free text? Can they resubmit, and how many times?
5. **Card:** who pays the fee (store, customer, Wasl), and what payout account is needed before card can be switched on?
6. **Disputes:** who pays if late / cold / lost — store, driver, or Wasl? (Carried from the main review; still open.)
7. **Admin on phone:** web-only (IA v0.2) or also a phone view for approvals on the go?
8. **Bottleneck plan:** at what size does one admin stop coping — a second admin, or auto-approve the drivers of stores he already trusts?
9. **Revenue (decided 2026-11-06): BOTH** — per-delivery fee AND monthly subscription, set by the admin per store. Amounts still open: Boston per-delivery $4–$7 (to test), Morocco MAD fee (to test), monthly plan price in both markets.

## 10. What this study changes in the other files (to do after approval)
- **IA §4:** replace the Admin bullet list with A1–A8 + the new flows.
- **BACKEND:** `users.verificationStatus` (pending / approved / rejected + reason + submittedByStore), `stores.paymentMethods` (cash / card), admin-only writes; approval is a server transaction (no self-approval).
- **High-fi prototype:** Admin screens A1–A8 (web) — after this study is approved.
- **UX_STUDY §1:** Admin is a fourth side of the system, not an afterthought; the admin persona lives here, not there.
