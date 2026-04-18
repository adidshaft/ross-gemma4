use crate::extraction::{
    local_timestamp, AdvocateReviewQueue, CaseMemoryUpdate, CaseMemoryUpdateSource, DocumentExtractionInput,
    ExtractionFinding, ExtractionFindingKind, ExtractionFindingSeverity, ExtractionOutcome,
    ExtractionRun, ExtractionRunStatus, LegalDocumentClassification, PageText,
};
use crate::language::{
    detect_document_language_profile, DocumentLanguage, DocumentLanguageProfile, LanguagePageSample,
};
use crate::legal_fields::{
    DeterministicLegalDocumentClassifier, DeterministicLegalFieldExtractor,
    DeterministicLegalFieldVerifier, VerificationResult,
};

pub trait TextAcquisitionProvider {
    fn acquire(&self, input: &DocumentExtractionInput) -> Vec<PageText>;
}

pub trait LanguageProfileProvider {
    fn detect(&self, input: &DocumentExtractionInput, pages: &[PageText]) -> DocumentLanguageProfile;
}

pub trait LegalDocumentClassifier {
    fn classify(
        &self,
        input: &DocumentExtractionInput,
        language_profile: &DocumentLanguageProfile,
    ) -> LegalDocumentClassification;
}

pub trait LegalFieldExtractor {
    fn extract(
        &self,
        input: &DocumentExtractionInput,
        classification: &LegalDocumentClassification,
        language_profile: &DocumentLanguageProfile,
    ) -> Vec<crate::extraction::ExtractedLegalField>;
}

pub trait LegalFieldVerifier {
    fn verify(
        &self,
        input: &DocumentExtractionInput,
        fields: &[crate::extraction::ExtractedLegalField],
    ) -> VerificationResult;
}

pub trait CaseMemoryBuilder {
    fn build(
        &self,
        input: &DocumentExtractionInput,
        classification: &LegalDocumentClassification,
        fields: &[crate::extraction::ExtractedLegalField],
    ) -> Vec<CaseMemoryUpdate>;
}

pub trait ReviewQueueBuilder {
    fn build(
        &self,
        input: &DocumentExtractionInput,
        fields: &[crate::extraction::ExtractedLegalField],
        findings: &[ExtractionFinding],
    ) -> AdvocateReviewQueue;
}

pub struct PassthroughTextAcquisitionProvider;

impl TextAcquisitionProvider for PassthroughTextAcquisitionProvider {
    fn acquire(&self, input: &DocumentExtractionInput) -> Vec<PageText> {
        input.pages.clone()
    }
}

pub struct HeuristicLanguageProfileProvider;

impl LanguageProfileProvider for HeuristicLanguageProfileProvider {
    fn detect(&self, input: &DocumentExtractionInput, pages: &[PageText]) -> DocumentLanguageProfile {
        let samples = pages
            .iter()
            .map(|page| LanguagePageSample {
                page_number: page.page_number,
                text: page.text.clone(),
            })
            .collect::<Vec<_>>();
        detect_document_language_profile(input.document_id.clone(), &samples)
    }
}

impl LegalDocumentClassifier for DeterministicLegalDocumentClassifier {
    fn classify(
        &self,
        input: &DocumentExtractionInput,
        language_profile: &DocumentLanguageProfile,
    ) -> LegalDocumentClassification {
        Self::classify(self, input, language_profile)
    }
}

impl LegalFieldExtractor for DeterministicLegalFieldExtractor {
    fn extract(
        &self,
        input: &DocumentExtractionInput,
        classification: &LegalDocumentClassification,
        language_profile: &DocumentLanguageProfile,
    ) -> Vec<crate::extraction::ExtractedLegalField> {
        Self::extract(self, input, classification, language_profile)
    }
}

impl LegalFieldVerifier for DeterministicLegalFieldVerifier {
    fn verify(
        &self,
        input: &DocumentExtractionInput,
        fields: &[crate::extraction::ExtractedLegalField],
    ) -> VerificationResult {
        Self::verify(self, input, fields)
    }
}

pub struct DeterministicCaseMemoryBuilder;

