import type { RuntimeEnv } from "../security/env.js";
import { AppError } from "../utils/http.js";
import { createId } from "../utils/ids.js";
import { signPayload } from "../utils/signing.js";
import { listModelPacks } from "../model_catalog/service.js";
import { getDevArtifactDescriptor, getExternalArtifactRecord } from "./dev_artifacts.js";

export interface ModelDownloadSessionInput {
  accountToken: string;
  packId: string;
  platform: "android" | "ios";
  deviceIdHash: string;
  appVersion: string;
}

export class ModelDownloadService {
  constructor(private readonly env: RuntimeEnv) {}

  async createSession(input: ModelDownloadSessionInput) {
    const pack = listModelPacks(this.env).find((candidate) => candidate.packId === input.packId);

    if (!pack) {
      throw new AppError(404, "unknown_model_pack", "Requested model pack does not exist.");
    }

    const artifact =
      pack.artifactKind === "external_debug_model"
        ? (await getExternalArtifactRecord(this.env, pack)).descriptor
        : getDevArtifactDescriptor(pack);
    const payload = {
      sessionId: createId("mdl"),
      packId: pack.packId,
      displayName: pack.displayName,
      tier: pack.tier,
      deliveryBoundary: "no_case_data",
      deliveryMode:
        pack.artifactKind === "external_debug_model"
          ? "signed_segmented_external_debug_artifact"
          : "signed_segmented_dev_artifact",
      artifactKind: pack.artifactKind,
      runtimeMode: pack.runtimeMode,
      developmentOnly: pack.developmentOnly,
      minimumAppVersion: pack.minimumAppVersion,
      artifact: {
        artifactId: artifact.artifactId,
        fileName: artifact.fileName,
        contentType: artifact.contentType,
        sizeBytes: artifact.sizeBytes,
        finalSha256: artifact.finalSha256,
        artifactKind: pack.artifactKind,
        runtimeMode: pack.runtimeMode,
        developmentOnly: pack.developmentOnly,
        minimumAppVersion: pack.minimumAppVersion,
        segmentSizeBytes: artifact.segmentSizeBytes,
        segmentCount: artifact.segmentCount,
        downloadPath: artifact.path,
        downloadUrl: `https://downloads.example.invalid${artifact.path}`,
        rangeUnit: "bytes",
        resumeStrategy: "range_request_segments",
        segments: artifact.segments
      },
      issuedAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 10 * 60_000).toISOString()
    };

    return {
      downloadSession: signPayload(payload, this.env.downloadSigningSecret, this.env.downloadKeyId),
      manifestReference: pack.packId
    };
  }
}
