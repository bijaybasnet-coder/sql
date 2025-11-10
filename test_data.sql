-- =====================================================================================
-- FIXED: US Healthcare Mobile App Registration Test Data Generation
-- Client ID: 100
-- Target: 3500+ unique device attempts, >95% conversion, <5min avg time
--
-- FIXES APPLIED:
-- 1. Average completion time: < 5 minutes (guest_start to full_complete)
-- 2. Conversion rate: > 95%
-- 3. Email verified count = Guest registered count
-- 4. Recent users with proper status for demographic validation query
-- 5. Diverse names for full registered users (not just Gabriel Bryant)
-- 6. Proper funnel: Full registered <= Demographic verified
-- 7. Proper timestamps (no "-" in time display)
-- =====================================================================================

BEGIN;
SET timezone = 'America/New_York';

-- =====================================================================================
-- UTILITY FUNCTIONS
-- =====================================================================================

CREATE OR REPLACE FUNCTION generate_us_phone() RETURNS TEXT AS $$
DECLARE
    area_codes TEXT[] := ARRAY['202','212','213','214','305','310','312','404','415','510','512','617','619','702','703','714','718','720','832','925'];
    area_code TEXT;
BEGIN
    area_code := area_codes[floor(random() * array_length(area_codes, 1)) + 1];
    RETURN area_code || lpad((floor(random() * 800) + 200)::TEXT, 3, '0') || lpad((floor(random() * 10000))::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_healthcare_email(unique_id INTEGER) RETURNS TEXT AS $$
DECLARE
    first_names TEXT[] := ARRAY['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','William','Elizabeth','David','Barbara','Richard','Susan','Joseph','Jessica','Thomas','Sarah','Christopher','Karen','Charles','Nancy','Daniel','Lisa','Matthew','Betty','Anthony','Dorothy','Mark','Sandra'];
    last_names TEXT[] := ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin','Lee'];
    domains TEXT[] := ARRAY['gmail.com','yahoo.com','hotmail.com','outlook.com','icloud.com'];
BEGIN
    RETURN lower(first_names[floor(random() * array_length(first_names, 1)) + 1]) || '.' ||
           lower(last_names[floor(random() * array_length(last_names, 1)) + 1]) || '.' ||
           unique_id::TEXT || '@' ||
           domains[floor(random() * array_length(domains, 1)) + 1];
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_device_id() RETURNS TEXT AS $$
BEGIN
    RETURN upper(substr(md5(random()::text), 1, 8) || '-' || substr(md5(random()::text), 1, 4) || '-' ||
                 substr(md5(random()::text), 1, 4) || '-' || substr(md5(random()::text), 1, 4) || '-' ||
                 substr(md5(random()::text), 1, 12));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_session_id() RETURNS TEXT AS $$
BEGIN
    RETURN 'SES_' || upper(substr(md5(random()::text), 1, 32));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_us_ip() RETURNS TEXT AS $$
DECLARE
    us_ranges TEXT[] := ARRAY['173.252.','69.171.','23.','104.','151.','192.168.','10.0.'];
BEGIN
    RETURN us_ranges[floor(random() * array_length(us_ranges, 1)) + 1] ||
           floor(random() * 255)::TEXT || '.' || (floor(random() * 255) + 1)::TEXT;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_device_info() RETURNS TEXT AS $$
DECLARE
    devices TEXT[] := ARRAY['iPhone 15 Pro Max; iOS 17.1.1','iPhone 14 Pro; iOS 16.7.2','Samsung Galaxy S24 Ultra; Android 14','Google Pixel 8 Pro; Android 14'];
BEGIN
    RETURN devices[floor(random() * array_length(devices, 1)) + 1];
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- STEP 1: GUEST REGISTRATION ATTEMPTS
-- KEY FIX: Proper timing - guest_complete = guest_start + 30-60 seconds
-- =====================================================================================

-- Create temp table to track guest registration times properly
CREATE TEMP TABLE temp_guest_registrations AS
SELECT
    i as user_id,
    generate_session_id() as session_id,
    generate_healthcare_email(i) as user_email,
    generate_device_id() as device_id,
    generate_device_info() as device_info,
    generate_us_ip() as ip_address,
    generate_us_phone() as user_phone,
    -- Start times spread over last 90 days for reporting
    NOW() - INTERVAL '1 day' * (random() * 90)::INTEGER - INTERVAL '1 hour' * (random() * 24)::INTEGER as started_on,
    -- Success rate for conversion > 95%
    CASE WHEN random() < 0.96 THEN true ELSE false END as will_complete_guest,
    CASE WHEN random() < 0.65 THEN 'iOS' ELSE 'Android' END as platform,
    floor(random() * 1000000)::BIGINT as reference_id
FROM generate_series(1, 3500) AS i;

-- Insert guest registrations with proper timing
INSERT INTO guest.registration_attempt (
    session_id, client_id, user_email, device_id, device_info, ip_address,
    country_code, user_phone, registration_type, verification_document_type,
    registration_started_on, registration_completed_on, status, platform, reference_id
)
SELECT
    session_id,
    100 AS client_id,
    user_email,
    device_id,
    device_info,
    ip_address,
    'US' as country_code,
    user_phone,
    5 AS registration_type,  -- GUEST
    1 AS verification_document_type,
    started_on as registration_started_on,
    -- FIX: Guest completes 30-60 seconds after start (not random time!)
    CASE WHEN will_complete_guest THEN started_on + INTERVAL '1 second' * (30 + random() * 30)::INTEGER
         ELSE NULL END as registration_completed_on,
    CASE WHEN will_complete_guest THEN 2 ELSE 1 END as status,  -- 2=COMPLETED, 1=IN_PROGRESS
    platform,
    reference_id
FROM temp_guest_registrations;

-- =====================================================================================
-- STEP 2: GUEST VERIFICATION ATTEMPTS (Phone + Email)
-- =====================================================================================

INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id,
    100,
    vt.verification_type,
    CASE WHEN vt.verification_type IN (1, 2) THEN ra.user_phone ELSE ra.user_email END,
    CASE WHEN vt.verification_type IN (1, 2) THEN '+1' ELSE NULL END,
    1,
    ra.registration_started_on + INTERVAL '1 second' * (vt.step_order * 5)::INTEGER,
    CASE WHEN ra.status = 2 THEN
        ra.registration_started_on + INTERVAL '1 second' * (vt.step_order * 5 + 5 + random() * 10)::INTEGER
    ELSE NULL END,
    lpad(floor(random() * 1000000)::TEXT, 6, '0'),
    CASE WHEN ra.status = 2 THEN 2 ELSE 1 END,
    false, false, false
FROM guest.registration_attempt ra
CROSS JOIN (
    SELECT 1 as verification_type, 1 as step_order  -- SMS
    UNION ALL
    SELECT 3 as verification_type, 2 as step_order  -- Email
) vt
WHERE ra.client_id = 100 AND ra.registration_type = 5;

-- =====================================================================================
-- STEP 3: GUEST USERS TABLE
-- KEY FIX: Create guest_user for EVERY completed guest with email verification
-- This ensures email_verified_count = guest_registered_count
-- =====================================================================================

INSERT INTO guest.guest_users (
    client_id, email, country_code, phone_number, password,
    created_on, updated_on, promoted_to_member, reference_member_id,
    language_preference, is_active
)
SELECT
    100,
    ra.user_email,
    'US',
    ra.user_phone,
    '$2a$10$' || substr(md5(random()::text), 1, 53),
    ra.registration_started_on,
    ra.registration_completed_on,
    false,  -- Not yet promoted
    NULL,
    'en',
    true  -- KEY FIX: is_active = true for all completed guest registrations
FROM guest.registration_attempt ra
WHERE ra.client_id = 100
    AND ra.registration_type = 5
    AND ra.status = 2  -- Only completed
    AND EXISTS (
        SELECT 1 FROM guest.verification_attempt va
        WHERE va.registration_attempt_id = ra.id
            AND va.verification_type = 3  -- Email
            AND va.status = 2  -- Completed
    );

-- =====================================================================================
-- STEP 4: FULL REGISTRATION ATTEMPTS
-- KEY FIX: Full registration starts and completes within 5 minutes of guest start
-- This ensures average completion time < 5 minutes
-- =====================================================================================

-- Create temp table for full registration timing
CREATE TEMP TABLE temp_full_registrations AS
SELECT
    ra_guest.id as guest_ra_id,
    ra_guest.user_email,
    ra_guest.device_id,
    ra_guest.device_info,
    ra_guest.ip_address,
    ra_guest.user_phone,
    ra_guest.platform,
    ra_guest.registration_started_on as guest_started_on,
    ra_guest.registration_completed_on as guest_completed_on,
    -- FIX: Full starts 60-120 seconds after guest completion
    ra_guest.registration_completed_on + INTERVAL '1 second' * (60 + random() * 60)::INTEGER as full_started_on,
    -- 96% of completed guests proceed to full registration
    CASE WHEN random() < 0.96 THEN true ELSE false END as will_complete_full
FROM guest.registration_attempt ra_guest
WHERE ra_guest.client_id = 100
    AND ra_guest.registration_type = 5
    AND ra_guest.status = 2  -- Only completed guests
    AND EXISTS (
        SELECT 1 FROM guest.verification_attempt va
        WHERE va.registration_attempt_id = ra_guest.id
            AND va.verification_type IN (1, 3)  -- Phone and Email
            AND va.status = 2
    );

-- Insert full registrations
INSERT INTO guest.registration_attempt (
    session_id, client_id, user_email, device_id, device_info, ip_address,
    country_code, user_phone, registration_type, verification_document_type,
    registration_started_on, registration_completed_on, status, platform, reference_id
)
SELECT
    generate_session_id(),
    100,
    user_email,
    device_id,
    device_info,
    ip_address,
    'US',
    user_phone,
    4,  -- FULL registration
    1,
    full_started_on,
    -- FIX: Full completes 60-120 seconds after full start
    CASE WHEN will_complete_full THEN full_started_on + INTERVAL '1 second' * (60 + random() * 60)::INTEGER
         ELSE NULL END,
    CASE WHEN will_complete_full THEN 2 ELSE 1 END,
    platform,
    floor(random() * 1000000)::BIGINT
FROM temp_full_registrations
WHERE random() < 0.96;  -- 96% of guests proceed to full

-- =====================================================================================
-- STEP 5: FULL REGISTRATION VERIFICATION ATTEMPTS
-- KEY FIX: Ensure every full registration has demographic verification
-- This ensures full_registered <= demographic_verified
-- =====================================================================================

INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id,
    100,
    vt.verification_type,
    'DOC_' || ra.id || '_' || vt.verification_type,
    'VER',
    1,
    ra.registration_started_on + INTERVAL '1 second' * (vt.step_order * 10)::INTEGER,
    CASE WHEN ra.status = 2 THEN
        ra.registration_started_on + INTERVAL '1 second' * (vt.step_order * 10 + 10 + random() * 20)::INTEGER
    ELSE NULL END,
    NULL,
    CASE WHEN ra.status = 2 THEN 2 ELSE 1 END,
    false, false, false
FROM guest.registration_attempt ra
CROSS JOIN (
    SELECT 4 as verification_type, 1 as step_order  -- Demographic (REQUIRED)
    UNION ALL
    SELECT 7 as verification_type, 2 as step_order  -- License Front
    UNION ALL
    SELECT 8 as verification_type, 3 as step_order  -- License Back
) vt
WHERE ra.client_id = 100 AND ra.registration_type = 4;

-- Also add email verification for full registration users
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id,
    100,
    3,  -- Email
    ra.user_email,
    NULL,
    1,
    ra.registration_started_on + INTERVAL '5 seconds',
    ra.registration_started_on + INTERVAL '25 seconds',
    lpad(floor(random() * 1000000)::TEXT, 6, '0'),
    2,  -- Completed
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND ra.status = 2;

-- =====================================================================================
-- STEP 6: IDENTITY VERIFICATION DATA
-- KEY FIX: Diverse names (not just Gabriel Bryant), proper session_id linking
-- =====================================================================================

INSERT INTO guest.identity_verification_data (
    identification_id, first_name, last_name, middle_name, dob, document_type,
    data_source, state, city, zip, address_line_1, gender, expiration_date,
    height, eye_color, issued_date, license_number, current_state, current_city,
    current_zip, current_address_line_1, details, ssn, attempt_number
)
SELECT
    ra.session_id,  -- KEY: Link by session_id
    -- FIX: Generate diverse names
    (ARRAY['Alexander','Sophia','Benjamin','Isabella','Christopher','Emma','Daniel','Olivia','Ethan','Ava','Gabriel','Mia','Isaac','Charlotte','Jacob','Abigail','Liam','Harper','Lucas','Evelyn','Mason','Ella','Noah','Scarlett','Oliver','Grace','Sebastian','Chloe','William','Victoria','James','Riley'])[floor(random() * 32 + 1)],
    (ARRAY['Anderson','Thomas','Jackson','White','Harris','Martin','Thompson','Garcia','Martinez','Robinson','Clark','Rodriguez','Lewis','Lee','Walker','Hall','Allen','Young','King','Wright','Lopez','Hill','Scott','Green','Adams','Baker','Nelson','Carter'])[floor(random() * 28 + 1)],
    (ARRAY['A','B','C','D','E','F','G','H','J','K','L','M'])[floor(random() * 12 + 1)],
    (CURRENT_DATE - INTERVAL '1 year' * (18 + random() * 57)::INTEGER)::DATE,
    1,  -- Driving license
    1,  -- Manual entry
    (ARRAY['NY','CA','TX','FL','PA','IL','OH','GA','NC','MI'])[floor(random() * 10 + 1)],
    (ARRAY['New York','Los Angeles','Chicago','Houston','Phoenix'])[floor(random() * 5 + 1)],
    lpad((floor(random() * 90000) + 10000)::TEXT, 5, '0'),
    (floor(random() * 5000) + 100)::TEXT || ' ' || (ARRAY['Main St','Oak Ave','Park Dr','Elm St','Maple Ave'])[floor(random() * 5 + 1)],
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    (CURRENT_DATE + INTERVAL '1 year' * (1 + random() * 4)::INTEGER)::DATE,
    60 + random() * 18,
    (ARRAY['BRO','BLU','GRN','HAZ','GRY'])[floor(random() * 5 + 1)],
    (CURRENT_DATE - INTERVAL '1 year' * (1 + random() * 7)::INTEGER)::DATE,
    upper(chr(65 + floor(random() * 26)::INTEGER) || lpad(floor(random() * 100000000)::TEXT, 8, '0')),
    (ARRAY['NY','CA','TX','FL','PA'])[floor(random() * 5 + 1)],
    (ARRAY['New York','Los Angeles','Chicago'])[floor(random() * 3 + 1)],
    lpad((floor(random() * 90000) + 10000)::TEXT, 5, '0'),
    (floor(random() * 5000) + 100)::TEXT || ' ' || (ARRAY['Main St','Oak Ave'])[floor(random() * 2 + 1)],
    ('{"verification_score": ' || (88 + random() * 12)::INTEGER || ', "confidence": ' || (92 + random() * 8)::INTEGER || '}')::json,
    lpad((100 + floor(random() * 665))::TEXT, 3, '0') || '-' || lpad((1 + floor(random() * 99))::TEXT, 2, '0') || '-' || lpad((1 + floor(random() * 9999))::TEXT, 4, '0'),
    1
FROM guest.registration_attempt ra
WHERE ra.client_id = 100
    AND ra.registration_type = 4
    AND ra.status = 2  -- Only completed full registrations
    AND EXISTS (
        SELECT 1 FROM guest.verification_attempt va
        WHERE va.registration_attempt_id = ra.id
            AND va.verification_type = 4  -- Demographic
            AND va.status = 2
    );

-- =====================================================================================
-- STEP 7: GUEST REGISTRATION LOG
-- KEY FIX: Proper match types for demographic validation query
-- =====================================================================================

INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    ssn, matched_member_id
)
SELECT
    ra.session_id,
    100,
    ivd.first_name,
    ivd.last_name,
    ivd.dob,
    ivd.gender,
    (ARRAY['UNIQUE_MATCH','EXACT_NAME_DOB_GENDER_AND_ZIP_MATCH','AUTO_PROMOTED'])[floor(random() * 3 + 1)],
    (ARRAY['UNIQUE_MATCH','AUTO_PROMOTED','REGISTRATION_COMPLETED'])[floor(random() * 3 + 1)],
    ('{"ip_address": "' || generate_us_ip() || '", "timestamp": "' || NOW()::TEXT || '"}')::json,
    gu.id,
    ivd.ssn,
    floor(random() * 100000 + 10000)::BIGINT
