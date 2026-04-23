import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { readRuntimeEnv } from "../src/security/env.js";

test("readRuntimeEnv loads backend-style env files and lets process env win", () => {
  const tempDirectory = mkdtempSync(path.join(tmpdir(), "ross-env-"));
  const envFilePath = path.join(tempDirectory, ".env");
  const envLocalFilePath = path.join(tempDirectory, ".env.local");

  try {
    writeFileSync(
      envFilePath,
      [
        "PORT=8787",
        "ROSS_PUBLIC_BASE_URL=http://127.0.0.1:8787",
        "ROSS_PUBLIC_LAW_GEMINI_MODEL=gemini-2.0-flash"
      ].join("\n")
    );
    writeFileSync(
      envLocalFilePath,
      [
        "ROSS_PUBLIC_LAW_GEMINI_API_KEY=local-dev-key",
        "ROSS_PUBLIC_LAW_GEMINI_MODEL=gemini-2.5-flash"
      ].join("\n")
    );

    const env = readRuntimeEnv({
      envFiles: [envFilePath, envLocalFilePath],
      environment: {
        PORT: "9797",
        ROSS_PUBLIC_BASE_URL: "http://127.0.0.1:9797",
        ROSS_PUBLIC_LAW_GEMINI_MODEL: "gemini-3-flash-preview"
      }
    });

    assert.equal(env.port, 9797);
    assert.equal(env.publicBaseUrl, "http://127.0.0.1:9797");
    assert.equal(env.publicLawGeminiApiKey, "local-dev-key");
    assert.equal(env.publicLawGeminiModel, "gemini-3-flash-preview");
  } finally {
    rmSync(tempDirectory, { recursive: true, force: true });
  }
});

test("readRuntimeEnv can load env values from local files when no explicit environment is passed", () => {
  const tempDirectory = mkdtempSync(path.join(tmpdir(), "ross-env-files-"));
  const envFilePath = path.join(tempDirectory, ".env");
  const envLocalFilePath = path.join(tempDirectory, ".env.local");

  try {
    writeFileSync(envFilePath, "PORT=8787\n");
    writeFileSync(
      envLocalFilePath,
      [
        "ROSS_PUBLIC_BASE_URL=http://127.0.0.1:8787",
        "ROSS_PUBLIC_LAW_GEMINI_API_KEY=local-dev-key",
        "ROSS_PUBLIC_LAW_GEMINI_MODEL=gemini-2.5-flash"
      ].join("\n")
    );

    const env = readRuntimeEnv({
      envFiles: [envFilePath, envLocalFilePath],
      environment: {}
    });

    assert.equal(env.port, 8787);
    assert.equal(env.publicBaseUrl, "http://127.0.0.1:8787");
    assert.equal(env.publicLawGeminiApiKey, "local-dev-key");
    assert.equal(env.publicLawGeminiModel, "gemini-2.5-flash");
  } finally {
    rmSync(tempDirectory, { recursive: true, force: true });
  }
});

test("readRuntimeEnv defaults model catalog to dev and accepts production metadata mode", () => {
  assert.equal(readRuntimeEnv({ environment: {} }).modelCatalogMode, "dev");
  assert.equal(
    readRuntimeEnv({ environment: { ROSS_MODEL_CATALOG_MODE: "production_metadata" } }).modelCatalogMode,
    "production_metadata"
  );
  assert.equal(
    readRuntimeEnv({ environment: { ROSS_MODEL_CATALOG_MODE: "unexpected" } }).modelCatalogMode,
    "dev"
  );
});
