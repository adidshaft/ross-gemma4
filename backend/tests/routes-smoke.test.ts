import assert from "node:assert/strict";
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
        packs: Array<{ packId: string }>;
      };
    };
  }>(modelCatalog.body);
  assert.match(catalogBody.manifest.signature, /^[a-f0-9]{64}$/);
  assert.ok(catalogBody.manifest.payload.packs.length >= 1);

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
      payload: {
        downloadUrl: string;
      };
    };
  }>(modelDownload.body);
  assert.match(modelDownloadBody.downloadSession.payload.downloadUrl, /^https:\/\/downloads\.example\.invalid\//);

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
    results: Array<{ title: string }>;
  }>(publicSearch.body);
  assert.equal(publicSearchBody.results[0]?.title, "Public-law search result stub");
});