FROM guest.registration_attempt ra
INNER JOIN guest.identity_verification_data ivd ON ivd.identification_id = ra.session_id
LEFT JOIN guest.guest_users gu ON gu.email = ra.user_email
WHERE ra.client_id = 100
    AND ra.registration_type = 4
    AND ra.status = 2;

-- KEY FIX: Create some users with demographic completed but NOT full registration completed
-- This is for the buildDemographicValidationQuery to return data
INSERT INTO guest.registration_attempt (
    session_id, client_id, user_email, device_id, device_info, ip_address,
    country_code, user_phone, registration_type, verification_document_type,
    registration_started_on, registration_completed_on, status, platform, reference_id
)
SELECT
    generate_session_id(),
    100,
    'pending.' || i || '@test.com',
    generate_device_id(),
    generate_device_info(),
    generate_us_ip(),
    'US',
    generate_us_phone(),
    5,  -- GUEST type
    1,
    NOW() - INTERVAL '1 hour' * i,
    NOW() - INTERVAL '1 hour' * i + INTERVAL '1 minute',
    1,  -- IN_PROGRESS (not completed!)
    'iOS',
    floor(random() * 1000000)::BIGINT
FROM generate_series(1, 20) AS i;

-- Add demographic verification for these pending users
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id,
    100,
    4,  -- Demographic
    'DOC_' || ra.id,
    'VER',
    1,
    ra.registration_started_on + INTERVAL '30 seconds',
    ra.registration_started_on + INTERVAL '90 seconds',
    NULL,
    2,  -- Completed
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.user_email LIKE 'pending.%@test.com';

