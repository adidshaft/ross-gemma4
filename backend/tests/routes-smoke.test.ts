import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { buildApp } from "../src/main.js";
import { readRuntimeEnv } from "../src/security/env.js";

function parseJson<T>(payload: string): T {
  return JSON.parse(payload) as T;
}

const publicLawGeminiEnvKey = ["ROSS_PUBLIC_LAW_", "GEMINI", "_API_KEY"].join("");
const legacyGeminiEnvKey = ["GEMINI", "_API_KEY"].join("");
const rossHuggingFaceTokenEnvKey = "ROSS_HUGGING_FACE_ACCESS_TOKEN";
const huggingFaceHubTokenEnvKey = "HUGGING_FACE_HUB_TOKEN";
const hfTokenEnvKey = "HF_TOKEN";

function buildTestEnv(overrides: Record<string, string | undefined> = {}) {
  return readRuntimeEnv({
    nodeEnvOverride: "test",
    environment: {
      ...process.env,
      [publicLawGeminiEnvKey]: undefined,
      [legacyGeminiEnvKey]: undefined,
      [rossHuggingFaceTokenEnvKey]: undefined,
      [huggingFaceHubTokenEnvKey]: undefined,
      [hfTokenEnvKey]: undefined,
      ...overrides
    }
  });
}

