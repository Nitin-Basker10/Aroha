# AROHA — Remaining Fixes Implementation (Consolidated)

> Generated 2026-09-21. Audited against current `lib/` — older plans partially done.
> Already DONE: family removal (only `hqAdmin`+`stationStaff`), station lock in `station_selector_bar.dart:23`, Watney zero/NaN guards, `validators.dart`, `InventoryAuditLog`, duplicate-ID checks for inventory/personnel, `selectedStation`/`getStationName` fallbacks, role-based tabs in `main_layout_screen.dart:95`, `getMessagesForUser` base filtering, `canViewMedical` masking.
> This file lists ONLY true remaining work.

## 0. Conventions
- Pass `user: auth.currentUser` to every mutating `PolarDataService` call (service already enforces `canEditStation`).
- Use `Validators.validateConsumption / validatePositiveNumber / validateRequired`.
- `DropdownButtonFormField(initialValue:)` is CORRECT on current Flutter — do NOT change to `value:`.

---

## 1. Cross-Station Comms Recipient Routing [BUG]

**Files:** `lib/views/comms/comms_hub_screen.dart`, `lib/services/polar_data_service.dart`

**Problem:**
- `comms_hub_screen.dart:714` uses `replaceAll(' Ops','')` → `recipientId` becomes station *name* (`"Maitri Station"`), but `getMessagesForUser` in `polar_data_service.dart:90` matches on `stationId`/`uid` (`maitri`, `staff_mtr_01`). Cross-station messages never appear for recipient.
- Resource-request dialog silently `pop()` on invalid input — no feedback.

**Implement:**
1. Add struct at top of `_CommsHubScreenState`:
```dart
class _RecipientOption {
  final String id; // 'hq_admin' or station id
  final String displayName;
  final String? stationId;
  const _RecipientOption({required this.id, required this.displayName, this.stationId});
}
```
2. Replace `String _selectedRecipient` + `List<String> recipients` in `_buildMessageComposer` with `List<_RecipientOption>`:
   - HQ: `hq_admin` + one option per station (`id: s.id`)
   - Staff: `hq_admin` + `getOtherStations(linkedStationId)` options
3. On transmit: `recipientId: opt.id`, `recipientName: opt.displayName`, `stationId: user?.linkedStationId`, `recipientStationId: opt.stationId`.
4. In `polar_data_service.dart:getMessagesForUser` — keep existing checks, ensure these two lines exist:
```dart
if (m.stationId == user.linkedStationId) return true;
if (m.recipientStationId == user.linkedStationId) return true;
if (m.recipientId == user.linkedStationId) return true;
```
5. In `_showCreateResourceRequestDialog` `SUBMIT`: if `itemCtrl.text.trim().isEmpty || qty<=0 || targetStationId==null`, show `SnackBar` / inline `Text` error instead of `pop()`.

**Verify:** Maitri staff → send to Bharati Ops → login as `sunita.deshmukh@bharati.ncpor.gov.in` → visible in dispatch log.

- [ ] `_RecipientOption` + transmit uses `id`/`recipientStationId`
- [ ] `getMessagesForUser` cross-station match verified
- [ ] Resource dialog validation feedback

## 2. Network Image Offline Fallbacks [CRASH-SAFETY]

**Problem:** `NetworkImage` with no error handler throws on satellite-link loss.

**Implement:**
- `lib/views/station_detail/station_detail_screen.dart:43` hero: `DecorationImage(..., onError: (_,__) {})` + wrap in `Stack` with fallback `Icon(Icons.terrain)` behind image.
- Same file personnel `CircleAvatar:291`: add `onBackgroundImageError: (_,__) {}` + `child: Icon(Icons.person)` fallback (use `foregroundImage` pattern or check `avatarUrl.isEmpty`).
- `lib/views/personnel/personnel_screen.dart:209` `TacticalAvatar` / `CircleAvatar`: same `onBackgroundImageError` guard. If `TacticalAvatar` lacks handler, add it there.
- `lib/views/command_center/hq_command_screen.dart:442` `_buildSectorCamCard`: add `onError: (_,__) {}` to `DecorationImage`.

