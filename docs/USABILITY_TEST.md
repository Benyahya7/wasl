# Store Delivery App — Usability Test, Round 1
Date: 2026-11-06 | Prototype: `store-delivery-app-wireframes` (16 screens at test time, low-fi; later grew to 18, then the high-fi reached 23 numbered phone screens + Admin with profiles S9/D9/C3 and maps S10/D10 (D2 job map became a real map))
> **Superseded in part — 2026-11-06 last review:** profiles and maps were added to the high-fi after this round. Round 2 should re-test Tasks 4 and 5 on the high-fi (job-board map, driver navigation, live map). F4–F8 fixes are still open unless marked fixed below.
Method: Google UX Design Certificate — Test phase, following the study in `UX_STUDY.md` §7

## Read this first — what this test is and is not
- **This is an expert walkthrough by Raiss, NOT a test with real users.** No store owner, driver or customer has tested the prototype yet. No times, success rates or quotes below are from real participants — there are none to quote.
- **What was actually done:** every one of the 6 tasks was walked through screen by screen on the 16-screen prototype, using the interactions the builder verified as working (role switcher, Prev/Next stepper, List/Map toggle, "Karim declines" escalation simulation, decline-reason flow, active-job status button, Optimise-route toggle, Accept-batch → active run, stop-by-stop button).
- **Verdicts mean:** Pass = the task can be completed in the prototype as designed. Partial = it can be completed, but with a workaround, a missing step, or a demo-only shortcut. Fail = it cannot be completed as the task asks.
- **The real test still has to happen.** This round finds prototype problems early and cheaply. It does not replace testing with 3 store owners, 2 own drivers and 2 marketplace drivers (§7 of the study). The blank score sheet for that real test is at the end of this file.

## Prototype screens used
- Store: S1 Dashboard, S2 New delivery, S3 Who delivers, S4 My Drivers, S5 Live status, S6 History & pay, S7 Build a Run
- Driver: D1 Job board (list), D2 Job board (map), D3 Incoming assignment, D4 Active job, D5 Earnings, D6 Batched offer, D7 Active multi-stop run
- Customer: C1 Tracking link, C2 Delivered + photo
- Plus: wide tablet/desktop store dashboard

## Task results

### Task 1 — Store: create a delivery for a regular customer, assign it to your own driver
**Path:** S1 → + New delivery (S2) → fill customer, address, items/order #, pickup time, fee, notes → S3 Who delivers → My driver → Karim → confirm → live card on S1
**Verdict: Pass**
- The one-screen form is the right call for the <1 min target — no second screen to get lost in.
- **Issue (medium):** no saved customers / recent addresses on S2. A regular customer has to be typed in full every time. That was listed as "Should (v1.1)" in the study, but Task 1 is literally "a regular customer", so it hurts the very first task.
- **Fix:** add a saved-customers row on S2 (recent + favourites) before the real test.

### Task 2 — Store: your own driver declines — get the order covered by a marketplace driver without re-creating it
**Path:** S3 → "Simulate: Karim declines" → escalation sequence runs → offer goes to marketplace → driver accepts → live card updates
**Verdict: Partial**
- The escalation itself works in the prototype and the store does not re-create the order. That is the core of the hybrid idea, and it works.
- **Issue (high):** the store side and the driver side are two separate demos, not one linked flow. On the store side you press a "Simulate" button. On the driver side (D3) there is a real decline-reason flow ("Busy on another job" etc.) — but pressing it there does not drive the store-side escalation, and vice versa. In the real app these are one event. In the prototype they are not connected.
- **Issue (medium):** the 2-minute Auto timeout is a label, not a behaviour. Nobody can tell from the prototype whether 2 minutes feels too long, too short, or right.
- **Fix:** link D3 decline → S3/S5 escalation in the prototype, and show a visible countdown ("Broadcasting to marketplace in 1:24") so the timeout can be judged in the real test.

### Task 3 — Own driver: accept an assigned job, mark pickup, mark delivered with a photo
**Path:** D3 Incoming assignment → Accept → D4 Active job → big button: Picked up → Delivered → photo step
**Verdict: Pass**
- The big status button is the right pattern for a driver on the road — one thumb, one action, no hunting.
- **Issue (medium):** the photo step is a low-fi placeholder. There is no camera, no "retake", and no "customer not answering" path on a single delivery — that path only exists on the multi-stop screen (D7, problem-at-stop). Karim's persona frustration is exactly "customer not answering the door".
- **Fix:** add a problem path to D4 (customer not answering / wrong address / order not ready) with the same shape as D7's, before the real test.