-- Add identity data for pending users
INSERT INTO guest.identity_verification_data (
    identification_id, first_name, last_name, dob, document_type,
    data_source, state, city, zip, address_line_1, gender
)
SELECT
    ra.session_id,
    (ARRAY['Michael','Sarah','David','Emma','John','Lisa'])[floor(random() * 6 + 1)],
    (ARRAY['Johnson','Williams','Brown','Davis','Miller'])[floor(random() * 5 + 1)],
    (CURRENT_DATE - INTERVAL '1 year' * (25 + random() * 40)::INTEGER)::DATE,
    1, 1, 'NY', 'New York', '10001',
    floor(random() * 1000)::TEXT || ' Broadway',
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END
FROM guest.registration_attempt ra
WHERE ra.user_email LIKE 'pending.%@test.com';

-- =====================================================================================
-- CLEANUP
-- =====================================================================================

DROP TABLE IF EXISTS temp_guest_registrations;
DROP TABLE IF EXISTS temp_full_registrations;

DROP FUNCTION IF EXISTS generate_us_phone();
DROP FUNCTION IF EXISTS generate_healthcare_email();
DROP FUNCTION IF EXISTS generate_device_id();
DROP FUNCTION IF EXISTS generate_session_id();
DROP FUNCTION IF EXISTS generate_us_ip();
DROP FUNCTION IF EXISTS generate_device_info();

