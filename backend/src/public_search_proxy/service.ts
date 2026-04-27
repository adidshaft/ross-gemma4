import type { RuntimeEnv } from "../security/env.js";
import { createId } from "../utils/ids.js";
import { AppError } from "../utils/http.js";
import { hashForAudit } from "../utils/signing.js";

export interface PublicSearchInput {
  query: string;
  jurisdiction: string;
  language: "en" | "hi";
  confirmedPublicPreview: true;
}

interface PublicSearchResult {
  resultId: string;
  source: string;
  title: string;
  citation: string;
  snippet: string;
  link: string;
  jurisdiction: string;
  score: number;
  matchedTerms: string[];
}

interface PublicSearchResponse {
  requestId: string;
  approvalState: "confirmed_public_preview";
  queryHash: string;
  connector: {
    mode: string;
    liveSourceConnected: boolean;
    cache: {
      policy: "private, no-store";
      ttlSeconds: 0;
      cacheKey: string;
      servedFromCache: false;
    };
  };
  results: PublicSearchResult[];
  resultCount: number;
  disclaimers: string[];
}

interface GeminiGroundingChunk {
  web?: {
    uri?: string;
    title?: string;
  };
}

interface GeminiGroundingSupport {
  segment?: {
    startIndex?: number;
    endIndex?: number;
    text?: string;
  };
  groundingChunkIndices?: number[];
}

interface GeminiCandidate {
  content?: {
    parts?: Array<{
      text?: string;
    }>;
  };
  groundingMetadata?: {
    webSearchQueries?: string[];
    groundingChunks?: GeminiGroundingChunk[];
    groundingSupports?: GeminiGroundingSupport[];
  };
}

interface GeminiGenerateContentResponse {
  candidates?: GeminiCandidate[];
}

type FetchLike = typeof fetch;

const GEMINI_SEARCH_TIMEOUT_MS = 15_000;

const PUBLIC_LAW_GEMINI_SYSTEM_INSTRUCTION = [
  "You help Ross perform public-law research for Indian advocates.",
  "Only the sanitized user query is user-provided context.",
  "Do not assume access to any private matter details beyond the sanitized query.",
  "Use Google Search grounding for fresh public sources and prefer official, court, statutory, or otherwise reliable public-law material.",
  "Return grounded public-law research only."
].join(" ");

