import { NextResponse } from "next/server";
import { sessionCookieOptions } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const response = NextResponse.json({ ok: true });
  const forwardedProto = request.headers.get("x-forwarded-proto");
  let isSecure = false;
  if (forwardedProto) {
    isSecure = forwardedProto.toLowerCase().includes("https");
  } else {
    try {
      isSecure = new URL(request.url).protocol === "https:";
    } catch {
      isSecure = false;
    }
  }

  response.cookies.set(
    "portal_session",
    "",
    {
      ...sessionCookieOptions({ secure: isSecure }),
      maxAge: 0,
    },
  );

  return response;
}
