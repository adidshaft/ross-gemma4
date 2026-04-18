use crate::extraction::{
    DocumentExtractionInput, ExtractionMode, ExtractedLegalField, LegalDocumentClassification,
    LegalFieldType, PageText, SourceRef,
};
use crate::extraction_orchestrator::{CaseMemoryBuilder, DeterministicCaseMemoryBuilder};
use crate::language::{detect_document_language_profile, DocumentLanguageProfile, LanguagePageSample};
use crate::legal_fields::{
    DeterministicLegalDocumentClassifier, DeterministicLegalFieldExtractor,
    DeterministicLegalFieldVerifier,
};
use crate::models::CapabilityTierId;
use serde::{Deserialize, Serialize};
use serde_json::json;

const EXISTING_FIELDS_MARKER: &str = "existing_fields_json=";
const CLASSIFICATION_MARKER: &str = "classification_json=";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LocalModelTask {
    OcrCleanup,
    LanguageCorrection,
    DocumentClassification,
    LegalFieldExtraction,
    LegalFieldVerification,
    CaseMemorySynthesis,
    ChronologyGeneration,
    OrderSummary,
    IssueExtraction,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SourceTextBlock {
    pub source_ref: SourceRef,
    pub text: String,
    pub page_number: u32,
    pub language_hint: Option<String>,
    pub ocr_confidence: Option<f32>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LocalModelInput {
    pub task: LocalModelTask,
    pub instruction: String,
    pub source_pack: Vec<SourceTextBlock>,
    pub expected_schema: String,
    pub max_output_tokens: i32,
    pub language_profile: Option<DocumentLanguageProfile>,
    pub document_classification: Option<LegalDocumentClassification>,
    pub extraction_mode: ExtractionMode,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LocalModelOutput {
    pub raw_text: String,
    pub parsed_json: Option<String>,
    pub schema_valid: bool,
    pub warnings: Vec<String>,
    pub source_refs: Vec<SourceRef>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LocalResourceEstimate {
    pub estimated_runtime_ms: u64,
    pub estimated_memory_mb: u32,
    pub notes: Vec<String>,
}

pub trait LocalModelProvider {
    fn is_available(&self) -> bool;
    fn capability_tier(&self) -> CapabilityTierId;
    fn supported_tasks(&self) -> Vec<LocalModelTask>;
    fn run(&self, task_input: &LocalModelInput) -> LocalModelOutput;
    fn estimate_cost_or_resource_use(&self, input: &LocalModelInput) -> LocalResourceEstimate;
    fn cancel(&self, invocation_id: &str) -> bool;
}

#[derive(Clone, Copy, Debug, Default)]
pub struct DeterministicDevLocalModelProvider;

impl LocalModelProvider for DeterministicDevLocalModelProvider {
    fn is_available(&self) -> bool {
        true
    }

    fn capability_tier(&self) -> CapabilityTierId {
        CapabilityTierId::CaseAssociate
    }

    fn supported_tasks(&self) -> Vec<LocalModelTask> {
        vec![
            LocalModelTask::OcrCleanup,
            LocalModelTask::LanguageCorrection,
            LocalModelTask::DocumentClassification,
            LocalModelTask::LegalFieldExtraction,
            LocalModelTask::LegalFieldVerification,
            LocalModelTask::CaseMemorySynthesis,
            LocalModelTask::ChronologyGeneration,
            LocalModelTask::OrderSummary,
            LocalModelTask::IssueExtraction,
        ]
    }

    fn run(&self, task_input: &LocalModelInput) -> LocalModelOutput {
        let document = document_from_source_pack(task_input);
        let language_profile = task_input
            .language_profile
            .clone()
            .unwrap_or_else(|| language_profile_from_input(task_input));

        match task_input.task {
            LocalModelTask::OcrCleanup => {
                let cleaned_pages = task_input
                    .source_pack
                    .iter()
                    .map(|block| cleanup_text(&block.text))
                    .collect::<Vec<_>>();
                let raw_text = cleaned_pages.join("\n\n");

                LocalModelOutput {
                    raw_text: raw_text.clone(),
                    parsed_json: Some(serde_json::to_string(&cleaned_pages).unwrap_or_else(|_| "[]".to_string())),
                    schema_valid: true,
                    warnings: vec!["Deterministic development cleanup only.".to_string()],
                    source_refs: task_input
                        .source_pack
                        .iter()
                        .map(|block| block.source_ref.clone())
                        .collect(),
                }
            }
            LocalModelTask::LanguageCorrection => {
                let payload = language_profile.clone();
                let raw_text = serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string());
                LocalModelOutput {
                    raw_text: raw_text.clone(),
                    parsed_json: Some(raw_text),
                    schema_valid: true,
                    warnings: vec!["Deterministic language correction used heuristics only.".to_string()],
                    source_refs: task_input
                        .source_pack
                        .iter()
                        .map(|block| block.source_ref.clone())
                        .collect(),
                }
            }
            LocalModelTask::DocumentClassification => {
                let classifier = DeterministicLegalDocumentClassifier;
                let classification = classifier.classify(&document, &language_profile);
                let raw_text = serde_json::to_string(&classification).unwrap_or_else(|_| "{}".to_string());
                LocalModelOutput {
                    raw_text: raw_text.clone(),
                    parsed_json: Some(raw_text),
                    schema_valid: true,
                    warnings: vec!["Deterministic development classification only.".to_string()],
                    source_refs: classification.source_refs.clone(),
                }
            }
            LocalModelTask::LegalFieldExtraction => {
                let classifier = DeterministicLegalDocumentClassifier;
                let extraction_classification = task_input
                    .document_classification
                    .clone()
                    .unwrap_or_else(|| classifier.classify(&document, &language_profile));
                let extractor = DeterministicLegalFieldExtractor;
                let fields = extractor.extract(&document, &extraction_classification, &language_profile);
                let raw_text = serde_json::to_string(&fields).unwrap_or_else(|_| "[]".to_string());
                LocalModelOutput {
                    raw_text: raw_text.clone(),
                    parsed_json: Some(raw_text),
                    schema_valid: true,
                    warnings: vec!["Deterministic development extraction only.".to_string()],
                    source_refs: fields.iter().flat_map(|field| field.source_refs.clone()).collect(),
                }
            }
            LocalModelTask::IssueExtraction => {
                let classifier = DeterministicLegalDocumentClassifier;
                let extraction_classification = task_input
                    .document_classification
                    .clone()
                    .unwrap_or_else(|| classifier.classify(&document, &language_profile));
                let extractor = DeterministicLegalFieldExtractor;
                let fields = extractor
                    .extract(&document, &extraction_classification, &language_profile)
                    .into_iter()
                    .filter(|field| {
                        matches!(
                            field.field_type,
                            LegalFieldType::Issue | LegalFieldType::Relief | LegalFieldType::Prayer
                        )
                    })
                    .collect::<Vec<_>>();
                let raw_text = serde_json::to_string(&fields).unwrap_or_else(|_| "[]".to_string());
                LocalModelOutput {
                    raw_text: raw_text.clone(),
                    parsed_json: Some(raw_text),
                    schema_valid: true,
                    warnings: vec!["Deterministic development issue extraction only.".to_string()],
                    source_refs: fields.iter().flat_map(|field| field.source_refs.clone()).collect(),
                }
            }
            LocalModelTask::LegalFieldVerification => {
                let existing_fields = existing_fields_from_instruction(&task_input.instruction);
                let verifier = DeterministicLegalFieldVerifier;
                let verification = verifier.verify(&document, &existing_fields);
                let payload = json!({
                    "fields": verification.fields,
                    "findings": verification.findings,
                });
                let raw_text = payload.to_string();
                LocalModelOutput {
                    raw_text: raw_text.clone(),
                    parsed_json: Some(raw_text),
                    schema_valid: true,
                    warnings: vec!["Deterministic development verification only.".to_string()],
                    source_refs: existing_fields
                        .iter()
                        .flat_map(|field| field.source_refs.clone())
                        .collect(),
                }
            }
            LocalModelTask::CaseMemorySynthesis => {
                let classifier = classification_from_instruction(&task_input.instruction)
                    .or_else(|| task_input.document_classification.clone())
                    .unwrap_or_else(|| {
                        let classifier = DeterministicLegalDocumentClassifier;
                        classifier.classify(&document, &language_profile)
                    });
                let existing_fields = existing_fields_from_instruction(&task_input.instruction);
                let builder = DeterministicCaseMemoryBuilder;
                let updates = builder.build(&document, &classifier, &existing_fields);
                let raw_text = serde_json::to_string(&updates).unwrap_or_else(|_| "[]".to_string());
                LocalModelOutput {
                    raw_text: raw_text.clone(),
                    parsed_json: Some(raw_text),
                    schema_valid: true,
                    warnings: vec!["Deterministic development synthesis only.".to_string()],
                    source_refs: existing_fields
                        .iter()
                        .flat_map(|field| field.source_refs.clone())
                        .collect(),
                }
            }
            LocalModelTask::ChronologyGeneration => {
                let existing_fields = existing_fields_from_instruction(&task_input.instruction);
                let chronology = existing_fields
                    .iter()
                    .filter(|field| {
                        matches!(field.field_type, LegalFieldType::Date | LegalFieldType::NextDate)
                    })
                    .map(|field| {
                        json!({
                            "label": field.label,
                            "value": field.value,
                            "source_refs": field.source_refs,
                            "needs_review": field.needs_review,
                        })
                    })
                    .collect::<Vec<_>>();
                let raw_text = serde_json::to_string(&chronology).unwrap_or_else(|_| "[]".to_string());
                LocalModelOutput {
                    raw_text: raw_text.clone(),
                    parsed_json: Some(raw_text),
                    schema_valid: true,
                    warnings: vec!["Deterministic chronology candidate generation only.".to_string()],
                    source_refs: existing_fields
                        .iter()
                        .flat_map(|field| field.source_refs.clone())
                        .collect(),
                }
            }
            LocalModelTask::OrderSummary => {
                let existing_fields = existing_fields_from_instruction(&task_input.instruction);
                let summary = json!({
                    "operative_directions": existing_fields
                        .iter()
                        .filter(|field| field.field_type == LegalFieldType::OrderDirection)
                        .map(|field| field.value.clone())
                        .collect::<Vec<_>>(),
                    "next_dates": existing_fields
                        .iter()
                        .filter(|field| field.field_type == LegalFieldType::NextDate)
                        .map(|field| field.value.clone())
                        .collect::<Vec<_>>(),
                });
                let raw_text = summary.to_string();
                LocalModelOutput {
                    raw_text: raw_text.clone(),
                    parsed_json: Some(raw_text),
                    schema_valid: true,
                    warnings: vec!["Deterministic order summary synthesis only.".to_string()],
                    source_refs: existing_fields
                        .iter()
                        .flat_map(|field| field.source_refs.clone())
                        .collect(),
                }
            }
        }
    }

    fn estimate_cost_or_resource_use(&self, input: &LocalModelInput) -> LocalResourceEstimate {
        LocalResourceEstimate {
            estimated_runtime_ms: (input.source_pack.len().max(1) * 120) as u64,
            estimated_memory_mb: (input.source_pack.len().max(1) * 6) as u32,
            notes: vec!["Deterministic development provider estimate.".to_string()],
        }
    }

    fn cancel(&self, _invocation_id: &str) -> bool {
        true
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlatformLocalModelProvider {
    pub capability_tier: CapabilityTierId,
    pub installed_model_path: Option<String>,
}

impl LocalModelProvider for PlatformLocalModelProvider {
    fn is_available(&self) -> bool {
        false
    }

    fn capability_tier(&self) -> CapabilityTierId {
        self.capability_tier
    }

    fn supported_tasks(&self) -> Vec<LocalModelTask> {
        vec![]
    }

    fn run(&self, task_input: &LocalModelInput) -> LocalModelOutput {
        LocalModelOutput {
            raw_text: String::new(),
            parsed_json: None,
            schema_valid: false,
            warnings: vec![format!(
                "No on-device runtime is available for {:?}. Install a compatible local runtime.",
                task_input.task
            )],
            source_refs: task_input
                .source_pack
                .iter()
                .map(|block| block.source_ref.clone())
                .collect(),
        }
    }

    fn estimate_cost_or_resource_use(&self, input: &LocalModelInput) -> LocalResourceEstimate {
        LocalResourceEstimate {
            estimated_runtime_ms: 0,
            estimated_memory_mb: 0,
            notes: vec![format!(
                "Runtime unavailable for {:?}; Ross will fail safely or fall back deterministically.",
                input.task
            )],
        }
    }

    fn cancel(&self, _invocation_id: &str) -> bool {
        false
    }
}

pub fn existing_fields_from_instruction(instruction: &str) -> Vec<ExtractedLegalField> {
    extract_json_marker(instruction, EXISTING_FIELDS_MARKER)
        .and_then(|json| serde_json::from_str::<Vec<ExtractedLegalField>>(&json).ok())
        .unwrap_or_default()
}

pub fn classification_from_instruction(instruction: &str) -> Option<LegalDocumentClassification> {
    extract_json_marker(instruction, CLASSIFICATION_MARKER)
        .and_then(|json| serde_json::from_str::<LegalDocumentClassification>(&json).ok())
}

fn document_from_source_pack(input: &LocalModelInput) -> DocumentExtractionInput {
    let first_ref = input.source_pack.first().map(|block| block.source_ref.clone());
    let case_id = first_ref
        .as_ref()
        .map(|reference| reference.case_id.clone())
        .unwrap_or_else(|| "case-local".to_string());
    let document_id = first_ref
        .as_ref()
        .map(|reference| reference.document_id.clone())
        .unwrap_or_else(|| "document-local".to_string());
    let document_title = first_ref
        .as_ref()
        .map(|reference| reference.document_title.clone())
        .unwrap_or_else(|| "Imported document".to_string());

    DocumentExtractionInput {
        case_id,
        document_id,
        document_title,
        mode: input.extraction_mode,
        pages: input
            .source_pack
            .iter()
            .map(|block| PageText {
                page_number: block.page_number,
                text: block.text.clone(),
                source_ref: block.source_ref.clone(),
                ocr_confidence: block.ocr_confidence,
                layout_hint: None,
            })
            .collect(),
    }
}

fn language_profile_from_input(input: &LocalModelInput) -> DocumentLanguageProfile {
    let document_id = input
        .source_pack
        .first()
        .map(|block| block.source_ref.document_id.clone())
        .unwrap_or_else(|| "document-local".to_string());
    let samples = input
        .source_pack
        .iter()
        .map(|block| LanguagePageSample {
            page_number: block.page_number,
            text: block.text.clone(),
        })
        .collect::<Vec<_>>();
    detect_document_language_profile(document_id, &samples)
}

fn cleanup_text(text: &str) -> String {
    text.replace('\u{00a0}', " ")
        .replace('\r', "\n")
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>()
        .join("\n")
}

fn extract_json_marker(instruction: &str, marker: &str) -> Option<String> {
    instruction
        .lines()
        .find_map(|line| line.strip_prefix(marker).map(|value| value.trim().to_string()))
}
