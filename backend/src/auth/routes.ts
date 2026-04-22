import type { FastifyInstance } from "fastify";
import { z } from "zod";

import type { AuditLogger } from "../audit/logger.js";
import type { RuntimeEnv } from "../security/env.js";
import { parseStrict } from "../security/privacy.js";
import { AppError } from "../utils/http.js";
import { hashForAudit } from "../utils/signing.js";
import {
  AuthService,
  type CompleteGoogleAuthInput,
  type RefreshSessionInput,
  type StartGoogleAuthInput
} from "./service.js";

interface RouteDeps {
  env: RuntimeEnv;
  auditLogger: AuditLogger;
}

const phoneNumberSchema = z
  .string()
  .trim()
  .regex(/^\+?[1-9]\d{7,14}$/, "Phone number must be in E.164-like format.");

const otpStartSchema = z
  .object({
    phoneNumber: phoneNumberSchema,
    channel: z.enum(["sms", "whatsapp"]).default("sms")
  })
  .strict();

const otpVerifySchema = z
  .object({
    phoneNumber: phoneNumberSchema,
    verificationId: z.string().trim().min(12),
    otpCode: z.string().trim().regex(/^\d{6}$/, "OTP code must be 6 digits.")
  })
  .strict();

const googleStartQuerySchema = z
  .object({
    redirectTarget: z.string().trim().min(1).max(512).optional(),
    redirect_uri: z.string().trim().min(1).max(512).optional(),
    platform: z.enum(["android", "ios"]).optional(),
    loginHint: z.string().trim().email().max(320).optional()
  })
  .strict()
  .transform((value) => ({
    redirectTarget: value.redirectTarget ?? value.redirect_uri,
    loginHint: value.loginHint
  }));

const googleCallbackQuerySchema = z
  .object({
    code: z.string().trim().min(1).optional(),
    state: z.string().trim().min(8).optional(),
    error: z.string().trim().min(1).optional(),
    error_description: z.string().trim().min(1).optional()
  })
  .passthrough();

const sessionRefreshSchema = z
  .object({
    refreshToken: z.string().trim().min(12).optional(),
    refresh_token: z.string().trim().min(12).optional()
  })
  .strict()
  .transform((value, ctx) => {
    const refreshToken = value.refreshToken ?? value.refresh_token;

    if (!refreshToken) {
      ctx.addIssue({
        code: "custom",
        message: "refreshToken or refresh_token is required."
      });

      return z.NEVER;
    }

    return {
      refreshToken
    };
  });

function redirectTargetScheme(value: string | undefined): string {
  if (!value) {
    return "default";
  }

  try {
    return new URL(value).protocol.replace(/:$/, "");
  } catch {
    return "invalid";
  }
}

export async function registerAuthRoutes(app: FastifyInstance, deps: RouteDeps): Promise<void> {
  const service = new AuthService(deps.env);

  app.post(
    "/auth/otp/start",
    {
      config: {
        auditClassification: "account_token"
      }
    },
    async (request, reply) => {
      const input = parseStrict(otpStartSchema, request.body);
      const response = service.startOtp(input);

      deps.auditLogger.info({
        event: "auth_otp_start",
        route: "/auth/otp/start",
        requestId: request.id,
        classification: "account_token",
        metadata: {
          channel: input.channel,
          phoneHash: hashForAudit(input.phoneNumber)
        }
      });

      return reply.status(202).send(response);
    }
  );

  app.post(
    "/auth/otp/verify",
    {
      config: {
        auditClassification: "account_token"
      }
    },
    async (request, reply) => {
      const input = parseStrict(otpVerifySchema, request.body);
      const response = service.verifyOtp(input);
      reply.header("Cache-Control", "private, no-store");

      deps.auditLogger.info({
        event: "auth_otp_verify",
        route: "/auth/otp/verify",
        requestId: request.id,
        classification: "account_token",
        metadata: {
          subject: response.subject
        }
      });

      return reply.send(response);
    }
  );

  app.get(
    "/auth/google/start",
    {
      config: {
        auditClassification: "no_case_data"
      }
    },
    async (request, reply) => {
      const input = parseStrict<StartGoogleAuthInput>(googleStartQuerySchema, request.query);
      const response = service.startGoogleAuth(input);

      reply.header("Cache-Control", "private, no-store");

      deps.auditLogger.info({
        event: "auth_google_start",
        route: "/auth/google/start",
        requestId: request.id,
        classification: "no_case_data",
        metadata: {
          redirectTargetScheme: redirectTargetScheme(response.redirectTarget),
          hasLoginHint: Boolean(input.loginHint)
        }
      });

      return reply.redirect(response.authorizationUrl);
    }
  );

  app.get(
    "/auth/google/callback",
    {
      config: {
        auditClassification: "account_token"
      }
    },
    async (request, reply) => {
      const input = parseStrict(googleCallbackQuerySchema, request.query);
      reply.header("Cache-Control", "private, no-store");

      if (input.error) {
        const redirectUrl = service.buildGoogleErrorRedirect({
          state: input.state,
          error: "google_oauth_denied",
          errorDescription: "Google sign-in was not completed."
        });

        deps.auditLogger.warn({
          event: "auth_google_denied",
          route: "/auth/google/callback",
          requestId: request.id,
          classification: "account_token",
          metadata: {
            providerError: input.error
          }
        });

        return reply.redirect(redirectUrl);
      }

      try {
        const response = await service.completeGoogleAuth(
          parseStrict<CompleteGoogleAuthInput>(
            z
              .object({
                code: z.string().trim().min(1),
                state: z.string().trim().min(8)
              })
              .strict(),
            {
              code: input.code,
              state: input.state
            }
          )
        );

        deps.auditLogger.info({
          event: "auth_google_callback",
          route: "/auth/google/callback",
          requestId: request.id,
          classification: "account_token",
          metadata: {
            subjectHash: hashForAudit(response.session.subject),
            ...(response.session.profile?.email
              ? {
                  emailHash: hashForAudit(response.session.profile.email)
                }
              : {})
          }
        });

        return reply.redirect(response.redirectUrl);
      } catch (error) {
        const appError =
          error instanceof AppError
            ? error
            : new AppError(500, "google_oauth_callback_failed", "Google sign-in could not be completed.");
        const redirectUrl = service.buildGoogleErrorRedirect({
          state: input.state,
          error: appError.code,
          errorDescription: appError.message
        });

        deps.auditLogger.warn({
          event: "auth_google_callback_failed",
          route: "/auth/google/callback",
          requestId: request.id,
          classification: "account_token",
          metadata: {
            code: appError.code
          }
        });

        return reply.redirect(redirectUrl);
      }
    }
  );

  app.post(
    "/auth/session/refresh",
    {
      config: {
        auditClassification: "account_token"
      }
    },
    async (request, reply) => {
      const input = parseStrict<RefreshSessionInput>(sessionRefreshSchema, request.body);
      const response = service.refreshSession(input);
      reply.header("Cache-Control", "private, no-store");

      deps.auditLogger.info({
        event: "auth_session_refreshed",
        route: "/auth/session/refresh",
        requestId: request.id,
        classification: "account_token",
        metadata: {
          subjectHash: hashForAudit(response.subject)
        }
      });

      return reply.send(response);
    }
  );
}
