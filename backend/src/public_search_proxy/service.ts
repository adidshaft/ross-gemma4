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

interface PublicLawFixture {
  id: string;
  jurisdiction: string;
  source: string;
  title: string;
  citation: string;
  snippet: string;
  link: string;
  tags: string[];
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

const PUBLIC_LAW_FIXTURES: PublicLawFixture[] = [
  {
    id: "arb-1996-section-34",
    jurisdiction: "IN-ALL",
    source: "Official or licensed source (preview)",
    title: "Arbitration and Conciliation Act, 1996: setting aside awards under Section 34",
    citation: "Arbitration and Conciliation Act, 1996, s. 34",
    snippet:
      "Sanitized fixture summary covering limited judicial review of arbitral awards and common public-law grounds raised in challenge petitions.",
    link: "https://example.invalid/public-law/fixtures/arb-1996-section-34",
    tags: ["arbitration", "award", "section 34", "judicial review", "challenge"]
  },
  {
    id: "limitation-1963-overview",
    jurisdiction: "IN-ALL",
    source: "Official or licensed source (preview)",
    title: "Limitation Act, 1963: condensed limitation periods overview",
    citation: "Limitation Act, 1963",
    snippet:
      "Sanitized fixture summary of commonly referenced limitation principles for civil filings, delay, and condonation issues.",
    link: "https://example.invalid/public-law/fixtures/limitation-1963-overview",
    tags: ["limitation", "delay", "condonation", "civil procedure", "filing period"]
  },
  {
    id: "evidence-65b-overview",
    jurisdiction: "IN-ALL",
    source: "Official or licensed source (preview)",
    title: "Indian Evidence Act: electronic records and Section 65B certificates",
    citation: "Indian Evidence Act, 1872, s. 65B",
    snippet:
      "Sanitized fixture summary for foundational requirements around admissibility of electronic evidence and certificate practice.",
    link: "https://example.invalid/public-law/fixtures/evidence-65b-overview",
    tags: ["electronic evidence", "65b", "certificate", "digital records", "admissibility"]
  },
  {
    id: "consumer-protection-2019-overview",
    jurisdiction: "IN-ALL",
    source: "Official or licensed source (preview)",
    title: "Consumer Protection Act, 2019: complaint and appellate structure overview",
    citation: "Consumer Protection Act, 2019",
    snippet:
      "Sanitized fixture summary of forum structure, limitation touchpoints, and typical statutory remedies in consumer matters.",
    link: "https://example.invalid/public-law/fixtures/consumer-protection-2019-overview",
    tags: ["consumer", "complaint", "appeal", "forum", "remedy"]
  },
  {
    id: "cpc-temporary-injunctions",
    jurisdiction: "IN-ALL",
    source: "Official or licensed source (preview)",
    title: "Code of Civil Procedure: temporary injunctions and interim relief",
    citation: "Code of Civil Procedure, 1908, O. XXXIX rr. 1-2",
    snippet:
      "Sanitized fixture summary of prima facie case, balance of convenience, and irreparable injury factors for interim relief.",
    link: "https://example.invalid/public-law/fixtures/cpc-temporary-injunctions",
    tags: ["injunction", "interim relief", "order 39", "civil procedure", "balance of convenience"]
  }
];

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

function buildFixtureScore(fixture: PublicLawFixture, queryTokens: string[], jurisdiction: string): number {
  const haystack = normalizeText(
    [fixture.title, fixture.citation, fixture.snippet, ...fixture.tags].join(" ")
  );

  let score = fixture.jurisdiction === jurisdiction ? 8 : fixture.jurisdiction === "IN-ALL" ? 4 : 0;

  for (const token of queryTokens) {
    if (haystack.includes(token)) {
      score += fixture.title.toLowerCase().includes(token) ? 6 : 3;
    }
  }

  return score;
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

function buildFixtureResults(input: PublicSearchInput): PublicSearchResult[] {
  const queryTokens = tokenize(input.query);
  const scoredFixtures = PUBLIC_LAW_FIXTURES.map((fixture) => ({
    fixture,
    score: buildFixtureScore(fixture, queryTokens, input.jurisdiction)
  }))
    .filter(({ score, fixture }) => score > 0 || fixture.jurisdiction === "IN-ALL")
    .sort((left, right) => right.score - left.score || left.fixture.title.localeCompare(right.fixture.title));

  return scoredFixtures.slice(0, 4).map(({ fixture, score }) => ({
    resultId: fixture.id,
    source: fixture.source,
    title: fixture.title,
    citation: fixture.citation,
    snippet: fixture.snippet,
    link: fixture.link,
    jurisdiction: fixture.jurisdiction,
    score,
    matchedTerms: queryTokens.filter((token) =>
      normalizeText([fixture.title, fixture.citation, fixture.snippet, ...fixture.tags].join(" ")).includes(token)
    )
  }));
}

function buildFixtureResponse(input: PublicSearchInput, statusNote: string): PublicSearchResponse {
  const results = buildFixtureResults(input);

  return {
    requestId: createId("pls"),
    approvalState: "confirmed_public_preview",
    queryHash: hashForAudit(input.query),
    connector: {
      mode: "backend_fixture_index",
      liveSourceConnected: false,
      cache: buildCacheMetadata(input)
    },
    results,
    resultCount: results.length,
    disclaimers: [
      "Public-law results are drafts for advocate review.",
      "Only a sanitized public-law query crossed the network boundary.",
      statusNote
    ]
  };
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
        score: supportSegments.length * 10 + matchedTerms.length * 4 + Math.max(0, 4 - index),
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
    const liveSearchFallbackNote =
      "Live public-law results are temporarily unavailable, so Ross is using a privacy-safe fallback index.";

    if (!this.env.publicLawGeminiApiKey) {
      return buildFixtureResponse(
        input,
        "Live public-law search is not configured on this backend, so Ross is using a privacy-safe fallback index."
      );
    }

    const endpoint = new URL(
      `/v1beta/models/${encodeURIComponent(this.env.publicLawGeminiModel)}:generateContent`,
      this.env.publicLawGeminiBaseUrl
    ).toString();

    let response: Response;
    try {
      response = await this.fetchImpl(endpoint, {
        method: "POST",
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
      return buildFixtureResponse(input, liveSearchFallbackNote);
    }

    if (!response.ok) {
      return buildFixtureResponse(input, liveSearchFallbackNote);
    }

    let payload: GeminiGenerateContentResponse;
    try {
      payload = (await response.json()) as GeminiGenerateContentResponse;
    } catch {
      return buildFixtureResponse(input, liveSearchFallbackNote);
    }

    const results = buildGeminiResults(input, payload);
    if (results.length === 0) {
      return buildFixtureResponse(input, liveSearchFallbackNote);
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
