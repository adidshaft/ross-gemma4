use crate::extraction::{
    field_is_source_backed, DocumentExtractionInput, ExtractionFinding, ExtractedLegalField,
    LegalDocumentClassification,
};
use crate::legal_fields::{DeterministicLegalFieldVerifier, VerificationResult};
use crate::local_model::LocalModelOutput;
use serde::de::DeserializeOwned;

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

pub fn collect_warnings(findings: &[ExtractionFinding]) -> Vec<String> {
    findings.iter().map(|finding| finding.message.clone()).collect()
}
