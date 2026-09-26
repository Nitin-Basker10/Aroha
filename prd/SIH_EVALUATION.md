# AROHA — SIH Evaluation Content
### Tech Stack · Methodology · Feasibility · Viability · Impact · Benefits
### Written for: **Resource** · **Industrial** · **Entrepreneur** panels

> All figures marked **[measured]** were taken from this repository or the live
> project. Figures marked **[estimate]** are explicitly reasoned assumptions,
> not measurements — a technical judge will ask, so they are labelled.
>
> This document is the appendix to `SIH_PRESENTATION.md`, not a replacement.
> It carries the depth; the deck carries the story.

---

## 1. Tech Stack

### 1.1 Layered view

| Layer | Technology | Version / detail |
|---|---|---|
| **Client** | Flutter (Dart) | 3.41.7 · Dart 3.11.5 **[measured]** |
| **UI** | Material 3 + custom semantic theme | Light/dark, contrast-tested |
| **State** | `provider` + `ChangeNotifier` | `PolarDataService`, `AuthService`, `NotificationService`, `ThemeProvider` |
| **Backend** | Supabase (Postgres + Edge Functions) | Project `qznvgjsenqtdxoidnuht` |
| **Realtime media** | `flutter_webrtc` | Dependency present; **peer connection not built** |
| **Networking** | `http` + `flutter_web_plugins` | 13 direct dependencies **[measured]** |
| **Persistence** | `shared_preferences` | Explicit light/dark choice |
| **Telemetry** | Custom HTML scraper | Reads `d1` JSON from `data.ncpor.res.in` |
| **Hosting** | GitHub Pages via Actions | Zero-cost, auto-deploy on push |
| **Tests** | `flutter_test` | 92 tests **[measured]** |

### 1.2 Why these choices

| Decision | Rationale |
|---|---|
| **Flutter (one codebase)** | Web + Android + Windows from one codebase. Field tablets and HQ desktops differ; the tactical UI ships to both. |
| **Offline-first** | The app must boot and run with the backend unreachable. Over a metered, high-latency link, "no network" is the normal case, not the exception. |
| **Supabase (not Firebase)** | **Data sovereignty.** Personnel medical data and station positions stay in an Indian government project, not a foreign SaaS. The PRD names Firestore helpers on every model, so swapping later is a mapping exercise. |
| **Postgres + RLS** | Authorization belongs in the database, not the client. A client-side check is one refactor from being bypassed. |
| **Edge Functions** | Solves CORS server-side and keeps the loopback dev proxy out of production. Also the only place `SUPABASE_SERVICE_ROLE_KEY` exists. |
| **Service-layer guards** | Every mutation validates server-of-record-side, so enforcement is independent of UI path. |

### 1.3 Codebase metrics **[measured]**

| Metric | Value |
|---|---|
| Dart source files (`lib/`) | 47 |
| Lines of application code | **13,628** |
| Test files | 10 |
| Lines of test code | **2,269** |
| Automated tests | **92** |
| Screens / widgets | 17 files |
| Data models | 15 |
| Service classes | 6 |
| Core utilities | 8 |
| Declared permissions | 13 |
| Direct dependencies | 13 |
| Backend tables | 11 |
| Permissive RLS policies | **0** |
| Third-party services required to run | **0** |

**Licensing cost: $0.** Every dependency is BSD/MIT/Apache-licensed. No paid
tier, no per-seat licence, no vendor lock-in.

### 1.4 Test distribution **[measured]**

| Suite | Tests | Focus |
|---|---|---|
| `ncpor_data_source_test.dart` | 23 | Telemetry parsing, per-station quirks, staleness |
| `call_access_test.dart` | 13 | Call authorization policy |
| `call_flow_test.dart` | 10 | End-to-end consent gate through the real UI |
| `family_invite_test.dart` | 11 | Invite binding and signature integrity |
| `responsive_layout_test.dart` | 8 | Every screen at 412px |
| `watney_calculator_test.dart` | 5 | Forecast + divide-by-zero guards |
| `supabase_repository_test.dart` | 5 | Row mappers, nullable compliance columns |
| `notification_service_test.dart` | 5 | Dedup, unread counts, no-plugin safety |
| `theme_provider_test.dart` | 11 | Contrast, persistence, serialization |
| `widget_test.dart` | 1 | Smoke |

