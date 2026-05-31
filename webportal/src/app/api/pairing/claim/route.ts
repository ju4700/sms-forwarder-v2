import crypto from "crypto";
import { NextResponse } from "next/server";
import { ensureSchema } from "@/lib/schema";
import { execute, query } from "@/lib/db";
import { buildPinLookup, hashSecret, isValidPin, normalizePin, verifySecret } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type PairingRow = {
  id: string;
  expires_at: Date;
  claimed_device_id: string | null;
};

type DeviceRow = {
  id: string;
  secret_hash: string;
};

function generatePin(): string {
  const value = crypto.randomInt(0, 100000000);
  return value.toString().padStart(8, "0");
}

async function generateUniquePin(): Promise<{ pin: string; pinLookup: string }> {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const pin = generatePin();
    const normalized = normalizePin(pin);
    if (!isValidPin(normalized)) {
      continue;
    }
    const pinLookup = buildPinLookup(normalized);
    const existing = await query<{ id: string }[]>(
      "SELECT id FROM devices WHERE pin_lookup = ?",
      [pinLookup],
    );
    if (existing.length === 0) {
      return { pin: normalized, pinLookup };
    }
  }

  throw new Error("Unable to generate a unique PIN.");
}

export async function POST(request: Request) {
  await ensureSchema();

  const body = await request.json().catch(() => ({}));
  const pairingId = typeof body.pairingId == "string" ? body.pairingId.trim() : "";
  const requestedDeviceId = body?.deviceId ? String(body.deviceId).trim() : "";
  const requestedSecret = body?.deviceSecret ? String(body.deviceSecret).trim() : "";

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

  const useExisting = requestedDeviceId && requestedSecret;
  let deviceId = requestedDeviceId;
  let deviceSecret = requestedSecret;

  if (useExisting) {
    const devices = await query<DeviceRow[]>(
      "SELECT id, secret_hash FROM devices WHERE id = ?",
      [deviceId],
    );
    const device = devices[0];
    if (!device) {
      return NextResponse.json({ error: "device not found" }, { status: 404 });
    }

    const ok = await verifySecret(deviceSecret, device.secret_hash);
    if (!ok) {
      return NextResponse.json({ error: "invalid device secret" }, { status: 401 });
    }
  } else {
    deviceId = crypto.randomUUID();
  }

  const { pin, pinLookup } = await generateUniquePin();
  const nextSecret = crypto.randomBytes(24).toString("base64url");
  const [secretHash, pinHash] = await Promise.all([
    hashSecret(nextSecret),
    hashSecret(pin),
  ]);

  if (useExisting) {
    await execute(
      "UPDATE devices SET secret_hash = ?, pin_hash = ?, pin_lookup = ?, pin_updated_at = ?, last_seen_at = ? WHERE id = ?",
      [secretHash, pinHash, pinLookup, new Date(), new Date(), deviceId],
    );
    deviceSecret = nextSecret;
  } else {
    deviceSecret = nextSecret;
    await execute(
      "INSERT INTO devices (id, secret_hash, pin_hash, pin_lookup, last_seen_at, pin_updated_at) VALUES (?, ?, ?, ?, ?, ?)",
      [deviceId, secretHash, pinHash, pinLookup, new Date(), new Date()],
    );
  }

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
