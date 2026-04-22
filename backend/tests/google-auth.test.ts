import assert from "node:assert/strict";
import test from "node:test";

import { buildApp } from "../src/main.js";
import { readRuntimeEnv } from "../src/security/env.js";

function parseJson<T>(payload: string): T {
  return JSON.parse(payload) as T;
}

function buildTestEnv(overrides: Record<string, string | undefined> = {}) {
  return readRuntimeEnv({
    nodeEnvOverride: "test",
    environment: {
      ...process.env,
      GOOGLE_OAUTH_CLIENT_ID: "test-google-client-id",
      GOOGLE_OAUTH_CLIENT_SECRET: "test-google-client-secret",
      ROSS_PUBLIC_BASE_URL: "http://localhost:8080",
      ROSS_AUTH_MOBILE_REDIRECT: "ross://auth/callback",
      ...overrides
    }
  });
}

function jsonResponse(payload: unknown, status: number = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "content-type": "application/json"
    }
  });
}

test("google auth start, callback, and refresh keep the session stateless", async (t) => {
  const originalFetch = globalThis.fetch;
  const fetchCalls: Array<{ url: string; init?: RequestInit | undefined }> = [];

  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    fetchCalls.push({
      url: typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url,
      init
    });

    if (fetchCalls.length === 1) {
      return jsonResponse({
        access_token: "google-access-token",
        token_type: "Bearer",
        expires_in: 3600
      });
    }

    if (fetchCalls.length === 2) {
      return jsonResponse({
        sub: "google-user-123",
        email: "advocate@example.com",
        email_verified: true,
        name: "Asha Counsel"
      });
    }

    throw new Error("Unexpected fetch call");
  }) as typeof fetch;

  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const app = await buildApp({
    env: buildTestEnv(),
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
  });

  const startResponse = await app.inject({
    method: "GET",
    url: "/auth/google/start?platform=android&redirect_uri=ross%3A%2F%2Fauth%2Fcallback&loginHint=advocate%40example.com"
  });

  assert.equal(startResponse.statusCode, 302);

  const googleAuthorizeUrl = new URL(startResponse.headers.location ?? "");
  assert.equal(googleAuthorizeUrl.origin, "https://accounts.google.com");
  assert.equal(googleAuthorizeUrl.searchParams.get("client_id"), "test-google-client-id");
  assert.equal(
    googleAuthorizeUrl.searchParams.get("redirect_uri"),
    "http://localhost:8080/auth/google/callback"
  );
  assert.equal(googleAuthorizeUrl.searchParams.get("login_hint"), "advocate@example.com");

  const state = googleAuthorizeUrl.searchParams.get("state");
  assert.ok(state);

  const callbackResponse = await app.inject({
    method: "GET",
    url: `/auth/google/callback?code=google-auth-code&state=${encodeURIComponent(state)}`
  });

  assert.equal(callbackResponse.statusCode, 302);

  const mobileRedirectUrl = new URL(callbackResponse.headers.location ?? "");
  assert.equal(mobileRedirectUrl.protocol, "ross:");
  assert.equal(mobileRedirectUrl.hostname, "auth");
  assert.equal(mobileRedirectUrl.pathname, "/callback");
  assert.equal(mobileRedirectUrl.searchParams.get("status"), "success");
  assert.equal(mobileRedirectUrl.searchParams.get("email"), "advocate@example.com");
  assert.equal(mobileRedirectUrl.searchParams.get("name"), "Asha Counsel");
  assert.equal(mobileRedirectUrl.searchParams.get("display_name"), "Asha Counsel");

  const accessToken = mobileRedirectUrl.searchParams.get("access_token");
  const refreshToken = mobileRedirectUrl.searchParams.get("refresh_token");
  const accountToken = mobileRedirectUrl.searchParams.get("account_token");
  const subject = mobileRedirectUrl.searchParams.get("subject");
  const expiresAt = mobileRedirectUrl.searchParams.get("expires_at");

  assert.ok(accessToken?.startsWith("acct_"));
  assert.ok(refreshToken?.startsWith("rfr_"));
  assert.equal(accountToken, accessToken);
  assert.ok(subject?.startsWith("google_"));
  assert.ok(expiresAt);

  assert.equal(fetchCalls.length, 2);
  assert.equal(fetchCalls[0]?.url, "https://oauth2.googleapis.com/token");
  assert.equal(fetchCalls[1]?.url, "https://openidconnect.googleapis.com/v1/userinfo");

  const tokenExchangeBody = fetchCalls[0]?.init?.body;
  assert.equal(tokenExchangeBody instanceof URLSearchParams, true);

  const tokenExchangeParams = tokenExchangeBody as URLSearchParams;
  assert.equal(tokenExchangeParams.get("code"), "google-auth-code");
  assert.equal(tokenExchangeParams.get("client_id"), "test-google-client-id");
  assert.equal(tokenExchangeParams.get("client_secret"), "test-google-client-secret");
  assert.equal(tokenExchangeParams.get("redirect_uri"), "http://localhost:8080/auth/google/callback");

  const refreshResponse = await app.inject({
    method: "POST",
    url: "/auth/session/refresh",
    payload: {
      refresh_token: refreshToken
    }
  });

  assert.equal(refreshResponse.statusCode, 200);

  const refreshBody = parseJson<{
    accessToken: string;
    accountToken: string;
    refreshToken: string;
    subject: string;
    accountBoundary: string;
    profile?: {
      email?: string | undefined;
    };
  }>(refreshResponse.body);

  assert.ok(refreshBody.accessToken.startsWith("acct_"));
  assert.equal(refreshBody.accountToken, refreshBody.accessToken);
  assert.notEqual(refreshBody.accessToken, accessToken);
  assert.notEqual(refreshBody.refreshToken, refreshToken);
  assert.equal(refreshBody.subject, subject);
  assert.equal(refreshBody.accountBoundary, "no_case_data");
  assert.equal(refreshBody.profile?.email, "advocate@example.com");
});

test("google callback redirects back to the mobile handler with error params on failure", async (t) => {
  const app = await buildApp({
    env: buildTestEnv(),
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
  });

  const startResponse = await app.inject({
    method: "GET",
    url: "/auth/google/start"
  });

  const googleAuthorizeUrl = new URL(startResponse.headers.location ?? "");
  const state = googleAuthorizeUrl.searchParams.get("state");
  assert.ok(state);

  const deniedResponse = await app.inject({
    method: "GET",
    url: `/auth/google/callback?error=access_denied&state=${encodeURIComponent(state)}`
  });

  assert.equal(deniedResponse.statusCode, 302);

  const deniedRedirect = new URL(deniedResponse.headers.location ?? "");
  assert.equal(deniedRedirect.protocol, "ross:");
  assert.equal(deniedRedirect.searchParams.get("status"), "error");
  assert.equal(deniedRedirect.searchParams.get("error"), "google_oauth_denied");
  assert.equal(
    deniedRedirect.searchParams.get("error_description"),
    "Google sign-in was not completed."
  );

  const invalidStateResponse = await app.inject({
    method: "GET",
    url: "/auth/google/callback?code=google-auth-code&state=stt_invalid"
  });

  assert.equal(invalidStateResponse.statusCode, 302);

  const invalidStateRedirect = new URL(invalidStateResponse.headers.location ?? "");
  assert.equal(invalidStateRedirect.protocol, "ross:");
  assert.equal(invalidStateRedirect.searchParams.get("status"), "error");
  assert.equal(invalidStateRedirect.searchParams.get("error"), "invalid_auth_state");
});
