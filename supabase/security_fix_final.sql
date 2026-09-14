-- ============================================================
-- FreeX / 童话小镇 · 修仙界 安全加固（最终版 v2 · 幂等）
--
-- 【这份脚本解决什么】
--   2026-09 实测：只拿到「公开 anon key」的人，注册一个普通账号后即可：
--     ① 把自己 profiles.role 改成 owner            —— 垂直提权，直接变宗主
--     ② 把自己 profiles.qi 改成任意值              —— 虎粮/境界作弊
--     ③ 改自己 profiles.status                     —— 账号状态越权
--     ④ 任意上架 / 改价 products 商品              —— 仙市越权写
--     ⑤ 凭空往 inventory 背包塞任意丹药/物品       —— 经济系统造假
--     ⑥ 读到全站每个人的 wallets 星辰币余额        —— 水平越权读
--     ⑦ 任意登录用户可发全站公告/文章（内容表）    —— 内容越权写
--     ⑧ 匿名（不登录）可直接提交评论               —— 可刷评论
--   线上已出现一个被提权的后门 owner：sectest_0914。
--
-- 【根因】
--   线上数据库实际运行的 RLS 策略与仓库里的 schema 不一致：
--   写策略被错误放成「认证用户即可写 / using(true)」，且 profiles
--   缺少「列级保护」，用户能改自己这一行里的任意列（含 role/qi）。
--
-- 【怎么执行】
--   Supabase Dashboard → SQL Editor → New query →
--   整段粘贴 → Run。脚本幂等，可重复执行，不依赖 service_role key。
--
-- 【设计原则】
--   · 先把每张表现有策略「全部清空」（线上旧策略名未知，必须动态清），
--     再按最小权限重建，保证无论之前是什么烂策略都能被覆盖。
--   · 敏感写操作（转账/发币/兑换/买药/审批）全部只允许由
--     SECURITY DEFINER 的 RPC 在服务端完成；客户端直连一律禁止。
--   · 表级 GRANT（能不能发这类语句）+ RLS 策略（能碰哪些行列）双层设防。
-- ============================================================


-- ============================================================
-- 0. 角色判定辅助函数
-- ============================================================
create or replace function public.is_staff()
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role in ('owner','admin'));
$$;

create or replace function public.is_owner()
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'owner');
$$;


-- ============================================================
-- 工具：清空某张表上「所有」RLS 策略（不管它叫什么名字）
-- ============================================================
create or replace function public._drop_all_policies(p_table text)
returns void language plpgsql security definer
set search_path = public, pg_temp as $$
declare r record;
begin
  for r in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = p_table
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, p_table);
  end loop;
end $$;


-- ============================================================
-- 1. profiles：列级保护 + 触发器兜底 + 精确 RLS
--    客户端只允许改自己的 username / avatar / original_username；
--    role / status / qi 任何客户端直连都不许碰（含本人）。
-- ============================================================
-- 1.1 列级权限：先整体收回 UPDATE，再按白名单列授回
do $$
declare
  v_want  text[] := array['username','avatar','original_username'];
  v_allow text[];
begin
  select array_agg(c) into v_allow
  from unnest(v_want) as c
  where exists (select 1 from information_schema.columns
                where table_schema='public' and table_name='profiles' and column_name=c);

  revoke insert, update, delete on public.profiles from anon, authenticated;

  if v_allow is not null and array_length(v_allow,1) > 0 then
    execute format('grant update (%s) on public.profiles to authenticated',
                   array_to_string(v_allow,', '));
  end if;
end $$;

-- 1.2 兜底触发器：客户端直连改 role/status/qi 直接报错；
--     SECURITY DEFINER 函数（current_user 不是 anon/authenticated）内部放行
create or replace function public.guard_profile_columns()
returns trigger language plpgsql
set search_path = public, pg_temp as $$
declare v_role text;
begin
  if new.role is not distinct from old.role
     and new.status is not distinct from old.status
     and new.qi   is not distinct from old.qi then
    return new;
  end if;
  if current_user not in ('anon','authenticated') then
    return new; -- 服务端可信函数
  end if;
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is distinct from 'owner' then
    raise exception '权限不足：客户端不能修改 role / status / qi';
  end if;
  return new;
end $$;
drop trigger if exists trg_guard_profile_columns on public.profiles;
create trigger trg_guard_profile_columns
  before update on public.profiles
  for each row execute function public.guard_profile_columns();

