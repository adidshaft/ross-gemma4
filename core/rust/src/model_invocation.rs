use crate::crypto::sha256_hex;
use crate::local_model::{LocalModelInput, LocalModelOutput, LocalModelTask};
use crate::models::CapabilityTierId;
use crate::SourceRef;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LocalModelInvocationStatus {
    Queued,
    Running,
    Complete,
    Failed,
    Cancelled,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LocalModelInvocation {
    pub id: String,
    pub task: LocalModelTask,
    pub case_id: Option<String>,
    pub document_id: Option<String>,
    pub extraction_run_id: Option<String>,
    pub capability_tier: CapabilityTierId,
    pub input_source_refs: Vec<SourceRef>,
    pub prompt_hash: String,
    pub input_hash: String,
    pub output_hash: Option<String>,
    pub started_at: String,
    pub completed_at: Option<String>,
    pub status: LocalModelInvocationStatus,
    pub error_category: Option<String>,
    pub local_only: bool,
}

impl LocalModelInvocation {
    pub fn new(
        id: impl Into<String>,
        task: LocalModelTask,
        case_id: Option<String>,
        document_id: Option<String>,
        extraction_run_id: Option<String>,
        capability_tier: CapabilityTierId,
        input_source_refs: Vec<SourceRef>,
        prompt_hash: String,
        input_hash: String,
        started_at: String,
    ) -> Self {
        Self {
            id: id.into(),
            task,
            case_id,
            document_id,
            extraction_run_id,
            capability_tier,
            input_source_refs: input_source_refs
                .into_iter()
                .map(|source_ref| SourceRef {
                    case_id: source_ref.case_id,
                    document_id: source_ref.document_id,
                    document_title: "Source document".to_string(),
                    page_number: source_ref.page_number,
                    paragraph_range: None,
                    text_snippet: None,
                    ocr_confidence: source_ref.ocr_confidence,
                })
                .collect(),
            prompt_hash,
            input_hash,
            output_hash: None,
            started_at,
            completed_at: None,
            status: LocalModelInvocationStatus::Running,
            error_category: None,
            local_only: true,
        }
    }

    pub fn complete(mut self, output_hash: String, completed_at: String) -> Self {
        self.output_hash = Some(output_hash);
        self.completed_at = Some(completed_at);
        self.status = LocalModelInvocationStatus::Complete;
        self.error_category = None;
        self
    }

    pub fn fail(mut self, error_category: impl Into<String>, completed_at: String) -> Self {
        self.completed_at = Some(completed_at);
        self.status = LocalModelInvocationStatus::Failed;
        self.error_category = Some(error_category.into());
        self
    }
}

pub fn prompt_hash_for_input(input: &LocalModelInput) -> String {
    sha256_hex(format!("{}\n{}", input.instruction, input.expected_schema))
}

pub fn input_hash_for_input(input: &LocalModelInput) -> String {
    let payload = serde_json::to_vec(&input.source_pack).unwrap_or_default();
    sha256_hex(payload)
}

pub fn output_hash_for_output(output: &LocalModelOutput) -> String {
    let payload = output
        .parsed_json
        .clone()
        .unwrap_or_else(|| output.raw_text.clone());
    sha256_hex(payload)
}
