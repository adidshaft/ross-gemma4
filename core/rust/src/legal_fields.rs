use crate::extraction::{
    field_id, field_is_source_backed, local_timestamp, score_field_confidence, DocumentExtractionInput,
    ExtractionFinding, ExtractionFindingKind, ExtractionFindingSeverity, ExtractionMode, ExtractionPass,
    ExtractedLegalField, FieldConfidenceSignal, LegalDocumentClassification, LegalDocumentType,
    LegalFieldType, SourceRef,
};
use crate::language::{DocumentLanguageProfile, DocumentScript};
use regex::Regex;
use std::collections::{BTreeMap, BTreeSet};
use std::sync::OnceLock;

pub struct DeterministicLegalDocumentClassifier;

impl DeterministicLegalDocumentClassifier {
    pub fn classify(
        &self,
        input: &DocumentExtractionInput,
        language_profile: &DocumentLanguageProfile,
    ) -> LegalDocumentClassification {
        let mut scores = BTreeMap::from([
            (LegalDocumentType::Pleading, 0f32),
            (LegalDocumentType::Order, 0f32),
            (LegalDocumentType::Judgment, 0f32),
            (LegalDocumentType::Affidavit, 0f32),
            (LegalDocumentType::Notice, 0f32),
            (LegalDocumentType::Evidence, 0f32),
            (LegalDocumentType::Correspondence, 0f32),
            (LegalDocumentType::Misc, 0.1f32),
        ]);
        let mut supporting_refs: Vec<SourceRef> = Vec::new();

        for page in &input.pages {
            let lowered = page.text.to_lowercase();
            let mut add_score = |doc_type: LegalDocumentType, score: f32| {
                if let Some(current) = scores.get_mut(&doc_type) {
                    *current += score;
                }
                if supporting_refs.len() < 3 {
                    supporting_refs.push(with_snippet(&page.source_ref, compact_line(&page.text)));
                }
            };

            if lowered.contains("hon'ble") || lowered.contains("coram") || lowered.contains("judgment") {
                add_score(LegalDocumentType::Judgment, 0.9);
            }
            if lowered.contains("order") || lowered.contains("ordered as under") || lowered.contains("it is directed") {
                add_score(LegalDocumentType::Order, 0.8);
            }
            if lowered.contains("affidavit") || lowered.contains("solemnly affirm") {
                add_score(LegalDocumentType::Affidavit, 1.0);
            }
            if lowered.contains("show cause notice")
                || lowered.contains("legal notice")
                || lowered.contains("notice is hereby issued")
            {
                add_score(LegalDocumentType::Notice, 0.95);
            }
            if lowered.contains("petition")
                || lowered.contains("plaint")
                || lowered.contains("written statement")
                || lowered.contains("application under")
            {
                add_score(LegalDocumentType::Pleading, 0.75);
            }
            if lowered.contains("exhibit")
                || lowered.contains("annexure")
                || lowered.contains("marked as")
            {
                add_score(LegalDocumentType::Evidence, 0.7);
            }
            if lowered.contains("dear sir")
                || lowered.contains("regards")
                || lowered.contains("subject:")
            {
                add_score(LegalDocumentType::Correspondence, 0.7);
            }
        }

        let (doc_type, score) = scores
            .into_iter()
            .max_by(|left, right| left.1.partial_cmp(&right.1).unwrap())
            .unwrap_or((LegalDocumentType::Misc, 0.1));

        let subtype = match doc_type {
            LegalDocumentType::Order => Some("interim_or_operational".to_string()),
            LegalDocumentType::Pleading if language_profile.primary_language != crate::language::DocumentLanguage::English => {
                Some("bilingual_pleading".to_string())
            }
            _ => None,
        };

        let confidence = (score / input.pages.len().max(1) as f32).clamp(0.35, 0.97);
        let needs_review = confidence < 0.68
            || language_profile.scripts_detected.contains(&DocumentScript::Mixed)
            || language_profile.confidence < 0.62;

        LegalDocumentClassification {
            document_id: input.document_id.clone(),
            r#type: doc_type,
            subtype,
            confidence,
            source_refs: supporting_refs.into_iter().take(3).collect(),
            needs_review,
        }
    }
}

