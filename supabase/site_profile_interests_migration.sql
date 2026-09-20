-- ============================================================
-- 个人资料：增加 兴趣信号(interests) 与 关于小站介绍(freex_intro)
-- ============================================================

alter table public.site_profile
  add column if not exists interests jsonb,
  add column if not exists freex_intro text;

-- 公开读取
create or replace function public.get_site_profile()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select jsonb_build_object(
      'name', sp.name,
      'tagline', sp.tagline,
      'tags', sp.tags,
      'manifesto', sp.manifesto,
      'about_text', sp.about_text,
      'avatar_url', sp.avatar_url,
      'interests', sp.interests,
      'freex_intro', sp.freex_intro,
      'updated_at', sp.updated_at
    ) from public.site_profile sp where sp.id = 1),
    'null'::jsonb
  );
$$;

grant execute on function public.get_site_profile() to anon, authenticated;

-- 管理员保存
create or replace function public.admin_save_site_profile(
  p_uid        text,
  p_pwd        text,
  p_name       text,
  p_tagline    text,
  p_tags       text[],
  p_manifesto text[],
  p_about_text text,
  p_avatar_url text,
  p_interests  jsonb default null,
  p_freex_intro text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.verify_admin_credentials('echo', p_uid, p_pwd) then
    raise exception '账号或密码错误';
  end if;

  insert into public.site_profile (
    id, name, tagline, tags, manifesto, about_text, avatar_url, interests, freex_intro, updated_at
  ) values (
    1, p_name, p_tagline, p_tags, p_manifesto, p_about_text, p_avatar_url, p_interests, p_freex_intro, now()
  )
  on conflict (id) do update set
    name = excluded.name,
    tagline = excluded.tagline,
    tags = excluded.tags,
    manifesto = excluded.manifesto,
    about_text = excluded.about_text,
    avatar_url = excluded.avatar_url,
    interests = excluded.interests,
    freex_intro = excluded.freex_intro,
    updated_at = now();
end;
$$;

grant execute on function public.admin_save_site_profile(text, text, text, text, text[], text[], text, text, jsonb, text) to anon, authenticated;