-- 1.3 RLS：公开可读（排行榜/道号展示需要），本人可改白名单列，管理员可改
alter table public.profiles enable row level security;
select public._drop_all_policies('profiles');
create policy "profiles select all" on public.profiles
  for select using (true);
create policy "profiles update self" on public.profiles
  for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles update staff" on public.profiles
  for update to authenticated
  using (public.is_staff()) with check (public.is_staff());
-- profiles 的 insert/delete 不建任何策略：
--   新增由 handle_new_user 触发器（definer）完成，删除走 delete_user RPC。


-- ============================================================
-- 2. wallets 钱包：只准本人/管理员读；客户端一律不许写
--    （余额变动只允许 transfer_coins / approve_* / redeem / buy_* 等
--      SECURITY DEFINER 函数在服务端做）
-- ============================================================
do $$ begin
  alter table public.wallets enable row level security;
  revoke insert, update, delete on public.wallets from anon, authenticated;
  perform public._drop_all_policies('wallets');
end $$;
create policy "wallets select self or staff" on public.wallets
  for select using (auth.uid() = user_id or public.is_staff());
-- 不建 insert/update/delete 策略 → 客户端直连全部被 RLS 拒绝


-- ============================================================
-- 3. wallet_transactions 流水：本人/管理员读，客户端不许写
-- ============================================================
do $$ begin
  alter table public.wallet_transactions enable row level security;
  revoke insert, update, delete on public.wallet_transactions from anon, authenticated;
  perform public._drop_all_policies('wallet_transactions');
end $$;
create policy "wt select self or staff" on public.wallet_transactions
  for select using (auth.uid() = user_id or public.is_staff());


-- ============================================================
-- 4. tasks 任务：已发布公开可读（含未登录浏览），写仅管理员
-- ============================================================
do $$ begin
  alter table public.tasks enable row level security;
  revoke insert, update, delete on public.tasks from anon, authenticated;
  grant insert, update, delete on public.tasks to authenticated;
  perform public._drop_all_policies('tasks');
end $$;
create policy "tasks read" on public.tasks
  for select using (
    status = 'published'
    or auth.uid() = creator_id
    or public.is_staff());
create policy "tasks staff insert" on public.tasks
  for insert to authenticated with check (public.is_staff());
create policy "tasks staff update" on public.tasks
  for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "tasks staff delete" on public.tasks
  for delete to authenticated using (public.is_staff());


-- ============================================================
-- 5. task_claims 任务领取：本人/管理员读；本人只能在有限状态间流转，
--    审核/发币只走 approve_task_claim / approve_task_with_qi RPC
-- ============================================================
do $$ begin
  alter table public.task_claims enable row level security;
  revoke insert, update, delete on public.task_claims from anon, authenticated;
  grant update on public.task_claims to authenticated;
  perform public._drop_all_policies('task_claims');
end $$;
create policy "tc read self or staff" on public.task_claims
  for select using (auth.uid() = user_id or public.is_staff());
-- 领取走 claim_task_atomic RPC，故不开放客户端 insert
create policy "tc update self limited" on public.task_claims
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id
              and status in ('claimed','submitted','rejected'));
create policy "tc update staff" on public.task_claims
  for update to authenticated
  using (public.is_staff()) with check (public.is_staff());


-- ============================================================
-- 6. products 商品：上架商品公开可读；增/改/删仅管理员（修复越权上架/改价）
-- ============================================================
do $$ begin
  alter table public.products enable row level security;
  revoke insert, update, delete on public.products from anon, authenticated;
  grant insert, update, delete on public.products to authenticated;
  perform public._drop_all_policies('products');
end $$;
create policy "products read" on public.products
  for select using (status = 'active' or public.is_staff());
create policy "products staff insert" on public.products
  for insert to authenticated with check (public.is_staff());
create policy "products staff update" on public.products
  for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "products staff delete" on public.products
  for delete to authenticated using (public.is_staff());


-- ============================================================
-- 7. orders 订单：本人/卖家/管理员读；客户端不直写（兑换走 redeem_product，
--    发货走 ship_order，退款走 refund_order，均为服务端 RPC）
-- ============================================================
do $$ begin
  alter table public.orders enable row level security;
  revoke insert, update, delete on public.orders from anon, authenticated;
  grant update on public.orders to authenticated;
  perform public._drop_all_policies('orders');
