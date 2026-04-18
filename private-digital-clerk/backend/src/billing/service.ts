import type { RuntimeEnv } from "../security/env.js";
import { createId } from "../utils/ids.js";
import { AppError } from "../utils/http.js";
import { verifyStubSignature } from "../utils/signing.js";

export class BillingService {
  constructor(private readonly env: RuntimeEnv) {}

  handleStripeWebhook(body: unknown, signature: string | undefined) {
    const verified = verifyStubSignature(body, signature, this.env.stripeWebhookSecret);

    if (!verified) {
      throw new AppError(401, "invalid_webhook_signature", "Stripe webhook signature verification failed.");
    }

    const event = this.extractEvent(body, "stripe_evt", "stripe");

    return {
      received: true,
      provider: "stripe",
      verification: this.env.stripeWebhookSecret ? "verified" : "stub_unverified",
      ...event
    };
  }

  handleRazorpayWebhook(body: unknown, signature: string | undefined) {
    const verified = verifyStubSignature(body, signature, this.env.razorpayWebhookSecret);

    if (!verified) {
      throw new AppError(401, "invalid_webhook_signature", "Razorpay webhook signature verification failed.");
    }

    const event = this.extractEvent(body, "rzp_evt", "razorpay");

    return {
      received: true,
      provider: "razorpay",
      verification: this.env.razorpayWebhookSecret ? "verified" : "stub_unverified",
      ...event
    };
  }

  private extractEvent(body: unknown, prefix: string, fallbackType: string) {
    if (body && typeof body === "object") {
      const candidate = body as Record<string, unknown>;

      return {
        eventId:
          (typeof candidate.id === "string" && candidate.id) ||
          (typeof candidate.event === "string" && candidate.event) ||
          createId(prefix),
        eventType:
          (typeof candidate.type === "string" && candidate.type) ||
          (typeof candidate.event === "string" && candidate.event) ||
          fallbackType
      };
    }

    return {
      eventId: createId(prefix),
      eventType: fallbackType
    };
  }
}
