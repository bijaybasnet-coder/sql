-- =====================================================================================
-- FINAL FIX: US Healthcare Mobile App Registration Test Data Generation
-- Client ID: 100
-- Target: >95% OVERALL conversion with proper DISTINCT count funnel flow
--
-- FUNNEL FLOW (based on Java getFunnelStageMetrics):
-- 1. Phone Verified: COUNT DISTINCT device_id with SMS/VOICE completed (GUEST)
-- 2. Email Verified: COUNT DISTINCT email with EMAIL completed (GUEST)
-- 3. Guest Registered: COUNT DISTINCT email from guest_users (is_active = true)
-- 4. Demographic Verified: COUNT DISTINCT email with DEMOGRAPHIC completed (FULL)
-- 5. Full Registered: COUNT DISTINCT email with FULL status = COMPLETED
--
-- Each stage % = current / previous (not from total downloads)
-- Overall conversion = Full Registered / Total Downloads
-- =====================================================================================

BEGIN;
SET timezone = 'America/New_York';

-- =====================================================================================
-- UTILITY FUNCTIONS
-- =====================================================================================

CREATE OR REPLACE FUNCTION generate_us_phone() RETURNS TEXT AS $$
DECLARE
    area_codes TEXT[] := ARRAY['202','212','213','214','305','310','312','404','415','510','512','617','619','702','703','714','718','720','832','925'];
BEGIN
    RETURN area_codes[floor(random() * array_length(area_codes, 1)) + 1] ||
           lpad((floor(random() * 800) + 200)::TEXT, 3, '0') ||
           lpad((floor(random() * 10000))::TEXT, 4, '0');
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
-- Target: 3000 total downloads, 99% will complete phone+email for 95%+ overall
-- =====================================================================================

CREATE TEMP TABLE temp_guest_registrations AS
SELECT
    i as user_id,
    generate_session_id() as session_id,
    generate_healthcare_email(i) as user_email,
    generate_device_id() as device_id,
    generate_device_info() as device_info,
    generate_us_ip() as ip_address,
    generate_us_phone() as user_phone,
    NOW() - INTERVAL '1 day' * (random() * 90)::INTEGER - INTERVAL '1 hour' * (random() * 24)::INTEGER as started_on,
    -- 99% will succeed in phone+email verification
    CASE WHEN random() < 0.99 THEN true ELSE false END as will_succeed_phone,
    CASE WHEN random() < 0.99 THEN true ELSE false END as will_succeed_email,
    CASE WHEN random() < 0.65 THEN 'iOS' ELSE 'Android' END as platform,
    floor(random() * 1000000)::BIGINT as reference_id
FROM generate_series(1, 3000) AS i;

INSERT INTO guest.registration_attempt (
    session_id, client_id, user_email, device_id, device_info, ip_address,
    country_code, user_phone, registration_type, verification_document_type,
    registration_started_on, registration_completed_on, status, platform, reference_id
)
SELECT
    session_id, 100, user_email, device_id, device_info, ip_address, 'US', user_phone,
    5, 1,
    started_on,
    CASE WHEN will_succeed_phone AND will_succeed_email THEN
        started_on + INTERVAL '1 second' * (30 + random() * 90)::INTEGER
    ELSE NULL END,
    CASE WHEN will_succeed_phone AND will_succeed_email THEN 2 ELSE 1 END,
    platform, reference_id
FROM temp_guest_registrations;

-- =====================================================================================
-- STEP 2: PHONE VERIFICATION (SMS + VOICE) - 99% SUCCESS RATE
-- This determines Phone Verified count (DISTINCT device_id)
-- =====================================================================================

-- First attempt SMS (everyone gets this) - 99% SUCCESS for those who will_succeed_phone
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100,
    1,  -- SMS
    ra.user_phone, '+1', 1,
    ra.registration_started_on + INTERVAL '5 seconds',
    CASE WHEN tgr.will_succeed_phone THEN  -- 99% of users will succeed
        ra.registration_started_on + INTERVAL '15 seconds'
    ELSE NULL END,
    lpad(floor(random() * 1000000)::TEXT, 6, '0'),
    CASE WHEN tgr.will_succeed_phone THEN 2 ELSE 1 END,
    random() < 0.06,  -- 6% captcha triggers
    random() < 0.04,  -- 4% rate limits
    false
FROM guest.registration_attempt ra
INNER JOIN temp_guest_registrations tgr ON tgr.device_id = ra.device_id
WHERE ra.client_id = 100 AND ra.registration_type = 5;

