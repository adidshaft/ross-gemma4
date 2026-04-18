use private_digital_clerk_core::{
    sign_entitlement, signing_key_from_seed, AIAvailabilityGuard, AIAvailabilityStatus,
    CapabilityTierId, EntitlementClaims, FeatureGateContext, FeatureName, InstallationState,
    InstalledModelPack, PackCapability,
};

fn verified_context(tier: CapabilityTierId, capabilities: Vec<PackCapability>) -> FeatureGateContext {
    let signing_key = signing_key_from_seed([3u8; 32]);
    let claims = EntitlementClaims {
        subject: "acct_789".into(),
        issued_at_ms: 1_000,
        expires_at_ms: 50_000,
        allowed_tiers: vec![tier],
        enabled_features: vec![
            FeatureName::InstantMode.as_str().into(),
            FeatureName::LongDocumentAnalysis.as_str().into(),
            FeatureName::BilingualMode.as_str().into(),
        ],
        allowed_pack_ids: vec!["pack-1".into()],
        account_tier: "pro".into(),
        nonce: "nonce-3".into(),
    };
    let token = sign_entitlement(claims, "key-1", &signing_key);
    let mut verifier = private_digital_clerk_core::EntitlementVerifier::new();
    verifier.insert_key("key-1", signing_key.verifying_key());
    let verified = verifier.verify(&token, 10_000).expect("verified entitlement");

    FeatureGateContext {
        verified_entitlement: Some(verified),
        installed_packs: vec![InstalledModelPack {
            pack_id: "pack-1".into(),
            capability_tier_id: tier,
            technical_model_id: "model-1".into(),
            installed_at_ms: 5_000,
            state: InstallationState::Installed,
            disk_usage_bytes: 10_000,
            checksum_verified: true,
            capabilities,
        }],
        network_available: true,
        extractive_fallback_available: true,
    }
}

#[test]
fn availability_reports_ready_when_pack_and_entitlement_match() {
    let guard = AIAvailabilityGuard::default();
    let context = verified_context(
        CapabilityTierId::CaseAssociate,
        vec![PackCapability::Generation, PackCapability::Embeddings, PackCapability::Bilingual],
    );

    let availability = guard.availability(&context);
    let decision = guard.evaluate(FeatureName::InstantMode, &context);

    assert_eq!(availability.status, AIAvailabilityStatus::Ready);
    assert!(decision.allowed);
}

#[test]
fn availability_falls_back_to_extractive_mode_without_pack() {
    let guard = AIAvailabilityGuard::default();
    let context = FeatureGateContext {
        verified_entitlement: None,
        installed_packs: Vec::new(),
        network_available: false,
        extractive_fallback_available: true,
    };

    let availability = guard.availability(&context);
    let decision = guard.evaluate(FeatureName::PublicLawSearch, &context);

    assert_eq!(availability.status, AIAvailabilityStatus::ExtractiveOnly);
    assert!(!decision.allowed);
}

#[test]
fn advanced_drafting_requires_senior_tier() {
    let guard = AIAvailabilityGuard::default();
    let context = verified_context(
        CapabilityTierId::CaseAssociate,
        vec![PackCapability::Generation, PackCapability::Embeddings, PackCapability::Bilingual],
    );

    let decision = guard.evaluate(FeatureName::AdvancedDrafting, &context);

    assert!(!decision.allowed);
    assert!(decision
        .reasons
        .iter()
        .any(|reason| reason.contains("senior_drafting")));
}
