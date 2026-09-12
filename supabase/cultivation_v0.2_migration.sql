-- ============================================================
-- 修仙系统 V0.2 迁移：灵气系统 + 丹药系统 + 储物袋
-- ============================================================

-- 1. profiles 表新增灵气字段
alter table public.profiles add column if not exists qi integer not null default 0 check (qi >= 0);

-- 2. task_claims 表新增获得灵气字段
alter table public.task_claims add column if not exists qi_earned integer not null default 0;

-- 3. wallet_transactions 表新增交易类型
alter table public.wallet_transactions drop constraint if exists wallet_transactions_type_check;
alter table public.wallet_transactions add constraint wallet_transactions_type_check check (type in (
  'task_reward', 'shop_redeem', 'transfer_in', 'transfer_out', 'admin_adjust',
  'pill_purchase', 'pill_sale', 'pill_resell'
));

-- 4. 新增丹药表
create table if not exists public.pills (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  grade       integer not null check (grade between 1 and 5),
  description text not null default '',
  qi_bonus    integer not null check (qi_bonus > 0),
  price       integer not null check (price > 0),
  seller_id   uuid not null references public.profiles(id) on delete cascade,
  status      text not null default 'active' check (status in ('active', 'sold', 'offline')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists pills_status_idx on public.pills (status);
create index if not exists pills_seller_idx on public.pills (seller_id);
create index if not exists pills_grade_idx on public.pills (grade);

-- 5. 新增储物袋表
create table if not exists public.inventory (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  item_type   text not null check (item_type in ('pill')),
  pill_id     uuid references public.pills(id) on delete set null,
  pill_name   text not null,
  pill_grade  integer not null,
  pill_qi_bonus integer not null,
  quantity    integer not null default 1 check (quantity > 0),
  status      text not null default 'owned' check (status in ('owned', 'used', 'listed')),
  resell_price integer,
  obtained_at timestamptz not null default now(),
  used_at     timestamptz,
  listed_at   timestamptz
);

create index if not exists inventory_user_idx on public.inventory (user_id);
create index if not exists inventory_status_idx on public.inventory (status);

-- 6. 新增转售市场表（用户转售的丹药）
create table if not exists public.resell_listings (
  id           uuid primary key default gen_random_uuid(),
  inventory_id uuid not null references public.inventory(id) on delete cascade,
  seller_id    uuid not null references public.profiles(id) on delete cascade,
  pill_name    text not null,
  pill_grade   integer not null,
  pill_qi_bonus integer not null,
  price        integer not null check (price > 0),
  status       text not null default 'active' check (status in ('active', 'sold', 'cancelled')),
  created_at   timestamptz not null default now(),
  sold_at      timestamptz
);

create index if not exists resell_status_idx on public.resell_listings (status);
create index if not exists resell_seller_idx on public.resell_listings (seller_id);

-- ============================================================
-- RLS 策略
-- ============================================================

-- pills 表
alter table public.pills enable row level security;

drop policy if exists "pills read active" on public.pills;
create policy "pills read active" on public.pills
  for select using (status = 'active' or seller_id = auth.uid() or exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

drop policy if exists "pills insert owner" on public.pills;
create policy "pills insert owner" on public.pills
  for insert with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'owner'));

drop policy if exists "pills update owner" on public.pills;
create policy "pills update owner" on public.pills
  for update using (exists (select 1 from public.profiles where id = auth.uid() and role = 'owner'));

-- inventory 表
alter table public.inventory enable row level security;

drop policy if exists "inventory read own" on public.inventory;
create policy "inventory read own" on public.inventory
  for select using (user_id = auth.uid());

drop policy if exists "inventory insert own" on public.inventory;
create policy "inventory insert own" on public.inventory
  for insert with check (user_id = auth.uid());

drop policy if exists "inventory update own" on public.inventory;
create policy "inventory update own" on public.inventory
  for update using (user_id = auth.uid());

-- resell_listings 表
alter table public.resell_listings enable row level security;

drop policy if exists "resell read active" on public.resell_listings;
create policy "resell read active" on public.resell_listings
  for select using (status = 'active' or seller_id = auth.uid() or exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

drop policy if exists "resell insert own" on public.resell_listings;
create policy "resell insert own" on public.resell_listings
  for insert with check (seller_id = auth.uid());

drop policy if exists "resell update own" on public.resell_listings;
create policy "resell update own" on public.resell_listings
  for update using (seller_id = auth.uid() or exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

-- ============================================================
-- RPC 函数
-- ============================================================

-- 使用丹药
create or replace function public.use_pill(p_inventory_id uuid)
returns json language plpgsql security definer as $$
declare
  v_inventory public.inventory;
  v_new_qi integer;
begin
  -- 查找储物袋物品
  select * into v_inventory from public.inventory where id = p_inventory_id and user_id = auth.uid();
  if not found then
    return json_build_object('success', false, 'error', '物品不存在');
  end if;

  if v_inventory.status != 'owned' then
    return json_build_object('success', false, 'error', '物品状态不正确');
  end if;

  -- 增加灵气
  update public.profiles set qi = qi + v_inventory.pill_qi_bonus, updated_at = now() where id = auth.uid() returning qi into v_new_qi;

  -- 根据数量处理：数量为1则删除，否则减1
  if v_inventory.quantity <= 1 then
    delete from public.inventory where id = p_inventory_id;
  else
    update public.inventory set quantity = quantity - 1, updated_at = now() where id = p_inventory_id;
  end if;

  return json_build_object('success', true, 'qi_earned', v_inventory.pill_qi_bonus, 'new_qi', v_new_qi);
end;
$$;

-- 购买丹药（官方商城）
create or replace function public.buy_pill(p_pill_id uuid)
returns json language plpgsql security definer as $$
declare
  v_pill public.pills;
  v_wallet public.wallets;
  v_new_coins integer;
  v_inventory_id uuid;
begin
  -- 查找丹药
  select * into v_pill from public.pills where id = p_pill_id and status = 'active';
  if not found then
    return json_build_object('success', false, 'error', '丹药不存在或已售罄');
  end if;

  -- 检查钱包
  select * into v_wallet from public.wallets where user_id = auth.uid();
  if not found then
    return json_build_object('success', false, 'error', '钱包不存在');
  end if;

  if v_wallet.coins < v_pill.price then
    return json_build_object('success', false, 'error', '灵石不足');
  end if;

  -- 扣除灵石
  v_new_coins := v_wallet.coins - v_pill.price;
  update public.wallets set coins = v_new_coins, updated_at = now() where user_id = auth.uid();

  -- 记录流水
  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (auth.uid(), -v_pill.price, 'pill_purchase', '购买丹药: ' || v_pill.name, v_pill.id);

  -- 添加到储物袋（检查是否已有相同丹药）
  insert into public.inventory (user_id, item_type, pill_id, pill_name, pill_grade, pill_qi_bonus, quantity)
  values (auth.uid(), 'pill', v_pill.id, v_pill.name, v_pill.grade, v_pill.qi_bonus, 1)
  returning id into v_inventory_id;

  return json_build_object('success', true, 'inventory_id', v_inventory_id, 'remaining_coins', v_new_coins);
end;
$$;

-- 上架转售丹药
create or replace function public.list_pill_for_resell(p_inventory_id uuid, p_price integer)
returns json language plpgsql security definer as $$
declare
  v_inventory public.inventory;
  v_listing_id uuid;
begin
  if p_price <= 0 then
    return json_build_object('success', false, 'error', '价格必须大于0');
  end if;

  select * into v_inventory from public.inventory where id = p_inventory_id and user_id = auth.uid();
  if not found then
    return json_build_object('success', false, 'error', '物品不存在');
  end if;

  if v_inventory.status != 'owned' then
    return json_build_object('success', false, 'error', '物品状态不正确');
  end if;

  -- 更新储物袋状态
  update public.inventory set status = 'listed', resell_price = p_price, listed_at = now() where id = p_inventory_id;

  -- 创建转售列表
  insert into public.resell_listings (inventory_id, seller_id, pill_name, pill_grade, pill_qi_bonus, price)
  values (p_inventory_id, auth.uid(), v_inventory.pill_name, v_inventory.pill_grade, v_inventory.pill_qi_bonus, p_price)
  returning id into v_listing_id;

  return json_build_object('success', true, 'listing_id', v_listing_id);
end;
$$;

-- 取消转售
create or replace function public.cancel_resell(p_listing_id uuid)
returns json language plpgsql security definer as $$
declare
  v_listing public.resell_listings;
begin
  select * into v_listing from public.resell_listings where id = p_listing_id and seller_id = auth.uid();
  if not found then
    return json_build_object('success', false, 'error', '转售记录不存在');
  end if;

  if v_listing.status != 'active' then
    return json_build_object('success', false, 'error', '转售状态不正确');
  end if;

  update public.resell_listings set status = 'cancelled' where id = p_listing_id;
  update public.inventory set status = 'owned', resell_price = null, listed_at = null where id = v_listing.inventory_id;

  return json_build_object('success', true);
end;
$$;

-- 购买转售丹药
create or replace function public.buy_resell_pill(p_listing_id uuid)
returns json language plpgsql security definer as $$
declare
  v_listing public.resell_listings;
  v_buyer_wallet public.wallets;
  v_seller_wallet public.wallets;
  v_new_buyer_coins integer;
  v_new_seller_coins integer;
  v_inventory_id uuid;
begin
  select * into v_listing from public.resell_listings where id = p_listing_id and status = 'active';
  if not found then
    return json_build_object('success', false, 'error', '转售记录不存在或已售出');
  end if;

  if v_listing.seller_id = auth.uid() then
    return json_build_object('success', false, 'error', '不能购买自己的丹药');
  end if;

  select * into v_buyer_wallet from public.wallets where user_id = auth.uid();
  if not found then
    return json_build_object('success', false, 'error', '钱包不存在');
  end if;

  if v_buyer_wallet.coins < v_listing.price then
    return json_build_object('success', false, 'error', '灵石不足');
  end if;

  -- 扣除买家灵石
  v_new_buyer_coins := v_buyer_wallet.coins - v_listing.price;
  update public.wallets set coins = v_new_buyer_coins, updated_at = now() where user_id = auth.uid();

  -- 增加卖家灵石
  select * into v_seller_wallet from public.wallets where user_id = v_listing.seller_id;
  if found then
    v_new_seller_coins := v_seller_wallet.coins + v_listing.price;
    update public.wallets set coins = v_new_seller_coins, updated_at = now() where user_id = v_listing.seller_id;
  end if;

  -- 记录流水
  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (auth.uid(), -v_listing.price, 'pill_purchase', '购买转售丹药: ' || v_listing.pill_name, v_listing.id);

  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (v_listing.seller_id, v_listing.price, 'pill_sale', '出售丹药: ' || v_listing.pill_name, v_listing.id);

  -- 更新转售状态
  update public.resell_listings set status = 'sold', sold_at = now() where id = p_listing_id;

  -- 更新原储物袋状态（标记为已售出）
  update public.inventory set status = 'used', used_at = now() where id = v_listing.inventory_id;

  -- 添加到买家储物袋
  insert into public.inventory (user_id, item_type, pill_id, pill_name, pill_grade, pill_qi_bonus, quantity)
  values (auth.uid(), 'pill', null, v_listing.pill_name, v_listing.pill_grade, v_listing.pill_qi_bonus, 1)
  returning id into v_inventory_id;

  return json_build_object('success', true, 'inventory_id', v_inventory_id, 'remaining_coins', v_new_buyer_coins);
end;
$$;

-- 完成任务时随机获得灵气
create or replace function public.approve_task_with_qi(p_claim_id uuid, p_review_note text default null)
returns json language plpgsql security definer as $$
declare
  v_claim public.task_claims;
  v_task public.tasks;
  v_random_qi integer;
  v_new_qi integer;
begin
  select * into v_claim from public.task_claims where id = p_claim_id;
  if not found then
    return json_build_object('success', false, 'error', '任务领取记录不存在');
  end if;

  if v_claim.status != 'submitted' then
    return json_build_object('success', false, 'error', '任务状态不正确');
  end if;

  select * into v_task from public.tasks where id = v_claim.task_id;
  if not found then
    return json_build_object('success', false, 'error', '任务不存在');
  end if;

  -- 随机获得灵气：基础10-50，与任务奖励灵石相关
  v_random_qi := floor(random() * (v_task.reward_coins / 2 + 40)) + 10;

  -- 更新任务领取状态，保存审核备注
  update public.task_claims 
  set status = 'approved', 
      qi_earned = v_random_qi, 
      review_note = coalesce(p_review_note, review_note)
  where id = p_claim_id;

  -- 增加灵石
  update public.wallets set coins = coins + v_task.reward_coins, updated_at = now() where user_id = v_claim.user_id;

  -- 增加灵气
  update public.profiles set qi = qi + v_random_qi, updated_at = now() where id = v_claim.user_id returning qi into v_new_qi;

  -- 记录流水
  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (v_claim.user_id, v_task.reward_coins, 'task_reward', '任务奖励: ' || v_task.title, v_claim.id);

  return json_build_object('success', true, 'reward', v_task.reward_coins, 'qi_earned', v_random_qi, 'new_qi', v_new_qi);
end;
$$;
