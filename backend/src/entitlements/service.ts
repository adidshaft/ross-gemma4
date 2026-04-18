import { createId } from "../utils/ids.js";
import { signPayload } from "../utils/signing.js";
import type { RuntimeEnv } from "../security/env.js";

export interface RefreshEntitlementsInput {
  accountToken: string;
  platform: "android" | "ios";
  appVersion: string;
  deviceIdHash: string;
}

export class EntitlementsService {
  constructor(private readonly env: RuntimeEnv) {}

  refresh(input: RefreshEntitlementsInput) {
    const payload = {
      entitlementId: createId("entl"),
      accountTokenHash: input.accountToken.slice(0, 12),
      platform: input.platform,
      appVersion: input.appVersion,
      deviceIdHash: input.deviceIdHash,
      tier: "case_associate",
      features: ["model_catalog", "model_download", "public_law_search"],
      issuedAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60_000).toISOString(),
      storagePolicy: "no_case_files"
    };

    return {
      entitlement: signPayload(payload, this.env.entitlementSigningSecret, this.env.entitlementKeyId),
      signaturePolicy: "stub-hmac-sha256"
    };
  }
}
