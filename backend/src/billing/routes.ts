import type { FastifyInstance } from "fastify";

import type { AuditLogger } from "../audit/logger.js";
import type { RuntimeEnv } from "../security/env.js";
import { BillingService } from "./service.js";

interface RouteDeps {
  env: RuntimeEnv;
  auditLogger: AuditLogger;
}

export async function registerBillingRoutes(app: FastifyInstance, deps: RouteDeps): Promise<void> {
  const service = new BillingService(deps.env);

  app.post(
    "/billing/stripe/webhook",
    {
      config: {
        auditClassification: "billing_event"
      }
    },
    async (request, reply) => {
      const signature = request.headers["stripe-signature"];
      const response = service.handleStripeWebhook(
        request.body,
        typeof signature === "string" ? signature : undefined
      );

      deps.auditLogger.info({
        event: "billing_webhook_received",
        route: "/billing/stripe/webhook",
        requestId: request.id,
        classification: "billing_event",
        metadata: {
          provider: "stripe",
          eventId: response.eventId,
          eventType: response.eventType
        }
      });

      return reply.send(response);
    }
  );

  app.post(
    "/billing/razorpay/webhook",
    {
      config: {
        auditClassification: "billing_event"
      }
    },
    async (request, reply) => {
      const signature = request.headers["x-razorpay-signature"];
      const response = service.handleRazorpayWebhook(
        request.body,
        typeof signature === "string" ? signature : undefined
      );

      deps.auditLogger.info({
        event: "billing_webhook_received",
        route: "/billing/razorpay/webhook",
        requestId: request.id,
        classification: "billing_event",
        metadata: {
          provider: "razorpay",
          eventId: response.eventId,
          eventType: response.eventType
        }
      });

      return reply.send(response);
    }
  );
}
