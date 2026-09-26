# AROHA — SIH Presentation Content
### Polar Expedition Logistics & Command · SIH26062

> Speaker-ready slide content. Every claim here is verifiable in the repo or
> against the live project. Where a capability is *not* built, it is marked
> **[NOT BUILT]** so it never gets stated as if it were — see the judge Q&A
> at the end, which is the most important section of this document.

---

## Slide 1 — Title

**AROHA**
Polar Expedition Logistics & Command

- National Centre for Polar and Ocean Research (NCPOR), Goa
- Maitri & Bharati (Antarctica) · Himadri (Svalbard)
- Flutter · Supabase · Live NPDC telemetry
- Team / Track ID: `SIH26062`

> **Say:** "AROHA is a command app for India's polar programme. Three research
> outposts, thousands of kilometres from head office, living on scheduled
> resupply windows. This is the system that keeps them supplied — and the one
> that decides who is allowed to speak to their families."

---

## Slide 2 — The Problem

**Polar stations are logistics-constrained, and the tracking is paper-based.**

| Reality | Consequence |
|---|---|
| Resupply is **annual/seasonal** — one ship window per year | Stock must last 300+ days. A miscount kills the mission |
| Crew consume food, fuel, medical oxygen **continuously** | Consumption is invisible until stock is already critical |
| **18–20 hour** satellite delay to HQ | Decisions cannot be queried in real time |
| Bandwidth is metered and tiny | Cannot stream dashboards; cannot "just check" |
| 3 stations, mixed Arctic/Antarctic cycles | No single view from Goa |

Today this is **spreadsheets + radio logs + memory.** A single unnoticed
consumption error 200 days before the ship arrives is a station-level
emergency that nobody would see until it is too late to resupply.

> **Say:** "The failure mode isn't a wrong number on a screen. It's running out
> of medical oxygen in Antarctica with no way to tell Goa until it's too late."

---

## Slide 3 — The Idea

**One command surface that forecasts survival and enforces who gets through.**

1. **Forecast** — turn stock + burn rate into *days of survival*, and
   compare that to the next resupply window.
2. **Scope** — every crew member sees only their own station. No exceptions.
3. **Gate** — satellite family calls require *both* sides to clear a
   compliance and consent gate before any room opens.

```
Days of survival  =  current quantity  ÷  daily consumption rate
Risk              =  compare that to the days remaining to the next resupply ship
```

The second and third are the differentiator — most logistics apps stop at the
forecast.

---

## Slide 4 — Solution: The Survival Engine

**"Mark Watney" calculator** — `lib/core/utils/watney_calculator.dart`

```
daysRemaining = currentQuantity / dailyConsumptionRate
```

| Risk level | Condition |
|---|---|
| **CRITICAL** | `qty <= 0` **OR** `days < 40%` of resupply gap **OR** `qty <= 50%` of threshold |
| **WARNING** | `days < resupply gap` **OR** `qty <= threshold` |
| **NOMINAL** | otherwise |

**Division-by-zero is treated as an engineering decision, not an edge case.**
Zero, negative or NaN burn rate returns `999d` (survival unknown → not
silently "out of stock"). Zero stock returns `0d`. Both are covered by tests.

> **Say:** "A naive implementation turns a sensor fault into 'you have zero
> food'. We return 999 days instead — unknown is not the same as empty, and
> that distinction matters when someone is deciding whether to panic."

---

## Slide 5 — Live Telemetry (real data, honestly labelled)

**Not mocked.** Reads the real NCPOR portal — `data.ncpor.res.in`.

- Reads 4 parameters per station: temperature, wind, pressure, humidity
- Folds live readings over the seed data
- Per-station provenance shown in the UI

| Label | Meaning |
|---|---|
| `NCPOR LIVE` | Reading inside the freshness window |
| `NCPOR STALE` | Real reading, outside the window — **age shown** |
| `MOCK TELEMETRY` | Portal unreachable |

**The hard part was CORS.** The portal answers `OPTIONS 200` but sends **no
`Access-Control-*` headers at all**, so no browser can read it. Solved with a
**Supabase Edge Function** that fetches server-side and returns it with
correct headers — host-allowlisted to `data.ncpor.res.in` only, refusing
everything else with `403`.

> **Say:** "This is genuinely live data off a government portal. And when the
> reading is old, the app says so and shows the age. We'd rather show
> 'STALE, 1 day old' than a green badge implying everything is fine."

---

## Slide 6 — Roles & Scoping

| Capability | HQ (Goa) | Station Crew | Family |
|---|---|---|---|
| See stations | All 3, switchable | **Own station only, locked** | Own slot only |
| Command Centre | Yes | No | No |
| Edit inventory / cargo | Any station | Own station | **Never** |
| Blood group / emergency contact | Any station | Own station | **Never** |
| Family portal | No | No | **Yes** |
| Station telemetry & alerts | All | Own station | **Never** |

