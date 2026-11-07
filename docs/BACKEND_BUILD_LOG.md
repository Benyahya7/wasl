# Wasl — Backend Build Log
Date: 2026-11-06 ~22:31–23:00 EST | Built by: Raiss (subagent) | Authorized by: Soufiane — "build the backend first"
Spec: `BACKEND.md` (followed exactly; no fields invented, no decided rules changed)

## Project
- **Project ID:** `wasl-delivery-app` (display name "Wasl")
- **Project number:** 716697285349
- **Console:** https://console.firebase.google.com/project/wasl-delivery-app/overview
- **Plan:** Spark (free). Billing verified OFF (`billingEnabled: false`), $0 spent, no payment method added.
- **Project ID note:** the ID could not literally be `wasl` — GCP project IDs must be at least 6 characters, and `wasl-app` and `wasl-delivery` were already taken globally. `wasl-delivery-app` was the first free ID.
- **Cleanup:** while probing IDs I created three projects; `wasl-store-delivery` and `wasl-boston` were deleted immediately (state `DELETE_REQUESTED`, purge after 30 days, cost $0). Only `wasl-delivery-app` remains active.

## What was created
1. **Google Cloud project** `wasl-delivery-app` (via Resource Manager API — the Firebase CLI's create call timed out on this VM, curl worked).
2. **Firebase enabled** on the project (`addFirebase` operation, done).
3. **APIs enabled:** `firestore.googleapis.com`, `identitytoolkit.googleapis.com`, `firebasestorage.googleapis.com`, `firebase.googleapis.com`.
4. **Firestore** — database `(default)`, Native mode, location `nam5`, free tier. Created via the Firestore Admin API.
5. **Web app** "Wasl Web" — app ID `1:716697285349:web:d014d63e5d1d57b2c99a0c`, auth domain `wasl-delivery-app.firebaseapp.com`. (Needed later for the Flutter build; the Android app registration comes with the app build — package name not decided yet.)
6. **Firestore security rules** — written to `firebase/firestore.rules`, deployed cleanly (CLI: "released rules to cloud.firestore", ruleset `168a9d81-c518-4ba0-bd60-e62acf996fc8`, 2026-11-07 03:41 UTC). Storage rules written to `firebase/storage.rules` (deploy pending on the bucket, see below).
7. **Collections** — all 11 exist: `users`, `stores`, `drivers`, `deliveries`, `runs`, `chats` (as `deliveries/{id}/messages` subcollection), `ratings`, `payouts`, `zones`, `markets`, `orders`, `menus`.
8. **Seed data** (19 docs, script: `firebase/seed.py` — re-runnable, idempotent):
   - `markets/boston` (USD, English), `markets/morocco` (MAD, Arabic/French) — fee fields left `null` on purpose (amounts still to test).
   - `zones/east-boston` (market: boston).
   - `stores/miras-coffee` (393 Bennington St, East Boston; cash on, card off; approved).
   - `drivers/karim` (own driver, Mira's Coffee, approved), `drivers/sara` (marketplace driver, approved).
   - `users/raiss95@gmail.com` — **role: admin**, approved (see admin note below).
   - `users/seed-store-miras-coffee`, `users/seed-driver-karim`, `users/seed-driver-sara` (approved), `users/seed-pending-driver` (pending — rules-test fixture), `users/seed-pending-store` (pending — rules-test fixture), `users/admin-test-uid` (admin role — rules-test fixture).
   - `deliveries/1044` — Mira's Coffee → customer, driver Karim, mode `my-driver`, status `accepted`, **pickupCode `K7M2`**, order total $18.00, fee $6.00 (prototype sample numbers).
   - `deliveries/1044/messages/msg-1` (store: "Order #1044 is ready for pickup."), `deliveries/1044/tracking/trk-1044-7f3a9c` (public tracking mirror).
   - `ratings/rating-1044` (5 stars for Karim), `payouts/payout-karim-1044` (pay owed $6, cash collected $18).
   - `runs/_seed`, `orders/_seed`, `menus/_seed` — placeholder docs that exist only to materialize these empty collections; **delete before launch**.

## What was verified (with evidence)
- **Rules deployed clean:** `firebase deploy --only firestore:rules` — "released rules firestore.rules to cloud.firestore", no errors.
- **Rules tested live against the deployed ruleset** (Firebase Rules Test API, `get()` mocked to the seeded user docs): **14/14 passed**, each for the right reason:
  1. pending store create delivery → DENY ✓
  2. approved store create delivery → ALLOW ✓
  3. pending driver list job board → DENY ✓
  4. approved driver list job board → ALLOW ✓
  5. unauthenticated get delivery → DENY ✓
  6. unauthenticated get tracking mirror → ALLOW ✓
  7. admin get user doc → ALLOW ✓
  8. pending driver get unassigned delivery → DENY ✓
  9. assigned driver (Karim) get delivery → ALLOW ✓
  10. other driver (Sara) get delivery → DENY ✓
  11. store owner get delivery → ALLOW ✓
  12. admin get delivery → ALLOW ✓
  13. pending user self-approve (set own verificationStatus) → DENY ✓
  14. admin approves pending user → ALLOW ✓
  - Note: the test API needed two workarounds — `get()` calls must be mocked (test API doesn't execute them live) and `request.resource` must be given in native rules-engine form, not Firestore proto form. The two `list` cases only evaluate on a document path in this API, not on the collection path; the rule itself is unchanged and correct.
- **Docs fetched live:** `deliveries/1044` (status `accepted`, pickupCode `K7M2`, Mira's Coffee, Karim, my-driver, $18/$6), `users/raiss95@gmail.com` (role `admin`, approved).
- **Billing:** `billingEnabled: false` — Spark, $0.
- **Other projects untouched:** anime-app-556c8, miras-coffee, chinese-dragon, driver-app-23a6a — read-only list only, never written.

## Still pending — needs the user (console clicks)
These two steps could NOT be done via API on this VM; they need a few clicks in the Firebase console. Nothing is faked — they are simply not done yet.

### 1. Enable sign-in methods (Google only for now — REQUIRED before any app sign-in works)
- Open https://console.firebase.google.com/project/wasl-delivery-app/authentication/providers
- **Google** → Enable → Save. (This auto-creates the OAuth client; the API route needs a client ID that only the console creates for this project.) Google sign-in is free on Spark — no billing screen.
- **Phone — DEFERRED (2026-11-06 ~23:07 EST):** the console asks to link a Cloud Billing account (Blaze, pay-as-you-go) when enabling Phone sign-in — the user hit exactly that screen. Do NOT link it; the user does not want to pay anything. Phone sign-in waits until/unless he approves Blaze. Google sign-in covers the pilot (stores, drivers, admin all sign in with Google).
- Why it is pending: the Identity Platform config does not exist yet for this project — the API returns `CONFIGURATION_NOT_FOUND`, and `initializeAuth` (the API way to create it) refuses with `BILLING_NOT_ENABLED` because it is the paid Identity Platform upgrade path. The console's Auth setup creates the free Spark config instead. Attempted and documented: `initializeAuth` (400 BILLING_NOT_ENABLED), IdP config create (400, needs clientId), Auth user create (400 CONFIGURATION_NOT_FOUND).
- After this is done, tell me and I will verify Google sign-in works and re-key the admin doc (see admin note).

### 2. Create the Storage default bucket — BLOCKED, requires a plan upgrade (found 2026-11-06 ~23:14 EST)
- The browser opened https://console.firebase.google.com/project/wasl-delivery-app/storage: there is NO "Get Started" button. The page says "To use Storage, upgrade your project's pricing plan" with only an "Upgrade project" button. The browser did NOT click it, did not link billing, did not change the plan. **The default bucket does not exist.**
- So on this new project, Cloud Storage for Firebase requires the Blaze plan — the free Spark tier no longer includes a default bucket. (The earlier API 404s were the same wall, not a bug.)
- **Consequence for the app build:** delivery photos cannot live in Firebase Storage unless the plan upgrades. Free alternatives (no card): Cloudinary free tier (25 GB) as the photo home, or small compressed photos stored in Firestore itself. Decision for the app build — default plan is Cloudinary free unless the user says otherwise.
- **Step 1 outcome (same session):** Google sign-in ENABLED and verified in the console (toast + provider row "Enabled", support email raiss95@gmail.com). Phone provider NOT enabled (deferred — Blaze prompt). The user signed in to Google himself during a brief browser takeover; sign-in completed via the account's two-step prompt.

## Still pending — Blaze-gated (NOT built, NOT faked)
Per BACKEND.md, these need the Blaze (pay-as-you-go) plan and are out of scope on Spark:
- Cloud Functions: 2-minute auto-escalation timer, push notifications (assignment / decline / delivered), server payout math, order-intake endpoint (v2, Mira's/Dragon apps).
- Customer tracking link currently works via the public tracking mirror (`deliveries/{id}/tracking/{token}`) instead of a function — that part IS built (see rules test #6).
- No Stripe (v2 only), no SMS provider (to decide), no Mapbox token yet (needed for the app build, free tier, no card).

## Admin note
- The admin doc is `users/raiss95@gmail.com` with `role: admin` — keyed by **email**, because no Firebase Auth user (UID) exists yet (Auth config pending, step 1 above).
- **At first Google sign-in**, the app must create/merge the `users/{uid}` doc for raiss95@gmail.com with `role: admin` (same auto-grant pattern as Hanimo: grant by email, store by UID). Until then, rules that read `users/{auth.uid}` cannot see the admin role — this is expected and documented, not a bug.
- `users/admin-test-uid` exists only as a rules-test fixture; delete it once the real admin UID doc exists.

## Files
- Rules + config: `~/workspace/store-delivery-app/firebase/` (`firestore.rules`, `storage.rules`, `firebase.json`, `.firebaserc`, `seed.py`)
- This log: `~/workspace/store-delivery-app/BACKEND_BUILD_LOG.md`
- Spec: `~/workspace/store-delivery-app/BACKEND.md` (unchanged by this build)

## Next step (when the user says go)
1. User does the two console steps above.
2. Re-run rules deploy for storage + verify Auth (Google sign-in) and the admin UID merge.
3. Build the Flutter app (package name to decide) wired to this backend: create → assign → pickup code → delivered + photo → cash ledger, end to end.
