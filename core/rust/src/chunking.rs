use crate::models::{ChunkingConfig, DocumentChunk, SourceKind};

#[derive(Clone, Debug)]
pub struct TextChunker {
    config: ChunkingConfig,
}

impl TextChunker {
    pub fn new(config: ChunkingConfig) -> Self {
        Self { config }
    }

    pub fn config(&self) -> &ChunkingConfig {
        &self.config
    }

    pub fn chunk_document(
        &self,
        document_id: &str,
        title: &str,
        text: &str,
        source_kind: SourceKind,
    ) -> Vec<DocumentChunk> {
        let chars = text.chars().collect::<Vec<_>>();
        if chars.is_empty() {
            return Vec::new();
        }

        let mut start = 0usize;
        let mut index = 0usize;
        let mut chunks = Vec::new();

        while start < chars.len() {
            let mut end = usize::min(start + self.config.target_chars, chars.len());
            end = self.prefer_boundary(&chars, start, end);

            if end <= start {
                end = usize::min(start + self.config.target_chars, chars.len());
            }

            let (trimmed_start, trimmed_end) = trim_range(&chars, start, end);
            if trimmed_end > trimmed_start {
                let chunk_chars = &chars[trimmed_start..trimmed_end];
                let chunk_text = chunk_chars.iter().collect::<String>();
                let page_start = page_number_at(&chars, trimmed_start);
                let page_end = page_number_at(&chars, trimmed_end.saturating_sub(1));

                chunks.push(DocumentChunk {
                    chunk_id: format!("{document_id}::{:04}", index + 1),
                    document_id: document_id.to_string(),
                    title: title.to_string(),
                    source_kind: source_kind.clone(),
                    text: chunk_text,
                    page_start: Some(page_start),
                    page_end: Some(page_end),
                    section: None,
                    token_count: chunk_chars
                        .iter()
                        .collect::<String>()
                        .split_whitespace()
                        .count(),
                    char_start: trimmed_start,
                    char_end: trimmed_end,
                    embedding: None,
                });
                index += 1;
            }

            if end >= chars.len() {
                break;
            }

            let next_start = end.saturating_sub(self.config.overlap_chars);
            start = if next_start > start { next_start } else { end };
        }

        chunks
    }

    fn prefer_boundary(&self, chars: &[char], start: usize, proposed_end: usize) -> usize {
        if proposed_end >= chars.len() {
            return chars.len();
        }

        let min_end = usize::min(start + self.config.min_chunk_chars, chars.len());
        let search_floor = usize::min(min_end, proposed_end);
        let search_start = search_floor.saturating_sub(80);
        let search_end = usize::min(proposed_end + 80, chars.len());

        if self.config.respect_paragraphs {
            if let Some(index) = find_last_paragraph_break(chars, search_start, search_end) {
                if index >= min_end {
                    return index;
                }
            }
        }

        if let Some(index) = find_last_whitespace(chars, search_start, search_end) {
            if index >= min_end {
                return index;
            }
        }

        proposed_end
    }
}

impl Default for TextChunker {
    fn default() -> Self {
        Self::new(ChunkingConfig::default())
    }
}

fn trim_range(chars: &[char], start: usize, end: usize) -> (usize, usize) {
    let mut real_start = start;
    let mut real_end = end;

    while real_start < real_end && chars[real_start].is_whitespace() {
        real_start += 1;
    }
    while real_end > real_start && chars[real_end - 1].is_whitespace() {
        real_end -= 1;
    }

    (real_start, real_end)
}

fn find_last_paragraph_break(chars: &[char], start: usize, end: usize) -> Option<usize> {
    let mut idx = end;
    while idx > start + 1 {
        if chars[idx - 1] == '\n' && chars[idx - 2] == '\n' {
            return Some(idx);
        }
        idx -= 1;
    }
    None
}

fn find_last_whitespace(chars: &[char], start: usize, end: usize) -> Option<usize> {
    let mut idx = end;
    while idx > start {
        if chars[idx - 1].is_whitespace() {
            return Some(idx);
        }
        idx -= 1;
    }
    None
}

fn page_number_at(chars: &[char], index: usize) -> u32 {
    let capped = usize::min(index, chars.len());
    let page_breaks = chars[..capped].iter().filter(|ch| **ch == '\u{000C}').count();
    (page_breaks as u32) + 1
}
