import type { FastifyInstance } from "fastify";
import { z } from "zod";

import type { AuditLogger } from "../audit/logger.js";
import { assertNoCaseDataPayload, assertSafePublicLawQuery, parseStrict } from "../security/privacy.js";
import { PublicSearchProxyService } from "./service.js";
import { hashForAudit } from "../utils/signing.js";

interface RouteDeps {
  auditLogger: AuditLogger;
}

const publicSearchSchema = z
  .object({
    query: z
      .string()
      .trim()
      .min(3)
      .max(240)
      .regex(/^[^\r\n]+$/, "Query must be a single-line public query preview."),
    jurisdiction: z.string().trim().min(2).max(20).default("IN-ALL"),
    language: z.enum(["en", "hi"]).default("en"),
    confirmedPublicPreview: z.literal(true)
  })
  .strict();

export async function registerPublicSearchProxyRoutes(
  app: FastifyInstance,
  deps: RouteDeps
): Promise<void> {
  const service = new PublicSearchProxyService();

  app.post(
    "/public-law/search",
    {
      config: {
        auditClassification: "sanitized_public_query"
      }
    },
    async (request, reply) => {
      assertNoCaseDataPayload(request.body);
      const input = parseStrict(publicSearchSchema, request.body);
      assertSafePublicLawQuery(input.query);
      const response = service.search(input);

      deps.auditLogger.info({
        event: "public_search_executed",
        route: "/public-law/search",
        requestId: request.id,
        classification: "sanitized_public_query",
        metadata: {
          jurisdiction: input.jurisdiction,
          language: input.language,
          queryHash: hashForAudit(input.query),
          queryLength: input.query.length
        }
      });

      return reply.send(response);
    }
  );
}
