import type { RuntimeEnv } from "../security/env.js";
import { createId } from "../utils/ids.js";
import { signPayload } from "../utils/signing.js";

export type CapabilityTier = "quick_start" | "case_associate" | "senior_drafting_support";

export interface ModelPack {
  packId: string;
  displayName: string;
  tier: CapabilityTier;
  sizeBytes: number;
  technicalModels: string[];
  checksumSha256: string;
}

export const MODEL_PACKS: ModelPack[] = [
  {
    packId: "quick-start-pack",
    displayName: "Quick Start",
    tier: "quick_start",
    sizeBytes: 1_400_000_000,
    technicalModels: ["gemma-4-e2b-q4", "embeddinggemma-300m-int8"],
    checksumSha256: "4f91a93b6ae8c6e31e1b1ea45bc98f3554c8d9d8eaf67f257ce694cf77d2f541"
  },
  {
    packId: "case-associate-pack",
    displayName: "Case Associate",
    tier: "case_associate",
    sizeBytes: 2_600_000_000,
    technicalModels: ["gemma-4-e4b-q4", "embeddinggemma-300m-int8"],
    checksumSha256: "d8e7dc1f14b7b1c4b5cb9474ef7fa2d66b5e9e8c3ef23c80498ccf07d76f4f03"
  },
  {
    packId: "senior-drafting-support-pack",
    displayName: "Senior Drafting Support",
    tier: "senior_drafting_support",
    sizeBytes: 3_800_000_000,
    technicalModels: ["gemma-4-e4b-q4", "qwen3-4b-thinking-q4", "embeddinggemma-300m-int8"],
    checksumSha256: "7e7d41f15ec441d6a4e6478c464346a6ec638951df03d2f2fdf7f367498fbb5d"
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
      packs: packs.map((pack) => ({
        ...pack,
        resumable: true,
        deliveryBoundary: "no_case_data"
      }))
    };

    return {
      manifest: signPayload(payload, this.env.manifestSigningSecret, this.env.manifestKeyId),
      storagePolicy: "never_store_case_files"
    };
  }
}
