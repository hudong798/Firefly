-- ============================================================
-- FreeX 个人数字宇宙 — Supabase 数据库 Schema
-- 表：echoes / travels / archives / comments / ai_tools
-- 安全：启用 RLS，公开内容允许 SELECT，管理操作需 Auth
-- 执行方式：在 Supabase Dashboard → SQL Editor 中粘贴执行
-- ============================================================

-- 扩展
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- 通用：updated_at 自动更新触发器函数
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================
-- 1. 回声 / 文章 echoes
-- ============================================================
create table if not exists public.echoes (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique,
  title       text not null,
  content     text not null default '',
  excerpt     text,
  cover_image text,
  mood        text,
  tags        text[] default '{}',
  status      text not null default 'published' check (status in ('draft', 'published')),
  view_count  integer not null default 0,
  like_count  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists echoes_status_idx    on public.echoes (status);
create index if not exists echoes_created_at_idx on public.echoes (created_at desc);
create index if not exists echoes_tags_idx        on public.echoes using gin (tags);

drop trigger if exists echoes_set_updated_at on public.echoes;
create trigger echoes_set_updated_at
  before update on public.echoes
  for each row execute function public.set_updated_at();

-- ============================================================
-- 2. 旅行 / 轨迹 travels
-- ============================================================
create table if not exists public.travels (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique,
  title        text not null,
  destination  text not null,
  country      text not null default '中国',
  province     text,
  city         text,
  start_date   date,
  end_date     date,
  description  text,
  cover_image  text,
  latitude     numeric(9, 6),
  longitude    numeric(9, 6),
  year         integer,
  tags         text[] default '{}',
  content      text,
  gallery      text[] default '{}',
  sort_order   integer not null default 0,
  status       text not null default 'published' check (status in ('draft', 'published')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists travels_status_idx     on public.travels (status);
create index if not exists travels_year_idx       on public.travels (year);
create index if not exists travels_created_at_idx on public.travels (created_at desc);
create index if not exists travels_location_idx   on public.travels (latitude, longitude);

drop trigger if exists travels_set_updated_at on public.travels;
create trigger travels_set_updated_at
  before update on public.travels
  for each row execute function public.set_updated_at();

-- ============================================================
-- 3. 档案 / 收藏 archives
-- ============================================================
create table if not exists public.archives (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  category     text not null check (category in ('影视', '漫画', '社区', '工具')),
  cover_image  text,
  url          text not null,
  rating       numeric(3, 1),
  tags         text[] default '{}',
  sort_order   integer not null default 0,
  status       text not null default 'published' check (status in ('draft', 'published')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists archives_category_idx on public.archives (category);
create index if not exists archives_status_idx   on public.archives (status);
create index if not exists archives_sort_idx     on public.archives (sort_order);

drop trigger if exists archives_set_updated_at on public.archives;
create trigger archives_set_updated_at
  before update on public.archives
  for each row execute function public.set_updated_at();

-- ============================================================
-- 4. 评论 / 信号 comments
-- ============================================================
create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid,
  post_path  text,
  nickname   text not null,
  email      text,
  website    text,
  content    text not null,
  avatar     text,
  parent_id  uuid references public.comments(id) on delete cascade,
  status     text not null default 'approved' check (status in ('pending', 'approved', 'hidden')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists comments_post_id_idx  on public.comments (post_id);
create index if not exists comments_parent_idx    on public.comments (parent_id);
create index if not exists comments_status_idx    on public.comments (status);
create index if not exists comments_created_at_idx on public.comments (created_at desc);

drop trigger if exists comments_set_updated_at on public.comments;
create trigger comments_set_updated_at
  before update on public.comments
  for each row execute function public.set_updated_at();

-- ============================================================
-- 5. AI 工具 ai_tools
-- ============================================================
create table if not exists public.ai_tools (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  logo        text,
  url         text not null,
  category    text,
  tags        text[] default '{}',
  rating      numeric(3, 1),
  status      text not null default 'published' check (status in ('draft', 'published')),
  featured    boolean not null default false,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists ai_tools_category_idx on public.ai_tools (category);
create index if not exists ai_tools_status_idx   on public.ai_tools (status);
create index if not exists ai_tools_featured_idx on public.ai_tools (featured);
create index if not exists ai_tools_sort_idx     on public.ai_tools (sort_order);

drop trigger if exists ai_tools_set_updated_at on public.ai_tools;
create trigger ai_tools_set_updated_at
  before update on public.ai_tools
  for each row execute function public.set_updated_at();

-- ============================================================
-- RLS 行级安全策略
-- 原则：公开内容允许匿名 SELECT；管理操作（INSERT/UPDATE/DELETE）需已认证用户
-- ============================================================

-- 启用 RLS
alter table public.echoes    enable row level security;
alter table public.travels   enable row level security;
alter table public.archives  enable row level security;
alter table public.comments  enable row level security;
alter table public.ai_tools  enable row level security;

-- ---------- echoes ----------
drop policy if exists "echoes: published readable by anon" on public.echoes;
create policy "echoes: published readable by anon"
  on public.echoes for select
  using (status = 'published');

drop policy if exists "echoes: all readable by auth" on public.echoes;
create policy "echoes: all readable by auth"
  on public.echoes for select
  to authenticated
  using (true);

drop policy if exists "echoes: insert by auth" on public.echoes;
create policy "echoes: insert by auth"
  on public.echoes for insert
  to authenticated
  with check (true);

drop policy if exists "echoes: update by auth" on public.echoes;
create policy "echoes: update by auth"
  on public.echoes for update
  to authenticated
  using (true);

drop policy if exists "echoes: delete by auth" on public.echoes;
create policy "echoes: delete by auth"
  on public.echoes for delete
  to authenticated
  using (true);

-- ---------- travels ----------
drop policy if exists "travels: published readable by anon" on public.travels;
create policy "travels: published readable by anon"
  on public.travels for select
  using (status = 'published');

drop policy if exists "travels: all readable by auth" on public.travels;
create policy "travels: all readable by auth"
  on public.travels for select
  to authenticated
  using (true);

drop policy if exists "travels: insert by auth" on public.travels;
create policy "travels: insert by auth"
  on public.travels for insert
  to authenticated
  with check (true);

drop policy if exists "travels: update by auth" on public.travels;
create policy "travels: update by auth"
  on public.travels for update
  to authenticated
  using (true);

drop policy if exists "travels: delete by auth" on public.travels;
create policy "travels: delete by auth"
  on public.travels for delete
  to authenticated
  using (true);

-- ---------- archives ----------
drop policy if exists "archives: published readable by anon" on public.archives;
create policy "archives: published readable by anon"
  on public.archives for select
  using (status = 'published');

drop policy if exists "archives: all readable by auth" on public.archives;
create policy "archives: all readable by auth"
  on public.archives for select
  to authenticated
  using (true);

drop policy if exists "archives: insert by auth" on public.archives;
create policy "archives: insert by auth"
  on public.archives for insert
  to authenticated
  with check (true);

drop policy if exists "archives: update by auth" on public.archives;
create policy "archives: update by auth"
  on public.archives for update
  to authenticated
  using (true);

drop policy if exists "archives: delete by auth" on public.archives;
create policy "archives: delete by auth"
  on public.archives for delete
  to authenticated
  using (true);

-- ---------- comments ----------
-- 匿名用户可查看已审核评论，可提交评论（status 默认 pending）
drop policy if exists "comments: approved readable by anon" on public.comments;
create policy "comments: approved readable by anon"
  on public.comments for select
  using (status = 'approved');

drop policy if exists "comments: all readable by auth" on public.comments;
create policy "comments: all readable by auth"
  on public.comments for select
  to authenticated
  using (true);

drop policy if exists "comments: insert by anon" on public.comments;
create policy "comments: insert by anon"
  on public.comments for insert
  with check (status IN ('pending', 'approved'));

drop policy if exists "comments: update by auth" on public.comments;
create policy "comments: update by auth"
  on public.comments for update
  to authenticated
  using (true);

drop policy if exists "comments: delete by auth" on public.comments;
create policy "comments: delete by auth"
  on public.comments for delete
  to authenticated
  using (true);

-- ---------- ai_tools ----------
drop policy if exists "ai_tools: published readable by anon" on public.ai_tools;
create policy "ai_tools: published readable by anon"
  on public.ai_tools for select
  using (status = 'published');

drop policy if exists "ai_tools: all readable by auth" on public.ai_tools;
create policy "ai_tools: all readable by auth"
  on public.ai_tools for select
  to authenticated
  using (true);

drop policy if exists "ai_tools: insert by auth" on public.ai_tools;
create policy "ai_tools: insert by auth"
  on public.ai_tools for insert
  to authenticated
  with check (true);

drop policy if exists "ai_tools: update by auth" on public.ai_tools;
create policy "ai_tools: update by auth"
  on public.ai_tools for update
  to authenticated
  using (true);

drop policy if exists "ai_tools: delete by auth" on public.ai_tools;
create policy "ai_tools: delete by auth"
  on public.ai_tools for delete
  to authenticated
  using (true);

-- ============================================================
-- RPC 函数：原子递增浏览量 / 点赞数
-- ============================================================
create or replace function public.increment_echo_view(p_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.echoes
  set view_count = view_count + 1
  where id = p_id;
end;
$$;

create or replace function public.increment_echo_like(p_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.echoes
  set like_count = like_count + 1
  where id = p_id;
end;
$$;

-- ============================================================
-- Storage Bucket（在 SQL 中创建，需要 supabase_admin 权限）
-- 如无法在 SQL Editor 执行，可在 Dashboard → Storage 手动创建
-- ============================================================
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('covers', 'covers', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('travel', 'travel', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('archive', 'archive', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', true)
on conflict (id) do nothing;

-- Storage 公开读策略
drop policy if exists "storage: public read avatars" on storage.objects;
create policy "storage: public read avatars"
  on storage.objects for select
  using (bucket_id in ('avatars', 'covers', 'travel', 'archive', 'uploads'));

drop policy if exists "storage: auth write" on storage.objects;
create policy "storage: auth write"
  on storage.objects for insert
  to authenticated
  with check (bucket_id in ('avatars', 'covers', 'travel', 'archive', 'uploads'));

drop policy if exists "storage: auth update" on storage.objects;
create policy "storage: auth update"
  on storage.objects for update
  to authenticated
  using (bucket_id in ('avatars', 'covers', 'travel', 'archive', 'uploads'));

drop policy if exists "storage: auth delete" on storage.objects;
create policy "storage: auth delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id in ('avatars', 'covers', 'travel', 'archive', 'uploads'));

-- ============================================================
-- 完成
-- ============================================================
-- 执行完毕后，请在 Supabase Dashboard 确认：
-- 1. 5 张表已创建且 RLS 已启用
-- 2. 5 个 Storage Bucket 已创建
-- 3. 执行 supabase/seed.sql 导入现有数据
-- 4. 在 Project Settings → API 中获取 URL 和 anon key，配置到环境变量