-- Second attempt SMS (1% need retry from those who didn't succeed first)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100,
    1,  -- SMS
    ra.user_phone, '+1', 2,
    ra.registration_started_on + INTERVAL '45 seconds',
    CASE WHEN random() < 0.85 THEN
        ra.registration_started_on + INTERVAL '55 seconds'
    ELSE NULL END,
    lpad(floor(random() * 1000000)::TEXT, 6, '0'),
    CASE WHEN random() < 0.85 THEN 2 ELSE 1 END,
    random() < 0.10,
    random() < 0.06,
    false
FROM guest.registration_attempt ra
INNER JOIN temp_guest_registrations tgr ON tgr.device_id = ra.device_id
WHERE ra.client_id = 100 AND ra.registration_type = 5 AND NOT tgr.will_succeed_phone AND random() < 0.80;

-- Voice callback attempts (8% use voice fallback)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100,
    2,  -- VOICE
    ra.user_phone, '+1', 1,
    ra.registration_started_on + INTERVAL '30 seconds',
    CASE WHEN tgr.will_succeed_phone THEN
        ra.registration_started_on + INTERVAL '50 seconds'
    ELSE NULL END,
    lpad(floor(random() * 1000000)::TEXT, 6, '0'),
    CASE WHEN tgr.will_succeed_phone THEN 2 ELSE 1 END,
    random() < 0.05,
    random() < 0.03,
    false
FROM guest.registration_attempt ra
INNER JOIN temp_guest_registrations tgr ON tgr.device_id = ra.device_id
WHERE ra.client_id = 100 AND ra.registration_type = 5 AND random() < 0.08;

-- Third attempt SMS (rare retries)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 1, ra.user_phone, '+1', 3,
    ra.registration_started_on + INTERVAL '90 seconds',
    CASE WHEN tgr.will_succeed_phone THEN ra.registration_started_on + INTERVAL '100 seconds' ELSE NULL END,
    lpad(floor(random() * 1000000)::TEXT, 6, '0'),
    CASE WHEN tgr.will_succeed_phone THEN 2 ELSE 5 END,
    random() < 0.12, random() < 0.08, false
FROM guest.registration_attempt ra
INNER JOIN temp_guest_registrations tgr ON tgr.device_id = ra.device_id
WHERE ra.client_id = 100 AND ra.registration_type = 5 AND random() < 0.03;

-- =====================================================================================
-- STEP 3: EMAIL VERIFICATION - 99% SUCCESS RATE
-- This determines Email Verified count (DISTINCT email)
-- Only for those who succeeded in phone verification
-- =====================================================================================

-- First email attempt (99% succeed among those who passed phone)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100,
    3,  -- EMAIL
    ra.user_email, NULL, 1,
    ra.registration_started_on + INTERVAL '20 seconds',
    CASE WHEN tgr.will_succeed_phone AND tgr.will_succeed_email THEN
        ra.registration_started_on + INTERVAL '35 seconds'
    ELSE NULL END,
    lpad(floor(random() * 1000000)::TEXT, 6, '0'),
    CASE WHEN tgr.will_succeed_phone AND tgr.will_succeed_email THEN 2 ELSE 1 END,
    false,  -- NO captcha for email
    random() < 0.02,  -- 2% rate limit
    false
FROM guest.registration_attempt ra
INNER JOIN temp_guest_registrations tgr ON tgr.device_id = ra.device_id
WHERE ra.client_id = 100 AND ra.registration_type = 5 AND tgr.will_succeed_phone;

-- Second email attempt - RESENDS (5% need code resend)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100,
    3,  -- EMAIL
    ra.user_email, NULL, 2,  -- attempt_number = 2 for resends
    ra.registration_started_on + INTERVAL '60 seconds',
    CASE WHEN ra.status = 2 THEN
        ra.registration_started_on + INTERVAL '75 seconds'
    ELSE NULL END,
    lpad(floor(random() * 1000000)::TEXT, 6, '0'),
    CASE WHEN ra.status = 2 THEN 2 ELSE 1 END,
    false,  -- NO captcha for email
    random() < 0.04,  -- 4% rate limit on resend
    false
FROM guest.registration_attempt ra
INNER JOIN temp_guest_registrations tgr ON tgr.device_id = ra.device_id
WHERE ra.client_id = 100 AND ra.registration_type = 5 AND ra.status = 2
    AND random() < 0.05;

-- =====================================================================================
-- STEP 4: GUEST USERS TABLE
-- Guest Registered = Email Verified (same DISTINCT email count)
-- Only for those who completed both phone and email verification
-- =====================================================================================

INSERT INTO guest.guest_users (
    client_id, email, country_code, phone_number, password,
    created_on, updated_on, promoted_to_member, reference_member_id,
    language_preference, is_active
)
SELECT
    100, ra.user_email, 'US', ra.user_phone,
    '$2a$10$' || substr(md5(random()::text), 1, 53),
    ra.registration_started_on, ra.registration_completed_on,
    false, NULL, 'en', true
FROM guest.registration_attempt ra
INNER JOIN temp_guest_registrations tgr ON tgr.device_id = ra.device_id
WHERE ra.client_id = 100 AND ra.registration_type = 5
    AND tgr.will_succeed_phone AND tgr.will_succeed_email;

-- =====================================================================================
-- STEP 5: FULL REGISTRATION ATTEMPTS - 99% PROCEED, 97% COMPLETE
-- =====================================================================================

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
    ra_guest.registration_completed_on + INTERVAL '1 second' * (60 + random() * 60)::INTEGER as full_started_on,
    -- 99% COMPLETED (to achieve 95%+ overall: 0.99 * 0.99 * 0.99 * 0.99 = 96.1%)
    CASE
        WHEN random() < 0.99 THEN 2  -- 99% COMPLETED
        WHEN random() < 0.015 THEN 1  -- 1.5% IN_PROGRESS
        WHEN random() < 0.008 THEN 4  -- 0.8% IN_HOLDING_TABLE
        WHEN random() < 0.005 THEN 9  -- 0.5% IN_CUSTOMER_SUPPORT
        WHEN random() < 0.003 THEN 7  -- 0.3% IN_VERIFICATION
        WHEN random() < 0.001 THEN 8  -- 0.1% IN_IDENTIFICATION
        ELSE 5                        -- 0.1% FAILED
    END as final_status,
    -- 99% will have successful demographic verification
    CASE WHEN random() < 0.99 THEN true ELSE false END as will_succeed_demographic
FROM guest.registration_attempt ra_guest
INNER JOIN temp_guest_registrations tgr ON tgr.device_id = ra_guest.device_id
WHERE ra_guest.client_id = 100
    AND ra_guest.registration_type = 5
    AND tgr.will_succeed_phone AND tgr.will_succeed_email
    AND random() < 0.99;  -- 99% proceed to full registration

INSERT INTO guest.registration_attempt (
    session_id, client_id, user_email, device_id, device_info, ip_address,
    country_code, user_phone, registration_type, verification_document_type,
    registration_started_on, registration_completed_on, status, platform, reference_id
)
SELECT
    generate_session_id(), 100, user_email, device_id, device_info, ip_address,
    'US', user_phone, 4, 1,
    full_started_on,
    CASE WHEN final_status = 2 THEN full_started_on + INTERVAL '1 second' * (60 + random() * 120)::INTEGER ELSE NULL END,
    final_status,
    platform,
    floor(random() * 1000000)::BIGINT
FROM temp_full_registrations;

-- =====================================================================================
-- STEP 6: FULL REGISTRATION VERIFICATIONS
-- Demographic: 99% success (determines Demographic Verified count)
-- All doc types: 87%+ first-try success
-- =====================================================================================

-- Demographic verification - MANDATORY (ALL full registrations) - 99% SUCCESS
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 4, 'DOC_' || ra.id || '_4', 'VER', 1,
    ra.registration_started_on + INTERVAL '10 seconds',
    CASE WHEN tfr.will_succeed_demographic THEN
        ra.registration_started_on + INTERVAL '25 seconds'
    ELSE NULL END,
    NULL,
    CASE WHEN tfr.will_succeed_demographic THEN 2 ELSE 1 END,
    false, false, false
FROM guest.registration_attempt ra
INNER JOIN temp_full_registrations tfr ON tfr.user_email = ra.user_email AND ra.registration_type = 4
WHERE ra.client_id = 100 AND ra.registration_type = 4;

-- Demographic retry (1% need retry) - 95% SUCCESS
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 4, 'DOC_' || ra.id || '_4', 'VER', 2,
    ra.registration_started_on + INTERVAL '45 seconds',
    CASE WHEN random() < 0.95 THEN ra.registration_started_on + INTERVAL '60 seconds' ELSE NULL END,
    NULL,
    CASE WHEN random() < 0.95 THEN 2 ELSE 5 END,
    false, false, false
FROM guest.registration_attempt ra
INNER JOIN temp_full_registrations tfr ON tfr.user_email = ra.user_email AND ra.registration_type = 4
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND NOT tfr.will_succeed_demographic;

-- License Front - 89% first-try success
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 7, 'DOC_' || ra.id || '_7', 'VER', 1,
    ra.registration_started_on + INTERVAL '30 seconds',
    CASE WHEN random() < 0.89 THEN
        ra.registration_started_on + INTERVAL '50 seconds'
    ELSE NULL END,
    NULL,
    CASE WHEN random() < 0.89 THEN 2 ELSE 1 END,
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4;

-- License Front retry (11% need retry)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 7, 'DOC_' || ra.id || '_7', 'VER', 2,
    ra.registration_started_on + INTERVAL '70 seconds',
    CASE WHEN ra.status IN (2, 4, 9) THEN ra.registration_started_on + INTERVAL '85 seconds' ELSE NULL END,
    NULL,
    CASE WHEN ra.status IN (2, 4, 9) THEN 2 ELSE 5 END,
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND random() < 0.11;

-- License Back - 88% first-try success
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 8, 'DOC_' || ra.id || '_8', 'VER', 1,
    ra.registration_started_on + INTERVAL '55 seconds',
    CASE WHEN random() < 0.88 THEN
        ra.registration_started_on + INTERVAL '75 seconds'
    ELSE NULL END,
    NULL,
    CASE WHEN random() < 0.88 THEN 2 ELSE 1 END,
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4;

-- License Back retry (12% need retry)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 8, 'DOC_' || ra.id || '_8', 'VER', 2,
    ra.registration_started_on + INTERVAL '95 seconds',
    CASE WHEN ra.status IN (2, 4, 9) THEN ra.registration_started_on + INTERVAL '110 seconds' ELSE NULL END,
    NULL,
    CASE WHEN ra.status IN (2, 4, 9) THEN 2 ELSE 5 END,
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND random() < 0.12;

-- SSN/Insurance Card - 87% first-try success (75% provide this)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 9, 'DOC_' || ra.id || '_9', 'VER', 1,
    ra.registration_started_on + INTERVAL '80 seconds',
    CASE WHEN random() < 0.87 THEN
        ra.registration_started_on + INTERVAL '100 seconds'
    ELSE NULL END,
    NULL,
    CASE WHEN random() < 0.87 THEN 2 ELSE 1 END,
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND random() < 0.75;

-- SSN/Insurance Card retry (13% need retry)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 9, 'DOC_' || ra.id || '_9', 'VER', 2,
    ra.registration_started_on + INTERVAL '120 seconds',
    CASE WHEN ra.status IN (2, 4, 9) THEN ra.registration_started_on + INTERVAL '140 seconds' ELSE NULL END,
    NULL,
    CASE WHEN ra.status IN (2, 4, 9) THEN 2 ELSE 5 END,
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND random() < 0.13
    AND EXISTS (SELECT 1 FROM guest.verification_attempt va WHERE va.registration_attempt_id = ra.id AND va.verification_type = 9);

-- Selfie Match verification - 92% first-try success
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 5, 'DOC_' || ra.id || '_5', 'VER', 1,
    ra.registration_started_on + INTERVAL '105 seconds',
    CASE WHEN random() < 0.92 THEN
        ra.registration_started_on + INTERVAL '120 seconds'
    ELSE NULL END,
    NULL,
    CASE WHEN random() < 0.92 THEN 2 ELSE 1 END,
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4;

-- Selfie Match retry (8% need retry)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 5, 'DOC_' || ra.id || '_5', 'VER', 2,
    ra.registration_started_on + INTERVAL '140 seconds',
    CASE WHEN ra.status = 2 THEN ra.registration_started_on + INTERVAL '155 seconds' ELSE NULL END,
    NULL,
    CASE WHEN ra.status = 2 THEN 2 ELSE 5 END,
    false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND random() < 0.08;

-- Add email verification for full registration users
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 3, ra.user_email, NULL, 1,
    ra.registration_started_on + INTERVAL '5 seconds',
    ra.registration_started_on + INTERVAL '25 seconds',
    lpad(floor(random() * 1000000)::TEXT, 6, '0'),
    2, false, false, false
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND ra.status = 2;

-- =====================================================================================
-- STEP 7: IDENTITY VERIFICATION DATA - DIVERSE NAMES
-- Only for those with completed demographic verification
-- =====================================================================================

INSERT INTO guest.identity_verification_data (
    identification_id, first_name, last_name, middle_name, dob, document_type,
    data_source, state, city, zip, address_line_1, gender, expiration_date,
    height, eye_color, issued_date, license_number, current_state, current_city,
    current_zip, current_address_line_1, details, ssn, attempt_number
)
SELECT
    ra.session_id,
    (ARRAY['Alexander','Sophia','Benjamin','Isabella','Christopher','Emma','Daniel','Olivia','Ethan','Ava','Gabriel','Mia','Isaac','Charlotte','Jacob','Abigail','Liam','Harper','Lucas','Evelyn','Mason','Ella','Noah','Scarlett','Oliver','Grace','Sebastian','Chloe','William','Victoria','James','Riley'])[floor(random() * 32 + 1)],
    (ARRAY['Anderson','Thomas','Jackson','White','Harris','Martin','Thompson','Garcia','Martinez','Robinson','Clark','Rodriguez','Lewis','Lee','Walker','Hall','Allen','Young','King','Wright','Lopez','Hill','Scott','Green','Adams','Baker','Nelson','Carter'])[floor(random() * 28 + 1)],
    (ARRAY['A','B','C','D','E','F','G','H','J','K','L','M'])[floor(random() * 12 + 1)],
    (CURRENT_DATE - INTERVAL '1 year' * (18 + random() * 57)::INTEGER)::DATE,
    1, 1,
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
WHERE ra.client_id = 100 AND ra.registration_type = 4
    AND EXISTS (SELECT 1 FROM guest.verification_attempt va WHERE va.registration_attempt_id = ra.id AND va.verification_type = 4 AND va.status = 2);

-- =====================================================================================
-- STEP 8: GUEST REGISTRATION LOG - WITH PROPER GuestToFullMatchActionType ENUM VALUES
-- =====================================================================================

-- For completed full registrations with demographic verified
INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    ssn, matched_member_id
)
SELECT
    ra.session_id, 100, ivd.first_name, ivd.last_name, ivd.dob, ivd.gender,
    CASE
        WHEN row_number() OVER (ORDER BY random()) % 10 IN (0, 1) THEN 'UNIQUE_MATCH'
        WHEN row_number() OVER (ORDER BY random()) % 10 = 2 THEN 'EXACT_NAME_DOB_GENDER_AND_ZIP_MATCH'
        WHEN row_number() OVER (ORDER BY random()) % 10 = 3 THEN 'EXACT_NAME_AND_SSN_MATCH'
        WHEN row_number() OVER (ORDER BY random()) % 10 IN (4, 5) THEN 'AUTO_PROMOTED'
        ELSE 'UNIQUE_MATCH'
    END,
    CASE
        WHEN row_number() OVER (ORDER BY random()) % 10 IN (0, 1, 2, 4, 5) THEN 'Promoted To Member'
        WHEN row_number() OVER (ORDER BY random()) % 10 = 3 THEN 'Promoted To Member'
        ELSE 'Member Notified through Push and Email'
    END,
    ('{"ip_address": "' || generate_us_ip() || '", "timestamp": "' || NOW()::TEXT || '"}')::json,
    gu.id, ivd.ssn,
    floor(random() * 100000 + 10000)::BIGINT