- Family sessions see **no station data at all** — verified by test
- Tabs are filtered by permission, not hidden client-side only
- 30-minute inactivity auto-logout; any interaction resets it

> **Say:** "The family portal is the sharpest example. A family member logs in
> with a one-time code and sees exactly one thing: their relative's call slot.
> No roster, no telemetry, no research. Not 'hidden by the UI' — the service
> layer returns nothing."

---

## Slide 7 — The Family Call Gate ★

**The feature judges remember.** A polar crew member gets a scheduled
satellite slot to speak to family. That call is a governed event, not a
button.

**Nothing opens until BOTH sides clear:**

```
CREW   signs the official disclaimer  (identity-bound)
FAMILY types their full name as an e-signature, accepts the disclaimer,
       and gives explicit consent
BOTH   acknowledge the "no research disclosure" briefing
AND    the slot is inside its join window
```

**Then, and only then:** `CallAccessPolicy` opens the room.

| Rule | Enforcement |
|---|---|
| Crew disclaimer | Bound to **that person**. A different crew member cannot sign it |
| Signature | **Immutable.** Cannot be overwritten or re-signed |
| Family consent | Requires the disclaimer first; **cannot be re-granted** once recorded |
| Family identity | Must match the issued invite **exactly** — name, station, person |
| Booking | Rejects duplicate IDs, past slots, wrong station, unsupported channel |
| Terminal bookings | Completed/cancelled calls **cannot be reopened** |

> **Say:** "Consent is a one-way door. Once it's given, it cannot be changed,
> and the person who gave it had to type their own name to give it. And a
> station can't sign for another station's crew — that's enforced in the
> service layer, with tests, not just in the UI."

---

## Slide 8 — Defending the Data (the part we're proudest of)

**The client is not a security boundary.** We treated the network layer as
hostile and locked it down.

**Before:** all 11 tables carried one permissive policy —
`roles {anon, authenticated}, cmd ALL, qual true, with_check true`.
The publishable key ships inside the JS bundle. So **anyone** could read
*and write* personnel medical data, invite codes and consent flags.

**After:** 0 policies, RLS **enabled and forced** on all 11 tables.
RLS with no permissive policy denies everything — so dropping the demo
policies *is* the lockdown.

**Verified with real `anon` requests, not by reading the config:**

| Attempt | Result |
|---|---|
| `SELECT` any table | `200 []` — zero rows |
| `INSERT` forged crew medical clearance | `401` — `42501 row-level security violated` |
| `UPDATE` invite to self-grant consent | `200 []` — 0 rows affected |
| `DELETE` station | `200 []` — 0 rows affected |

> **Say:** "This is the attack that actually matters for this app. Forge a
> medical clearance, or flip one consent flag, and you get into a family call.
> That's closed now — and we proved it by running the attack, not by trusting
> a setting."

---

## Slide 9 — Fail-Closed by Design

**Every mutation validates, and the default is refusal.**

- No session → mutation refused
- Wrong station → refused
- Already-signed record → re-signing refused
- Unknown role in a cloud payload → **throws**, never defaults to HQ admin
- Mutating APIs require an explicit user context; there is no "anonymous edit"
- Duplicate IDs rejected on inventory, personnel and bookings

**Enforcement lives in the service layer**, so it holds no matter which screen
or code path reaches it. The UI can only ever be *more* restrictive.

> **Say:** "We put the checks in the service layer deliberately. A UI-only
> check is one refactor away from being bypassed."

---

## Slide 10 — Engineering Discipline

| | |
|---|---|
| **92 automated tests** | Passing, `flutter analyze` clean |
| Behavioural, not snapshot | Asserts *authorization outcomes*, not pixels |
| Fail-closed paths tested | Wrong station, wrong person, forged consent, re-grant |
| Responsive regression suite | Every screen pumped at **412px** — a real handset |
| Light/dark theming | Semantic tokens, contrast-tested in both modes |
| Offline-first | App boots and runs with the backend unreachable |

The responsive suite exists because a dense tactical UI had **12 silent
overflows across 7 screens** at handset width. Now structurally prevented.

> **Say:** "A test that asserts a button is disabled is worth less than a test
> that asserts *the wrong crew member cannot sign this booking*."

---

## Slide 11 — Demo Script (90 seconds)

> Two browser windows. This order is deliberate — the gate cannot be skipped.

| # | Window A — Crew | Window B — Family |
|---|---|---|
| 1 | Login `aarav.sharma@maitri.ncpor.gov.in` | — |
| 2 | **Comms** → booking card | — |
| 3 | Tap **SIGN DISCLAIMER**, sign | — |
| 4 | Button now reads **AWAITING FAMILY CONSENT** | — |
| 5 | — | Login screen → **Family** → code `MTR-2026` |
| 6 | — | Accept disclaimer, give **consent** |
| 7 | Button flips to **JOIN VIDEO** | — |
| 8 | Show HQ view, inventory at-risk, **live telemetry** | — |

