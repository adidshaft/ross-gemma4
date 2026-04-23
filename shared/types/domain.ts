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
  recommendedRamGb?: number;
  minOsVersion?: string;
  supportsLongDocuments: boolean;
  supportsAdvancedDrafting: boolean;
  supportsBilingualMode: boolean;
  hiddenTechnicalModelId: string;
  technicalModelName?: string;
  repo?: string;
  alternateRepo?: string;
  quantization?: "Q4" | "Q4";
  runtimeMode?: LocalRuntimeMode;
  artifactKind?: ModelArtifactKind;
  userFacingRole?: string;
  technicalRole?: string;
  retrievalModelIds?: string[];
  sortOrder: number;
}

export type ModelArtifactKind =
  | "tiny_dev_artifact"
  | "local_model_artifact"
  | "local_embedding_model"
  | "system_model"
  | "external_debug_model";

export type LocalRuntimeMode =
  | "deterministic_dev"
  | "mediapipe_llm"
  | "gemma_local_runtime"
  | "apple_foundation_models"
  | "litert"
  | "unavailable";

export interface PrivateAssistantTierRegistryEntry {
  displayName: string;
  technicalModelName: string;
  repo: string;
  alternateRepo?: string;
  quantization: "Q4" | "Q4";
  runtimeMode: "gemma_local_runtime";
  artifactKind: "local_model_artifact";
  approxDownloadSizeMb: number;
  userFacingRole: string;
  technicalRole: string;
}

export interface RetrievalModelRegistryEntry {
  displayName: "Matter Search";
  technicalModelName: string;
  repo: string;
  runtimeMode: "litert" | "gemma_local_runtime";
  artifactKind: "local_embedding_model";
  technicalRole: string;
}

export interface PrivateAssistantModelRegistry {
  assistantTiers: Record<ModelCapabilityTierId, PrivateAssistantTierRegistryEntry>;
  retrievalModels: {
    preferred: RetrievalModelRegistryEntry;
    singleRuntimeFallback: RetrievalModelRegistryEntry;
  };
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
    | "gemma_local_runtime"
    | "mediapipe"
    | "coreml"
    | "litert"
    | "custom";
  technicalModelName: string;
  licenseName: string;
  downloadSizeBytes: number;
  installedSizeBytes: number;
  requiredFreeSpaceBytes: number;
  sha256: string;
  segments: ModelPackManifestSegment[];
  artifactKind?: ModelArtifactKind;
  runtimeMode?: LocalRuntimeMode | "platform_stub";
  developmentOnly?: boolean;
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
  artifactKind?: ModelArtifactKind;
  runtimeMode?: LocalRuntimeMode | "platform_stub";
  developmentOnly?: boolean;
  isActive: boolean;
}

export type LocalModelTask =
  | "ocr_cleanup"
  | "language_correction"
  | "document_classification"
  | "legal_field_extraction"
  | "legal_field_verification"
  | "case_memory_synthesis"
  | "chronology_generation"
  | "order_summary"
  | "issue_extraction";

export type LocalModelInvocationStatus =
  | "queued"
  | "running"
  | "complete"
  | "failed"
  | "cancelled";

export interface SourceTextBlock {
  sourceRef: SourceRef;
  text: string;
  pageNumber: number;
  languageHint?: string;
  ocrConfidence?: number;
}

export interface LocalModelInput {
  task: LocalModelTask;
  instruction: string;
  sourcePack: SourceTextBlock[];
  expectedSchema: string;
  maxOutputTokens: number;
  languageProfile?: DocumentLanguageProfile;
  documentClassification?: LegalDocumentClassification;
  extractionMode: ExtractionMode;
}

export interface LocalModelOutput {
  rawText: string;
  parsedJson?: string;
  schemaValid: boolean;
  warnings: string[];
  sourceRefs: SourceRef[];
}

export interface LocalModelInvocation {
  id: string;
  task: LocalModelTask;
  caseId?: string;
  documentId?: string;
  extractionRunId?: string;
  capabilityTier: ModelCapabilityTierId;
  inputSourceRefs: SourceRef[];
  promptHash: string;
  inputHash: string;
  outputHash?: string;
  startedAt: string;
  completedAt?: string;
  status: LocalModelInvocationStatus;
  errorCategory?: string;
  localOnly: true;
}

export type ExtractionPipelineFallback = "skip" | "deterministic" | "needs_review";
export type ExtractionPipelineQuality = "Basic" | "Standard" | "Advanced";

export interface ExtractionPipelinePassPlan {
  task: LocalModelTask;
  required: boolean;
  maxPagesPerBatch: number;
  fallback: ExtractionPipelineFallback;
}

export interface ExtractionPipelinePlan {
  mode: ExtractionMode;
  passes: ExtractionPipelinePassPlan[];
  requiresInstalledPack: boolean;
  userFacingQuality: ExtractionPipelineQuality;
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
