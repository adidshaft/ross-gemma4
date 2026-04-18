use crate::chunking::TextChunker;
use crate::models::{
    AnswerEnvelope, DocumentChunk, RagQuery, RetrievalBundle, RetrievalMatch, SourceBackedAnswer,
    SourceKind,
};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

#[derive(Clone, Debug)]
struct VectorRecord {
    chunk: DocumentChunk,
    embedding: Vec<f32>,
}

#[derive(Clone, Debug)]
pub struct SimpleEmbedder {
    dimensions: usize,
}

impl SimpleEmbedder {
    pub fn new(dimensions: usize) -> Self {
        Self {
            dimensions: dimensions.max(8),
        }
    }

    pub fn embed(&self, text: &str) -> Vec<f32> {
        let mut vector = vec![0.0f32; self.dimensions];
        for token in tokenize(text) {
            let mut hasher = DefaultHasher::new();
            token.hash(&mut hasher);
            let index = (hasher.finish() as usize) % self.dimensions;
            vector[index] += 1.0 + (token.len() as f32 / 12.0);
        }
        normalize(vector)
    }
}

impl Default for SimpleEmbedder {
    fn default() -> Self {
        Self::new(64)
    }
}

#[derive(Clone, Debug)]
pub struct InMemoryVectorStore {
    embedder: SimpleEmbedder,
    records: Vec<VectorRecord>,
}

impl InMemoryVectorStore {
    pub fn new(dimensions: usize) -> Self {
        Self {
            embedder: SimpleEmbedder::new(dimensions),
            records: Vec::new(),
        }
    }

    pub fn len(&self) -> usize {
        self.records.len()
    }

    pub fn is_empty(&self) -> bool {
        self.records.is_empty()
    }

    pub fn add_chunk(&mut self, mut chunk: DocumentChunk) {
        let embedding = chunk
            .embedding
            .clone()
            .unwrap_or_else(|| self.embedder.embed(&chunk.text));
        chunk.embedding = Some(embedding.clone());
        self.records.push(VectorRecord { chunk, embedding });
    }

    pub fn add_chunks<I>(&mut self, chunks: I)
    where
        I: IntoIterator<Item = DocumentChunk>,
    {
        for chunk in chunks {
            self.add_chunk(chunk);
        }
    }

    pub fn add_document(
        &mut self,
        document_id: &str,
        title: &str,
        text: &str,
        source_kind: SourceKind,
    ) {
        let chunker = TextChunker::default();
        self.add_chunks(chunker.chunk_document(document_id, title, text, source_kind));
    }

    pub fn search(&self, query: &RagQuery) -> RetrievalBundle {
        let query_embedding = self.embedder.embed(&query.text);
        let query_terms = tokenize(&query.text);

        let mut matches = self
            .records
            .iter()
            .filter(|record| match &query.source_kind {
                Some(kind) => &record.chunk.source_kind == kind,
                None => true,
            })
            .filter_map(|record| {
                let keyword_hits = query_terms
                    .iter()
                    .filter(|term| record.chunk.text.to_lowercase().contains(term.as_str()))
                    .count();
                let semantic_score = dot(&query_embedding, &record.embedding);
                let blended_score = semantic_score + (keyword_hits as f32 * 0.07);

                (blended_score >= query.minimum_score).then(|| RetrievalMatch {
                    chunk: record.chunk.clone(),
                    score: blended_score,
                    keyword_hits,
                })
            })
            .collect::<Vec<_>>();

        matches.sort_by(|left, right| right.score.total_cmp(&left.score));
        matches.truncate(query.top_k);

        RetrievalBundle { matches }
    }
}

impl Default for InMemoryVectorStore {
    fn default() -> Self {
        Self::new(64)
    }
}

#[derive(Clone, Debug)]
pub struct RagEngine {
    store: InMemoryVectorStore,
}

impl RagEngine {
    pub fn new(store: InMemoryVectorStore) -> Self {
        Self { store }
    }

    pub fn store(&self) -> &InMemoryVectorStore {
        &self.store
    }

    pub fn retrieve(&self, query: &RagQuery) -> RetrievalBundle {
        self.store.search(query)
    }

    pub fn answer(&self, query: &RagQuery) -> AnswerEnvelope {
        let bundle = self.retrieve(query);
        if bundle.matches.is_empty() {
            return AnswerEnvelope::refusal(
                crate::models::RefusalKind::MissingSources,
                "No sufficiently relevant local sources were retrieved.",
                "Not found in the case file.",
                vec![
                    "Try a narrower question anchored to a document, page, date, or exhibit.".into(),
                    "Confirm the relevant document has been imported and chunked locally.".into(),
                ],
            );
        }

        let citations = bundle
            .matches
            .iter()
            .map(|item| item.chunk.to_citation(snippet(&item.chunk.text), Some(item.score)))
            .collect::<Vec<_>>();

        let mut answer = SourceBackedAnswer::new(
            bundle
                .matches
                .iter()
                .take(2)
                .map(|item| snippet(&item.chunk.text))
                .collect::<Vec<_>>()
                .join(" "),
            citations,
        );
        answer.confidence = if bundle.matches[0].score > 0.8 {
            crate::models::AnswerConfidence::High
        } else {
            crate::models::AnswerConfidence::Medium
        };

        AnswerEnvelope::Answer(answer)
    }
}

fn tokenize(text: &str) -> Vec<String> {
    text.split(|ch: char| !ch.is_alphanumeric())
        .filter(|token| token.len() >= 3)
        .map(|token| token.to_lowercase())
        .collect()
}

fn normalize(mut vector: Vec<f32>) -> Vec<f32> {
    let magnitude = vector.iter().map(|value| value * value).sum::<f32>().sqrt();
    if magnitude > 0.0 {
        for value in &mut vector {
            *value /= magnitude;
        }
    }
    vector
}

fn dot(left: &[f32], right: &[f32]) -> f32 {
    left.iter().zip(right.iter()).map(|(a, b)| a * b).sum()
}

fn snippet(text: &str) -> String {
    let trimmed = text.split_whitespace().collect::<Vec<_>>().join(" ");
    if trimmed.len() <= 180 {
        trimmed
    } else {
        format!("{}...", &trimmed[..180])
    }
}
