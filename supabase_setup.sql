-- ============================================
-- 运动积分系统 - Supabase 数据库脚本
-- 在 Supabase SQL Editor 中执行
-- ============================================

-- 1. 成员表
CREATE TABLE IF NOT EXISTS members (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    department TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 运动记录表
CREATE TABLE IF NOT EXISTS exercise_records (
    id BIGSERIAL PRIMARY KEY,
    member_id BIGINT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    exercise_date DATE NOT NULL,
    exercise_type INTEGER NOT NULL,  -- 1跑步 2健走 3骑行 4健身 5球类/游泳/瑜伽 6团队运动
    distance REAL DEFAULT 0,         -- 公里
    steps INTEGER DEFAULT 0,         -- 步数
    duration INTEGER DEFAULT 0,      -- 分钟
    is_team BOOLEAN DEFAULT FALSE,   -- 是否团队运动
    points REAL DEFAULT 0,           -- 积分（自动计算）
    screenshot_url TEXT DEFAULT '',  -- 截图存储URL
    note TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 创建索引
CREATE INDEX IF NOT EXISTS idx_records_member ON exercise_records(member_id);
CREATE INDEX IF NOT EXISTS idx_records_date ON exercise_records(exercise_date);
CREATE INDEX IF NOT EXISTS idx_records_type ON exercise_records(exercise_type);

-- 4. 积分计算函数
CREATE OR REPLACE FUNCTION calculate_points(
    p_type INTEGER,
    p_distance REAL,
    p_steps INTEGER,
    p_duration INTEGER,
    p_is_team BOOLEAN
) RETURNS REAL AS $$
DECLARE
    v_points REAL := 0;
BEGIN
    IF p_type = 1 THEN  -- 跑步: ≥2km, 1分/2km
        IF p_distance >= 2 THEN
            v_points := FLOOR(p_distance / 2.0);
        END IF;
    ELSIF p_type = 2 THEN  -- 健走: ≥10000步, 1分/次
        IF p_steps >= 10000 THEN
            v_points := 1;
        END IF;
    ELSIF p_type = 3 THEN  -- 骑行: ≥5km, 1分/5km
        IF p_distance >= 5 THEN
            v_points := FLOOR(p_distance / 5.0);
        END IF;
    ELSIF p_type = 4 THEN  -- 健身/力量: ≥30分钟, 1分/次
        IF p_duration >= 30 THEN
            v_points := 1;
        END IF;
    ELSIF p_type = 5 THEN  -- 球类/游泳/瑜伽: ≥30分钟, 1分/次
        IF p_duration >= 30 THEN
            v_points := 1;
        END IF;
    ELSIF p_type = 6 THEN  -- 团队运动: ≥30分钟, 积分翻倍
        IF p_duration >= 30 THEN
            v_points := 1;
        END IF;
    END IF;

    -- 团队运动翻倍
    IF p_is_team THEN
        v_points := v_points * 2;
    END IF;

    RETURN v_points;
END;
$$ LANGUAGE plpgsql;

-- 5. 自动计算积分的触发器
CREATE OR REPLACE FUNCTION auto_calc_points() RETURNS TRIGGER AS $$
BEGIN
    NEW.points := calculate_points(
        NEW.exercise_type, NEW.distance, NEW.steps, NEW.duration, NEW.is_team
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calc_points ON exercise_records;
CREATE TRIGGER trg_calc_points
    BEFORE INSERT OR UPDATE ON exercise_records
    FOR EACH ROW
    EXECUTE FUNCTION auto_calc_points();

-- 6. 开放访问策略（允许所有人读写）
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to members" ON members
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow all access to records" ON exercise_records
    FOR ALL USING (true) WITH CHECK (true);

-- 7. 开启实时订阅
ALTER PUBLICATION supabase_realtime ADD TABLE exercise_records;
ALTER PUBLICATION supabase_realtime ADD TABLE members;
