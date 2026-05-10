import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

import { buildApp } from "../src/main.js";
import { readRuntimeEnv } from "../src/security/env.js";

const registryPath = path.resolve(process.cwd(), "../shared/constants/privateAssistantModelRegistry.json");
const publicLawGeminiEnvKey = ["ROSS_PUBLIC_LAW_", "GEMINI", "_API_KEY"].join("");
const legacyGeminiEnvKey = ["GEMINI", "_API_KEY"].join("");

function readRegistry() {
  return JSON.parse(readFileSync(registryPath, "utf8")) as {
    assistantTiers: Record<
      string,
      {
        displayName: string;
        technicalModelName: string;
        repo: string;
        alternateRepo?: string;
        quantization: string;
        runtimeMode: string;
        artifactKind: string;
        approxDownloadSizeMb: number;
      }
    >;
    retrievalModels: Record<
      string,
      {
        displayName: string;
        technicalModelName: string;
        repo: string;
        runtimeMode: string;
        artifactKind: string;
      }
    >;
  };
}

function buildTestEnv(overrides: Record<string, string | undefined> = {}) {
  return readRuntimeEnv({
    nodeEnvOverride: "test",
    environment: {
      ...process.env,
      [publicLawGeminiEnvKey]: undefined,
      [legacyGeminiEnvKey]: undefined,
      ROSS_HUGGING_FACE_ACCESS_TOKEN: undefined,
      HUGGING_FACE_HUB_TOKEN: undefined,
      HF_TOKEN: undefined,
      ...overrides
    }
  });
}

test("canonical private assistant registry maps tiers to qwen gguf models and separate retrieval", () => {
  const registry = readRegistry();
  const quickStart = registry.assistantTiers.quick_start;
  const caseAssociate = registry.assistantTiers.case_associate;
  const seniorDrafting = registry.assistantTiers.senior_drafting_support;
  const preferredRetrieval = registry.retrievalModels.preferred;
  const fallbackRetrieval = registry.retrievalModels.singleRuntimeFallback;

  assert.ok(quickStart);
  assert.ok(caseAssociate);
  assert.ok(seniorDrafting);
  assert.ok(preferredRetrieval);
  assert.ok(fallbackRetrieval);

  assert.equal(quickStart.displayName, "Basic");
  assert.equal(quickStart.technicalModelName, "Gemma 4 E2B Q4");
  assert.equal(quickStart.repo, "google/gemma-4-e2b-q4");
  assert.equal(quickStart.quantization, "Q4");
  assert.equal(quickStart.runtimeMode, "gemma_local_runtime");
  assert.equal(quickStart.approxDownloadSizeMb, 429);

  assert.equal(caseAssociate.displayName, "Standard");
  assert.equal(caseAssociate.technicalModelName, "Gemma 4 E4B Q4");
  assert.equal(caseAssociate.repo, "google/gemma-4-e4b-q4");
  assert.equal(caseAssociate.alternateRepo, "jc-builds/gemma-4-e4b-q4-Q4");
  assert.equal(caseAssociate.quantization, "Q4");

  assert.equal(seniorDrafting.displayName, "Advanced");
  assert.equal(seniorDrafting.technicalModelName, "Gemma 4 26B-A4B Q4");
  assert.equal(seniorDrafting.repo, "google/gemma-4-26b-a4b-q4");
  assert.equal(seniorDrafting.alternateRepo, "Gemma/gemma-4-26b-a4b-q4");
  assert.equal(seniorDrafting.quantization, "Q4");

  assert.equal(preferredRetrieval.displayName, "Matter Search");
  assert.equal(preferredRetrieval.technicalModelName, "EmbeddingGemma 300M");
  assert.equal(preferredRetrieval.repo, "litert-community/embeddinggemma-300m");
  assert.equal(preferredRetrieval.runtimeMode, "litert");
  assert.equal(preferredRetrieval.artifactKind, "local_embedding_model");

  assert.equal(fallbackRetrieval.technicalModelName, "Gemma 4 Embedding");
  assert.equal(fallbackRetrieval.runtimeMode, "gemma_local_runtime");
});

