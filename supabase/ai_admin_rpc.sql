-- AI 工具 管理 RPC：增删改查 ai_tools 表
-- 登录鉴权复用 admin_credentials（module='echo'，账号 idong）

-- 1. 列表
create or replace function public.admin_list_ai_tools()
returns table (
  id uuid,
  name text,
  url text,
  description text,
  category text,
  tags text[],
  status text,
  sort_order int,
  created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select a.id, a.name, a.url, a.description, a.category, a.tags,
         a.status::text, a.sort_order, a.created_at
  from public.ai_tools a
  order by a.category, a.sort_order, a.created_at desc;
$$;

-- 2. 新增
create or replace function public.admin_create_ai_tool(
  p_name text, p_url text, p_category text,
  p_description text default null, p_tags text[] default null,
  p_username text default null, p_password text default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.verify_admin_credentials('echo', p_username, p_password) then
    raise exception '未授权';
  end if;
  insert into public.ai_tools (name, url, category, description, tags, status, sort_order)
  values (p_name, p_url, p_category, p_description, coalesce(p_tags,'{}'), 'published', 999);
end;
$$;

-- 3. 编辑
create or replace function public.admin_update_ai_tool(
  p_id uuid, p_name text, p_url text, p_category text,
  p_description text default null, p_tags text[] default null,
  p_username text default null, p_password text default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.verify_admin_credentials('echo', p_username, p_password) then
    raise exception '未授权';
  end if;
  update public.ai_tools
     set name = p_name, url = p_url, category = p_category,
         description = p_description, tags = p_tags, updated_at = now()
   where id = p_id;
end;
$$;

-- 4. 删除
create or replace function public.admin_delete_ai_tool(
  p_id uuid, p_username text default null, p_password text default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.verify_admin_credentials('echo', p_username, p_password) then
    raise exception '未授权';
  end if;
  delete from public.ai_tools where id = p_id;
end;
$$;

grant execute on function public.admin_list_ai_tools to anon, authenticated;
grant execute on function public.admin_create_ai_tool(text, text, text, text, text[], text, text) to anon, authenticated;
grant execute on function public.admin_update_ai_tool(uuid, text, text, text, text, text[], text, text) to anon, authenticated;
grant execute on function public.admin_delete_ai_tool(uuid, text, text) to anon, authenticated;
