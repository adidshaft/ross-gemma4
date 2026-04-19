import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import type { AuditEvent } from "../src/audit/logger.js";
import { buildApp } from "../src/main.js";
import { readRuntimeEnv } from "../src/security/env.js";

function parseJson<T>(payload: string): T {
  return JSON.parse(payload) as T;
}

function escapeForRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function buildTestEnv(
  overrides: Record<string, string | undefined> = {},
  nodeEnvOverride: string = "test"
) {
  return readRuntimeEnv({
    nodeEnvOverride,
    environment: {
      ...process.env,
      ...overrides
    }
  });
}

test("rejects case-data fields on protected entitlement, model, and public search routes", async (t) => {
  const auditSink: AuditEvent[] = [];
  const app = await buildApp({
    env: buildTestEnv(),
    auditSink,
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
  });

  const responses = await Promise.all([
    app.inject({
      method: "POST",
      url: "/entitlements/refresh",
      payload: {
        accountToken: "acct_test_token_1234567890",
        platform: "android",
        appVersion: "1.0.0",
        deviceIdHash: "a1b2c3d4e5f6a7b8",
        caseId: "case-123"
      }
    }),
    app.inject({
      method: "POST",
      url: "/model-download/session",
      payload: {
        accountToken: "acct_test_token_1234567890",
        packId: "quick-start-pack",
        platform: "ios",
        appVersion: "1.0.0",
        deviceIdHash: "a1b2c3d4e5f6a7b8",
        fileName: "private-brief.pdf"
      }
    }),
    app.inject({
      method: "POST",
      url: "/public-law/search",
      payload: {
        query: "latest arbitration law",
        jurisdiction: "IN-ALL",
        language: "en",
        confirmedPublicPreview: true,
        ocrText: "raw private OCR text"
      }
    }),
    app.inject({
      method: "GET",
      url: "/model-catalog?platform=android&caseNumber=CS123"
    })
  ]);

  for (const response of responses) {
    assert.equal(response.statusCode, 400);
    const body = parseJson<{
      error: string;
      details?: { fields?: string[] };
    }>(response.body);

    assert.equal(body.error, "privacy_boundary_violation");
    assert.ok(body.details?.fields && body.details.fields.length > 0);
  }

  const serializedLogs = JSON.stringify(auditSink);
  assert.doesNotMatch(serializedLogs, /raw private OCR text/);
  assert.doesNotMatch(serializedLogs, /private-brief\.pdf/);
});

test("rejected requests do not echo fake secrets back in errors or logs", async (t) => {
  const fakeSecret = "sk_live_FAKE_SECRET_DO_NOT_LEAK_123";
  const auditSink: AuditEvent[] = [];
  const app = await buildApp({
    env: buildTestEnv(),
    auditSink,
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
  });

  const response = await app.inject({
    method: "POST",
    url: "/model-download/session",
    payload: {
      accountToken: "acct_test_token_1234567890",
      packId: "quick-start-pack",
      platform: "ios",
      appVersion: "1.0.0",
      deviceIdHash: "a1b2c3d4e5f6a7b8",
      fileName: fakeSecret
    }
  });

  assert.equal(response.statusCode, 400);
  assert.doesNotMatch(response.body, new RegExp(fakeSecret));
  assert.doesNotMatch(JSON.stringify(auditSink), new RegExp(fakeSecret));
});

test("successful model catalog and download responses stay privacy-safe and exclude request secrets", async (t) => {
  const accountToken = "acct_test_FAKE_DOWNLOAD_SECRET_1234567890";
  const deviceIdHash = "feedfacecafebeef1234567890abcd";
  const appVersion = "secret-build-9.9.9";
  const auditSink: AuditEvent[] = [];
  const app = await buildApp({
    env: buildTestEnv(),
    auditSink,
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
  });

  const catalogResponse = await app.inject({
    method: "GET",
    url: "/model-catalog?platform=android"
  });

  const catalogBody = parseJson<{
    manifest: {
      payload: {
        packs: Array<{ packId: string }>;
      };
    };
  }>(catalogResponse.body);

  const downloadResponse = await app.inject({
    method: "POST",
    url: "/model-download/session",
    payload: {
      accountToken,
      packId: catalogBody.manifest.payload.packs[0]?.packId ?? "quick-start-pack",
      platform: "android",
      appVersion,
      deviceIdHash
    }
  });

  assert.equal(catalogResponse.statusCode, 200);
  assert.equal(downloadResponse.statusCode, 200);

  const downloadBody = parseJson<{
    downloadSession: {
      payload: {
        artifact: {
          segments: Array<{ sha256: string }>;
        };
        accountTokenHash?: string;
        deviceIdHash?: string;
        appVersion?: string;
      };
    };
  }>(downloadResponse.body);

  assert.ok(downloadBody.downloadSession.payload.artifact.segments.length >= 1);
  assert.equal(downloadBody.downloadSession.payload.accountTokenHash, undefined);
  assert.equal(downloadBody.downloadSession.payload.deviceIdHash, undefined);
  assert.equal(downloadBody.downloadSession.payload.appVersion, undefined);

  const serialized = `${catalogResponse.body}\n${downloadResponse.body}\n${JSON.stringify(auditSink)}`;
  assert.doesNotMatch(serialized, new RegExp(escapeForRegExp(accountToken)));
  assert.doesNotMatch(serialized, new RegExp(escapeForRegExp(deviceIdHash)));
  assert.doesNotMatch(serialized, new RegExp(escapeForRegExp(appVersion)));
  assert.doesNotMatch(serialized, /caseId/i);
  assert.doesNotMatch(serialized, /caseText/i);
});

