use crate::models::{RedactionKind, RedactionReport, RedactionSpan};
use regex::Regex;
use std::sync::OnceLock;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RedactorConfig {
    pub redact_file_names: bool,
    pub redact_numeric_identifiers: bool,
}

impl Default for RedactorConfig {
    fn default() -> Self {
        Self {
            redact_file_names: true,
            redact_numeric_identifiers: true,
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct Redactor {
    config: RedactorConfig,
}

impl Redactor {
    pub fn new(config: RedactorConfig) -> Self {
        Self { config }
    }

    pub fn redact_text(&self, input: &str) -> RedactionReport {
        let spans = self.collect_spans(input);
        if spans.is_empty() {
            return RedactionReport {
                sanitized_text: input.trim().to_string(),
                spans,
                warnings: Vec::new(),
            };
        }

        let mut sanitized = String::with_capacity(input.len());
        let mut cursor = 0usize;
        for span in &spans {
            sanitized.push_str(&input[cursor..span.start]);
            sanitized.push_str(&span.replacement);
            cursor = span.end;
        }
        sanitized.push_str(&input[cursor..]);

        RedactionReport {
            sanitized_text: sanitized.split_whitespace().collect::<Vec<_>>().join(" "),
            warnings: vec!["Sensitive material was conservatively redacted before leaving the device.".into()],
            spans,
        }
    }

    pub fn contains_sensitive_markers(&self, input: &str) -> bool {
        !self.collect_spans(input).is_empty()
    }

    fn collect_spans(&self, input: &str) -> Vec<RedactionSpan> {
        let mut spans = Vec::new();
        self.push_matches(input, email_regex(), RedactionKind::Email, &mut spans);
        self.push_matches(input, phone_regex(), RedactionKind::PhoneNumber, &mut spans);
        self.push_matches(input, case_number_regex(), RedactionKind::CaseNumber, &mut spans);
        self.push_matches(input, party_name_regex(), RedactionKind::PartyName, &mut spans);
        self.push_matches(input, long_quote_regex(), RedactionKind::LongQuote, &mut spans);

        if self.config.redact_file_names {
            self.push_matches(input, file_name_regex(), RedactionKind::FileName, &mut spans);
        }
        if self.config.redact_numeric_identifiers {
            self.push_matches(
                input,
                numeric_identifier_regex(),
                RedactionKind::NumericIdentifier,
                &mut spans,
            );
        }

        spans.sort_by(|left, right| {
            left.start
                .cmp(&right.start)
                .then_with(|| right.end.cmp(&left.end))
        });

        merge_overlaps(input, spans)
    }

    fn push_matches(
        &self,
        input: &str,
        regex: &Regex,
        kind: RedactionKind,
        spans: &mut Vec<RedactionSpan>,
    ) {
        for capture in regex.find_iter(input) {
            spans.push(RedactionSpan {
                start: capture.start(),
                end: capture.end(),
                replacement: format!("[REDACTED:{}]", replacement_label(&kind)),
                kind: kind.clone(),
                original_excerpt: capture.as_str().to_string(),
            });
        }
    }
}

fn merge_overlaps(input: &str, spans: Vec<RedactionSpan>) -> Vec<RedactionSpan> {
    let mut merged: Vec<RedactionSpan> = Vec::new();

    for span in spans {
        if let Some(current) = merged.last_mut() {
            if span.start <= current.end {
                current.end = current.end.max(span.end);
                current.original_excerpt = input[current.start..current.end].to_string();
                continue;
            }
        }
        merged.push(span);
    }

    merged
}

fn replacement_label(kind: &RedactionKind) -> &'static str {
    match kind {
        RedactionKind::Email => "EMAIL",
        RedactionKind::PhoneNumber => "PHONE",
        RedactionKind::CaseNumber => "CASE_NUMBER",
        RedactionKind::FileName => "FILE",
        RedactionKind::NumericIdentifier => "IDENTIFIER",
        RedactionKind::PartyName => "PARTY",
        RedactionKind::LongQuote => "LONG_QUOTE",
    }
}

fn email_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(r"(?i)\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b").expect("valid email regex")
    })
}

fn phone_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| Regex::new(r"(?x)(?:\+?\d[\d\s().-]{8,}\d)").expect("valid phone regex"))
}

fn case_number_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(
            r"(?i)\b(?:case|matter|petition|appeal|suit|complaint|wp|w\.p\.|crl|cs)\s*(?:no\.?|number)?\s*(?::|#|-)?\s*[A-Z0-9./-]{3,}\b",
        )
        .expect("valid case number regex")
    })
}

fn file_name_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(r"(?i)\b[\w.-]+\.(?:pdf|doc|docx|txt|jpg|jpeg|png)\b").expect("valid file regex")
    })
}

fn numeric_identifier_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| Regex::new(r"\b\d{8,}\b").expect("valid numeric identifier regex"))
}

fn party_name_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(
            r"(?i)\b(?:client|petitioner|respondent|appellant|accused|complainant)\s*[:\-]\s*[A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){0,3}\b",
        )
        .expect("valid party regex")
    })
}

fn long_quote_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| Regex::new(r#""[^"]{120,}""#).expect("valid long quote regex"))
}