pub struct DeterministicLegalFieldExtractor;

impl DeterministicLegalFieldExtractor {
    pub fn extract(
        &self,
        input: &DocumentExtractionInput,
        classification: &LegalDocumentClassification,
        language_profile: &DocumentLanguageProfile,
    ) -> Vec<ExtractedLegalField> {
        let mut fields = Vec::new();
        let mut seen = BTreeSet::new();

        for page in &input.pages {
            for (ordinal, value) in extract_case_numbers(&page.text).into_iter().enumerate() {
                push_field(
                    &mut fields,
                    &mut seen,
                    input,
                    page,
                    LegalFieldType::CaseNumber,
                    "Case number",
                    value.clone(),
                    Some(value),
                    ExtractionPass::Regex,
                    score_field_confidence(FieldConfidenceSignal {
                        evidence_strength: 0.86,
                        source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                        language_confidence: Some(language_profile.confidence),
                        verified: false,
                    }),
                    ordinal,
                );
            }

            for (ordinal, court_name) in extract_court_names(&page.text).into_iter().enumerate() {
                push_field(
                    &mut fields,
                    &mut seen,
                    input,
                    page,
                    LegalFieldType::Court,
                    "Court",
                    court_name.clone(),
                    Some(court_name),
                    ExtractionPass::Regex,
                    score_field_confidence(FieldConfidenceSignal {
                        evidence_strength: 0.8,
                        source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                        language_confidence: Some(language_profile.confidence),
                        verified: false,
                    }),
                    ordinal,
                );
            }

            for (ordinal, date_value) in extract_dates(&page.text).into_iter().enumerate() {
                let field_type = if date_value.is_next_date {
                    LegalFieldType::NextDate
                } else {
                    LegalFieldType::Date
                };
                push_field(
                    &mut fields,
                    &mut seen,
                    input,
                    page,
                    field_type,
                    field_type.label(),
                    date_value.original.clone(),
                    Some(date_value.normalized),
                    ExtractionPass::Regex,
                    score_field_confidence(FieldConfidenceSignal {
                        evidence_strength: 0.83,
                        source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                        language_confidence: Some(language_profile.confidence),
                        verified: false,
                    }),
                    ordinal,
                );
            }

            for (ordinal, section) in extract_sections(&page.text).into_iter().enumerate() {
                push_field(
                    &mut fields,
                    &mut seen,
                    input,
                    page,
                    LegalFieldType::Section,
                    "Section",
                    section.clone(),
                    Some(section),
                    ExtractionPass::Regex,
                    score_field_confidence(FieldConfidenceSignal {
                        evidence_strength: 0.78,
                        source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                        language_confidence: Some(language_profile.confidence),
                        verified: false,
                    }),
                    ordinal,
                );
            }

            for (ordinal, exhibit) in extract_exhibits(&page.text).into_iter().enumerate() {
                push_field(
                    &mut fields,
                    &mut seen,
                    input,
                    page,
                    LegalFieldType::ExhibitNumber,
                    "Exhibit",
                    exhibit.clone(),
                    Some(exhibit),
                    ExtractionPass::Regex,
                    score_field_confidence(FieldConfidenceSignal {
                        evidence_strength: 0.74,
                        source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                        language_confidence: Some(language_profile.confidence),
                        verified: false,
                    }),
                    ordinal,
                );
            }

            for (ordinal, party) in extract_parties(&page.text).into_iter().enumerate() {
                push_field(
                    &mut fields,
                    &mut seen,
                    input,
                    page,
                    LegalFieldType::PartyName,
                    "Party",
                    party.clone(),
                    Some(normalize_for_match(&party)),
                    ExtractionPass::Regex,
                    score_field_confidence(FieldConfidenceSignal {
                        evidence_strength: 0.76,
                        source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                        language_confidence: Some(language_profile.confidence),
                        verified: false,
                    }),
                    ordinal,
                );
            }

            for (ordinal, amount) in extract_amounts(&page.text).into_iter().enumerate() {
                push_field(
                    &mut fields,
                    &mut seen,
                    input,
                    page,
                    LegalFieldType::Amount,
                    "Amount",
                    amount.clone(),
                    Some(amount.clone()),
                    ExtractionPass::Regex,
                    score_field_confidence(FieldConfidenceSignal {
                        evidence_strength: 0.7,
                        source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                        language_confidence: Some(language_profile.confidence),
                        verified: false,
                    }),
                    ordinal,
                );
            }

            if input.mode != ExtractionMode::Basic {
                for (ordinal, issue) in extract_issue_candidates(&page.text).into_iter().enumerate() {
                    push_field(
                        &mut fields,
                        &mut seen,
                        input,
                        page,
                        LegalFieldType::Issue,
                        "Issue",
                        issue.clone(),
                        Some(normalize_for_match(&issue)),
                        ExtractionPass::LlmExtract,
                        score_field_confidence(FieldConfidenceSignal {
                            evidence_strength: if input.mode == ExtractionMode::QuickStart { 0.58 } else { 0.68 },
                            source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                            language_confidence: Some(language_profile.confidence),
                            verified: false,
                        }),
                        ordinal,
                    );
                }

                for (ordinal, direction) in extract_order_directions(&page.text).into_iter().enumerate() {
                    push_field(
                        &mut fields,
                        &mut seen,
                        input,
                        page,
                        LegalFieldType::OrderDirection,
                        "Order direction",
                        direction.clone(),
                        Some(normalize_for_match(&direction)),
                        ExtractionPass::LlmExtract,
                        score_field_confidence(FieldConfidenceSignal {
                            evidence_strength: if classification.r#type == LegalDocumentType::Order { 0.74 } else { 0.62 },
                            source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                            language_confidence: Some(language_profile.confidence),
                            verified: false,
                        }),
                        ordinal,
                    );
                }

                for (ordinal, relief) in extract_reliefs(&page.text).into_iter().enumerate() {
                    let field_type = if relief.to_lowercase().contains("prayer") {
                        LegalFieldType::Prayer
                    } else {
                        LegalFieldType::Relief
                    };
                    push_field(
                        &mut fields,
                        &mut seen,
                        input,
                        page,
                        field_type,
                        field_type.label(),
                        relief.clone(),
                        Some(normalize_for_match(&relief)),
                        ExtractionPass::LlmExtract,
                        score_field_confidence(FieldConfidenceSignal {
                            evidence_strength: 0.64,
                            source_quality: page.ocr_confidence.or(page.source_ref.ocr_confidence),
                            language_confidence: Some(language_profile.confidence),
                            verified: false,
                        }),
                        ordinal,
                    );
                }
            }
        }

        fields
    }
}