- [ ] Station detail cam `onError`
- [ ] Avatars `onBackgroundImageError` + fallback icon
- [ ] HQ cam `onError`

## 3. User Context & Permission Enforcement in UI

**Problem:** UI calls mutations without `user`, bypassing audit + permission logs; alerts resolvable without context.

**Implement:**
- `lib/views/inventory/inventory_screen.dart`:
  - `final auth = context.watch<AuthService>(); final user = auth.currentUser;` in `build`.
  - `logConsumption(item.id, consumed, user: user)`, `addInventoryItem(item, user: user)`, `updateInventoryItem(updated, user: user)`, `deleteInventoryItem(item.id, user: user)`.
  - `_showLogUsageDialog`: `final err = Validators.validateConsumption(consumed, item.currentQuantity);` show inline `Text(err)` in dialog, block confirm if `err != null`.
  - `_showAddItemDialog`: `validateRequired(name)`, `validatePositiveNumber(qty/burn/thresh)` with inline errors.
- `lib/views/resupply/resupply_screen.dart`:
  - Watch `AuthService`, `canEdit = user?.canEditStation(station.id) ?? false`.
  - Hide `ADD MANIFEST PAYLOAD` button if `!canEdit`; guard `updateCargoStatus` tap with `canEdit`.
  - Change service signatures to `addCargoItem(cycleId, cargo, {UserProfile? user})` + `updateCargoStatus(..., {UserProfile? user})` with `canEditStation` check (see §4).
- `lib/views/command_center/hq_command_screen.dart:408`: `data.resolveAlert(alert.id, user: context.read<AuthService>().currentUser)`.
- `lib/views/station_detail/station_detail_screen.dart`: add resolve button in local-anomaly card (mirror HQ card) gated by `auth.hasPermission(Permission.resolveAlerts) && user.canEditStation(station.id)`.

- [ ] Inventory passes `user` + inline validation
- [ ] Resupply gated by `canEditStation`
- [ ] HQ resolve passes `user`
- [ ] Station detail local resolve button

## 4. Collection Safety + Cargo Guards

**File:** `lib/services/polar_data_service.dart`

**Already safe:** `selectedStation:44`, `deleteInventoryItem:248` (indexWhere), `deletePersonnel:321`, `getStationName:431`. Do NOT regress.

**Implement:**
```dart
void addCargoItem(String cycleId, CargoItem cargo, {UserProfile? user}) {
  final cycleIdx = _resupplyCycles.indexWhere((c) => c.id == cycleId);
  if (cycleIdx == -1) return;
  final cycle = _resupplyCycles[cycleIdx];
  if (user != null && !user.canEditStation(cycle.stationId)) return;
  if (cycle.cargoItems.any((i) => i.id == cargo.id)) return;
  _resupplyCycles[cycleIdx] = cycle.copyWith(cargoItems: [...cycle.cargoItems, cargo]);
  notifyListeners();
}
void updateCargoStatus(String cycleId, String cargoId, String newStatus, {UserProfile? user}) {
  final cycleIdx = _resupplyCycles.indexWhere((c) => c.id == cycleId);
  if (cycleIdx == -1) return;
  if (user != null && !user.canEditStation(_resupplyCycles[cycleIdx].stationId)) return;
  // ... existing index lookup
}
```

- [ ] `addCargoItem` duplicate + permission guard
- [ ] `updateCargoStatus` permission guard

## 5. Session Keep-Alive + Error Boundary

- `lib/views/main_layout_screen.dart:149`:
```dart
body: Listener(
  behavior: HitTestBehavior.translucent,
  onPointerDown: (_) => auth.touchSession(),
  child: IndexedStack(index: _currentTabIndex, children: screens),
),
```
- `lib/main.dart:9` in `main()` before `runApp`:
```dart
ErrorWidget.builder = (details) => MaterialApp(home: Scaffold(
  backgroundColor: AppColors.glacierInk,
  body: Center(child: Text('TACTICAL SYSTEM FAULT // ${details.exception}', style: TextStyle(color: Colors.white))),
)));
```

