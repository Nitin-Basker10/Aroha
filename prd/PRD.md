# AROHA — Polar Expedition Logistics & Command
### Product Requirements Document (PRD) + Workflow Guide
`OPS-v4.2 // NCPOR | SIH26062 | App: aroha_polar 1.0.0+1 (Flutter, Dart ^3.11.5)`

This is the single easy-read reference for what the app does, who uses it, and how each workflow runs in code.

---

## 1. What it is

Command app for India's polar program (NCPOR Goa HQ + 3 field outposts). Replaces spreadsheets/radio logs with one tactical dark UI for inventory survival forecasting, station telemetry, crew roster, resupply cargo, and satellite comms.

**Stations (seeded):**

| Station | Code | Location | Resupply in | Status |
|---|---|---|---|---|
| Maitri Station | MTR-01 | Schirmacher Oasis, Antarctica | ~114d | active |
| Bharati Station | BHR-02 | Larsemann Hills, Antarctica | ~82d | active |
| Himadri Arctic Station | HMD-03 | Ny-Ålesund, Svalbard | ~45d | low-connectivity |

**Tech:** Flutter Material3, `provider` (`PolarDataService` + `AuthService`), `google_fonts` (IBM Plex Sans + JetBrains Mono), `uuid`, `intl`. No backend — all state is in-memory mock in `lib/services/polar_data_service.dart`. Firestore helpers (`toFirestore/fromMap`) exist on every model for future backend swap.

---

## 2. Who uses it (roles)

| Capability | HQ Admin (Goa) | Station Staff (crew) |
|---|---|---|
| See stations | All 3, switchable | Own station only, locked (`station_selector_bar.dart:23`) |
| Command Center tab | Yes | No |
| Station / Inventory / Resupply / Personnel / Comms | All stations | Own station only |
| Edit inventory / crew / cargo | Any station | Own station only (`canEditStation`) |
| View blood group / emergency contact | Yes | Own station only (`canViewMedical`) |
| Resolve alerts | Any station | Own station only |
| Message HQ / other stations | Yes | Yes |
| Cross-station resource requests | View all | Send + approve/deny incoming |

Family portal was **removed** — HQ contacts families outside the app.

**Demo logins (mock only):**

| Role | Email | Key |
|---|---|---|
| HQ | `nitin.verma@ncpor.res.in` | `admin@ncpor2026` |
| HQ | `ritu.kapoor@ncpor.res.in` | `ops@ncpor2026` |
| Maitri | `aarav.sharma@maitri.ncpor.gov.in` | `maitri@2026` |
| Maitri | `rajesh.varma@maitri.ncpor.gov.in` | `maitri@2026` |
| Bharati | `sunita.deshmukh@bharati.ncpor.gov.in` | `bharati@2026` |
| Himadri | `alok.sengupta@himadri.ncpor.gov.in` | `himadri@2026` |

---

## 3. App flow (start to finish)

```
main.dart → RootNavigationCoordinator
  ├─ not authed → LoginRouterScreen (pick HQ / Research Center → email+key → AuthService.login)
  └─ authed → MainLayoutScreen (TacticalHeader + role-filtered tabs + CustomNavBar)
       ├─ HQ: HQ Command, Station View, Inventory, Resupply, Personnel, Comms
       └─ Staff: Station View, Inventory, Resupply, Personnel, Comms (locked to linkedStationId)
```

- Session: 30-min inactivity auto-logout (`auth_service.dart:14`). Any tap resets timer via `Listener` in `main_layout_screen.dart`.
- Crash safety: tactical `ErrorWidget.builder` in `main.dart`.
- Theme: semantic light/dark Material 3 themes built from the glacier-ink / pack-ice dark palette and warm light surfaces; first launch follows the OS brightness, the header/login control switches modes, and the explicit choice persists across restarts. Status accents use mode-specific foreground roles, including cargo, call, and resource-request states (`app_colors.dart`, `app_theme.dart`, `theme_provider.dart`).

---

## 4. Core engine — Mark Watney survival forecast

**Formula:** `daysRemaining = currentQuantity / dailyConsumptionRate` (`inventory_item.dart:31`, `watney_calculator.dart:12`). Guards: zero/negative/NaN burn → `999d`; zero stock → `0d`.

