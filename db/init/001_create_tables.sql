-- 001_create_tables.sql
-- Core schema for hotel bookings

CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- for gen_random_uuid()

CREATE TABLE IF NOT EXISTS hotel_bookings (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    hotel_id      VARCHAR(100) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    checkin_date  DATE NOT NULL,
    checkout_date DATE NOT NULL,
    amount        NUMERIC(12,2) NOT NULL,
    status        VARCHAR(50) NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS booking_events (
    id          BIGSERIAL PRIMARY KEY,
    booking_id  UUID NOT NULL REFERENCES hotel_bookings(id),
    event_type  VARCHAR(100) NOT NULL,
    payload     JSONB,
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- Query we need to optimize (see README "Indexing Decision" section):
--
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi'
--     AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- The WHERE clause filters on (city, created_at). A composite B-tree
-- index on (city, created_at) lets Postgres do an index range scan
-- directly to the matching rows instead of a sequential scan, and
-- also returns rows already ordered by created_at within each city,
-- which helps the GROUP BY aggregate step.
-- We additionally include org_id, status, amount as INCLUDE columns
-- so the whole query can be answered as an index-only scan without
-- touching the heap (Postgres 11+).
-- ---------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);

-- Helpful supporting indexes for common access patterns
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id
    ON booking_events (booking_id);

CREATE INDEX IF NOT EXISTS idx_hotel_bookings_org_id
    ON hotel_bookings (org_id);
