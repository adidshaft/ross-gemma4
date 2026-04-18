import type { FastifyInstance } from "fastify";
import { z } from "zod";

import type { AuditLogger } from "../audit/logger.js";
import type { RuntimeEnv } from "../security/env.js";
import { assertNoCaseDataPayload, hashValueSchema, parseStrict, platformSchema } from "../security/privacy.js";
import { hashForAudit } from "../utils/signing.js";
import { EntitlementsService } from "./service.js";

interface RouteDeps {
  env: RuntimeEnv;
  auditLogger: AuditLogger;
}

const refreshSchema = z
  .object({
    accountToken: z.string().trim().min(12),
    platform: platformSchema,
    appVersion: z.string().trim().min(3).max(32),
    deviceIdHash: hashValueSchema
  })
  .strict();

export async function registerEntitlementRoutes(
  app: FastifyInstance,
  deps: RouteDeps
): Promise<void> {
  const service = new EntitlementsService(deps.env);

  app.post(
    "/entitlements/refresh",
    {
      config: {
        auditClassification: "account_token"
      }
    },
    async (request, reply) => {
      assertNoCaseDataPayload(request.body);
      const input = parseStrict(refreshSchema, request.body);
      const response = service.refresh(input);

      deps.auditLogger.info({
        event: "entitlements_refreshed",
        route: "/entitlements/refresh",
        requestId: request.id,
        classification: "account_token",
        metadata: {
          accountHash: hashForAudit(input.accountToken),
          platform: input.platform
        }
      });

      return reply.send(response);
    }
  );
}
