-- 说说编辑功能：admin_update_echo
-- 校验说说管理员账号后，按 p_id 更新说说字段；上锁状态变化时同步全局上锁密码 hash
CREATE OR REPLACE FUNCTION public.admin_update_echo(
  p_id uuid,
  p_username text,
  p_password text,
  p_slug text,
  p_title text,
  p_content text,
  p_mood text,
  p_tags text[],
  p_status text,
  p_is_locked boolean DEFAULT false,
  p_pinned boolean DEFAULT false,
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

  UPDATE public.echoes
  SET
    slug = p_slug,
    title = p_title,
    content = p_content,
    mood = p_mood,
    tags = COALESCE(p_tags, '{}'),
    status = COALESCE(p_status, 'published'),
    is_locked = COALESCE(p_is_locked, false),
    pinned = COALESCE(p_pinned, false),
    lock_password_hash = CASE
      WHEN COALESCE(p_is_locked, false) THEN
        (SELECT value FROM public.app_settings WHERE key = 'echo_lock_password_hash')
      ELSE lock_password_hash
    END,
    updated_at = now()
  WHERE id = p_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_echo(uuid, text, text, text, text, text, text, text[], text, boolean, boolean, text) TO anon, authenticated;
