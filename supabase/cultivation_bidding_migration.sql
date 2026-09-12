-- ============================================================
-- 炒币市场竞价功能迁移
-- ============================================================

-- 0. 修改 wallet_transactions 表的 type 约束，添加竞价相关类型
alter table public.wallet_transactions drop constraint if exists wallet_transactions_type_check;
alter table public.wallet_transactions add constraint wallet_transactions_type_check check (type in (
  'task_reward', 'shop_redeem', 'shop_refund', 'shop_sale',
  'pill_purchase', 'pill_sale', 'pill_resell',
  'transfer_in', 'transfer_out', 'admin_adjust',
  'bid_freeze', 'bid_refund', 'resell_sale'
));

-- 0.1 给 inventory 表添加 acquired_at 字段
alter table public.inventory add column if not exists acquired_at timestamptz;

-- 1. 新建竞价表
create table if not exists public.resell_bids (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.resell_listings(id) on delete cascade,
  bidder_id uuid not null references public.profiles(id) on delete cascade,
  bid_price integer not null check (bid_price > 0),
  status text not null default 'active' check (status in ('active', 'won', 'lost', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists resell_bids_listing_idx on public.resell_bids (listing_id);
create index if not exists resell_bids_bidder_idx on public.resell_bids (bidder_id);
create index if not exists resell_bids_status_idx on public.resell_bids (status);

-- 2. 修改 resell_listings 表，添加竞价相关字段
alter table public.resell_listings 
  add column if not exists max_bidders integer not null default 5,
  add column if not exists current_highest_bid integer,
  add column if not exists bidding_ends_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

-- 3. 启用 RLS
alter table public.resell_bids enable row level security;

-- 竞价表 RLS 策略
drop policy if exists "resell bids read own or listing" on public.resell_bids;
create policy "resell bids read own or listing" on public.resell_bids
  for select using (
    bidder_id = auth.uid() or 
    exists (select 1 from public.resell_listings rl where rl.id = listing_id and rl.seller_id = auth.uid())
  );

drop policy if exists "resell bids insert own" on public.resell_bids;
create policy "resell bids insert own" on public.resell_bids
  for insert with check (bidder_id = auth.uid());

drop policy if exists "resell bids update own" on public.resell_bids;
create policy "resell bids update own" on public.resell_bids
  for update using (bidder_id = auth.uid());

-- ============================================================
-- RPC 函数：参与竞价
-- ============================================================
create or replace function public.place_resell_bid(p_listing_id uuid, p_bid_price integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing resell_listings;
  v_bidder_id uuid := auth.uid();
  v_bidder_wallet wallets;
  v_existing_bid resell_bids;
  v_active_bid_count integer;
  v_highest_bid integer;
  v_result jsonb;
begin
  -- 检查登录
  if v_bidder_id is null then
    return jsonb_build_object('success', false, 'error', '请先登录');
  end if;

  -- 检查转售商品
  select * into v_listing from resell_listings where id = p_listing_id;
  if not found then
    return jsonb_build_object('success', false, 'error', '商品不存在');
  end if;

  if v_listing.status != 'active' then
    return jsonb_build_object('success', false, 'error', '该商品已结束竞价');
  end if;

  if v_listing.seller_id = v_bidder_id then
    return jsonb_build_object('success', false, 'error', '不能对自己的商品竞价');
  end if;

  if p_bid_price < v_listing.price then
    return jsonb_build_object('success', false, 'error', '竞价价格不能低于基础价格 ' || v_listing.price);
  end if;

  -- 获取当前最高价
  select coalesce(max(bid_price), 0) into v_highest_bid 
  from resell_bids 
  where listing_id = p_listing_id and status = 'active';

  if p_bid_price <= v_highest_bid then
    return jsonb_build_object('success', false, 'error', '竞价价格必须高于当前最高价');
  end if;

  -- 检查竞价者是否已经竞价过
  select * into v_existing_bid 
  from resell_bids 
  where listing_id = p_listing_id and bidder_id = v_bidder_id and status = 'active';

  if found then
    -- 更新已有竞价
    -- 先退回之前的灵石
    update wallets 
    set coins = coins + v_existing_bid.bid_price, updated_at = now() 
    where user_id = v_bidder_id;

    -- 标记旧竞价为取消
    update resell_bids 
    set status = 'cancelled', updated_at = now() 
    where id = v_existing_bid.id;
  end if;

  -- 检查当前活跃竞价人数（排除已取消的）
  select count(*) into v_active_bid_count 
  from resell_bids 
  where listing_id = p_listing_id and status = 'active';

  if v_active_bid_count >= v_listing.max_bidders then
    -- 退回刚才的退款（如果是更新竞价）
    if found then
      update wallets 
      set coins = coins - v_existing_bid.bid_price, updated_at = now() 
      where user_id = v_bidder_id;
      update resell_bids 
      set status = 'active', updated_at = now() 
      where id = v_existing_bid.id;
    end if;
    return jsonb_build_object('success', false, 'error', '竞价人数已满（最多' || v_listing.max_bidders || '人）');
  end if;

  -- 检查竞价者余额
  select * into v_bidder_wallet from wallets where user_id = v_bidder_id;
  if not found or v_bidder_wallet.coins < p_bid_price then
    -- 退回刚才的退款（如果是更新竞价）
    if found then
      update wallets 
      set coins = coins - v_existing_bid.bid_price, updated_at = now() 
      where user_id = v_bidder_id;
      update resell_bids 
      set status = 'active', updated_at = now() 
      where id = v_existing_bid.id;
    end if;
    return jsonb_build_object('success', false, 'error', '灵石余额不足');
  end if;

  -- 扣除灵石
  update wallets 
  set coins = coins - p_bid_price, updated_at = now() 
  where user_id = v_bidder_id;

  -- 记录灵石流水（冻结）
  insert into wallet_transactions (user_id, type, amount, related_id, description)
  values (v_bidder_id, 'bid_freeze', -p_bid_price, p_listing_id, '竞价冻结：' || v_listing.pill_name);

  -- 创建竞价记录
  insert into resell_bids (listing_id, bidder_id, bid_price, status)
  values (p_listing_id, v_bidder_id, p_bid_price, 'active');

  -- 更新转售商品的当前最高价
  update resell_listings 
  set current_highest_bid = p_bid_price, updated_at = now() 
  where id = p_listing_id;

  v_result := jsonb_build_object(
    'success', true,
    'message', '竞价成功',
    'bid_price', p_bid_price,
    'remaining_coins', v_bidder_wallet.coins - p_bid_price
  );

  return v_result;
end;
$$;

-- ============================================================
-- RPC 函数：结束竞价（卖家操作）
-- ============================================================
create or replace function public.end_resell_bidding(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing resell_listings;
  v_seller_id uuid := auth.uid();
  v_winning_bid resell_bids;
  v_seller_wallet wallets;
  v_result jsonb;
  v_bid record;
begin
  -- 检查登录
  if v_seller_id is null then
    return jsonb_build_object('success', false, 'error', '请先登录');
  end if;

  -- 检查转售商品
  select * into v_listing from resell_listings where id = p_listing_id;
  if not found then
    return jsonb_build_object('success', false, 'error', '商品不存在');
  end if;

  if v_listing.seller_id != v_seller_id then
    return jsonb_build_object('success', false, 'error', '只有卖家可以结束竞价');
  end if;

  if v_listing.status != 'active' then
    return jsonb_build_object('success', false, 'error', '该商品已结束竞价');
  end if;

  -- 获取最高竞价
  select * into v_winning_bid 
  from resell_bids 
  where listing_id = p_listing_id and status = 'active'
  order by bid_price desc
  limit 1;

  if not found then
    -- 没有竞价，直接取消
    update resell_listings set status = 'cancelled', updated_at = now() where id = p_listing_id;
    update inventory set status = 'owned', resell_price = null, listed_at = null where id = v_listing.inventory_id;
    return jsonb_build_object('success', true, 'message', '无人竞价，已取消上架');
  end if;

  -- 标记成功者
  update resell_bids 
  set status = 'won', updated_at = now() 
  where id = v_winning_bid.id;

  -- 退回其他竞价者的灵石
  for v_bid in 
    select * from resell_bids 
    where listing_id = p_listing_id and status = 'active'
  loop
    -- 退回灵石
    update wallets 
    set coins = coins + v_bid.bid_price, updated_at = now() 
    where user_id = v_bid.bidder_id;

    -- 记录流水
    insert into wallet_transactions (user_id, type, amount, related_id, description)
    values (v_bid.bidder_id, 'bid_refund', v_bid.bid_price, p_listing_id, '竞价失败退回：' || v_listing.pill_name);

    -- 标记为失败
    update resell_bids 
    set status = 'lost', updated_at = now() 
    where id = v_bid.id;
  end loop;

  -- 给卖家增加灵石
  update wallets 
  set coins = coins + v_winning_bid.bid_price, updated_at = now() 
  where user_id = v_seller_id;

  -- 记录卖家收入
  insert into wallet_transactions (user_id, type, amount, related_id, description)
  values (v_seller_id, 'resell_sale', v_winning_bid.bid_price, p_listing_id, '转售成交：' || v_listing.pill_name);

  -- 更新转售商品状态
  update resell_listings 
  set status = 'sold', sold_at = now(), current_highest_bid = v_winning_bid.bid_price, updated_at = now() 
  where id = p_listing_id;

  -- 转移物品所有权给竞价成功者
  update inventory 
  set user_id = v_winning_bid.bidder_id, status = 'owned', resell_price = null, listed_at = null, acquired_at = now()
  where id = v_listing.inventory_id;

  v_result := jsonb_build_object(
    'success', true,
    'message', '竞价结束，成交价格：' || v_winning_bid.bid_price || ' 灵石',
    'final_price', v_winning_bid.bid_price,
    'winner_id', v_winning_bid.bidder_id
  );

  return v_result;
end;
$$;

-- ============================================================
-- RPC 函数：取消竞价（竞价者操作）
-- ============================================================
create or replace function public.cancel_resell_bid(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bidder_id uuid := auth.uid();
  v_bid resell_bids;
  v_listing resell_listings;
  v_new_highest integer;
begin
  if v_bidder_id is null then
    return jsonb_build_object('success', false, 'error', '请先登录');
  end if;

  select * into v_bid 
  from resell_bids 
  where listing_id = p_listing_id and bidder_id = v_bidder_id and status = 'active';

  if not found then
    return jsonb_build_object('success', false, 'error', '您没有进行中的竞价');
  end if;

  select * into v_listing from resell_listings where id = p_listing_id;
  if v_listing.status != 'active' then
    return jsonb_build_object('success', false, 'error', '竞价已结束，无法取消');
  end if;

  -- 退回灵石
  update wallets 
  set coins = coins + v_bid.bid_price, updated_at = now() 
  where user_id = v_bidder_id;

  insert into wallet_transactions (user_id, type, amount, related_id, description)
  values (v_bidder_id, 'bid_refund', v_bid.bid_price, p_listing_id, '取消竞价退回：' || v_listing.pill_name);

  -- 标记为取消
  update resell_bids 
  set status = 'cancelled', updated_at = now() 
  where id = v_bid.id;

  -- 更新当前最高价
  select coalesce(max(bid_price), 0) into v_new_highest 
  from resell_bids 
  where listing_id = p_listing_id and status = 'active';

  update resell_listings 
  set current_highest_bid = case when v_new_highest > 0 then v_new_highest else null end, updated_at = now() 
  where id = p_listing_id;

  return jsonb_build_object('success', true, 'message', '已取消竞价，灵石已退回');
end;
$$;

-- ============================================================
-- RPC 函数：获取竞价信息（不显示具体金额，只显示人数和自己的竞价）
-- ============================================================
create or replace function public.get_resell_bid_info(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_active_count integer;
  v_my_bid resell_bids;
  v_listing resell_listings;
  v_is_seller boolean;
begin
  select * into v_listing from resell_listings where id = p_listing_id;
  if not found then
    return jsonb_build_object('success', false, 'error', '商品不存在');
  end if;

  v_is_seller := (v_listing.seller_id = v_user_id);

  select count(*) into v_active_count 
  from resell_bids 
  where listing_id = p_listing_id and status = 'active';

  if v_user_id is not null then
    select * into v_my_bid 
    from resell_bids 
    where listing_id = p_listing_id and bidder_id = v_user_id and status = 'active';
  end if;

  return jsonb_build_object(
    'success', true,
    'active_bid_count', v_active_count,
    'max_bidders', v_listing.max_bidders,
    'is_seller', v_is_seller,
    'my_bid_price', case when v_my_bid.id is not null then v_my_bid.bid_price else null end,
    'has_my_bid', v_my_bid.id is not null,
    'listing_status', v_listing.status,
    'base_price', v_listing.price
  );
end;
$$;
