import crypto from "crypto";
import { NextResponse } from "next/server";
import { ensureSchema } from "@/lib/schema";
import { execute, query } from "@/lib/db";
import { hashSecret } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type PairingRow = {
  id: string;
  expires_at: Date;
  claimed_device_id: string | null;
};

function generatePin(): string {
  const value = Math.floor(100000 + Math.random() * 900000);
  return value.toString();
}

export async function POST(request: Request) {
  await ensureSchema();

  const body = await request.json().catch(() => ({}));
  const pairingId = typeof body.pairingId == "string" ? body.pairingId.trim() : "";

  if (!pairingId) {
    return NextResponse.json({ error: "pairingId is required" }, { status: 400 });
  }

  const rows = await query<PairingRow[]>(
    "SELECT id, expires_at, claimed_device_id FROM pairing_sessions WHERE id = ?",
    [pairingId],
  );

  const row = rows[0];
  if (!row) {
    return NextResponse.json({ error: "pairing session not found" }, { status: 404 });
  }

  if (row.claimed_device_id) {
    return NextResponse.json({ error: "pairing already claimed" }, { status: 409 });
  }

  if (new Date(row.expires_at).getTime() < Date.now()) {
    return NextResponse.json({ error: "pairing expired" }, { status: 410 });
  }

  const deviceId = crypto.randomUUID();
  const deviceSecret = crypto.randomBytes(24).toString("base64url");
  const pin = generatePin();

  const [secretHash, pinHash] = await Promise.all([
    hashSecret(deviceSecret),
    hashSecret(pin),
  ]);

  await execute(
    "INSERT INTO devices (id, secret_hash, pin_hash, last_seen_at) VALUES (?, ?, ?, ?)",
    [deviceId, secretHash, pinHash, new Date()],
  );

  await execute(
    "UPDATE pairing_sessions SET claimed_device_id = ?, claimed_at = ? WHERE id = ?",
    [deviceId, new Date(), pairingId],
  );

  return NextResponse.json({
    deviceId,
    deviceSecret,
    pin,
  });
}
