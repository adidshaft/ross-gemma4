import { createId } from "../utils/ids.js";
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

const PUBLIC_LAW_FIXTURES: PublicLawFixture[] = [
  {
    id: "arb-1996-section-34",
    jurisdiction: "IN-ALL",
    source: "Backend fixture index",
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
    source: "Backend fixture index",
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
    source: "Backend fixture index",
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
    source: "Backend fixture index",
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
    source: "Backend fixture index",
    title: "Code of Civil Procedure: temporary injunctions and interim relief",
    citation: "Code of Civil Procedure, 1908, O. XXXIX rr. 1-2",
    snippet:
      "Sanitized fixture summary of prima facie case, balance of convenience, and irreparable injury factors for interim relief.",
    link: "https://example.invalid/public-law/fixtures/cpc-temporary-injunctions",
    tags: ["injunction", "interim relief", "order 39", "civil procedure", "balance of convenience"]
  }
];

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

export class PublicSearchProxyService {
  search(input: PublicSearchInput) {
    const queryTokens = tokenize(input.query);
    const scoredFixtures = PUBLIC_LAW_FIXTURES.map((fixture) => ({
      fixture,
      score: buildFixtureScore(fixture, queryTokens, input.jurisdiction)
    }))
      .filter(({ score, fixture }) => score > 0 || fixture.jurisdiction === "IN-ALL")
      .sort((left, right) => right.score - left.score || left.fixture.title.localeCompare(right.fixture.title));

    const topFixtures = scoredFixtures.slice(0, 4);

    return {
      requestId: createId("pls"),
      approvalState: "confirmed_public_preview",
      queryHash: hashForAudit(input.query),
      connector: {
        mode: "backend_fixture_index",
        liveSourceConnected: false,
        cache: {
          policy: "private, no-store",
          ttlSeconds: 0,
          cacheKey: hashForAudit(`${input.jurisdiction}:${input.language}:${input.query}`),
          servedFromCache: false
        }
      },
      results: topFixtures.map(({ fixture, score }) => ({
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
      })),
      resultCount: topFixtures.length,
      disclaimers: [
        "Public-law results are drafts for advocate review.",
        "No case files or private matter details are stored by this backend.",
        "This backend currently serves a sanitized fixture index until an approved connector is integrated."
      ]
    };
  }
}
