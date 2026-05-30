import { NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { publishStatus, ssePing, subscribe } from "@/lib/events";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const session = getSessionFromRequest(request);
  if (!session) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const url = new URL(request.url);
  const deviceId = url.searchParams.get("deviceId")?.trim() ?? "";

  if (!deviceId) {
    return NextResponse.json({ error: "deviceId is required" }, { status: 400 });
  }

  if (session.deviceId != deviceId) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }

  let unsubscribe: (() => void) | null = null;
  let keepAlive: ReturnType<typeof setInterval> | null = null;

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      unsubscribe = subscribe(deviceId, controller);
      publishStatus(deviceId, { status: "connected", at: new Date().toISOString() });

      keepAlive = setInterval(() => ssePing(controller), 20000);
    },
    cancel() {
      if (keepAlive) {
        clearInterval(keepAlive);
      }
      if (unsubscribe) {
        unsubscribe();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
    },
  });
}
