import { createHash } from "node:crypto";

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

const artifactCache = new Map<string, DevArtifactRecord>();

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

export function findDevArtifactRecord(packs: ModelPack[], artifactId: string): DevArtifactRecord | undefined {
  for (const pack of packs) {
    const record = getDevArtifactRecord(pack);

    if (record.descriptor.artifactId === artifactId) {
      return record;
    }
  }

  return undefined;
}
