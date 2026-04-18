export type ModelCapabilityTierId =
  | "quick_start"
  | "case_associate"
  | "senior_drafting_support";

export interface ModelCapabilityTier {
  id: ModelCapabilityTierId;
  displayName: string;
  subtitle: string;
  userFacingDescription: string;
  approxDownloadSizeMb: number;
  requiredFreeSpaceMb: number;
  recommendedOnWifi: boolean;
  minRamGb?: number;
  minOsVersion?: string;
  supportsLongDocuments: boolean;
  supportsAdvancedDrafting: boolean;
  supportsBilingualMode: boolean;
  hiddenTechnicalModelId: string;
  sortOrder: number;
}

export interface ModelPackManifestSegment {
  segmentId: string;
  url: string;
  sizeBytes: number;
  sha256: string;
}

export interface ModelPackManifest {
  manifestVersion: string;
  packId: string;
  capabilityTierId: ModelCapabilityTierId;
  platform: "android" | "ios";
  runtime:
    | "aicore"
    | "apple_foundation_models"
    | "gemma_local_runtime"
    | "mediapipe"
    | "coreml"
    | "custom";
  technicalModelName: string;
  licenseName: string;
  downloadSizeBytes: number;
  installedSizeBytes: number;
  requiredFreeSpaceBytes: number;
  sha256: string;
  segments: ModelPackManifestSegment[];
  version: string;
  releaseDate: string;
  isDeprecated: boolean;
  minimumAppVersion: string;
}

export interface ModelDownloadJob {
  id: string;
  packId: string;
  capabilityTierId: ModelCapabilityTierId;
  sessionId?: string;
  checksumSha256?: string;
  state:
    | "not_started"
    | "queued"
    | "downloading"
    | "paused_waiting_for_wifi"
    | "paused_user"
    | "paused_no_storage"
    | "paused_error"
    | "verifying"
    | "installed"
    | "failed"
    | "cancelled";
  networkPolicy: "wifi_only" | "mobile_allowed";
  bytesDownloaded: number;
  totalBytes: number;
  progressPercent: number;
  canResume: boolean;
  failureReason?: string;
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
}

export interface InstalledModelPack {
  id: string;
  packId: string;
  capabilityTierId: ModelCapabilityTierId;
  installedAt: string;
  installPath: string;
  checksumSha256: string;
  isActive: boolean;
}

export interface DeviceCapabilityProfile {
  availableStorageBytes: number;
  estimatedRamGb?: number;
  batteryPercent?: number;
  isCharging?: boolean;
  networkType: "wifi" | "mobile" | "offline" | "unknown";
  recommendedTierId: ModelCapabilityTierId;
  reason: string;
}

export interface InstantModeState {
  isAvailable: boolean;
  reason:
    | "quick_start_pack_installed"
    | "extractive_mode_only"
    | "no_model_available";
  limitations: string[];
}

export interface PrivacyLedgerEntry {
  id: string;
  timestamp: string;
  purpose:
    | "entitlement_check"
    | "model_catalog"
    | "model_download"
    | "model_verification"
    | "public_law_search";
  payloadClass: "no_case_data" | "sanitized_public_query" | "account_token";
  endpointLabel: string;
  success: boolean;
}

export interface SanitizedPublicQuery {
  query: string;
  jurisdiction: string;
  language: "en" | "hi";
  confirmedPublicPreview: true;
}

export interface SourceRef {
  caseId: string;
  documentId: string;
  documentTitle: string;
  pageNumber: number;
  paragraphRange?: string;
  textSnippet?: string;
  ocrConfidence?: number;
}

export interface PublicLawCacheItem {
  id: string;
  queryHash: string;
  query: string;
  savedAt: string;
  resultTitles: string[];
}
