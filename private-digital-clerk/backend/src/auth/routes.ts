import type { FastifyInstance } from "fastify";
import { z } from "zod";

import type { AuditLogger } from "../audit/logger.js";
import type { RuntimeEnv } from "../security/env.js";
import { parseStrict } from "../security/privacy.js";
import { hashForAudit } from "../utils/signing.js";
import { AuthService } from "./service.js";

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
}
