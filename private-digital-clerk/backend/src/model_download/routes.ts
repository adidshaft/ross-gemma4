import type { FastifyInstance } from "fastify";
import { z } from "zod";

import type { AuditLogger } from "../audit/logger.js";
import type { RuntimeEnv } from "../security/env.js";
import { assertNoCaseDataPayload, hashValueSchema, parseStrict, platformSchema } from "../security/privacy.js";
import { hashForAudit } from "../utils/signing.js";
import { ModelDownloadService } from "./service.js";

interface RouteDeps {
  env: RuntimeEnv;
  auditLogger: AuditLogger;
}

const modelDownloadSessionSchema = z
  .object({
    accountToken: z.string().trim().min(12),
    packId: z.string().trim().min(3).max(64),
    platform: platformSchema,
    deviceIdHash: hashValueSchema,
    appVersion: z.string().trim().min(3).max(32)
  })
  .strict();

export async function registerModelDownloadRoutes(
  app: FastifyInstance,
  deps: RouteDeps
): Promise<void> {
  const service = new ModelDownloadService(deps.env);

  app.post(
    "/model-download/session",
    {
      config: {
        auditClassification: "account_token"
      }
    },
    async (request, reply) => {
      assertNoCaseDataPayload(request.body);
      const input = parseStrict(modelDownloadSessionSchema, request.body);
      const response = service.createSession(input);

      deps.auditLogger.info({
        event: "model_download_session_created",
        route: "/model-download/session",
        requestId: request.id,
        classification: "account_token",
        metadata: {
          accountHash: hashForAudit(input.accountToken),
          packId: input.packId,
          platform: input.platform
        }
      });

      return reply.send(response);
    }
  );
}
