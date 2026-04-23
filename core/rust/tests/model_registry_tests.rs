use ross_core::{CapabilityTierId, LocalModelCatalog};

#[test]
fn model_registry_maps_private_assistant_tiers_to_qwen_stack() {
    let catalog = LocalModelCatalog::default();

    let quick = catalog
        .tier(CapabilityTierId::QuickStart)
        .expect("quick start tier");
    let case = catalog
        .tier(CapabilityTierId::CaseAssociate)
        .expect("case associate tier");
    let senior = catalog
        .tier(CapabilityTierId::SeniorDrafting)
        .expect("senior drafting tier");

    assert_eq!(quick.display_name, "Quick Start");
    assert_eq!(quick.hidden_technical_model_id, "qwen3-0_6b-q4_0-gguf");
    assert_eq!(quick.approx_download_size_mb, 429);

    assert_eq!(case.display_name, "Case Associate");
    assert_eq!(case.hidden_technical_model_id, "qwen3-1_7b-q4_k_m-gguf");
    assert_eq!(case.approx_download_size_mb, 1280);

    assert_eq!(senior.display_name, "Senior Drafting Support");
    assert_eq!(senior.hidden_technical_model_id, "qwen3-4b-q4_k_m-gguf");
    assert_eq!(senior.approx_download_size_mb, 2500);

    let generative_names: Vec<_> = catalog
        .technical_models
        .iter()
        .map(|model| model.display_name.as_str())
        .collect();
    assert!(generative_names.contains(&"Gemma 4 E2B Q4"));
    assert!(generative_names.contains(&"Gemma 4 E4B Q4"));
    assert!(generative_names.contains(&"Gemma 4 26B-A4B Q4"));
}

#[test]
fn retrieval_registry_is_separate_from_generative_tiers() {
    let catalog = LocalModelCatalog::default();

    assert!(catalog
        .retrieval_models
        .iter()
        .any(|model| model.display_name == "EmbeddingGemma 300M"));
    assert!(catalog
        .retrieval_models
        .iter()
        .any(|model| model.display_name == "Gemma 4 Embedding"));

    for retrieval_model in &catalog.retrieval_models {
        assert!(retrieval_model
            .use_cases
            .iter()
            .any(|use_case| use_case == "local_rag"));
    }
}