**Risk levels** (`watney_calculator.dart:21`):

| Level | Condition |
|---|---|
| critical | `qty<=0` OR `days < 40% of resupply gap` OR `qty <= 50% of threshold` |
| warning | `days < resupply gap` OR `qty <= threshold` |
| nominal | otherwise |

**Engine loop:** any inventory add/update/consume → `recalculateAllWatneyAlerts()` wipes `watney_*` alerts and regenerates per station (`polar_data_service.dart:278`). Manual alerts (e.g. SAT-link loss) are kept.

**Live examples in seed data:** Maitri diesel 4200L / 48L-day = 87.5d < 114d gap → critical; Himadri kerosene 34d < 45d → alert; Maitri oxygen 8 < 12 threshold → warning.

---

## 5. Workflows (how to use each screen)

### A. HQ Command Center (`hq_command_screen.dart`)
HQ-only overview. Telemetry cards (outposts, crew on-station, alert count) → sector cam cards (tap jumps to station) → per-station diagnostics (resupply window, power, temp, wind + at-risk bar → jump to Inventory) → alert feed (top 5, acknowledge button passes `user`).
*Workflow:* spot red station → `OPEN STATION TELEMETRY` or `VIEW RISK` → act in Station/Inventory.

### B. Station Detail (`station_detail_screen.dart`)
Hero cam (offline-safe `onError`), power/temp/wind cards, life-support pods (HVAC, RO water, oxygen manifold, VSAT), local anomalies with **acknowledge button**, crew preview → `MANAGE ROSTER`, shortcuts `LOG CONSUMPTION` / `DISPATCH COMMS`.

### C. Inventory (`inventory_screen.dart`)
Watney explainer banner → search + category chips → item cards (reserve, burn rate, projected runout, ±buffer vs gap, notes) → actions:
- **Log consumption:** validates `>0`, `≤ stock`, finite (`validators.dart:6`); writes `InventoryAuditLog` + recalculates Watney.
- **Calibrate:** edit reserve/burn/threshold or delete (all pass `user`, permission-checked).
- **New item:** validates name/quantity/burn/threshold; duplicate-ID blocked.

### D. Resupply (`resupply_screen.dart`)
Cycles filtered by selected station (Golovnin voyages, ETA, payload tons) → cargo manifest with status popup (`pending/packed/shipped/delivered`). Add/status actions hidden or blocked unless `canEditStation`. All mutations pass `user`; duplicate cargo IDs rejected.

### E. Personnel (`personnel_screen.dart`)
Roster count / med-clearance / on-duty cards → search + role chips → crew cards (deployment days, blood group, med-clearance, emergency contact — last two show `RESTRICTED` unless `canViewMedical`). `ENROLL CREW` (station-editable only) validates name, writes with `user`.

### F. Comms Hub (`comms_hub_screen.dart`)
Three stacked workflows:
1. **Resource requests:** station staff `REQUEST SUPPLIES` (target station, item, qty, urgency) with validation feedback; incoming pending requests show `APPROVE/DENY` + response notes; HQ sees all.
2. **Satellite dispatch:** recipient dropdown uses structured `_RecipientOption(id)` — `hq_admin` or station ID — so cross-station mail routes via `recipientStationId`/`recipientId` and appears in the recipient's feed (`getMessagesForUser`). Priority chips routine/urgent/emergency, AES-256 label, empty-message blocked.
3. **Call bookings + log:** reserve sat-voice/low-res-video slots; message log shows NEW badges, filtered per user (HQ sees all, staff sees own-station threads).

---

## 6. Data model map

