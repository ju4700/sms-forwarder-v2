import { NextResponse } from "next/server";
import { ensureSchema } from "@/lib/schema";
import { execute, query } from "@/lib/db";
import { verifySecret } from "@/lib/auth";
import { cleanupOldMessages } from "@/lib/retention";
import { publishMessage, publishStatus } from "@/lib/events";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type DeviceRow = {
  id: string;
  secret_hash: string;
};

function parseTimestamp(value: unknown): Date | null {
  if (typeof value == "number") {
    return new Date(value);
  }
  if (typeof value == "string") {
    const parsed = Number(value);
    if (!Number.isNaN(parsed)) {
      return new Date(parsed);
    }
    const date = new Date(value);
    if (!Number.isNaN(date.getTime())) {
      return date;
    }
  }
  return null;
}

export async function POST(request: Request) {
  await ensureSchema();

  const deviceId = request.headers.get("x-device-id")?.trim() ?? "";
  const deviceSecret = request.headers.get("x-device-secret")?.trim() ?? "";

  if (!deviceId || !deviceSecret) {
    return NextResponse.json({ error: "missing device headers" }, { status: 401 });
  }

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

  const body = await request.json().catch(() => ({}));
  const address = typeof body.address == "string" ? body.address.trim() : "";
  const messageBody = typeof body.body == "string" ? body.body.trim() : "";
  const direction = body.direction == "outgoing" ? "outgoing" : "incoming";
  const sentAt = parseTimestamp(body.timestamp) ?? new Date();

  if (!address || !messageBody) {
    return NextResponse.json({ error: "address and body are required" }, { status: 400 });
  }

  await execute(
    "INSERT INTO messages (device_id, address, body, direction, sent_at) VALUES (?, ?, ?, ?, ?)",
    [deviceId, address, messageBody, direction, sentAt],
  );

  await execute("UPDATE devices SET last_seen_at = ? WHERE id = ?", [new Date(), deviceId]);

  publishMessage(deviceId, {
    address,
    body: messageBody,
    direction,
    sentAt: sentAt.toISOString(),
  });

  publishStatus(deviceId, { lastSeenAt: new Date().toISOString() });
  await cleanupOldMessages();

  return NextResponse.json({ ok: true }, { status: 201 });
}
