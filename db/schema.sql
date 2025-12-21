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
