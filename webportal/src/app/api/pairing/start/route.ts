import crypto from "crypto";
import { NextResponse } from "next/server";
import { execute } from "@/lib/db";
import { ensureSchema } from "@/lib/schema";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST() {
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
}
