use crate::extraction::{
    field_is_source_backed, CaseMemoryUpdate, DocumentExtractionInput, ExtractionFinding,
    ExtractedLegalField, LegalDocumentClassification, LegalFieldType, SourceRef,
};
use crate::legal_fields::{DeterministicLegalFieldVerifier, VerificationResult};
use crate::local_model::LocalModelOutput;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VerifiedFieldDisposition {
    Verified,
    NeedsReview,
    Rejected,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ChronologyEntry {
    pub label: String,
    pub value: String,
    pub source_refs: Vec<SourceRef>,
    pub needs_review: bool,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OrderSummaryPayload {
    pub operative_directions: Vec<String>,
    pub next_dates: Vec<String>,
    pub source_refs: Vec<SourceRef>,
}

pub fn parse_output_json<T: DeserializeOwned>(output: &LocalModelOutput) -> Result<T, String> {
    let payload = repair_json_payload(output)
        .ok_or_else(|| "Local model output did not include parseable JSON.".to_string())?;
    serde_json::from_str::<T>(&payload).map_err(|error| error.to_string())
}

pub fn repair_json_payload(output: &LocalModelOutput) -> Option<String> {
    if let Some(parsed) = &output.parsed_json {
        return Some(parsed.clone());
    }

    let raw = output.raw_text.trim();
    if raw.starts_with('{') && raw.ends_with('}') {
        return Some(raw.to_string());
    }
    if raw.starts_with('[') && raw.ends_with(']') {
        return Some(raw.to_string());
    }
    None
}

pub fn validate_classification(
    classification: LegalDocumentClassification,
) -> Result<LegalDocumentClassification, String> {
    if classification.source_refs.is_empty() {
        return Err("Classification is missing source refs.".to_string());
    }
    Ok(classification)
}

pub fn validate_fields(
    input: &DocumentExtractionInput,
    fields: Vec<ExtractedLegalField>,
) -> VerificationResult {
    let verifier = DeterministicLegalFieldVerifier;
    let verification = verifier.verify(input, &fields);
    let filtered_fields = verification
        .fields
        .into_iter()
        .filter(|field| field_is_source_backed(field))
        .collect::<Vec<_>>();

    VerificationResult {
        fields: filtered_fields,
        findings: verification.findings,
    }
}

pub fn verified_field_disposition(field: &ExtractedLegalField) -> VerifiedFieldDisposition {
    if field.source_refs.is_empty() || field.value.trim().is_empty() {
        return VerifiedFieldDisposition::Rejected;
    }
    if field.needs_review || matches!(field.field_type, LegalFieldType::Unknown) {
        return VerifiedFieldDisposition::NeedsReview;
    }
    VerifiedFieldDisposition::Verified
}

pub fn validate_verification_payload(
    input: &DocumentExtractionInput,
    fields: Vec<ExtractedLegalField>,
) -> VerificationResult {
    validate_fields(input, fields)
}

pub fn validate_case_memory_updates(updates: Vec<CaseMemoryUpdate>) -> Result<Vec<CaseMemoryUpdate>, String> {
    if updates.iter().any(|update| update.summary.trim().is_empty()) {
        return Err("Case memory update summary must not be empty.".to_string());
    }
    Ok(updates)
}

pub fn validate_chronology_entries(entries: Vec<ChronologyEntry>) -> Result<Vec<ChronologyEntry>, String> {
    if entries.iter().any(|entry| entry.source_refs.is_empty() || entry.value.trim().is_empty()) {
        return Err("Chronology entries must keep source refs and non-empty values.".to_string());
    }
    Ok(entries)
}

pub fn validate_order_summary_payload(
    summary: OrderSummaryPayload,
) -> Result<OrderSummaryPayload, String> {
    if summary.source_refs.is_empty() {
        return Err("Order summary must retain source refs.".to_string());
    }
    Ok(summary)
}

pub fn collect_warnings(findings: &[ExtractionFinding]) -> Vec<String> {
    findings.iter().map(|finding| finding.message.clone()).collect()
}
