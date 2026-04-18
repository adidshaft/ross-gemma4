use crate::crypto::{sign_message_base64, verify_message, CryptoError, LocalSigningKey};
use crate::models::{
    CapabilityTierId, EntitlementClaims, EntitlementToken, FeatureName, VerifiedEntitlement,
};
use ed25519_dalek::PublicKey;
use std::collections::HashMap;
use std::error::Error;
use std::fmt::{Display, Formatter};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EntitlementError {
    UnknownKey(String),
    Crypto(CryptoError),
    Expired,
    NotYetValid,
}

impl Display for EntitlementError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UnknownKey(key_id) => write!(f, "unknown entitlement signing key: {key_id}"),
            Self::Crypto(error) => write!(f, "{error}"),
            Self::Expired => write!(f, "entitlement has expired"),
            Self::NotYetValid => write!(f, "entitlement is not valid yet"),
        }
    }
}

impl Error for EntitlementError {}

#[derive(Clone, Debug, Default)]
pub struct EntitlementVerifier {
    keys: HashMap<String, PublicKey>,
}

impl EntitlementVerifier {
    pub fn new() -> Self {
        Self {
            keys: HashMap::new(),
        }
    }

    pub fn insert_key(&mut self, key_id: impl Into<String>, key: PublicKey) {
        self.keys.insert(key_id.into(), key);
    }

    pub fn verify(
        &self,
        token: &EntitlementToken,
        now_ms: u64,
    ) -> Result<VerifiedEntitlement, EntitlementError> {
        let verifying_key = self
            .keys
            .get(&token.key_id)
            .ok_or_else(|| EntitlementError::UnknownKey(token.key_id.clone()))?;

        verify_message(
            verifying_key,
            token.claims.signing_payload().as_bytes(),
            &token.signature_base64,
        )
        .map_err(EntitlementError::Crypto)?;

        if token.claims.issued_at_ms > now_ms {
            return Err(EntitlementError::NotYetValid);
        }
        if token.claims.expires_at_ms < now_ms {
            return Err(EntitlementError::Expired);
        }

        Ok(VerifiedEntitlement {
            claims: token.claims.clone(),
            key_id: token.key_id.clone(),
            verified_at_ms: now_ms,
        })
    }
}

pub fn sign_entitlement(
    claims: EntitlementClaims,
    key_id: impl Into<String>,
    signing_key: &LocalSigningKey,
) -> EntitlementToken {
    EntitlementToken {
        signature_base64: sign_message_base64(signing_key, claims.signing_payload().as_bytes()),
        claims,
        key_id: key_id.into(),
    }
}

pub fn highest_allowed_tier(entitlement: &VerifiedEntitlement) -> Option<CapabilityTierId> {
    entitlement.claims.highest_allowed_tier()
}

pub fn allows_tier(entitlement: &VerifiedEntitlement, requested_tier: CapabilityTierId) -> bool {
    entitlement
        .claims
        .highest_allowed_tier()
        .map(|tier| tier >= requested_tier)
        .unwrap_or(false)
}

pub fn allows_feature(entitlement: &VerifiedEntitlement, feature: FeatureName) -> bool {
    entitlement
        .claims
        .enabled_features
        .iter()
        .any(|candidate| candidate == feature.as_str())
}

pub fn allows_pack(entitlement: &VerifiedEntitlement, pack_id: &str) -> bool {
    entitlement
        .claims
        .allowed_pack_ids
        .iter()
        .any(|candidate| candidate == pack_id)
}