pub struct VerificationResult {
    pub fields: Vec<ExtractedLegalField>,
    pub findings: Vec<ExtractionFinding>,
}

pub struct DeterministicLegalFieldVerifier;

impl DeterministicLegalFieldVerifier {
    pub fn verify(
        &self,
        input: &DocumentExtractionInput,
        fields: &[ExtractedLegalField],
    ) -> VerificationResult {
        let mut verified_fields = Vec::with_capacity(fields.len());
        let mut findings = Vec::new();

        for field in fields {
            let supported = source_supported_by_pages(field, &input.pages);
            let mut updated = field.clone();
            if !supported {
                updated.needs_review = true;
                updated.confidence = (updated.confidence - 0.25).clamp(0.05, 0.79);
                findings.push(ExtractionFinding {
                    id: format!("finding-unsupported-{}", updated.id),
                    case_id: updated.case_id.clone(),
                    document_id: updated.document_id.clone(),
                    kind: match updated.field_type {
                        LegalFieldType::OrderDirection => ExtractionFindingKind::AmbiguousOrderDirection,
                        _ => ExtractionFindingKind::UnsupportedLayout,
                    },
                    message: format!(
                        "{} needs review because Ross could not confirm the value against the cited page text.",
                        updated.label
                    ),
                    source_refs: updated.source_refs.clone(),
                    severity: ExtractionFindingSeverity::Warning,
                    resolved: false,
                });
            } else if updated.extraction_pass == ExtractionPass::LlmExtract {
                updated.extraction_pass = ExtractionPass::LlmVerify;
                updated.confidence = (updated.confidence + 0.12).clamp(0.05, 0.98);
            }

            if !field_is_source_backed(&updated) {
                updated.needs_review = true;
                findings.push(ExtractionFinding {
                    id: format!("finding-source-{}", updated.id),
                    case_id: updated.case_id.clone(),
                    document_id: updated.document_id.clone(),
                    kind: ExtractionFindingKind::UnsupportedLayout,
                    message: format!("{} is missing a usable source reference.", updated.label),
                    source_refs: updated.source_refs.clone(),
                    severity: ExtractionFindingSeverity::Critical,
                    resolved: false,
                });
            }

            verified_fields.push(updated);
        }

        findings.extend(conflict_findings(&verified_fields));

        VerificationResult {
            fields: verified_fields,
            findings,
        }
    }
}

