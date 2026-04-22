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
      ROSS_PUBLIC_LAW_GEMINI_API_KEY: "test-gemini-key",
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

test("public-law search uses Gemini grounding when configured and sends only the sanitized query", async (t) => {
  const originalFetch = globalThis.fetch;
  const fetchCalls: Array<{ url: string; init?: RequestInit | undefined }> = [];

  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    fetchCalls.push({
      url: typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url,
      init
    });

    return jsonResponse({
      candidates: [
        {
          content: {
            parts: [
              {
                text: "Recent public-law material notes that delay condonation depends on sufficient cause and diligence."
              }
            ]
          },
          groundingMetadata: {
            webSearchQueries: [
              "India condonation of delay sufficient cause diligence"
            ],
            groundingChunks: [
              {
                web: {
                  uri: "https://www.livelaw.in/top-stories/condonation-delay-supreme-court-example",
                  title: "Supreme Court on condonation of delay"
                }
              },
              {
                web: {
                  uri: "https://www.scobserver.in/journal/limitation-act-delay-condonation-overview",
                  title: "Limitation and delay condonation overview"
                }
              }
            ],
            groundingSupports: [
              {
                segment: {
                  startIndex: 0,
                  endIndex: 72,
                  text: "Delay condonation depends on sufficient cause and documented diligence."
                },
                groundingChunkIndices: [0, 1]
              }
            ]
          }
        }
      ]
    });
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

  const query = "Latest Indian public-law guidance on condonation of delay where diligence is documented";
  const response = await app.inject({
    method: "POST",
    url: "/public-law/search",
    payload: {
      query,
      jurisdiction: "IN-ALL",
      language: "en",
      confirmedPublicPreview: true
    }
  });

  assert.equal(response.statusCode, 200);

  const body = parseJson<{
    connector: {
      mode: string;
      liveSourceConnected: boolean;
    };
    resultCount: number;
    results: Array<{
      title: string;
      source: string;
      link: string;
      snippet: string;
    }>;
  }>(response.body);

  assert.equal(body.connector.mode, "gemini_google_search");
  assert.equal(body.connector.liveSourceConnected, true);
  assert.ok(body.resultCount >= 1);
  assert.match(body.results[0]?.title ?? "", /delay|condonation|overview/i);
  assert.match(body.results[0]?.source ?? "", /livelaw\.in|scobserver\.in/i);

  assert.equal(fetchCalls.length, 1);
  assert.equal(
    fetchCalls[0]?.url,
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
  );

  const requestBody = JSON.stringify(fetchCalls[0]?.init?.body);
  const parsedRequest = JSON.parse(fetchCalls[0]?.init?.body as string) as {
    contents?: Array<{ parts?: Array<{ text?: string }> }>;
    tools?: Array<Record<string, unknown>>;
    systemInstruction?: { parts?: Array<{ text?: string }> };
  };

  assert.equal(parsedRequest.contents?.[0]?.parts?.[0]?.text, query);
  assert.equal(Array.isArray(parsedRequest.tools), true);
  assert.match(parsedRequest.systemInstruction?.parts?.[0]?.text ?? "", /Only the sanitized user query is user-provided context/i);
  assert.doesNotMatch(requestBody, /Raghav Fakepriv/i);
  assert.doesNotMatch(requestBody, /9876501234/);
  assert.doesNotMatch(requestBody, /fakepriv@example\.com/i);
  assert.doesNotMatch(requestBody, /FAKE\/123\/2026/i);
  assert.doesNotMatch(requestBody, /blue suitcase near temple/i);
  assert.doesNotMatch(requestBody, /caseId|caseText|filename|document text/i);
});

test("unsafe public-law queries are rejected before any Gemini request is made", async (t) => {
  const originalFetch = globalThis.fetch;
  const fetchCalls: Array<{ url: string; init?: RequestInit | undefined }> = [];

  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    fetchCalls.push({
      url: typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url,
      init
    });

    return jsonResponse({});
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

  const response = await app.inject({
    method: "POST",
    url: "/public-law/search",
    payload: {
      query: "Need public-law guidance for Raghav Fakepriv in FAKE/123/2026",
      jurisdiction: "IN-ALL",
      language: "en",
      confirmedPublicPreview: true
    }
  });

  assert.equal(response.statusCode, 400);
  assert.equal(fetchCalls.length, 0);
  assert.doesNotMatch(response.body, /Raghav Fakepriv/i);
  assert.doesNotMatch(response.body, /FAKE\/123\/2026/i);
});

test("Gemini connector failures fall back to the privacy-safe index without echoing the query", async (t) => {
  const originalFetch = globalThis.fetch;

  globalThis.fetch = (async () =>
    jsonResponse(
      {
        error: {
          message: "provider unavailable"
        }
      },
      503
    )) as typeof fetch;

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

  const query = "Latest Indian public-law guidance on condonation of delay";
  const response = await app.inject({
    method: "POST",
    url: "/public-law/search",
    payload: {
      query,
      jurisdiction: "IN-ALL",
      language: "en",
      confirmedPublicPreview: true
    }
  });

  assert.equal(response.statusCode, 200);
  assert.match(response.body, /backend_fixture_index/);
  assert.match(response.body, /temporarily unavailable/i);
  assert.doesNotMatch(response.body, new RegExp(query, "i"));
});

test("Gemini responses without usable grounding fall back to the privacy-safe index", async (t) => {
  const originalFetch = globalThis.fetch;

  globalThis.fetch = (async () =>
    jsonResponse({
      candidates: [
        {
          content: {
            parts: [
              {
                text: "General answer without grounding chunks."
              }
            ]
          },
          groundingMetadata: {
            groundingChunks: [],
            groundingSupports: []
          }
        }
      ]
    })) as typeof fetch;

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

  const response = await app.inject({
    method: "POST",
    url: "/public-law/search",
    payload: {
      query: "Latest Indian public-law guidance on delay condonation and sufficient cause",
      jurisdiction: "IN-ALL",
      language: "en",
      confirmedPublicPreview: true
    }
  });

  assert.equal(response.statusCode, 200);
  assert.match(response.body, /backend_fixture_index/);
  assert.match(response.body, /temporarily unavailable/i);
});
