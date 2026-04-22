use ross_core::{
    build_public_answer, PayloadClass, PublicLawDocument, PublicQuerySanitizer,
};

#[test]
fn sanitizer_redacts_case_specific_content() {
    let raw = "Need public law on anticipatory bail. My client jane@example.com in Case No. WP-123/2024 needs guidance.";
    let sanitized = PublicQuerySanitizer::default().sanitize(raw).expect("query should sanitize");

    assert_eq!(sanitized.classification, PayloadClass::SanitizedPublicQuery);
    assert!(sanitized.requires_user_confirmation);
    assert!(!sanitized.text.contains("jane@example.com"));
    assert!(!sanitized.text.contains("WP-123/2024"));
    assert!(sanitized.search_terms.iter().any(|term| term == "anticipatory"));
}

#[test]
fn sanitizer_rejects_private_narrative_pastes() {
    let raw = "My client says the accused came on 4 April 2024 and then again on 5 April 2024 with several threats and detailed factual background that goes on and on across many lines. This is the full private narrative from the case file and should never leave the device.";
    let refusal = PublicQuerySanitizer::default().sanitize(raw).expect_err("query should be rejected");

    assert!(refusal.user_message.contains("too close to case-specific material"));
}

#[test]
fn sanitizer_preserves_legal_citations_and_strips_known_fake_secrets() {
    let raw = "Order 39 Rules 1 and 2 CPC temporary injunction for Raghav Fakepriv in FAKE/123/2026 using fakepriv@example.com and 9876501234 near blue suitcase near temple";
    let sanitized = PublicQuerySanitizer::default().sanitize(raw).expect("query should sanitize");

    assert!(sanitized.text.contains("Order 39 Rules 1 and 2 CPC"));
    assert!(sanitized.text.contains("temporary injunction"));
    assert!(!sanitized.text.contains("Raghav Fakepriv"));
    assert!(!sanitized.text.contains("FAKE/123/2026"));
    assert!(!sanitized.text.contains("fakepriv@example.com"));
    assert!(!sanitized.text.contains("9876501234"));
    assert!(!sanitized.text.contains("blue suitcase near temple"));
}

#[test]
fn sanitizer_preserves_other_common_indian_legal_citations() {
    let raw = "Section 138 NI Act notice limitation, Section 482 CrPC quashing FIR, Article 226 Constitution of India writ mandamus, and delay filing written statement 120 days Commercial Courts Act";
    let sanitized = PublicQuerySanitizer::default().sanitize(raw).expect("query should sanitize");

    assert!(sanitized.text.contains("Section 138 NI Act"));
    assert!(sanitized.text.contains("Section 482 CrPC"));
    assert!(sanitized.text.contains("Article 226 Constitution of India"));
    assert!(sanitized.text.contains("120 days Commercial Courts Act"));
}

#[test]
fn public_answer_is_source_backed() {
    let results = vec![PublicLawDocument {
        id: "src-1".into(),
        title: "Supreme Court on anticipatory bail".into(),
        citation: "(2023) 4 SCC 100".into(),
        snippet: "The court reiterated that anticipatory bail protects against unwarranted arrest.".into(),
        url: "https://example.invalid/authority".into(),
        source_name: "Official Reporter".into(),
    }];

    let response = build_public_answer("anticipatory bail scope", &results);

    match response {
        ross_core::AnswerEnvelope::Answer(answer) => {
            assert_eq!(answer.citations.len(), 1);
            assert!(answer.answer.contains("anticipatory bail scope"));
        }
        ross_core::AnswerEnvelope::Refusal(_) => panic!("expected answer"),
    }
}
