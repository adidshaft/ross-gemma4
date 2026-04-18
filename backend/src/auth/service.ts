import { addMinutes } from "./time.js";
import { createId } from "../utils/ids.js";
import { AppError } from "../utils/http.js";
import { hashForAudit } from "../utils/signing.js";
import type { RuntimeEnv } from "../security/env.js";

export interface StartOtpInput {
  phoneNumber: string;
  channel: "sms" | "whatsapp";
}

export interface VerifyOtpInput {
  phoneNumber: string;
  verificationId: string;
  otpCode: string;
}

function maskPhoneNumber(phoneNumber: string): string {
  const tail = phoneNumber.slice(-2);
  return `***${tail}`;
}

export class AuthService {
  constructor(private readonly env: RuntimeEnv) {}

  startOtp(input: StartOtpInput) {
    return {
      verificationId: createId("otp"),
      channel: input.channel,
      expiresInSeconds: 300,
      resendAfterSeconds: 30,
      deliveryHint: maskPhoneNumber(input.phoneNumber),
      developmentOtpHint: this.env.isProduction ? undefined : this.env.otpStubCode
    };
  }

  verifyOtp(input: VerifyOtpInput) {
    if (input.otpCode !== this.env.otpStubCode) {
      throw new AppError(401, "invalid_otp_code", "OTP verification failed.");
    }

    const subjectHash = hashForAudit(`${input.phoneNumber}:${input.verificationId}`);

    return {
      accountToken: `acct_${createId("token").slice(-24)}`,
      refreshToken: createId("refresh"),
      tokenType: "Bearer",
      subject: `advocate_${subjectHash}`,
      expiresAt: addMinutes(60),
      accountBoundary: "no_case_data"
    };
  }
}
