-- ============================================================
-- FreeX 修仙界 · 安全加固迁移
--
-- 背景：前端只用 anon key，所以「谁能在数据库里做什么」完全由
--       RLS 策略 + 列级权限决定。本次修复针对已暴露的越权路径：
--       ① 任意登录用户可以把 profiles.role 改成 owner  → 直接拿到宗主权限
--       ② 任意登录用户可以改自己的 profiles.qi          → 排行榜作弊
--       ③ site_config 里存着明文管理密码，anon 可直接读到
--       ④ reset_user_password 未校验调用者               → 可重置他人密码
--       ⑤ 内容表/评论表的写策略是「登录即可写」          → 可删改全站内容
--       ⑥ storage 桶的写策略同样是「登录即可写」
--
-- 用法：Supabase Dashboard → SQL Editor → 整段粘贴执行。
--       脚本是幂等的，可以重复执行。
-- ============================================================


-- ============================================================
-- 0. 通用：判断调用者是否为宗主 / 管理员
-- ============================================================
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
	select exists (
		select 1 from public.profiles
		where id = auth.uid() and role in ('owner', 'admin')
	);
$$;

create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
	select exists (
		select 1 from public.profiles
		where id = auth.uid() and role = 'owner'
	);
$$;


-- ============================================================
-- 1. profiles：禁止客户端改 role / status / qi
-- ============================================================
-- Postgres 权限是「叠加」的：只要角色还有表级 UPDATE，列级授权就没法限制，
-- 所以必须先撤掉表级 UPDATE，再按列授权白名单。
do $$
declare
	v_want  text[] := array['username', 'avatar', 'original_username'];
	v_allow text[];
begin
	select array_agg(c) into v_allow
	from unnest(v_want) as c
	where exists (
		select 1 from information_schema.columns
		where table_schema = 'public' and table_name = 'profiles' and column_name = c
	);

	revoke update on public.profiles from anon, authenticated;

	if v_allow is not null and array_length(v_allow, 1) > 0 then
		execute format(
			'grant update (%s) on public.profiles to authenticated',
			array_to_string(v_allow, ', ')
		);
	end if;

	raise notice 'profiles 允许客户端更新的列：%', coalesce(array_to_string(v_allow, ', '), '(无)');
end $$;

-- 兜底触发器：即使将来有人误把 UPDATE 权限加回去，也拦得住
-- 注意：这里刻意不加 SECURITY DEFINER —— 需要靠 current_user 区分
--       「客户端直连」与「服务端可信函数（SECURITY DEFINER）内部写入」。
create or replace function public.guard_profile_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
	v_caller_role text;
begin
	-- 敏感列没动，直接放行
	if new.role is not distinct from old.role
		and new.status is not distinct from old.status
		and new.qi is not distinct from old.qi then
		return new;
	end if;

	-- 服务端可信函数（如 use_pill / approve_task_claim）内部写入：
	-- 此时 current_user 是函数属主，而不是 anon / authenticated
	if current_user not in ('anon', 'authenticated') then
		return new;
	end if;

	-- 客户端直连：只有宗主能改这三列
	select role into v_caller_role from public.profiles where id = auth.uid();
	if v_caller_role is distinct from 'owner' then
		raise exception '权限不足：不能修改 role / status / qi';
	end if;

	return new;
end;
$$;

drop trigger if exists trg_guard_profile_columns on public.profiles;
create trigger trg_guard_profile_columns
	before update on public.profiles
	for each row execute function public.guard_profile_columns();


-- ============================================================
-- 2. 角色 / 状态变更：改为鉴权 RPC
-- ============================================================
create or replace function public.admin_set_user_role(p_user_id uuid, p_role text)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
	v_caller_role text;
begin
	if p_role not in ('owner', 'admin', 'user') then
		return json_build_object('success', false, 'error', '非法角色');
	end if;

	if not public.is_owner() then
		return json_build_object('success', false, 'error', '只有宗主可以调整角色');
	end if;

	select role into v_caller_role from public.profiles where id = p_user_id;
	if v_caller_role is null then
		return json_build_object('success', false, 'error', '用户不存在');
	end if;

	if p_user_id = auth.uid() and p_role <> 'owner' then
		return json_build_object('success', false, 'error', '不能降低自己的权限');
	end if;

	update public.profiles set role = p_role, updated_at = now() where id = p_user_id;
	return json_build_object('success', true);
end;
$$;

create or replace function public.admin_set_user_status(p_user_id uuid, p_status text)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
	v_caller_role text;
	v_target_role text;
begin
	if p_status not in ('active', 'disabled') then
		return json_build_object('success', false, 'error', '非法状态');
	end if;

	select role into v_caller_role from public.profiles where id = auth.uid();
	if v_caller_role is null or v_caller_role not in ('owner', 'admin') then
		return json_build_object('success', false, 'error', '权限不足');
	end if;

	select role into v_target_role from public.profiles where id = p_user_id;
	if v_target_role is null then
		return json_build_object('success', false, 'error', '用户不存在');
	end if;

	-- 管理员只能处理普通用户
	if v_caller_role = 'admin' and v_target_role <> 'user' then
		return json_build_object('success', false, 'error', '管理员只能操作普通用户');
	end if;

	update public.profiles set status = p_status, updated_at = now() where id = p_user_id;
	return json_build_object('success', true);