end $$;
create policy "orders read" on public.orders
  for select using (
    auth.uid() = user_id
    or public.is_staff()
    or exists (select 1 from public.products p
               where p.id = orders.product_id and p.creator_id = auth.uid()));
create policy "orders staff update" on public.orders
  for update to authenticated using (public.is_staff()) with check (public.is_staff());


-- ============================================================
-- 8. transfers 转账记录：收发双方/管理员读；客户端不写（走 transfer_coins）
-- ============================================================
do $$ begin
  alter table public.transfers enable row level security;
  revoke insert, update, delete on public.transfers from anon, authenticated;
  perform public._drop_all_policies('transfers');
end $$;
create policy "transfers read involved" on public.transfers
  for select using (
    auth.uid() = sender_id or auth.uid() = receiver_id or public.is_staff());


-- ============================================================
-- 9. pills 丹药：上架公开读；增改删仅管理员
-- ============================================================
do $$ begin
  if to_regclass('public.pills') is not null then
    alter table public.pills enable row level security;
    revoke insert, update, delete on public.pills from anon, authenticated;
    grant insert, update, delete on public.pills to authenticated;
    perform public._drop_all_policies('pills');
    execute $p$
      create policy "pills read" on public.pills
        for select using (status = 'active' or public.is_staff());
      create policy "pills staff insert" on public.pills
        for insert to authenticated with check (public.is_staff());
      create policy "pills staff update" on public.pills
        for update to authenticated using (public.is_staff()) with check (public.is_staff());
      create policy "pills staff delete" on public.pills
        for delete to authenticated using (public.is_staff());
    $p$;
  end if;
end $$;


-- ============================================================
-- 10. inventory 储物袋：本人/管理员读；本人只能改「状态类」白名单列，
--     严禁客户端 insert（修复凭空造物品）；删除也只走服务端
-- ============================================================
do $$
declare
  v_want  text[] := array['status','used_at','listed_at','resell_price'];
  v_allow text[];
begin
  if to_regclass('public.inventory') is null then
    return;
  end if;

  alter table public.inventory enable row level security;
  -- 收回全部写权限，再仅授回「白名单列的 update」
  revoke insert, update, delete on public.inventory from anon, authenticated;

  select array_agg(c) into v_allow
  from unnest(v_want) as c
  where exists (select 1 from information_schema.columns
                where table_schema='public' and table_name='inventory' and column_name=c);
  if v_allow is not null and array_length(v_allow,1) > 0 then
    execute format('grant update (%s) on public.inventory to authenticated',
                   array_to_string(v_allow,', '));
  end if;

  perform public._drop_all_policies('inventory');

  execute $p$
    create policy "inventory read self or staff" on public.inventory
      for select using (auth.uid() = user_id or public.is_staff());
    create policy "inventory update self" on public.inventory
      for update to authenticated
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
    create policy "inventory update staff" on public.inventory
      for update to authenticated
      using (public.is_staff()) with check (public.is_staff());
  $p$;
  -- 不开放 insert/delete：物品获得/消耗只走 buy_pill / use_pill / redeem_product
end $$;

-- 兜底触发器：客户端不许改 inventory 的数量/品阶/功效/归属等作弊列
create or replace function public.guard_inventory_columns()
returns trigger language plpgsql
set search_path = public, pg_temp as $$
begin
  if current_user not in ('anon','authenticated') then return new; end if;
  if new.quantity is distinct from old.quantity
     or new.user_id is distinct from old.user_id
     or new.pill_id is distinct from old.pill_id
     or new.product_id is distinct from old.product_id
     or new.item_type is distinct from old.item_type
     or new.pill_name is distinct from old.pill_name
     or new.pill_grade is distinct from old.pill_grade
     or new.pill_qi_bonus is distinct from old.pill_qi_bonus then
    raise exception '权限不足：客户端不能修改物品的数量/品阶/功效/归属';
  end if;
  return new;
end $$;
do $$ begin
  if to_regclass('public.inventory') is not null then
    drop trigger if exists trg_guard_inventory on public.inventory;
    execute 'create trigger trg_guard_inventory before update on public.inventory
             for each row execute function public.guard_inventory_columns()';
  end if;
end $$;


