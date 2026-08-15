// 管理员登录：校验密码，签发 HttpOnly 签名 Cookie
// 显式指定 Node.js 运行时（node:crypto 不支持 Edge Runtime）
export const config = { runtime: "nodejs" };

import { createHmac, timingSafeEqual } from "node:crypto";

const TOKEN_TTL_MS = 7 * 24 * 3600 * 1000;

function getSecret(): string {
  return process.env.ADMIN_PASSWORD || "";
}

function signToken(payload: string): string {
  return createHmac("sha256", getSecret()).update(payload).digest("base64url");
}

function makeToken(): string {
  const payload = JSON.stringify({
    role: "admin",
    exp: Date.now() + TOKEN_TTL_MS,
  });
  const b64 = Buffer.from(payload).toString("base64url");
  return `${b64}.${signToken(b64)}`;
}

export default async function handler(req: any, res: any) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const adminPassword = process.env.ADMIN_PASSWORD;
  if (!adminPassword) {
    return res.status(500).json({ error: "服务端未配置 ADMIN_PASSWORD" });
  }

  const { password } = req.body || {};
  if (typeof password !== "string" || password.length === 0) {
    return res.status(400).json({ error: "请输入密码" });
  }
  if (password !== adminPassword) {
    return res.status(401).json({ error: "密码错误" });
  }

  const token = makeToken();
  res.setHeader(
    "Set-Cookie",
    `wb_admin_token=${token}; HttpOnly; Path=/; SameSite=Lax; Max-Age=604800`,
  );
  return res.status(200).json({ ok: true });
}
