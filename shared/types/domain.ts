export type ModelCapabilityTierId =
  | "quick_start"
  | "case_associate"
  | "senior_drafting_support";

export type ExtractionMode =
  | "basic"
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

export type DocumentLanguage = "english" | "hindi" | "mixed" | "unknown";
export type DocumentScript = "latin" | "devanagari" | "mixed" | "other" | "unknown";
export type LegalDocumentType =
  | "pleading"
  | "order"
  | "judgment"
  | "affidavit"
  | "notice"
  | "evidence"
  | "correspondence"
  | "misc";
export type ExtractedLegalFieldType =
  | "court"
  | "case_number"
  | "party_name"
  | "advocate_name"
  | "judge_name"
  | "date"
  | "next_date"
  | "section"
  | "relief"
  | "prayer"
  | "order_direction"
  | "limitation_date"
  | "amount"
  | "exhibit_number"
  | "fact"
  | "issue"
  | "unknown";
export type ExtractionPass =
  | "ocr"
  | "regex"
  | "llm_extract"
  | "llm_verify"
  | "user_corrected";
export type ExtractionRunStatus =
  | "queued"
  | "running"
  | "needs_review"
  | "complete"
  | "failed"
  | "cancelled";
export type ExtractionFindingKind =
  | "low_confidence_ocr"
  | "language_uncertain"
  | "possible_missing_page"
  | "date_conflict"
  | "party_conflict"
  | "case_number_conflict"
  | "ambiguous_order_direction"
  | "possible_handwriting"
  | "unsupported_layout";
export type ExtractionFindingSeverity = "info" | "warning" | "critical";
export type AdvocateCorrectionType =
  | "field_value"
  | "document_type"
  | "language"
  | "date"
  | "party"
  | "source_ref"
  | "ignore_field";
export type CaseMemoryUpdateSource =
  | "extraction_run"
  | "user_correction"
  | "ask_case"
  | "manual_note";

export interface DocumentLanguageProfilePage {
  pageNumber: number;
  language: DocumentLanguage;
  script: DocumentScript;
  confidence: number;
}

export interface DocumentLanguageProfile {
  documentId: string;
  primaryLanguage: DocumentLanguage;
  scriptsDetected: Array<"latin" | "devanagari" | "other">;
  confidence: number;
  pageProfiles: DocumentLanguageProfilePage[];
}

export interface LegalDocumentClassification {
  documentId: string;
  type: LegalDocumentType;
  subtype?: string;
  confidence: number;
  sourceRefs: SourceRef[];
  needsReview: boolean;
}

export interface ExtractedLegalField {
  id: string;
  caseId: string;
  documentId: string;
  fieldType: ExtractedLegalFieldType;
  label: string;
  value: string;
  normalizedValue?: string;
  sourceRefs: SourceRef[];
  confidence: number;
  extractionMode: ExtractionMode;
  extractionPass: ExtractionPass;
  needsReview: boolean;
  userCorrected: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ExtractionRun {
  id: string;
  caseId: string;
  documentId: string;
  mode: ExtractionMode;
  status: ExtractionRunStatus;
  startedAt?: string;
  completedAt?: string;
  pagesProcessed: number;
  totalPages: number;
  fieldsExtracted: number;
  fieldsNeedingReview: number;
  warnings: string[];
  errorMessage?: string;
}

export interface ExtractionFinding {
  id: string;
  caseId: string;
  documentId: string;
  kind: ExtractionFindingKind;
  message: string;
  sourceRefs: SourceRef[];
  severity: ExtractionFindingSeverity;
  resolved: boolean;
}

export interface AdvocateCorrection {
  id: string;
  caseId: string;
  documentId: string;
  fieldId?: string;
  oldValue?: string;
  newValue: string;
  correctionType: AdvocateCorrectionType;
  createdAt: string;
}

export interface CaseMemoryUpdate {
  id: string;
  caseId: string;
  source: CaseMemoryUpdateSource;
  summary: string;
  affectedDocuments: string[];
  createdAt: string;
}

export interface PublicLawCacheItem {
  id: string;
  queryHash: string;
  query: string;
  savedAt: string;
  resultTitles: string[];
}