- [ ] `Listener.touchSession`
- [ ] `ErrorWidget.builder`

## 6. Verification
```powershell
& 'C:\Users\user\flutter\bin\flutter.bat' analyze
& 'C:\Users\user\flutter\bin\flutter.bat' test
```
- Extend `test/watney_calculator_test.dart`: cross-station routing, empty-station fallback, duplicate cargo rejection.
- Manual: §1 routing test, inventory negative/over-stock blocked, offline images no-crash, station staff local resolve.

## 7. NPDC Live Telemetry (DONE — production CORS path closed)

Added `lib/models/ncpor_reading.dart` + `lib/services/ncpor_data_source.dart`.
Reads `d1` JSON out of data.ncpor.res.in metric pages for maitri / bharati /
himadri; folds real temperature + wind over the seeds; shows provenance in
`station_selector_bar.dart` (`NCPOR LIVE` / `STALE` / `MOCK TELEMETRY`).
Polling starts in `main.dart` via `startNporPolling()`, **not** the
constructor, so tests stay offline. Attribution line added for the NPDC data
policy (Antarctic Treaty §III.1.c / IPY).

**Production CORS path — shipped.** `supabase/functions/npdc-proxy` is a
Deno Edge Function that fetches the portal server-side and returns it with
permissive CORS headers, because the portal answers OPTIONS with 200 but
sends no `Access-Control-*` at all. It is public and unauthenticated by
necessity (the browser has no Supabase session), so it allowlists exactly
one host — `data.ncpor.res.in` over https — and refuses everything else
with 403. It is not an open proxy.

The Flutter build bakes the function URL in at compile time:
```powershell
flutter build web --release --base-href /Aroha/ `
  --dart-define=NCPOR_PROXY=https://qznvgjsenqtdxoidnuht.supabase.co/functions/v1/npdc-proxy?url=