COMMIT;

-- =====================================================================================
-- VERIFICATION QUERIES
-- =====================================================================================

-- Test 1: Average completion time (should be < 5 minutes = 300 seconds)
SELECT
    'Average Completion Time' as metric,
    ROUND(AVG(EXTRACT(EPOCH FROM (full_ra.registration_completed_on - guest_ra.registration_started_on))), 2) as seconds,
    ROUND(AVG(EXTRACT(EPOCH FROM (full_ra.registration_completed_on - guest_ra.registration_started_on))) / 60.0, 2) as minutes
FROM guest.registration_attempt guest_ra
INNER JOIN guest.registration_attempt full_ra ON guest_ra.user_email = full_ra.user_email
INNER JOIN guest.guest_registration_log grl ON grl.identification_id = full_ra.session_id
WHERE guest_ra.registration_type = 5
    AND full_ra.registration_type = 4
    AND full_ra.status = 2
    AND guest_ra.status = 2
    AND guest_ra.registration_started_on IS NOT NULL
    AND full_ra.registration_completed_on IS NOT NULL
    AND grl.action != 'SENT_TO_CUSTOMER_SUPPORT'
    AND guest_ra.client_id = 100;

-- Test 2: Conversion rate (should be > 95%)
SELECT
    'Conversion Rate' as metric,
    ROUND(COUNT(*) FILTER (WHERE status = 2) * 100.0 / COUNT(*), 2) as percentage
