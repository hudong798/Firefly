-- 邀请码功能数据库迁移
-- 创建邀请码表

CREATE TABLE IF NOT EXISTS invitation_codes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(16) UNIQUE NOT NULL,
    created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    used_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
    used_at timestamptz,
    is_used boolean NOT NULL DEFAULT false
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_invitation_codes_code ON invitation_codes(code);
CREATE INDEX IF NOT EXISTS idx_invitation_codes_created_by ON invitation_codes(created_by);
CREATE INDEX IF NOT EXISTS idx_invitation_codes_expires_at ON invitation_codes(expires_at);

-- 启用 RLS
ALTER TABLE invitation_codes ENABLE ROW LEVEL SECURITY;

-- RLS 策略：宗主可以查看所有邀请码
CREATE POLICY "宗主查看所有邀请码" ON invitation_codes
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid() AND p.role = 'owner'
        )
    );

-- RLS 策略：宗主可以创建邀请码
CREATE POLICY "宗主创建邀请码" ON invitation_codes
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid() AND p.role = 'owner'
        )
    );

-- RLS 策略：宗主可以更新邀请码
CREATE POLICY "宗主更新邀请码" ON invitation_codes
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = auth.uid() AND p.role = 'owner'
        )
    );

-- 创建验证邀请码的 RPC 函数
CREATE OR REPLACE FUNCTION validate_invitation_code(p_code varchar)
RETURNS json AS $$
DECLARE
    v_code record;
BEGIN
    -- 查询邀请码
    SELECT * INTO v_code
    FROM invitation_codes
    WHERE code = p_code;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', '邀请码不存在');
    END IF;

    -- 检查是否已使用
    IF v_code.is_used THEN
        RETURN json_build_object('success', false, 'error', '邀请码已被使用');
    END IF;

    -- 检查是否过期
    IF v_code.expires_at < now() THEN
        RETURN json_build_object('success', false, 'error', '邀请码已过期');
    END IF;

    RETURN json_build_object('success', true, 'code_id', v_code.id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建使用邀请码的 RPC 函数
CREATE OR REPLACE FUNCTION use_invitation_code(p_code varchar, p_user_id uuid)
RETURNS json AS $$
DECLARE
    v_code record;
BEGIN
    -- 查询邀请码并加行锁
    SELECT * INTO v_code
    FROM invitation_codes
    WHERE code = p_code
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', '邀请码不存在');
    END IF;

    -- 检查是否已使用
    IF v_code.is_used THEN
        RETURN json_build_object('success', false, 'error', '邀请码已被使用');
    END IF;

    -- 检查是否过期
    IF v_code.expires_at < now() THEN
        RETURN json_build_object('success', false, 'error', '邀请码已过期');
    END IF;

    -- 标记为已使用
    UPDATE invitation_codes
    SET is_used = true,
        used_by = p_user_id,
        used_at = now()
    WHERE id = v_code.id;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建生成邀请码的 RPC 函数（只有宗主可以调用）
CREATE OR REPLACE FUNCTION generate_invitation_code()
RETURNS json AS $$
DECLARE
    v_user record;
    v_code varchar;
    v_code_id uuid;
BEGIN
    -- 检查当前用户是否是宗主
    SELECT * INTO v_user
    FROM profiles
    WHERE id = auth.uid();

    IF NOT FOUND OR v_user.role != 'owner' THEN
        RETURN json_build_object('success', false, 'error', '只有宗主可以生成邀请码');
    END IF;

    -- 生成8位随机邀请码（大写字母和数字）
    v_code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 8));

    -- 确保邀请码唯一
    WHILE EXISTS (SELECT 1 FROM invitation_codes WHERE code = v_code) LOOP
        v_code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 8));
    END LOOP;

    -- 插入邀请码（24小时后过期）
    INSERT INTO invitation_codes (code, created_by, expires_at)
    VALUES (v_code, auth.uid(), now() + interval '24 hours')
    RETURNING id INTO v_code_id;

    RETURN json_build_object(
        'success', true,
        'code', v_code,
        'code_id', v_code_id,
        'expires_at', now() + interval '24 hours'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
