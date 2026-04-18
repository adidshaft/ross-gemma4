use crate::crypto::sha256_hex;
use crate::models::{AuditEvent, AuditPurpose, PayloadClass, SanitizedPublicQuery};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone, Debug, Default)]
pub struct AuditLedger {
    entries: Vec<AuditEvent>,
}

impl AuditLedger {
    pub fn new() -> Self {
        Self { entries: Vec::new() }
    }

    pub fn entries(&self) -> &[AuditEvent] {
        &self.entries
    }

    pub fn record(
        &mut self,
        purpose: AuditPurpose,
        payload_class: PayloadClass,
        endpoint_label: impl Into<String>,
        success: bool,
        detail: impl Into<String>,
    ) -> &AuditEvent {
        let next_id = self.entries.len() + 1;
        let event = AuditEvent {
            id: format!("audit-{next_id:06}"),
            timestamp_ms: now_ms(),
            purpose,
            payload_class,
            endpoint_label: endpoint_label.into(),
            success,
            detail: detail.into(),
        };
        self.entries.push(event);
        self.entries.last().expect("entry was pushed")
    }

    pub fn record_public_query(
        &mut self,
        query: &SanitizedPublicQuery,
        success: bool,
    ) -> &AuditEvent {
        self.record(
            AuditPurpose::PublicLawSearch,
            PayloadClass::SanitizedPublicQuery,
            "/public-law/search",
            success,
            format!(
                "preview_hash={};search_terms={};redactions={}",
                sha256_hex(query.preview.as_bytes()),
                query.search_terms.len(),
                query.removed_categories.len()
            ),
        )
    }

    pub fn record_entitlement_check(&mut self, key_id: &str, success: bool) -> &AuditEvent {
        self.record(
            AuditPurpose::EntitlementCheck,
            PayloadClass::AccountToken,
            "/entitlements/verify",
            success,
            format!("key_id={key_id}"),
        )
    }
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis() as u64)
        .unwrap_or(0)
}
