import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import type { RuntimeEnv } from "../security/env.js";
import { AppError } from "../utils/http.js";
import type { ModelPack } from "../model_catalog/service.js";

export interface DevArtifactSegment {
  index: number;
  startByte: number;
  endByteInclusive: number;
  sizeBytes: number;
  sha256: string;
  rangeHeader: string;
}

export interface DevArtifactDescriptor {
  artifactId: string;
  fileName: string;
  contentType: "application/octet-stream";
  sizeBytes: number;
  segmentSizeBytes: number;
  segmentCount: number;
  finalSha256: string;
  path: string;
  segments: DevArtifactSegment[];
}

export interface DevArtifactRecord {
  descriptor: DevArtifactDescriptor;
  bytes: Buffer;
}

export interface ExternalArtifactRecord {
  descriptor: DevArtifactDescriptor;
  absolutePath: string;
}

const artifactCache = new Map<string, DevArtifactRecord>();
const EXTERNAL_SEGMENT_SIZE_BYTES = 1_048_576;
const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../.."
);

function sha256Hex(value: Buffer | string): string {
  return createHash("sha256").update(value).digest("hex");
}

function createArtifactBytes(pack: ModelPack): Buffer {
  const header = Buffer.from(
    [
      "ROSS-DEV-ARTIFACT",
      `packId=${pack.packId}`,
      `displayName=${pack.displayName}`,
      `tier=${pack.tier}`,
      `technicalModels=${pack.technicalModels.join(",")}`,
      `byteLength=${pack.sizeBytes}`,
      ""
    ].join("\n"),
    "utf8"
  );

  if (header.length > pack.sizeBytes) {
    throw new Error(`Model pack ${pack.packId} header exceeds configured dev artifact size.`);
  }

  const chunks: Buffer[] = [header];
  let remaining = pack.sizeBytes - header.length;
  let counter = 0;

  while (remaining > 0) {
    const block = createHash("sha256")
      .update(`${pack.packId}:${pack.artifactSeed}:${counter}`)
      .digest();
    const nextChunk = block.subarray(0, Math.min(remaining, block.length));
    chunks.push(nextChunk);
    remaining -= nextChunk.length;
    counter += 1;
  }

  return Buffer.concat(chunks, pack.sizeBytes);
}

export function getDevArtifactRecord(pack: ModelPack): DevArtifactRecord {
  const cached = artifactCache.get(pack.packId);

  if (cached) {
    return cached;
  }

  const artifactBytes = createArtifactBytes(pack);
  const finalSha256 = sha256Hex(artifactBytes);
  const artifactId = `${pack.packId}-dev-${finalSha256.slice(0, 12)}`;
  const segments: DevArtifactSegment[] = [];

  for (let startByte = 0, index = 0; startByte < artifactBytes.length; startByte += pack.segmentSizeBytes, index += 1) {
    const endByteExclusive = Math.min(startByte + pack.segmentSizeBytes, artifactBytes.length);
    const segment = artifactBytes.subarray(startByte, endByteExclusive);
    const endByteInclusive = endByteExclusive - 1;

    segments.push({
      index,
      startByte,
      endByteInclusive,
      sizeBytes: segment.length,
      sha256: sha256Hex(segment),
      rangeHeader: `bytes=${startByte}-${endByteInclusive}`
    });
  }

  const descriptor: DevArtifactDescriptor = {
    artifactId,
    fileName: `${pack.packId}.ross-dev.bin`,
    contentType: "application/octet-stream",
    sizeBytes: artifactBytes.length,
    segmentSizeBytes: pack.segmentSizeBytes,
    segmentCount: segments.length,
    finalSha256,
    path: `/dev-artifacts/${artifactId}`,
    segments
  };

  const record = {
    descriptor,
    bytes: artifactBytes
  };
  artifactCache.set(pack.packId, record);
  return record;
}

export function getDevArtifactDescriptor(pack: ModelPack): DevArtifactDescriptor {
  return getDevArtifactRecord(pack).descriptor;
}

