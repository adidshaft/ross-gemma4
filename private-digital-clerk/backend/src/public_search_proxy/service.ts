import { createId } from "../utils/ids.js";
import { hashForAudit } from "../utils/signing.js";

export interface PublicSearchInput {
  query: string;
  jurisdiction: string;
  language: "en" | "hi";
  confirmedPublicPreview: true;
}

export class PublicSearchProxyService {
  search(input: PublicSearchInput) {
    return {
      requestId: createId("pls"),
      approvalState: "confirmed_public_preview",
      queryHash: hashForAudit(input.query),
      results: [
        {
          source: "Official or licensed source connector (stub)",
          title: "Public-law search result stub",
          citation: "(2024) Stub 101",
          snippet: "Replace this stub with an approved official or licensed public-law source integration.",
          link: "https://example.invalid/public-law/stub"
        }
      ],
      disclaimers: [
        "Public-law results are drafts for advocate review.",
        "No case files or private matter details are stored by this backend."
      ]
    };
  }
}
