import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import { buildApp } from "../src/main.js";
import { readRuntimeEnv } from "../src/security/env.js";

function parseJson<T>(payload: string): T {
  return JSON.parse(payload) as T;
}

test("backend scaffold endpoints return coherent stub responses", async (t) => {
  const app = await buildApp({
    env: readRuntimeEnv({ nodeEnvOverride: "test" }),
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
    ["case-associate-pack", "quick-start-pack", "senior-drafting-support-pack"]
  );
  for (const pack of catalogBody.manifest.payload.packs) {
    assert.equal(pack.artifactKind, "tiny_dev_artifact");
    assert.match(pack.checksumSha256, /^[a-f0-9]{64}$/);
    assert.ok(pack.segmentCount >= 1);
    assert.ok(pack.segmentSizeBytes >= 1);
  }

  const modelDownload = await app.inject({
    method: "POST",
    url: "/model-download/session",
    payload: {
      accountToken: authBody.accountToken,
      packId: catalogBody.manifest.payload.packs[0]?.packId ?? "quick-start-pack",
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
        artifact: {
          downloadPath: string;
          downloadUrl: string;
          sizeBytes: number;
          finalSha256: string;
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
  assert.equal(modelDownloadBody.downloadSession.payload.deliveryMode, "signed_segmented_dev_artifact");
  assert.match(
    modelDownloadBody.downloadSession.payload.artifact.downloadPath,
    /^\/dev-artifacts\//
  );
  assert.match(
    modelDownloadBody.downloadSession.payload.artifact.downloadUrl,
    /^https:\/\/downloads\.example\.invalid\/dev-artifacts\//
  );
  assert.match(modelDownloadBody.downloadSession.payload.artifact.finalSha256, /^[a-f0-9]{64}$/);
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
      range: firstSegment.rangeHeader
    }
  });

  assert.equal(artifactRange.statusCode, 206);
  assert.equal(
    artifactRange.headers["content-range"],
    `bytes ${firstSegment.startByte}-${firstSegment.endByteInclusive}/${modelDownloadBody.downloadSession.payload.artifact.sizeBytes}`
  );
  assert.equal(
    createHash("sha256").update(Buffer.from(artifactRange.rawPayload)).digest("hex"),
    firstSegment.sha256
  );

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

  assert.equal(publicSearch.statusCode, 200);
  const publicSearchBody = parseJson<{
    connector: { mode: string };
    resultCount: number;
    results: Array<{ title: string }>;
  }>(publicSearch.body);
  assert.equal(publicSearchBody.connector.mode, "backend_fixture_index");
  assert.equal(publicSearchBody.resultCount, publicSearchBody.results.length);
  assert.match(publicSearchBody.results[0]?.title ?? "", /Act|Procedure|Evidence|injunction/i);
});