### Task 4 — Marketplace driver: find an offer worth $6+ within 3 miles and accept it
**Path:** D1 Job board (list) → scan cards (pay, distance, store, drop-off area) → D2 map toggle → accept one
**Verdict: Partial**
- Pay and distance are on every card, big and readable. That part works.
- **Issue (high):** there is no filter or sort. To do this task the driver has to scan every card by eye and compare pay and distance herself. For 3 offers that is fine; for 15 offers at dinner rush it is the whole job. Sara's persona need is literally "see distance, pay and store reliability *before* she accepts" — and the prototype makes her hunt for it.
- **Fix:** add filter chips on D1/D2 before the real test: Pay $6+, <3 mi, plus sort by pay and by distance. This is the single biggest fix from Round 1.

### Task 5 — Store: find where an order is right now and what the customer sees
**Path:** S5 Live status → order card (Accepted / Picked up / On the way / Delivered, driver name, ETA) → C1 tracking link (what the customer sees)
**Verdict: Pass**
- The store can tell where an order is without phoning anyone — that was the success criterion, and it holds.
- Customer side shows map, driver first name and ETA, no app to install. Good.
- **Issue (low):** the map on C1 and D2 is a low-fi placeholder box, not a real map. ETA and driver position cannot be judged for real until a map is in. That is expected at low-fi — do not "fix" it by faking a real map; note it as a limit of this round.
- **Update (2026-11-06, after this round):** fixed in the high-fi — real interactive maps on S10 (store live map), D10 (driver navigation), D2 (job map) and C1 (customer tracking). Round 2 must verify the map tiles actually draw on a real phone.

### Task 6 — Store builds a batched run; driver accepts the batch and completes stop 1
**Path:** S7 Build a Run → group 3 ready orders → Optimise route (5.9 mi → 4.6 mi) → send via Karim / Marketplace / Auto → D6 Batched offer (total pay, miles, time, 3 sequenced stops) → Accept → D7 Active run → big button advances Stop 1 → photo → Stop 2
**Verdict: Pass**
- The batch flow is complete end to end, and the whole-batch-only rule is stated clearly on D6.
- **Issue (medium):** whole-batch-only may frustrate drivers — Sara may want 2 of the 3 stops, not all or nothing. No evidence either way yet; that is a question for the real test, not a guess to bake in.
- **Issue (medium):** batch pricing ($18.50 in the example) and the 5-stop cap are open questions carried from the wireframe notes. The prototype shows a number but does not explain how it was calculated (sum of 3 fees? discount for batching?). A driver will ask.
- **Fix:** show the batch pay breakdown on D6 (Stop 1 $6 + Stop 2 $6.50 + Stop 3 $6 = $18.50, or whatever the rule is) once the pricing rule is decided — do not invent the rule in the prototype.

## Cross-cutting findings

| # | Finding | Severity | Where | Fix before real test? |
|---|---|---|---|---|
| F1 | No filter / sort on the driver job board (Task 4) | High | D1 / D2 | Yes — filter chips: $6+, <3 mi; sort by pay / distance |
| F2 | Store escalation and driver decline are separate demos, not one linked flow (Task 2) | High | S3 / D3 / S5 | Yes — link D3 decline to store escalation + visible countdown |
| F3 | No chat screen in the wireframes, although "chat with driver" is a Must in the MVP | High | — (missing screen) | Yes — add a simple in-app chat screen (store ↔ driver, per order, no personal numbers) |
| F4 | No saved customers / recent addresses on the new-delivery form (Task 1) | Medium | S2 | Yes |
| F5 | No problem path on a single delivery — customer not answering, wrong address, order not ready (Task 3) | Medium | D4 | Yes — mirror D7's problem-at-stop |
| F6 | Batch pay breakdown not shown; pricing rule undecided (Task 6) | Medium | D6 | After pricing decision — show breakdown, don't invent the rule |
| F7 | Map is a placeholder box on C1 / D2 | Low | C1 / D2 | No — expected at low-fi; note as a limit |
| F8 | 2-minute Auto timeout is a label, not a behaviour | Medium | S3 | Show a live countdown in the prototype so it can be judged |

**Success bar from the study (§7):** 4 of 5 tasks completed without help by 4 of 5 participants; create-delivery in <2 min first try. **Round 1 verdict:** 4 of 6 tasks Pass, 2 Partial, 0 Fail — on an expert walkthrough, not on real participants. That bar cannot be claimed as met until the real test runs. F1–F3 should be fixed first, or the real test will spend its time rediscovering them instead of finding new problems.

## What was NOT tested in this round
- Real map / navigation, real camera / photo, real notifications, real payment / payout.
- Any task with a real store owner, driver or customer.
- The tablet dashboard beyond "Run R-7 at Stop 2 of 3" being visible — it was not walked through task by task.
- Accessibility beyond the big-button pattern (one-hand use, contrast, text + icons) — needs a real phone test, in daylight, by a driver.