FROM guest.registration_attempt ra
INNER JOIN guest.identity_verification_data ivd ON ivd.identification_id = ra.session_id
LEFT JOIN guest.guest_users gu ON gu.email = ra.user_email
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND ra.status = 2;

-- For IN_CUSTOMER_SUPPORT status
INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    ssn, matched_member_id
)
SELECT
    ra.session_id, 100,
    (ARRAY['Michael','Sarah','David','Emma'])[floor(random() * 4 + 1)],
    (ARRAY['Johnson','Williams','Brown','Davis'])[floor(random() * 4 + 1)],
    (CURRENT_DATE - INTERVAL '1 year' * (25 + random() * 40)::INTEGER)::DATE,
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    'SOFT_MATCH',
    'Sent to Customer Support',
    ('{"ip_address": "' || generate_us_ip() || '", "timestamp": "' || NOW()::TEXT || '"}')::json,
    NULL,
    lpad((100 + floor(random() * 665))::TEXT, 3, '0') || '-' || lpad((1 + floor(random() * 99))::TEXT, 2, '0') || '-' || lpad((1 + floor(random() * 9999))::TEXT, 4, '0'),
    floor(random() * 100000 + 10000)::BIGINT
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND ra.status = 9;

-- For IN_HOLDING_TABLE status
INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    ssn, matched_member_id
)
SELECT
    ra.session_id, 100,
    (ARRAY['John','Lisa','Robert','Anna'])[floor(random() * 4 + 1)],
    (ARRAY['Miller','Wilson','Moore','Taylor'])[floor(random() * 4 + 1)],
    (CURRENT_DATE - INTERVAL '1 year' * (20 + random() * 50)::INTEGER)::DATE,
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    'NO_MATCH',
    'Saved to Holding Table',
    ('{"ip_address": "' || generate_us_ip() || '", "timestamp": "' || NOW()::TEXT || '"}')::json,
    NULL,
    lpad((100 + floor(random() * 665))::TEXT, 3, '0') || '-' || lpad((1 + floor(random() * 99))::TEXT, 2, '0') || '-' || lpad((1 + floor(random() * 9999))::TEXT, 4, '0'),
    NULL
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND ra.status = 4;

