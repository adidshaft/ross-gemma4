use ross_core::{
    allows_feature, allows_tier, highest_allowed_tier, sign_entitlement, signing_key_from_seed,
    CapabilityTierId, EntitlementClaims, EntitlementError, EntitlementVerifier, FeatureName,
};

#[test]
fn entitlement_verification_accepts_valid_signature() {
    let signing_key = signing_key_from_seed([7u8; 32]);
    let claims = EntitlementClaims {
        subject: "acct_123".into(),
        issued_at_ms: 1_000,
        expires_at_ms: 10_000,
        allowed_tiers: vec![CapabilityTierId::CaseAssociate],
        enabled_features: vec![
            FeatureName::InstantMode.as_str().into(),
            FeatureName::LongDocumentAnalysis.as_str().into(),
        ],
        allowed_pack_ids: vec!["case-associate-desktop".into()],
        account_tier: "pro".into(),
        nonce: "nonce-1".into(),
    };
    let token = sign_entitlement(claims, "test-key", &signing_key);
    let mut verifier = EntitlementVerifier::new();
    verifier.insert_key("test-key", signing_key.verifying_key());

    let verified = verifier.verify(&token, 5_000).expect("valid entitlement");

    assert_eq!(highest_allowed_tier(&verified), Some(CapabilityTierId::CaseAssociate));
    assert!(allows_tier(&verified, CapabilityTierId::QuickStart));
    assert!(allows_feature(&verified, FeatureName::LongDocumentAnalysis));
}

#[test]
fn entitlement_verification_rejects_expired_claims() {
    let signing_key = signing_key_from_seed([11u8; 32]);
    let claims = EntitlementClaims {
        subject: "acct_456".into(),
        issued_at_ms: 1_000,
        expires_at_ms: 2_000,
        allowed_tiers: vec![CapabilityTierId::QuickStart],
        enabled_features: vec![FeatureName::InstantMode.as_str().into()],
        allowed_pack_ids: vec!["quick-start-desktop".into()],
        account_tier: "starter".into(),
        nonce: "nonce-2".into(),
    };
    let token = sign_entitlement(claims, "expired-key", &signing_key);
    let mut verifier = EntitlementVerifier::new();
    verifier.insert_key("expired-key", signing_key.verifying_key());

    let error = verifier.verify(&token, 5_000).expect_err("entitlement should be expired");

    assert_eq!(error, EntitlementError::Expired);
}
