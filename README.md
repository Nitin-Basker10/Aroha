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
