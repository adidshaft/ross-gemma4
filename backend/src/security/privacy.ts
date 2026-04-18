import { z, type ZodType } from "zod";

import { AppError } from "../utils/http.js";

const forbiddenNormalizedKeys = new Set([
  "attachments",
  "caseid",
  "casememory",
  "casenumber",
  "casetext",
  "chathistory",
  "chunks",
  "chunktext",
  "clientname",
  "documentid",
  "documentname",
  "documents",
  "email",
  "emailaddress",
  "embeddings",
  "file",
  "filename",
  "files",
  "filepath",
  "messages",
  "ocr",
  "ocrtext",
  "partyname",
  "partynames",
  "phonenumber",
  "phone",
  "prompt",
  "prompttext",
  "rawocrtext",
  "rawtext"
]);

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function normalizeKey(value: string): string {
  return value.replace(/[^a-zA-Z0-9]/g, "").toLowerCase();
}

export class PrivacyViolationError extends AppError {
  constructor(fields: string[]) {
    super(400, "privacy_boundary_violation", "Case-data fields are not allowed on this endpoint.", {
      fields
    });
  }
}

export class RequestValidationError extends AppError {
  constructor(issues: string[]) {
    super(400, "request_validation_error", "Request payload failed validation.", {
      issues
    });
  }
}

export function assertNoCaseDataPayload(payload: unknown): void {
  const matches = new Set<string>();

  const visit = (value: unknown, path: string): void => {
    if (Array.isArray(value)) {
      value.forEach((child, index) => visit(child, `${path}[${index}]`));
      return;
    }

    if (!isPlainObject(value)) {
      return;
    }

    for (const [key, child] of Object.entries(value)) {
      const nextPath = path ? `${path}.${key}` : key;
      const normalizedKey = normalizeKey(key);

      if (forbiddenNormalizedKeys.has(normalizedKey)) {
        matches.add(nextPath);
      }

      visit(child, nextPath);
    }
  };

  visit(payload, "");

  if (matches.size > 0) {
    throw new PrivacyViolationError([...matches].sort());
  }
}

export function parseStrict<T>(schema: ZodType<T>, payload: unknown): T {
  const parsed = schema.safeParse(payload);

  if (!parsed.success) {
    const issues = parsed.error.issues.map((issue) => {
      const path = issue.path.length > 0 ? `${issue.path.join(".")}: ` : "";
      return `${path}${issue.message}`;
    });

    throw new RequestValidationError(issues);
  }

  return parsed.data;
}

export const hashValueSchema = z
  .string()
  .trim()
  .regex(/^[a-f0-9]{8,128}$/i, "Expected a hexadecimal hash value.");

export const platformSchema = z.enum(["android", "ios"]);