test("production model catalog advertises platform runtime packs with real download descriptors", async (t) => {
  const app = await buildApp({
    env: buildTestEnv({ ROSS_MODEL_CATALOG_MODE: "production_metadata" }),
    emitLogsToConsole: false
  });

  t.after(async () => {
    await app.close();
  });

  const androidCatalog = await app.inject({
    method: "GET",
    url: "/model-catalog?platform=android"
  });

  assert.equal(androidCatalog.statusCode, 200);
  const androidBody = JSON.parse(androidCatalog.body) as {
    manifest: {
      payload: {
        packs: Array<{
          packId: string;
          displayName: string;
          tier: string;
          technicalModelName: string;
          repo: string;
          artifactKind: string;
          runtimeMode: string;
          developmentOnly: boolean;
          checksumSha256: string;
          segmentCount: number;
          downloadConfigured: boolean;
        }>;
      };
    };
  };

  assert.deepEqual(
    androidBody.manifest.payload.packs.map((pack) => pack.displayName),
    ["Basic", "Standard", "Advanced"]
  );

  const quickStart = androidBody.manifest.payload.packs.find((pack) => pack.tier === "quick_start");
  const caseAssociate = androidBody.manifest.payload.packs.find((pack) => pack.tier === "case_associate");
  const senior = androidBody.manifest.payload.packs.find((pack) => pack.tier === "senior_drafting_support");

  assert.equal(quickStart?.technicalModelName, "Gemma 3 270M IT Q8 MediaPipe Task");
  assert.equal(caseAssociate?.technicalModelName, "Gemma 3 1B IT Q4 MediaPipe Task");
  assert.equal(senior?.technicalModelName, "Gemma 3 1B IT Q4 Block128 MediaPipe Task");

  for (const pack of androidBody.manifest.payload.packs) {
    assert.equal(pack.artifactKind, "huggingface_gated_model_artifact");
    assert.equal(pack.runtimeMode, "mediapipe_llm");
    assert.equal(pack.developmentOnly, false);
    assert.match(pack.checksumSha256, /^[a-f0-9]{64}$/);
    assert.equal(pack.segmentCount, 1);
    assert.equal(pack.downloadConfigured, true);
  }

  const download = await app.inject({
    method: "POST",
    url: "/model-download/session",
    payload: {
      accountToken: "acct_test_token_1234567890",
      packId: quickStart?.packId ?? "gemma3-quick-start-mediapipe-task",
      platform: "android",
      appVersion: "1.0.0",
      deviceIdHash: "a1b2c3d4e5f6a7b8"
    }
  });

  assert.equal(download.statusCode, 200);
  const downloadBody = JSON.parse(download.body) as {
    downloadSession: {
      payload: {
        deliveryMode: string;
        artifact: {
          downloadPath?: string;
          downloadUrl: string;
          finalSha256: string;
          segmentCount: number;
        };
      };
    };
  };

  assert.equal(
    downloadBody.downloadSession.payload.deliveryMode,
    "signed_segmented_local_model_artifact"
  );
  assert.match(
    downloadBody.downloadSession.payload.artifact.downloadPath ?? "",
    /^\/model-download\/artifacts\//
  );
  assert.match(
    downloadBody.downloadSession.payload.artifact.downloadUrl,
    /^https:\/\/huggingface\.co\//
  );
  assert.match(
    downloadBody.downloadSession.payload.artifact.finalSha256,
    /^[a-f0-9]{64}$/
  );
  assert.equal(downloadBody.downloadSession.payload.artifact.segmentCount, 1);

  const gatedArtifactWithoutAccount = await app.inject({
    method: "GET",
    url: downloadBody.downloadSession.payload.artifact.downloadPath ?? "/model-download/artifacts/missing"
  });

  assert.equal(gatedArtifactWithoutAccount.statusCode, 401);
  assert.match(gatedArtifactWithoutAccount.body, /account_token_required/);

  const gatedArtifactWithoutToken = await app.inject({
    method: "GET",
    url: downloadBody.downloadSession.payload.artifact.downloadPath ?? "/model-download/artifacts/missing",
    headers: {
      "x-ross-account-token": "acct_test_token_1234567890"
    }
  });

  assert.equal(gatedArtifactWithoutToken.statusCode, 409);
  assert.match(gatedArtifactWithoutToken.body, /huggingface_token_required/);

  const mirrorApp = await buildApp({
    env: buildTestEnv({
      ROSS_MODEL_CATALOG_MODE: "production_metadata",
      ROSS_MODEL_ARTIFACT_BASE_URL: "https://models.ross.example/private-assistant",
      ROSS_MODEL_ARTIFACT_BEARER_TOKEN: "mirror-token"
    }),
    emitLogsToConsole: false
  });
  const originalFetch = globalThis.fetch;
  try {
    globalThis.fetch = (async (input, init) => {
      assert.equal(
        String(input),
        "https://models.ross.example/private-assistant/gemma3-270m-it-q8.task"
      );
      const headers = init?.headers as Record<string, string>;
      assert.equal(headers.Authorization, "Bearer mirror-token");
      assert.equal(headers.Range, "bytes=0-15");
      return new Response(Buffer.from("ross mirror bytes"), {
        status: 206,
        headers: {
          "content-type": "application/octet-stream",
          "content-length": "17",
          "content-range": "bytes 0-15/303950933"
        }
      });
    }) as typeof fetch;

    const mirroredArtifact = await mirrorApp.inject({
      method: "GET",
      url: downloadBody.downloadSession.payload.artifact.downloadPath ?? "/model-download/artifacts/missing",
      headers: {
        "x-ross-account-token": "acct_test_token_1234567890",
        range: "bytes=0-15"
      }
    });

    assert.equal(mirroredArtifact.statusCode, 206);
    assert.equal(mirroredArtifact.headers["content-range"], "bytes 0-15/303950933");
    assert.equal(mirroredArtifact.body, "ross mirror bytes");
  } finally {
    globalThis.fetch = originalFetch;
    await mirrorApp.close();
  }

  const iosCatalog = await app.inject({
    method: "GET",
    url: "/model-catalog?platform=ios"
  });

  assert.equal(iosCatalog.statusCode, 200);
  const iosBody = JSON.parse(iosCatalog.body) as typeof androidBody;
  const iosQuickStart = iosBody.manifest.payload.packs.find((pack) => pack.tier === "quick_start");
  assert.equal(iosQuickStart?.technicalModelName, "Gemma 4 E2B Q4");
  assert.equal(iosQuickStart?.runtimeMode, "gemma_local_runtime");
  assert.equal(iosQuickStart?.artifactKind, "local_model_artifact");
});