end;
$$;


-- ============================================================
-- 3. reset_user_password：补上调用者校验
-- ============================================================
create or replace function public.reset_user_password(p_user_id uuid, p_new_password text)
returns json
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
	v_caller_role text;
	v_target_role text;
	v_rows        int;
begin
	select role into v_caller_role from public.profiles where id = auth.uid();
	if v_caller_role is null or v_caller_role not in ('owner', 'admin') then
		return json_build_object('success', false, 'error', '权限不足');
	end if;

	if length(coalesce(p_new_password, '')) < 6 then
		return json_build_object('success', false, 'error', '新密码至少 6 位');
	end if;

	select role into v_target_role from public.profiles where id = p_user_id;
	if v_target_role is null then
		return json_build_object('success', false, 'error', '用户不存在');
	end if;

	-- 管理员不能重置宗主 / 其他管理员的密码，避免互相顶号
	if v_caller_role = 'admin' and v_target_role <> 'user' then
		return json_build_object('success', false, 'error', '管理员只能重置普通用户的密码');
	end if;

	update auth.users
	   set encrypted_password = crypt(p_new_password, gen_salt('bf'))
	 where id = p_user_id;
	get diagnostics v_rows = row_count;

	if v_rows = 0 then
		return json_build_object('success', false, 'error', '用户不存在');
	end if;

	return json_build_object('success', true);
end;
$$;


-- ============================================================
-- 4. 内容表：写操作收紧到宗主 / 管理员
--    （原来 echoes / travels / archives / ai_tools 的策略是「登录即可增删改」，
--      任何注册用户都能改掉全站内容）
-- ============================================================
drop policy if exists "echoes: insert by auth" on public.echoes;
drop policy if exists "echoes: update by auth" on public.echoes;
drop policy if exists "echoes: delete by auth" on public.echoes;
create policy "echoes: staff insert" on public.echoes for insert to authenticated with check (public.is_staff());
create policy "echoes: staff update" on public.echoes for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "echoes: staff delete" on public.echoes for delete to authenticated using (public.is_staff());

drop policy if exists "travels: insert by auth" on public.travels;
drop policy if exists "travels: update by auth" on public.travels;
drop policy if exists "travels: delete by auth" on public.travels;
create policy "travels: staff insert" on public.travels for insert to authenticated with check (public.is_staff());
create policy "travels: staff update" on public.travels for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "travels: staff delete" on public.travels for delete to authenticated using (public.is_staff());

drop policy if exists "archives: insert by auth" on public.archives;
drop policy if exists "archives: update by auth" on public.archives;
drop policy if exists "archives: delete by auth" on public.archives;
create policy "archives: staff insert" on public.archives for insert to authenticated with check (public.is_staff());
create policy "archives: staff update" on public.archives for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "archives: staff delete" on public.archives for delete to authenticated using (public.is_staff());

drop policy if exists "ai_tools: insert by auth" on public.ai_tools;
drop policy if exists "ai_tools: update by auth" on public.ai_tools;
drop policy if exists "ai_tools: delete by auth" on public.ai_tools;
create policy "ai_tools: staff insert" on public.ai_tools for insert to authenticated with check (public.is_staff());
create policy "ai_tools: staff update" on public.ai_tools for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "ai_tools: staff delete" on public.ai_tools for delete to authenticated using (public.is_staff());

-- 评论：任何登录用户原本都能改 / 删所有评论，这里收紧到宗主 / 管理员
drop policy if exists "comments: update by auth" on public.comments;
drop policy if exists "comments: delete by auth" on public.comments;
create policy "comments: staff update" on public.comments for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "comments: staff delete" on public.comments for delete to authenticated using (public.is_staff());

-- 可选（默认不开启）：下面两句放开后，游客提交的评论会变成「待审核」，
-- 需要你在后台点通过才显示。当前前台是直接写 approved，所以默认保持原样。
-- drop policy if exists "comments: insert by anon" on public.comments;
-- create policy "comments: insert pending" on public.comments for insert to anon, authenticated
--   with check (status = 'pending');


-- ============================================================
-- 5. task_claims：禁止自己把任务状态改成 approved
--    （发币只走 approve_task_claim / approve_task_with_qi 函数）
-- ============================================================
drop policy if exists "tc update own" on public.task_claims;
create policy "tc update own" on public.task_claims for update to authenticated
	using (auth.uid() = user_id)
	with check (auth.uid() = user_id and status in ('claimed', 'submitted', 'rejected'));

drop policy if exists "tc update staff" on public.task_claims;
create policy "tc update staff" on public.task_claims for update to authenticated
	using (public.is_staff()) with check (public.is_staff());


