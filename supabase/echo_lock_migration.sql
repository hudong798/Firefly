-- ============================================================
-- 说说（echoes）「上锁保护」+「有图只显标题」迁移
-- 设计要点：
--   1. echoes 加 is_locked / lock_password_hash（bcrypt，永不下发前端）
--   2. anon 直接 select 时，上锁行整行不可见（RLS 排除）
--   3. 前台列表走 list_public_echoes()：返回元数据，上锁行 content=NULL
--   4. 解锁走 unlock_echo(id, pwd)：数据库端 bcrypt 校验通过才返回正文
--   5. 后台列表走 admin_list_echoes(uid, pwd)：先校验 echo 管理员再返回正文
--   6. 发布走 admin_insert_echo(...)：扩展两个参数（上锁标志 + 上锁密码）
-- 幂等，可重复执行。
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. 加列
ALTER TABLE public.echoes
  ADD COLUMN IF NOT EXISTS is_locked boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS lock_password_hash text;

-- 2. RLS：anon 直接查询时，上锁说说整行不可见（连标题都不返回）
DROP POLICY IF EXISTS "echoes: published readable by anon" ON public.echoes;
CREATE POLICY "echoes: published readable by anon"
  ON public.echoes FOR SELECT
  TO anon
  USING (status = 'published' AND is_locked = false);

-- 3. 前台公开列表 RPC（SECURITY DEFINER 绕过 RLS）
--    返回所有 published 说说元数据；上锁行正文置 NULL，并带 has_image 标志
CREATE OR REPLACE FUNCTION public.list_public_echoes()
RETURNS TABLE (
  id uuid,
  slug text,
  title text,
  content text,
  mood text,
  tags text[],
  status text,
  created_at timestamptz,
  is_locked boolean,
  has_image boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.slug,
    e.title,
    CASE WHEN e.is_locked THEN NULL ELSE e.content END AS content,
    e.mood,
    e.tags,
    e.status,
    e.created_at,
    e.is_locked,
    (e.content ~ '!\[[^\]]*\]\(') AS has_image
  FROM public.echoes e
  WHERE e.status = 'published'
  ORDER BY e.created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_public_echoes() TO anon, authenticated;

-- 4. 解锁说说 RPC：数据库端 bcrypt 比对上锁密码，正确才返回正文
CREATE OR REPLACE FUNCTION public.unlock_echo(
  p_echo_id uuid,
  p_password text
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_hash text;
  v_content text;
  v_status text;
BEGIN
  SELECT e.lock_password_hash, e.content, e.status
    INTO v_hash, v_content, v_status
  FROM public.echoes e
  WHERE e.id = p_echo_id;

  IF v_status IS NULL OR v_status <> 'published' THEN
    RETURN NULL;
  END IF;

  -- 未设密码的上锁行，直接放行
  IF v_hash IS NULL OR v_hash = '' THEN
    RETURN v_content;
  END IF;

  IF v_hash = extensions.crypt(p_password, v_hash) THEN
    RETURN v_content;
  END IF;

  RETURN NULL;
END;
$$;
GRANT EXECUTE ON FUNCTION public.unlock_echo(uuid, text) TO anon, authenticated;

-- 5. 后台说说列表 RPC：先校验 echo 模块管理员，再返回全部（含正文，不含密码哈希）
CREATE OR REPLACE FUNCTION public.admin_list_echoes(
  p_username text,
  p_password text
)
RETURNS TABLE (
  id uuid,
  slug text,
  title text,
  content text,
  mood text,
  tags text[],
  status text,
  created_at timestamptz,
  is_locked boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NOT public.verify_admin_credentials('echo', p_username, p_password) THEN
    RAISE EXCEPTION '说说管理员验证失败';
  END IF;

  RETURN QUERY
  SELECT e.id, e.slug, e.title, e.content, e.mood, e.tags, e.status, e.created_at, e.is_locked
  FROM public.echoes e
  ORDER BY e.created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_list_echoes(text, text) TO anon, authenticated;

-- 6. 发布说说 RPC（扩展签名，加上锁标志 + 上锁密码；bcrypt 存储）
--    注意：Postgres 函数按参数重载，旧的 8 参数版本保留但前端改调此 10 参数版本
CREATE OR REPLACE FUNCTION public.admin_insert_echo(
  p_username text,
  p_password text,
  p_slug text,
  p_title text,
  p_content text,
  p_mood text,
  p_tags text[],
  p_status text,
  p_is_locked boolean DEFAULT false,
  p_lock_password text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NOT public.verify_admin_credentials('echo', p_username, p_password) THEN
    RAISE EXCEPTION '说说管理员验证失败';
  END IF;

  INSERT INTO public.echoes (
    slug, title, content, mood, tags, status, is_locked, lock_password_hash
  ) VALUES (
    p_slug,
    p_title,
    p_content,
    p_mood,
    COALESCE(p_tags, '{}'),
    COALESCE(p_status, 'published'),
    COALESCE(p_is_locked, false),
    CASE
      WHEN COALESCE(p_is_locked, false)
           AND p_lock_password IS NOT NULL
           AND p_lock_password <> ''
      THEN extensions.crypt(p_lock_password, extensions.gen_salt('bf'))
      ELSE NULL
    END
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_insert_echo(text, text, text, text, text, text, text[], text, boolean, text) TO anon, authenticated;

-- 7. 自检：当前说说上锁情况（不返回密码哈希）
SELECT id, title, is_locked, (lock_password_hash IS NOT NULL) AS has_lock_pwd
FROM public.echoes
ORDER BY created_at DESC;
