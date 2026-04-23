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
  technicalModelName: string;
  repo?: string;
  alternateRepo?: string;
  quantization?: "Q4" | "Q4";
  userFacingRole?: string;
  technicalRole?: string;
  artifactSeed: string;
  artifactKind: ModelArtifactKind;
  runtimeMode: LocalRuntimeMode;
  developmentOnly: boolean;
  minimumAppVersion: string | null;
  downloadConfigured: boolean;
}

export const EXTERNAL_DEBUG_PACK_ID = "case-associate-local-debug-pack";
const EXTERNAL_DEBUG_SEGMENT_SIZE_BYTES = 1_048_576;

export const DEV_MODEL_PACKS: ModelPack[] = [
  {
    packId: "quick-start-pack",
    displayName: "Quick Start",
    tier: "quick_start",
    sizeBytes: 25_913,
    segmentSizeBytes: 8_192,
    technicalModels: ["qwen3-0_6b-q4_0-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E2B Q4",
    repo: "google/gemma-4-E2B-it",
    quantization: "Q4",
    userFacingRole: "Start quickly with basic local review and simple Ask Ross actions",
    technicalRole: "command routing, short summaries, basic local Q&A, local public-law query shaping",
    artifactSeed: "ross-dev-quick-start-v1",
    artifactKind: "tiny_dev_artifact",
    runtimeMode: "deterministic_dev",
    developmentOnly: true,
    minimumAppVersion: null,
    downloadConfigured: true
  },
  {
    packId: "case-associate-pack",
    displayName: "Case Associate",
    tier: "case_associate",
    sizeBytes: 41_287,
    segmentSizeBytes: 8_192,
    technicalModels: ["qwen3-1_7b-q4_k_m-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E4B Q4",
    repo: "google/gemma-4-E4B-it",
    alternateRepo: "google/gemma-4-E4B-it",
    quantization: "Q4",
    userFacingRole: "Recommended private assistant for most matters",
    technicalRole: "default legal document assistant, document review, drafting, source-backed Ask Ross",
    artifactSeed: "ross-dev-case-associate-v1",
    artifactKind: "tiny_dev_artifact",
    runtimeMode: "deterministic_dev",
    developmentOnly: true,
    minimumAppVersion: null,
    downloadConfigured: true
  },
  {
    packId: "senior-drafting-support-pack",
    displayName: "Senior Drafting Support",
    tier: "senior_drafting_support",
    sizeBytes: 58_633,
    segmentSizeBytes: 8_192,
    technicalModels: ["qwen3-4b-q4_k_m-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 26B-A4B Q4",
    repo: "google/gemma-4-26B-A4B-it",
    alternateRepo: "google/gemma-4-26B-A4B-it",
    quantization: "Q4",
    userFacingRole: "Advanced private assistant for deeper review and drafting",
    technicalRole: "advanced drafting, chronology refinement, issue extraction, deeper matter reasoning",
    artifactSeed: "ross-dev-senior-drafting-support-v1",
    artifactKind: "tiny_dev_artifact",
    runtimeMode: "deterministic_dev",
    developmentOnly: true,
    minimumAppVersion: null,
    downloadConfigured: true
  }
];

export const PRODUCTION_METADATA_MODEL_PACKS: ModelPack[] = [
  {
    packId: "gemma-4-e2b-q4",
    displayName: "Quick Start",
    tier: "quick_start",
    sizeBytes: 429_000_000,
    segmentSizeBytes: 0,
    technicalModels: ["qwen3-0_6b-q4_0-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E2B Q4",
    repo: "google/gemma-4-E2B-it",
    quantization: "Q4",
    userFacingRole: "Start quickly with basic local review and simple Ask Ross actions",
    technicalRole: "command routing, short summaries, basic local Q&A, local public-law query shaping",
    artifactSeed: "qwen3-quick-start-metadata-v1",
    artifactKind: "local_model_artifact",
    runtimeMode: "gemma_local_runtime",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: false
  },
  {
    packId: "gemma-4-e4b-q4",
    displayName: "Case Associate",
    tier: "case_associate",
    sizeBytes: 1_280_000_000,
    segmentSizeBytes: 0,
    technicalModels: ["qwen3-1_7b-q4_k_m-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E4B Q4",
    repo: "google/gemma-4-E4B-it",
    alternateRepo: "google/gemma-4-E4B-it",
    quantization: "Q4",
    userFacingRole: "Recommended private assistant for most matters",
    technicalRole: "default legal document assistant, document review, drafting, source-backed Ask Ross",
    artifactSeed: "qwen3-case-associate-metadata-v1",
    artifactKind: "local_model_artifact",
    runtimeMode: "gemma_local_runtime",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: false
  },
  {
    packId: "gemma-4-26b-a4b-q4",
    displayName: "Senior Drafting Support",
    tier: "senior_drafting_support",
    sizeBytes: 2_500_000_000,
    segmentSizeBytes: 0,
    technicalModels: ["qwen3-4b-q4_k_m-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 26B-A4B Q4",
    repo: "google/gemma-4-26B-A4B-it",
    alternateRepo: "google/gemma-4-26B-A4B-it",
    quantization: "Q4",
    userFacingRole: "Advanced private assistant for deeper review and drafting",
    technicalRole: "advanced drafting, chronology refinement, issue extraction, deeper matter reasoning",
    artifactSeed: "qwen3-senior-drafting-support-metadata-v1",
    artifactKind: "local_model_artifact",
    runtimeMode: "gemma_local_runtime",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: false
  }
];

export const MODEL_PACKS: ModelPack[] = DEV_MODEL_PACKS;

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
    technicalModelName: env.externalModelDisplayName ?? "Case Associate Local Debug Model",
    artifactSeed: `external-debug-${env.externalModelSha256.slice(0, 12)}`,
    artifactKind: "external_debug_model",
    runtimeMode: "mediapipe_llm",
    developmentOnly: true,
    minimumAppVersion: env.externalModelMinAppVersion ?? null,
    downloadConfigured: true
  };
}

export function listModelPacks(env: RuntimeEnv): ModelPack[] {
  const basePacks =
    env.modelCatalogMode === "production_metadata"
      ? PRODUCTION_METADATA_MODEL_PACKS
      : DEV_MODEL_PACKS;
  const externalPack = buildExternalDebugPack(env);
  return externalPack ? [...basePacks, externalPack] : basePacks;
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
        const artifact = (() => {
          if (pack.artifactKind === "tiny_dev_artifact") {
            return getDevArtifactDescriptor(pack);
          }

          if (pack.artifactKind === "external_debug_model") {
            return {
              sizeBytes: pack.sizeBytes,
              finalSha256: this.env.externalModelSha256 ?? "",
              segmentSizeBytes: pack.segmentSizeBytes,
              segmentCount: Math.ceil(pack.sizeBytes / pack.segmentSizeBytes),
              contentType: "application/octet-stream" as const
            };
          }

          return {
            sizeBytes: pack.sizeBytes,
            finalSha256: "",
            segmentSizeBytes: 0,
            segmentCount: 0,
            contentType: "application/octet-stream" as const
          };
        })();

        return {
          packId: pack.packId,
          displayName: pack.displayName,
          tier: pack.tier,
          sizeBytes: artifact.sizeBytes,
          technicalModels: pack.technicalModels,
          technicalModelName: pack.technicalModelName,
          repo: pack.repo,
          alternateRepo: pack.alternateRepo,
          quantization: pack.quantization,
          userFacingRole: pack.userFacingRole,
          technicalRole: pack.technicalRole,
          checksumSha256: artifact.finalSha256,
          segmentSizeBytes: artifact.segmentSizeBytes,
          segmentCount: artifact.segmentCount,
          contentType: artifact.contentType,
          artifactKind: pack.artifactKind,
          runtimeMode: pack.runtimeMode,
          developmentOnly: pack.developmentOnly,
          minimumAppVersion: pack.minimumAppVersion,
          downloadConfigured: pack.downloadConfigured,
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