```

- [x] **Production CORS path** — Supabase Edge Function, replacing the
      loopback-only dev proxy.

`tool/ncpor_proxy.dart` remains useful for local work and is still
loopback-bound. **Never ship it.**

## 8. Light/Dark Theme (DONE — HARDENED)

- [x] Added semantic `AppThemeColors` theme extension for light/dark surfaces,
      text, borders, controls, status accents, and matching status foregrounds.
- [x] Replaced hard-coded dark UI colors across login, shared widgets, all
      authenticated screens, dialogs, and the satellite call room.
- [x] Centralized cargo, call-booking, and resource-request status colors.
- [x] Added a shared toggle to the login terminal and mission header.
- [x] First launch follows OS brightness; explicit user choice persists via
      `shared_preferences` with serialized writes.
- [x] Added `test/theme_provider_test.dart` covering system fallback,
      persistence, rapid toggles, status mappings, and `MaterialApp` switching.
- [x] Made the global error fallback theme-aware and aligned web/Android
      light/dark startup resources.

## 9. Verification

- [x] `flutter analyze`
- [x] `flutter test`
- [x] `flutter build web --release`

## Task List (copy to tracker)
- [x] 1. Comms recipient struct + routing + dialog validation
- [x] 2. Image `onError`/`onBackgroundImageError` fallbacks (3 screens — personnel already safe via TacticalAvatar)
- [x] 3. Inventory/Resupply/HQ/Detail user-context + permission gates
- [x] 4. Cargo duplicate + permission guards
- [x] 5. Keep-alive Listener + ErrorWidget
- [x] 6. analyze + test + manual checks
- [x] 7. NPDC telemetry: production CORS proxy (Supabase Edge Function)

## 10. Data Access — RLS lockdown APPLIED

All 11 tables shipped with one permissive `demo open access` policy
(`roles {anon,authenticated}`, `cmd ALL`, `qual true`, `with_check true`).
On web the publishable key is inside the JS bundle, so that granted full
read **and write** to anyone. The client-side guards in `lib/` are advisory
only — a caller can skip the UI and hit PostgREST directly.

`20260926000000_lock_down_demo_rls.sql` drops those policies and forces RLS
on every table. RLS with no permissive policy denies everything, so dropping
them *is* the lockdown.

Verified against the live project using the publishable key as `anon`:
`SELECT` returns `[]` on all 11 tables, `INSERT` returns `42501 new row
violates row-level security policy`, and `UPDATE`/`DELETE` affect 0 rows.
Forging a personnel medical clearance, or self-granting `consent_given` on a
family invite to walk into a call, is no longer possible over the network.

Consequence: cloud sync no longer works, by design. `PolarDataService` is
offline-first and falls back to local seed data, and the whole demo path
(family code `MTR-2026` -> `call_01`) is seeded locally, so the walkthrough
is unaffected.

Re-opening controlled access requires Supabase Auth plus a `profiles` table
first — see the tail of the migration file for the intended shape. Until
then, deny-all is the correct posture.

## 11. Two-party video media — NOT BUILT, and why

The call room is **local preview only**. There is no `RTCPeerConnection`, no
ICE exchange and no signaling anywhere in `lib/`. The room shows the user's
own camera via `getUserMedia` and says `REMOTE RELAY NOT CONFIGURED`. No
peer connection, recording or encryption is claimed.

A signaling relay was built and then removed. It is recorded here so the
same ground is not covered twice.

**Supabase Realtime is unavailable on this project.** The `realtime`
extension is not installed and there is no `realtime.messages` table, so
broadcast cannot be used for SDP/ICE exchange. This is a project-level
setting, not something SQL can change.

**Supabase Edge Functions cannot hold a WebSocket.** A `call-signal` Edge
Function was written, deployed and probed. The relay logic was correct —
authorisation resolved `AUTHORISED` for `MTR-2026` and `denied` for a wrong
code, and the upgrade handshake returned 101 with `readyState=OPEN`. But the
socket was then torn down immediately: a single-peer liveness probe
consistently showed `readyState=1`, then `readyState=3` with close code
**1006** (abnormal closure, no close frame) and zero messages received. The
connection does not survive long enough to relay anything. This is a
platform limitation, not a coding bug.

Three Deno-specific traps were hit and fixed along the way, worth knowing
if this is ever retried on a host that does support WebSockets:

1. `Deno.upgradeWebSocket()` must be reached **synchronously**. Awaiting the
   authorisation check first makes the gateway return **502** and the client
   reports "not upgraded to websocket". Fix: upgrade immediately, authorise
   afterwards, and gate *registration* rather than the upgrade.
2. A server-side `onopen` **never fires** — Deno returns the socket already
   open. Peers must register themselves directly after the upgrade.
3. A freshly upgraded socket can still report `readyState == CONNECTING`, so
   a `send()` that insists on `OPEN` silently drops the first message, which
   is the `hello` telling a peer who is already in the room.

**Viable hosts, if the media leg is ever wanted:** a Cloudflare Worker with
a Durable Object (free tier, native WebSocket support), a LiveKit Cloud free
tier (a complete WebRTC SFU, supplying signaling *and* TURN *and* media
routing, so the least code), or a small Node server on a cheap host. All
three need a new account.

**Framing constraint.** A browser-to-browser WebRTC session is *not* a
satellite link. Real polar crew reach family through a satellite operator's
media gateway; peer-to-peer media over the general Internet is a
ground-network simulation of that path. If this is ever built it must be
labelled as a simulation in the UI, because the current honest labels
(`REMOTE RELAY NOT DEPLOYED`, `DEMO CHANNEL — NO E2E SIGNALING`) are the
thing keeping the project's claims defensible.

The authorisation and consent gate around the call — two-party clearance,
invite binding, non-overwritable signatures, station scoping, fail-closed
service guards — is complete and is the part worth demonstrating.