-- =====================================================================================
-- STEP 9: ADDITIONAL VERIFICATION REQUESTS
-- =====================================================================================

-- Zip code requests
INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    ssn, matched_member_id, created_on
)
SELECT
    'ZIP_REQ_' || i, 100,
    (ARRAY['Alex','Maria','James','Anna'])[floor(random() * 4 + 1)],
    (ARRAY['Garcia','Miller','Wilson','Moore'])[floor(random() * 4 + 1)],
    (CURRENT_DATE - INTERVAL '1 year' * (20 + random() * 50)::INTEGER)::DATE,
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    'MULTIPLE_MATCH',
    'Asked Current Zip',
    ('{"verification_type": "zip_request", "timestamp": "' || NOW()::TEXT || '"}')::json,
    NULL,
    lpad((100 + floor(random() * 665))::TEXT, 3, '0') || '-' || lpad((1 + floor(random() * 99))::TEXT, 2, '0') || '-' || lpad((1 + floor(random() * 9999))::TEXT, 4, '0'),
    floor(random() * 100000 + 10000)::BIGINT,
    NOW() - INTERVAL '1 day' * (random() * 90)::INTEGER
FROM generate_series(1, 95) AS i;

-- Address requests
INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    ssn, matched_member_id, created_on
)
SELECT
    'ADDR_REQ_' || i, 100,
    (ARRAY['Kevin','Susan','Robert','Linda'])[floor(random() * 4 + 1)],
    (ARRAY['Clark','Lewis','Walker','Hall'])[floor(random() * 4 + 1)],
    (CURRENT_DATE - INTERVAL '1 year' * (20 + random() * 50)::INTEGER)::DATE,
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    'EXACT_NAME_AND_DOB_MATCH_WITH_ADDRESS_MISMATCH',
    'Asked Current Address',
    ('{"verification_type": "address_request", "timestamp": "' || NOW()::TEXT || '"}')::json,
    NULL,
    lpad((100 + floor(random() * 665))::TEXT, 3, '0') || '-' || lpad((1 + floor(random() * 99))::TEXT, 2, '0') || '-' || lpad((1 + floor(random() * 9999))::TEXT, 4, '0'),
    floor(random() * 100000 + 10000)::BIGINT,
    NOW() - INTERVAL '1 day' * (random() * 90)::INTEGER
