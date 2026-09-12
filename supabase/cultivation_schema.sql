-- ============================================================
-- FreeX 修仙系统 V0.1 数据库 Schema
-- ============================================================

-- 启用扩展
create extension if not exists "pgcrypto";

-- ============================================================
-- 1. profiles 用户资料表
-- ============================================================
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text unique not null,
  avatar      text,
  role        text not null default 'user' check (role in ('owner', 'admin', 'user')),
  status      text not null default 'active' check (status in ('active', 'disabled')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists profiles_role_idx   on public.profiles (role);
create index if not exists profiles_status_idx on public.profiles (status);

-- ============================================================
-- 2. wallets 钱包表
-- ============================================================
create table if not exists public.wallets (
  user_id     uuid primary key references public.profiles(id) on delete cascade,
  coins       integer not null default 0 check (coins >= 0),
  updated_at  timestamptz not null default now()
);

-- ============================================================
-- 3. wallet_transactions 灵石流水表
-- ============================================================
create table if not exists public.wallet_transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  amount      integer not null,
  type        text not null check (type in ('task_reward', 'shop_redeem', 'shop_refund', 'shop_sale', 'pill_purchase', 'pill_sale', 'transfer_in', 'transfer_out', 'admin_adjust')),
  description text,
  related_id  uuid,
  created_at  timestamptz not null default now()
);

create index if not exists wt_user_id_idx    on public.wallet_transactions (user_id);
create index if not exists wt_created_at_idx on public.wallet_transactions (created_at desc);

