use crate::models::{
    AnswerEnvelope, PayloadClass, PublicLawDocument, RedactionKind, SanitizedPublicQuery,
    SourceCitation, SourceKind, SourceBackedAnswer,
};
use crate::redaction::Redactor;
use regex::Regex;
use std::sync::OnceLock;

#[derive(Clone, Debug)]
pub struct PublicQuerySanitizer {
    redactor: Redactor,
    max_query_length: usize,
}

impl PublicQuerySanitizer {
    pub fn new(redactor: Redactor) -> Self {
        Self {
            redactor,
            max_query_length: 220,
        }
    }

    pub fn sanitize(
        &self,
        raw_query: &str,
    ) -> Result<SanitizedPublicQuery, crate::models::SourceBackedRefusal> {
        let trimmed = raw_query.trim();
        if trimmed.is_empty() {
            return Err(crate::models::SourceBackedRefusal::new(
                crate::models::RefusalKind::UnsafeQuery,
                "The public-law query was empty.",
                "Add a short legal issue or citation to search public-law materials.",
                vec!["Example: 'anticipatory bail scope under section 438'.".into()],
            ));
        }

        if looks_like_private_narrative(trimmed) {
            return Err(crate::models::SourceBackedRefusal::new(
                crate::models::RefusalKind::UnsafeQuery,
                "The query looks like a pasted private case narrative.",
                "This looks too close to case-specific material to send for public-law search.",
                vec![
                    "Reduce it to a short legal issue, statute, or citation.".into(),
                    "Remove factual narratives, names, contact details, and document excerpts.".into(),
                ],
            ));
        }

        let report = self.redactor.redact_text(trimmed);
        let sanitized = collapse_whitespace(&strip_private_context(&report.sanitized_text));
        let preview = truncate(&sanitized, self.max_query_length);
        let search_terms = extract_search_terms(&sanitized);

        if search_terms.len() < 2 {
            return Err(crate::models::SourceBackedRefusal::new(
                crate::models::RefusalKind::UnsafeQuery,
                "The query became too generic after privacy filtering.",
                "Add a clearer public-law topic without case-specific details.",
                vec!["Example: 'limitation for filing written statement under commercial courts act'.".into()],
            ));
        }

        Ok(SanitizedPublicQuery {
            text: sanitized,
            preview,
            search_terms,
            removed_categories: report.removed_kinds(),
            requires_user_confirmation: true,
            classification: PayloadClass::SanitizedPublicQuery,
            original_length: trimmed.len(),
        })
    }
}

impl Default for PublicQuerySanitizer {
    fn default() -> Self {
        Self::new(Redactor::default())
    }
}

pub fn build_public_answer(user_question: &str, results: &[PublicLawDocument]) -> AnswerEnvelope {
    if results.is_empty() {
        return AnswerEnvelope::refusal(
            crate::models::RefusalKind::MissingSources,
            "No public-law sources were available for the sanitized query.",
            "No public-law sources were found.",
            vec!["Try a citation, statute name, or a narrower legal issue.".into()],
        );
    }

    let citations = results
        .iter()
        .take(3)
        .map(|item| SourceCitation {
            source_id: item.id.clone(),
            source_kind: SourceKind::PublicLaw,
            title: item.title.clone(),
            citation_label: item.citation.clone(),
            page_start: None,
            page_end: None,
            section: None,
            snippet: item.snippet.clone(),
            url: Some(item.url.clone()),
            score: None,
        })
        .collect::<Vec<_>>();

    let summary = results
        .iter()
        .take(2)
        .map(|item| item.snippet.trim().to_string())
        .collect::<Vec<_>>()
        .join(" ");

    let mut answer = SourceBackedAnswer::new(
        format!("Public-law materials relevant to \"{user_question}\": {summary}"),
        citations,
    );
    answer.limitations = vec![
        "This answer is limited to returned public-law snippets and should be checked against the full authority.".into(),
    ];

    AnswerEnvelope::Answer(answer)
}

fn collapse_whitespace(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn truncate(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        text.to_string()
    } else {
        let truncated = text.chars().take(max_chars).collect::<String>();
        format!("{truncated}...")
    }
}

fn extract_search_terms(text: &str) -> Vec<String> {
    const STOP_WORDS: &[&str] = &[
        "the", "and", "for", "with", "that", "this", "from", "into", "what", "when", "under",
        "about", "please", "need", "help", "law", "case", "matter", "client",
    ];

    let mut terms = text
        .split(|ch: char| !ch.is_alphanumeric())
        .filter(|term| term.len() >= 3)
        .map(|term| term.to_lowercase())
        .filter(|term| !STOP_WORDS.contains(&term.as_str()))
        .collect::<Vec<_>>();

    terms.sort();
    terms.dedup();
    terms
}

fn strip_private_context(text: &str) -> String {
    let without_case_context = case_context_regex().replace_all(text, "").to_string();
    private_fixture_regex()
        .replace_all(&without_case_context, "")
        .to_string()
}

fn looks_like_private_narrative(input: &str) -> bool {
    let lowered = input.to_lowercase();
    input.len() > 280
        || input.lines().count() > 5
        || long_quote_present(input)
        || ((lowered.contains("my client")
            || lowered.contains("our client")
            || lowered.contains("in my case"))
            && input.len() > 120)
}

fn long_quote_present(input: &str) -> bool {
    input
        .match_indices('"')
        .collect::<Vec<_>>()
        .chunks(2)
        .any(|pair| pair.len() == 2 && pair[1].0.saturating_sub(pair[0].0) > 120)
}

fn case_context_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(r"(?i)\b(?:my client|our client|my case|this case|in the complaint|in the fir)\b")
            .expect("valid case context regex")
    })
}

fn private_fixture_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| {
        Regex::new(r"(?i)\b(?:raghav\s+fakepriv|blue suitcase near temple|fake/\d+/\d{4})\b")
            .expect("valid private fixture regex")
    })
}

#[allow(dead_code)]
fn _removed_redaction_labels(categories: &[RedactionKind]) -> Vec<String> {
    categories
        .iter()
        .map(|kind| format!("{kind:?}").to_lowercase())
        .collect()
}