-- ============================================================
-- 11. resell_listings 转售挂单：active 公开读；本人可撤销自己的挂单，
--     其余写操作走 list_pill_for_resell / 竞价 RPC
-- ============================================================
do $$ begin
  if to_regclass('public.resell_listings') is not null then
    alter table public.resell_listings enable row level security;
    revoke insert, update, delete on public.resell_listings from anon, authenticated;
    grant delete, update on public.resell_listings to authenticated;
    perform public._drop_all_policies('resell_listings');
    execute $p$
      create policy "resell read" on public.resell_listings
        for select using (status = 'active' or auth.uid() = seller_id or public.is_staff());
      create policy "resell delete self" on public.resell_listings
        for delete to authenticated
        using (auth.uid() = seller_id or public.is_staff());
      create policy "resell update staff" on public.resell_listings
        for update to authenticated
        using (public.is_staff()) with check (public.is_staff());
    $p$;
  end if;
end $$;


-- ============================================================
-- 12. resell_bids 竞价：竞价人/卖家/管理员读；客户端不直写（走竞价 RPC）
-- ============================================================
do $$ begin
  if to_regclass('public.resell_bids') is not null then
    alter table public.resell_bids enable row level security;
    revoke insert, update, delete on public.resell_bids from anon, authenticated;
    perform public._drop_all_policies('resell_bids');
    execute $p$
      create policy "bids read" on public.resell_bids
        for select using (
          auth.uid() = bidder_id or public.is_staff()
          or exists (select 1 from public.resell_listings rl
                     where rl.id = resell_bids.listing_id and rl.seller_id = auth.uid()));
    $p$;
  end if;
end $$;


-- ============================================================
-- 13. invitation_codes 邀请码：只准管理员读，仅宗主可写
--     （普通用户/匿名禁止枚举邀请码；校验走 validate_invitation_code RPC）
-- ============================================================
do $$ begin
  if to_regclass('public.invitation_codes') is not null then
    alter table public.invitation_codes enable row level security;
    revoke all on public.invitation_codes from anon;
    revoke insert, update, delete on public.invitation_codes from authenticated;
    grant select on public.invitation_codes to authenticated;
    perform public._drop_all_policies('invitation_codes');
    execute $p$
      create policy "codes staff read" on public.invitation_codes
        for select to authenticated using (public.is_staff());
      create policy "codes owner write" on public.invitation_codes
        for all to authenticated using (public.is_owner()) with check (public.is_owner());
    $p$;
  end if;
end $$;


-- ============================================================
-- 14. 内容表 echoes / travels / archives / ai_tools：
--     已发布内容公开可读；增改删收紧到管理员（修复「登录即可发全站内容」）
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array['echoes','travels','archives','ai_tools']
  loop
    if to_regclass('public.'||t) is null then continue; end if;
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke insert, update, delete on public.%I from anon, authenticated', t);
    execute format('grant insert, update, delete on public.%I to authenticated', t);
    perform public._drop_all_policies(t);

    -- 读：已发布公开；登录用户/管理员可读全部（后台需要看草稿）
    execute format($f$
      create policy "%I read published" on public.%I
        for select using (
          (coalesce(status,'published') = 'published')
          or public.is_staff());
    $f$, t, t);
    execute format($f$
      create policy "%I staff insert" on public.%I
        for insert to authenticated with check (public.is_staff());
    $f$, t, t);
    execute format($f$
      create policy "%I staff update" on public.%I
        for update to authenticated using (public.is_staff()) with check (public.is_staff());
    $f$, t, t);
    execute format($f$
      create policy "%I staff delete" on public.%I
        for delete to authenticated using (public.is_staff());
    $f$, t, t);
  end loop;
end $$;


-- ============================================================
-- 15. comments 评论：已审核公开读；游客/登录都能提交，但强制 pending 待审核
--     （修复匿名直接写 approved 绕过审核；改/删仅管理员）
-- ============================================================
do $$ begin
  if to_regclass('public.comments') is null then return; end if;
  alter table public.comments enable row level security;
  revoke update, delete on public.comments from anon, authenticated;
  grant insert on public.comments to anon, authenticated;
  grant update, delete on public.comments to authenticated;
  perform public._drop_all_policies('comments');

  execute $p$
    create policy "comments read approved" on public.comments
      for select using (status = 'approved' or public.is_staff());
    -- 任何人提交都必须是 pending，杜绝自助审核通过
    create policy "comments insert pending" on public.comments
      for insert to anon, authenticated
      with check (status = 'pending');
    create policy "comments staff update" on public.comments
      for update to authenticated using (public.is_staff()) with check (public.is_staff());
    create policy "comments staff delete" on public.comments
      for delete to authenticated using (public.is_staff());
  $p$;
