use ross_core::{AnswerEnvelope, InMemoryVectorStore, RagEngine, RagQuery, SourceKind};

#[test]
fn rag_returns_source_backed_answer() {
    let mut store = InMemoryVectorStore::default();
    store.add_document(
        "doc-1",
        "Chronology",
        "The injunction hearing was held on 4 April 2024 before the district court. The matter was adjourned to 18 April 2024 for replies.",
        SourceKind::CaseFile,
    );
    let engine = RagEngine::new(store);

    let response = engine.answer(&RagQuery::new("When was the injunction hearing held?"));

    match response {
        AnswerEnvelope::Answer(answer) => {
            assert!(!answer.citations.is_empty());
            assert!(answer.answer.contains("4 April 2024"));
        }
        AnswerEnvelope::Refusal(_) => panic!("expected source-backed answer"),
    }
}

#[test]
fn rag_refuses_when_nothing_relevant_is_found() {
    let mut store = InMemoryVectorStore::default();
    store.add_document(
        "doc-2",
        "Pleadings",
        "The plaintiff seeks permanent injunction and damages.",
        SourceKind::CaseFile,
    );
    let engine = RagEngine::new(store);

    let response = engine.answer(&RagQuery {
        text: "What is the email address of the respondent?".into(),
        top_k: 2,
        minimum_score: 0.75,
        source_kind: Some(SourceKind::CaseFile),
    });

    match response {
        AnswerEnvelope::Refusal(refusal) => {
            assert_eq!(refusal.reason, "No sufficiently relevant local sources were retrieved.");
        }
        AnswerEnvelope::Answer(_) => panic!("expected refusal"),
    }
}
