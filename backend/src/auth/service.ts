import type { RuntimeEnv } from "../security/env.js";
import { createId } from "../utils/ids.js";
import { AppError } from "../utils/http.js";
import { hashForAudit, sha256Hex } from "../utils/signing.js";
import { exchangeGoogleAuthorizationCode, fetchGoogleUserProfile, type FetchLike } from "./google.js";
import {
  issueGoogleStateToken,
  issueRossSession,
  refreshRossSession,
  verifyGoogleStateToken,
  type RossSession
} from "./tokens.js";

export interface StartOtpInput {
  phoneNumber: string;
  channel: "sms" | "whatsapp";
}

export interface VerifyOtpInput {
  phoneNumber: string;
  verificationId: string;
  otpCode: string;
}

export interface StartGoogleAuthInput {
  redirectTarget?: string | undefined;
  loginHint?: string | undefined;
}

export interface CompleteGoogleAuthInput {
  code: string;
  state: string;
}

export interface RefreshSessionInput {
  refreshToken: string;
}

export interface GoogleAuthCallbackResult {
  redirectUrl: string;
  session: RossSession;
}

function maskPhoneNumber(phoneNumber: string): string {
  const tail = phoneNumber.slice(-2);
  return `***${tail}`;
}

function ensureGoogleOauthConfigured(env: RuntimeEnv): {
  clientId: string;
  clientSecret: string;
} {
  if (!env.googleOauthClientId || !env.googleOauthClientSecret) {
    throw new AppError(
      503,
      "google_oauth_unavailable",
      "Google sign-in is not configured on this backend."
    );
  }

  return {
    clientId: env.googleOauthClientId,
    clientSecret: env.googleOauthClientSecret
  };
}

function isLoopbackHost(hostname: string): boolean {
  return ["127.0.0.1", "10.0.2.2", "::1", "localhost"].includes(hostname.toLowerCase());
}

function resolveRedirectTarget(candidate: string | undefined, fallback: string): string {
  const rawValue = candidate?.trim() || fallback.trim();

  let parsed: URL;

  try {
    parsed = new URL(rawValue);
  } catch {
    throw new AppError(400, "invalid_redirect_target", "Redirect target is invalid.");
  }

  if (parsed.username || parsed.password) {
    throw new AppError(400, "invalid_redirect_target", "Redirect target is invalid.");
  }

  if (["http:", "https:"].includes(parsed.protocol) && !isLoopbackHost(parsed.hostname)) {
    throw new AppError(400, "invalid_redirect_target", "Redirect target must stay local for development.");
  }

  return parsed.toString();
}

function appendSessionToRedirectTarget(
  redirectTarget: string,
  session: RossSession
): string {
  const redirectUrl = new URL(redirectTarget);
  redirectUrl.searchParams.set("status", "success");
  redirectUrl.searchParams.set("access_token", session.accessToken);
  redirectUrl.searchParams.set("refresh_token", session.refreshToken);
  redirectUrl.searchParams.set("account_token", session.accountToken);
  redirectUrl.searchParams.set("expires_at", session.expiresAt);
  redirectUrl.searchParams.set("subject", session.subject);

  if (session.profile?.email) {
    redirectUrl.searchParams.set("email", session.profile.email);
  }

  if (session.profile?.displayName) {
    redirectUrl.searchParams.set("display_name", session.profile.displayName);
    redirectUrl.searchParams.set("name", session.profile.displayName);
  }

  return redirectUrl.toString();
}

function appendErrorToRedirectTarget(
  redirectTarget: string,
  error: string,
  errorDescription?: string
): string {
  const redirectUrl = new URL(redirectTarget);
  redirectUrl.searchParams.set("status", "error");
  redirectUrl.searchParams.set("error", error);

  if (errorDescription) {
    redirectUrl.searchParams.set("error_description", errorDescription);
  }

  return redirectUrl.toString();
}

function buildGoogleAuthorizeUrl(input: {
  clientId: string;
  redirectUri: string;
  stateToken: string;
  loginHint?: string | undefined;
}): string {
  const authorizeUrl = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  authorizeUrl.searchParams.set("client_id", input.clientId);
  authorizeUrl.searchParams.set("redirect_uri", input.redirectUri);
  authorizeUrl.searchParams.set("response_type", "code");
  authorizeUrl.searchParams.set("scope", "openid email profile");
  authorizeUrl.searchParams.set("access_type", "offline");
  authorizeUrl.searchParams.set("include_granted_scopes", "true");
  authorizeUrl.searchParams.set("state", input.stateToken);
  authorizeUrl.searchParams.set("prompt", "consent");

  if (input.loginHint) {
    authorizeUrl.searchParams.set("login_hint", input.loginHint);
  }

  return authorizeUrl.toString();
}

function googleSubject(profileSub: string): string {
  return `google_${sha256Hex(`google:${profileSub}`).slice(0, 24)}`;
}

