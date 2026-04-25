import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export interface RuntimeEnv {
  nodeEnv: string;
  isProduction: boolean;
  port: number;
  publicBaseUrl: string;
  authMobileRedirect: string;
  googleOauthClientId?: string | undefined;
  googleOauthClientSecret?: string | undefined;
  publicLawGeminiApiKey?: string | undefined;
  publicLawGeminiModel: string;
  publicLawGeminiBaseUrl: string;
  authAccessSigningSecret: string;
  authRefreshSigningSecret: string;
  otpStubCode: string;
  entitlementSigningSecret: string;
  entitlementKeyId: string;
  manifestSigningSecret: string;
  manifestKeyId: string;
  downloadSigningSecret: string;
  downloadKeyId: string;
  stripeWebhookSecret?: string | undefined;
  razorpayWebhookSecret?: string | undefined;
  modelCatalogMode: "dev" | "production_metadata";
  enableExternalModelMetadata: boolean;
  externalModelRuntime?: string | undefined;
  externalModelKind?: string | undefined;
  externalModelSha256?: string | undefined;
  externalModelSizeBytes?: number | undefined;
  externalModelDisplayName?: string | undefined;
  externalModelMinAppVersion?: string | undefined;
  enableExternalModelServing: boolean;
  externalModelFilePath?: string | undefined;
  huggingFaceAccessToken?: string | undefined;
  modelArtifactBaseUrl?: string | undefined;
  modelArtifactBearerToken?: string | undefined;
}

const backendRootDirectory = fileURLToPath(new URL("../../", import.meta.url));

function parsePort(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) ? parsed : 8080;
}

function parseBoolean(value: string | undefined): boolean {
  return ["1", "true", "yes", "on"].includes((value ?? "").trim().toLowerCase());
}