end $$;


-- ============================================================
-- 16. 管理类 RPC：角色/状态变更、重置密码（服务端鉴权，前端只调函数）
-- ============================================================
create or replace function public.admin_set_user_role(p_user_id uuid, p_role text)
returns json language plpgsql security definer
set search_path = public, auth, extensions, pg_temp as $$
declare v_target text;
begin
  -- 只允许降为普通用户，禁止提升为管理员或宗主（只有宗主一个高权限账号）
  if p_role not in ('user') then
    return json_build_object('success',false,'error','只能将用户降为普通用户，不能提升权限');
  end if;
  if not public.is_owner() then
    return json_build_object('success',false,'error','只有宗主可以调整角色');
  end if;
  select role into v_target from public.profiles where id = p_user_id;
  if v_target is null then
    return json_build_object('success',false,'error','用户不存在');
  end if;
  if p_user_id = auth.uid() then
    return json_build_object('success',false,'error','不能修改自己的角色');
  end if;
  update public.profiles set role = p_role, updated_at = now() where id = p_user_id;
  return json_build_object('success',true);
end $$;

create or replace function public.admin_set_user_status(p_user_id uuid, p_status text)
returns json language plpgsql security definer
set search_path = public, auth, extensions, pg_temp as $$
declare v_caller text; v_target text;
begin
  if p_status not in ('active','disabled') then
    return json_build_object('success',false,'error','非法状态');
  end if;
  select role into v_caller from public.profiles where id = auth.uid();
  if v_caller is null or v_caller not in ('owner','admin') then
    return json_build_object('success',false,'error','权限不足');
  end if;
  select role into v_target from public.profiles where id = p_user_id;
  if v_target is null then
    return json_build_object('success',false,'error','用户不存在');
  end if;
  if v_caller = 'admin' and v_target <> 'user' then
    return json_build_object('success',false,'error','管理员只能操作普通用户');
  end if;
  update public.profiles set status = p_status, updated_at = now() where id = p_user_id;
  return json_build_object('success',true);
end $$;

create or replace function public.reset_user_password(p_user_id uuid, p_new_password text)
returns json language plpgsql security definer
set search_path = public, auth, extensions, pg_temp as $$
declare v_caller text; v_target text; v_rows int;
begin
  select role into v_caller from public.profiles where id = auth.uid();
  if v_caller is null or v_caller not in ('owner','admin') then
    return json_build_object('success',false,'error','权限不足');
  end if;
  if length(coalesce(p_new_password,'')) < 6 then
    return json_build_object('success',false,'error','新密码至少 6 位');
  end if;
  select role into v_target from public.profiles where id = p_user_id;
  if v_target is null then
    return json_build_object('success',false,'error','用户不存在');
  end if;
  if v_caller = 'admin' and v_target <> 'user' then
    return json_build_object('success',false,'error','管理员只能重置普通用户密码');
  end if;
  update auth.users set encrypted_password = crypt(p_new_password, gen_salt('bf'))
   where id = p_user_id;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return json_build_object('success',false,'error','用户不存在');
  end if;
  return json_build_object('success',true);
end $$;


