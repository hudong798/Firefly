-- 收藏/档案 管理 RPC：增删改查 archives 表
-- 登录鉴权复用 admin_credentials（module='echo'，账号 idong）

-- 1. 列表（含草稿）
create or replace function public.admin_list_archives()
returns table (
  id uuid,
  title text,
  url text,
  description text,
  category text,
  tags text[],
  status text,
  sort_order int,
  created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select a.id, a.title, a.url, a.description, a.category::text, a.tags,
         a.status::text, a.sort_order, a.created_at
  from public.archives a
  order by a.category, a.sort_order, a.created_at desc;
$$;

-- 2. 新增
create or replace function public.admin_create_archive(
  p_title text, p_url text, p_category text,
  p_description text default null, p_tags text[] default null,
  p_username text default null, p_password text default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.verify_admin_credentials('echo', p_username, p_password) then
    raise exception '未授权';
  end if;
  insert into public.archives (title, url, category, description, tags, status, sort_order)
  values (p_title, p_url, p_category,
          p_description, coalesce(p_tags,'{}'), 'published', 999);
end;
$$;

-- 3. 编辑
create or replace function public.admin_update_archive(
  p_id uuid, p_title text, p_url text, p_category text,
  p_description text default null, p_tags text[] default null,
  p_username text default null, p_password text default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.verify_admin_credentials('echo', p_username, p_password) then
    raise exception '未授权';
  end if;
  update public.archives
     set title = p_title, url = p_url, category = p_category,
         description = p_description, tags = p_tags, updated_at = now()
   where id = p_id;
end;
$$;

-- 4. 删除
create or replace function public.admin_delete_archive(
  p_id uuid, p_username text default null, p_password text default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.verify_admin_credentials('echo', p_username, p_password) then
    raise exception '未授权';
  end if;
  delete from public.archives where id = p_id;
end;
$$;

-- 权限
grant execute on function public.admin_list_archives to anon, authenticated;
grant execute on function public.admin_create_archive(text, text, text, text, text[], text, text) to anon, authenticated;
grant execute on function public.admin_update_archive(uuid, text, text, text, text, text[], text, text) to anon, authenticated;
grant execute on function public.admin_delete_archive(uuid, text, text) to anon, authenticated;
