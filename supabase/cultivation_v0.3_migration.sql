-- ============================================================
-- 修仙系统 V0.3 迁移：商品库存 + 任务领取人数限制
-- ============================================================

-- 1. 给 products 表添加 stock 字段（库存数量）
alter table public.products 
  add column if not exists stock integer not null default 1 check (stock >= 0);

-- 2. 给 tasks 表添加 max_claimants 字段（最大领取人数，0 表示不限制）
alter table public.tasks 
  add column if not exists max_claimants integer not null default 0 check (max_claimants >= 0);

-- 3. 修改 redeem_product 函数，添加库存检查和扣减
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
  -- 获取商品（行锁）
  select * into v_product from public.products where id = p_product_id for update;
  if v_product is null then
    return json_build_object('success', false, 'error', '商品不存在');
  end if;

  if v_product.status != 'active' then
    return json_build_object('success', false, 'error', '商品已下架');
  end if;

  -- 检查库存
  if v_product.stock <= 0 then
    return json_build_object('success', false, 'error', '商品已售罄');
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

  -- 扣减库存
  update public.products set stock = stock - 1 where id = p_product_id;

  -- 如果库存为0，自动下架
  if v_product.stock - 1 <= 0 then
    update public.products set status = 'inactive' where id = p_product_id;
  end if;

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
