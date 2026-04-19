import type { RuntimeEnv } from "../security/env.js";
import { createId } from "../utils/ids.js";
import { signPayload } from "../utils/signing.js";
import { getDevArtifactDescriptor } from "../model_download/dev_artifacts.js";

export type CapabilityTier = "quick_start" | "case_associate" | "senior_drafting_support";
export type ModelArtifactKind =
  | "tiny_dev_artifact"
  | "local_model_artifact"
  | "system_model"
  | "external_debug_model";

export type LocalRuntimeMode =
  | "deterministic_dev"
  | "mediapipe_llm"
  | "gemma_local_runtime"
  | "apple_foundation_models"
  | "unavailable";

export interface ModelPack {
  packId: string;
  displayName: string;
  tier: CapabilityTier;
  sizeBytes: number;
  segmentSizeBytes: number;
  technicalModels: string[];
  artifactSeed: string;
  artifactKind: ModelArtifactKind;
  runtimeMode: LocalRuntimeMode;
  developmentOnly: boolean;
  minimumAppVersion: string | null;
}

export const EXTERNAL_DEBUG_PACK_ID = "case-associate-local-debug-pack";
const EXTERNAL_DEBUG_SEGMENT_SIZE_BYTES = 1_048_576;

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
    developmentOnly: true,
    minimumAppVersion: null
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
    developmentOnly: true,
    minimumAppVersion: null
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
    developmentOnly: true,
    minimumAppVersion: null
  }
];

function buildExternalDebugPack(env: RuntimeEnv): ModelPack | null {
  if (!env.enableExternalModelMetadata) {
    return null;
  }

  if (
    env.externalModelRuntime !== "mediapipe_llm" ||
    env.externalModelKind !== "external_debug_model" ||
    !env.externalModelSha256?.match(/^[a-f0-9]{64}$/i) ||
    env.externalModelSizeBytes === undefined
  ) {
    return null;
  }

  return {
    packId: EXTERNAL_DEBUG_PACK_ID,
    displayName: env.externalModelDisplayName ?? "Case Associate Local Debug Model",
    tier: "case_associate",
    sizeBytes: env.externalModelSizeBytes,
    segmentSizeBytes: EXTERNAL_DEBUG_SEGMENT_SIZE_BYTES,
    technicalModels: [],
    artifactSeed: `external-debug-${env.externalModelSha256.slice(0, 12)}`,
    artifactKind: "external_debug_model",
    runtimeMode: "mediapipe_llm",
    developmentOnly: true,
    minimumAppVersion: env.externalModelMinAppVersion ?? null
  };
}

export function listModelPacks(env: RuntimeEnv): ModelPack[] {
  const externalPack = buildExternalDebugPack(env);
  return externalPack ? [...MODEL_PACKS, externalPack] : MODEL_PACKS;
}

export interface ModelCatalogQuery {
  platform: "android" | "ios";
  tier?: CapabilityTier | undefined;
}

export class ModelCatalogService {
  constructor(private readonly env: RuntimeEnv) {}

  listCatalog(input: ModelCatalogQuery) {
    const allPacks = listModelPacks(this.env);
    const packs = input.tier ? allPacks.filter((pack) => pack.tier === input.tier) : allPacks;

    const payload = {
      manifestId: createId("manifest"),
      platform: input.platform,
      issuedAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
      packs: packs.map((pack) => {
        const artifact =
          pack.artifactKind === "tiny_dev_artifact"
            ? getDevArtifactDescriptor(pack)
            : {
                sizeBytes: pack.sizeBytes,
                finalSha256: this.env.externalModelSha256 ?? "",
                segmentSizeBytes: pack.segmentSizeBytes,
                segmentCount: Math.ceil(pack.sizeBytes / pack.segmentSizeBytes),
                contentType: "application/octet-stream" as const
              };

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
          minimumAppVersion: pack.minimumAppVersion,
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
