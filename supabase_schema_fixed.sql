-- ============================================
-- Sortie - Supabase Database Schema (FIXED VERSION)
-- ============================================
-- 修复了语法错误，可直接在 Supabase 中执行
-- ============================================

-- ============================================
-- 1. 用户扩展表 (扩展 Supabase Auth)
-- ============================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,

    -- 隐私偏好设置
    data_sync_enabled BOOLEAN DEFAULT false,
    calendar_sync_enabled BOOLEAN DEFAULT false,
    analytics_enabled BOOLEAN DEFAULT false,

    -- Apple 集成相关 (加密存储)
    apple_refresh_token TEXT,
    apple_token_expires_at TIMESTAMPTZ,

    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX idx_profiles_email ON public.profiles(email);

-- ============================================
-- 2. 分类配置表
-- ============================================
CREATE TABLE public.categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    -- 分类信息
    name TEXT NOT NULL,
    emoji TEXT NOT NULL,
    color TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,

    -- 系统分类标记
    is_system BOOLEAN DEFAULT false,

    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX idx_categories_user_id ON public.categories(user_id);
CREATE INDEX idx_categories_sort_order ON public.categories(user_id, sort_order);

-- ============================================
-- 3. 内容项表 (核心数据表)
-- ============================================
CREATE TABLE public.items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,

    -- 内容类型
    item_type TEXT NOT NULL CHECK (item_type IN ('note', 'schedule', 'todo', 'file', 'notification')),

    -- 基础信息
    title TEXT NOT NULL,
    content TEXT,
    source_type TEXT DEFAULT 'manual' CHECK (source_type IN ('manual', 'ai_parsed', 'shared')),

    -- 日程特定字段
    scheduled_start TIMESTAMPTZ,
    scheduled_end TIMESTAMPTZ,
    location TEXT,
    reminder_sent BOOLEAN DEFAULT false,

    -- 日历同步相关
    apple_event_id TEXT,
    calendar_synced BOOLEAN DEFAULT false,

    -- 待办特定字段
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,

    -- 文件特定字段
    file_url TEXT,
    file_type TEXT,
    file_size BIGINT,
    file_name TEXT,

    -- AI 解析信息
    ai_parsed_data JSONB,
    confidence_score NUMERIC,

    -- 元数据
    metadata JSONB DEFAULT '{}',

    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 创建索引
CREATE INDEX idx_items_user_id ON public.items(user_id);
CREATE INDEX idx_items_category_id ON public.items(category_id);
CREATE INDEX idx_items_type ON public.items(user_id, item_type);
CREATE INDEX idx_items_scheduled_start ON public.items(user_id, scheduled_start) WHERE item_type = 'schedule';
CREATE INDEX idx_items_created_at ON public.items(user_id, created_at DESC);
CREATE INDEX idx_items_deleted_at ON public.items(deleted_at) WHERE deleted_at IS NOT NULL;

-- ============================================
-- 4. 同步状态表
-- ============================================
CREATE TABLE public.sync_status (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    -- 同步信息
    device_id TEXT NOT NULL,
    device_name TEXT,
    last_sync_at TIMESTAMPTZ DEFAULT NOW(),
    sync_cursor TEXT,

    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- 唯一约束
    UNIQUE(user_id, device_id)
);

-- 创建索引
CREATE INDEX idx_sync_status_user_id ON public.sync_status(user_id);

-- ============================================
-- 5. 活动日志表
-- ============================================
CREATE TABLE public.activity_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    -- 活动信息
    action TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete', 'sync', 'share')),
    item_type TEXT,
    item_id UUID,
    details JSONB DEFAULT '{}',

    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX idx_activity_logs_user_id ON public.activity_logs(user_id);
CREATE INDEX idx_activity_logs_created_at ON public.activity_logs(created_at DESC);

-- ============================================
-- 6. 函数和触发器
-- ============================================

-- 自动更新 updated_at 的函数
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为需要的表添加触发器
DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_categories_updated_at ON public.categories;
CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE ON public.categories
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_items_updated_at ON public.items;
CREATE TRIGGER update_items_updated_at
    BEFORE UPDATE ON public.items
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- 新用户注册时自动创建 profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', '')
    );

    -- 创建默认分类（文件分类/文件夹）
    INSERT INTO public.categories (user_id, name, emoji, color, is_system, sort_order) VALUES
        (NEW.id, '灵感', '💡', '#D4C8D4', true, 1),
        (NEW.id, '工作', '💼', '#9CB4B8', true, 2),
        (NEW.id, '学习', '📚', '#B8C4A8', true, 3),
        (NEW.id, '生活', '🏠', '#C8B8A8', true, 4);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 7. 视图
