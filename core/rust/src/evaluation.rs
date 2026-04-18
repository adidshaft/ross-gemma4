use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EvaluationRun {
    pub id: String,
    pub runtime_mode: String,
    pub extraction_mode: String,
    pub fixture_id: String,
    pub started_at: String,
    pub completed_at: String,
    pub fields_expected: u32,
    pub fields_found: u32,
    pub fields_verified: u32,
    pub fields_needing_review: u32,
    pub unsupported_accepted: u32,
    pub schema_valid: bool,
    pub source_coverage: f32,
    pub notes: Vec<String>,
}

impl EvaluationRun {
    pub fn verified_precision_proxy(&self) -> f32 {
        if self.fields_found == 0 {
            0.0
        } else {
            self.fields_verified as f32 / self.fields_found as f32
        }
    }

    pub fn field_recall(&self) -> f32 {
        if self.fields_expected == 0 {
            0.0
        } else {
            self.fields_found as f32 / self.fields_expected as f32
        }
    }

    pub fn invariant_holds(&self) -> bool {
        self.unsupported_accepted == 0 && self.schema_valid
    }
}
