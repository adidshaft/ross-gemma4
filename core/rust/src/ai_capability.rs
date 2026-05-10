use crate::models::{
    CapabilityTierId, ModelCapabilityTier, ModelPackManifest, ModelPackManifestSegment,
    PackCapability, PackInstallPlan, PackInstallRequest, PackPlatform, RuntimeTarget,
};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TechnicalModelDescriptor {
    pub id: String,
    pub display_name: String,
    pub family: String,
    pub runtime_candidates: Vec<RuntimeTarget>,
    pub use_cases: Vec<String>,
    pub license_name: String,
    pub onboarding_visible: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalModelCatalog {
    pub capability_tiers: Vec<ModelCapabilityTier>,
    pub technical_models: Vec<TechnicalModelDescriptor>,
    pub retrieval_models: Vec<TechnicalModelDescriptor>,
    pub manifests: Vec<ModelPackManifest>,
}

impl Default for LocalModelCatalog {
    fn default() -> Self {
        Self {
            capability_tiers: default_capability_tiers(),
            technical_models: technical_model_registry(),
            retrieval_models: retrieval_model_registry(),
            manifests: default_manifests(),
        }
    }
}

impl LocalModelCatalog {
    pub fn tier(&self, id: CapabilityTierId) -> Option<&ModelCapabilityTier> {
        self.capability_tiers.iter().find(|tier| tier.id == id)
    }

    pub fn manifests_for_tier(
        &self,
        tier_id: CapabilityTierId,
        platform: PackPlatform,
    ) -> Vec<ModelPackManifest> {
        self.manifests
            .iter()
            .filter(|manifest| {
                manifest.capability_tier_id == tier_id && manifest.platform == platform
            })
            .cloned()
            .collect()
    }

    pub fn recommended_tier(
        &self,
        available_storage_mb: u64,
        estimated_ram_gb: Option<u8>,
    ) -> CapabilityTierId {
        let mut recommended = CapabilityTierId::QuickStart;
        let mut tiers = self.capability_tiers.clone();
        tiers.sort_by_key(|tier| tier.sort_order);

        for tier in tiers {
            let enough_storage = available_storage_mb >= tier.required_free_space_mb as u64;
            let enough_ram = estimated_ram_gb
                .map(|ram| ram >= tier.min_ram_gb.unwrap_or(0))
                .unwrap_or(true);
            if enough_storage && enough_ram {
                recommended = tier.id;
            }
        }

        recommended
    }

    pub fn plan_install(&self, request: &PackInstallRequest) -> PackInstallPlan {
        let manifests = self.manifests_for_tier(request.requested_tier_id, request.platform);
        let selected = if let Some(runtime) = request.requested_runtime {
            manifests
                .iter()
                .find(|manifest| manifest.runtime == runtime)
                .cloned()
        } else {
            manifests.first().cloned()
        };

        let mut reasons = Vec::new();
        if let Some(manifest) = &selected {
            if request.available_storage_bytes < manifest.required_free_space_bytes {
                reasons.push("Not enough free storage for the requested pack.".into());
            }
            if request.requested_tier_id != CapabilityTierId::QuickStart
                && !request.wifi_connected
                && !request.user_approved_mobile
            {
                reasons.push("Large pack downloads are gated to Wi-Fi unless the user explicitly allows mobile data.".into());
            }
        } else {
            reasons.push(
                "No local manifest matched the requested tier, platform, and runtime.".into(),
            );
        }

        PackInstallPlan {
            allowed: reasons.is_empty(),
            reasons,
            recommended_pack_id: selected.as_ref().map(|manifest| manifest.pack_id.clone()),
            suggested_tier_id: Some(self.recommended_tier(
                request.available_storage_bytes / 1_000_000,
                request.estimated_ram_gb,
            )),
        }
    }
}

pub fn default_capability_tiers() -> Vec<ModelCapabilityTier> {
    vec![
        ModelCapabilityTier {
            id: CapabilityTierId::QuickStart,
            display_name: "Quick Start".into(),
            subtitle: "Start quickly with basic local review".into(),
            user_facing_description: "Basic document cleanup, short summaries, simple Ask Ross actions, and basic local matter Q&A.".into(),
            approx_download_size_mb: 429,
            required_free_space_mb: 900,
            recommended_on_wifi: true,
            min_ram_gb: Some(4),
            min_os_version: Some("Android 12 / iOS 17".into()),
            supports_long_documents: false,
            supports_advanced_drafting: false,
            supports_bilingual_mode: false,
            hidden_technical_model_id: "qwen3-0_6b-q4_0-gguf".into(),
            sort_order: 1,
        },
        ModelCapabilityTier {
            id: CapabilityTierId::CaseAssociate,
            display_name: "Case Associate".into(),
            subtitle: "Recommended private assistant for most matters".into(),
            user_facing_description: "Source-backed case Q&A, document review, next-date extraction, chronologies, order summaries, and hearing notes.".into(),
            approx_download_size_mb: 1280,
            required_free_space_mb: 2600,
            recommended_on_wifi: true,
            min_ram_gb: Some(6),
            min_os_version: Some("Android 13 / iOS 18".into()),
            supports_long_documents: true,
            supports_advanced_drafting: false,
            supports_bilingual_mode: true,
            hidden_technical_model_id: "qwen3-1_7b-q4_k_m-gguf".into(),
            sort_order: 2,
        },
        ModelCapabilityTier {
            id: CapabilityTierId::SeniorDrafting,
            display_name: "Senior Drafting Support".into(),
            subtitle: "Advanced private assistant for deeper review and drafting".into(),
            user_facing_description: "Advanced drafting, deeper review, longer matter reasoning, chronology refinement, issue extraction, and hearing preparation.".into(),
            approx_download_size_mb: 2500,
            required_free_space_mb: 5000,
            recommended_on_wifi: true,
            min_ram_gb: Some(8),
            min_os_version: Some("Android 14 / iOS 18".into()),
            supports_long_documents: true,
            supports_advanced_drafting: true,
            supports_bilingual_mode: true,
            hidden_technical_model_id: "qwen3-4b-q4_k_m-gguf".into(),
            sort_order: 3,
        },
    ]
}

pub fn technical_model_registry() -> Vec<TechnicalModelDescriptor> {
    vec![
        TechnicalModelDescriptor {
            id: "qwen3-0_6b-q4_0-gguf".into(),
            display_name: "Gemma 4 E2B Q4".into(),
            family: "qwen".into(),
            runtime_candidates: vec![RuntimeTarget::GemmaLocalRuntime, RuntimeTarget::Custom],
            use_cases: vec![
                "command_routing".into(),
                "short_summaries".into(),
                "basic_local_qa".into(),
                "public_law_query_shaping".into(),
            ],
            license_name: "Gemma license".into(),
            onboarding_visible: false,
        },
        TechnicalModelDescriptor {
            id: "qwen3-1_7b-q4_k_m-gguf".into(),
            display_name: "Gemma 4 E4B Q4".into(),
            family: "qwen".into(),
            runtime_candidates: vec![RuntimeTarget::GemmaLocalRuntime, RuntimeTarget::Custom],
            use_cases: vec![
                "document_review".into(),
                "next_date_extraction".into(),
                "order_direction_extraction".into(),
                "matter_summaries".into(),
                "hearing_notes".into(),
                "case_notes".into(),
                "chronology".into(),
                "source_backed_answers".into(),
                "public_law_query_shaping".into(),
            ],
            license_name: "Gemma license".into(),
            onboarding_visible: false,
        },
        TechnicalModelDescriptor {
            id: "qwen3-4b-q4_k_m-gguf".into(),
            display_name: "Gemma 4 26B-A4B Q4".into(),
            family: "qwen".into(),
            runtime_candidates: vec![RuntimeTarget::GemmaLocalRuntime, RuntimeTarget::Custom],
            use_cases: vec![
                "advanced_drafting".into(),
                "deeper_review".into(),
                "longer_matter_reasoning".into(),
                "chronology_refinement".into(),
                "issue_extraction".into(),
                "order_summary_refinement".into(),
                "hearing_preparation".into(),
            ],
            license_name: "Gemma license".into(),
            onboarding_visible: false,
        },
    ]
}

pub fn retrieval_model_registry() -> Vec<TechnicalModelDescriptor> {
    vec![
        TechnicalModelDescriptor {
            id: "embeddinggemma-300m-litert".into(),
            display_name: "EmbeddingGemma 300M".into(),
            family: "gemma".into(),
            runtime_candidates: vec![RuntimeTarget::LiteRt, RuntimeTarget::Custom],
            use_cases: vec![
                "local_rag".into(),
                "semantic_search".into(),
                "source_retrieval".into(),
                "source_backed_answers".into(),
            ],
            license_name: "Gemma terms".into(),
            onboarding_visible: false,
        },
        TechnicalModelDescriptor {
            id: "qwen3-embedding-0_6b-gguf".into(),
            display_name: "Gemma 4 Embedding".into(),
            family: "qwen".into(),
            runtime_candidates: vec![RuntimeTarget::GemmaLocalRuntime, RuntimeTarget::Custom],
            use_cases: vec![
                "local_rag".into(),
                "semantic_search".into(),
                "source_retrieval".into(),
                "source_backed_answers".into(),
            ],
            license_name: "Gemma license".into(),
            onboarding_visible: false,
        },
    ]
}

pub fn default_manifests() -> Vec<ModelPackManifest> {
    vec![
        manifest_for_tier(
            CapabilityTierId::QuickStart,
            "quick-start-desktop",
            "qwen3-0_6b-q4_0-gguf",
            429,
            900,
            vec![
                PackCapability::Generation,
                PackCapability::Summarization,
                PackCapability::Classification,
            ],
        ),
        manifest_for_tier(
            CapabilityTierId::CaseAssociate,
            "case-associate-desktop",
            "qwen3-1_7b-q4_k_m-gguf",
            1_280,
            2_600,
            vec![
                PackCapability::Generation,
                PackCapability::Embeddings,
                PackCapability::Summarization,
                PackCapability::Classification,
                PackCapability::Bilingual,
            ],
        ),
        manifest_for_tier(
            CapabilityTierId::SeniorDrafting,
            "senior-drafting-desktop",
            "qwen3-4b-q4_k_m-gguf",
            2_500,
            5_000,
            vec![
                PackCapability::Generation,
                PackCapability::Embeddings,
                PackCapability::Summarization,
                PackCapability::Classification,
                PackCapability::Bilingual,
            ],
        ),
    ]
}

fn manifest_for_tier(
    tier: CapabilityTierId,
    pack_id: &str,
    technical_model_name: &str,
    download_size_mb: u64,
    free_space_mb: u64,
    capabilities: Vec<PackCapability>,
) -> ModelPackManifest {
    ModelPackManifest {
        manifest_version: "1".into(),
        pack_id: pack_id.into(),
        capability_tier_id: tier,
        platform: PackPlatform::Desktop,
        runtime: RuntimeTarget::Custom,
        artifact_kind: "tiny_dev_artifact".into(),
        runtime_mode: "deterministic_dev".into(),
        development_only: true,
        technical_model_name: technical_model_name.into(),
        license_name: "Placeholder evaluation license".into(),
        download_size_bytes: download_size_mb * 1_000_000,
        installed_size_bytes: (download_size_mb + 400) * 1_000_000,
        required_free_space_bytes: free_space_mb * 1_000_000,
        sha256: format!("stubbed-{}", pack_id),
        segments: vec![ModelPackManifestSegment {
            segment_id: format!("{pack_id}-segment-1"),
            url: format!("app://model-packs/{pack_id}/segment-1"),
            size_bytes: download_size_mb * 1_000_000,
            sha256: format!("stubbed-segment-{}", pack_id),
        }],
        version: "0.1.0".into(),
        release_date: "2026-04-18".into(),
        is_deprecated: false,
        minimum_app_version: "0.1.0".into(),
        capabilities,
    }
}
