export interface RuntimeEnv {
  nodeEnv: string;
  isProduction: boolean;
  port: number;
  otpStubCode: string;
  entitlementSigningSecret: string;
  entitlementKeyId: string;
  manifestSigningSecret: string;
  manifestKeyId: string;
  downloadSigningSecret: string;
  downloadKeyId: string;
  stripeWebhookSecret?: string | undefined;
  razorpayWebhookSecret?: string | undefined;
  enableExternalModelMetadata: boolean;
  externalModelRuntime?: string | undefined;
  externalModelKind?: string | undefined;
  externalModelSha256?: string | undefined;
  externalModelSizeBytes?: number | undefined;
  externalModelDisplayName?: string | undefined;
  externalModelMinAppVersion?: string | undefined;
  enableExternalModelServing: boolean;
  externalModelFilePath?: string | undefined;
}

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

function trimmedValue(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

export function readRuntimeEnv(
  options: {
    nodeEnvOverride?: string;
    environment?: Record<string, string | undefined>;
  } = {}
): RuntimeEnv {
  const environment = options.environment ?? process.env;
  const nodeEnv = options.nodeEnvOverride ?? environment.NODE_ENV ?? "development";

  return {
    nodeEnv,
    isProduction: nodeEnv === "production",
    port: parsePort(environment.PORT),
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
    externalModelFilePath: trimmedValue(environment.ROSS_EXTERNAL_MODEL_FILE_PATH)
  };
}