| Model | Key fields | Service behavior |
|---|---|---|
| `Station` | status, power, temp, wind, satLink, nextResupplyDate, `daysUntilResupply`, `isNominal` | selected via selector; personnel count auto-recounted |
| `InventoryItem` | stationId, category, qty, unit, burnRate, threshold, `daysRemaining`, `isAtRisk/isCritical` | CRUD + audit + Watney recalc, permission-gated |
| `Personnel` | stationId, role, specialization, status, blood, emergency, medCleared | CRUD, duplicate-blocked, med-gated |
| `ResupplyCycle` + `CargoItem` | vessel, expeditionCode, ports, ETA, cargo list, `totalPayloadWeightKg` | cargo add/status gated + deduped |
| `AlertItem` | stationId, type, severity, message, resolved, itemId | Watney-generated (`watney_*`) + manual; resolve needs `resolveAlerts` + station edit |
| `CommsMessage` | sender/recipient IDs + names, stationId, recipientStationId, priority, read | scoped by `getMessagesForUser` |
| `CallBooking` | stationId, person, family contact, slot, duration, channel | insert + status update |
| `ResourceRequest` | from/to stations, item, qty, urgency, status, notes | create + approve/deny with responder stamp |
| `InventoryAuditLog` | item, action (create/update/consumption/delete), old→new, who/when | prepended on every mutation |
| `UserProfile` / `UserRole` / `Permission` | role, linkedStationId, linkedPersonId, `canAccess/canEdit/canViewMedical` | 2 roles × 15 permissions |

---

## 7. Permissions & safety rules (enforced)

- Mutations without rights return `false` / no-op (service layer), UI hides or blocks buttons (resupply add, personnel enroll).
- Medical data masked unless `canViewMedical`.
- Inventory inputs validated service-side **and** dialog-side.
- Empty stations → fallback `unknown` station (no `StateError`); deletes use `indexWhere`; cargo deduped.
- Images offline-safe (`onError` / `TacticalAvatar errorBuilder` with initials fallback).
- `flutter analyze`: clean. `flutter test`: Watney math + zero-burn + seed + auth pass.

---

## 8. Run & verify

```powershell
cd C:\Users\user\sih_polar
& 'C:\Users\user\flutter\bin\flutter.bat' pub get
& 'C:\Users\user\flutter\bin\flutter.bat' analyze
& 'C:\Users\user\flutter\bin\flutter.bat' test
& 'C:\Users\user\flutter\bin\flutter.bat' run -d web-server --web-port 8099 --web-hostname 127.0.0.1
# open http://127.0.0.1:8099
```

**Manual checks:** (1) Maitri → message Bharati Ops → login Bharati → appears. (2) Inventory log negative/over-stock → blocked with error. (3) Break network → cams/avatars show fallback, no crash. (4) Staff resolves own-station alert from Station Detail. (5) Staff cannot switch stations; HQ can. (6) Toggle light/dark from both the login terminal and mission header; all cards, dialogs, inputs, menus, and the call room remain readable; the choice survives an app restart.

---

## 9. Known limits / next steps

- In-memory only — restart wipes changes; wire `toFirestore/fromMap` to Firebase when ready.
- Telemetry/cam URLs are static Unsplash mocks; replace with live feeds + `FadeInImage` assets.
- No pagination, no push notifications, no offline queue — add for field use.
- Passwords are demo hashes (`user_credentials.dart:110`) — replace with Firebase Auth/bcrypt.

---

## 10. Notifications (`notification_service.dart`)

Two layers, both driven by a watcher in `main_layout_screen.dart` that diffs
critical-alert / message / resource-request IDs on every data change:

1. **In-app feed** — always works (including web). Bell icon in
   `TacticalHeader` shows unread badge; tapping opens the alert inbox
   (per-item acknowledge, MARK ALL READ).
2. **OS banner** — `flutter_local_notifications ^22.3.1`, best-effort and
   fully guarded (tests/web never crash). New critical alerts also fire a
   red heads-up `SnackBar`.

Triggers: new critical Watney/manual alert on an accessible station,
incoming dispatch not sent by you, new/updated resource request involving
your station (HQ: all). Duplicate IDs ignored so recalculation loops can't
spam. Web permission is requested only from the inbox's ENABLE OS ALERTS
button (browser requirement: user gesture).

---

## 11. Family portal — invite-only, own-slot scope (confidentiality)

Research stays confidential: families never see telemetry, inventory,
roster or other slots. Access is by HQ/crew-issued invite code only.

**Flow:**
1. Crew/HQ books a satellite slot in Comms (voice or low-res video).
2. HQ or station editor taps INVITE FAMILY on the booking → short code
   (e.g. `MTR-2026`, `FamilyInvite.makeCode`) shown for out-of-band sharing.