-- ============================================================
-- 6. Storage：写操作收紧（前端目前没有上传逻辑，改完不影响页面）
-- ============================================================
drop policy if exists "storage: auth write" on storage.objects;
drop policy if exists "storage: auth update" on storage.objects;
drop policy if exists "storage: auth delete" on storage.objects;

create policy "storage: staff write" on storage.objects for insert to authenticated
	with check (bucket_id in ('covers', 'travel', 'archive', 'uploads') and public.is_staff());
create policy "storage: staff update" on storage.objects for update to authenticated
	using (bucket_id in ('covers', 'travel', 'archive', 'uploads') and public.is_staff());
create policy "storage: staff delete" on storage.objects for delete to authenticated
	using (bucket_id in ('covers', 'travel', 'archive', 'uploads') and public.is_staff());

-- 头像桶：允许登录用户写自己 uid 目录下的文件（约定路径 avatars/<uid>/xxx.png）
create policy "storage: avatar write own" on storage.objects for insert to authenticated
	with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "storage: avatar update own" on storage.objects for update to authenticated
	using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "storage: avatar delete own" on storage.objects for delete to authenticated
	using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);


-- ============================================================
-- 7. site_config：启用 RLS，并删掉明文管理密码
--    前端已不再读取该表（后台改为按账号角色鉴权）
-- ============================================================
do $$
begin
	if to_regclass('public.site_config') is not null then
		execute 'alter table public.site_config enable row level security';

		execute 'drop policy if exists "site_config staff read" on public.site_config';
		execute $p$
			create policy "site_config staff read" on public.site_config
				for select to authenticated using (public.is_staff())
		$p$;

		execute 'drop policy if exists "site_config owner write" on public.site_config';
		execute $p$
			create policy "site_config owner write" on public.site_config
				for all to authenticated using (public.is_owner()) with check (public.is_owner())
		$p$;

		execute 'delete from public.site_config where key = ''admin_password''';
		raise notice 'site_config 已启用 RLS，并删除明文 admin_password';
	else
		raise notice '未找到 public.site_config 表，跳过（若仍在使用请告知实际表名）';
	end if;
end $$;


-- ============================================================
-- 8. 收紧函数执行权：把 public 下所有函数的默认 PUBLIC 执行权收回
--    （Postgres 新建函数默认 PUBLIC 可执行，等于 anon 能调用所有 RPC）
-- ============================================================
do $$
declare
	r record;
begin
	for r in
		select p.oid::regprocedure as sig
		from pg_proc p
		join pg_namespace n on n.oid = p.pronamespace
		where n.nspname = 'public'
	loop
		execute format('revoke all on function %s from public, anon', r.sig);
		execute format('grant execute on function %s to authenticated', r.sig);
	end loop;
end $$;

-- 白名单：未登录也要能调的 RPC（排行榜、邀请码校验、任务人数、文章浏览/点赞）
do $$
declare
	r       record;
	v_names text[] := array[
		'get_public_coin_ranking',
		'get_public_realm_ranking',
		'validate_invitation_code',
		'get_task_claim_counts',
		'increment_echo_view',
		'increment_echo_like',
		'is_staff',
		'is_owner'
	];
begin
	for r in
		select p.oid::regprocedure as sig
		from pg_proc p
		join pg_namespace n on n.oid = p.pronamespace
		where n.nspname = 'public' and p.proname = any(v_names)
	loop
		execute format('grant execute on function %s to anon', r.sig);
	end loop;
end $$;


-- ============================================================
-- 9. 收尾自检
-- ============================================================
-- 9.1 profiles 的列级权限（应只看到 username / avatar / original_username）
select grantee, privilege_type, column_name
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles' and privilege_type = 'UPDATE'
order by grantee, column_name;

-- 9.2 当前宗主 / 管理员名单（确认没有多出来的陌生账号！）
select id, username, role, status, qi, created_at, updated_at
from public.profiles
where role in ('owner', 'admin')
order by updated_at desc;

-- 9.3 最近被动过的账号（排查是否已被改过数据）
select id, username, role, status, qi, updated_at
from public.profiles
order by updated_at desc
limit 30;


-- ============================================================
-- 做完 SQL 之后，还必须在控制台手动处理的三件事：
--
-- 1) 轮换密码：既然明文管理密码可以公开读，请假定它已泄露。
--    · Supabase Dashboard → Authentication → Users，给宗主账号改密码
--    · 修仙界里所有用户的密码也可能被 reset_user_password 重置过，
--      建议逐个通知改密码（改密码走的是 auth.updateUser，前端已有入口）
--
-- 2) 关闭自助注册：Dashboard → Authentication → Sign In / Providers →
--    Email 里关掉「Allow new users to sign up」。
--    现在注册页的邀请码只是前端校验，任何人都能绕过它直接调 signUp 注册。
--
-- 3) 检查是否有人在数据里留了后手：
--    select * from public.wallet_transactions order by created_at desc limit 100;
--    select * from public.orders order by created_at desc limit 50;
--    select * from public.invitation_codes order by created_at desc limit 50;
-- ============================================================
