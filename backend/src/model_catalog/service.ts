import type { RuntimeEnv } from "../security/env.js";
import { createId } from "../utils/ids.js";
import { signPayload } from "../utils/signing.js";
import { getDevArtifactDescriptor } from "../model_download/dev_artifacts.js";

export type CapabilityTier = "quick_start" | "case_associate" | "senior_drafting_support";
export type ModelArtifactKind =
  | "tiny_dev_artifact"
  | "local_model_artifact"
  | "mlx_directory"
  | "huggingface_gated_model_artifact"
  | "system_model"
  | "external_debug_model";

export type LocalRuntimeMode =
  | "deterministic_dev"
  | "mediapipe_llm"
  | "gemma_local_runtime"
  | "mlx_swift_lm"
  | "apple_foundation_models"
  | "unavailable";

export interface ModelPackDraftArtifact {
  fileName: string;
  sizeBytes: number;
  finalSha256: string;
  artifactKind: ModelArtifactKind;
  downloadUrl: string;
  draftTokens?: number | undefined;
}

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
  quantization?: "Q4" | "Q8" | "Q4_BLOCK128" | "UD-Q4_K_XL";
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
  draftArtifact?: ModelPackDraftArtifact | undefined;
  requiresBackendProxy?: boolean;
  verified: boolean;
  releaseReady: boolean;
  downloadSource: string;
  licenseNotice: string;
  safetyNotice: string;
  isActiveTier: boolean;
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
    displayName: "Quick Start",
    tier: "quick_start",
    sizeBytes: 25_913,
    segmentSizeBytes: 8_192,
    technicalModels: ["gemma4-e4b-ud-q4_k_xl-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E4B UD Q4_K_XL",
    repo: "unsloth/gemma-4-E4B-it-qat-GGUF",
    quantization: "UD-Q4_K_XL",
    userFacingRole: "Balanced local assistant for short case Q&A, intake review, and lighter matter work",
    technicalRole: "short source-backed Ask Ross answers, lighter summaries, and quick matter review",
    artifactSeed: "ross-dev-quick-start-v1",
    artifactKind: "tiny_dev_artifact",
    runtimeMode: "deterministic_dev",
    developmentOnly: true,
    minimumAppVersion: null,
    downloadConfigured: true,
    verified: false,
    releaseReady: false,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  },
  {
    packId: "case-associate-pack",
    displayName: "Case Associate",
    tier: "case_associate",
    sizeBytes: 41_287,
    segmentSizeBytes: 8_192,
    technicalModels: ["gemma4-12b-ud-q4_k_xl-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 12B UD Q4_K_XL",
    repo: "unsloth/gemma-4-12B-it-qat-GGUF",
    quantization: "UD-Q4_K_XL",
    userFacingRole: "Recommended private assistant for richer matter review, larger files, and longer answers",
    technicalRole: "default higher-quality legal assistant, deeper matter reasoning, and longer source-backed Ask Ross",
    artifactSeed: "ross-dev-case-associate-v1",
    artifactKind: "tiny_dev_artifact",
    runtimeMode: "deterministic_dev",
    developmentOnly: true,
    minimumAppVersion: null,
    downloadConfigured: true,
    verified: false,
    releaseReady: false,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  },
  {
    packId: "senior-drafting-support-pack",
    displayName: "Senior Drafting Support",
    tier: "senior_drafting_support",
    sizeBytes: 58_633,
    segmentSizeBytes: 8_192,
    technicalModels: ["gemma4-26b-a4b-ud-q4_k_xl-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 26B-A4B UD Q4_K_XL",
    repo: "unsloth/gemma-4-26B-A4B-it-qat-GGUF",
    quantization: "UD-Q4_K_XL",
    userFacingRole: "Senior Drafting Support private assistant for deeper review and drafting",
    technicalRole: "advanced drafting, chronology refinement, issue extraction, deeper matter reasoning",
    artifactSeed: "ross-dev-senior-drafting-support-v1",
    artifactKind: "tiny_dev_artifact",
    runtimeMode: "deterministic_dev",
    developmentOnly: true,
    minimumAppVersion: null,
    downloadConfigured: true,
    verified: false,
    releaseReady: false,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  }
];

export const PRODUCTION_METADATA_MODEL_PACKS: ModelPack[] = [
  {
    packId: "gemma-4-e4b-q4",
    displayName: "Quick Start",
    tier: "quick_start",
    sizeBytes: 4_215_693_760,
    segmentSizeBytes: 4_215_693_760,
    technicalModels: ["gemma4-e4b-ud-q4_k_xl-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 E4B UD Q4_K_XL",
    repo: "unsloth/gemma-4-E4B-it-qat-GGUF",
    quantization: "UD-Q4_K_XL",
    userFacingRole: "Balanced local assistant for short case Q&A, intake review, and lighter matter work",
    technicalRole: "short source-backed Ask Ross answers, lighter summaries, and quick matter review",
    artifactSeed: "gemma4-e4b-basic-metadata-v3",
    artifactKind: "local_model_artifact",
    runtimeMode: "gemma_local_runtime",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: true,
    fileName: "gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf",
    downloadUrl: "https://huggingface.co/unsloth/gemma-4-E4B-it-qat-GGUF/resolve/main/gemma-4-E4B-it-qat-UD-Q4_K_XL.gguf",
    finalSha256: "b3052f962d6449b4eb2075733c068bdec1c51eadb7b237e6c3157bfbb7b1dae0",
    draftArtifact: {
      fileName: "mtp-gemma-4-E4B-it.gguf",
      sizeBytes: 59_676_544,
      finalSha256: "b0005dc39d47ede950c3ec413cb20e832f15b216126eae368d9f572676153cb6",
      artifactKind: "local_model_artifact",
      downloadUrl: "https://huggingface.co/unsloth/gemma-4-E4B-it-qat-GGUF/resolve/main/mtp-gemma-4-E4B-it.gguf"
    },
    verified: true,
    releaseReady: true,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  },
  {
    packId: "gemma-4-12b-q4",
    displayName: "Case Associate",
    tier: "case_associate",
    sizeBytes: 6_716_355_328,
    segmentSizeBytes: 6_716_355_328,
    technicalModels: ["gemma4-12b-ud-q4_k_xl-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 12B UD Q4_K_XL",
    repo: "unsloth/gemma-4-12B-it-qat-GGUF",
    quantization: "UD-Q4_K_XL",
    userFacingRole: "Recommended private assistant for richer matter review, larger files, and longer answers",
    technicalRole: "default higher-quality legal assistant, deeper matter reasoning, and longer source-backed Ask Ross",
    artifactSeed: "gemma4-12b-standard-metadata-v2",
    artifactKind: "local_model_artifact",
    runtimeMode: "gemma_local_runtime",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: true,
    fileName: "gemma-4-12B-it-qat-UD-Q4_K_XL.gguf",
    downloadUrl: "https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF/resolve/main/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf",
    finalSha256: "cc9ff072e0a8203429ed854e6662c17a6c2bc1e5dca5b475dd4736caaacbc165",
    draftArtifact: {
      fileName: "mtp-gemma-4-12b-it.gguf",
      sizeBytes: 253_707_328,
      finalSha256: "c50c91c35f04903815b2e8930cbb8c8c5bee0e1aa00748c30a7b8ff05d2310b4",
      artifactKind: "local_model_artifact",
      downloadUrl: "https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF/resolve/main/mtp-gemma-4-12B-it.gguf"
    },
    verified: true,
    releaseReady: true,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  },
  {
    packId: "gemma-4-26b-a4b-q4",
    displayName: "Senior Drafting Support",
    tier: "senior_drafting_support",
    sizeBytes: 14_249_045_120,
    segmentSizeBytes: 14_249_045_120,
    technicalModels: ["gemma4-26b-a4b-ud-q4_k_xl-gguf", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 4 26B-A4B UD Q4_K_XL",
    repo: "unsloth/gemma-4-26B-A4B-it-qat-GGUF",
    quantization: "UD-Q4_K_XL",
    userFacingRole: "Senior Drafting Support private assistant for deeper review and drafting",
    technicalRole: "advanced drafting, chronology refinement, issue extraction, deeper matter reasoning",
    artifactSeed: "gemma4-26b-advanced-metadata-v2",
    artifactKind: "local_model_artifact",
    runtimeMode: "gemma_local_runtime",
    developmentOnly: false,
    minimumAppVersion: null,
    downloadConfigured: true,
    fileName: "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf",
    downloadUrl: "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-qat-GGUF/resolve/main/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf",
    finalSha256: "dcf179a91153e3a7ece792e48ef872180d9d6ef9b7677f0a0bd3e83cfe624d5e",
    draftArtifact: {
      fileName: "mtp-gemma-4-26B-A4B-it.gguf",
      sizeBytes: 251_937_728,
      finalSha256: "62bd3af7f66c9308de9a5454233852f8c7324c93767e8dfb824ed45b9179864a",
      artifactKind: "local_model_artifact",
      downloadUrl: "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-qat-GGUF/resolve/main/mtp-gemma-4-26B-A4B-it.gguf"
    },
    verified: true,
    releaseReady: true,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  }
];

export const PRODUCTION_IOS_MODEL_PACKS: ModelPack[] = [
  ...PRODUCTION_METADATA_MODEL_PACKS,
  {
    ...PRODUCTION_METADATA_MODEL_PACKS.find((pack) => pack.tier === "quick_start")!,
    packId: "gemma-4-e4b-mlx",
    sizeBytes: 6_830_818_938,
    segmentSizeBytes: 6_830_818_938,
    technicalModelName: "Gemma 4 E4B QAT 4-bit (MLX)",
    repo: "mlx-community/gemma-4-E4B-it-qat-4bit",
    artifactSeed: "gemma4-e4b-mlx-metadata-v1",
    artifactKind: "mlx_directory",
    runtimeMode: "mlx_swift_lm",
    fileName: "gemma-4-E4B-it-qat-4bit",
    downloadUrl: "https://huggingface.co/mlx-community/gemma-4-E4B-it-qat-4bit",
    finalSha256: "f62f14fb4ab2795f9ed17f7d5cbf9d40672c34fbfde875c7b590ce04914eb25f",
    draftArtifact: {
      fileName: "gemma-4-E4B-it-qat-assistant-6bit",
      sizeBytes: 97_064_255,
      finalSha256: "6541d883bcf462e19640a309f6b540fb6a24898d451d796cb535c0d897fb41a1",
      artifactKind: "mlx_directory",
      downloadUrl: "https://huggingface.co/mlx-community/gemma-4-E4B-it-qat-assistant-6bit"
    },
    downloadSource: "direct"
  },
  {
    ...PRODUCTION_METADATA_MODEL_PACKS.find((pack) => pack.tier === "case_associate")!,
    packId: "gemma-4-12b-mlx",
    sizeBytes: 11_020_140_534,
    segmentSizeBytes: 11_020_140_534,
    technicalModelName: "Gemma 4 12B QAT 4-bit (MLX)",
    repo: "mlx-community/gemma-4-12B-it-qat-4bit",
    artifactSeed: "gemma4-12b-mlx-metadata-v1",
    artifactKind: "mlx_directory",
    runtimeMode: "mlx_swift_lm",
    fileName: "gemma-4-12B-it-qat-4bit",
    downloadUrl: "https://huggingface.co/mlx-community/gemma-4-12B-it-qat-4bit",
    finalSha256: "21978d82c01abd20e40f3ea6fe638831f9d7a77db39617181ba9a9fe880125fc",
    draftArtifact: {
      fileName: "gemma-4-12B-it-qat-assistant-4bit",
      sizeBytes: 270_097_044,
      finalSha256: "9106d7a467fae26d231f71c617acb950bc0651917f3861cad89a4c67957f0a4f",
      artifactKind: "mlx_directory",
      downloadUrl: "https://huggingface.co/mlx-community/gemma-4-12B-it-qat-assistant-4bit"
    },
    downloadSource: "direct"
  },
  {
    ...PRODUCTION_METADATA_MODEL_PACKS.find((pack) => pack.tier === "senior_drafting_support")!,
    packId: "gemma-4-26b-a4b-mlx",
    sizeBytes: 15_641_241_228,
    segmentSizeBytes: 15_641_241_228,
    technicalModelName: "Gemma 4 26B-A4B QAT 4-bit (MLX)",
    repo: "mlx-community/gemma-4-26B-A4B-it-qat-4bit",
    artifactSeed: "gemma4-26b-mlx-metadata-v1",
    artifactKind: "mlx_directory",
    runtimeMode: "mlx_swift_lm",
    fileName: "gemma-4-26B-A4B-it-qat-4bit",
    downloadUrl: "https://huggingface.co/mlx-community/gemma-4-26B-A4B-it-qat-4bit",
    finalSha256: "853a863cb5f21d6bd677c869f76a5daead32bdf45a3a82775c9a1428764dd654",
    draftArtifact: {
      fileName: "gemma-4-26B-A4B-it-qat-assistant-4bit",
      sizeBytes: 268_327_387,
      finalSha256: "702b480752e77c1d069b08379f307b32a73af42320e1c6571809c6535c1e71c2",
      artifactKind: "mlx_directory",
      downloadUrl: "https://huggingface.co/mlx-community/gemma-4-26B-A4B-it-qat-assistant-4bit"
    },
    downloadSource: "direct"
  }
];

export const PRODUCTION_ANDROID_MODEL_PACKS: ModelPack[] = [
  {
    packId: "gemma3-quick-start-mediapipe-task",
    displayName: "Quick Start",
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
    requiresBackendProxy: true,
    verified: false,
    releaseReady: false,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  },
  {
    packId: "gemma3-case-associate-mediapipe-task",
    displayName: "Case Associate",
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
    requiresBackendProxy: true,
    verified: false,
    releaseReady: false,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  },
  {
    packId: "gemma3-senior-drafting-support-mediapipe-task",
    displayName: "Senior Drafting Support",
    tier: "senior_drafting_support",
    sizeBytes: 689_308_662,
    segmentSizeBytes: 689_308_662,
    technicalModels: ["gemma3-1b-it-q4-block128-mediapipe-task", "embeddinggemma-300m-litert"],
    technicalModelName: "Gemma 3 1B IT Q4 Block128 MediaPipe Task",
    repo: "litert-community/Gemma3-1B-IT",
    quantization: "Q4_BLOCK128",
    userFacingRole: "Senior Drafting Support private assistant for deeper review and drafting",
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
    requiresBackendProxy: true,
    verified: false,
    releaseReady: false,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  }
];

export const MODEL_PACKS: ModelPack[] = PRODUCTION_IOS_MODEL_PACKS;

export function buildDirectDownloadArtifact(pack: ModelPack): DirectDownloadArtifactDescriptor | null {
  if (
    (pack.artifactKind !== "local_model_artifact" && pack.artifactKind !== "mlx_directory") ||
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
  if (pack.artifactKind === "local_model_artifact" || pack.artifactKind === "mlx_directory") {
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
    downloadConfigured: true,
    verified: false,
    releaseReady: false,
    downloadSource: "huggingface",
    licenseNotice: "Gemma License",
    safetyNotice: "Review generated content.",
    isActiveTier: true
  };
}

function buildAdditionalIOSMLXPacks(env: RuntimeEnv): ModelPack[] {
  return env.iosAdditionalMLXPacks.flatMap((config) => {
    const basePack = PRODUCTION_METADATA_MODEL_PACKS.find((candidate) => candidate.tier === config.tier);
    if (!basePack) {
      return [];
    }

    const resolvedRepo = config.repo ?? basePack.repo;
    const resolvedAlternateRepo = config.alternateRepo ?? basePack.alternateRepo;

    return [
      {
        ...basePack,
        packId: config.packId,
        sizeBytes: config.sizeBytes,
        segmentSizeBytes: config.sizeBytes,
        technicalModels: config.technicalModels ?? basePack.technicalModels,
        technicalModelName: config.technicalModelName ?? `${basePack.technicalModelName} MLX`,
        artifactSeed: config.artifactSeed ?? `${config.packId}-metadata-v1`,
        artifactKind: "mlx_directory",
        runtimeMode: "mlx_swift_lm",
        minimumAppVersion: config.minimumAppVersion ?? basePack.minimumAppVersion,
        fileName: config.fileName,
        downloadUrl: config.downloadUrl,
        finalSha256: config.finalSha256,
        downloadSource: "direct",
        ...(resolvedRepo ? { repo: resolvedRepo } : {}),
        ...(resolvedAlternateRepo ? { alternateRepo: resolvedAlternateRepo } : {})
      }
    ];
  });
}

export function listModelPacks(env: RuntimeEnv, platform: ModelCatalogQuery["platform"] = "ios"): ModelPack[] {
  const basePacks =
    env.modelCatalogMode === "production_metadata"
      ? platform === "android"
        ? PRODUCTION_ANDROID_MODEL_PACKS
        : PRODUCTION_IOS_MODEL_PACKS
      : DEV_MODEL_PACKS;
  const externalPack = buildExternalDebugPack(env);
  const additionalIOSMLXPacks =
    env.modelCatalogMode === "production_metadata" && platform === "ios"
      ? buildAdditionalIOSMLXPacks(env)
      : [];
  const packs = [...basePacks, ...additionalIOSMLXPacks];
  return externalPack ? [...packs, externalPack] : packs;
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
          draftArtifact: pack.draftArtifact
            ? {
                fileName: pack.draftArtifact.fileName,
                sizeBytes: pack.draftArtifact.sizeBytes,
                checksumSha256: pack.draftArtifact.finalSha256,
                artifactKind: pack.draftArtifact.artifactKind,
                draftTokens: pack.draftArtifact.draftTokens
              }
            : undefined,
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