3. Family opens FAMILY CALL ACCESS terminal → enters code → scoped
   `familyMember` session (`accessFamilyPortal` only; `canEditStation`
   hard-returns false for family).
4. Family sees: crew name, slot, duration, channel + briefing
   (monitored govt link, no research talk) + consent checkboxes
   (recording consent under DPDP Act 2023, briefing ack).
5. JOIN unlocks after consent → `confirmFamilyConsent` mirrors
   consent/briefing onto the booking for the HQ audit trail.

**Dual disclaimer gates (both mandatory):**
- Family: entry disclaimer screen blocks the portal until any typed name
  + read-box ticked (`acceptFamilyDisclaimer`; empty/unticked rejected,
  name recorded for audit).
- Crew: each booking shows CREW DISCLAIMER PENDING/SIGNED; station-side
  signatory types their name + ticks acceptance (`signCrewDisclaimer`,
  station-edit rights required). Crew/HQ JOIN stays disabled until signed.

**Calls:** `VideoCallScreen` (flutter_webrtc) — local preview, mic/cam
controls, call timer vs allotted minutes, REC banner + monitored-link
strip. **Local preview only in this build:** there is no `RTCPeerConnection`,
ICE, SDP, or signaling anywhere in `lib/`, so the room shows only the
user's own camera and states `REMOTE RELAY NOT CONFIGURED` /
`CALL COMPLIANCE GATE ACTIVE — REMOTE RELAY NOT DEPLOYED IN THIS MVP`.
No peer connection, recording, or encryption is claimed or implied. A
genuine remote leg needs a signaling channel and TURN/relay, which is
separate work. Voice bookings run in voice mode. Android camera/mic
permissions are in `AndroidManifest.xml`; iOS needs
`NSCameraUsageDescription` / `NSMicrophoneUsageDescription` when the iOS
folder is added.

**Demo:** family code `MTR-2026` → Priya Sharma → call_01.

---

## 12. Backend — Supabase (live, offline-first)

Project `qznvgjsenqtdxoidnuht`, wired via MCP. 11 tables mirroring
`lib/models/*` (migration `aroha_initial_schema`), RLS on with
demo-open anon policies until Supabase Auth replaces mock logins.

**Client layers:**
- `supabase_service.dart` — URL + publishable key only (`--dart-define`
  overrides), guarded `init()`, `clientOrNull` null when offline.
- `supabase_repository.dart` — snake_case row mappers + CRUD per table,
  realtime channel `aroha_ops` on alerts/messages/resource_requests.
  Watney-derived alerts (`watney_*`) are never persisted.

**Sync (`polar_data_service.dart`):**
- Boot: `syncFromCloud()` retries backend readiness, pulls cloud state
  when stations exist, else pushes local seeds as first-run bootstrap,
  then subscribes to realtime and merges new ids (request rows updated
  in place — HQ-moderated by design).
- Every mutation write-throughs best-effort (`unawaited`, try/catch
  inside repo): inventory/personnel/cargo/messages/bookings/requests/
  alerts/invites/consents/disclaimers + audit-log inserts.
- Verified: anon REST read returns all 3 stations through RLS.

---

## 13. Logic audit fixes (permissions + join clearance)

Full pass over every mutation and join path:
- Room opens only on mutual clearance: crew disclaimer + family
  consent + booked/live status — enforced on crew JOIN, HQ JOIN and
  family JOIN alike (`_isJoinable`, family `joinable`).
- `canAccessStation` / `getMessagesForUser` hard-return false/empty
  for family sessions (invite scope only, no station traffic).
- `canEditStation` already false for non-staff; service mutations now
  all take `user` and enforce it: `sendMessage` (sendMessages perm),
  `bookCallSlot`, `updateBookingStatus`, `createResourceRequest`
  (from-station), `respondToResourceRequest` (to-station). UI passes
  `auth.currentUser` and shows denial SnackBars.
- `createFamilyInvite` only for booked/live slots.
- `confirmFamilyConsent` requires the signed entry disclaimer first.
- `signCrewDisclaimer`: station staff must own the booking
  (`linkedPersonId == personId`); HQ may countersign (oversight).
- Pull sync never wipes local lists with empty cloud tables
  (the bug that emptied inventory after manual station seeding).
