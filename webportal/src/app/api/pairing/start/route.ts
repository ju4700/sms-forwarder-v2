import crypto from "crypto";
import { NextResponse } from "next/server";
import { execute } from "@/lib/db";
import { ensureSchema } from "@/lib/schema";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function resolvePairingError(error: unknown): string {
  if (error instanceof Error && error.message.includes("DATABASE_URL is not set")) {
    return "Database not configured. Set DATABASE_URL in webportal/.env.";
  }

  if (typeof error === "object" && error) {
    const code = "code" in error && typeof error.code === "string" ? error.code : "";
    if (code === "ER_BAD_DB_ERROR") {
      return "Database does not exist. Create it and try again.";
    }
    if (code === "ER_ACCESS_DENIED_ERROR" || code === "ER_DBACCESS_DENIED_ERROR") {
      return "Database credentials are invalid.";
    }
    if (code === "ECONNREFUSED") {
      return "Database connection refused. Check the host and port.";
    }
    if (code === "ENOTFOUND") {
      return "Database host not found.";
    }
  }

  return "Unable to create a pairing session.";
}

export async function POST() {
  try {
    await ensureSchema();

    const pairingId = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await execute(
      "INSERT INTO pairing_sessions (id, expires_at) VALUES (?, ?)",
      [pairingId, expiresAt],
    );

    const qrPayload = JSON.stringify({
      type: "sms-portal",
      pairingId,
    });

    return NextResponse.json({
      pairingId,
      expiresAt: expiresAt.toISOString(),
      qrPayload,
    });
  } catch (error) {
    console.error("Failed to start pairing session", error);
    return NextResponse.json({ error: resolvePairingError(error) }, { status: 500 });
  }
}
