use ross_core::{
    field_is_source_backed, source_ref_for_page, validate_source_ref, DeterministicLegalDocumentClassifier,
    DeterministicLegalFieldExtractor, DeterministicLegalFieldVerifier, DocumentExtractionInput,
    DocumentLanguageProfile, DocumentLanguage, DocumentScript, ExtractionMode, ExtractionPass,
    ExtractedLegalField, LanguagePageProfile, LegalFieldType, PageText,
};

fn sample_language_profile(document_id: &str) -> DocumentLanguageProfile {
    DocumentLanguageProfile {
        document_id: document_id.to_string(),
        primary_language: DocumentLanguage::English,
        scripts_detected: vec![DocumentScript::Latin],
        confidence: 0.92,
        page_profiles: vec![LanguagePageProfile {
            page_number: 1,
            language: DocumentLanguage::English,
            script: DocumentScript::Latin,
            confidence: 0.92,
        }],
    }
}

fn sample_input(text: &str) -> DocumentExtractionInput {
    let source = source_ref_for_page(
        "case-1",
        "doc-1",
        "Order",
        1,
        Some("Source snippet".to_string()),
        Some(0.88),
    );
    DocumentExtractionInput {
        case_id: "case-1".to_string(),
        document_id: "doc-1".to_string(),
        document_title: "Order".to_string(),
        mode: ExtractionMode::CaseAssociate,
        pages: vec![PageText {
            page_number: 1,
            text: text.to_string(),
            source_ref: source,
            ocr_confidence: Some(0.88),
            layout_hint: None,
        }],
    }
}

#[test]
fn extracts_noisy_ocr_dates() {
    let input = sample_input("Date of order: O1/O2/2O26. Next date 15-03-2026.");
    let classifier = DeterministicLegalDocumentClassifier;
    let extractor = DeterministicLegalFieldExtractor;
    let classification = classifier.classify(&input, &sample_language_profile("doc-1"));

    let fields = extractor.extract(&input, &classification, &sample_language_profile("doc-1"));

    assert!(fields.iter().any(|field| {
        field.field_type == LegalFieldType::Date
            && field.normalized_value.as_deref() == Some("01/02/2026")
    }));
}

#[test]
fn extracts_case_numbers_from_legal_caption() {
    let input = sample_input("IN THE HIGH COURT OF DELHI\nCS(COMM) No. 245/2026\nRaghav v. State");
    let classifier = DeterministicLegalDocumentClassifier;
    let extractor = DeterministicLegalFieldExtractor;
    let classification = classifier.classify(&input, &sample_language_profile("doc-1"));

    let fields = extractor.extract(&input, &classification, &sample_language_profile("doc-1"));

    assert!(fields.iter().any(|field| {
        field.field_type == LegalFieldType::CaseNumber && field.value.contains("245/2026")
    }));
}

#[test]
fn source_ref_validation_requires_page_and_ids() {
    let invalid = ross_core::SourceRef {
        case_id: "".to_string(),
        document_id: "doc-1".to_string(),
        document_title: "Title".to_string(),
        page_number: 0,
        paragraph_range: None,
        text_snippet: None,
        ocr_confidence: None,
    };

    assert!(!validate_source_ref(&invalid));
}

#[test]
fn no_extracted_field_is_created_without_source_ref() {
    let input = sample_input("Section 34 of the Arbitration and Conciliation Act. Exhibit P-1.");
    let classifier = DeterministicLegalDocumentClassifier;
    let extractor = DeterministicLegalFieldExtractor;
    let classification = classifier.classify(&input, &sample_language_profile("doc-1"));

    let fields = extractor.extract(&input, &classification, &sample_language_profile("doc-1"));

    assert!(!fields.is_empty());
    assert!(fields.iter().all(field_is_source_backed));
}

#[test]
fn verifier_marks_unsupported_value_as_needing_review() {
    let input = sample_input("This page speaks only about procedural history.");
    let verifier = DeterministicLegalFieldVerifier;
    let unsupported = ExtractedLegalField {
        id: "field-1".to_string(),
        case_id: "case-1".to_string(),
        document_id: "doc-1".to_string(),
        field_type: LegalFieldType::OrderDirection,
        label: "Order direction".to_string(),
        value: "Respondent shall deposit Rs. 50,000 within two weeks.".to_string(),
        normalized_value: Some("respondent shall deposit rs 50000 within two weeks".to_string()),
        source_refs: vec![source_ref_for_page(
            "case-1",
            "doc-1",
            "Order",
            1,
            Some("This page speaks only about procedural history.".to_string()),
            Some(0.9),
        )],
        confidence: 0.82,
        extraction_mode: ExtractionMode::CaseAssociate,
        extraction_pass: ExtractionPass::LlmExtract,
        needs_review: false,
        user_corrected: false,
        created_at: "local-now".to_string(),
        updated_at: "local-now".to_string(),
    };

    let result = verifier.verify(&input, &[unsupported]);

    assert_eq!(result.fields.len(), 1);
    assert!(result.fields[0].needs_review);
    assert!(!result.findings.is_empty());
}
