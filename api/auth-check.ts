// 登录状态检查
export const config = { runtime: "nodejs" };

import { createHmac, timingSafeEqual } from "node:crypto";

function getSecret(): string {
  return process.env.ADMIN_PASSWORD || "";
}

function signToken(payload: string): string {
  return createHmac("sha256", getSecret()).update(payload).digest("base64url");
}

function verifyToken(token: string | undefined): boolean {
  if (!token) return false;
  const [b64, sig] = token.split(".");
  if (!b64 || !sig) return false;
  let payload: any;
  try {
    payload = JSON.parse(Buffer.from(b64, "base64url").toString("utf8"));
  } catch {
    return false;
  }
  if (
    !payload ||
    payload.role !== "admin" ||
    typeof payload.exp !== "number" ||
    payload.exp < Date.now()
  ) {
    return false;
  }
  const expected = signToken(b64);
  try {
    return timingSafeEqual(Buffer.from(sig), Buffer.from(expected));
  } catch {
    return false;
  }
}

function getCookieToken(req: any): string | undefined {
  const cookie: string | undefined = req.headers.cookie;
  if (!cookie) return undefined;
  for (const part of cookie.split(";")) {
    const idx = part.indexOf("=");
    if (idx < 0) continue;
    const key = part.slice(0, idx).trim();
    if (key === "wb_admin_token") return part.slice(idx + 1).trim();
  }
  return undefined;
}

export default async function handler(req: any, res: any) {
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({ error: "Method Not Allowed" });
  }
  const ok = verifyToken(getCookieToken(req));
  return res.status(200).json({ ok });
}
