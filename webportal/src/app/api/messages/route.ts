import { NextResponse } from "next/server";
import { ensureSchema } from "@/lib/schema";
import { query } from "@/lib/db";
import { getSessionFromRequest } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type MessageRow = {
  id: number;
  address: string;
  body: string;
  direction: "incoming" | "outgoing";
  sent_at: Date;
};

export async function GET(request: Request) {
  await ensureSchema();

  const session = getSessionFromRequest(request);
  if (!session) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const url = new URL(request.url);
  const deviceId = url.searchParams.get("deviceId")?.trim() ?? "";
  const limit = Math.min(Number(url.searchParams.get("limit") ?? 100), 500);

  if (!deviceId) {
    return NextResponse.json({ error: "deviceId is required" }, { status: 400 });
  }

  if (session.deviceId != deviceId) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }

  const rows = await query<MessageRow[]>(
    "SELECT id, address, body, direction, sent_at FROM messages WHERE device_id = ? ORDER BY sent_at DESC LIMIT ?",
    [deviceId, limit],
  );

  const messages = rows.map((row) => ({
    id: row.id,
    address: row.address,
    body: row.body,
    direction: row.direction,
    sentAt: row.sent_at.toISOString(),
  }));

  return NextResponse.json({ messages });
}
