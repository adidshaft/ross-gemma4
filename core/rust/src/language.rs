use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DocumentLanguage {
    English,
    Hindi,
    Mixed,
    Unknown,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DocumentScript {
    Latin,
    Devanagari,
    Mixed,
    Other,
    Unknown,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LanguagePageSample {
    pub page_number: u32,
    pub text: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LanguagePageProfile {
    pub page_number: u32,
    pub language: DocumentLanguage,
    pub script: DocumentScript,
    pub confidence: f32,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DocumentLanguageProfile {
    pub document_id: String,
    pub primary_language: DocumentLanguage,
    pub scripts_detected: Vec<DocumentScript>,
    pub confidence: f32,
    pub page_profiles: Vec<LanguagePageProfile>,
}

pub fn detect_document_language_profile(
    document_id: impl Into<String>,
    pages: &[LanguagePageSample],
) -> DocumentLanguageProfile {
    let mut page_profiles = Vec::with_capacity(pages.len());
    let mut latin_pages = 0usize;
    let mut devanagari_pages = 0usize;
    let mut other_pages = 0usize;
    let mut total_confidence = 0f32;

    for page in pages {
        let profile = detect_page_profile(page.page_number, &page.text);
        match profile.script {
            DocumentScript::Latin => latin_pages += 1,
            DocumentScript::Devanagari => devanagari_pages += 1,
            DocumentScript::Mixed => {
                latin_pages += 1;
                devanagari_pages += 1;
            }
            DocumentScript::Other => other_pages += 1,
            DocumentScript::Unknown => {}
        }
        total_confidence += profile.confidence;
        page_profiles.push(profile);
    }

    let primary_language = if latin_pages > 0 && devanagari_pages > 0 {
        DocumentLanguage::Mixed
    } else if devanagari_pages > 0 {
        DocumentLanguage::Hindi
    } else if latin_pages > 0 {
        DocumentLanguage::English
    } else {
        DocumentLanguage::Unknown
    };

    let mut scripts_detected = Vec::new();
    if latin_pages > 0 {
        scripts_detected.push(DocumentScript::Latin);
    }
    if devanagari_pages > 0 {
        scripts_detected.push(DocumentScript::Devanagari);
    }
    if other_pages > 0 || scripts_detected.is_empty() {
        scripts_detected.push(if other_pages > 0 {
            DocumentScript::Other
        } else {
            DocumentScript::Unknown
        });
    }

    let confidence = if page_profiles.is_empty() {
        0.0
    } else {
        (total_confidence / page_profiles.len() as f32).clamp(0.0, 1.0)
    };

    DocumentLanguageProfile {
        document_id: document_id.into(),
        primary_language,
        scripts_detected,
        confidence,
        page_profiles,
    }
}

pub fn detect_page_profile(page_number: u32, text: &str) -> LanguagePageProfile {
    let counts = script_counts(text);
    let total_letters = counts.latin + counts.devanagari + counts.other;
    let (language, script, confidence) = if total_letters == 0 {
        (DocumentLanguage::Unknown, DocumentScript::Unknown, 0.0)
    } else if counts.latin > 0 && counts.devanagari > 0 {
        let dominant = counts.latin.max(counts.devanagari) as f32 / total_letters as f32;
        (
            DocumentLanguage::Mixed,
            DocumentScript::Mixed,
            (0.52 + dominant * 0.33).clamp(0.0, 0.92),
        )
    } else if counts.devanagari > 0 {
        (
            DocumentLanguage::Hindi,
            DocumentScript::Devanagari,
            (counts.devanagari as f32 / total_letters as f32).clamp(0.55, 0.99),
        )
    } else if counts.latin > 0 {
        (
            DocumentLanguage::English,
            DocumentScript::Latin,
            (counts.latin as f32 / total_letters as f32).clamp(0.55, 0.99),
        )
    } else {
        (
            DocumentLanguage::Unknown,
            DocumentScript::Other,
            (counts.other as f32 / total_letters as f32).clamp(0.2, 0.75),
        )
    };

    LanguagePageProfile {
        page_number,
        language,
        script,
        confidence,
    }
}

#[derive(Default)]
struct ScriptCounts {
    latin: usize,
    devanagari: usize,
    other: usize,
}

fn script_counts(text: &str) -> ScriptCounts {
    let mut counts = ScriptCounts::default();
    for ch in text.chars() {
        if ch.is_ascii_alphabetic() {
            counts.latin += 1;
        } else if ('\u{0900}'..='\u{097F}').contains(&ch) || ('\u{A8E0}'..='\u{A8FF}').contains(&ch) {
            counts.devanagari += 1;
        } else if ch.is_alphabetic() {
            counts.other += 1;
        }
    }
    counts
}