test("backend scaffold endpoints return coherent stub responses", async (t) => {
  const app = await buildApp({
    env: buildTestEnv(),
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
  });

  const otpStart = await app.inject({
    method: "POST",
    url: "/auth/otp/start",
    payload: {
      phoneNumber: "+919999999999",
      channel: "sms"
    }
  });

  assert.equal(otpStart.statusCode, 202);
  const otpStartBody = parseJson<{
    verificationId: string;
    developmentOtpHint?: string;
  }>(otpStart.body);
  assert.match(otpStartBody.verificationId, /^otp_/);
  assert.equal(otpStartBody.developmentOtpHint, "123456");

  const otpVerify = await app.inject({
    method: "POST",
    url: "/auth/otp/verify",
    payload: {
      phoneNumber: "+919999999999",
      verificationId: otpStartBody.verificationId,
      otpCode: "123456"
    }
  });

  assert.equal(otpVerify.statusCode, 200);
  const authBody = parseJson<{
    accountToken: string;
  }>(otpVerify.body);
  assert.match(authBody.accountToken, /^acct_/);

  const entitlements = await app.inject({
    method: "POST",
    url: "/entitlements/refresh",
    payload: {
      accountToken: authBody.accountToken,
      platform: "android",
      appVersion: "1.0.0",
      deviceIdHash: "a1b2c3d4e5f6a7b8"
    }
  });

  assert.equal(entitlements.statusCode, 200);
  const entitlementBody = parseJson<{
    entitlement: {
      signature: string;
      payload: {
        tier: string;
      };
    };
  }>(entitlements.body);
  assert.match(entitlementBody.entitlement.signature, /^[a-f0-9]{64}$/);
  assert.equal(entitlementBody.entitlement.payload.tier, "case_associate");

  const modelCatalog = await app.inject({
    method: "GET",
    url: "/model-catalog?platform=android"
  });

  assert.equal(modelCatalog.statusCode, 200);
  const catalogBody = parseJson<{
    manifest: {
      signature: string;
      payload: {
        packs: Array<{
          packId: string;
          artifactKind: string;
          runtimeMode: string;
          developmentOnly: boolean;
          checksumSha256: string;
          segmentCount: number;
          segmentSizeBytes: number;
        }>;
      };
    };
  }>(modelCatalog.body);
  assert.match(catalogBody.manifest.signature, /^[a-f0-9]{64}$/);
  assert.deepEqual(
    catalogBody.manifest.payload.packs.map((pack) => pack.packId).sort(),
    [
      "gemma3-case-associate-mediapipe-task",
      "gemma3-quick-start-mediapipe-task",
      "gemma3-senior-drafting-support-mediapipe-task"
    ]
  );
  for (const pack of catalogBody.manifest.payload.packs) {
    assert.equal(pack.artifactKind, "huggingface_gated_model_artifact");
    assert.equal(pack.runtimeMode, "mediapipe_llm");
    assert.equal(pack.developmentOnly, false);
    assert.match(pack.checksumSha256, /^[a-f0-9]{64}$/);
    assert.equal(pack.segmentCount, 1);
    assert.ok(pack.segmentSizeBytes >= 1);
  }

  const modelDownload = await app.inject({
    method: "POST",
    url: "/model-download/session",
    payload: {
      accountToken: authBody.accountToken,
      packId: catalogBody.manifest.payload.packs[0]?.packId ?? "gemma3-quick-start-mediapipe-task",
      platform: "android",
      appVersion: "1.0.0",
      deviceIdHash: "a1b2c3d4e5f6a7b8"
    }
  });

  assert.equal(modelDownload.statusCode, 200);
  const modelDownloadBody = parseJson<{
    downloadSession: {
      signature: string;
      payload: {
        deliveryMode: string;
        artifactKind: string;
        runtimeMode: string;
        developmentOnly: boolean;
        artifact: {
          downloadPath: string;
          downloadUrl: string;
          sizeBytes: number;
          finalSha256: string;
          artifactKind: string;
          runtimeMode: string;
          developmentOnly: boolean;
          segmentSizeBytes: number;
          segmentCount: number;
          segments: Array<{
            index: number;
            startByte: number;
            endByteInclusive: number;
            sizeBytes: number;
            sha256: string;
            rangeHeader: string;
          }>;
        };
      };
    };
  }>(modelDownload.body);
  assert.match(modelDownloadBody.downloadSession.signature, /^[a-f0-9]{64}$/);
  assert.equal(modelDownloadBody.downloadSession.payload.deliveryMode, "signed_segmented_local_model_artifact");
  assert.equal(modelDownloadBody.downloadSession.payload.artifactKind, "huggingface_gated_model_artifact");
  assert.equal(modelDownloadBody.downloadSession.payload.runtimeMode, "mediapipe_llm");
  assert.equal(modelDownloadBody.downloadSession.payload.developmentOnly, false);
  assert.match(
    modelDownloadBody.downloadSession.payload.artifact.downloadPath,
    /^\/model-download\/artifacts\//
  );
  assert.match(
    modelDownloadBody.downloadSession.payload.artifact.downloadUrl,
    /^https:\/\/huggingface\.co\//
  );
  assert.match(modelDownloadBody.downloadSession.payload.artifact.finalSha256, /^[a-f0-9]{64}$/);
  assert.equal(modelDownloadBody.downloadSession.payload.artifact.artifactKind, "huggingface_gated_model_artifact");
  assert.equal(modelDownloadBody.downloadSession.payload.artifact.runtimeMode, "mediapipe_llm");
  assert.equal(modelDownloadBody.downloadSession.payload.artifact.developmentOnly, false);
  assert.ok(modelDownloadBody.downloadSession.payload.artifact.segmentSizeBytes >= 1);
  assert.equal(
    modelDownloadBody.downloadSession.payload.artifact.segments.length,
    modelDownloadBody.downloadSession.payload.artifact.segmentCount
  );

  let expectedStartByte = 0;
  let totalBytes = 0;

  for (const segment of modelDownloadBody.downloadSession.payload.artifact.segments) {
    assert.equal(segment.startByte, expectedStartByte);
    assert.equal(segment.endByteInclusive - segment.startByte + 1, segment.sizeBytes);
    assert.match(segment.sha256, /^[a-f0-9]{64}$/);
    assert.equal(segment.rangeHeader, `bytes=${segment.startByte}-${segment.endByteInclusive}`);
    expectedStartByte = segment.endByteInclusive + 1;
    totalBytes += segment.sizeBytes;
  }

  assert.equal(totalBytes, modelDownloadBody.downloadSession.payload.artifact.sizeBytes);

  const firstSegment = modelDownloadBody.downloadSession.payload.artifact.segments[0];
  assert.ok(firstSegment);

  const artifactRange = await app.inject({
    method: "GET",
    url: modelDownloadBody.downloadSession.payload.artifact.downloadPath,
    headers: {
      range: firstSegment.rangeHeader,
      "x-ross-account-token": authBody.accountToken
    }
  });

  assert.equal(artifactRange.statusCode, 409);
  assert.match(artifactRange.body, /huggingface_token_required/);

  const stripeWebhook = await app.inject({
    method: "POST",
    url: "/billing/stripe/webhook",
    payload: {
      id: "evt_test_001",
      type: "checkout.session.completed"
    }
  });

  assert.equal(stripeWebhook.statusCode, 200);
  assert.equal(parseJson<{ provider: string }>(stripeWebhook.body).provider, "stripe");

  const razorpayWebhook = await app.inject({
    method: "POST",
    url: "/billing/razorpay/webhook",
    payload: {
      id: "evt_test_002",
      event: "payment.captured"
    }
  });

  assert.equal(razorpayWebhook.statusCode, 200);
  assert.equal(parseJson<{ provider: string }>(razorpayWebhook.body).provider, "razorpay");

  const publicSearch = await app.inject({
    method: "POST",
    url: "/public-law/search",
    payload: {
      query: "latest arbitration law",
      jurisdiction: "IN-ALL",
      language: "en",
      confirmedPublicPreview: true
    }
  });

  assert.equal(publicSearch.statusCode, 503);
  assert.match(publicSearch.body, /public_law_gemini_unavailable/);
  assert.doesNotMatch(publicSearch.body, /backend_fixture_index/);
});