fn push_field(
    fields: &mut Vec<ExtractedLegalField>,
    seen: &mut BTreeSet<String>,
    input: &DocumentExtractionInput,
    page: &crate::extraction::PageText,
    field_type: LegalFieldType,
    label: &str,
    value: String,
    normalized_value: Option<String>,
    extraction_pass: ExtractionPass,
    confidence: f32,
    ordinal: usize,
) {
    let dedupe_key = format!(
        "{:?}:{}",
        field_type,
        normalized_value.clone().unwrap_or_else(|| normalize_for_match(&value))
    );
    if value.trim().is_empty() || seen.contains(&dedupe_key) {
        return;
    }
    seen.insert(dedupe_key);

    let source = with_snippet(&page.source_ref, compact_line(&value));
    fields.push(ExtractedLegalField {
        id: field_id(&input.document_id, &field_type, page.page_number, ordinal),
        case_id: input.case_id.clone(),
        document_id: input.document_id.clone(),
        field_type,
        label: label.to_string(),
        value,
        normalized_value,
        source_refs: vec![source],
        confidence,
        extraction_mode: input.mode,
        extraction_pass,
        needs_review: confidence < 0.68,
        user_corrected: false,
        created_at: local_timestamp(),
        updated_at: local_timestamp(),
    });
}

fn extract_case_numbers(text: &str) -> Vec<String> {
    let mut matches = case_number_regex()
        .captures_iter(text)
        .filter_map(|caps| caps.get(0).map(|m| m.as_str().trim().to_string()))
        .take(3)
        .collect::<Vec<_>>();

    if matches.is_empty() {
        matches = text
            .lines()
            .map(str::trim)
            .filter(|line| {
                fallback_case_number_regex().is_match(line)
                    || (line.contains('/')
                        && line.chars().any(|ch| ch.is_ascii_uppercase()))
            })
            .map(|line| line.to_string())
            .take(3)
            .collect();
    }

    matches
}

#[derive(Clone, Debug)]
struct NormalizedDate {
    original: String,
    normalized: String,
    is_next_date: bool,
}

fn extract_dates(text: &str) -> Vec<NormalizedDate> {
    let mut dates = Vec::new();
    for line in text.lines() {
        let normalized_line = normalize_ocr_digits(line);
        for capture in date_regex().find_iter(&normalized_line) {
            let prefix = normalized_line[..capture.start()].to_lowercase();
            let is_next_date = prefix.contains("next date") || prefix.contains("listed on");
            let value = capture.as_str().trim().to_string();
            dates.push(NormalizedDate {
                original: value.clone(),
                normalized: normalize_date_string(&value),
                is_next_date,
            });
            if dates.len() >= 6 {
                return dates;
            }
        }
    }
    dates
}

fn extract_court_names(text: &str) -> Vec<String> {
    text.lines()
        .map(str::trim)
        .filter(|line| {
            let lowered = line.to_lowercase();
            lowered.contains("court")
                || lowered.contains("tribunal")
                || lowered.contains("commission")
        })
        .map(|line| line.to_string())
        .take(3)
        .collect()
}

