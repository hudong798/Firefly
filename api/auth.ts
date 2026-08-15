// 管理员登录：校验密码，签发 HttpOnly 签名 Cookie
import { json, makeToken } from "./_lib";

export default async function handler(req: any, res: any) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return json(res, 405, { error: "Method Not Allowed" });
  }

  const adminPassword = process.env.ADMIN_PASSWORD;
  if (!adminPassword) {
    return json(res, 500, { error: "服务端未配置 ADMIN_PASSWORD" });
  }

  const { password } = req.body || {};
  if (typeof password !== "string" || password.length === 0) {
    return json(res, 400, { error: "请输入密码" });
  }
  if (password !== adminPassword) {
    return json(res, 401, { error: "密码错误" });
  }

  const token = makeToken();
  res.setHeader(
    "Set-Cookie",
    `wb_admin_token=${token}; HttpOnly; Path=/; SameSite=Lax; Max-Age=604800`,
  );
  return json(res, 200, { ok: true });
}
