import type { FastifyInstance } from "fastify";
import { z } from "zod";

import type { AuditLogger } from "../audit/logger.js";
import type { RuntimeEnv } from "../security/env.js";
import { assertNoCaseDataPayload, parseStrict, platformSchema } from "../security/privacy.js";
import { ModelCatalogService, type CapabilityTier } from "./service.js";

interface RouteDeps {
  env: RuntimeEnv;
  auditLogger: AuditLogger;
}

const modelCatalogQuerySchema = z
  .object({
    platform: platformSchema,
    tier: z
      .enum(["quick_start", "case_associate", "senior_drafting_support"] satisfies [CapabilityTier, ...CapabilityTier[]])
      .optional()
  })
  .strict();

export async function registerModelCatalogRoutes(
  app: FastifyInstance,
  deps: RouteDeps
): Promise<void> {
  const service = new ModelCatalogService(deps.env);

  app.get(
    "/model-catalog",
    {
      config: {
        auditClassification: "no_case_data"
      }
    },
    async (request, reply) => {
      assertNoCaseDataPayload(request.query);
      const input = parseStrict(modelCatalogQuerySchema, request.query);
      const response = service.listCatalog(input);

      deps.auditLogger.info({
        event: "model_catalog_read",
        route: "/model-catalog",
        requestId: request.id,
        classification: "no_case_data",
        metadata: {
          platform: input.platform,
          filteredTier: input.tier ?? "all"
        }
      });

      return reply.send(response);
    }
  );
}