## Next step — the real test (to run, not run yet)
**Participants (from the study):** 3 store owners (1 restaurant, 1 coffee, 1 grocery), 2 own drivers, 2 marketplace drivers. 30–45 min each, on the clickable prototype, in person where possible.
**Before that test, fix F1, F2 and F3 in the wireframes.** Then run the 6 tasks below with the score sheet. Soufiane can also be tester 1 himself — run the 6 tasks on his phone, note where he gets stuck, and those notes become the first real findings.

### Real-test tasks (give the participant the goal, not the steps)
1. Store: create a delivery for a regular customer, assign it to your own driver.
2. Store: your own driver declines — get the order covered by a marketplace driver without re-creating it.
3. Own driver: accept an assigned job, mark pickup, mark delivered with a photo.
4. Marketplace driver: find an offer worth $6+ within 3 miles and accept it.
5. Store: find where an order is right now and what the customer sees.
6. Store + driver: build a batched run of 3 orders, accept it as a driver, complete stop 1.

### Blank score sheet — fill one per participant
| Participant (role / store type) | Task | Success (yes / no / with help) | Time | Errors / what they said (their words) | Fix |
|---|---|---|---|---|---|
| | 1. Create + assign to own driver | | | | |
| | 2. Decline → marketplace cover | | | | |
| | 3. Own driver pickup → delivered + photo | | | | |
| | 4. Marketplace driver finds + accepts $6+ / <3 mi | | | | |
| | 5. Store finds live status + customer view | | | | |
| | 6. Batched run: build → accept → stop 1 | | | | |
| Post-test rating (1–5, easy–hard) per task: | | | | | |

---
*Sources: `workspace/store-delivery-app/UX_STUDY.md` §6–§7; prototype `store-delivery-app-wireframes` (16 screens) and its builder verification (role switcher, stepper, List/Map toggle, escalation simulation, decline flow, status button, Optimise-route toggle, Accept-batch, stop-by-stop button all verified working). No real participants, times or quotes exist yet.*


---

# Round 2 — Real test on the high-fi prototype (STARTED 2026-11-06)
Status: **IN PROGRESS — plan ready, participant 1 (Soufiane) running now; the owner and driver participants are still to be named.**
Prototype: `store-delivery-app-high-fidelity-prototype` — 23 numbered phone screens (S1–S10, D1–D10, C1–C3) + Admin web surface A1–A8, Wasl branding, real maps, profiles, market selector (global).
Method: Google UX Design Certificate — Test phase, following `UX_STUDY.md` §7 and `ADMIN_STUDY.md` §8.

## What changed since Round 1 (what Round 2 must verify)
- **F1 fixed:** filter chips ($6+, ≤3 mi, Clear) + sort (Pay / Distance / Soonest) on D1/D2, with live count. Round 2 Task 4 is the proof.
- **F2 fixed:** D3 decline with a reason now drives the S3 escalation on order #1044 (banner + auto-run to Sara) with a visible countdown. Round 2 Task 2 is the proof.
- **F3 fixed:** chat screens S8 (store) and D8 (driver) — same per-order thread mirrored. Test it inside Task 2 or 5.
- **Profiles added:** S9 store, D9 driver, C3 customer (optional).
- **Real maps added:** S10 store live map, D10 driver navigation, D2 job map, live map on S5 and C1. **Round 2 must verify the map tiles actually draw on a real phone** — the builders could not confirm this.
- **Admin added:** A1–A8 web surface (approvals, payment switches, revenue, live map of all deliveries, markets).
- **Still open in the prototype:** F4 (no saved customers on S2), F5 (no problem path on a single delivery D4), F6 (batch pay breakdown on D6 — pricing rule undecided, do NOT invent it in the test). Note them if participants hit them; do not treat them as new findings.

## Participants
- **P1 — Soufiane** (store owner + admin): runs store Tasks 1, 2, 5, 6 and all 5 Admin tasks. First session, running now.
- **P2 — store owner (TO NAME):** runs store Tasks 1, 2, 5, 6. Proposed: Mira's Coffee or Chinese Dragon owner.
- **P3 — driver (TO NAME):** runs own-driver Tasks 3, 6 and marketplace Task 4. A real driver, not the Karim/Sara personas.
- 30–45 minutes each, on a real phone, in person where possible. One session per participant.

## Rules for running a session
- Give the participant the **goal, not the steps**. Read the task out loud exactly as written below.
- **No help** unless they are stuck for more than 2 minutes — then help once, and record the task as "with help" + what the help was.
- Record: time, success (yes / no / with help), errors or wrong turns, and **their exact words** — quotes, not summaries.
- After each task, ask: "How easy was that, 1 to 5?" (1 = hard, 5 = easy). Write the number down.
- Do not explain the prototype, defend a design choice, or say "it's just a prototype" when they get stuck. A stuck participant is a finding.

