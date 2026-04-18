use private_digital_clerk_core::{ChunkingConfig, SourceKind, TextChunker};

#[test]
fn chunker_creates_overlapping_windows() {
    let text = "A".repeat(140) + &"B".repeat(140) + &"C".repeat(140);
    let chunker = TextChunker::new(ChunkingConfig {
        target_chars: 180,
        overlap_chars: 30,
        min_chunk_chars: 120,
        respect_paragraphs: false,
    });

    let chunks = chunker.chunk_document("doc-1", "Test Doc", &text, SourceKind::CaseFile);

    assert!(chunks.len() >= 2);
    assert_eq!(chunks[0].char_end - chunks[1].char_start, 30);
    assert_eq!(chunks[0].document_id, "doc-1");
}

#[test]
fn chunker_tracks_page_boundaries() {
    let text = format!("Page one text{}Page two text that is also long enough.", '\u{000C}');
    let chunks = TextChunker::default().chunk_document("doc-2", "Paged Doc", &text, SourceKind::CaseFile);

    assert!(!chunks.is_empty());
    assert_eq!(chunks[0].page_start, Some(1));
    assert!(chunks.iter().any(|chunk| chunk.page_end == Some(2)));
}