test("external debug model metadata appears only when explicitly enabled", async (t) => {
  const disabledApp = await buildApp({
    env: buildTestEnv(),
    emitLogsToConsole: false
  });
  const enabledApp = await buildApp({
    env: buildTestEnv({
      ROSS_ENABLE_EXTERNAL_MODEL_METADATA: "1",
      ROSS_EXTERNAL_MODEL_RUNTIME: "mediapipe_llm",
      ROSS_EXTERNAL_MODEL_KIND: "external_debug_model",
      ROSS_EXTERNAL_MODEL_SHA256: "a".repeat(64),
      ROSS_EXTERNAL_MODEL_SIZE_BYTES: "4096",
      ROSS_EXTERNAL_MODEL_DISPLAY_NAME: "Case Associate Local Debug Model",
      ROSS_EXTERNAL_MODEL_MIN_APP_VERSION: "0.2.0"
    }),
    emitLogsToConsole: false
  });

  t.after(async () => {
    await disabledApp.close();
    await enabledApp.close();
  });

  const disabledCatalog = await disabledApp.inject({
    method: "GET",
    url: "/model-catalog?platform=android"
  });
  const enabledCatalog = await enabledApp.inject({
    method: "GET",
    url: "/model-catalog?platform=android"
  });

  const disabledBody = parseJson<{
    manifest: { payload: { packs: Array<{ artifactKind: string }> } };
  }>(disabledCatalog.body);
  const enabledBody = parseJson<{
    manifest: {
      payload: {
        packs: Array<{
          packId: string;
          displayName: string;
          artifactKind: string;
          runtimeMode: string;
          developmentOnly: boolean;
          checksumSha256: string;
          sizeBytes: number;
          minimumAppVersion: string | null;
        }>;
      };
    };
  }>(enabledCatalog.body);

  assert.equal(disabledBody.manifest.payload.packs.some((pack) => pack.artifactKind === "external_debug_model"), false);

  const externalPack = enabledBody.manifest.payload.packs.find((pack) => pack.packId === "case-associate-local-debug-pack");
  assert.ok(externalPack);
  assert.equal(externalPack.displayName, "Case Associate Local Debug Model");
  assert.equal(externalPack.artifactKind, "external_debug_model");
  assert.equal(externalPack.runtimeMode, "mediapipe_llm");
  assert.equal(externalPack.developmentOnly, true);
  assert.equal(externalPack.checksumSha256, "a".repeat(64));
  assert.equal(externalPack.sizeBytes, 4096);
  assert.equal(externalPack.minimumAppVersion, "0.2.0");
});