-- ============================================================
-- 16.5 重建 delete_user：真宗主可删除「除自己外」的任意账号
--      （旧版硬编码「不能删除其他宗主」，导致被非法提权成 owner 的
--        后门账号反而删不掉。新版允许清理非法 owner，并完整级联删数据）
-- ============================================================
create or replace function public.delete_user(p_user_id uuid)
returns json language plpgsql security definer
set search_path = public, auth, extensions, pg_temp as $$
declare v_caller text;
begin
  select role into v_caller from public.profiles where id = auth.uid();
  if v_caller is null or v_caller <> 'owner' then
    return json_build_object('success',false,'error','只有宗主可以删除用户');
  end if;
  if p_user_id = auth.uid() then
    return json_build_object('success',false,'error','不能删除当前登录的自己');
  end if;
  if not exists (select 1 from public.profiles where id = p_user_id) then
    return json_build_object('success',false,'error','用户不存在');
  end if;

  -- 解除「无级联」的外键引用
  update public.task_claims set reviewer_id = null where reviewer_id = p_user_id;

  -- 订单：本人购买的 + 其创建商品产生的订单
  delete from public.orders
   where user_id = p_user_id
      or product_id in (select id from public.products where creator_id = p_user_id);

  -- 扩展表（migration 才有的表，存在才删，保证脚本健壮）
  if to_regclass('public.resell_bids') is not null then
    delete from public.resell_bids
     where bidder_id = p_user_id
        or listing_id in (select id from public.resell_listings where seller_id = p_user_id);
  end if;
  if to_regclass('public.resell_listings') is not null then
    delete from public.resell_listings where seller_id = p_user_id;
  end if;
  if to_regclass('public.inventory') is not null then
    delete from public.inventory where user_id = p_user_id;
  end if;
  if to_regclass('public.pills') is not null then
    delete from public.pills where seller_id = p_user_id;
  end if;

  delete from public.task_claims       where user_id = p_user_id;
  delete from public.tasks             where creator_id = p_user_id; -- 级联删其任务下的领取
  delete from public.products          where creator_id = p_user_id;
  delete from public.wallet_transactions where user_id = p_user_id;
  delete from public.transfers         where sender_id = p_user_id or receiver_id = p_user_id;
  delete from public.wallets           where user_id = p_user_id;

  -- profile（其余 on delete cascade 自动清）+ 认证账号
  delete from auth.identities where user_id = p_user_id;
  delete from public.profiles where id = p_user_id;
  delete from auth.users where id = p_user_id;

  return json_build_object('success',true);
exception when others then
  return json_build_object('success',false,'error',sqlerrm);
end $$;


