import { NextResponse } from "next/server";
import { ensureSchema } from "@/lib/schema";
import { query } from "@/lib/db";
import { createSessionToken, sessionCookieOptions, verifySecret } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type DeviceRow = {
  id: string;
  pin_hash: string;
};

export async function POST(request: Request) {
  await ensureSchema();

  const body = await request.json().catch(() => ({}));
  const deviceId = body?.deviceId ? String(body.deviceId).trim() : "";
  const rawPin = body?.pin ? String(body.pin).trim() : "";
  const pin = rawPin.replace(/\D/g, "");

  if (!deviceId || !pin) {
    return NextResponse.json({ error: "deviceId and pin are required" }, { status: 400 });
  }

  const rows = await query<DeviceRow[]>(
    "SELECT id, pin_hash FROM devices WHERE id = ?",
    [deviceId],
  );

  const row = rows[0];
  if (!row) {
    return NextResponse.json({ error: "device not found" }, { status: 404 });
  }

  const ok = await verifySecret(pin, row.pin_hash);
  if (!ok) {
    return NextResponse.json({ error: "invalid pin" }, { status: 401 });
  }

  const token = createSessionToken(row.id);
  const response = NextResponse.json({ ok: true, deviceId: row.id });
  response.cookies.set("portal_session", token, sessionCookieOptions());

  return response;
}