-- ============================================

-- 用户内容统计视图
CREATE OR REPLACE VIEW public.user_content_stats AS
SELECT
    p.id AS user_id,
    COUNT(DISTINCT c.id) AS total_categories,
    COUNT(i.id) FILTER (WHERE i.deleted_at IS NULL) AS total_items,
    COUNT(i.id) FILTER (WHERE i.item_type = 'note' AND i.deleted_at IS NULL) AS note_count,
    COUNT(i.id) FILTER (WHERE i.item_type = 'schedule' AND i.deleted_at IS NULL) AS schedule_count,
    COUNT(i.id) FILTER (WHERE i.item_type = 'todo' AND i.deleted_at IS NULL) AS todo_count,
    COUNT(i.id) FILTER (WHERE i.item_type = 'file' AND i.deleted_at IS NULL) AS file_count
FROM public.profiles p
LEFT JOIN public.categories c ON c.user_id = p.id
LEFT JOIN public.items i ON i.user_id = p.id
GROUP BY p.id;

-- 日程视图
CREATE OR REPLACE VIEW public.user_schedule AS
SELECT
    i.id,
    i.user_id,
    i.title,
    i.content,
    i.scheduled_start,
    i.scheduled_end,
    i.location,
    i.reminder_sent,
    i.apple_event_id,
    i.calendar_synced,
    c.name AS category_name,
    c.emoji AS category_emoji,
    c.color AS category_color
FROM public.items i
JOIN public.categories c ON i.category_id = c.id
WHERE i.item_type = 'schedule'
    AND i.deleted_at IS NULL
    AND i.scheduled_start IS NOT NULL;

-- ============================================
-- 8. Row Level Security (RLS)
-- ============================================

-- 启用 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Profiles 表策略
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- Categories 表策略
CREATE POLICY "Users can view own categories"
    ON public.categories FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own categories"
    ON public.categories FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own categories"
    ON public.categories FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own categories"
    ON public.categories FOR DELETE
    USING (auth.uid() = user_id AND is_system = false);

-- Items 表策略
CREATE POLICY "Users can view own items"
    ON public.items FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own items"
    ON public.items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own items"
    ON public.items FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own items"
    ON public.items FOR DELETE
    USING (auth.uid() = user_id);

-- Sync Status 表策略
CREATE POLICY "Users can view own sync status"
    ON public.sync_status FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own sync status"
    ON public.sync_status FOR ALL
    USING (auth.uid() = user_id);

-- Activity Logs 表策略
CREATE POLICY "Users can view own activity logs"
    ON public.activity_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert activity logs"
    ON public.activity_logs FOR INSERT
    WITH CHECK (true);

-- ============================================
-- 9. 实用函数
-- ============================================

-- 导出用户数据
CREATE OR REPLACE FUNCTION public.export_user_data(user_id_param UUID DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
    target_user_id UUID := COALESCE(user_id_param, auth.uid());
    result JSON;
BEGIN
    SELECT json_build_object(
        'profile', (SELECT row_to_json(p) FROM (SELECT id, email, full_name, created_at FROM public.profiles WHERE id = target_user_id) p),
        'categories', (SELECT json_agg(row_to_json(c)) FROM public.categories c WHERE c.user_id = target_user_id),
        'items', (SELECT json_agg(row_to_json(i)) FROM public.items i WHERE i.user_id = target_user_id AND i.deleted_at IS NULL),
        'exported_at', NOW()
    ) INTO result;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 软删除用户数据
CREATE OR REPLACE FUNCTION public.soft_delete_user()
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.items
    SET deleted_at = NOW()
    WHERE user_id = auth.uid();

    DELETE FROM public.sync_status
    WHERE user_id = auth.uid();

    DELETE FROM public.activity_logs
    WHERE user_id = auth.uid();

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 10. 授权
-- ============================================
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.categories TO authenticated;
GRANT ALL ON public.items TO authenticated;
GRANT ALL ON public.sync_status TO authenticated;
GRANT ALL ON public.activity_logs TO authenticated;
GRANT SELECT ON public.user_content_stats TO authenticated;
GRANT SELECT ON public.user_schedule TO authenticated;
