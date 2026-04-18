use crate::extraction::ExtractionMode;
use crate::local_model::LocalModelTask;
use crate::models::InstalledModelPack;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExtractionPipelineFallback {
    Skip,
    Deterministic,
    NeedsReview,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum UserFacingQuality {
    Basic,
    Standard,
    Advanced,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExtractionPipelinePassPlan {
    pub task: LocalModelTask,
    pub required: bool,
    pub max_pages_per_batch: usize,
    pub fallback: ExtractionPipelineFallback,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExtractionPipelinePlan {
    pub mode: ExtractionMode,
    pub passes: Vec<ExtractionPipelinePassPlan>,
    pub requires_installed_pack: bool,
    pub user_facing_quality: UserFacingQuality,
}

pub fn extraction_mode_for_pack(pack: Option<&InstalledModelPack>) -> ExtractionMode {
    match pack {
        Some(pack) if pack.is_ready() => match pack.capability_tier_id {
            crate::models::CapabilityTierId::QuickStart => ExtractionMode::QuickStart,
            crate::models::CapabilityTierId::CaseAssociate => ExtractionMode::CaseAssociate,
            crate::models::CapabilityTierId::SeniorDrafting => ExtractionMode::SeniorDraftingSupport,
        },
        _ => ExtractionMode::Basic,
    }
}

pub fn build_extraction_pipeline_plan(mode: ExtractionMode) -> ExtractionPipelinePlan {
    match mode {
        ExtractionMode::Basic => ExtractionPipelinePlan {
            mode,
            passes: vec![
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LanguageCorrection,
                    required: false,
                    max_pages_per_batch: 8,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LegalFieldVerification,
                    required: true,
                    max_pages_per_batch: 12,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
            ],
            requires_installed_pack: false,
            user_facing_quality: UserFacingQuality::Basic,
        },
        ExtractionMode::QuickStart => ExtractionPipelinePlan {
            mode,
            passes: vec![
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::OcrCleanup,
                    required: false,
                    max_pages_per_batch: 12,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::DocumentClassification,
                    required: true,
                    max_pages_per_batch: 12,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LegalFieldExtraction,
                    required: true,
                    max_pages_per_batch: 12,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LegalFieldVerification,
                    required: true,
                    max_pages_per_batch: 12,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
            ],
            requires_installed_pack: true,
            user_facing_quality: UserFacingQuality::Standard,
        },
        ExtractionMode::CaseAssociate => ExtractionPipelinePlan {
            mode,
            passes: vec![
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::OcrCleanup,
                    required: true,
                    max_pages_per_batch: 16,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LanguageCorrection,
                    required: true,
                    max_pages_per_batch: 16,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::DocumentClassification,
                    required: true,
                    max_pages_per_batch: 16,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LegalFieldExtraction,
                    required: true,
                    max_pages_per_batch: 16,
                    fallback: ExtractionPipelineFallback::NeedsReview,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LegalFieldVerification,
                    required: true,
                    max_pages_per_batch: 16,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::CaseMemorySynthesis,
                    required: true,
                    max_pages_per_batch: 24,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
            ],
            requires_installed_pack: true,
            user_facing_quality: UserFacingQuality::Advanced,
        },
        ExtractionMode::SeniorDraftingSupport => ExtractionPipelinePlan {
            mode,
            passes: vec![
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::OcrCleanup,
                    required: true,
                    max_pages_per_batch: 20,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LanguageCorrection,
                    required: true,
                    max_pages_per_batch: 20,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::DocumentClassification,
                    required: true,
                    max_pages_per_batch: 20,
                    fallback: ExtractionPipelineFallback::NeedsReview,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LegalFieldExtraction,
                    required: true,
                    max_pages_per_batch: 20,
                    fallback: ExtractionPipelineFallback::NeedsReview,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::LegalFieldVerification,
                    required: true,
                    max_pages_per_batch: 20,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::IssueExtraction,
                    required: false,
                    max_pages_per_batch: 20,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
                ExtractionPipelinePassPlan {
                    task: LocalModelTask::CaseMemorySynthesis,
                    required: true,
                    max_pages_per_batch: 32,
                    fallback: ExtractionPipelineFallback::Deterministic,
                },
            ],
            requires_installed_pack: true,
            user_facing_quality: UserFacingQuality::Advanced,
        },
    }
}
