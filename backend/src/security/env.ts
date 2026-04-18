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
}

function parsePort(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) ? parsed : 8080;
}

export function readRuntimeEnv(options: { nodeEnvOverride?: string } = {}): RuntimeEnv {
  const nodeEnv = options.nodeEnvOverride ?? process.env.NODE_ENV ?? "development";

  return {
    nodeEnv,
    isProduction: nodeEnv === "production",
    port: parsePort(process.env.PORT),
    otpStubCode: process.env.OTP_STUB_CODE ?? "123456",
    entitlementSigningSecret:
      process.env.ENTITLEMENT_SIGNING_SECRET ?? "dev-entitlement-secret-change-me",
    entitlementKeyId: process.env.ENTITLEMENT_KEY_ID ?? "entitlement-dev-v1",
    manifestSigningSecret: process.env.MANIFEST_SIGNING_SECRET ?? "dev-manifest-secret-change-me",
    manifestKeyId: process.env.MANIFEST_KEY_ID ?? "manifest-dev-v1",
    downloadSigningSecret: process.env.DOWNLOAD_SIGNING_SECRET ?? "dev-download-secret-change-me",
    downloadKeyId: process.env.DOWNLOAD_KEY_ID ?? "download-dev-v1",
    stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET,
    razorpayWebhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET
  };
}
