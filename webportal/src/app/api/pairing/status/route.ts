import { NextResponse } from "next/server";
import { ensureSchema } from "@/lib/schema";
import { query } from "@/lib/db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type PairingRow = {
  id: string;
  expires_at: Date;
  claimed_at: Date | null;
  claimed_device_id: string | null;
};

export async function GET(request: Request) {
  await ensureSchema();

  const url = new URL(request.url);
  const pairingId = url.searchParams.get("pairingId")?.trim() ?? "";
  if (!pairingId) {
    return NextResponse.json({ error: "pairingId is required" }, { status: 400 });
  }

  const rows = await query<PairingRow[]>(
    "SELECT id, expires_at, claimed_at, claimed_device_id FROM pairing_sessions WHERE id = ?",
    [pairingId],
  );

  const row = rows[0];
  if (!row) {
    return NextResponse.json({ status: "missing" }, { status: 404 });
  }

  if (new Date(row.expires_at).getTime() < Date.now()) {
    return NextResponse.json({ status: "expired" }, { status: 410 });
  }

  if (row.claimed_device_id) {
    return NextResponse.json({
      status: "claimed",
      deviceId: row.claimed_device_id,
      claimedAt: row.claimed_at?.toISOString() ?? null,
    });
  }

  return NextResponse.json({ status: "pending" });
}
