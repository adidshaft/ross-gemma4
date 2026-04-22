import { createHmac, timingSafeEqual } from "node:crypto";

import { createId } from "../utils/ids.js";
import { AppError } from "../utils/http.js";
import { canonicalize, sha256Hex } from "../utils/signing.js";

const accessTokenPrefix = "acct_";
const refreshTokenPrefix = "rfr_";
const stateTokenPrefix = "stt_";

const accessTokenTtlMinutes = 60;
const refreshTokenTtlDays = 30;
const stateTokenTtlMinutes = 10;

type AccountBoundary = "no_case_data";

export interface RossSessionProfile {
  email?: string | undefined;
  displayName?: string | undefined;
  emailVerified?: boolean | undefined;
  pictureUrl?: string | undefined;
}

interface BaseClaims {
  sessionId: string;
  subject: string;
  accountId: string;
  accountBoundary: AccountBoundary;
  issuedAt: string;
  expiresAt: string;
  profile?: RossSessionProfile | undefined;
}

export interface RossAccessTokenClaims extends BaseClaims {
  kind: "ross_access";
}

export interface RossRefreshTokenClaims extends BaseClaims {
  kind: "ross_refresh";
}

export interface GoogleStateClaims {
  kind: "google_oauth_state";
  nonce: string;
  redirectTarget: string;
  issuedAt: string;
  expiresAt: string;
}

export interface RossSession {
  accountToken: string;
  accessToken: string;
  refreshToken: string;
  tokenType: "Bearer";
  subject: string;
  expiresAt: string;
  accountBoundary: AccountBoundary;
  profile?: RossSessionProfile | undefined;
}

export interface IssueRossSessionInput {
  subject: string;
  accountSeed: string;
  accountId?: string | undefined;
  profile?: RossSessionProfile | undefined;
}

function base64UrlEncode(value: string): string {
  return Buffer.from(value, "utf8").toString("base64url");
}

function base64UrlDecode(value: string): string {
  return Buffer.from(value, "base64url").toString("utf8");
}

function signCanonicalPayload(payload: unknown, secret: string): string {
  return createHmac("sha256", secret).update(canonicalize(payload)).digest("base64url");
}

function issueSignedToken<T extends { issuedAt: string; expiresAt: string }>(
  prefix: string,
  payload: T,
  secret: string
): string {
  const encodedPayload = base64UrlEncode(canonicalize(payload));
  const signature = signCanonicalPayload(payload, secret);
  return `${prefix}${encodedPayload}.${signature}`;
}

function parseSignedToken<T>(token: string, prefix: string, secret: string): T {
  if (!token.startsWith(prefix)) {
    throw new AppError(401, "invalid_auth_token", "Authentication token is invalid.");
  }

  const rawValue = token.slice(prefix.length);
  const [encodedPayload, providedSignature] = rawValue.split(".");

  if (!encodedPayload || !providedSignature) {
    throw new AppError(401, "invalid_auth_token", "Authentication token is invalid.");
  }

  let payload: T;

  try {
    payload = JSON.parse(base64UrlDecode(encodedPayload)) as T;
  } catch {
    throw new AppError(401, "invalid_auth_token", "Authentication token is invalid.");
  }

  const expectedSignature = signCanonicalPayload(payload, secret);

  if (expectedSignature.length !== providedSignature.length) {
    throw new AppError(401, "invalid_auth_token", "Authentication token is invalid.");
  }

  const isSignatureValid = timingSafeEqual(
    Buffer.from(expectedSignature),
    Buffer.from(providedSignature)
  );

  if (!isSignatureValid) {
    throw new AppError(401, "invalid_auth_token", "Authentication token is invalid.");
  }

  const expiresAt = extractExpiresAt(payload);

  if (Date.parse(expiresAt) <= Date.now()) {
    throw new AppError(401, "expired_auth_token", "Authentication token has expired.");
  }

  return payload;
}

