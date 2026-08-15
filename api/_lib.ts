// 管理后台共享认证逻辑（HMAC 签名令牌）
// Vercel 约定：api/ 目录下以下划线开头的文件不会被部署为独立接口
import { createHmac, timingSafeEqual } from "node:crypto";

const TOKEN_TTL_MS = 7 * 24 * 3600 * 1000; // 7 天

function getSecret(): string {
  return process.env.ADMIN_PASSWORD || "";
}

export function signToken(payload: string): string {
  return createHmac("sha256", getSecret()).update(payload).digest("base64url");
}

export function makeToken(): string {
  const payload = JSON.stringify({
    role: "admin",
    exp: Date.now() + TOKEN_TTL_MS,
  });
  const b64 = Buffer.from(payload).toString("base64url");
  return `${b64}.${signToken(b64)}`;
}

export function verifyToken(token: string | undefined): boolean {
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

export function getCookieToken(req: any): string | undefined {
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

export function json(res: any, status: number, data: any) {
  return res.status(status).json(data);
}
