import type { RuntimeEnv } from "../security/env.js";
import { createId } from "../utils/ids.js";
import { signPayload } from "../utils/signing.js";
import { getDevArtifactDescriptor } from "../model_download/dev_artifacts.js";

export type CapabilityTier = "quick_start" | "case_associate" | "senior_drafting_support";
export type ModelArtifactKind =
  | "tiny_dev_artifact"
  | "local_model_artifact"
  | "huggingface_gated_model_artifact"
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
  quantization?: "Q4" | "Q4" | "Q8" | "Q4_BLOCK128";
  userFacingRole?: string;
  technicalRole?: string;
  artifactSeed: string;
  artifactKind: ModelArtifactKind;
  runtimeMode: LocalRuntimeMode;
  developmentOnly: boolean;
  minimumAppVersion: string | null;
  downloadConfigured: boolean;
  fileName?: string;
  downloadUrl?: string;
  finalSha256?: string;
  requiresBackendProxy?: boolean;
}

export const EXTERNAL_DEBUG_PACK_ID = "case-associate-local-debug-pack";
const EXTERNAL_DEBUG_SEGMENT_SIZE_BYTES = 1_048_576;

export interface DirectDownloadArtifactDescriptor {
  artifactId: string;
  fileName: string;
  contentType: "application/octet-stream";
  sizeBytes: number;
  segmentSizeBytes: number;
  segmentCount: number;
  finalSha256: string;
  downloadUrl: string;
  downloadPath?: string;
  segments: Array<{
    index: number;
    startByte: number;
    endByteInclusive: number;
    sizeBytes: number;
    sha256: string;
    rangeHeader: string;
  }>;
}