FROM guest.registration_attempt
WHERE client_id = 100;

-- Test 3: Email verified vs Guest registered (should be equal)
WITH email_verified AS (
    SELECT COUNT(DISTINCT ra.user_email) as count
    FROM guest.registration_attempt ra
    INNER JOIN guest.verification_attempt va ON va.registration_attempt_id = ra.id
    WHERE ra.registration_type = 5
        AND ra.status = 2
        AND va.verification_type = 3
        AND va.status = 2
        AND ra.client_id = 100
),
guest_registered AS (
    SELECT COUNT(DISTINCT email) as count
    FROM guest.guest_users
    WHERE client_id = 100 AND is_active = true
)
SELECT
    'Email Verified Count' as metric, ev.count as value FROM email_verified ev
UNION ALL
SELECT
    'Guest Registered Count' as metric, gr.count as value FROM guest_registered gr;

-- Test 4: Recent users for demographic validation (should return > 0)
SELECT COUNT(*) as recent_users_count
FROM guest.registration_attempt ra
WHERE ra.user_email IS NOT NULL
    AND ra.status != 2  -- Not completed
    AND EXISTS (
        SELECT 1 FROM guest.verification_attempt va_demo
        WHERE va_demo.registration_attempt_id = ra.id
            AND va_demo.verification_type = 4
            AND va_demo.status = 2
    )
    AND ra.client_id = 100;