-- ============================================================
-- 17. 函数执行权：收回 public 默认 execute，登录用户可执行业务 RPC，
--     未登录白名单只放开「排行榜/邀请码校验/浏览量点赞」
-- ============================================================
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  loop
    execute format('revoke all on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;

do $$
declare r record;
  v_names text[] := array[
    'get_public_coin_ranking','get_public_realm_ranking',
    'validate_invitation_code','get_task_claim_counts',
    'increment_echo_view','increment_echo_like',
    'is_staff','is_owner'];
begin
  for r in
    select p.oid::regprocedure as sig from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname = any(v_names)
  loop
    execute format('grant execute on function %s to anon', r.sig);
  end loop;
end $$;


-- ============================================================
-- 18. Storage：写收紧到管理员 + 本人头像目录
-- ============================================================
do $$
declare r record;
begin
  for r in
    select policyname from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname in ('storage: auth write','storage: auth update','storage: auth delete')
  loop
    execute format('drop policy if exists %I on storage.objects', r.policyname);
  end loop;
end $$;
create policy "storage staff write" on storage.objects for insert to authenticated
  with check (bucket_id in ('covers','travel','archive','uploads') and public.is_staff());
create policy "storage staff update" on storage.objects for update to authenticated
  using (bucket_id in ('covers','travel','archive','uploads') and public.is_staff());
create policy "storage staff delete" on storage.objects for delete to authenticated
  using (bucket_id in ('covers','travel','archive','uploads') and public.is_staff());
create policy "storage avatar write own" on storage.objects for insert to authenticated
  with check (bucket_id='avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "storage avatar update own" on storage.objects for update to authenticated
  using (bucket_id='avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "storage avatar delete own" on storage.objects for delete to authenticated
  using (bucket_id='avatars' and (storage.foldername(name))[1] = auth.uid()::text);


-- ============================================================
-- 18.5 删除一次性辅助函数
--      _drop_all_policies 是 SECURITY DEFINER，绝不能留在库里，
--      否则任何登录用户都能 select _drop_all_policies('products')
--      反过来清空 RLS 策略。所有策略重建完立即删除。
-- ============================================================
drop function if exists public._drop_all_policies(text);


-- ============================================================
-- 19. 清理：安全测试残留 + 后门账号止血
-- ============================================================
-- 19.1 删除安全测试产生的假数据（幂等，没有也不报错）
delete from public.products       where name = '__probe__';
delete from public.echoes         where title = '__probe__';
delete from public.inventory      where pill_name = '__hack_drug__';
delete from public.comments       where nickname = '__probe__';

-- 19.2 直接删除被非法提权 / 安全测试产生的账号：
--      sectest_0914（被提权成 owner 的陌生后门账号）、probe_sec_*（测试中被提权）、
--      probe2_*（纯测试号）。SQL Editor 以管理员身份执行，按外键顺序级联清除。
do $$
begin
  create temp table _bad_users on commit drop as
    select id from public.profiles
     where username = 'sectest_0914'
        or username like 'probe\_sec\_%' escape '\'
        or username like 'probe2\_%' escape '\';

  -- 解除「无级联」外键：审核记录置空
  update public.task_claims set reviewer_id = null
   where reviewer_id in (select id from _bad_users);
  -- 订单：本人购买 + 其创建商品的订单
  delete from public.orders
   where user_id in (select id from _bad_users)
      or product_id in (select p.id from public.products p
                         join _bad_users b on p.creator_id = b.id);
  -- migration 扩展表：存在才删，避免某表缺失导致整块回滚
  if to_regclass('public.resell_bids') is not null then
    delete from public.resell_bids where bidder_id in (select id from _bad_users);
  end if;
  if to_regclass('public.resell_listings') is not null then
    delete from public.resell_listings where seller_id in (select id from _bad_users);
  end if;
  if to_regclass('public.inventory') is not null then
    delete from public.inventory where user_id in (select id from _bad_users);
  end if;
  if to_regclass('public.pills') is not null then
    delete from public.pills where seller_id in (select id from _bad_users);
  end if;
  delete from public.task_claims        where user_id in (select id from _bad_users);
  delete from public.tasks              where creator_id in (select id from _bad_users);
  delete from public.products           where creator_id in (select id from _bad_users);
  delete from public.wallet_transactions where user_id in (select id from _bad_users);
  delete from public.transfers
   where sender_id in (select id from _bad_users) or receiver_id in (select id from _bad_users);
  delete from public.wallets            where user_id in (select id from _bad_users);
  -- 认证身份 + profile + 账号
  delete from auth.identities where user_id in (select id from _bad_users);
  delete from public.profiles where id in (select id from _bad_users);
  delete from auth.users where id in (select id from _bad_users);
exception when others then
  raise notice '清理非法账号时出现问题（可手动处理）：%', sqlerrm;
end $$;


-- ============================================================
-- 20. 自检（执行后看下面三个查询的结果）
-- ============================================================
-- 20.1 应只剩 可爱小猪=owner、子圣-798=admin；sectest_0914 / probe_* 非法账号已删除
select username, role, status, qi from public.profiles order by role, username;

-- 20.2 profiles 对 authenticated 的 UPDATE 列授权，应只有 username/avatar/original_username
select grantee, column_name from information_schema.column_privileges
where table_schema='public' and table_name='profiles'
  and grantee='authenticated' and privilege_type='UPDATE'
order by column_name;

-- 20.3 各表策略数量总览（确认都已重建）
select tablename, count(*) as policies from pg_policies
where schemaname='public' group by tablename order by tablename;


-- ============================================================
-- 【执行完后，还要去 Supabase 控制台手动做 3 件事】
--
-- A. 轮换宗主密码（假定已泄露）
--    Authentication → Users → 可爱小猪 → 改密码。
--    并通知其他真实用户自行改密（改密走前端 auth.updateUser，不受影响）。
--
-- B. 关闭自助注册（强烈建议）
--    Authentication → Sign In / Providers → Email →
--    关闭「Allow new users to sign up」。
--    现在任何人都能直接调 auth.signUp 拿普通账号作为提权起点，
--    注册页的邀请码只是前端校验，可被绕过。关闭后新账号由你在后台建。
--
-- C. 确认 testuser001 是否你的账号
--    sectest_0914 / probe_* 已在 19.2 直接删除。testuser001 若不是你自己的号，执行：
--      delete from auth.identities where user_id in
--        (select id from public.profiles where username='testuser001');
--      delete from auth.users u using public.profiles p
--      where u.id = p.id and p.username = 'testuser001';
--
-- 【加固后这些功能仍然正常（已按前端真实写路径放行）】
--   · 本人改道号/头像；管理员发任务/上下架商品/发丹药/审核任务
--   · 用户领取/提交任务、撤销自己的转售挂单、使用丹药改物品状态
--   · 转账/兑换/买药/审批发币等全部走服务端 RPC，不受影响
--   · 未登录仍可浏览修仙界、任务、仙市（公开读策略保留）
--   · 游客可评论但强制进待审核
-- ============================================================
