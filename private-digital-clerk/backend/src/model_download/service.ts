import type { RuntimeEnv } from "../security/env.js";
import { AppError } from "../utils/http.js";
import { createId } from "../utils/ids.js";
import { signPayload } from "../utils/signing.js";
import { MODEL_PACKS } from "../model_catalog/service.js";

export interface ModelDownloadSessionInput {
  accountToken: string;
  packId: string;
  platform: "android" | "ios";
  deviceIdHash: string;
  appVersion: string;
}

export class ModelDownloadService {
  constructor(private readonly env: RuntimeEnv) {}

  createSession(input: ModelDownloadSessionInput) {
    const pack = MODEL_PACKS.find((candidate) => candidate.packId === input.packId);

    if (!pack) {
      throw new AppError(404, "unknown_model_pack", "Requested model pack does not exist.");
    }

    const payload = {
      sessionId: createId("mdl"),
      accountTokenHash: input.accountToken.slice(0, 12),
      packId: pack.packId,
      platform: input.platform,
      deviceIdHash: input.deviceIdHash,
      appVersion: input.appVersion,
      downloadUrl: `https://downloads.example.invalid/model-packs/${pack.packId}`,
      checksumSha256: pack.checksumSha256,
      resumable: true,
      expiresAt: new Date(Date.now() + 10 * 60_000).toISOString()
    };

    return {
      downloadSession: signPayload(payload, this.env.downloadSigningSecret, this.env.downloadKeyId),
      manifestReference: pack.packId
    };
  }
}
