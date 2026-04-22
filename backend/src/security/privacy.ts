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

function normalizeText(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
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

export class PublicQueryPrivacyViolationError extends AppError {
  constructor(reasons: string[]) {
    super(
      400,
      "privacy_boundary_violation",
      "Public-law search only accepts general public-law research queries.",
      {
        reasons
      }
    );
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

export function assertSafePublicLawQuery(query: string): void {
  const normalizedQuery = normalizeText(query);
  const reasons = new Set<string>();

  if (
    /\b(my|our)\s+(client|case|matter)\b/.test(normalizedQuery) ||
    /\b(private|confidential)\s+matter\b/.test(normalizedQuery) ||
    /\bthis\s+(case|matter)\b/.test(normalizedQuery)
  ) {
    reasons.add("private_matter_content");
  }

  if (/\b\d{10}\b/.test(query) || /\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b/i.test(query)) {
    reasons.add("sensitive_identifier");
  }

  if (/\b[A-Za-z]{1,8}[(/\- ]*\d+[A-Za-z/()\- ]*\d{4}\b/i.test(query)) {
    reasons.add("filing_reference");
  }

  if (/\b[^()\s]+\.(pdf|docx|doc|txt|png|jpg|jpeg)\b/i.test(query)) {
    reasons.add("file_name");
  }

  if (
    /\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b/.test(query) ||
    /\b\d{1,2}\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+\d{4}\b/i.test(query)
  ) {
    reasons.add("exact_private_date");
  }

  if (/\b(?:client|party|petitioner|respondent|appellant|defendant|plaintiff|chat history|source chunk|ocr|filename|address|mobile)\b/i.test(query)) {
    reasons.add("private_context_term");
  }

  if (/\b(?:near|behind|opposite|at)\s+[A-Za-z][A-Za-z\s]{3,40}\b/i.test(query)) {
    reasons.add("location_detail");
  }

  if (
    normalizedQuery.includes("raghav fakepriv") ||
    normalizedQuery.includes("9876501234") ||
    normalizedQuery.includes("fakepriv example com") ||
    normalizedQuery.includes("fake 123 2026") ||
    normalizedQuery.includes("blue suitcase near temple")
  ) {
    reasons.add("test_secret");
  }

  if (reasons.size > 0) {
    throw new PublicQueryPrivacyViolationError([...reasons].sort());
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
