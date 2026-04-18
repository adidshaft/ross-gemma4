import type { FastifyInstance } from "fastify";
import { z } from "zod";

import type { AuditLogger } from "../audit/logger.js";
import type { RuntimeEnv } from "../security/env.js";
import { assertNoCaseDataPayload, hashValueSchema, parseStrict, platformSchema } from "../security/privacy.js";
import { MODEL_PACKS } from "../model_catalog/service.js";
import { findDevArtifactRecord } from "./dev_artifacts.js";
import { hashForAudit } from "../utils/signing.js";
import { AppError } from "../utils/http.js";
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
      reply.header("Cache-Control", "private, no-store");

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

  app.get(
    "/dev-artifacts/:artifactId",
    {
      config: {
        auditClassification: "no_case_data"
      }
    },
    async (request, reply) => {
      const params = parseStrict(
        z
          .object({
            artifactId: z.string().trim().min(8).max(128)
          })
          .strict(),
        request.params
      );

      const record = findDevArtifactRecord(MODEL_PACKS, params.artifactId);

      if (!record) {
        throw new AppError(404, "unknown_dev_artifact", "Requested development artifact does not exist.");
      }

      const totalBytes = record.bytes.length;
      const rangeHeader = request.headers.range;
      let startByte = 0;
      let endByteInclusive = totalBytes - 1;
      let statusCode = 200;

      if (typeof rangeHeader === "string" && rangeHeader.trim().length > 0) {
        const match = /^bytes=(\d+)-(\d+)?$/i.exec(rangeHeader.trim());

        if (!match) {
          throw new AppError(416, "range_not_satisfiable", "Requested byte range is invalid.");
        }

        startByte = Number.parseInt(match[1] ?? "", 10);
        endByteInclusive =
          match[2] === undefined ? totalBytes - 1 : Number.parseInt(match[2], 10);

        if (
          !Number.isFinite(startByte) ||
          !Number.isFinite(endByteInclusive) ||
          startByte < 0 ||
          endByteInclusive < startByte ||
          startByte >= totalBytes ||
          endByteInclusive >= totalBytes
        ) {
          throw new AppError(416, "range_not_satisfiable", "Requested byte range is outside the development artifact.");
        }

        statusCode = 206;
        reply.header("Content-Range", `bytes ${startByte}-${endByteInclusive}/${totalBytes}`);
      }

      const chunk = record.bytes.subarray(startByte, endByteInclusive + 1);
      reply
        .code(statusCode)
        .header("Accept-Ranges", "bytes")
        .header("Cache-Control", "private, no-store")
        .header("Content-Type", record.descriptor.contentType)
        .header("Content-Length", String(chunk.length))
        .header("Content-Disposition", `attachment; filename="${record.descriptor.fileName}"`);

      deps.auditLogger.info({
        event: "dev_artifact_served",
        route: "/dev-artifacts/:artifactId",
        requestId: request.id,
        classification: "no_case_data",
        metadata: {
          artifactId: params.artifactId,
          statusCode,
          startByte,
          endByteInclusive
        }
      });

      return reply.send(chunk);
    }
  );
}
