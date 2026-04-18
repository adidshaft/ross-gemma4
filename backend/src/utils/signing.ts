import { createHash, createHmac, timingSafeEqual } from "node:crypto";

export interface SignedEnvelope<T> {
  payload: T;
  signature: string;
  algorithm: "HS256";
  keyId: string;
  signedAt: string;
  digest: string;
}

function stableValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => stableValue(item));
  }

  if (value && typeof value === "object") {
    const sortedEntries = Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, childValue]) => [key, stableValue(childValue)]);

    return Object.fromEntries(sortedEntries);
  }

  return value;
}

export function canonicalize(value: unknown): string {
  return JSON.stringify(stableValue(value));
}

export function sha256Hex(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function hashForAudit(value: string): string {
  return sha256Hex(value).slice(0, 16);
}

export function signPayload<T>(payload: T, secret: string, keyId: string): SignedEnvelope<T> {
  const canonicalPayload = canonicalize(payload);

  return {
    payload,
    signature: createHmac("sha256", secret).update(canonicalPayload).digest("hex"),
    algorithm: "HS256",
    keyId,
    signedAt: new Date().toISOString(),
    digest: sha256Hex(canonicalPayload)
  };
}

export function verifyStubSignature(
  payload: unknown,
  providedSignature: string | undefined,
  secret: string | undefined
): boolean {
  if (!secret) {
    return true;
  }

  if (!providedSignature) {
    return false;
  }

  const normalizedSignature = providedSignature.split("=").at(-1)?.trim() ?? "";
  const expectedSignature = createHmac("sha256", secret).update(canonicalize(payload)).digest("hex");

  if (normalizedSignature.length !== expectedSignature.length) {
    return false;
  }

  return timingSafeEqual(Buffer.from(normalizedSignature), Buffer.from(expectedSignature));
}
