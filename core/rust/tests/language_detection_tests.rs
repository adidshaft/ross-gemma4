use ross_core::{
    detect_document_language_profile, detect_page_profile, DocumentLanguage, DocumentScript,
    LanguagePageSample,
};

#[test]
fn detects_hindi_text_language_profile() {
    let page = detect_page_profile(1, "यह एक अंतरिम आदेश है जिसमें अगली तारीख 12/05/2026 दी गई है।");
    assert_eq!(page.language, DocumentLanguage::Hindi);
    assert_eq!(page.script, DocumentScript::Devanagari);
    assert!(page.confidence >= 0.55);
}

#[test]
fn detects_mixed_english_hindi_language_profile() {
    let profile = detect_document_language_profile(
        "doc-1",
        &[LanguagePageSample {
            page_number: 1,
            text: "Order dated 12/05/2026. अगली सुनवाई 14/06/2026 है.".to_string(),
        }],
    );

    assert_eq!(profile.primary_language, DocumentLanguage::Mixed);
    assert!(profile.scripts_detected.contains(&DocumentScript::Latin));
    assert!(profile.scripts_detected.contains(&DocumentScript::Devanagari));
}
