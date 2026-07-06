-- 002_seed_data.sql
-- Generates realistic-ish seed data:
--   - 5 organizations
--   - 6 cities
--   - 4 statuses
--   - 300 bookings, created_at spread over the last 90 days
--     (so the "last 30 days" filter used by the target query has
--      a meaningful, non-trivial subset to hit)
--   - booking_events for ~70% of bookings

DO $$
DECLARE
    orgs   UUID[] := ARRAY[
        gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
        gen_random_uuid(), gen_random_uuid()
    ];
    cities TEXT[]  := ARRAY['delhi', 'mumbai', 'bangalore', 'pune', 'chennai', 'hyderabad'];
    statuses TEXT[] := ARRAY['confirmed', 'cancelled', 'completed', 'pending'];
    event_types TEXT[] := ARRAY['created', 'payment_received', 'checked_in', 'checked_out', 'cancelled'];

    v_id UUID;
    i INT;
    j INT;
    n_events INT;
    checkin DATE;
BEGIN
    FOR i IN 1..300 LOOP
        v_id := gen_random_uuid();
        checkin := (CURRENT_DATE - (floor(random() * 120))::int);

        INSERT INTO hotel_bookings (
            id, org_id, hotel_id, city, checkin_date, checkout_date,
            amount, status, created_at
        ) VALUES (
            v_id,
            orgs[1 + floor(random() * array_length(orgs, 1))::int],
            'HOTEL-' || lpad((floor(random() * 40) + 1)::text, 3, '0'),
            cities[1 + floor(random() * array_length(cities, 1))::int],
            checkin,
            checkin + (1 + floor(random() * 5))::int,
            round((1500 + random() * 18000)::numeric, 2),
            statuses[1 + floor(random() * array_length(statuses, 1))::int],
            -- created_at spread over the last 90 days, timestamp not just date
            now() - (random() * interval '90 days')
        );

        -- ~70% of bookings get 1-3 events
        IF random() < 0.7 THEN
            n_events := 1 + floor(random() * 3)::int;
            FOR j IN 1..n_events LOOP
                INSERT INTO booking_events (booking_id, event_type, payload, created_at)
                VALUES (
                    v_id,
                    event_types[1 + floor(random() * array_length(event_types, 1))::int],
                    jsonb_build_object('source', 'seed', 'seq', j),
                    now() - (random() * interval '90 days')
                );
            END LOOP;
        END IF;
    END LOOP;
END $$;