function googleAccountSeed(profileSub: string): string {
  return `google:${profileSub}`;
}

function otpAccountSeed(phoneNumber: string, verificationId: string): string {
  return `otp:${phoneNumber}:${verificationId}`;
}

export class AuthService {
  constructor(
    private readonly env: RuntimeEnv,
    private readonly fetchImpl: FetchLike = globalThis.fetch.bind(globalThis)
  ) {}

  startOtp(input: StartOtpInput) {
    return {
      verificationId: createId("otp"),
      channel: input.channel,
      expiresInSeconds: 300,
      resendAfterSeconds: 30,
      deliveryHint: maskPhoneNumber(input.phoneNumber),
      developmentOtpHint: this.env.isProduction ? undefined : this.env.otpStubCode
    };
  }

  verifyOtp(input: VerifyOtpInput): RossSession {
    if (input.otpCode !== this.env.otpStubCode) {
      throw new AppError(401, "invalid_otp_code", "OTP verification failed.");
    }

    const subjectHash = hashForAudit(`${input.phoneNumber}:${input.verificationId}`);

    return issueRossSession(
      {
        subject: `advocate_${subjectHash}`,
        accountSeed: otpAccountSeed(input.phoneNumber, input.verificationId)
      },
      {
        accessSecret: this.env.authAccessSigningSecret,
        refreshSecret: this.env.authRefreshSigningSecret
      }
    );
  }

  startGoogleAuth(input: StartGoogleAuthInput): { authorizationUrl: string; redirectTarget: string } {
    const { clientId } = ensureGoogleOauthConfigured(this.env);
    const redirectTarget = resolveRedirectTarget(input.redirectTarget, this.env.authMobileRedirect);
    const callbackUrl = new URL("/auth/google/callback", this.env.publicBaseUrl).toString();
    const stateToken = issueGoogleStateToken(
      {
        redirectTarget
      },
      this.env.authAccessSigningSecret
    );

    return {
      authorizationUrl: buildGoogleAuthorizeUrl({
        clientId,
        redirectUri: callbackUrl,
        stateToken,
        loginHint: input.loginHint
      }),
      redirectTarget
    };
  }

  async completeGoogleAuth(input: CompleteGoogleAuthInput): Promise<GoogleAuthCallbackResult> {
    if (!input.code.trim()) {
      throw new AppError(400, "missing_google_code", "Google sign-in did not return an authorization code.");
    }

    const { clientId, clientSecret } = ensureGoogleOauthConfigured(this.env);
    const state = verifyGoogleStateToken(input.state, this.env.authAccessSigningSecret);
    const callbackUrl = new URL("/auth/google/callback", this.env.publicBaseUrl).toString();
    const tokenResponse = await exchangeGoogleAuthorizationCode(
      {
        code: input.code,
        clientId,
        clientSecret,
        redirectUri: callbackUrl
      },
      this.fetchImpl
    );

    if (!tokenResponse.access_token) {
      throw new AppError(502, "google_oauth_exchange_failed", "Google sign-in could not be completed.");
    }

    const profile = await fetchGoogleUserProfile(tokenResponse.access_token, this.fetchImpl);

    if (!profile.email || !profile.sub) {
      throw new AppError(502, "google_profile_invalid", "Google profile is missing required fields.");
    }

    const session = issueRossSession(
      {
        subject: googleSubject(profile.sub),
        accountSeed: googleAccountSeed(profile.sub),
        profile: {
          email: profile.email,
          displayName: profile.name,
          emailVerified: profile.email_verified,
          pictureUrl: profile.picture
        }
      },
      {
        accessSecret: this.env.authAccessSigningSecret,
        refreshSecret: this.env.authRefreshSigningSecret
      }
    );

    return {
      redirectUrl: appendSessionToRedirectTarget(state.redirectTarget, session),
      session
    };
  }

  buildGoogleErrorRedirect(input: {
    state?: string | undefined;
    error: string;
    errorDescription?: string | undefined;
  }): string {
    const fallbackRedirect = resolveRedirectTarget(undefined, this.env.authMobileRedirect);

    if (!input.state) {
      return appendErrorToRedirectTarget(fallbackRedirect, input.error, input.errorDescription);
    }

    try {
      const state = verifyGoogleStateToken(input.state, this.env.authAccessSigningSecret);
      return appendErrorToRedirectTarget(state.redirectTarget, input.error, input.errorDescription);
    } catch {
      return appendErrorToRedirectTarget(fallbackRedirect, input.error, input.errorDescription);
    }
  }

  refreshSession(input: RefreshSessionInput): RossSession {
    return refreshRossSession(input.refreshToken, {
      accessSecret: this.env.authAccessSigningSecret,
      refreshSecret: this.env.authRefreshSigningSecret
    });
  }
}