impl CaseMemoryBuilder for DeterministicCaseMemoryBuilder {
    fn build(
        &self,
        input: &DocumentExtractionInput,
        classification: &LegalDocumentClassification,
        fields: &[crate::extraction::ExtractedLegalField],
    ) -> Vec<CaseMemoryUpdate> {
        let mut updates = Vec::new();

        let parties = join_values(fields, crate::extraction::LegalFieldType::PartyName);
        let dates = join_values(fields, crate::extraction::LegalFieldType::Date);
        let next_dates = join_values(fields, crate::extraction::LegalFieldType::NextDate);
        let issues = join_values(fields, crate::extraction::LegalFieldType::Issue);
        let directions = join_values(fields, crate::extraction::LegalFieldType::OrderDirection);
        let reliefs = join_values(fields, crate::extraction::LegalFieldType::Relief);

        updates.push(CaseMemoryUpdate {
            id: format!("memory-meta-{}", input.document_id),
            case_id: input.case_id.clone(),
            source: CaseMemoryUpdateSource::ExtractionRun,
            summary: format!(
                "Document classified as {:?}. Parties: {}. Important dates: {}.",
                classification.r#type,
                default_or_not_found(parties),
                default_or_not_found(dates),
            ),
            affected_documents: vec![input.document_id.clone()],
            created_at: local_timestamp(),
        });

        if !next_dates.is_empty() || !directions.is_empty() {
            updates.push(CaseMemoryUpdate {
                id: format!("memory-order-{}", input.document_id),
                case_id: input.case_id.clone(),
                source: CaseMemoryUpdateSource::ExtractionRun,
                summary: format!(
                    "Order and compliance candidate. Next date: {}. Directions: {}.",
                    default_or_not_found(next_dates),
                    default_or_not_found(directions),
                ),
                affected_documents: vec![input.document_id.clone()],
                created_at: local_timestamp(),
            });
        }

        if !issues.is_empty() || !reliefs.is_empty() {
            updates.push(CaseMemoryUpdate {
                id: format!("memory-issues-{}", input.document_id),
                case_id: input.case_id.clone(),
                source: CaseMemoryUpdateSource::ExtractionRun,
                summary: format!(
                    "Issue and relief candidate. Issues: {}. Reliefs/prayers: {}.",
                    default_or_not_found(issues),
                    default_or_not_found(reliefs),
                ),
                affected_documents: vec![input.document_id.clone()],
                created_at: local_timestamp(),
            });
        }

        updates
    }
}

pub struct DeterministicReviewQueueBuilder;

impl ReviewQueueBuilder for DeterministicReviewQueueBuilder {
    fn build(
        &self,
        input: &DocumentExtractionInput,
        fields: &[crate::extraction::ExtractedLegalField],
        findings: &[ExtractionFinding],
    ) -> AdvocateReviewQueue {
        let review_field_ids = fields
            .iter()
            .filter(|field| field.needs_review)
            .map(|field| field.id.clone())
            .collect::<Vec<_>>();
        let review_finding_ids = findings
            .iter()
            .filter(|finding| !finding.resolved)
            .map(|finding| finding.id.clone())
            .collect::<Vec<_>>();

        AdvocateReviewQueue {
            case_id: input.case_id.clone(),
            document_id: input.document_id.clone(),
            field_ids: review_field_ids.clone(),
            finding_ids: review_finding_ids.clone(),
            summary: if review_field_ids.is_empty() && review_finding_ids.is_empty() {
                "Ross found key details and did not detect unresolved review blockers.".to_string()
            } else {
                "Ross found key details. Please review the uncertain ones.".to_string()
            },
        }
    }
}

pub struct LocalExtractionOrchestrator<
    TA = PassthroughTextAcquisitionProvider,
    LP = HeuristicLanguageProfileProvider,
    DC = DeterministicLegalDocumentClassifier,
    FE = DeterministicLegalFieldExtractor,
    FV = DeterministicLegalFieldVerifier,
    CM = DeterministicCaseMemoryBuilder,
    RQ = DeterministicReviewQueueBuilder,
> {
    pub text_acquisition: TA,
    pub language_profiles: LP,
    pub classifier: DC,
    pub extractor: FE,
    pub verifier: FV,
    pub case_memory: CM,
    pub review_queue: RQ,
}

impl Default for LocalExtractionOrchestrator {
    fn default() -> Self {
        Self {
            text_acquisition: PassthroughTextAcquisitionProvider,
            language_profiles: HeuristicLanguageProfileProvider,
            classifier: DeterministicLegalDocumentClassifier,
            extractor: DeterministicLegalFieldExtractor,
            verifier: DeterministicLegalFieldVerifier,
            case_memory: DeterministicCaseMemoryBuilder,
            review_queue: DeterministicReviewQueueBuilder,
        }
    }
}

pub struct OrchestratedExtraction {
    pub language_profile: DocumentLanguageProfile,
    pub classification: LegalDocumentClassification,
    pub outcome: ExtractionOutcome,
}