**Fallback if the network is unreliable:** the app is offline-first and runs
entirely on local seed data. `MTR-2026` → `call_01` is seeded, so the whole
gate demo works with no internet.

**Expect `NCPOR STALE`, not `NCPOR LIVE`** — the portal's newest reading may
be >24h old. That is correct behaviour, not a fault.

---

## Slide 12 — Impact

- **Safety:** oxygen/fuel/ration exhaustion surfaced weeks before the ship,
  not after
- **Sovereignty:** all data stays in an Indian government cloud project
  (NCPOR), not a foreign SaaS
- **Human:** a crew member on a 20-minute satellite slot with their family —
  governed, consented, and auditable
- **Research confidentiality:** the briefing and portal scoping enforce the
  Antarctic Treaty §III.1.c obligation that station positions and research
  activity are not disclosed
- **Institutional:** replaces spreadsheets across a national programme

---

## Slide 13 — What's Real vs. What's Next

**Built and demonstrated**
- Survival forecasting & risk engine
- Role + station scoping, fail-closed service guards
- Two-party consent gate for family calls
- **Live NPDC telemetry** through a production Edge Function
- **Enforced RLS lockdown**, verified by attack
- Offline-first, responsive, light/dark, 92 tests

**Not built — stated plainly**

| Gap | Status |
|---|---|
| **Satellite media leg** | **Local preview only.** No `RTCPeerConnection`/ICE/signaling. The room shows your own camera and says `REMOTE RELAY NOT CONFIGURED`. A real link needs a satellite operator's media gateway. **[NOT BUILT]** |
| **Real authentication** | Demo role picker + invite code. No Supabase Auth, no passwords at rest. **[NOT BUILT]** — which is *why* RLS is deny-all rather than scoped |
| **Cloud sync** | Intentionally off; runs on local seed data. **[BY DESIGN]** |
| **Encrypted calls** | No E2E. The UI says `DEMO CHANNEL — NO E2E SIGNALING`. **[NOT BUILT]** |

**Next:** Supabase Auth + a `profiles` table to replace the demo login ·
scoped RLS policies once identity exists · a satellite-operator media gateway
for the real call path.

> **Say:** "I'd rather show you four things that genuinely work than fifteen
> that don't. The media leg is the honest gap — the authorization around it
> is complete, the transport isn't."

---

## Slide 14 — Closing

**AROHA keeps a station alive, keeps its data sovereign, and keeps a
crew member's call with their family a governed event rather than a button.**

Live: `https://nitin-basker10.github.io/Aroha/`
Repo: `github.com/Nitin-Basker10/Aroha`

> "The hardest part of this problem wasn't the forecasting. It was deciding
> what a family member is *allowed* to see, and then making sure the
> database agreed — even when nobody was watching."

---

# Judge Q&A — Anticipated

**Q: Can I actually make a satellite call?**
No, and the app tells you so on screen. There's no peer connection, ICE or
signaling in the codebase — the room shows your own camera and says
`REMOTE RELAY NOT CONFIGURED`. A real link runs through a satellite
operator's media gateway, not peer-to-peer. **What we built and can defend
is the authorization and consent layer around the call.**

**Q: The invite code is `MTR-2026` — isn't that public?**
Yes, and we documented that as a limitation. The invite code is the only
credential for the signalling path, and in this build it's in the README.
It's a placeholder for real access control. The correct fix is per-booking
random codes delivered out of band, plus real authentication binding a
session to a verified user.

**Q: You locked down RLS — isn't the app disconnected from the backend now?**
Yes, deliberately. With no authentication system, any policy that filters by
identity would deny *everyone* — so deny-all is the only safe posture. The
app is offline-first and runs fully on local seed data, so the demo is
unaffected. When Auth lands, we swap in scoped policies.

**Q: The telemetry says STALE. Is it live?**
It's real data from the NCPOR portal; the newest reading is outside our 24h
freshness window, so the app labels it `STALE` and shows the age. We chose
to show the age rather than show a reassuring green badge.

**Q: How do you know the security controls actually work?**
We ran the attacks. Anonymous `SELECT` returns nothing, anonymous `INSERT`
of a forged medical clearance returns `42501`, and self-granting consent
affects zero rows. Those are real responses from the live project, not
claims about configuration.

**Q: What's the most impressive engineering decision?**
Putting the authorization checks in the service layer rather than the UI, and
then writing tests that assert the *failure* — that a different crew member
cannot sign, that consent cannot be re-granted, that an unknown role throws
instead of defaulting to admin.

---

### Before you present — two housekeeping items

1. **Revoke the Netlify token.** It was pasted in chat and is account-wide.
   Netlify → User settings → Personal access tokens.
2. **`prd/PRD.md` has two stale lines** — §1 says "No backend" and §2 says
   the family portal "was removed". Both are now false. Worth fixing before
   a judge reads it.
