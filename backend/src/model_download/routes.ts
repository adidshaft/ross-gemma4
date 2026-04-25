import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { Readable } from "node:stream";
import type { ReadableStream as NodeReadableStream } from "node:stream/web";

import type { AuditLogger } from "../audit/logger.js";
import type { RuntimeEnv } from "../security/env.js";
import { assertNoCaseDataPayload, hashValueSchema, parseStrict, platformSchema } from "../security/privacy.js";
import { buildDownloadArtifact, findDownloadPackByArtifactId, listModelPacks } from "../model_catalog/service.js";
import { findArtifactRecord } from "./dev_artifacts.js";
import { hashForAudit } from "../utils/signing.js";
import { AppError } from "../utils/http.js";
import { ModelDownloadService } from "./service.js";
import { createReadStream } from "node:fs";

interface RouteDeps {
  env: RuntimeEnv;
  auditLogger: AuditLogger;
}

function modelArtifactMirrorUrl(env: RuntimeEnv, fileName: string): string | null {
  const baseUrl = env.modelArtifactBaseUrl?.trim().replace(/\/+$/, "");
  if (!baseUrl) {
    return null;
  }

  return `${baseUrl}/${encodeURIComponent(fileName)}`;
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
      const response = await service.createSession(input);
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
    "/model-download/artifacts/:artifactId",
    {
      config: {
        auditClassification: "account_token"
      }
    },
    async (request, reply) => {
      const params = parseStrict(
        z
          .object({
            artifactId: z.string().trim().min(8).max(160)
          })
          .strict(),
        request.params
      );

      const pack = findDownloadPackByArtifactId(deps.env, undefined, params.artifactId);
      const artifact = pack ? buildDownloadArtifact(pack) : null;
      const accountTokenHeader = request.headers["x-ross-account-token"];
      const accountToken = Array.isArray(accountTokenHeader)
        ? accountTokenHeader[0]
        : accountTokenHeader;

      if (!pack || !artifact || pack.artifactKind !== "huggingface_gated_model_artifact") {
        throw new AppError(404, "unknown_model_artifact", "Requested model artifact does not exist.");
      }

      if (!accountToken || accountToken.trim().length < 12) {
        throw new AppError(401, "account_token_required", "A Ross account session is required to download model artifacts.");
      }

      const mirrorUrl = modelArtifactMirrorUrl(deps.env, artifact.fileName);
      const sourceUrl = mirrorUrl ?? pack.downloadUrl ?? artifact.downloadUrl;
      const sourceKind = mirrorUrl ? "ross_artifact_mirror" : "huggingface";

      if (!mirrorUrl && !deps.env.huggingFaceAccessToken) {
        throw new AppError(
          409,
          "huggingface_token_required",
          "Ross backend needs either ROSS_MODEL_ARTIFACT_BASE_URL or a Hugging Face access token to serve this Android model artifact."
        );
      }

      const headers: Record<string, string> = {
        Accept: "application/octet-stream"
      };
      const bearerToken = mirrorUrl ? deps.env.modelArtifactBearerToken : deps.env.huggingFaceAccessToken;
      if (bearerToken) {
        headers.Authorization = `Bearer ${bearerToken}`;
      }
      const rangeHeader = request.headers.range;
      if (typeof rangeHeader === "string" && rangeHeader.trim().length > 0) {
        headers.Range = rangeHeader.trim();
      }

      const upstream = await fetch(sourceUrl, {
        method: "GET",
        headers,
        redirect: "follow"
      });

      if (!upstream.ok || !upstream.body) {
        throw new AppError(
          upstream.status === 401 || upstream.status === 403 ? 502 : upstream.status,
          "model_artifact_upstream_unavailable",
          "Ross could not fetch the verified model artifact from the upstream model host."
        );
      }

      reply
        .code(upstream.status)
        .header("Accept-Ranges", upstream.headers.get("accept-ranges") ?? "bytes")
        .header("Cache-Control", "private, no-store")
        .header("Content-Type", upstream.headers.get("content-type") ?? artifact.contentType)
        .header("Content-Disposition", `attachment; filename="${artifact.fileName}"`);

      const contentLength = upstream.headers.get("content-length");
      const contentRange = upstream.headers.get("content-range");
      if (contentLength) {
        reply.header("Content-Length", contentLength);
      }
      if (contentRange) {
        reply.header("Content-Range", contentRange);
      }

      deps.auditLogger.info({
        event: "model_artifact_proxy_served",
        route: "/model-download/artifacts/:artifactId",
        requestId: request.id,
        classification: "account_token",
        metadata: {
          artifactId: params.artifactId,
          packId: pack.packId,
          sourceKind,
          accountHash: hashForAudit(accountToken),
          statusCode: upstream.status,
          rangeRequested: typeof rangeHeader === "string" && rangeHeader.trim().length > 0
        }
      });

      return reply.send(Readable.fromWeb(upstream.body as unknown as NodeReadableStream));
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

      const record = await findArtifactRecord(deps.env, listModelPacks(deps.env), params.artifactId);

      if (!record) {
        throw new AppError(404, "unknown_dev_artifact", "Requested development artifact does not exist.");
      }

      const totalBytes =
        "bytes" in record ? record.bytes.length : record.descriptor.sizeBytes;
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

      reply
        .code(statusCode)
        .header("Accept-Ranges", "bytes")
        .header("Cache-Control", "private, no-store")
        .header("Content-Type", record.descriptor.contentType)
        .header("Content-Length", String(endByteInclusive - startByte + 1))
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

      if ("bytes" in record) {
        const chunk = record.bytes.subarray(startByte, endByteInclusive + 1);
        return reply.send(chunk);
      }

      return reply.send(
        createReadStream(record.absolutePath, {
          start: startByte,
          end: endByteInclusive
        })
      );
    }
  );
}
