import bcrypt from "bcryptjs";
import crypto from "crypto";
import { cookies } from "next/headers";

const TOKEN_TTL_SECONDS = 12 * 60 * 60;

const PIN_LENGTH = 8;

function getTokenSecret(): string {
  const secret = process.env.PORTAL_TOKEN_SECRET;
  if (!secret) {
    throw new Error("PORTAL_TOKEN_SECRET is not set");
  }
  return secret;
}

function getPinSecret(): string {
  const secret = process.env.PORTAL_PIN_SECRET;
  if (!secret) {
    throw new Error("PORTAL_PIN_SECRET is not set");
  }
  return secret;
}

function base64UrlEncode(value: string): string {
  return Buffer.from(value, "utf8")
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function base64UrlDecode(value: string): string {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const padLength = (4 - (padded.length % 4)) % 4;
  const paddedValue = padded + "=".repeat(padLength);
  return Buffer.from(paddedValue, "base64").toString("utf8");
}

function signPayload(payload: string): string {
  const signature = crypto
    .createHmac("sha256", getTokenSecret())
    .update(payload)
    .digest("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return signature;
}

export function createSessionToken(deviceId: string): string {
  const payload = {
    deviceId,
    exp: Date.now() + TOKEN_TTL_SECONDS * 1000,
  };
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signature = signPayload(encodedPayload);
  return `${encodedPayload}.${signature}`;
}

export function verifySessionToken(token: string): { deviceId: string } | null {
  const parts = token.split(".");
  if (parts.length != 2) {
    return null;
  }

  const [payloadPart, signaturePart] = parts;
  const expectedSignature = signPayload(payloadPart);

  const signatureBuffer = Buffer.from(signaturePart);
  const expectedBuffer = Buffer.from(expectedSignature);
  if (signatureBuffer.length !== expectedBuffer.length) {
    return null;
  }

  if (!crypto.timingSafeEqual(signatureBuffer, expectedBuffer)) {
    return null;
  }

  try {
    const payload = JSON.parse(base64UrlDecode(payloadPart)) as {
      deviceId?: string;
      exp?: number;
    };
    if (!payload.deviceId || !payload.exp) {
      return null;
    }
    if (Date.now() > payload.exp) {
      return null;
    }
    return { deviceId: payload.deviceId };
  } catch {
    return null;
  }
}

export async function getSessionFromCookies(): Promise<{ deviceId: string } | null> {
  const cookieStore = await cookies();
  const sessionCookie = cookieStore.get("portal_session");
  if (!sessionCookie?.value) {
    return null;
  }
  return verifySessionToken(sessionCookie.value);
}

export function getSessionFromRequest(request: Request): { deviceId: string } | null {
  const cookieHeader = request.headers.get("cookie") ?? "";
  const match = cookieHeader
    .split(";")
    .map((part) => part.trim())
    .find((part) => part.startsWith("portal_session="));

  if (!match) {
    return null;
  }

  const token = match.substring("portal_session=".length);
  return verifySessionToken(token);
}

export async function hashSecret(secret: string): Promise<string> {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(secret, salt);
}

export async function verifySecret(secret: string, hash: string): Promise<boolean> {
  return bcrypt.compare(secret, hash);
}

export function normalizePin(value: string): string {
  return value.replace(/\D/g, "");
}

export function isValidPin(pin: string): boolean {
  return pin.length === PIN_LENGTH;
}

export function buildPinLookup(pin: string): string {
  return crypto
    .createHmac("sha256", getPinSecret())
    .update(pin)
    .digest("hex");
}

export function sessionCookieOptions({ secure }: { secure: boolean }) {
  return {
    httpOnly: true,
    sameSite: "lax" as const,
    secure,
    path: "/",
    maxAge: TOKEN_TTL_SECONDS,
  };
}