function isSafeExternalArtifactPath(filePath: string): boolean {
  if (!path.isAbsolute(filePath)) {
    return false;
  }

  const normalized = path.resolve(filePath);
  const relativeToRepo = path.relative(repoRoot, normalized);

  if (
    relativeToRepo === "" ||
    (!relativeToRepo.startsWith("..") && !path.isAbsolute(relativeToRepo))
  ) {
    return false;
  }

  if (/[\\/]android[\\/]|[\\/]ios[\\/]|[\\/]backend[\\/]|[\\/]core[\\/]/i.test(normalized)) {
    return false;
  }

  if (/[\\/](build|deriveddata|tmp|dist|node_modules)[\\/]/i.test(normalized)) {
    return false;
  }

  return true;
}

async function sha256File(filePath: string): Promise<string> {
  const digest = createHash("sha256");
  const stream = createReadStream(filePath);

  for await (const chunk of stream) {
    digest.update(chunk as Buffer);
  }

  return digest.digest("hex");
}

export async function getExternalArtifactRecord(
  env: RuntimeEnv,
  pack: ModelPack
): Promise<ExternalArtifactRecord> {
  if (!env.enableExternalModelServing) {
    throw new AppError(
      403,
      "external_model_serving_disabled",
      "External development model serving is disabled."
    );
  }

  const filePath = env.externalModelFilePath;
  if (!filePath || !isSafeExternalArtifactPath(filePath)) {
    throw new AppError(
      400,
      "external_model_path_invalid",
      "The configured external development model path is invalid."
    );
  }

  const stats = await fs.stat(filePath).catch(() => null);
  if (!stats?.isFile()) {
    throw new AppError(
      404,
      "external_model_not_found",
      "The configured external development model artifact was not found."
    );
  }

  if (env.externalModelSizeBytes !== undefined && stats.size !== env.externalModelSizeBytes) {
    throw new AppError(
      400,
      "external_model_size_mismatch",
      "The configured external development model artifact did not match the declared size."
    );
  }

  if (env.externalModelSha256) {
    const actualSha256 = await sha256File(filePath);
    if (!actualSha256.match(new RegExp(`^${env.externalModelSha256}$`, "i"))) {
      throw new AppError(
        400,
        "external_model_checksum_mismatch",
        "The configured external development model artifact did not match the declared checksum."
      );
    }
  }

  const finalSha256 = env.externalModelSha256 ?? (await sha256File(filePath));
  const segmentCount = Math.ceil(stats.size / EXTERNAL_SEGMENT_SIZE_BYTES);
  const segments: DevArtifactSegment[] = [];

  for (
    let startByte = 0, index = 0;
    startByte < stats.size;
    startByte += EXTERNAL_SEGMENT_SIZE_BYTES, index += 1
  ) {
    const endByteExclusive = Math.min(startByte + EXTERNAL_SEGMENT_SIZE_BYTES, stats.size);
    const endByteInclusive = endByteExclusive - 1;
    const handle = await fs.open(filePath, "r");
    const buffer = Buffer.alloc(endByteExclusive - startByte);

    try {
      await handle.read(buffer, 0, buffer.length, startByte);
    } finally {
      await handle.close();
    }

    segments.push({
      index,
      startByte,
      endByteInclusive,
      sizeBytes: buffer.length,
      sha256: sha256Hex(buffer),
      rangeHeader: `bytes=${startByte}-${endByteInclusive}`
    });
  }

  return {
    descriptor: {
      artifactId: `${pack.packId}-external-${finalSha256.slice(0, 12)}`,
      fileName: "case-associate-local-debug.task",
      contentType: "application/octet-stream",
      sizeBytes: stats.size,
      segmentSizeBytes: EXTERNAL_SEGMENT_SIZE_BYTES,
      segmentCount,
      finalSha256,
      path: `/dev-artifacts/${pack.packId}-external-${finalSha256.slice(0, 12)}`,
      segments
    },
    absolutePath: filePath
  };
}

export async function findArtifactRecord(
  env: RuntimeEnv,
  packs: ModelPack[],
  artifactId: string
): Promise<DevArtifactRecord | ExternalArtifactRecord | undefined> {
  for (const pack of packs) {
    const record =
      pack.artifactKind === "external_debug_model"
        ? await getExternalArtifactRecord(env, pack).catch(() => undefined)
        : getDevArtifactRecord(pack);

    if (record?.descriptor.artifactId === artifactId) {
      return record;
    }
  }

  return undefined;
}
