import { AppError } from "../utils/http.js";

export interface GoogleTokenExchangeResponse {
  access_token: string;
  token_type?: string | undefined;
  expires_in?: number | undefined;
  refresh_token?: string | undefined;
  scope?: string | undefined;
  id_token?: string | undefined;
}

export interface GoogleUserProfile {
  sub: string;
  email: string;
  email_verified?: boolean | undefined;
  name?: string | undefined;
  picture?: string | undefined;
}

export type FetchLike = typeof fetch;

function assertOkResponse(response: Response, code: string, message: string): void {
  if (!response.ok) {
    throw new AppError(502, code, message, {
      providerStatus: response.status
    });
  }
}

export async function exchangeGoogleAuthorizationCode(
  input: {
    code: string;
    clientId: string;
    clientSecret: string;
    redirectUri: string;
  },
  fetchImpl: FetchLike
): Promise<GoogleTokenExchangeResponse> {
  const response = await fetchImpl("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      accept: "application/json"
    },
    body: new URLSearchParams({
      code: input.code,
      client_id: input.clientId,
      client_secret: input.clientSecret,
      redirect_uri: input.redirectUri,
      grant_type: "authorization_code"
    })
  });

  assertOkResponse(response, "google_oauth_exchange_failed", "Google sign-in could not be completed.");
  return (await response.json()) as GoogleTokenExchangeResponse;
}

export async function fetchGoogleUserProfile(
  accessToken: string,
  fetchImpl: FetchLike
): Promise<GoogleUserProfile> {
  const response = await fetchImpl("https://openidconnect.googleapis.com/v1/userinfo", {
    method: "GET",
    headers: {
      authorization: `Bearer ${accessToken}`,
      accept: "application/json"
    }
  });

  assertOkResponse(response, "google_profile_fetch_failed", "Google profile could not be loaded.");
  return (await response.json()) as GoogleUserProfile;
}