fn extract_sections(text: &str) -> Vec<String> {
    section_regex()
        .captures_iter(text)
        .filter_map(|caps| caps.get(0).map(|m| m.as_str().trim().to_string()))
        .take(8)
        .collect()
}

fn extract_exhibits(text: &str) -> Vec<String> {
    exhibit_regex()
        .captures_iter(text)
        .filter_map(|caps| caps.get(0).map(|m| m.as_str().trim().to_string()))
        .take(8)
        .collect()
}

fn extract_parties(text: &str) -> Vec<String> {
    let mut parties = Vec::new();
    for line in text.lines().map(str::trim).filter(|line| !line.is_empty()) {
        let lowered = line.to_lowercase();
        if lowered.contains(" versus ") || lowered.contains(" vs ") || lowered.contains(" v. ") {
            let separator = if lowered.contains(" versus ") {
                "versus"
            } else if lowered.contains(" vs ") {
                "vs"
            } else {
                "v."
            };
            let pieces = line.split(separator).map(str::trim).collect::<Vec<_>>();
            for piece in pieces {
                if !piece.is_empty() {
                    parties.push(piece.trim_matches(|c: char| c == ':' || c == '-').to_string());
                }
            }
            break;
        }
    }
    parties.truncate(4);
    parties
}

fn extract_amounts(text: &str) -> Vec<String> {
    amount_regex()
        .captures_iter(text)
        .filter_map(|caps| caps.get(0).map(|m| m.as_str().trim().to_string()))
        .take(5)
        .collect()
}

fn extract_issue_candidates(text: &str) -> Vec<String> {
    text.lines()
        .map(str::trim)
        .filter(|line| {
            let lowered = line.to_lowercase();
            lowered.starts_with("issue")
                || lowered.starts_with("whether")
                || lowered.contains("point for consideration")
        })
        .map(|line| line.to_string())
        .take(4)
        .collect()
}

fn extract_order_directions(text: &str) -> Vec<String> {
    text.lines()
        .map(str::trim)
        .filter(|line| {
            let lowered = line.to_lowercase();
            lowered.contains("it is directed")
                || lowered.contains("is directed to")
                || lowered.contains("shall")
                || lowered.contains("listed on")
                || lowered.contains("next date")
                || lowered.contains("compliance")
        })
        .map(|line| line.to_string())
        .take(5)
        .collect()
}

fn extract_reliefs(text: &str) -> Vec<String> {
    text.lines()
        .map(str::trim)
        .filter(|line| {
            let lowered = line.to_lowercase();
            lowered.starts_with("prayer")
                || lowered.contains("it is therefore prayed")
                || lowered.contains("relief sought")
        })
        .map(|line| line.to_string())
        .take(4)
        .collect()
}

fn source_supported_by_pages(field: &ExtractedLegalField, pages: &[crate::extraction::PageText]) -> bool {
    let normalized_value = field
        .normalized_value
        .clone()
        .unwrap_or_else(|| normalize_for_match(&field.value));

    field.source_refs.iter().any(|reference| {
        pages.iter()
            .find(|page| page.page_number == reference.page_number)
            .map(|page| {
                let haystack = normalize_for_match(&normalize_ocr_digits(&page.text));
                haystack.contains(&normalized_value)
                    || reference
                        .text_snippet
                        .as_ref()
                        .map(|snippet| normalize_for_match(snippet).contains(&normalized_value))
                        .unwrap_or(false)
            })
            .unwrap_or(false)
    })
}

fn conflict_findings(fields: &[ExtractedLegalField]) -> Vec<ExtractionFinding> {
    let mut findings = Vec::new();
    findings.extend(conflict_for_field_type(
        fields,
        LegalFieldType::CaseNumber,
        ExtractionFindingKind::CaseNumberConflict,
        "Ross found multiple competing case numbers. Review the supported value.",
    ));
    findings.extend(conflict_for_field_type(
        fields,
        LegalFieldType::Date,
        ExtractionFindingKind::DateConflict,
        "Ross found multiple important dates that may conflict. Review the supported source pages.",
    ));
    findings.extend(conflict_for_field_type(
        fields,
        LegalFieldType::PartyName,
        ExtractionFindingKind::PartyConflict,
        "Ross found party naming variation that needs advocate review.",
    ));
    findings
}

