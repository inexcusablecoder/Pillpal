-- PillPal MVP schema: auth (users), medicines, dose intake history (dose_logs).
-- Matches: backend/alembic/versions/0001_initial_schema.py
--
-- In pgAdmin: connect to your PillPal database → Query Tool → paste this script → Execute (F5).
-- If PostgreSQL lowercased the name, the DB may appear as "pillpal" in the connection list.

BEGIN;

CREATE TYPE dose_status AS ENUM ('pending', 'taken', 'missed');

CREATE TABLE users (
    id UUID NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_users_email ON users (email);

CREATE TABLE medicines (
    id UUID NOT NULL,
    user_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    dosage VARCHAR(255) NOT NULL,
    scheduled_time TIME WITHOUT TIME ZONE NOT NULL,
    frequency VARCHAR(32) NOT NULL,
    active BOOLEAN NOT NULL,
    pill_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_medicines_user_id ON medicines (user_id);

CREATE TABLE dose_logs (
    id UUID NOT NULL,
    user_id UUID NOT NULL,
    medicine_id UUID NOT NULL,
    scheduled_date DATE NOT NULL,
    scheduled_time TIME WITHOUT TIME ZONE NOT NULL,
    status dose_status NOT NULL,
    taken_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uq_dose_medicine_date UNIQUE (medicine_id, scheduled_date)
);

CREATE INDEX ix_dose_logs_user_id ON dose_logs (user_id);
CREATE INDEX ix_dose_logs_medicine_id ON dose_logs (medicine_id);
CREATE INDEX ix_dose_logs_scheduled_date ON dose_logs (scheduled_date);
CREATE INDEX ix_dose_logs_user_scheduled ON dose_logs (user_id, scheduled_date);

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL,
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

INSERT INTO alembic_version (version_num) VALUES ('0001_initial');

COMMIT;