FROM generate_series(1, 55) AS i;

-- =====================================================================================
-- STEP 10: RECENT USERS FOR DEMOGRAPHIC VALIDATION
-- =====================================================================================

INSERT INTO guest.registration_attempt (
    session_id, client_id, user_email, device_id, device_info, ip_address,
    country_code, user_phone, registration_type, verification_document_type,
    registration_started_on, registration_completed_on, status, platform, reference_id
)
SELECT
    generate_session_id(), 100,
    'pending.' || i || '@test.com',
    generate_device_id(), generate_device_info(), generate_us_ip(),
    'US', generate_us_phone(), 5, 1,
    NOW() - INTERVAL '1 hour' * i,
    NOW() - INTERVAL '1 hour' * i + INTERVAL '1 minute',
    1,  -- IN_PROGRESS
    'iOS', floor(random() * 1000000)::BIGINT
FROM generate_series(1, 20) AS i;

INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT
    ra.id, 100, 4, 'DOC_' || ra.id, 'VER', 1,
    ra.registration_started_on + INTERVAL '30 seconds',
    ra.registration_started_on + INTERVAL '90 seconds',
    NULL, 2, false, false, false
FROM guest.registration_attempt ra
WHERE ra.user_email LIKE 'pending.%@test.com';

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
-- FUNNEL METRICS VERIFICATION (matches Java getFunnelStageMetrics logic)
-- =====================================================================================

