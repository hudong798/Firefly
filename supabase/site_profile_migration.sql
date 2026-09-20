-- ============================================================
-- 个人资料（关于我）在线编辑：site_profile 单行表
-- 复用说说管理员账号（verify_admin_credentials('echo', uid, pwd)）
-- ============================================================

create table if not exists public.site_profile (
  id           int primary key default 1 check (id = 1),
  name         text,
  tagline      text,
  tags         text[],
  manifesto    text[],          -- 宣言若干行
  about_text   text,            -- 关于我正文（纯文本，换行分段）
  avatar_url   text,
  updated_at   timestamptz default now()
);

-- 关闭 RLS：所有读写都走 RPC，前端只持 anon key
alter table public.site_profile enable row level security;

-- 公开读取（前台 about 页面用）
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
      'updated_at', sp.updated_at
    ) from public.site_profile sp where sp.id = 1),
    'null'::jsonb
  );
$$;

grant execute on function public.get_site_profile() to anon, authenticated;

-- 管理员保存（复用说说账号）
create or replace function public.admin_save_site_profile(
  p_uid        text,
  p_pwd        text,
  p_name       text,
  p_tagline    text,
  p_tags       text[],
  p_manifesto text[],
  p_about_text text,
  p_avatar_url text
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
    id, name, tagline, tags, manifesto, about_text, avatar_url, updated_at
  ) values (
    1, p_name, p_tagline, p_tags, p_manifesto, p_about_text, p_avatar_url, now()
  )
  on conflict (id) do update set
    name = excluded.name,
    tagline = excluded.tagline,
    tags = excluded.tags,
    manifesto = excluded.manifesto,
    about_text = excluded.about_text,
    avatar_url = excluded.avatar_url,
    updated_at = now();
end;
$$;

grant execute on function public.admin_save_site_profile(text, text, text, text, text[], text[], text, text) to anon, authenticated;
