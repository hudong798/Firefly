-- ============================================================
-- 日程 & 公告 独立管理员凭证系统
-- 与修仙界 Supabase auth 完全无关
-- 密码用 bcrypt 哈希存储，通过 RPC 验证，RLS 禁止直接读取
-- ============================================================

-- 确保 pgcrypto 扩展启用（在 extensions schema）
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. 创建管理员凭证表
CREATE TABLE IF NOT EXISTS public.admin_credentials (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    module text NOT NULL,              -- 'schedule' 或 'echo'
    username text NOT NULL,
    password_hash text NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(module, username)
);

-- 2. 启用 RLS（禁止直接读取密码哈希）
ALTER TABLE public.admin_credentials ENABLE ROW LEVEL SECURITY;

-- 不创建任何 SELECT 策略 —— 只能通过 RPC 函数间接验证
-- 只有 service_role 可以写入（初始化和修改账号）

-- 3. 创建验证 RPC 函数（SECURITY DEFINER 使其能绕过 RLS 读取表）
--    注意：pgcrypto 在 extensions schema，search_path 需包含 extensions
CREATE OR REPLACE FUNCTION public.verify_admin_credentials(
    p_module text,
    p_username text,
    p_password text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_hash text;
    v_result boolean;
BEGIN
    SELECT password_hash INTO v_hash
    FROM public.admin_credentials
    WHERE module = p_module
      AND username = p_username
    LIMIT 1;

    IF v_hash IS NULL THEN
        RETURN false;
    END IF;

    -- 用 crypt 验证密码（bcrypt）
    SELECT (v_hash = extensions.crypt(p_password, v_hash)) INTO v_result;
    RETURN v_result;
END;
$$;

-- 4. 允许 anon 和 authenticated 角色调用验证函数
GRANT EXECUTE ON FUNCTION public.verify_admin_credentials(text, text, text) TO anon, authenticated;

-- 5. 初始化日程管理员账号
INSERT INTO public.admin_credentials (module, username, password_hash)
VALUES ('schedule', 'itong', extensions.crypt('schedule2026', extensions.gen_salt('bf')))
ON CONFLICT (module, username) DO NOTHING;

-- 6. 初始化公告管理员账号
INSERT INTO public.admin_credentials (module, username, password_hash)
VALUES ('echo', 'itong', extensions.crypt('echo2026', extensions.gen_salt('bf')))
ON CONFLICT (module, username) DO NOTHING;

-- 7. 验证初始化结果
SELECT module, username, '***' as password FROM public.admin_credentials ORDER BY module;