---

## 2. Methodology

The methodology is the differentiator. Three principles, applied consistently.

### 2.1 Fail closed

The default answer to any ambiguous authorization question is **refusal**.

| Situation | Behaviour |
|---|---|
| No session | Mutation refused |
| Unknown role in a cloud payload | **Throws** — never falls back to HQ admin |
| Wrong station | Refused |
| Record already signed | Re-signing refused |
| Consent already recorded | Re-granting refused |
| Terminal booking (`completed`/`cancelled`) | Reopening refused |
| Guest role | `canAccessStation` and `canEditStation` both hard-coded `false` |

**Validated, not asserted.** `call_flow_test.dart` proves a second crew member
cannot sign someone else's booking, that consent is one-way, and that a
family session cannot forge another family's consent — by exercising the real
service, not by inspecting a flag.

### 2.2 Policy as a single source of truth

`lib/core/utils/call_access.dart` defines the call policy once. The UI and the
service layer both consult it, so a cleared button is never the only thing
standing between a user and a call room.

### 2.3 Verify the attack, don't read the config

The RLS lockdown was validated by **issuing real anonymous requests** against
the live project with the publishable key — not by reading `pg_policies`.

| Attack | Response |
|---|---|
| `SELECT` personnel / invites / bookings / stations / inventory | `200 []` — zero rows |
| `INSERT` forged crew medical clearance | `401` — `42501 new row violates row-level security policy` |
| `PATCH` invite → `consent_given: true` | `200 []` — 0 rows affected |
| `DELETE` station | `200 []` — 0 rows affected |

This is the methodology point: **a security control that has not been attacked
has not been tested.**

---

## 3. Feasibility

### 3.1 What is proven, by evidence

| Capability | Evidence | Status |
|---|---|---|
| Survival forecasting | Unit-tested incl. zero/negative/NaN burn | **Proven** |
| Role & station scoping | Service-layer tests per role | **Proven** |
| Two-party consent gate | 10 end-to-end UI tests | **Proven** |
| Live NPDC telemetry | 11/11 endpoints return 200 through the Edge Function | **Proven** |
| Host-allowlist on the proxy | 4 attack classes → `403` | **Proven** |
| RLS lockdown | 4 attack classes → blocked | **Proven** |
| Responsive layout | 8 screens at 412px, enforced by test | **Proven** |
| Offline-first operation | Whole demo runs with no backend | **Proven** |
| Public deployment | Live, auto-deploying | **Proven** |
| **Satellite media leg** | No `RTCPeerConnection`/ICE/signaling in `lib/` | **NOT BUILT** |
| **Real authentication** | Demo role picker; no Supabase Auth | **NOT BUILT** |
| **Cloud sync** | RLS locked → app runs on local seed data | **OFF BY DESIGN** |

### 3.2 Measured performance **[measured]**

| Metric | Value |
|---|---|
| Telemetry proxy latency (5 samples) | 911 / 978 / 1056 / 1171 / 1497 ms — **median ≈ 1.06 s** |
| Payload per endpoint | 80 KB – 564 KB (HTML pages, scraped) |
| Payload for one full 11-endpoint poll | **≈ 2.40 MB** |
| Cold-start behaviour | App unaffected; telemetry degrades to labelled fallback |
| Security check response | < 200 ms (all four attacks) |
| Web cold load | ~28.6 MB served, `main.dart.js` 2.94 MB |

### 3.3 The one number that matters to a resource panel

**A full telemetry poll costs ≈ 2.40 MB**, because the app fetches 11 HTML
pages and scrapes them client-side.

Over a real metered Iridium/VSAT link that is the dominant operating cost of
the whole system. At hourly polling it is **≈ 1.7 GB/month per station**;
across 3 stations, **≈ 5.2 GB/month**. **[estimate — extrapolated from the
measured 2.40 MB]**

**The fix is small and already 80% designed:** move the extraction into the
Edge Function and return ~2 KB of JSON per station instead of 85–564 KB of
HTML. That is a ~**100× payload reduction** **[estimate]**, turning ~5.2 GB/month
into roughly ~50 MB/month, and it also removes scraping fragility from the
client. The Function already fetches the page; it only needs to parse before
responding. `Cache-Control: max-age=300` is already set.