function normalizeText(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function tokenize(value: string): string[] {
  return normalizeText(value)
    .split(" ")
    .filter((token) => token.length >= 2);
}

function clipText(value: string, maxLength: number): string {
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (trimmed.length <= maxLength) {
    return trimmed;
  }

  return `${trimmed.slice(0, maxLength - 1).trimEnd()}…`;
}

function safeHostname(value: string | undefined): string | undefined {
  if (!value) {
    return undefined;
  }

  try {
    return new URL(value).hostname.replace(/^www\./i, "");
  } catch {
    return undefined;
  }
}

function uniqueNonEmpty(values: Array<string | undefined>): string[] {
  const seen = new Set<string>();

  for (const value of values) {
    const normalized = value?.trim();
    if (!normalized) {
      continue;
    }

    seen.add(normalized);
  }

  return [...seen];
}

function sourceQualityScore(host: string | undefined, title: string | undefined, link: string | undefined): number {
  const normalized = [host, title, link]
    .filter((value): value is string => Boolean(value))
    .join(" ")
    .toLowerCase();
  if (!normalized) {
    return 0;
  }
  if (
    normalized.endsWith(".gov.in") ||
    normalized.endsWith(".nic.in") ||
    normalized.includes("sci.gov.in") ||
    normalized.includes("indiacode.nic.in") ||
    normalized.includes("judgments.ecourts.gov.in")
  ) {
    return 30;
  }
  if (
    normalized.includes("indiankanoon.org") ||
    normalized.includes("livelaw.in") ||
    normalized.includes("scobserver.in") ||
    normalized.includes("barandbench.com")
  ) {
    return 14;
  }
  if (
    normalized.includes("scribd.com") ||
    normalized.includes("studocu.com") ||
    normalized.includes("coursehero.com") ||
    normalized.includes("slideshare.net")
  ) {
    return -100;
  }

  return 0;
}

function buildCacheMetadata(input: PublicSearchInput) {
  return {
    policy: "private, no-store" as const,
    ttlSeconds: 0 as const,
    cacheKey: hashForAudit(`${input.jurisdiction}:${input.language}:${input.query}`),
    servedFromCache: false as const
  };
}

function extractGeminiAnswerText(candidate: GeminiCandidate | undefined): string {
  return (
    candidate?.content?.parts
      ?.map((part) => part.text?.trim())
      .filter((part): part is string => Boolean(part))
      .join(" ")
      .trim() ?? ""
  );
}

function buildGeminiResults(input: PublicSearchInput, payload: GeminiGenerateContentResponse): PublicSearchResult[] {
  const candidate = payload.candidates?.[0];
  const answerText = extractGeminiAnswerText(candidate);
  const groundingChunks = candidate?.groundingMetadata?.groundingChunks ?? [];
  const groundingSupports = candidate?.groundingMetadata?.groundingSupports ?? [];
  const queryTokens = tokenize(input.query);
  const supportTextByChunk = new Map<number, string[]>();

  for (const support of groundingSupports) {
    const segmentText = support.segment?.text?.trim();
    if (!segmentText) {
      continue;
    }

    for (const chunkIndex of support.groundingChunkIndices ?? []) {
      const existing = supportTextByChunk.get(chunkIndex) ?? [];
      if (!existing.includes(segmentText)) {
        existing.push(segmentText);
      }
      supportTextByChunk.set(chunkIndex, existing);
    }
  }

  const results = groundingChunks
    .map((chunk, index): PublicSearchResult | null => {
      const link = chunk.web?.uri?.trim();
      const host = safeHostname(link);
      const supportSegments = supportTextByChunk.get(index) ?? [];
      const title = chunk.web?.title?.trim() || host || "Public-law source";
      const qualityScore = sourceQualityScore(host, title, link);
      if (qualityScore <= -100) {
        return null;
      }
      const citation = host ? `Public web source • ${host}` : "Public web source";
      const snippet = clipText(
        uniqueNonEmpty([
          ...supportSegments,
          answerText ? `${answerText}` : undefined
        ]).join(" "),
        320
      );

      if (!link || !snippet) {
        return null;
      }

      const haystack = normalizeText(`${title} ${citation} ${snippet}`);
      const matchedTerms = queryTokens.filter((token) => haystack.includes(token));

      return {
        resultId: createId(`gem-${index + 1}`),
        source: host ?? "Public web source",
        title,
        citation,
        snippet,
        link,
        jurisdiction: input.jurisdiction,
        score: qualityScore + supportSegments.length * 10 + matchedTerms.length * 4 + Math.max(0, 4 - index),
        matchedTerms
      };
    })
    .filter((result): result is PublicSearchResult => Boolean(result))
    .sort((left, right) => right.score - left.score || left.title.localeCompare(right.title))
    .slice(0, 4);

  return results;
}

export class PublicSearchProxyService {
  constructor(
    private readonly env: RuntimeEnv,
    private readonly fetchImpl: FetchLike = globalThis.fetch.bind(globalThis)
  ) {}

  async search(input: PublicSearchInput): Promise<PublicSearchResponse> {
    if (!this.env.publicLawGeminiApiKey) {
      throw new AppError(
        503,
        "public_law_gemini_unavailable",
        "Live Gemini public-law search is required for this backend and is not configured."
      );
    }

    const endpoint = new URL(
      `/v1beta/models/${encodeURIComponent(this.env.publicLawGeminiModel)}:generateContent`,
      this.env.publicLawGeminiBaseUrl
    ).toString();

    let response: Response;
    const controller = new AbortController();
    const timeout = setTimeout(() => {
      controller.abort();
    }, GEMINI_SEARCH_TIMEOUT_MS);

    try {
      response = await this.fetchImpl(endpoint, {
        method: "POST",
        signal: controller.signal,
        headers: {
          "content-type": "application/json",
          accept: "application/json",
          "x-goog-api-key": this.env.publicLawGeminiApiKey
        },
        body: JSON.stringify({
          systemInstruction: {
            parts: [
              {
                text: PUBLIC_LAW_GEMINI_SYSTEM_INSTRUCTION
              }
            ]
          },
          contents: [
            {
              role: "user",
              parts: [
                {
                  text: input.query
                }
              ]
            }
          ],
          tools: [
            {
              google_search: {}
            }
          ],
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: 768
          }
        })
      });
    } catch {
      throw new AppError(
        503,
        "public_law_gemini_unavailable",
        "Live Gemini public-law search is required for this backend and is not available right now."
      );
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      throw new AppError(
        503,
        "public_law_gemini_unavailable",
        "Live Gemini public-law search returned an unavailable response."
      );
    }

    let payload: GeminiGenerateContentResponse;
    try {
      payload = (await response.json()) as GeminiGenerateContentResponse;
    } catch {
      throw new AppError(
        503,
        "public_law_gemini_unavailable",
        "Live Gemini public-law search returned an unreadable response."
      );
    }

    const results = buildGeminiResults(input, payload);
    if (results.length === 0) {
      throw new AppError(
        503,
        "public_law_gemini_unavailable",
        "Live Gemini public-law search returned no grounded sources."
      );
    }

    return {
      requestId: createId("pls"),
      approvalState: "confirmed_public_preview",
      queryHash: hashForAudit(input.query),
      connector: {
        mode: "gemini_google_search",
        liveSourceConnected: true,
        cache: buildCacheMetadata(input)
      },
      results,
      resultCount: results.length,
      disclaimers: [
        "Public-law results are drafts for advocate review.",
        "Only a sanitized public-law query crossed the network boundary.",
        "Live public-law results were grounded from public web sources."
      ]
    };
  }
}
