import { NextResponse } from "next/server";
import { ensureSchema } from "@/lib/schema";
import { execute, query } from "@/lib/db";
import { verifySecret } from "@/lib/auth";
import { cleanupOldMessages } from "@/lib/retention";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type DeviceRow = {
  id: string;
  secret_hash: string;
};

type BulkMessage = {
  address: string;
  body: string;
  direction: "incoming" | "outgoing";
  timestamp: number | string;
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

  const payload = await request.json().catch(() => ({}));
  const messages = Array.isArray(payload.messages) ? payload.messages : [];
  if (messages.length == 0) {
    return NextResponse.json({ error: "messages array is required" }, { status: 400 });
  }

  const maxBatch = 500;
  const slice = messages.slice(0, maxBatch) as BulkMessage[];

  for (const message of slice) {
    const address = typeof message.address == "string" ? message.address.trim() : "";
    const body = typeof message.body == "string" ? message.body.trim() : "";
    if (!address || !body) {
      continue;
    }

    const direction = message.direction == "outgoing" ? "outgoing" : "incoming";
    const sentAt = parseTimestamp(message.timestamp) ?? new Date();

    await execute(
      "INSERT INTO messages (device_id, address, body, direction, sent_at) VALUES (?, ?, ?, ?, ?)",
      [deviceId, address, body, direction, sentAt],
    );
  }

  await execute("UPDATE devices SET last_seen_at = ? WHERE id = ?", [new Date(), deviceId]);
  await cleanupOldMessages();

  return NextResponse.json({ ok: true, inserted: slice.length });
}