**This is stated as a known inefficiency with a known fix, not hidden.** A
resource panel will find it; better that we found it first.

### 3.4 Deployment feasibility

| Item | Cost | Note |
|---|---|---|
| Hosting | **$0** | GitHub Pages, static |
| Database | **$0** | Supabase free tier covers 3 stations |
| Edge Functions | **$0** | 2 functions, low volume |
| Media relay (TURN) | **$0–5/mo** | Not needed for a same-network demo |
| Device | Any tablet / laptop | Web build runs in a browser |
| **Total to pilot** | **≈ $0** | **[estimate]**, excluding staff time |

**Staff time to build: ~13.6k lines of Dart + 2.3k lines of tests [measured].**
A single competent Flutter developer delivered a deployable pilot.

---

## 4. Viability

### 4.1 Sustainability

| Question | Answer |
|---|---|
| **Vendor lock-in?** | Low. Postgres + Dart. Swapping Supabase means rewriting one repository class (`supabase_repository.dart`) — row mappers are already isolated and unit-tested. |
| **Does it still work if Supabase disappears?** | **Yes.** Offline-first; the app runs entirely on local seed data. That was a deliberate architectural choice, and it is also the disaster-recovery plan. |
| **Can a non-specialist maintain it?** | Partly. The risk is concentrated in `polar_data_service.dart` (the largest file) and the call-authorization policy. Both are the most heavily tested code in the repo. |
| **Operational burden** | Low. No servers to operate, no on-call, no database to patch. Static hosting + managed Postgres. |
| **Long-term data format** | Plain Postgres tables, snake_case, documented. No proprietary serialization. |

### 4.2 The viability trade-off we made deliberately

Cloud sync is **off** because there is no authentication system. Any RLS
policy that filters by identity would deny every caller, so **deny-all is the
only safe posture until identity exists**.

Cost of that decision: no cross-device sync.
Benefit: no unauthenticated write access to personnel medical data, invite
codes and consent flags.

**This is a sequencing decision, not a permanent state.** Supabase Auth + a
`profiles` table converts the lockdown into scoped policies without touching
application code.

### 4.3 Business viability

**Revenue model: not the point — but the cost argument is strong.**

This is an Indian government programme. The defensible commercial argument is
**cost avoidance and risk reduction**, not market capture:

- One prevented stockout of medical oxygen or survival ration at a remote
  station is a mission-costing event. Resupply cannot be accelerated — the
  ship sails annually.
- NCPOR already operates the stations; there is **no new operator to onboard**.
  Deployment is a single web link per station.
- The software is **$0 to license**. The economic argument is entirely about
  avoided loss, not license cost.

**Expansion path, in order of realism:**

1. **More stations.** The model is station-scoped by `station_id` throughout.
   Adding a fourth station is a data row, not a code change.
2. **Adjacent Indian research infrastructure.** NDRI/DA-IICT, Antarctic
   logistics contractors, DRDO field deployments — same offline-first,
   low-bandwidth problem shape.
3. **Other polar programmes.** Territorial claims make data-sharing sensitive,
   which makes a sovereignty-preserving tool more valuable, not less.
4. **Commercial Antarctic operators.** Tourism/logistics operators face the
   identical resupply-survival problem with worse information.

**Market sizing: deliberately not fabricated.** A specific TAM figure for a
3-station national programme would be indefensible, and an entrepreneur panel
respects a stated assumption more than an invented number. If pressed:
*"The addressable market is small by station count and large by mission cost.
The right metric is cost-per-avoided-stockout, not user count."*

---

## 5. Impact

### 5.1 Quantitative

| Indicator | Value | Basis |
|---|---|---|
| Stations under management | 3 | Maitri, Bharati, Himadri |
| Telemetry parameters per station | 4 (temp, wind, pressure, humidity) | **[measured]** — 11 endpoints total, Himadri publishes no wind sensor |
| Telemetry refresh | 60 s polling | Configured |
| Risk states surfaced per item | 3 (nominal / warning / critical) | — |
| Data points fetched per poll cycle | 11 | **[measured]** |
| Personnel medical fields protected from anon access | 4 (blood group, emergency contact, medical clearance, role) | Schema |
| Tables under enforced RLS | 11 / 11 | **[measured]** |
| Permissive policies remaining | **0** | **[measured]** |
| Anonymised attack classes blocked | 4 (read / insert / update / delete) | **[measured]** |
| Automated tests | 92 | **[measured]** |
| Screens verified at handset width | 8 | **[measured]** |
| Handset overflows fixed | 12 across 7 screens | **[measured]** |
| Third-party runtime dependencies | **0** | **[measured]** |
| Licensing cost | **$0** | **[measured]** |

