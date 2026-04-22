# Auth QA

This runbook covers demo mode, Google sign-in readiness, Apple sign-in status, session refresh, and quick unlock for Ross.

## Demo mode

Purpose:

- local QA only
- no production-account claim

Expected behavior:

- visible as `Open demo mode`
- works without backend credentials
- creates a local session
- lands on Home
- seeds a synthetic workspace for local QA

Current local demo workspace:

- `Demo Matter: Sharma v. Rana`
- seeded documents, tasks, dates, and review items

Reset path:

- `Settings > Account > Reset demo data`

## Google OAuth

### Backend environment

Required backend environment values:

- `PORT`
- `ROSS_PUBLIC_BASE_URL`
- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`
- `ROSS_AUTH_ACCESS_SIGNING_SECRET`
- `ROSS_AUTH_REFRESH_SIGNING_SECRET`

Recommended local storage:

- keep these in `backend/.env.local`
- do not commit that file

Typical local start:

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
3. backend receives the callback
4. backend redirects back to `ross://auth/callback`
5. app reads the session tokens and profile fields from the callback

### iOS requirements

- URL scheme `ross` must remain registered
- backend URL must be reachable from the simulator or device

### Android requirements

- deep link for `ross://auth/callback` must remain registered
- backend URL must be reachable from the emulator or device

### Expected success

- auth completes in the browser
- Ross receives the callback
- session is stored
- app lands on Home

### Expected failure

- app shows `Could not sign in. Please try again.`
- raw token or provider errors do not appear in normal UI

### Current status

- backend routes exist
- iOS and Android wiring exist
- session refresh route exists
- real Google OAuth is still not manually proven in this phase

## Apple sign-in

Current status:

- iOS only
- local Ross session only
- not backed by a Ross backend Apple auth route

Current user-facing truth:

- it is fair to present Apple sign-in as an on-device sign-in path
- it is not fair to imply cross-device Ross account sync

Future work needed for backend-backed Apple auth:

- dedicated backend Apple auth route
- account-linking rules
- entitlement and capability review

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

Expected plain fallback:

- `Quick unlock is not available on this device.`

Current proof status:

- implementation exists
- real hardware proof is still pending

## Auth truth as of April 22, 2026

Proven:

- demo sign-in works on iOS simulator

Not yet proven:

- real Google OAuth with real credentials
- backend-backed Apple auth
- physical-device quick unlock
