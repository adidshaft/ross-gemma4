import type { RuntimeEnv } from "../security/env.js";
import { createId } from "../utils/ids.js";
import { signPayload } from "../utils/signing.js";
import { getDevArtifactDescriptor } from "../model_download/dev_artifacts.js";

export type CapabilityTier = "quick_start" | "case_associate" | "senior_drafting_support";

export interface ModelPack {
  packId: string;
  displayName: string;
  tier: CapabilityTier;
  sizeBytes: number;
  segmentSizeBytes: number;
  technicalModels: string[];
  artifactSeed: string;
  artifactKind: "tiny_dev_artifact";
  runtimeMode: "deterministic_dev" | "platform_stub";
  developmentOnly: boolean;
}

export const MODEL_PACKS: ModelPack[] = [
  {
    packId: "quick-start-pack",
    displayName: "Quick Start",
    tier: "quick_start",
    sizeBytes: 25_913,
    segmentSizeBytes: 8_192,
    technicalModels: ["gemma-4-e2b-q4", "embeddinggemma-300m-int8"],
    artifactSeed: "ross-dev-quick-start-v1",
    artifactKind: "tiny_dev_artifact",
    runtimeMode: "deterministic_dev",
    developmentOnly: true
  },
  {
    packId: "case-associate-pack",
    displayName: "Case Associate",
    tier: "case_associate",
    sizeBytes: 41_287,
    segmentSizeBytes: 8_192,
    technicalModels: ["gemma-4-e4b-q4", "embeddinggemma-300m-int8"],
    artifactSeed: "ross-dev-case-associate-v1",
    artifactKind: "tiny_dev_artifact",
    runtimeMode: "deterministic_dev",
    developmentOnly: true
  },
  {
    packId: "senior-drafting-support-pack",
    displayName: "Senior Drafting Support",
    tier: "senior_drafting_support",
    sizeBytes: 58_633,
    segmentSizeBytes: 8_192,
    technicalModels: ["gemma-4-e4b-q4", "qwen3-4b-thinking-q4", "embeddinggemma-300m-int8"],
    artifactSeed: "ross-dev-senior-drafting-support-v1",
    artifactKind: "tiny_dev_artifact",
    runtimeMode: "deterministic_dev",
    developmentOnly: true
  }
];

export interface ModelCatalogQuery {
  platform: "android" | "ios";
  tier?: CapabilityTier | undefined;
}

export class ModelCatalogService {
  constructor(private readonly env: RuntimeEnv) {}

  listCatalog(input: ModelCatalogQuery) {
    const packs = input.tier ? MODEL_PACKS.filter((pack) => pack.tier === input.tier) : MODEL_PACKS;

    const payload = {
      manifestId: createId("manifest"),
      platform: input.platform,
      issuedAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
      packs: packs.map((pack) => {
        const artifact = getDevArtifactDescriptor(pack);

        return {
          packId: pack.packId,
          displayName: pack.displayName,
          tier: pack.tier,
          sizeBytes: artifact.sizeBytes,
          technicalModels: pack.technicalModels,
          checksumSha256: artifact.finalSha256,
          segmentSizeBytes: artifact.segmentSizeBytes,
          segmentCount: artifact.segmentCount,
          contentType: artifact.contentType,
          artifactKind: pack.artifactKind,
          runtimeMode: pack.runtimeMode,
          developmentOnly: pack.developmentOnly,
          resumable: true,
          deliveryBoundary: "no_case_data"
        };
      })
    };

    return {
      manifest: signPayload(payload, this.env.manifestSigningSecret, this.env.manifestKeyId),
      storagePolicy: "never_store_case_files"
    };
  }
}
