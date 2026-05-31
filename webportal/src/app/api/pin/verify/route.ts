import { NextResponse } from "next/server";
import { ensureSchema } from "@/lib/schema";
import { execute, query } from "@/lib/db";
import {
  buildPinLookup,
  createSessionToken,
  isValidPin,
  normalizePin,
  sessionCookieOptions,
  verifySecret,
} from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type DeviceRow = {
  id: string;
  pin_hash: string;
  pin_lookup?: string | null;
};

export async function POST(request: Request) {
  await ensureSchema();

  const body = await request.json().catch(() => ({}));
  const rawPin = body?.pin ? String(body.pin).trim() : "";
  const pin = normalizePin(rawPin);

  if (!pin) {
    return NextResponse.json({ error: "pin is required" }, { status: 400 });
  }

  if (!isValidPin(pin)) {
    return NextResponse.json({ error: "pin must be 8 digits" }, { status: 400 });
  }

  const pinLookup = buildPinLookup(pin);
  let rows = await query<DeviceRow[]>(
    "SELECT id, pin_hash, pin_lookup FROM devices WHERE pin_lookup = ?",
    [pinLookup],
  );

  let row = rows[0];
  if (!row) {
    const fallbackRows = await query<DeviceRow[]>(
      "SELECT id, pin_hash, pin_lookup FROM devices WHERE pin_lookup IS NULL OR pin_lookup = ''",
    );

    for (const candidate of fallbackRows) {
      try {
        const ok = await verifySecret(pin, candidate.pin_hash);
        if (ok) {
          row = candidate;
          break;
        }
      } catch {
        continue;
      }
    }
  }

  if (!row || !row.pin_hash) {
    return NextResponse.json({ error: "invalid pin" }, { status: 401 });
  }

  let ok = false;
  try {
    ok = await verifySecret(pin, row.pin_hash);
  } catch {
    return NextResponse.json({ error: "verification failed" }, { status: 500 });
  }

  if (!ok) {
    return NextResponse.json({ error: "invalid pin" }, { status: 401 });
  }

  if (!row.pin_lookup) {
    try {
      await execute(
        "UPDATE devices SET pin_lookup = ?, pin_updated_at = ? WHERE id = ?",
        [pinLookup, new Date(), row.id],
      );
    } catch {
      // Ignore lookup update failures to avoid blocking a valid unlock.
    }
  }

  const token = createSessionToken(row.id);
  const response = NextResponse.json({ ok: true, deviceId: row.id });
  response.cookies.set("portal_session", token, sessionCookieOptions());

  return response;
}
