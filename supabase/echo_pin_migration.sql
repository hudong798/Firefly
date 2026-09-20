-- ============================================================
-- 说说（echoes）「置顶」迁移
--   1. echoes 加 pinned（默认 false）
--   2. 前台 list_public_echoes 返回 pinned，并按 pinned 优先排序
--   3. 后台 admin_list_echoes 返回 pinned
--   4. 发布 admin_insert_echo 增加 p_pinned 参数
--   5. 新增 admin_toggle_pin_echo(uid, pwd, id) 切换置顶
-- 幂等，可重复执行。
-- ============================================================

-- 1. 加列
ALTER TABLE public.echoes
  ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false;

-- 2. 前台公开列表：返回 pinned，置顶优先
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
  has_image boolean,
  pinned boolean
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
    (e.content ~ '!\[[^\]]*\]\(') AS has_image,
    e.pinned
  FROM public.echoes e
  WHERE e.status = 'published'
  ORDER BY e.pinned DESC, e.created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_public_echoes() TO anon, authenticated;

-- 3. 后台列表：返回 pinned
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
  is_locked boolean,
  pinned boolean
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
  SELECT e.id, e.slug, e.title, e.content, e.mood, e.tags, e.status, e.created_at, e.is_locked, e.pinned
  FROM public.echoes e
  ORDER BY e.pinned DESC, e.created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_list_echoes(text, text) TO anon, authenticated;

-- 4. 发布说说：增加 p_pinned
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
  p_lock_password text DEFAULT NULL,
  p_pinned boolean DEFAULT false
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
    slug, title, content, mood, tags, status, is_locked, lock_password_hash, pinned
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
    END,
    COALESCE(p_pinned, false)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_insert_echo(text, text, text, text, text, text, text[], text, boolean, text, boolean) TO anon, authenticated;

-- 5. 切换置顶
CREATE OR REPLACE FUNCTION public.admin_toggle_pin_echo(
  p_username text,
  p_password text,
  p_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NOT public.verify_admin_credentials('echo', p_username, p_password) THEN
    RAISE EXCEPTION '说说管理员验证失败';
  END IF;

  UPDATE public.echoes
    SET pinned = NOT pinned
  WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_toggle_pin_echo(text, text, uuid) TO anon, authenticated;

-- 6. 自检
SELECT id, title, pinned
FROM public.echoes
ORDER BY pinned DESC, created_at DESC;