function extractExpiresAt(payload: unknown): string {
  if (!payload || typeof payload !== "object" || typeof (payload as { expiresAt?: unknown }).expiresAt !== "string") {
    throw new AppError(401, "invalid_auth_token", "Authentication token is invalid.");
  }

  return (payload as { expiresAt: string }).expiresAt;
}

function issuedAtNow(): string {
  return new Date().toISOString();
}

function addDuration(date: Date, milliseconds: number): string {
  return new Date(date.getTime() + milliseconds).toISOString();
}

function buildAccountId(accountSeed: string): string {
  return `acct_google_${sha256Hex(accountSeed).slice(0, 24)}`;
}

function sessionClaimsFromInput(input: IssueRossSessionInput): {
  accessClaims: RossAccessTokenClaims;
  refreshClaims: RossRefreshTokenClaims;
} {
  const sessionId = createId("session");
  const now = new Date();
  const issuedAt = now.toISOString();
  const accountId = input.accountId ?? buildAccountId(input.accountSeed);
  const baseClaims: BaseClaims = {
    sessionId,
    subject: input.subject,
    accountId,
    accountBoundary: "no_case_data",
    issuedAt,
    expiresAt: addDuration(now, accessTokenTtlMinutes * 60_000),
    profile: input.profile
  };

  return {
    accessClaims: {
      ...baseClaims,
      kind: "ross_access"
    },
    refreshClaims: {
      ...baseClaims,
      kind: "ross_refresh",
      expiresAt: addDuration(now, refreshTokenTtlDays * 24 * 60 * 60_000)
    }
  };
}

export function issueRossSession(
  input: IssueRossSessionInput,
  secrets: {
    accessSecret: string;
    refreshSecret: string;
  }
): RossSession {
  const { accessClaims, refreshClaims } = sessionClaimsFromInput(input);
  const accessToken = issueSignedToken(accessTokenPrefix, accessClaims, secrets.accessSecret);
  const refreshToken = issueSignedToken(refreshTokenPrefix, refreshClaims, secrets.refreshSecret);

  return {
    accountToken: accessToken,
    accessToken,
    refreshToken,
    tokenType: "Bearer",
    subject: accessClaims.subject,
    expiresAt: accessClaims.expiresAt,
    accountBoundary: accessClaims.accountBoundary,
    profile: accessClaims.profile
  };
}

export function refreshRossSession(
  refreshToken: string,
  secrets: {
    accessSecret: string;
    refreshSecret: string;
  }
): RossSession {
  // The backend stays stateless for local/mobile auth, so refresh rotation issues a
  // fresh pair without maintaining a server-side revocation list.
  const claims = parseSignedToken<RossRefreshTokenClaims>(
    refreshToken,
    refreshTokenPrefix,
    secrets.refreshSecret
  );

  if (claims.kind !== "ross_refresh") {
    throw new AppError(401, "invalid_refresh_token", "Refresh token is invalid.");
  }

  return issueRossSession(
    {
      subject: claims.subject,
      accountSeed: claims.accountId,
      accountId: claims.accountId,
      profile: claims.profile
    },
    secrets
  );
}

export function issueGoogleStateToken(
  input: { redirectTarget: string },
  accessSecret: string
): string {
  const issuedAt = issuedAtNow();
  const claims: GoogleStateClaims = {
    kind: "google_oauth_state",
    nonce: createId("oauth"),
    redirectTarget: input.redirectTarget,
    issuedAt,
    expiresAt: addDuration(new Date(issuedAt), stateTokenTtlMinutes * 60_000)
  };

  return issueSignedToken(stateTokenPrefix, claims, accessSecret);
}

export function verifyGoogleStateToken(stateToken: string, accessSecret: string): GoogleStateClaims {
  let claims: GoogleStateClaims;

  try {
    claims = parseSignedToken<GoogleStateClaims>(stateToken, stateTokenPrefix, accessSecret);
  } catch {
    throw new AppError(401, "invalid_auth_state", "Authentication state is invalid.");
  }

  if (claims.kind !== "google_oauth_state") {
    throw new AppError(401, "invalid_auth_state", "Authentication state is invalid.");
  }

  return claims;
}