impl<TA, LP, DC, FE, FV, CM, RQ> LocalExtractionOrchestrator<TA, LP, DC, FE, FV, CM, RQ>
where
    TA: TextAcquisitionProvider,
    LP: LanguageProfileProvider,
    DC: LegalDocumentClassifier,
    FE: LegalFieldExtractor,
    FV: LegalFieldVerifier,
    CM: CaseMemoryBuilder,
    RQ: ReviewQueueBuilder,
{
    pub fn run(&self, input: &DocumentExtractionInput) -> OrchestratedExtraction {
        let pages = self.text_acquisition.acquire(input);
        let language_profile = self.language_profiles.detect(input, &pages);
        let classification = self.classifier.classify(input, &language_profile);
        let extracted_fields = self.extractor.extract(input, &classification, &language_profile);
        let VerificationResult {
            fields,
            mut findings,
        } = self.verifier.verify(input, &extracted_fields);
        findings.extend(base_findings(input, &language_profile, &pages));
        let case_memory_updates = self.case_memory.build(input, &classification, &fields);
        let review_queue = self.review_queue.build(input, &fields, &findings);
        let warnings = findings.iter().map(|finding| finding.message.clone()).collect::<Vec<_>>();
        let status = if fields.is_empty() {
            ExtractionRunStatus::Failed
        } else if fields.iter().any(|field| field.needs_review) || findings.iter().any(|f| !f.resolved) {
            ExtractionRunStatus::NeedsReview
        } else {
            ExtractionRunStatus::Complete
        };

        let run = ExtractionRun {
            id: format!("run-{}", input.document_id),
            case_id: input.case_id.clone(),
            document_id: input.document_id.clone(),
            mode: input.mode,
            status,
            started_at: Some(local_timestamp()),
            completed_at: Some(local_timestamp()),
            pages_processed: pages.len() as u32,
            total_pages: input.pages.len() as u32,
            fields_extracted: fields.len() as u32,
            fields_needing_review: fields.iter().filter(|field| field.needs_review).count() as u32,
            warnings,
            error_message: if fields.is_empty() {
                Some("Ross could not find supported legal fields in this document yet.".to_string())
            } else {
                None
            },
        };

        OrchestratedExtraction {
            language_profile,
            classification,
            outcome: ExtractionOutcome {
                run,
                fields,
                findings,
                case_memory_updates,
                review_queue,
            },
        }
    }
}

fn base_findings(
    input: &DocumentExtractionInput,
    language_profile: &DocumentLanguageProfile,
    pages: &[PageText],
) -> Vec<ExtractionFinding> {
    let mut findings = Vec::new();

    if language_profile.primary_language == DocumentLanguage::Mixed || language_profile.confidence < 0.62 {
        findings.push(ExtractionFinding {
            id: format!("finding-language-{}", input.document_id),
            case_id: input.case_id.clone(),
            document_id: input.document_id.clone(),
            kind: ExtractionFindingKind::LanguageUncertain,
            message: "Ross detected mixed or uncertain language/script content. Review bilingual fields carefully.".to_string(),
            source_refs: pages.iter().take(2).map(|page| page.source_ref.clone()).collect(),
            severity: ExtractionFindingSeverity::Warning,
            resolved: false,
        });
    }

    if let Some(page) = pages
        .iter()
        .find(|page| page.ocr_confidence.unwrap_or(page.source_ref.ocr_confidence.unwrap_or(0.8)) < 0.58)
    {
        findings.push(ExtractionFinding {
            id: format!("finding-ocr-{}", page.page_number),
            case_id: input.case_id.clone(),
            document_id: input.document_id.clone(),
            kind: ExtractionFindingKind::LowConfidenceOcr,
            message: "Ross detected a low-confidence scan on at least one page. Review uncertain fields before relying on them.".to_string(),
            source_refs: vec![page.source_ref.clone()],
            severity: ExtractionFindingSeverity::Warning,
            resolved: false,
        });
    }

    findings
}

fn join_values(fields: &[crate::extraction::ExtractedLegalField], target: crate::extraction::LegalFieldType) -> Vec<String> {
    fields
        .iter()
        .filter(|field| field.field_type == target)
        .map(|field| field.value.clone())
        .collect::<Vec<_>>()
}

fn default_or_not_found(values: Vec<String>) -> String {
    if values.is_empty() {
        "Not found".to_string()
    } else {
        values.join(" | ")
    }
}
