-- ============================================================
-- 说说上锁：固定密码（519931819）存 Supabase + 单条详情 RPC
-- 1. app_settings 存全局上锁密码的 bcrypt hash（前端不含明文）
-- 2. admin_insert_echo：勾选上锁即自动套用全局密码，无需每条设密码
-- 3. get_echo_detail(slug)：前台详情页按 slug 取单条（上锁行正文置空）
-- 幂等，可重复执行。
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. 全局设置表 + 说说上锁密码（519931819）bcrypt
CREATE TABLE IF NOT EXISTS public.app_settings (
  key text PRIMARY KEY,
  value text
);

INSERT INTO public.app_settings(key, value)
VALUES ('echo_lock_password_hash', extensions.crypt('519931819', extensions.gen_salt('bf')))
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 2. 重写发布 RPC：上锁时自动套用全局密码 hash（忽略传入的 p_lock_password）
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
    RAISE EXCEPTION 'echo admin auth failed';
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
      THEN (SELECT value FROM public.app_settings WHERE key = 'echo_lock_password_hash')
      ELSE NULL
    END
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_insert_echo(text, text, text, text, text, text, text[], text, boolean, text) TO anon, authenticated;

-- 已有上锁说说统一套用全局密码
UPDATE public.echoes
SET lock_password_hash = (SELECT value FROM public.app_settings WHERE key = 'echo_lock_password_hash')
WHERE is_locked = true;

-- 3. 单条说说详情 RPC
CREATE OR REPLACE FUNCTION public.get_echo_detail(p_slug text)
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
    CASE WHEN e.is_locked THEN NULL ELSE e.content END,
    e.mood,
    e.tags,
    e.status,
    e.created_at,
    e.is_locked,
    (e.content ~ '!\[[^\]]*\]\(') AS has_image
  FROM public.echoes e
  WHERE e.slug = p_slug AND e.status = 'published'
  LIMIT 1;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_echo_detail(text) TO anon, authenticated;

-- 自检
SELECT id, title, is_locked, (lock_password_hash IS NOT NULL) AS has_lock_pwd
FROM public.echoes
ORDER BY created_at DESC;