-- Phone Verified: COUNT DISTINCT device_id with SMS/VOICE completed (GUEST)
WITH phone_verified AS (
    SELECT COUNT(DISTINCT ra.device_id) as count
    FROM guest.registration_attempt ra
    INNER JOIN guest.verification_attempt va ON va.registration_attempt_id = ra.id
    WHERE ra.client_id = 100 AND ra.registration_type = 5
        AND va.verification_type IN (1, 2) AND va.status = 2
),
-- Email Verified: COUNT DISTINCT email with EMAIL completed (GUEST)
email_verified AS (
    SELECT COUNT(DISTINCT ra.user_email) as count
    FROM guest.registration_attempt ra
    INNER JOIN guest.verification_attempt va ON va.registration_attempt_id = ra.id
    WHERE ra.client_id = 100 AND ra.registration_type = 5
        AND va.verification_type = 3 AND va.status = 2
),
-- Guest Registered: COUNT DISTINCT email from guest_users
guest_registered AS (
    SELECT COUNT(DISTINCT email) as count
    FROM guest.guest_users
    WHERE client_id = 100 AND is_active = true
),
-- Demographic Verified: COUNT DISTINCT email with DEMOGRAPHIC completed (FULL)
demographic_verified AS (
    SELECT COUNT(DISTINCT ra.user_email) as count
    FROM guest.registration_attempt ra
    INNER JOIN guest.verification_attempt va ON va.registration_attempt_id = ra.id
    WHERE ra.client_id = 100 AND ra.registration_type = 4
        AND va.verification_type = 4 AND va.status = 2
),
-- Full Registered: COUNT DISTINCT email with FULL status = COMPLETED
full_registered AS (
    SELECT COUNT(DISTINCT user_email) as count
    FROM guest.registration_attempt
    WHERE client_id = 100 AND registration_type = 4 AND status = 2
),
-- Total Downloads (assume = total GUEST registration attempts)
total_downloads AS (
    SELECT COUNT(*) as count
    FROM guest.registration_attempt
    WHERE client_id = 100 AND registration_type = 5
)
SELECT
    'FUNNEL METRICS (matching Java getFunnelStageMetrics)' as stage,
    '' as count,
    '' as percentage