fn conflict_for_field_type(
    fields: &[ExtractedLegalField],
    target_type: LegalFieldType,
    kind: ExtractionFindingKind,
    message: &str,
) -> Vec<ExtractionFinding> {
    let relevant = fields
        .iter()
        .filter(|field| field.field_type == target_type)
        .collect::<Vec<_>>();
    let unique = relevant
        .iter()
        .map(|field| field.normalized_value.clone().unwrap_or_else(|| normalize_for_match(&field.value)))
        .collect::<BTreeSet<_>>();

    if unique.len() <= 1 || relevant.is_empty() {
        return Vec::new();
    }

    vec![ExtractionFinding {
        id: format!("finding-conflict-{:?}", kind).to_lowercase(),
        case_id: relevant[0].case_id.clone(),
        document_id: relevant[0].document_id.clone(),
        kind,
        message: message.to_string(),
        source_refs: relevant.iter().flat_map(|field| field.source_refs.clone()).take(4).collect(),
        severity: ExtractionFindingSeverity::Warning,
        resolved: false,
    }]
}

fn normalize_date_string(value: &str) -> String {
    normalize_ocr_digits(value)
        .replace('.', "/")
        .replace('-', "/")
        .replace(" ", "")
}

fn normalize_ocr_digits(value: &str) -> String {
    value
        .chars()
        .map(|ch| match ch {
            'O' | 'o' => '0',
            'I' | 'l' | '|' => '1',
            _ => ch,
        })
        .collect()
}

fn normalize_for_match(value: &str) -> String {
    normalize_ocr_digits(value)
        .to_lowercase()
        .replace(|ch: char| !ch.is_alphanumeric(), " ")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn compact_line(value: &str) -> Option<String> {
    let compact = value
        .replace('\n', " ")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
    if compact.is_empty() {
        None
    } else {
        Some(compact.chars().take(180).collect())
    }
}

fn with_snippet(reference: &SourceRef, snippet: Option<String>) -> SourceRef {
    let mut copy = reference.clone();
    if copy.text_snippet.is_none() {
        copy.text_snippet = snippet;
    }
    copy
}

fn case_number_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(
            r"(?ix)
            \b(
                (?:[A-Z]{1,10}(?:\([A-Z]+\))?|
                    w\.?p\.?|
                    c\.?s\.?|
                    m\.?a\.?|
                    oa|
                    case|
                    petition|
                    appeal|
                    application|
                    suit)
                \s*(?:no\.?|number)?\s*[:.-]?\s*
                [A-Z0-9./() -]{1,30}\d{1,8}/\d{2,4}
            |
                [A-Z]{2,12}/\d{1,8}/\d{4}
            )\b",
        )
        .expect("valid case number regex")
    })
}

fn fallback_case_number_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(r"(?i).*(?:no\.?|number).*?\d{1,8}/\d{2,4}.*|[A-Z]{1,10}(?:\([A-Z]+\))?\s*\d{1,8}/\d{2,4}")
            .expect("valid fallback case number regex")
    })
}

fn date_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(
            r"(?ix)
            \b(
                \d{1,2}[./-]\d{1,2}[./-]\d{2,4}
                |
                \d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+\d{2,4}
            )\b",
        )
        .expect("valid date regex")
    })
}

fn section_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(r"(?i)\b(?:section|sections|u/s|under section)\s+[0-9A-Za-z/(), -]{1,40}")
            .expect("valid section regex")
    })
}

fn exhibit_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(r"(?i)\b(?:exhibit|ex\.?|annexure)\s+[A-Za-z0-9/-]{1,20}")
            .expect("valid exhibit regex")
    })
}

fn amount_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(r"(?i)(?:₹|rs\.?|inr)\s*[\d,]+(?:\.\d{2})?")
            .expect("valid amount regex")
    })
}
