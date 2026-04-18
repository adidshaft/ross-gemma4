use serde::{Deserialize, Serialize};
use std::cmp::Ordering;

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceKind {
    CaseFile,
    PublicLaw,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AnswerConfidence {
    Low,
    Medium,
    High,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SourceCitation {
    pub source_id: String,
    pub source_kind: SourceKind,
    pub title: String,
    pub citation_label: String,
    pub page_start: Option<u32>,
    pub page_end: Option<u32>,
    pub section: Option<String>,
    pub snippet: String,
    pub url: Option<String>,
    pub score: Option<f32>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DocumentChunk {
    pub chunk_id: String,
    pub document_id: String,
    pub title: String,
    pub source_kind: SourceKind,
    pub text: String,
    pub page_start: Option<u32>,
    pub page_end: Option<u32>,
    pub section: Option<String>,
    pub token_count: usize,
    pub char_start: usize,
    pub char_end: usize,
    pub embedding: Option<Vec<f32>>,
}

impl DocumentChunk {
    pub fn to_citation(&self, snippet: impl Into<String>, score: Option<f32>) -> SourceCitation {
        let citation_label = match (self.page_start, self.page_end) {
            (Some(start), Some(end)) if start != end => format!("pp. {start}-{end}"),
            (Some(start), _) => format!("p. {start}"),
            _ => self.title.clone(),
        };

        SourceCitation {
            source_id: self.chunk_id.clone(),
            source_kind: self.source_kind.clone(),
            title: self.title.clone(),
            citation_label,
            page_start: self.page_start,
            page_end: self.page_end,
            section: self.section.clone(),
            snippet: snippet.into(),
            url: None,
            score,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ChunkingConfig {
    pub target_chars: usize,
    pub overlap_chars: usize,
    pub min_chunk_chars: usize,
    pub respect_paragraphs: bool,
}

impl Default for ChunkingConfig {
    fn default() -> Self {
        Self {
            target_chars: 900,
            overlap_chars: 120,
            min_chunk_chars: 300,
            respect_paragraphs: true,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RedactionKind {
    Email,
    PhoneNumber,
    CaseNumber,
    FileName,
    NumericIdentifier,
    PartyName,
    LongQuote,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedactionSpan {
    pub start: usize,
    pub end: usize,
    pub kind: RedactionKind,
    pub replacement: String,
    pub original_excerpt: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedactionReport {
    pub sanitized_text: String,
    pub spans: Vec<RedactionSpan>,
    pub warnings: Vec<String>,
}

impl RedactionReport {
    pub fn removed_kinds(&self) -> Vec<RedactionKind> {
        let mut kinds = self
            .spans
            .iter()
            .map(|span| span.kind.clone())
            .collect::<Vec<_>>();
        kinds.sort();
        kinds.dedup();
        kinds
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RefusalKind {
    MissingSources,
    UnsafeQuery,
    MissingEntitlement,
    FeatureUnavailable,
    VerificationFailed,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SourceBackedAnswer {
    pub answer: String,
    pub citations: Vec<SourceCitation>,
    pub confidence: AnswerConfidence,
    pub limitations: Vec<String>,
}

impl SourceBackedAnswer {
    pub fn new(answer: impl Into<String>, citations: Vec<SourceCitation>) -> Self {
        Self {
            answer: answer.into(),
            citations,
            confidence: AnswerConfidence::Medium,
            limitations: vec!["Local scaffold uses extractive synthesis from retrieved sources.".into()],
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SourceBackedRefusal {
    pub refusal_kind: RefusalKind,
    pub reason: String,
    pub user_message: String,
    pub citations: Vec<SourceCitation>,
    pub remediation: Vec<String>,
}

impl SourceBackedRefusal {
    pub fn new(
        refusal_kind: RefusalKind,
        reason: impl Into<String>,
        user_message: impl Into<String>,
        remediation: Vec<String>,
    ) -> Self {
        Self {
            refusal_kind,
            reason: reason.into(),
            user_message: user_message.into(),
            citations: Vec::new(),
            remediation,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "payload", rename_all = "snake_case")]
pub enum AnswerEnvelope {
    Answer(SourceBackedAnswer),
    Refusal(SourceBackedRefusal),
}

impl AnswerEnvelope {
    pub fn answer(answer: impl Into<String>, citations: Vec<SourceCitation>) -> Self {
        Self::Answer(SourceBackedAnswer::new(answer, citations))
    }

    pub fn refusal(
        refusal_kind: RefusalKind,
        reason: impl Into<String>,
        user_message: impl Into<String>,
        remediation: Vec<String>,
    ) -> Self {
        Self::Refusal(SourceBackedRefusal::new(
            refusal_kind,
            reason,
            user_message,
            remediation,
        ))
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CapabilityTierId {
    QuickStart,
    CaseAssociate,
    SeniorDrafting,
}

impl CapabilityTierId {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::QuickStart => "quick_start",
            Self::CaseAssociate => "case_associate",
            Self::SeniorDrafting => "senior_drafting",
        }
    }

    pub fn rank(&self) -> u8 {
        match self {
            Self::QuickStart => 1,
            Self::CaseAssociate => 2,
            Self::SeniorDrafting => 3,
        }
    }
}

impl Ord for CapabilityTierId {
    fn cmp(&self, other: &Self) -> Ordering {
        self.rank().cmp(&other.rank())
    }
}

impl PartialOrd for CapabilityTierId {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelCapabilityTier {
    pub id: CapabilityTierId,
    pub display_name: String,
    pub subtitle: String,
    pub user_facing_description: String,
    pub approx_download_size_mb: u32,
    pub required_free_space_mb: u32,
    pub recommended_on_wifi: bool,
    pub min_ram_gb: Option<u8>,
    pub min_os_version: Option<String>,
    pub supports_long_documents: bool,
    pub supports_advanced_drafting: bool,
    pub supports_bilingual_mode: bool,
    pub hidden_technical_model_id: String,
    pub sort_order: u8,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RuntimeTarget {
    AiCore,
    AppleFoundationModels,
    Gemma 4 E4B Q4Cpp,
    Mediapipe,
    CoreMl,
    Custom,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PackPlatform {
    Android,
    Ios,
    Desktop,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PackCapability {
    Generation,
    Embeddings,
    Summarization,
    Classification,
    Bilingual,
}

impl PackCapability {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Generation => "generation",
            Self::Embeddings => "embeddings",
            Self::Summarization => "summarization",
            Self::Classification => "classification",
            Self::Bilingual => "bilingual",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelPackManifestSegment {
    pub segment_id: String,
    pub url: String,
    pub size_bytes: u64,
    pub sha256: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelPackManifest {
    pub manifest_version: String,
    pub pack_id: String,
    pub capability_tier_id: CapabilityTierId,
    pub platform: PackPlatform,
    pub runtime: RuntimeTarget,
    pub technical_model_name: String,
    pub license_name: String,
    pub download_size_bytes: u64,
    pub installed_size_bytes: u64,
    pub required_free_space_bytes: u64,
    pub sha256: String,
    pub segments: Vec<ModelPackManifestSegment>,
    pub version: String,
    pub release_date: String,
    pub is_deprecated: bool,
    pub minimum_app_version: String,
    pub capabilities: Vec<PackCapability>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InstallationState {
    NotInstalled,
    Downloading,
    Installed,
    Failed,
    VerificationPending,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct InstalledModelPack {
    pub pack_id: String,
    pub capability_tier_id: CapabilityTierId,
    pub technical_model_id: String,
    pub installed_at_ms: u64,
    pub state: InstallationState,
    pub disk_usage_bytes: u64,
    pub checksum_verified: bool,
    pub capabilities: Vec<PackCapability>,
}

impl InstalledModelPack {
    pub fn is_ready(&self) -> bool {
        self.state == InstallationState::Installed && self.checksum_verified
    }

    pub fn supports(&self, capability: &PackCapability) -> bool {
        self.capabilities.iter().any(|item| item == capability)
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PackInstallRequest {
    pub requested_tier_id: CapabilityTierId,
    pub platform: PackPlatform,
    pub available_storage_bytes: u64,
    pub wifi_connected: bool,
    pub user_approved_mobile: bool,
    pub estimated_ram_gb: Option<u8>,
    pub requested_runtime: Option<RuntimeTarget>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PackInstallPlan {
    pub allowed: bool,
    pub reasons: Vec<String>,
    pub recommended_pack_id: Option<String>,
    pub suggested_tier_id: Option<CapabilityTierId>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FeatureName {
    InstantMode,
    SourceBackedQa,
    PublicLawSearch,
    LongDocumentAnalysis,
    AdvancedDrafting,
    BilingualMode,
}

impl FeatureName {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::InstantMode => "instant_mode",
            Self::SourceBackedQa => "source_backed_qa",
            Self::PublicLawSearch => "public_law_search",
            Self::LongDocumentAnalysis => "long_document_analysis",
            Self::AdvancedDrafting => "advanced_drafting",
            Self::BilingualMode => "bilingual_mode",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct FeatureRequirement {
    pub feature: FeatureName,
    pub minimum_tier: Option<CapabilityTierId>,
    pub requires_pack_install: bool,
    pub requires_online: bool,
    pub requires_signed_entitlement: bool,
    pub required_pack_capabilities: Vec<PackCapability>,
    pub allow_extractive_fallback: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct EntitlementClaims {
    pub subject: String,
    pub issued_at_ms: u64,
    pub expires_at_ms: u64,
    pub allowed_tiers: Vec<CapabilityTierId>,
    pub enabled_features: Vec<String>,
    pub allowed_pack_ids: Vec<String>,
    pub account_tier: String,
    pub nonce: String,
}

impl EntitlementClaims {
    pub fn signing_payload(&self) -> String {
        let mut tiers = self.allowed_tiers.clone();
        tiers.sort();
        tiers.dedup();

        let mut features = self.enabled_features.clone();
        features.sort();
        features.dedup();

        let mut packs = self.allowed_pack_ids.clone();
        packs.sort();
        packs.dedup();

        format!(
            "subject={}|issued_at_ms={}|expires_at_ms={}|allowed_tiers={}|enabled_features={}|allowed_pack_ids={}|account_tier={}|nonce={}",
            self.subject,
            self.issued_at_ms,
            self.expires_at_ms,
            tiers
                .into_iter()
                .map(|tier| tier.as_str().to_string())
                .collect::<Vec<_>>()
                .join(","),
            features.join(","),
            packs.join(","),
            self.account_tier,
            self.nonce
        )
    }

    pub fn highest_allowed_tier(&self) -> Option<CapabilityTierId> {
        self.allowed_tiers.iter().copied().max()
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct EntitlementToken {
    pub claims: EntitlementClaims,
    pub key_id: String,
    pub signature_base64: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct VerifiedEntitlement {
    pub claims: EntitlementClaims,
    pub key_id: String,
    pub verified_at_ms: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct FeatureGateContext {
    pub verified_entitlement: Option<VerifiedEntitlement>,
    pub installed_packs: Vec<InstalledModelPack>,
    pub network_available: bool,
    pub extractive_fallback_available: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct FeatureGateDecision {
    pub allowed: bool,
    pub feature: FeatureName,
    pub reasons: Vec<String>,
    pub required_tier: Option<CapabilityTierId>,
    pub can_run_extractively: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AIAvailabilityStatus {
    Ready,
    ExtractiveOnly,
    Blocked,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AIAvailabilityReport {
    pub status: AIAvailabilityStatus,
    pub reasons: Vec<String>,
    pub active_tier: Option<CapabilityTierId>,
    pub installed_capabilities: Vec<PackCapability>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SanitizedPublicQuery {
    pub text: String,
    pub preview: String,
    pub search_terms: Vec<String>,
    pub removed_categories: Vec<RedactionKind>,
    pub requires_user_confirmation: bool,
    pub classification: PayloadClass,
    pub original_length: usize,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PublicLawDocument {
    pub id: String,
    pub title: String,
    pub citation: String,
    pub snippet: String,
    pub url: String,
    pub source_name: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RagQuery {
    pub text: String,
    pub top_k: usize,
    pub minimum_score: f32,
    pub source_kind: Option<SourceKind>,
}

impl RagQuery {
    pub fn new(text: impl Into<String>) -> Self {
        Self {
            text: text.into(),
            top_k: 4,
            minimum_score: 0.18,
            source_kind: Some(SourceKind::CaseFile),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RetrievalMatch {
    pub chunk: DocumentChunk,
    pub score: f32,
    pub keyword_hits: usize,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RetrievalBundle {
    pub matches: Vec<RetrievalMatch>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AuditPurpose {
    EntitlementCheck,
    ModelCatalog,
    ModelDownload,
    ModelVerification,
    PublicLawSearch,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PayloadClass {
    NoCaseData,
    AccountToken,
    SanitizedPublicQuery,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AuditEvent {
    pub id: String,
    pub timestamp_ms: u64,
    pub purpose: AuditPurpose,
    pub payload_class: PayloadClass,
    pub endpoint_label: String,
    pub success: bool,
    pub detail: String,
}