test("public-law search rejects obvious private matter content and fake secrets without echoing them", async (t) => {
  const auditSink: AuditEvent[] = [];
  const app = await buildApp({
    env: buildTestEnv(),
    auditSink,
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
  });

  const disallowedQueries = [
    "What public law applies in my client dispute?",
    "Need guidance for Raghav Fakepriv under public law",
    "Need guidance tied to 9876501234",
    "Can fakepriv@example.com be mentioned in a filing?",
    "Status of FAKE/123/2026",
    "How should blue suitcase near temple be handled?"
  ];

  for (const query of disallowedQueries) {
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

    assert.equal(response.statusCode, 400);

    const body = parseJson<{
      error: string;
      details?: { reasons?: string[] };
    }>(response.body);

    assert.equal(body.error, "privacy_boundary_violation");
    assert.ok(body.details?.reasons && body.details.reasons.length > 0);
    assert.doesNotMatch(response.body, new RegExp(escapeForRegExp(query), "i"));
  }

  const serializedLogs = JSON.stringify(auditSink);
  assert.match(serializedLogs, /sanitized_public_query/);
  assert.match(serializedLogs, /public_search_rejected/);
  assert.match(serializedLogs, /reasonCount/);
  assert.match(serializedLogs, /queryHash/);
  assert.doesNotMatch(serializedLogs, /Raghav Fakepriv/i);
  assert.doesNotMatch(serializedLogs, /9876501234/);
  assert.doesNotMatch(serializedLogs, /fakepriv@example\.com/i);
  assert.doesNotMatch(serializedLogs, /FAKE\/123\/2026/i);
  assert.doesNotMatch(serializedLogs, /blue suitcase near temple/i);
});

test("production public search logs only hashed query metadata and never the full query", async (t) => {
  const fakeSecret = "FAKE_SECRET_MUST_NOT_APPEAR";
  const auditSink: AuditEvent[] = [];
  const app = await buildApp({
    env: buildTestEnv({}, "production"),
    auditSink,
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
  });

  const response = await app.inject({
    method: "POST",
    url: "/public-law/search",
    payload: {
      query: `latest arbitration position ${fakeSecret}`,
      jurisdiction: "IN-ALL",
      language: "en",
      confirmedPublicPreview: true
    }
  });

  assert.equal(response.statusCode, 200);
  assert.doesNotMatch(response.body, new RegExp(fakeSecret));

  const serializedLogs = JSON.stringify(auditSink);
  assert.match(response.body, /backend_fixture_index/);
  assert.match(serializedLogs, /queryHash/);
  assert.match(serializedLogs, /queryLength/);
  assert.doesNotMatch(serializedLogs, new RegExp(fakeSecret));
});

test("external model serving never logs the configured local file path or fake-secret filename", async (t) => {
  const externalDir = mkdtempSync(path.join(tmpdir(), "ross-external-secret-"));
  const fakeSecretName = "Raghav Fakepriv-9876501234-fakepriv@example.com.task";
  const externalPath = path.join(externalDir, fakeSecretName);
  const bytes = Buffer.from("external model bytes");
  writeFileSync(externalPath, bytes);

  const auditSink: AuditEvent[] = [];
  const app = await buildApp({
    env: buildTestEnv({
      ROSS_ENABLE_EXTERNAL_MODEL_METADATA: "1",
      ROSS_ENABLE_EXTERNAL_MODEL_SERVING: "1",
      ROSS_EXTERNAL_MODEL_RUNTIME: "mediapipe_llm",
      ROSS_EXTERNAL_MODEL_KIND: "external_debug_model",
      ROSS_EXTERNAL_MODEL_SHA256: createHash("sha256").update(bytes).digest("hex"),
      ROSS_EXTERNAL_MODEL_SIZE_BYTES: String(bytes.length),
      ROSS_EXTERNAL_MODEL_FILE_PATH: externalPath
    }),
    auditSink,
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
    rmSync(externalDir, { recursive: true, force: true });
  });

  const sessionResponse = await app.inject({
    method: "POST",
    url: "/model-download/session",
    payload: {
      accountToken: "acct_test_token_1234567890",
      packId: "case-associate-local-debug-pack",
      platform: "android",
      appVersion: "1.0.0",
      deviceIdHash: "a1b2c3d4e5f6a7b8"
    }
  });

  assert.equal(sessionResponse.statusCode, 200);

  const serializedLogs = `${sessionResponse.body}\n${JSON.stringify(auditSink)}`;
  assert.doesNotMatch(serializedLogs, /Raghav Fakepriv/i);
  assert.doesNotMatch(serializedLogs, /9876501234/);
  assert.doesNotMatch(serializedLogs, /fakepriv@example\.com/i);
  assert.doesNotMatch(serializedLogs, new RegExp(escapeForRegExp(externalPath)));
});