-- Test 5: Funnel metrics (full <= demographic)
WITH funnel AS (
    SELECT
        COUNT(DISTINCT CASE WHEN ra.registration_type = 5 THEN ra.device_id END) as downloads,
        COUNT(DISTINCT CASE WHEN va_demo.status = 2 THEN ra.user_email END) as demographic_verified,
        COUNT(DISTINCT CASE WHEN ra.registration_type = 4 AND ra.status = 2 THEN ra.user_email END) as full_registered
    FROM guest.registration_attempt ra
    LEFT JOIN guest.verification_attempt va_demo
        ON va_demo.registration_attempt_id = ra.id AND va_demo.verification_type = 4
    WHERE ra.client_id = 100
)
SELECT
    downloads,
    demographic_verified,
    full_registered,
    CASE WHEN full_registered <= demographic_verified THEN 'PASS' ELSE 'FAIL' END as funnel_check
FROM funnel;

-- Test 6: Name diversity (should show multiple different names)
SELECT
    COALESCE(ivd.first_name || ' ' || ivd.last_name, 'Unknown') as full_name,
    COUNT(*) as count
FROM guest.registration_attempt ra
LEFT JOIN guest.identity_verification_data ivd ON ra.session_id = ivd.identification_id
WHERE ra.client_id = 100
    AND ra.registration_type = 4
    AND ra.status = 2
GROUP BY ivd.first_name, ivd.last_name
ORDER BY count DESC
LIMIT 10;
