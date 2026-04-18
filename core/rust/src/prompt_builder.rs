use crate::models::DocumentChunk;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PromptMode {
    CaseQuestion,
    Chronology,
    EvidenceMatrix,
}

#[derive(Clone, Debug, PartialEq)]
pub struct PromptBuildRequest {
    pub mode: PromptMode,
    pub user_question: String,
    pub retrieved_chunks: Vec<DocumentChunk>,
    pub audience_note: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PromptPackage {
    pub system_instructions: String,
    pub source_pack: String,
    pub user_prompt: String,
}

#[derive(Clone, Debug)]
pub struct PromptBuilder {
    max_sources: usize,
}

impl PromptBuilder {
    pub fn new(max_sources: usize) -> Self {
        Self { max_sources }
    }

    pub fn build(&self, request: &PromptBuildRequest) -> PromptPackage {
        let system_instructions = match request.mode {
            PromptMode::CaseQuestion => {
                "You are a local legal assistant. Use only supplied sources. If a fact is missing, say `Not found in the case file`.".to_string()
            }
            PromptMode::Chronology => {
                "Build a chronology only from supplied sources. Preserve dates and source references.".to_string()
            }
            PromptMode::EvidenceMatrix => {
                "Build an evidence matrix only from supplied sources. Separate support from contradiction and cite every line.".to_string()
            }
        };

        let source_pack = request
            .retrieved_chunks
            .iter()
            .take(self.max_sources)
            .map(|chunk| {
                format!(
                    "[{} | {}-{}]\n{}",
                    chunk.title,
                    chunk.page_start.unwrap_or(0),
                    chunk.page_end.unwrap_or(0),
                    chunk.text
                )
            })
            .collect::<Vec<_>>()
            .join("\n\n");

        let user_prompt = match &request.audience_note {
            Some(note) => format!("Question: {}\nAudience note: {note}", request.user_question),
            None => format!("Question: {}", request.user_question),
        };

        PromptPackage {
            system_instructions,
            source_pack,
            user_prompt,
        }
    }
}

impl Default for PromptBuilder {
    fn default() -> Self {
        Self::new(6)
    }
}