export const DEV_MODEL_PACKS: ModelPack[] = [
  {
    packId: "quick-start-pack",
    displayName: "Basic",
    tier: "quick_start",
    sizeBytes: 25_913,
    segmentSizeBytes: 8_192,
    technicalModels: ["qwen3-0_6b-q4_0-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E2B Q4",
    repo: "google/gemma-4-e2b-q4",
    quantization: "Q4",
    userFacingRole: "Start quickly with short local Q&A and simple Ask Ross actions after setup",
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
    displayName: "Standard",
    tier: "case_associate",
    sizeBytes: 41_287,
    segmentSizeBytes: 8_192,
    technicalModels: ["qwen3-1_7b-q4_k_m-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E4B Q4",
    repo: "google/gemma-4-e4b-q4",
    alternateRepo: "jc-builds/gemma-4-e4b-q4-Q4",
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
    displayName: "Advanced",
    tier: "senior_drafting_support",
    sizeBytes: 58_633,
    segmentSizeBytes: 8_192,
    technicalModels: ["qwen3-4b-q4_k_m-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 26B-A4B Q4",
    repo: "google/gemma-4-26b-a4b-q4",
    alternateRepo: "Gemma/gemma-4-26b-a4b-q4",
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
    displayName: "Basic",
    tier: "quick_start",
    sizeBytes: 428_970_080,
    segmentSizeBytes: 428_970_080,
    technicalModels: ["qwen3-0_6b-q4_0-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E2B Q4",
    repo: "google/gemma-4-e2b-q4",
    quantization: "Q4",
    userFacingRole: "Start quickly with short local Q&A and simple Ask Ross actions after setup",
    technicalRole: "command routing, short summaries, basic local Q&A, local public-law query shaping",
    artifactSeed: "qwen3-quick-start-metadata-v1",
    artifactKind: "local_model_artifact",
    runtimeMode: "gemma_local_runtime",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: true,
    fileName: "gemma-4-e2b-q4.gguf",
    downloadUrl: "https://huggingface.co/google/gemma-4-e2b-q4/resolve/main/gemma-4-e2b-q4.gguf",
    finalSha256: "da2572f16c06133561ce56accaa822216f2391ef4d37fba427801cd6736417d4"
  },
  {
    packId: "gemma-4-e4b-q4",
    displayName: "Standard",
    tier: "case_associate",
    sizeBytes: 1_282_439_264,
    segmentSizeBytes: 1_282_439_264,
    technicalModels: ["qwen3-1_7b-q4_k_m-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E4B Q4",
    repo: "google/gemma-4-e4b-q4",
    alternateRepo: "jc-builds/gemma-4-e4b-q4-Q4",
    quantization: "Q4",
    userFacingRole: "Recommended private assistant for most matters",
    technicalRole: "default legal document assistant, document review, drafting, source-backed Ask Ross",
    artifactSeed: "qwen3-case-associate-metadata-v1",
    artifactKind: "local_model_artifact",
    runtimeMode: "gemma_local_runtime",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: true,
    fileName: "gemma-4-e4b-q4.gguf",
    downloadUrl: "https://huggingface.co/google/gemma-4-e4b-q4/resolve/main/gemma-4-e4b-q4.gguf",
    finalSha256: "d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5"
  },
  {
    packId: "gemma-4-26b-a4b-q4",
    displayName: "Advanced",
    tier: "senior_drafting_support",
    sizeBytes: 2_497_280_640,
    segmentSizeBytes: 2_497_280_640,
    technicalModels: ["qwen3-4b-q4_k_m-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 26B-A4B Q4",
    repo: "google/gemma-4-26b-a4b-q4",
    alternateRepo: "Gemma/gemma-4-26b-a4b-q4",
    quantization: "Q4",
    userFacingRole: "Advanced private assistant for deeper review and drafting",
    technicalRole: "advanced drafting, chronology refinement, issue extraction, deeper matter reasoning",
    artifactSeed: "qwen3-senior-drafting-support-metadata-v1",
    artifactKind: "local_model_artifact",
    runtimeMode: "gemma_local_runtime",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: true,
    fileName: "gemma-4-26b-a4b-q4.gguf",
    downloadUrl: "https://huggingface.co/google/gemma-4-26b-a4b-q4/resolve/main/gemma-4-26b-a4b-q4.gguf",
    finalSha256: "ab27b9bfa375a178d6cba48f3ad892b94b7739659dcc7aae8058ce0ffed6b328"
  }
];

export const PRODUCTION_IOS_MODEL_PACKS: ModelPack[] = PRODUCTION_METADATA_MODEL_PACKS;

export const PRODUCTION_ANDROID_MODEL_PACKS: ModelPack[] = [
  {
    packId: "gemma3-quick-start-mediapipe-task",
    displayName: "Basic",
    tier: "quick_start",
    sizeBytes: 303_950_933,
    segmentSizeBytes: 303_950_933,
    technicalModels: ["gemma3-270m-it-q8-mediapipe-task", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 3 270M IT Q8 MediaPipe Task",
    repo: "litert-community/gemma-3-270m-it",
    quantization: "Q8",
    userFacingRole: "Start quickly with short local Q&A and simple Ask Ross actions after setup",
    technicalRole: "command routing, short summaries, basic local Q&A, local public-law query shaping",
    artifactSeed: "gemma3-quick-start-mediapipe-v1",
    artifactKind: "huggingface_gated_model_artifact",
    runtimeMode: "mediapipe_llm",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: true,
    fileName: "gemma3-270m-it-q8.task",
    downloadUrl: "https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task",
    finalSha256: "0f7147f1c22eaf758b819bbf7841793e4c90096c9352cde7fbe5c631f2265ef5",
    requiresBackendProxy: true
  },
  {
    packId: "gemma3-case-associate-mediapipe-task",
    displayName: "Standard",
    tier: "case_associate",
    sizeBytes: 554_661_246,
    segmentSizeBytes: 554_661_246,
    technicalModels: ["gemma3-1b-it-q4-mediapipe-task", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 3 1B IT Q4 MediaPipe Task",
    repo: "litert-community/Gemma3-1B-IT",
    quantization: "Q4",
    userFacingRole: "Recommended private assistant for most matters",
    technicalRole: "default legal document assistant, document review, drafting, source-backed Ask Ross",
    artifactSeed: "gemma3-case-associate-mediapipe-v1",
    artifactKind: "huggingface_gated_model_artifact",
    runtimeMode: "mediapipe_llm",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: true,
    fileName: "Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task",
    downloadUrl: "https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task",
    finalSha256: "ddfaf1210d8b4d1b812b5fadb6652999e852c8be6dd9abe353b9213a25262c10",
    requiresBackendProxy: true
  },
  {
    packId: "gemma3-senior-drafting-support-mediapipe-task",
    displayName: "Advanced",
    tier: "senior_drafting_support",
    sizeBytes: 689_308_662,
    segmentSizeBytes: 689_308_662,
    technicalModels: ["gemma3-1b-it-q4-block128-mediapipe-task", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 3 1B IT Q4 Block128 MediaPipe Task",
    repo: "litert-community/Gemma3-1B-IT",
    quantization: "Q4_BLOCK128",
    userFacingRole: "Advanced private assistant for deeper review and drafting",
    technicalRole: "advanced drafting, chronology refinement, issue extraction, deeper matter reasoning",
    artifactSeed: "gemma3-senior-drafting-support-mediapipe-v1",
    artifactKind: "huggingface_gated_model_artifact",
    runtimeMode: "mediapipe_llm",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: true,
    fileName: "Gemma3-1B-IT_multi-prefill-seq_q4_block128_ekv4096.task",
    downloadUrl: "https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_block128_ekv4096.task",
    finalSha256: "036e15114d1868fc7be7ccc552fc8da2fe31d64af02b48847ff99f0185d37891",
    requiresBackendProxy: true
  }
];

export const MODEL_PACKS: ModelPack[] = PRODUCTION_IOS_MODEL_PACKS;

export function buildDirectDownloadArtifact(pack: ModelPack): DirectDownloadArtifactDescriptor | null {
  if (
    pack.artifactKind !== "local_model_artifact" ||
    !pack.fileName ||
    !pack.downloadUrl ||
    !pack.finalSha256 ||
    !pack.downloadConfigured ||
    pack.sizeBytes <= 0
  ) {
    return null;
  }

  return {
    artifactId: `${pack.packId}-${pack.finalSha256.slice(0, 12)}`,
    fileName: pack.fileName,
    contentType: "application/octet-stream",
    sizeBytes: pack.sizeBytes,
    segmentSizeBytes: pack.sizeBytes,
    segmentCount: 1,
    finalSha256: pack.finalSha256,
    downloadUrl: pack.downloadUrl,
    segments: [
      {
        index: 0,
        startByte: 0,
        endByteInclusive: pack.sizeBytes - 1,
        sizeBytes: pack.sizeBytes,
        sha256: pack.finalSha256,
        rangeHeader: `bytes=0-${pack.sizeBytes - 1}`
      }
    ]
  };
}

export function buildDownloadArtifact(pack: ModelPack): DirectDownloadArtifactDescriptor | null {
  if (pack.artifactKind === "local_model_artifact") {
    return buildDirectDownloadArtifact(pack);
  }

  if (
    pack.artifactKind !== "huggingface_gated_model_artifact" ||
    !pack.fileName ||
    !pack.downloadUrl ||
    !pack.finalSha256 ||
    !pack.downloadConfigured ||
    pack.sizeBytes <= 0
  ) {
    return null;
  }

  const artifactId = `${pack.packId}-${pack.finalSha256.slice(0, 12)}`;
  return {
    artifactId,
    fileName: pack.fileName,
    contentType: "application/octet-stream",
    sizeBytes: pack.sizeBytes,
    segmentSizeBytes: pack.sizeBytes,
    segmentCount: 1,
    finalSha256: pack.finalSha256,
    downloadUrl: `${pack.downloadUrl}?download=1`,
    downloadPath: `/model-download/artifacts/${artifactId}`,
    segments: [
      {
        index: 0,
        startByte: 0,
        endByteInclusive: pack.sizeBytes - 1,
        sizeBytes: pack.sizeBytes,
        sha256: pack.finalSha256,
        rangeHeader: `bytes=0-${pack.sizeBytes - 1}`
      }
    ]
  };
}

export function findDownloadPackByArtifactId(
  env: RuntimeEnv,
  platform: ModelCatalogQuery["platform"] | undefined,
  artifactId: string
): ModelPack | null {
  const platforms: Array<ModelCatalogQuery["platform"]> =
    platform === undefined ? ["android", "ios"] : [platform];
  for (const candidatePlatform of platforms) {
    for (const pack of listModelPacks(env, candidatePlatform)) {
      const artifact = buildDownloadArtifact(pack);
      if (artifact?.artifactId === artifactId) {
        return pack;
      }
    }
  }
  return null;
}

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

export function listModelPacks(env: RuntimeEnv, platform: ModelCatalogQuery["platform"] = "ios"): ModelPack[] {
  const basePacks =
    env.modelCatalogMode === "production_metadata"
      ? platform === "android"
        ? PRODUCTION_ANDROID_MODEL_PACKS
        : PRODUCTION_IOS_MODEL_PACKS
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
    const allPacks = listModelPacks(this.env, input.platform);
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

          const directArtifact = buildDownloadArtifact(pack);
          return (
            directArtifact ?? {
              sizeBytes: pack.sizeBytes,
              finalSha256: "",
              segmentSizeBytes: 0,
              segmentCount: 0,
              contentType: "application/octet-stream" as const
            }
          );
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
