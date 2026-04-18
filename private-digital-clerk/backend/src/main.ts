import Fastify, { type FastifyInstance, type FastifyRequest } from "fastify";
import { pathToFileURL } from "node:url";

import { createAuditLogger, type AuditEvent, type DataClassification } from "./audit/logger.js";
import { registerAuthRoutes } from "./auth/routes.js";
import { registerBillingRoutes } from "./billing/routes.js";
import { registerEntitlementRoutes } from "./entitlements/routes.js";
import { registerModelCatalogRoutes } from "./model_catalog/routes.js";
import { registerModelDownloadRoutes } from "./model_download/routes.js";
import { registerPublicSearchProxyRoutes } from "./public_search_proxy/routes.js";
import { readRuntimeEnv, type RuntimeEnv } from "./security/env.js";
import { AppError } from "./utils/http.js";

interface BuildAppOptions {
  env?: RuntimeEnv | undefined;
  auditSink?: AuditEvent[] | undefined;
  emitLogsToConsole?: boolean | undefined;
}

function getAuditClassification(request: FastifyRequest): DataClassification | undefined {
  const routeConfig = request.routeOptions.config as { auditClassification?: DataClassification } | undefined;
  return routeConfig?.auditClassification;
}

function getRouteLabel(request: FastifyRequest): string {
  return request.routeOptions.url ?? request.url.split("?")[0] ?? request.url;
}

export async function buildApp(options: BuildAppOptions = {}): Promise<FastifyInstance> {
  const env = options.env ?? readRuntimeEnv();
  const auditLogger = createAuditLogger({
    sink: options.auditSink,
    emitConsole: options.emitLogsToConsole ?? !options.auditSink
  });

  const app = Fastify({
    logger: false,
    disableRequestLogging: true,
    bodyLimit: 64 * 1024
  });

  app.setErrorHandler((error, request, reply) => {
    const appError =
      error instanceof AppError
        ? error
        : new AppError(500, "internal_error", "Internal server error.");

    auditLogger.warn({
      event: "request_failed",
      route: getRouteLabel(request),
      requestId: request.id,
      classification: getAuditClassification(request),
      statusCode: appError.statusCode,
      metadata: {
        code: appError.code
      }
    });

    const responseBody: Record<string, unknown> = {
      error: appError.code,
      message: appError.message
    };

    if (appError.details !== undefined) {
      responseBody.details = appError.details;
    }

    reply.status(appError.statusCode).send(responseBody);
  });

  app.addHook("onResponse", async (request, reply) => {
    auditLogger.info({
      event: "http_request",
      route: getRouteLabel(request),
      requestId: request.id,
      classification: getAuditClassification(request),
      statusCode: reply.statusCode
    });
  });

  await registerAuthRoutes(app, { env, auditLogger });
  await registerEntitlementRoutes(app, { env, auditLogger });
  await registerModelCatalogRoutes(app, { env, auditLogger });
  await registerModelDownloadRoutes(app, { env, auditLogger });
  await registerBillingRoutes(app, { env, auditLogger });
  await registerPublicSearchProxyRoutes(app, { auditLogger });

  return app;
}

export async function startServer(): Promise<FastifyInstance> {
  const env = readRuntimeEnv();
  const app = await buildApp({ env });
  await app.listen({ host: "0.0.0.0", port: env.port });
  return app;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  startServer().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : "Unknown startup failure";
    console.error(
      JSON.stringify({
        level: "error",
        event: "startup_failure",
        message
      })
    );
    process.exit(1);
  });
}