-- ============================================================
-- 4. tasks 任务表
-- ============================================================
create table if not exists public.tasks (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  description   text not null default '',
  reward_coins  integer not null check (reward_coins > 0),
  creator_id    uuid not null references public.profiles(id),
  status        text not null default 'published' check (status in ('draft', 'published', 'offline')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists tasks_status_idx     on public.tasks (status);
create index if not exists tasks_creator_idx    on public.tasks (creator_id);
create index if not exists tasks_created_at_idx on public.tasks (created_at desc);

-- ============================================================
-- 5. task_claims 任务领取/提交记录表
-- ============================================================
create table if not exists public.task_claims (
  id             uuid primary key default gen_random_uuid(),
  task_id        uuid not null references public.tasks(id) on delete cascade,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  status         text not null default 'claimed' check (status in ('claimed', 'submitted', 'approved', 'rejected')),
  proof_text     text,
  proof_images   text[] default '{}',
  submitted_at   timestamptz,
  reviewed_at    timestamptz,
  reviewer_id    uuid references public.profiles(id),
  review_note    text,
  reward_status  text not null default 'pending' check (reward_status in ('pending', 'paid', 'failed')),
  reward_amount  integer,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (task_id, user_id)
);

create index if not exists tc_task_id_idx   on public.task_claims (task_id);
create index if not exists tc_user_id_idx   on public.task_claims (user_id);
create index if not exists tc_status_idx    on public.task_claims (status);
create index if not exists tc_created_idx   on public.task_claims (created_at desc);

-- ============================================================
-- 6. products 商城商品表
-- ============================================================
create table if not exists public.products (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text not null default '',
  image_url   text,
  price       integer not null check (price > 0),
  status      text not null default 'active' check (status in ('active', 'inactive')),
  creator_id  uuid not null references public.profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists products_status_idx on public.products (status);

-- ============================================================
-- 7. orders 兑换订单表
-- ============================================================
create table if not exists public.orders (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  product_id  uuid not null references public.products(id),
  price       integer not null check (price > 0),
  status      text not null default 'completed' check (status in ('pending', 'completed', 'cancelled', 'fulfilled')),
  created_at  timestamptz not null default now()
);

create index if not exists orders_user_id_idx on public.orders (user_id);
create index if not exists orders_created_idx on public.orders (created_at desc);

-- ============================================================
-- 8. transfers 转赠记录表
-- ============================================================
create table if not exists public.transfers (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  amount      integer not null check (amount > 0),
  note        text,
  created_at  timestamptz not null default now(),
  check (sender_id != receiver_id)
);

create index if not exists transfers_sender_idx   on public.transfers (sender_id);
create index if not exists transfers_receiver_idx on public.transfers (receiver_id);
create index if not exists transfers_created_idx  on public.transfers (created_at desc);

-- ============================================================
-- 触发器：自动更新 updated_at
-- ============================================================
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at before update on public.tasks
  for each row execute function public.set_updated_at();

drop trigger if exists task_claims_set_updated_at on public.task_claims;
create trigger task_claims_set_updated_at before update on public.task_claims
  for each row execute function public.set_updated_at();

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists wallets_set_updated_at on public.wallets;
create trigger wallets_set_updated_at before update on public.wallets
  for each row execute function public.set_updated_at();

-- ============================================================
-- 触发器：新用户注册后自动创建 profile 和 wallet
-- ============================================================
create or replace function public.handle_new_user()
returns trigger as $$
declare
  new_username text;
begin
  -- 从 email 或 raw_user_meta_data 中获取 username
  new_username := coalesce(
    new.raw_user_meta_data->>'username',
    split_part(new.email, '@', 1),
    'user_' || substr(new.id::text, 1, 8)
  );

  -- 确保 username 唯一
  while exists (select 1 from public.profiles where username = new_username) loop
    new_username := new_username || '_' || substr(gen_random_uuid()::text, 1, 4);
  end loop;

  -- 创建 profile
  insert into public.profiles (id, username, role, status)
  values (new.id, new_username, 'user', 'active');

  -- 创建 wallet
  insert into public.wallets (user_id, coins)
  values (new.id, 0);

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- RPC 函数：转赠灵石（原子操作）
-- ============================================================
create or replace function public.transfer_coins(
  p_receiver_id uuid,
  p_amount integer,
  p_note text default null
)
returns json as $$
declare
  v_sender_id uuid := auth.uid();
  v_sender_balance integer;
  v_receiver_exists boolean;
  v_transfer_id uuid;
begin
  -- 验证参数
  if p_receiver_id is null then
    return json_build_object('success', false, 'error', '接收者不能为空');
  end if;

  if p_amount is null or p_amount <= 0 then
    return json_build_object('success', false, 'error', '转赠数量必须大于0');
  end if;

  if v_sender_id = p_receiver_id then
    return json_build_object('success', false, 'error', '不能转赠给自己');
  end if;

  -- 检查发送者状态
  if not exists (select 1 from public.profiles where id = v_sender_id and status = 'active') then
    return json_build_object('success', false, 'error', '账户状态异常');
  end if;

  -- 检查接收者是否存在且活跃
  select exists(select 1 from public.profiles where id = p_receiver_id and status = 'active') into v_receiver_exists;
  if not v_receiver_exists then
    return json_build_object('success', false, 'error', '接收者不存在或已被停用');
  end if;

  -- 检查余额并扣款（行锁）
  select coins into v_sender_balance
  from public.wallets
  where user_id = v_sender_id
  for update;

  if v_sender_balance is null then
    return json_build_object('success', false, 'error', '钱包不存在');
  end if;

  if v_sender_balance < p_amount then
    return json_build_object('success', false, 'error', '灵石余额不足');
  end if;

  -- 扣款
  update public.wallets set coins = coins - p_amount where user_id = v_sender_id;

  -- 收款
  update public.wallets set coins = coins + p_amount where user_id = p_receiver_id;

  -- 创建转赠记录
  insert into public.transfers (sender_id, receiver_id, amount, note)
  values (v_sender_id, p_receiver_id, p_amount, p_note)
  returning id into v_transfer_id;

  -- 发送者流水
  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (v_sender_id, -p_amount, 'transfer_out', '转赠给 ' || (select username from public.profiles where id = p_receiver_id), v_transfer_id);

  -- 接收者流水
  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (p_receiver_id, p_amount, 'transfer_in', '收到 ' || (select username from public.profiles where id = v_sender_id) || ' 转赠', v_transfer_id);

  return json_build_object('success', true, 'transfer_id', v_transfer_id);
end;
$$ language plpgsql security definer;

-- ============================================================
-- RPC 函数：审核任务通过并发放奖励（原子操作）
-- ============================================================
create or replace function public.approve_task_claim(
  p_claim_id uuid,
  p_review_note text default null
)
returns json as $$
declare
  v_reviewer_id uuid := auth.uid();
  v_claim record;
  v_task record;
  v_reviewer_role text;
begin
  -- 获取领取记录
  select * into v_claim from public.task_claims where id = p_claim_id;
  if v_claim is null then
    return json_build_object('success', false, 'error', '任务记录不存在');
  end if;

  if v_claim.status != 'submitted' then
    return json_build_object('success', false, 'error', '当前状态不能审核');
  end if;

  if v_claim.reward_status = 'paid' then
    return json_build_object('success', false, 'error', '奖励已发放，不能重复审核');
  end if;

  -- 获取任务信息
  select * into v_task from public.tasks where id = v_claim.task_id;
  if v_task is null then
    return json_build_object('success', false, 'error', '任务不存在');
  end if;

  -- 检查审核者权限
  select role into v_reviewer_role from public.profiles where id = v_reviewer_id;
  if v_reviewer_role not in ('owner', 'admin') then
    return json_build_object('success', false, 'error', '没有审核权限');
  end if;

  -- 更新领取记录
  update public.task_claims
  set status = 'approved',
      reviewed_at = now(),
      reviewer_id = v_reviewer_id,
      review_note = p_review_note,
      reward_status = 'paid',
      reward_amount = v_task.reward_coins
  where id = p_claim_id;

  -- 发放奖励
  update public.wallets
  set coins = coins + v_task.reward_coins
  where user_id = v_claim.user_id;

  -- 创建流水
  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (v_claim.user_id, v_task.reward_coins, 'task_reward', '任务奖励：' || v_task.title, p_claim_id);

  return json_build_object('success', true, 'reward', v_task.reward_coins);
end;
$$ language plpgsql security definer;

-- ============================================================
-- RPC 函数：商城兑换（原子操作）
-- ============================================================
create or replace function public.redeem_product(
  p_product_id uuid
)
returns json as $$
declare
  v_user_id uuid := auth.uid();
  v_product record;
  v_balance integer;
  v_order_id uuid;
begin
  -- 获取商品
  select * into v_product from public.products where id = p_product_id;
  if v_product is null then
    return json_build_object('success', false, 'error', '商品不存在');
  end if;

  if v_product.status != 'active' then
    return json_build_object('success', false, 'error', '商品已下架');
  end if;

  -- 检查余额（行锁）
  select coins into v_balance from public.wallets where user_id = v_user_id for update;
  if v_balance is null then
    return json_build_object('success', false, 'error', '钱包不存在');
  end if;

  if v_balance < v_product.price then
    return json_build_object('success', false, 'error', '灵石余额不足');
  end if;

  -- 扣款
  update public.wallets set coins = coins - v_product.price where user_id = v_user_id;

  -- 创建订单
  insert into public.orders (user_id, product_id, price, status)
  values (v_user_id, p_product_id, v_product.price, 'completed')
  returning id into v_order_id;

  -- 创建流水
  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (v_user_id, -v_product.price, 'shop_redeem', '兑换：' || v_product.name, v_order_id);

  return json_build_object('success', true, 'order_id', v_order_id);
end;
$$ language plpgsql security definer;

-- ============================================================
-- RLS 策略
-- ============================================================
alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.tasks enable row level security;
alter table public.task_claims enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.transfers enable row level security;

-- profiles：所有人可读，自己可改，管理员可改
drop policy if exists "profiles read all" on public.profiles;
create policy "profiles read all" on public.profiles
  for select using (true);

drop policy if exists "profiles update self" on public.profiles;
create policy "profiles update self" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "profiles update by owner" on public.profiles;
create policy "profiles update by owner" on public.profiles
  for update using (exists (select 1 from public.profiles where id = auth.uid() and role = 'owner'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'owner'));

-- wallets：自己可读
drop policy if exists "wallets read own" on public.wallets;
create policy "wallets read own" on public.wallets
  for select using (auth.uid() = user_id);

-- wallet_transactions：自己可读
drop policy if exists "wt read own" on public.wallet_transactions;
create policy "wt read own" on public.wallet_transactions
  for select using (auth.uid() = user_id);

-- tasks：已发布的所有人可读，创建者可写，管理员可写
drop policy if exists "tasks read published" on public.tasks;
create policy "tasks read published" on public.tasks
  for select using (status = 'published' or auth.uid() = creator_id or exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

drop policy if exists "tasks insert admin" on public.tasks;
create policy "tasks insert admin" on public.tasks
  for insert with check (exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

drop policy if exists "tasks update creator" on public.tasks;
create policy "tasks update creator" on public.tasks
  for update using (auth.uid() = creator_id or exists (select 1 from public.profiles where id = auth.uid() and role = 'owner'));

-- task_claims：自己可读，管理员可读全部
drop policy if exists "tc read own" on public.task_claims;
create policy "tc read own" on public.task_claims
  for select using (auth.uid() = user_id or exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

drop policy if exists "tc insert user" on public.task_claims;
create policy "tc insert user" on public.task_claims
  for insert with check (auth.uid() = user_id);

drop policy if exists "tc update own" on public.task_claims;
create policy "tc update own" on public.task_claims
  for update using (auth.uid() = user_id or exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

-- products：上架的所有人可读
drop policy if exists "products read active" on public.products;
create policy "products read active" on public.products
  for select using (status = 'active' or exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

drop policy if exists "products insert admin" on public.products;
create policy "products insert admin" on public.products
  for insert with check (exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

drop policy if exists "products update admin" on public.products;
create policy "products update admin" on public.products
  for update using (exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

-- orders：自己可读
drop policy if exists "orders read own" on public.orders;
create policy "orders read own" on public.orders
  for select using (
    auth.uid() = user_id
    or exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin'))
    or exists (select 1 from public.products where id = orders.product_id and creator_id = auth.uid())
  );

drop policy if exists "orders insert user" on public.orders;
create policy "orders insert user" on public.orders
  for insert with check (auth.uid() = user_id);

-- transfers：发送者和接收者可读
drop policy if exists "transfers read involved" on public.transfers;
create policy "transfers read involved" on public.transfers
  for select using (auth.uid() = sender_id or auth.uid() = receiver_id or exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin')));

-- ============================================================
-- RPC 函数：删除用户（仅宗主可调用）
-- ============================================================
create or replace function public.delete_user(p_user_id uuid)
returns json as $$
declare
  v_current_role text;
  v_target_role text;
begin
  -- 检查当前用户角色
  select role into v_current_role from public.profiles where id = auth.uid();
  if v_current_role is null or v_current_role != 'owner' then
    return json_build_object('success', false, 'error', '只有宗主可以删除用户');
  end if;

  -- 不能删除自己
  if p_user_id = auth.uid() then
    return json_build_object('success', false, 'error', '不能删除自己');
  end if;

  -- 检查目标用户角色
  select role into v_target_role from public.profiles where id = p_user_id;
  if v_target_role is null then
    return json_build_object('success', false, 'error', '用户不存在');
  end if;

  -- 不能删除其他宗主
  if v_target_role = 'owner' then
    return json_build_object('success', false, 'error', '不能删除其他宗主');
  end if;

  -- 删除用户相关数据
  delete from public.wallet_transactions where user_id = p_user_id;
  delete from public.wallets where user_id = p_user_id;
  delete from public.task_claims where user_id = p_user_id;
  delete from public.orders where user_id = p_user_id;
  delete from public.transfers where sender_id = p_user_id or receiver_id = p_user_id;

  -- 删除 profile
  delete from public.profiles where id = p_user_id;

  -- 删除 auth 用户
  delete from auth.users where id = p_user_id;

  return json_build_object('success', true);
end;
$$ language plpgsql security definer;

-- ============================================================
-- 9. 订单流程：发货 / 确认收货 / 退款
-- ============================================================

-- 修改 orders 表状态约束，增加发货/退款流程状态
alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check
  check (status in ('pending', 'shipped', 'completed', 'refunded', 'cancelled'));

-- 给 orders 表增加发货和退款时间字段
alter table public.orders add column if not exists shipped_at timestamptz;
alter table public.orders add column if not exists completed_at timestamptz;
alter table public.orders add column if not exists refunded_at timestamptz;
alter table public.orders add column if not exists refund_reason text;

-- RPC：管理员发货
create or replace function public.ship_order(p_order_id uuid)
returns json as $$
declare
  v_user_id uuid := auth.uid();
  v_admin_role text;
  v_is_admin boolean;
  v_is_seller boolean;
  v_order record;
  v_product record;
begin
  -- 检查权限
  select role into v_admin_role from public.profiles where id = v_user_id;
  v_is_admin := (v_admin_role is not null and v_admin_role in ('owner', 'admin'));

  -- 获取订单
  select * into v_order from public.orders where id = p_order_id;
  if v_order is null then
    return json_build_object('success', false, 'error', '订单不存在');
  end if;

  -- 检查是否是卖家（商品的创建者）
  select creator_id into v_product from public.products where id = v_order.product_id;
  v_is_seller := (v_product.creator_id = v_user_id);

  -- 只有管理员或卖家可以发货
  if not v_is_admin and not v_is_seller then
    return json_build_object('success', false, 'error', '没有发货权限');
  end if;

  if v_order.status != 'pending' then
    return json_build_object('success', false, 'error', '当前订单状态不能发货');
  end if;

  -- 获取商品信息
  select * into v_product from public.products where id = v_order.product_id;

  -- 更新订单状态为已发货
  update public.orders
  set status = 'shipped', shipped_at = now()
  where id = p_order_id;

  -- 把商品放入买家储物袋
  insert into public.inventory (user_id, item_type, product_id, pill_name, pill_grade, pill_qi_bonus, quantity, status)
  values (
    v_order.user_id,
    'product',
    v_order.product_id,
    coalesce(v_product.name, '未知商品'),
    0,
    0,
    1,
    'owned'
  );

  return json_build_object('success', true);
end;
$$ language plpgsql security definer;

-- RPC：用户确认收货
create or replace function public.confirm_receipt(p_order_id uuid)
returns json as $$
declare
  v_user_id uuid := auth.uid();
  v_order record;
begin
  -- 获取订单
  select * into v_order from public.orders where id = p_order_id;
  if v_order is null then
    return json_build_object('success', false, 'error', '订单不存在');
  end if;

  if v_order.user_id != v_user_id then
    return json_build_object('success', false, 'error', '只能确认自己的订单');
  end if;

  if v_order.status != 'shipped' then
    return json_build_object('success', false, 'error', '当前订单状态不能确认收货');
  end if;

  -- 更新订单状态为已完成
  update public.orders
  set status = 'completed', completed_at = now()
  where id = p_order_id;

  return json_build_object('success', true);
end;
$$ language plpgsql security definer;

-- RPC：退款（管理员可退任何状态，买家只能在待发货时退自己的订单）
create or replace function public.refund_order(
  p_order_id uuid,
  p_reason text default null
)
returns json as $$
declare
  v_user_id uuid := auth.uid();
  v_admin_role text;
  v_order record;
  v_product record;
  v_is_admin boolean;
  v_is_seller boolean;
  v_is_buyer boolean;
begin
  -- 检查是否是管理员
  select role into v_admin_role from public.profiles where id = v_user_id;
  v_is_admin := (v_admin_role is not null and v_admin_role in ('owner', 'admin'));

  -- 获取订单
  select * into v_order from public.orders where id = p_order_id;
  if v_order is null then
    return json_build_object('success', false, 'error', '订单不存在');
  end if;

  -- 检查是否是卖家（商品的创建者）
  select * into v_product from public.products where id = v_order.product_id;
  v_is_seller := (v_product.creator_id = v_user_id);
  v_is_buyer := (v_order.user_id = v_user_id);

  -- 权限检查：管理员可以退款任何状态，买家只能在 pending 时退款自己的订单，卖家可以退款自己商品的 pending/shipped 订单
  if not v_is_admin then
    if not v_is_buyer and not v_is_seller then
      return json_build_object('success', false, 'error', '只能退款自己的订单或自己商品的订单');
    end if;
    if v_is_buyer and v_order.status != 'pending' then
      return json_build_object('success', false, 'error', '订单已发货，无法退款');
    end if;
    if v_is_seller and not v_is_buyer and v_order.status not in ('pending', 'shipped') then
      return json_build_object('success', false, 'error', '当前订单状态不能退款');
    end if;
  else
    if v_order.status not in ('pending', 'shipped') then
      return json_build_object('success', false, 'error', '当前订单状态不能退款');
    end if;
  end if;

  -- 获取商品信息
  select * into v_product from public.products where id = v_order.product_id;

  -- 退款：将灵石退还给用户
  update public.wallets
  set coins = coins + v_order.price, updated_at = now()
  where user_id = v_order.user_id;

  -- 创建退款流水
  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (
    v_order.user_id,
    v_order.price,
    'shop_refund',
    '商品退款：' || coalesce(v_product.name, '未知商品'),
    v_order.id
  );

  -- 更新订单状态
  update public.orders
  set status = 'refunded', refund_reason = p_reason, refunded_at = now()
  where id = p_order_id;

  return json_build_object('success', true, 'refund_amount', v_order.price);
end;
$$ language plpgsql security definer;

-- 修改 redeem_product 函数，创建订单时状态设为 pending（待发货）
create or replace function public.redeem_product(
  p_product_id uuid
)
returns json as $$
declare
  v_user_id uuid := auth.uid();
  v_product record;
  v_balance integer;
  v_order_id uuid;
begin
  -- 获取商品
  select * into v_product from public.products where id = p_product_id;
  if v_product is null then
    return json_build_object('success', false, 'error', '商品不存在');
  end if;

  if v_product.status != 'active' then
    return json_build_object('success', false, 'error', '商品已下架');
  end if;

  -- 检查余额（行锁）
  select coins into v_balance from public.wallets where user_id = v_user_id for update;
  if v_balance is null then
    return json_build_object('success', false, 'error', '钱包不存在');
  end if;

  if v_balance < v_product.price then
    return json_build_object('success', false, 'error', '灵石余额不足');
  end if;

  -- 扣款
  update public.wallets set coins = coins - v_product.price where user_id = v_user_id;

  -- 创建订单（状态为 pending 待发货）
  insert into public.orders (user_id, product_id, price, status)
  values (v_user_id, p_product_id, v_product.price, 'pending')
  returning id into v_order_id;

  -- 创建流水
  insert into public.wallet_transactions (user_id, amount, type, description, related_id)
  values (v_user_id, -v_product.price, 'shop_redeem', '兑换：' || v_product.name, v_order_id);

  return json_build_object('success', true, 'order_id', v_order_id);
end;
$$ language plpgsql security definer;
