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
    pub manifests: Vec<ModelPackManifest>,
}

impl Default for LocalModelCatalog {
    fn default() -> Self {
        Self {
            capability_tiers: default_capability_tiers(),
            technical_models: technical_model_registry(),
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
            .filter(|manifest| manifest.capability_tier_id == tier_id && manifest.platform == platform)
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
            reasons.push("No local manifest matched the requested tier, platform, and runtime.".into());
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
            subtitle: "Start using private AI sooner".into(),
            user_facing_description: "Basic document cleanup, short summaries, simple case questions over small files, and basic chronology extraction.".into(),
            approx_download_size_mb: 850,
            required_free_space_mb: 1600,
            recommended_on_wifi: true,
            min_ram_gb: Some(4),
            min_os_version: Some("Android 12 / iOS 17".into()),
            supports_long_documents: false,
            supports_advanced_drafting: false,
            supports_bilingual_mode: false,
            hidden_technical_model_id: "llama-3.2-3b-q4".into(),
            sort_order: 1,
        },
        ModelCapabilityTier {
            id: CapabilityTierId::CaseAssociate,
            display_name: "Case Associate".into(),
            subtitle: "Recommended for most advocates".into(),
            user_facing_description: "Source-backed case Q&A, 50+ page PDF summarization, chronologies, issue extraction, order summaries, and evidence review.".into(),
            approx_download_size_mb: 3800,
            required_free_space_mb: 6200,
            recommended_on_wifi: true,
            min_ram_gb: Some(6),
            min_os_version: Some("Android 13 / iOS 18".into()),
            supports_long_documents: true,
            supports_advanced_drafting: false,
            supports_bilingual_mode: true,
            hidden_technical_model_id: "gemma-4-e2b-q4".into(),
            sort_order: 2,
        },
        ModelCapabilityTier {
            id: CapabilityTierId::SeniorDrafting,
            display_name: "Senior Drafting Support".into(),
            subtitle: "Best for longer files and detailed drafts".into(),
            user_facing_description: "Longer-document workflows, more detailed drafting, stronger bilingual handling, senior counsel briefs, and deeper issue analysis.".into(),
            approx_download_size_mb: 6400,
            required_free_space_mb: 9800,
            recommended_on_wifi: true,
            min_ram_gb: Some(8),
            min_os_version: Some("Android 14 / iOS 18".into()),
            supports_long_documents: true,
            supports_advanced_drafting: true,
            supports_bilingual_mode: true,
            hidden_technical_model_id: "gemma-4-e4b-q4".into(),
            sort_order: 3,
        },
    ]
}

pub fn technical_model_registry() -> Vec<TechnicalModelDescriptor> {
    vec![
        TechnicalModelDescriptor {
            id: "gemma-4-e2b-q4".into(),
            display_name: "Gemma 4 E2B Q4".into(),
            family: "gemma".into(),
            runtime_candidates: vec![RuntimeTarget::Gemma 4 E4B Q4Cpp, RuntimeTarget::Mediapipe, RuntimeTarget::Custom],
            use_cases: vec![
                "summaries".into(),
                "case_qa".into(),
                "chronology".into(),
                "issue_extraction".into(),
            ],
            license_name: "Placeholder evaluation license".into(),
            onboarding_visible: true,
        },
        TechnicalModelDescriptor {
            id: "gemma-4-e4b-q4".into(),
            display_name: "Gemma 4 E4B Q4".into(),
            family: "gemma".into(),
            runtime_candidates: vec![RuntimeTarget::Gemma 4 E4B Q4Cpp, RuntimeTarget::CoreMl, RuntimeTarget::Custom],
            use_cases: vec![
                "advanced_drafting".into(),
                "long_document_analysis".into(),
                "bilingual_outputs".into(),
            ],
            license_name: "Placeholder evaluation license".into(),
            onboarding_visible: true,
        },
        TechnicalModelDescriptor {
            id: "embeddinggemma-300m-int8".into(),
            display_name: "EmbeddingGemma 300M INT8".into(),
            family: "gemma".into(),
            runtime_candidates: vec![RuntimeTarget::Mediapipe, RuntimeTarget::Custom],
            use_cases: vec!["local_rag".into(), "semantic_search".into()],
            license_name: "Placeholder evaluation license".into(),
            onboarding_visible: false,
        },
        TechnicalModelDescriptor {
            id: "llama-3.2-3b-q4".into(),
            display_name: "Gemma 4 E4B Q4 3.2 3B Q4".into(),
            family: "llama".into(),
            runtime_candidates: vec![RuntimeTarget::Gemma 4 E4B Q4Cpp, RuntimeTarget::Custom],
            use_cases: vec!["compact_summaries".into(), "basic_classification".into()],
            license_name: "Placeholder evaluation license".into(),
            onboarding_visible: true,
        },
    ]
}

pub fn default_manifests() -> Vec<ModelPackManifest> {
    vec![
        manifest_for_tier(
            CapabilityTierId::QuickStart,
            "quick-start-desktop",
            "llama-3.2-3b-q4",
            850,
            1_600,
            vec![
                PackCapability::Generation,
                PackCapability::Summarization,
                PackCapability::Classification,
            ],
        ),
        manifest_for_tier(
            CapabilityTierId::CaseAssociate,
            "case-associate-desktop",
            "gemma-4-e2b-q4",
            3_800,
            6_200,
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
            "gemma-4-e4b-q4",
            6_400,
            9_800,
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
