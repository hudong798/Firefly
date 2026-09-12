-- 公开排名 RPC 函数（允许未登录用户查看排行榜）
-- 使用 SECURITY DEFINER 绕过 RLS 限制

-- 获取灵石排名
CREATE OR REPLACE FUNCTION get_public_coin_ranking(p_limit INT DEFAULT 10)
RETURNS TABLE (
  user_id UUID,
  username TEXT,
  coins INT,
  rank INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    w.user_id,
    p.username,
    w.coins,
    ROW_NUMBER() OVER (ORDER BY w.coins DESC)::INT AS rank
  FROM wallets w
  JOIN profiles p ON p.id = w.user_id
  ORDER BY w.coins DESC
  LIMIT p_limit;
END;
$$;

-- 获取境界排名
CREATE OR REPLACE FUNCTION get_public_realm_ranking(p_limit INT DEFAULT 10)
RETURNS TABLE (
  user_id UUID,
  username TEXT,
  qi INT,
  rank INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id AS user_id,
    p.username,
    p.qi,
    ROW_NUMBER() OVER (ORDER BY p.qi DESC)::INT AS rank
  FROM profiles p
  ORDER BY p.qi DESC
  LIMIT p_limit;
END;
$$;

-- 授予 anon 和 authenticated 角色执行权限
GRANT EXECUTE ON FUNCTION get_public_coin_ranking(INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_public_realm_ranking(INT) TO anon, authenticated;
