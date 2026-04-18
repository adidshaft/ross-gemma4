export type DataClassification =
  | "account_token"
  | "billing_event"
  | "no_case_data"
  | "sanitized_public_query";

export interface AuditEvent {
  timestamp: string;
  level: "info" | "warn" | "error";
  event: string;
  route?: string | undefined;
  requestId?: string | undefined;
  classification?: DataClassification | undefined;
  statusCode?: number | undefined;
  metadata?: Record<string, string | number | boolean | null> | undefined;
}

export interface AuditLogger {
  info(event: Omit<AuditEvent, "level" | "timestamp">): void;
  warn(event: Omit<AuditEvent, "level" | "timestamp">): void;
  error(event: Omit<AuditEvent, "level" | "timestamp">): void;
}

interface CreateAuditLoggerOptions {
  sink?: AuditEvent[] | undefined;
  emitConsole?: boolean | undefined;
}

function normalizeMetadata(
  metadata: AuditEvent["metadata"] | undefined
): AuditEvent["metadata"] | undefined {
  if (!metadata) {
    return undefined;
  }

  const normalizedEntries = Object.entries(metadata).map(([key, value]) => {
    if (typeof value === "string") {
      return [key, value.slice(0, 120)] as const;
    }

    return [key, value] as const;
  });

  return Object.fromEntries(normalizedEntries);
}

export function createAuditLogger(options: CreateAuditLoggerOptions = {}): AuditLogger {
  const sink = options.sink;
  const emitConsole = options.emitConsole ?? true;

  const write = (level: AuditEvent["level"], event: Omit<AuditEvent, "level" | "timestamp">) => {
    const entry: AuditEvent = {
      ...event,
      metadata: normalizeMetadata(event.metadata),
      level,
      timestamp: new Date().toISOString()
    };

    sink?.push(entry);

    if (emitConsole) {
      const printer = level === "error" ? console.error : console.log;
      printer(JSON.stringify(entry));
    }
  };

  return {
    info: (event) => write("info", event),
    warn: (event) => write("warn", event),
    error: (event) => write("error", event)
  };
}
