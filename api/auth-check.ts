// 登录状态检查
import { json, getCookieToken, verifyToken } from "./_lib";

export default async function handler(req: any, res: any) {
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return json(res, 405, { error: "Method Not Allowed" });
  }
  const ok = verifyToken(getCookieToken(req));
  return json(res, 200, { ok });
}
