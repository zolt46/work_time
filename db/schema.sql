-- File: /db/schema.sql
-- PostgreSQL schema for Dasan Information Center shift management

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('MASTER', 'OPERATOR', 'MEMBER');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'request_type') THEN
        CREATE TYPE request_type AS ENUM ('ABSENCE', 'EXTRA');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'request_status') THEN
        CREATE TYPE request_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');
    ELSE
        IF NOT EXISTS (
            SELECT 1
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'request_status'
              AND e.enumlabel = 'CANCELLED'
        ) THEN
            ALTER TYPE request_status ADD VALUE IF NOT EXISTS 'CANCELLED';
        END IF;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notice_type') THEN
        CREATE TYPE notice_type AS ENUM ('DB_MAINTENANCE', 'SYSTEM_MAINTENANCE', 'WORK_SPECIAL', 'GENERAL');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notice_channel') THEN
        CREATE TYPE notice_channel AS ENUM ('POPUP', 'BANNER', 'POPUP_BANNER', 'NONE', 'BOARD');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notice_scope') THEN
        CREATE TYPE notice_scope AS ENUM ('ALL', 'ROLE', 'USER');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'visitor_period_type') THEN
        CREATE TYPE visitor_period_type AS ENUM ('SEMESTER_1', 'SEMESTER_2', 'SUMMER_BREAK', 'WINTER_BREAK');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    identifier TEXT UNIQUE,
    role user_role NOT NULL DEFAULT 'MEMBER',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth_accounts (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    login_id TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    last_login_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    weekday SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    location TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (start_time < end_time)
);

CREATE TABLE IF NOT EXISTS user_shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    valid_from DATE NOT NULL,
    valid_to DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_shifts_user ON user_shifts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_shifts_shift ON user_shifts(shift_id);

CREATE TABLE IF NOT EXISTS shift_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type request_type NOT NULL,
    target_date DATE NOT NULL,
    target_shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    target_start_time TIME,
    target_end_time TIME,
    reason TEXT,
    status request_status NOT NULL DEFAULT 'PENDING',
    operator_id UUID REFERENCES users(id),
    decided_at TIMESTAMPTZ,
    cancelled_after_approval BOOLEAN NOT NULL DEFAULT FALSE,
    cancel_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_shift_requests_user ON shift_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_shift_requests_status ON shift_requests(status);
CREATE INDEX IF NOT EXISTS idx_shift_requests_type ON shift_requests(type);

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_user_id UUID REFERENCES users(id),
    action_type TEXT NOT NULL,
    target_user_id UUID REFERENCES users(id),
    request_id UUID REFERENCES shift_requests(id),
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

CREATE TABLE IF NOT EXISTS notices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type notice_type NOT NULL,
    channel notice_channel NOT NULL,
    scope notice_scope NOT NULL DEFAULT 'ALL',
    target_roles JSONB,
    priority INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notices_active ON notices(is_active);
CREATE INDEX IF NOT EXISTS idx_notices_channel ON notices(channel);
CREATE INDEX IF NOT EXISTS idx_notices_window ON notices(start_at, end_at);
CREATE INDEX IF NOT EXISTS idx_notices_priority ON notices(priority);

CREATE TABLE IF NOT EXISTS notice_targets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    notice_id UUID NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_notice_targets_unique ON notice_targets(notice_id, user_id);

CREATE TABLE IF NOT EXISTS notice_reads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    notice_id UUID NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel notice_channel NOT NULL,
    read_at TIMESTAMPTZ,
    dismissed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_notice_reads_unique ON notice_reads(notice_id, user_id, channel);
CREATE INDEX IF NOT EXISTS idx_notice_reads_user ON notice_reads(user_id);

CREATE TABLE IF NOT EXISTS visitor_school_years (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    academic_year INTEGER NOT NULL UNIQUE,
    label TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    initial_total INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS visitor_periods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_year_id UUID NOT NULL REFERENCES visitor_school_years(id) ON DELETE CASCADE,
    period_type visitor_period_type NOT NULL,
    name TEXT NOT NULL,
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_year_id, period_type)
);
CREATE INDEX IF NOT EXISTS idx_visitor_periods_year ON visitor_periods(school_year_id);

CREATE TABLE IF NOT EXISTS visitor_daily_counts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_year_id UUID NOT NULL REFERENCES visitor_school_years(id) ON DELETE CASCADE,
    visit_date DATE NOT NULL,
    count1 INTEGER NOT NULL DEFAULT 0,
    count2 INTEGER NOT NULL DEFAULT 0,
    baseline_total INTEGER,
    daily_override INTEGER,
    total_count INTEGER NOT NULL DEFAULT 0,
    previous_total INTEGER NOT NULL DEFAULT 0,
    daily_visitors INTEGER NOT NULL DEFAULT 0,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_year_id, visit_date)
);
CREATE INDEX IF NOT EXISTS idx_visitor_daily_year ON visitor_daily_counts(school_year_id);
CREATE INDEX IF NOT EXISTS idx_visitor_daily_date ON visitor_daily_counts(visit_date);

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

CREATE TRIGGER trg_shifts_updated
BEFORE UPDATE ON shifts
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

CREATE TRIGGER trg_user_shifts_updated
BEFORE UPDATE ON user_shifts
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

CREATE TRIGGER trg_shift_requests_updated
BEFORE UPDATE ON shift_requests
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

CREATE TRIGGER trg_notices_updated
BEFORE UPDATE ON notices
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

CREATE TRIGGER trg_visitor_school_years_updated
BEFORE UPDATE ON visitor_school_years
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

CREATE TRIGGER trg_visitor_periods_updated
BEFORE UPDATE ON visitor_periods
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

CREATE TRIGGER trg_visitor_daily_counts_updated
BEFORE UPDATE ON visitor_daily_counts
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