test("external debug model serving stays disabled by default", async (t) => {
  const app = await buildApp({
    env: buildTestEnv({
      ROSS_ENABLE_EXTERNAL_MODEL_METADATA: "1",
      ROSS_EXTERNAL_MODEL_RUNTIME: "mediapipe_llm",
      ROSS_EXTERNAL_MODEL_KIND: "external_debug_model",
      ROSS_EXTERNAL_MODEL_SHA256: "a".repeat(64),
      ROSS_EXTERNAL_MODEL_SIZE_BYTES: "4096"
    }),
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
      packId: "case-associate-local-debug-pack",
      platform: "android",
      appVersion: "1.0.0",
      deviceIdHash: "a1b2c3d4e5f6a7b8"
    }
  });

  assert.equal(response.statusCode, 403);
  assert.match(response.body, /external_model_serving_disabled/);
});

test("external debug model serving rejects unsafe in-repo paths", async (t) => {
  const app = await buildApp({
    env: buildTestEnv({
      ROSS_ENABLE_EXTERNAL_MODEL_METADATA: "1",
      ROSS_ENABLE_EXTERNAL_MODEL_SERVING: "1",
      ROSS_EXTERNAL_MODEL_RUNTIME: "mediapipe_llm",
      ROSS_EXTERNAL_MODEL_KIND: "external_debug_model",
      ROSS_EXTERNAL_MODEL_SHA256: "a".repeat(64),
      ROSS_EXTERNAL_MODEL_SIZE_BYTES: "4096",
      ROSS_EXTERNAL_MODEL_FILE_PATH: path.resolve(process.cwd(), "src/main.ts")
    }),
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
      packId: "case-associate-local-debug-pack",
      platform: "android",
      appVersion: "1.0.0",
      deviceIdHash: "a1b2c3d4e5f6a7b8"
    }
  });

  assert.equal(response.statusCode, 400);
  assert.match(response.body, /external_model_path_invalid/);
  assert.doesNotMatch(response.body, /src\/main\.ts/);
});

test("external debug model range serving works with a safe temporary file", async (t) => {
  const externalDir = mkdtempSync(path.join(tmpdir(), "ross-external-model-"));
  const externalPath = path.join(externalDir, "case-associate.task");
  const bytes = Buffer.from("ross external debug model bytes");
  writeFileSync(externalPath, bytes);

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
  const sessionBody = parseJson<{
    downloadSession: {
      payload: {
        artifact: {
          downloadPath: string;
          finalSha256: string;
          sizeBytes: number;
          segments: Array<{
            sha256: string;
            rangeHeader: string;
            startByte: number;
            endByteInclusive: number;
          }>;
        };
      };
    };
  }>(sessionResponse.body);

  const firstSegment = sessionBody.downloadSession.payload.artifact.segments[0];
  assert.ok(firstSegment);

  const rangeResponse = await app.inject({
    method: "GET",
    url: sessionBody.downloadSession.payload.artifact.downloadPath,
    headers: {
      range: firstSegment.rangeHeader
    }
  });

  assert.equal(rangeResponse.statusCode, 206);
  assert.equal(
    createHash("sha256").update(Buffer.from(rangeResponse.rawPayload)).digest("hex"),
    firstSegment.sha256
  );
  assert.equal(sessionBody.downloadSession.payload.artifact.finalSha256, createHash("sha256").update(bytes).digest("hex"));
  assert.equal(sessionBody.downloadSession.payload.artifact.sizeBytes, bytes.length);
});