function parseOptionalPositiveInteger(value: string | undefined): number | undefined {
  const trimmed = value?.trim();
  if (!trimmed) {
    return undefined;
  }

  const parsed = Number.parseInt(trimmed, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : undefined;
}

function parseModelCatalogMode(
  value: string | undefined,
  nodeEnv: string
): "dev" | "production_metadata" {
  const normalized = (value ?? "").trim().toLowerCase();
  if (normalized === "production_metadata") {
    return "production_metadata";
  }
  if (normalized === "dev") {
    return "dev";
  }
  return nodeEnv === "test" ? "dev" : "production_metadata";
}

function trimmedValue(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

function parseEnvFileValue(rawValue: string): string {
  const trimmed = rawValue.trim();

  if (
    (trimmed.startsWith("\"") && trimmed.endsWith("\"")) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }

  return trimmed;
}

function readEnvFile(filePath: string): Record<string, string> {
  if (!existsSync(filePath)) {
    return {};
  }

  const parsed: Record<string, string> = {};
  const contents = readFileSync(filePath, "utf8");

  for (const line of contents.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (!match) {
      continue;
    }

    const key = match[1];
    const rawValue = match[2] ?? "";
    if (!key) {
      continue;
    }
    parsed[key] = parseEnvFileValue(rawValue);
  }

  return parsed;
}

function readRuntimeEnvironmentFiles(filePaths?: string[]): Record<string, string> {
  const defaultFiles = [`${backendRootDirectory}/.env`, `${backendRootDirectory}/.env.local`];
  const merged: Record<string, string> = {};

  for (const filePath of filePaths ?? defaultFiles) {
    Object.assign(merged, readEnvFile(filePath));
  }

  return merged;
}

export function readRuntimeEnv(
  options: {
    nodeEnvOverride?: string;
    environment?: Record<string, string | undefined>;
    envFiles?: string[];
  } = {}
): RuntimeEnv {
  const environment = {
    ...readRuntimeEnvironmentFiles(options.envFiles),
    ...(options.environment ?? process.env)
  } satisfies Record<string, string | undefined>;
  const nodeEnv = options.nodeEnvOverride ?? environment.NODE_ENV ?? "development";

  return {
    nodeEnv,
    isProduction: nodeEnv === "production",
    port: parsePort(environment.PORT),
    publicBaseUrl: trimmedValue(environment.ROSS_PUBLIC_BASE_URL) ?? "http://localhost:8080",
    authMobileRedirect:
      trimmedValue(environment.ROSS_AUTH_MOBILE_REDIRECT) ?? "ross://auth/callback",
    googleOauthClientId: trimmedValue(environment.GOOGLE_OAUTH_CLIENT_ID),
    googleOauthClientSecret: trimmedValue(environment.GOOGLE_OAUTH_CLIENT_SECRET),
    publicLawGeminiApiKey:
      trimmedValue(environment.ROSS_PUBLIC_LAW_GEMINI_API_KEY) ?? trimmedValue(environment.GEMINI_API_KEY),
    publicLawGeminiModel: trimmedValue(environment.ROSS_PUBLIC_LAW_GEMINI_MODEL) ?? "gemini-2.5-flash",
    publicLawGeminiBaseUrl:
      trimmedValue(environment.ROSS_PUBLIC_LAW_GEMINI_BASE_URL) ??
      "https://generativelanguage.googleapis.com",
    authAccessSigningSecret:
      environment.ROSS_AUTH_ACCESS_SIGNING_SECRET ?? "dev-ross-access-secret-change-me",
    authRefreshSigningSecret:
      environment.ROSS_AUTH_REFRESH_SIGNING_SECRET ?? "dev-ross-refresh-secret-change-me",
    otpStubCode: environment.OTP_STUB_CODE ?? "123456",
    entitlementSigningSecret:
      environment.ENTITLEMENT_SIGNING_SECRET ?? "dev-entitlement-secret-change-me",
    entitlementKeyId: environment.ENTITLEMENT_KEY_ID ?? "entitlement-dev-v1",
    manifestSigningSecret: environment.MANIFEST_SIGNING_SECRET ?? "dev-manifest-secret-change-me",
    manifestKeyId: environment.MANIFEST_KEY_ID ?? "manifest-dev-v1",
    downloadSigningSecret: environment.DOWNLOAD_SIGNING_SECRET ?? "dev-download-secret-change-me",
    downloadKeyId: environment.DOWNLOAD_KEY_ID ?? "download-dev-v1",
    stripeWebhookSecret: environment.STRIPE_WEBHOOK_SECRET,
    razorpayWebhookSecret: environment.RAZORPAY_WEBHOOK_SECRET,
    modelCatalogMode: parseModelCatalogMode(environment.ROSS_MODEL_CATALOG_MODE, nodeEnv),
    enableExternalModelMetadata: parseBoolean(environment.ROSS_ENABLE_EXTERNAL_MODEL_METADATA),
    externalModelRuntime: trimmedValue(environment.ROSS_EXTERNAL_MODEL_RUNTIME),
    externalModelKind: trimmedValue(environment.ROSS_EXTERNAL_MODEL_KIND),
    externalModelSha256: trimmedValue(environment.ROSS_EXTERNAL_MODEL_SHA256),
    externalModelSizeBytes: parseOptionalPositiveInteger(environment.ROSS_EXTERNAL_MODEL_SIZE_BYTES),
    externalModelDisplayName:
      trimmedValue(environment.ROSS_EXTERNAL_MODEL_DISPLAY_NAME) ??
      "Case Associate Local Debug Model",
    externalModelMinAppVersion: trimmedValue(environment.ROSS_EXTERNAL_MODEL_MIN_APP_VERSION),
    enableExternalModelServing: parseBoolean(environment.ROSS_ENABLE_EXTERNAL_MODEL_SERVING),
    externalModelFilePath: trimmedValue(environment.ROSS_EXTERNAL_MODEL_FILE_PATH),
    huggingFaceAccessToken:
      trimmedValue(environment.ROSS_HUGGING_FACE_ACCESS_TOKEN) ??
      trimmedValue(environment.HUGGING_FACE_HUB_TOKEN) ??
      trimmedValue(environment.HF_TOKEN),
    modelArtifactBaseUrl: trimmedValue(environment.ROSS_MODEL_ARTIFACT_BASE_URL),
    modelArtifactBearerToken: trimmedValue(environment.ROSS_MODEL_ARTIFACT_BEARER_TOKEN)
  };
}
