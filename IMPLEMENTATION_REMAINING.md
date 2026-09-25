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

## 7. NPDC Live Telemetry (DONE — one deployment item open)

Added `lib/models/ncpor_reading.dart` + `lib/services/ncpor_data_source.dart`.
Reads `d1` JSON out of data.ncpor.res.in metric pages for maitri / bharati /
himadri; folds real temperature + wind over the seeds; shows provenance in
`station_selector_bar.dart` (`NCPOR LIVE` / `STALE` / `MOCK TELEMETRY`).
Polling starts in `main.dart` via `startNporPolling()`, **not** the
constructor, so tests stay offline. Attribution line added for the NPDC data
policy (Antarctic Treaty §III.1.c / IPY).

Dev run (web needs the CORS proxy — the portal sends no `Access-Control-*`):
```powershell
& 'C:\Users\user\flutter\bin\dart.bat' run tool\ncpor_proxy.dart   # 127.0.0.1:8100
& 'C:\Users\user\flutter\bin\flutter.bat' run -d web-server --web-port 8099 --web-hostname 127.0.0.1 `
  --dart-define=NCPOR_PROXY=http://127.0.0.1:8100/?url=
& 'C:\Users\user\flutter\bin\dart.bat' run tool\ncpor_smoke.dart    # connectivity check
```

- [ ] **Production CORS path** — `tool/ncpor_proxy.dart` is loopback-only dev
      scaffolding. For a deployed build, move the fetch server-side into a
      Supabase Edge Function (project already uses Supabase) and point
      `NCPOR_PROXY` at it. Never ship the loopback proxy.

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
- [ ] 7. NPDC telemetry: production CORS proxy (Supabase Edge Function)