### 5.2 Qualitative — per stakeholder

**The crew (Maitri/Bharati/Himadri)**
- Knows days-of-survival, not spreadsheet cells — the difference between
  "we have oxygen" and "we have 34 days of oxygen, ship in 114"
- The family call is a **governed, consented event** rather than an open
  channel — auditable after the fact
- Research confidentiality is enforced by the briefing and the portal
  scoping, supporting the Antarctic Treaty §III.1.c obligation

**HQ (Goa)**
- One view across 3 stations instead of 3 spreadsheets and radio logs
- Alerts carry an owner and a resolution trail; resolution requires a
  permission check and a user context
- Reduced dependence on scheduled radio contact over a 18–20 h delay

**The organisation (NCPOR)**
- Personnel medical data no longer anonymously readable or writable by
  anyone holding a public key
- Data resident in an Indian government cloud project — sovereignty, not a
  checkbox
- Audit trail on consent and disclaimer events, immutable once recorded

**The family**
- A scheduled, consented, private window with a relative at a polar station
- Sees **only** their own slot — no roster, no telemetry, no research
- Can withdraw nothing and re-consent nothing, because consent is one-way

---

## 6. Benefits

### 6.1 By stakeholder

| Stakeholder | Benefit | Quantified where possible |
|---|---|---|
| Crew | Survival visibility; governed family contact | Days-of-survival per item, refreshed 60 s |
| HQ | Cross-station situational awareness | 3 stations, 11 telemetry points, 1 view |
| NCPOR | Data sovereignty + access control | 11/11 tables locked, 0 open policies |
| Maintenance team | Testable, swappable backend | 92 tests; 1 repository class to swap |
| Finance | No licence cost | $0 |
| Family | Privacy-preserving contact | 1 slot, 0 station data |

### 6.2 Non-functional benefits

| Property | Evidence |
|---|---|
| **Resilience** | Runs fully offline; backend loss is a labelled degradation, not an outage |
| **Security** | Authorization in the data layer, fail-closed, attack-verified |
| **Accessibility** | Semantic light/dark themes with contrast pairs verified in both modes |
| **Usability on a handset** | 8 screens regression-tested at 412px |
| **Deployability** | Auto-deploy on push; ~30 s web build |
| **Observability** | Provenance shown per station — `NCPOR LIVE` / `STALE` / `MOCK` |

---

## 7. Panel-Specific Angles

### 7.1 For the **Resource** panel

Lead with: **what it costs to run, and what it costs not to.**

- **$0 licence, $0 hosting, $0 database** at pilot scale. 13.6k lines of Dart
  delivered the pilot.
- **The dominant runtime cost is telemetry payload: 2.40 MB per full poll
  cycle ≈ 5.2 GB/month across 3 stations at hourly polling [estimate].**
  Server-side extraction in the Edge Function cuts this ~100× **[estimate]**.
  We found this ourselves; it is the first thing on the optimisation list.
- **Resource saved:** manual reconciliation of 3 spreadsheets, and radio
  round-trips on a 18–20 h link.
- **Resource protected:** medical oxygen, survival ration and fuel — items
  that cannot be resupplied on demand.
- **Lowest-risk deployment:** static site, managed Postgres, no servers to
  operate, no on-call rotation.

**Anticipated question — "how do you know 2.40 MB is right?"**
Answer: measured. Each of the 11 endpoints was fetched through the production
Edge Function and its `Content-Length` recorded; they sum to 2,402,336 bytes.
The figure is reproducible via `tool/ncpor_smoke.dart`.

### 7.2 For the **Industrial** panel

Lead with: **it fits an existing operation and does not replace it.**

- **No new operator to onboard.** NCPOR already runs the stations. Delivery
  is a URL per station.
