use base64::{engine::general_purpose::STANDARD, Engine as _};
use ed25519_dalek::{Keypair, PublicKey, SecretKey, Signature, Signer, Verifier};
use sha2::{Digest, Sha256};
use std::error::Error;
use std::fmt::{Display, Formatter};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CryptoError {
    InvalidPublicKey,
    InvalidSignatureEncoding,
    SignatureVerificationFailed,
}

impl Display for CryptoError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidPublicKey => write!(f, "invalid Ed25519 public key"),
            Self::InvalidSignatureEncoding => write!(f, "invalid Ed25519 signature encoding"),
            Self::SignatureVerificationFailed => write!(f, "Ed25519 signature verification failed"),
        }
    }
}

impl Error for CryptoError {}

pub fn sha256_hex(data: impl AsRef<[u8]>) -> String {
    let digest = Sha256::digest(data.as_ref());
    hex::encode(digest)
}

pub struct LocalSigningKey {
    keypair: Keypair,
}

impl LocalSigningKey {
    pub fn verifying_key(&self) -> PublicKey {
        self.keypair.public
    }

    pub fn sign(&self, message: &[u8]) -> Signature {
        self.keypair.sign(message)
    }
}

pub fn signing_key_from_seed(seed: [u8; 32]) -> LocalSigningKey {
    let secret = SecretKey::from_bytes(&seed).expect("32-byte Ed25519 seed");
    let public = PublicKey::from(&secret);
    LocalSigningKey {
        keypair: Keypair { secret, public },
    }
}

pub fn verifying_key_from_base64(encoded: &str) -> Result<PublicKey, CryptoError> {
    let bytes = STANDARD
        .decode(encoded)
        .map_err(|_| CryptoError::InvalidPublicKey)?;
    let key_bytes: [u8; 32] = bytes
        .try_into()
        .map_err(|_| CryptoError::InvalidPublicKey)?;
    PublicKey::from_bytes(&key_bytes).map_err(|_| CryptoError::InvalidPublicKey)
}

pub fn verifying_key_to_base64(key: &PublicKey) -> String {
    STANDARD.encode(key.as_bytes())
}

pub fn sign_message_base64(signing_key: &LocalSigningKey, message: &[u8]) -> String {
    STANDARD.encode(signing_key.sign(message).to_bytes())
}

pub fn verify_message(
    public_key: &PublicKey,
    message: &[u8],
    signature_base64: &str,
) -> Result<(), CryptoError> {
    let bytes = STANDARD
        .decode(signature_base64)
        .map_err(|_| CryptoError::InvalidSignatureEncoding)?;
    let signature_bytes: [u8; 64] = bytes
        .try_into()
        .map_err(|_| CryptoError::InvalidSignatureEncoding)?;
    let signature =
        Signature::from_bytes(&signature_bytes).map_err(|_| CryptoError::InvalidSignatureEncoding)?;
    public_key
        .verify(message, &signature)
        .map_err(|_| CryptoError::SignatureVerificationFailed)
}
