# Auth QA

This runbook covers demo mode, Google sign-in readiness, Apple sign-in status, session refresh, and quick unlock for the Ross internal alpha.

## Demo mode

Purpose:

- local QA only
- no production-account claim

Expected behavior:

- visible as `Open demo mode`
- works without backend credentials
- creates a local session
- lands on Home

Known demo emails:

- `advocate@ross.ai`
- `test@ross.ai`
- `admin@ross.ai`

## Google OAuth

### Backend environment

Required backend environment values:

- `PORT`
- `ROSS_PUBLIC_BASE_URL`
- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`
- `ROSS_AUTH_ACCESS_SIGNING_SECRET`
- `ROSS_AUTH_REFRESH_SIGNING_SECRET`

Typical local start command:

```bash
cd /Users/amanpandey/projects/ross/backend
PORT=8787 \
ROSS_PUBLIC_BASE_URL=http://127.0.0.1:8787 \
GOOGLE_OAUTH_CLIENT_ID=... \
GOOGLE_OAUTH_CLIENT_SECRET=... \
npm run dev
```

### Callback behavior

Current mobile flow:

1. app opens `/auth/google/start`
2. backend redirects to Google
3. backend receives Google callback
4. backend redirects back to `ross://auth/callback`
5. app reads access, refresh, account token, subject, and profile fields from the callback

### iOS requirements

- bundle URL scheme `ross` must remain registered
- callback target is `ross://auth/callback`
- backend base URL must be reachable from the simulator or device

### Android requirements

- callback intent filter for `ross://auth/callback` must remain registered
- backend base URL must be reachable from the emulator or device

Note:

The current mobile flow is backend-mediated OAuth. It does not depend on a native Google SDK setup or Android SHA registration in the same way a native SDK flow would.

### Expected success

- browser auth completes
- app returns to Ross
- app stores session
- app lands on Home

### Expected failure

- app shows `Could not sign in. Please try again.`
- app does not expose raw token or provider errors

### Current status

- backend routes are present
- app wiring is present on iOS and Android
- session refresh path exists
- real Google OAuth is not yet proven in this phase without real credentials

## Apple sign-in

Current status:

- iOS only
- implemented as a local Ross session on device
- no Ross backend Apple auth route exists yet

Expected current behavior:

- Apple sign-in can create a local session
- UI should not imply backend-backed sync

Future requirement for backend-backed Apple auth:

- dedicated backend Apple auth route
- entitlement and capability review
- documented account-linking behavior

## Session refresh

Current behavior:

- backend-backed sessions call `/auth/session/refresh`
- expired or failed refresh signs out cleanly
- normal user copy is `Session expired. Please sign in again.`

QA expectation:

- no crash loop
- no raw refresh-token error in UI

## Quick unlock

iOS:

- uses LocalAuthentication
- simulator support is limited

Android:

- uses `BiometricManager` with strong biometrics or device credential
- emulator support is limited

Expected plain-language fallback:

- `Quick unlock is not available on this device.`

Current proof status:

- implementation exists
- physical-device validation is still pending

## Known blockers

- real Google OAuth proof still depends on real configured credentials
- Apple sign-in is not yet backend-backed
- physical-device quick unlock proof is still pending