- **Standards-aware:** station-scoped by `station_id` throughout; research
  confidentiality aligned to Antarctic Treaty §III.1.c; attribution line
  included for the NCPOR data policy.
- **Works on the link that exists.** Offline-first and low-bandwidth by
  design, because a metered satellite link is the normal case.
- **Honest about integration limits:** the NPDC portal sends no CORS headers
  at all, so a server-side proxy is *mandatory*, not optional. We built it and
  host-allowlisted it.
- **Honest about the media leg:** no satellite call is possible. A real path
  needs a satellite operator's media gateway — an integration with a telecom
  provider, not a code change we could ship.
- **Integration seam:** `supabase_repository.dart` isolates all row mapping.
  Swapping the backend touches one class.

**Anticipated question — "why not just use WhatsApp/email for family calls?"**
Answer: neither can produce a consent trail, bind a call to a verified
relative, or prevent one crew member from signing away another's consent. The
value is the compliance record, not the video.

### 7.3 For the **Entrepreneur** panel

Lead with: **the defensibility and the sequencing.**

- **Sovereignty is the moat.** A foreign SaaS cannot be used for Indian
  polar personnel data. That constraint *is* the market — it excludes
  global competitors by default.
- **Zero marginal cost of distribution.** Static hosting; adding a station is
  a data row, not a deployment.
- **The defensible asset is the policy layer**, not the UI: the consent model
  (immutable signatures, one-way consent, invite binding) is the hard part to
  copy, and it is already tested.
- **Deliberate sequencing:** we shipped deny-all RLS before authentication
  rather than shipping wide-open access for convenience. That is a
  cost-now / risk-later trade **we chose to make**, and it is reversible by
  adding Auth.
- **Expansion:** more stations → adjacent Indian research infrastructure →
  other national polar programmes → commercial Antarctic operators, who face
  the same survival problem with worse information.

**Anticipated question — "what's your TAM?"**
Answer: *"Small by user count, large by mission cost. I'm not going to
invent a number for a three-station national programme. The metric that
matters is cost-per-avoided-stockout, and one avoided stockout of survival
oxygen at a remote station is worth more than every licence we could ever
sell."*

---

## 8. Honest Limitations Register

Presented proactively. A panel that discovers these themselves costs more
credibility than volunteering them.

| # | Limitation | Impact | Status / path |
|---|---|---|---|
| 1 | **No satellite media leg** | Family call is local preview only | Needs a satellite operator's media gateway. Authorization layer is complete. |
| 2 | **No real authentication** | Demo role picker + invite code | Supabase Auth + `profiles` table. Until then RLS stays deny-all. |
| 3 | **Invite code is public** (`MTR-2026`, in the README) | Signalling path credential is not secret | Per-booking random codes, out-of-band delivery, never committed |
| 4 | **Telemetry payload 2.40 MB/poll** | Dominant runtime cost on metered links | Move extraction into the Edge Function (~100× reduction) |
| 5 | **Cloud sync disabled** | No cross-device state | Resolves automatically when #2 lands |
| 6 | **No E2E encryption on comms** | Messages are not encrypted in transit beyond TLS | UI states `DEMO CHANNEL — NO E2E SIGNALING`. Would need an SFU or E2EE insertable-encryption layer. |
| 7 | **`polar_data_service.dart` is large** | Maintenance concentration | Highest test coverage in the repo; candidate for splitting |

---

## 9. Reproducing Every Number in This Document

| Claim | How to verify |
|---|---|
| 13,628 LOC / 2,269 test LOC | `git ls-files '*.dart' \| xargs wc -l` |
| 92 tests | `flutter test` |
| analyze clean | `flutter analyze` |
| 11 endpoints return 200 | `dart run tool/ncpor_smoke.dart` |
| 2.40 MB poll payload | `dart run tool/ncpor_smoke.dart`, sum endpoint sizes |
| Proxy latency samples | 5 × `curl` against the deployed Edge Function |
| RLS: 0 policies, 11 forced | `pg_policies` / `pg_class` |
| RLS attack results | `curl` with the publishable key as `anon` |
| Proxy host-allowlist | 4 rejected targets → `403` |
| 8 screens at 412px | `flutter test test/responsive_layout_test.dart` |
| Live deployment | `https://nitin-basker10.github.io/Aroha/` |
