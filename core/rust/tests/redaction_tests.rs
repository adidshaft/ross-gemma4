use ross_core::{RedactionKind, Redactor};

#[test]
fn redactor_masks_sensitive_identifiers() {
    let input = "Client: Jane Doe, email jane@example.com, phone +91 98765 43210, Case No. WP-123/2024.";
    let report = Redactor::default().redact_text(input);

    assert!(report.sanitized_text.contains("[REDACTED:EMAIL]"));
    assert!(report.sanitized_text.contains("[REDACTED:PHONE]"));
    assert!(report.sanitized_text.contains("[REDACTED:CASE_NUMBER]"));
    assert!(report.spans.iter().any(|span| span.kind == RedactionKind::Email));
}

#[test]
fn redactor_masks_party_labels_and_file_names() {
    let input = "Petitioner: Arjun Rao filed affidavit_final.pdf on record.";
    let report = Redactor::default().redact_text(input);

    assert!(report.sanitized_text.contains("[REDACTED:PARTY]"));
    assert!(report.sanitized_text.contains("[REDACTED:FILE]"));
}