UNION ALL
SELECT
    'Total Downloads',
    (SELECT count FROM total_downloads)::TEXT,
    '100%'
UNION ALL
SELECT
    'Phone Verified',
    (SELECT count FROM phone_verified)::TEXT,
    ROUND((SELECT count FROM phone_verified) * 100.0 / (SELECT count FROM total_downloads), 2) || '%'
UNION ALL
SELECT
    'Email Verified',
    (SELECT count FROM email_verified)::TEXT,
    ROUND((SELECT count FROM email_verified) * 100.0 / (SELECT count FROM phone_verified), 2) || '%'
UNION ALL
SELECT
    'Guest Registered',
    (SELECT count FROM guest_registered)::TEXT,
    ROUND((SELECT count FROM guest_registered) * 100.0 / (SELECT count FROM email_verified), 2) || '%'
UNION ALL
SELECT
    'Demographic Verified',
    (SELECT count FROM demographic_verified)::TEXT,
    ROUND((SELECT count FROM demographic_verified) * 100.0 / (SELECT count FROM guest_registered), 2) || '%'
UNION ALL
SELECT
    'Full Registered',
    (SELECT count FROM full_registered)::TEXT,
    ROUND((SELECT count FROM full_registered) * 100.0 / (SELECT count FROM demographic_verified), 2) || '%'
UNION ALL
SELECT
    'OVERALL CONVERSION',
    (SELECT count FROM full_registered)::TEXT || ' / ' || (SELECT count FROM total_downloads)::TEXT,
    ROUND((SELECT count FROM full_registered) * 100.0 / (SELECT count FROM total_downloads), 2) || '%';
