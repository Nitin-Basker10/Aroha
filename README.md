# AROHA — Polar Expedition Command

AROHA is a Flutter Material 3 command application for NCPOR polar-station logistics, telemetry, personnel, resupply, communications, and family satellite-call workflows.

## Theme behavior

- The first launch follows the device operating-system light/dark setting.
- Use the sun/moon control on the login terminal or mission header to switch modes.
- An explicit user choice is persisted with `shared_preferences` and restored on later launches.
- All Flutter screens and dialogs use semantic light/dark theme tokens; status colors and foreground roles remain contrast-safe in both modes.
- Cargo, call-booking, and resource-request states use the shared semantic status mapping.
- The satellite call room follows the selected application theme, including its status controls and recording indicator.
- Web and Android launch surfaces define light/dark startup colors.

## Run locally

From `C:\Users\user\sih_polar`:

```powershell
& 'C:\Users\user\flutter\bin\flutter.bat' pub get
& 'C:\Users\user\flutter\bin\flutter.bat' analyze
& 'C:\Users\user\flutter\bin\flutter.bat' test
& 'C:\Users\user\flutter\bin\flutter.bat' run -d chrome
```

For the optional web NPDC telemetry proxy, see `IMPLEMENTATION_REMAINING.md` and `tool/ncpor_proxy.dart`.

## Deploy

Pushed to GitHub Pages by `.github/workflows/pages.yml` on every push to
`main`. The public site is:

```
https://nitin-basker10.github.io/Aroha/
```

**One-time setup:** in the repo, **Settings → Pages → Build and deployment
→ Source → GitHub Actions**. Without that toggle the workflow builds
successfully but the deploy step fails, because Pages has nowhere to
publish.

The telemetry proxy URL is inlined in the workflow, since the Edge Function
is public and unauthenticated. To point at a different Supabase project,
define a repository variable named `NCPOR_PROXY` (Settings → Secrets and
variables → Actions → Variables) and it takes precedence:

```
https://<project>.supabase.co/functions/v1/npdc-proxy?url=
```

`--base-href /Aroha/` must track the repo name; a mismatch renders a blank
page because the app resolves `main.dart.js` against the wrong root.

Live telemetry in the deployed build goes through the
`supabase/functions/npdc-proxy` Edge Function. `tool/ncpor_proxy.dart` is
loopback-only dev scaffolding and must never be deployed.