## Success bar
- **Store + driver tasks (from the study §7):** 4 of 5 tasks completed without help by 4 of 5 participants; create-delivery in under 2 minutes on the first try.
- **Admin tasks (from ADMIN_STUDY.md §8):** approval in under 30 seconds, under 3 taps.

## Round 2 tasks (give the goal, not the steps)
### Store + driver tasks (same 6 as Round 1, now on the high-fi)
1. **Store:** create a delivery for a regular customer and assign it to your own driver.
2. **Store:** your own driver declines — get the order covered by a marketplace driver, without re-creating it.
3. **Own driver:** accept an assigned job, mark pickup, mark delivered with a photo.
4. **Marketplace driver:** find an offer worth $6+ within 3 miles and accept it.
5. **Store:** find where an order is right now, and see what the customer sees.
6. **Store + driver:** build a batched run of 3 orders, accept it as a driver, complete stop 1.

### Admin tasks (Soufiane as admin, A1–A8)
- **A.** Approve a store that is waiting in the approvals queue.
- **B.** Reject a driver with a reason.
- **C.** Approve a driver that a store submitted.
- **D.** Turn card on for one store (the guard should stop you — card needs a payout account + fee agreement — and the store must never be left with no payment method).
- **E.** Settle a late-order dispute: decide who pays and record the decision.

## Score sheets — fill one per participant (results: P1 Task 2 recorded 2026-11-06; the rest blank)
### P1 — Soufiane (store + admin) — session: ___ / ___ / 2026, ___ min
| Task | Success (yes / no / with help) | Time | Taps / errors | Their words (exact) | Fix |
|---|---|---|---|---|---|
| 1. Create + assign to own driver | | | | | |
| 2. Decline → marketplace cover | yes | — (to confirm) | — | "When I assign to a drivers one was busy and the other he declined so I got back up from the market place" / "Was easy but I was worried no one will pickup the delivery" | R2-1: easy to do, but the store owner worried no one would pick the delivery up — guaranteed-driver-pool question still open |
| 3. (driver) Pickup → delivered + photo | | | | | |
| 4. (marketplace) Find + accept $6+ / <3 mi | | | | | |
| 5. Live status + customer view | | | | | |
| 6. Batched run → accept → stop 1 | | | | | |
| A. Approve a store | | | | | |
| B. Reject a driver with reason | | | | | |
| C. Approve a store-submitted driver | | | | | |
| D. Turn card on (guard check) | | | | | |
| E. Settle a late-order dispute | | | | | |
| Easy rating 1–5 per task: Task 2: easy (user's word, no number given) | | | | | |
| Maps drew on the phone? D10 / S10 / A6: | | | | | |

### P2 — store owner (name: ___) — session: ___ / ___ / 2026, ___ min
| Task | Success (yes / no / with help) | Time | Taps / errors | Their words (exact) | Fix |
|---|---|---|---|---|---|
| 1. Create + assign to own driver | | | | | |
| 2. Decline → marketplace cover | | | | | |
| 5. Live status + customer view | | | | | |
| 6. Batched run (store side) | | | | | |
| Easy rating 1–5 per task: | | | | | |

### P3 — driver (name: ___) — session: ___ / ___ / 2026, ___ min
| Task | Success (yes / no / with help) | Time | Taps / errors | Their words (exact) | Fix |
|---|---|---|---|---|---|
| 3. Pickup → delivered + photo | | | | | |
| 4. Find + accept $6+ / <3 mi | | | | | |
| 6. Batched run → accept → stop 1 | | | | | |
| Easy rating 1–5 per task: | | | | | |
| Maps drew on the phone? D10 / D2: | | | | | |

## Session log
| Session | Participant | Date | Tasks run | Result |
|---|---|---|---|---|
| 1 | P1 Soufiane | 2026-11-06 | Task 2 run — own drivers busy / declined → marketplace backup worked | partial — ease recorded ("easy"), time still to confirm |
| 2 | P2 (to name) | — | — | not scheduled |
| 3 | P3 (to name) | — | — | not scheduled |

## Round 2 findings so far
| # | Finding | Severity | Where | Fix / status |
|---|---|---|---|---|
| R2-1 | Task 2 was easy to do, but the store owner worried no one would pick the delivery up. The screens work; the fear is about the real world, not the prototype — a clickable demo cannot prove a driver will accept at dinner rush. This is CONCEPT.md risk #2 ("What happens when no driver accepts?") confirmed by a real user, not just a study question. | High | Task 2 / escalation | Open — decide before the build: what happens when nobody accepts? Candidates (not decided): auto-raise the pay after X minutes with no accept; alert the store to handle it by hand; a small on-call guaranteed pool. Only real drivers at real rush hour can prove the answer. |
