use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExtractionMode {
    Basic,
    QuickStart,
    CaseAssociate,
    SeniorDraftingSupport,
}

impl ExtractionMode {
    pub fn quality_label(&self) -> &'static str {
        match self {
            Self::Basic => "Basic",
            Self::QuickStart => "Standard",
            Self::CaseAssociate => "Advanced",
            Self::SeniorDraftingSupport => "Advanced Plus",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SourceRef {
    pub case_id: String,
    pub document_id: String,
    pub document_title: String,
    pub page_number: u32,
    pub paragraph_range: Option<String>,
    pub text_snippet: Option<String>,
    pub ocr_confidence: Option<f32>,
}

impl SourceRef {
    pub fn label(&self) -> String {
        format!("{} p. {}", self.document_title, self.page_number)
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PageText {
    pub page_number: u32,
    pub text: String,
    pub source_ref: SourceRef,
    pub ocr_confidence: Option<f32>,
    pub layout_hint: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DocumentExtractionInput {
    pub case_id: String,
    pub document_id: String,
    pub document_title: String,
    pub mode: ExtractionMode,
    pub pages: Vec<PageText>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LegalDocumentType {
    Pleading,
    Order,
    Judgment,
    Affidavit,
    Notice,
    Evidence,
    Correspondence,
    Misc,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LegalDocumentClassification {
    pub document_id: String,
    pub r#type: LegalDocumentType,
    pub subtype: Option<String>,
    pub confidence: f32,
    pub source_refs: Vec<SourceRef>,
    pub needs_review: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LegalFieldType {
    Court,
    CaseNumber,
    PartyName,
    AdvocateName,
    JudgeName,
    Date,
    NextDate,
    Section,
    Relief,
    Prayer,
    OrderDirection,
    LimitationDate,
    Amount,
    ExhibitNumber,
    Fact,
    Issue,
    Unknown,
}

impl LegalFieldType {
    pub fn label(&self) -> &'static str {
        match self {
            Self::Court => "Court",
            Self::CaseNumber => "Case number",
            Self::PartyName => "Party",
            Self::AdvocateName => "Advocate",
            Self::JudgeName => "Judge",
            Self::Date => "Date",
            Self::NextDate => "Next date",
            Self::Section => "Section",
            Self::Relief => "Relief",
            Self::Prayer => "Prayer",
            Self::OrderDirection => "Order direction",
            Self::LimitationDate => "Limitation date",
            Self::Amount => "Amount",
            Self::ExhibitNumber => "Exhibit",
            Self::Fact => "Fact",
            Self::Issue => "Issue",
            Self::Unknown => "Unknown",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExtractionPass {
    Ocr,
    Regex,
    LlmExtract,
    LlmVerify,
    UserCorrected,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ExtractedLegalField {
    pub id: String,
    pub case_id: String,
    pub document_id: String,
    pub field_type: LegalFieldType,
    pub label: String,
    pub value: String,
    pub normalized_value: Option<String>,
    pub source_refs: Vec<SourceRef>,
    pub confidence: f32,
    pub extraction_mode: ExtractionMode,
    pub extraction_pass: ExtractionPass,
    pub needs_review: bool,
    pub user_corrected: bool,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExtractionRunStatus {
    Queued,
    Running,
    NeedsReview,
    Complete,
    Failed,
    Cancelled,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ExtractionRun {
    pub id: String,
    pub case_id: String,
    pub document_id: String,
    pub mode: ExtractionMode,
    pub status: ExtractionRunStatus,
    pub started_at: Option<String>,
    pub completed_at: Option<String>,
    pub pages_processed: u32,
    pub total_pages: u32,
    pub fields_extracted: u32,
    pub fields_needing_review: u32,
    pub warnings: Vec<String>,
    pub error_message: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExtractionFindingKind {
    LowConfidenceOcr,
    LanguageUncertain,
    PossibleMissingPage,
    DateConflict,
    PartyConflict,
    CaseNumberConflict,
    AmbiguousOrderDirection,
    PossibleHandwriting,
    UnsupportedLayout,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExtractionFindingSeverity {
    Info,
    Warning,
    Critical,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ExtractionFinding {
    pub id: String,
    pub case_id: String,
    pub document_id: String,
    pub kind: ExtractionFindingKind,
    pub message: String,
    pub source_refs: Vec<SourceRef>,
    pub severity: ExtractionFindingSeverity,
    pub resolved: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AdvocateCorrectionType {
    FieldValue,
    DocumentType,
    Language,
    Date,
    Party,
    SourceRef,
    IgnoreField,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AdvocateCorrection {
    pub id: String,
    pub case_id: String,
    pub document_id: String,
    pub field_id: Option<String>,
    pub old_value: Option<String>,
    pub new_value: String,
    pub correction_type: AdvocateCorrectionType,
    pub created_at: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CaseMemoryUpdateSource {
    ExtractionRun,
    UserCorrection,
    AskCase,
    ManualNote,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CaseMemoryUpdate {
    pub id: String,
    pub case_id: String,
    pub source: CaseMemoryUpdateSource,
    pub summary: String,
    pub affected_documents: Vec<String>,
    pub created_at: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AdvocateReviewQueue {
    pub case_id: String,
    pub document_id: String,
    pub field_ids: Vec<String>,
    pub finding_ids: Vec<String>,
    pub summary: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ExtractionOutcome {
    pub run: ExtractionRun,
    pub fields: Vec<ExtractedLegalField>,
    pub findings: Vec<ExtractionFinding>,
    pub case_memory_updates: Vec<CaseMemoryUpdate>,
    pub review_queue: AdvocateReviewQueue,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct FieldConfidenceSignal {
    pub evidence_strength: f32,
    pub source_quality: Option<f32>,
    pub language_confidence: Option<f32>,
    pub verified: bool,
}

pub fn score_field_confidence(signal: FieldConfidenceSignal) -> f32 {
    let source_quality = signal.source_quality.unwrap_or(0.55);
    let language_confidence = signal.language_confidence.unwrap_or(0.6);
    let verification_bonus = if signal.verified { 0.12 } else { -0.12 };
    (signal.evidence_strength * 0.45 + source_quality * 0.35 + language_confidence * 0.20 + verification_bonus)
        .clamp(0.05, 0.99)
}

pub fn validate_source_ref(reference: &SourceRef) -> bool {
    !reference.case_id.trim().is_empty()
        && !reference.document_id.trim().is_empty()
        && !reference.document_title.trim().is_empty()
        && reference.page_number > 0
}

pub fn validate_source_refs(references: &[SourceRef]) -> bool {
    !references.is_empty() && references.iter().all(validate_source_ref)
}

pub fn field_is_source_backed(field: &ExtractedLegalField) -> bool {
    !field.value.trim().is_empty() && validate_source_refs(&field.source_refs)
}

pub fn source_ref_for_page(
    case_id: impl Into<String>,
    document_id: impl Into<String>,
    document_title: impl Into<String>,
    page_number: u32,
    text_snippet: Option<String>,
    ocr_confidence: Option<f32>,
) -> SourceRef {
    SourceRef {
        case_id: case_id.into(),
        document_id: document_id.into(),
        document_title: document_title.into(),
        page_number,
        paragraph_range: None,
        text_snippet,
        ocr_confidence,
    }
}

pub fn field_id(document_id: &str, field_type: &LegalFieldType, page_number: u32, ordinal: usize) -> String {
    format!(
        "{}-{:?}-{}-{}",
        document_id,
        field_type,
        page_number,
        ordinal
    )
    .to_lowercase()
}

pub fn local_timestamp() -> String {
    let seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    format!("local-epoch-{seconds}")
}
