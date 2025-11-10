-- =====================================================================================
-- US Healthcare Mobile App Registration Test Data Generation - ENHANCED
-- Client ID: 100
-- Target: 3500+ unique device attempts, 98%+ conversion, <2min avg time
-- Time Period: Last 3 months (recent users for demographic verification)
-- 
-- FIXES:
-- * Conversion rate increased to 98%+
-- * Average time reduced to under 2 minutes
-- * Randomized names (no more 'deborah davis')
-- * Recent users within last 3 months
-- * Proper demographic verification metrics with all match types
-- * Additional verification requests data
-- * Multiple verification attempts per registration
-- * All journey progress match types
-- 
-- ENHANCED REGISTRATION FLOW:
-- 1. App Download (unique device_id)
-- 2. Guest Registration: Phone (SMS + Voice callbacks) → Email → Guest Complete
-- 3. Full Registration: Demographic → License Front → License Back → SSN/Insurance → Full Complete
-- 4. Enhanced Identity Verification with all match types and verification statuses
-- 5. Proper timing: Guest completion BEFORE Full registration start
-- =====================================================================================

-- Disable auto-commit for transaction control
BEGIN;

-- Set timezone for consistent timestamps
SET timezone = 'America/New_York';

-- =====================================================================================
-- ENHANCED UTILITY FUNCTIONS FOR REALISTIC DATA GENERATION
-- =====================================================================================

-- Generate random US phone numbers
CREATE OR REPLACE FUNCTION generate_us_phone() RETURNS TEXT AS $$
DECLARE
    area_codes TEXT[] := ARRAY['202','212','213','214','215','216','224','225','240','248','251','252','253','254','256','301','302','303','304','305','307','310','312','313','314','315','316','317','318','319','320','321','323','404','405','407','408','410','412','413','414','415','417','469','470','478','480','501','502','503','504','505','510','512','513','515','516','517','518','520','540','561','562','571','573','574','585','602','603','605','607','608','612','614','615','616','617','619','623','626','630','631','636','650','651','661','678','702','703','704','706','707','708','713','714','715','716','717','718','719','720','727','732','734','737','757','760','763','770','772','773','774','775','781','801','802','803','804','805','806','813','814','815','816','817','818','828','830','832','843','845','847','850','856','857','858','860','863','864','865','901','903','904','907','908','909','910','912','913','914','915','916','917','918','919','920','925','928','931','936','937','940','941','949','951','952','954','970','971','972','973','978','979','980','984','985'];
    area_code TEXT;
    exchange TEXT;
    number TEXT;
BEGIN
    area_code := area_codes[floor(random() * array_length(area_codes, 1)) + 1];
    exchange := lpad((floor(random() * 800) + 200)::TEXT, 3, '0');
    number := lpad((floor(random() * 10000))::TEXT, 4, '0');
    RETURN area_code || exchange || number;
END;
$$ LANGUAGE plpgsql;

-- Generate realistic US healthcare emails with unique suffix
CREATE OR REPLACE FUNCTION generate_healthcare_email(unique_id INTEGER DEFAULT NULL) RETURNS TEXT AS $$
DECLARE
    first_names TEXT[] := ARRAY['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','William','Elizabeth','David','Barbara','Richard','Susan','Joseph','Jessica','Thomas','Sarah','Christopher','Karen','Charles','Nancy','Daniel','Lisa','Matthew','Betty','Anthony','Dorothy','Mark','Sandra','Donald','Donna','Steven','Carol','Paul','Ruth','Andrew','Kenneth','Kimberly','Laura','Emily','Amy','Deborah','Angela','Brenda','Emma','Olivia','Cynthia'];
    last_names TEXT[] := ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson','White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson','Walker','Young','Allen','King','Wright','Scott','Torres','Nguyen','Hill','Flores','Green','Adams','Nelson','Baker','Hall','Rivera','Campbell','Mitchell','Carter','Roberts'];
    domains TEXT[] := ARRAY['gmail.com','yahoo.com','hotmail.com','outlook.com','aol.com','icloud.com','protonmail.com','healthmail.com','medconnect.org','carepoint.net'];
    first_name TEXT;
    last_name TEXT;
    domain TEXT;
    suffix TEXT;
BEGIN
    first_name := lower(first_names[floor(random() * array_length(first_names, 1)) + 1]);
    last_name := lower(last_names[floor(random() * array_length(last_names, 1)) + 1]);
    domain := domains[floor(random() * array_length(domains, 1)) + 1];
    
    -- Always add a unique suffix to ensure no duplicates
    IF unique_id IS NOT NULL THEN
        suffix := unique_id::TEXT;
    ELSE
        suffix := extract(epoch from now())::BIGINT::TEXT || floor(random() * 1000)::TEXT;
    END IF;
    
    -- Simple format: first.last.uniqueID@domain
    RETURN first_name || '.' || last_name || '.' || suffix || '@' || domain;
END;
$$ LANGUAGE plpgsql;

-- Generate realistic device IDs
CREATE OR REPLACE FUNCTION generate_device_id() RETURNS TEXT AS $$
BEGIN
    RETURN upper(
        substr(md5(random()::text), 1, 8) || '-' ||
        substr(md5(random()::text), 1, 4) || '-' ||
        substr(md5(random()::text), 1, 4) || '-' ||
        substr(md5(random()::text), 1, 4) || '-' ||
        substr(md5(random()::text), 1, 12)
    );
END;
$$ LANGUAGE plpgsql;

-- Generate realistic session IDs
CREATE OR REPLACE FUNCTION generate_session_id() RETURNS TEXT AS $$
BEGIN
    RETURN 'SES_' || upper(substr(md5(random()::text), 1, 32));
END;
$$ LANGUAGE plpgsql;

-- Generate US IP addresses
CREATE OR REPLACE FUNCTION generate_us_ip() RETURNS TEXT AS $$
DECLARE
    us_ip_ranges TEXT[] := ARRAY[
        '173.252.', '69.171.', '31.13.', '157.240.', '185.60.', '129.134.',
        '192.168.', '10.0.', '172.16.', '204.15.', '208.80.', '198.35.',
        '23.', '104.', '151.', '199.', '185.', '192.30.', '140.82.'
    ];
    range_prefix TEXT;
    third_octet INTEGER;
    fourth_octet INTEGER;
BEGIN
    range_prefix := us_ip_ranges[floor(random() * array_length(us_ip_ranges, 1)) + 1];
    third_octet := floor(random() * 255);
    fourth_octet := floor(random() * 255) + 1;
    RETURN range_prefix || third_octet || '.' || fourth_octet;
END;
$$ LANGUAGE plpgsql;

-- Generate realistic device info
CREATE OR REPLACE FUNCTION generate_device_info() RETURNS TEXT AS $$
DECLARE
    devices TEXT[] := ARRAY[
        'iPhone 15 Pro Max; iOS 17.1.1',
        'iPhone 15 Pro; iOS 17.1.2',
        'iPhone 14 Pro Max; iOS 17.0.3',
        'iPhone 14 Pro; iOS 16.7.2',
        'iPhone 13 Pro Max; iOS 16.7.1',
        'iPhone 13 Pro; iOS 17.1',
        'iPhone 12 Pro Max; iOS 16.7',
        'Samsung Galaxy S24 Ultra; Android 14',
        'Samsung Galaxy S23 Ultra; Android 14',
        'Samsung Galaxy S22 Ultra; Android 13',
        'Google Pixel 8 Pro; Android 14',
        'Google Pixel 7 Pro; Android 14',
        'OnePlus 12; Android 14',
        'Xiaomi 14 Pro; Android 14'
    ];
BEGIN
    RETURN devices[floor(random() * array_length(devices, 1)) + 1];
END;
$$ LANGUAGE plpgsql;

-- Generate realistic US addresses for identity verification
CREATE OR REPLACE FUNCTION generate_us_address() RETURNS TABLE(
    street_address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT
) AS $$
DECLARE
    street_numbers INTEGER[] := ARRAY[100,200,300,400,500,600,700,800,900,1000,1100,1200,1300,1400,1500,1600,1700,1800,1900,2000,2100,2200,2300,2400,2500,2600,2700,2800,2900,3000,3100,3200,3300,3400,3500,3600,3700,3800,3900,4000,4100,4200,4300,4400,4500,4600,4700,4800,4900,5000];
    street_names TEXT[] := ARRAY[
        'Main St', 'Oak Ave', 'Park Dr', 'Elm St', 'Maple Ave', 'Cedar St', 'Pine St', 'Washington Ave',
        'Jefferson Blvd', 'Madison St', 'Franklin Ave', 'Lincoln Dr', 'Adams St', 'Jackson Ave',
        'Broadway', 'First St', 'Second Ave', 'Third St', 'Fourth Ave', 'Fifth St',
        'Spring St', 'Church St', 'School St', 'Mill St', 'River Rd', 'Hill St', 'Lake Dr',
        'Sunset Blvd', 'Sunrise Ave', 'Valley Rd', 'Mountain View Dr', 'Forest Ave'
    ];
    us_cities TEXT[] := ARRAY[
        'New York:NY:10001', 'Los Angeles:CA:90210', 'Chicago:IL:60601', 'Houston:TX:77001',
        'Phoenix:AZ:85001', 'Philadelphia:PA:19101', 'San Antonio:TX:78201', 'San Diego:CA:92101',
        'Dallas:TX:75201', 'San Jose:CA:95101', 'Austin:TX:78701', 'Jacksonville:FL:32099',
        'Fort Worth:TX:76101', 'Columbus:OH:43085', 'Charlotte:NC:28201', 'San Francisco:CA:94101',
        'Indianapolis:IN:46201', 'Seattle:WA:98101', 'Denver:CO:80201', 'Washington:DC:20001',
        'Boston:MA:02101', 'El Paso:TX:79901', 'Nashville:TN:37201', 'Detroit:MI:48201',
        'Oklahoma City:OK:73101', 'Portland:OR:97201', 'Las Vegas:NV:89101', 'Memphis:TN:38101',
        'Louisville:KY:40201', 'Baltimore:MD:21201', 'Milwaukee:WI:53201', 'Albuquerque:NM:87101',
        'Tucson:AZ:85701', 'Fresno:CA:93701', 'Sacramento:CA:95814', 'Mesa:AZ:85201',
        'Kansas City:MO:64101', 'Atlanta:GA:30301', 'Long Beach:CA:90801', 'Omaha:NE:68101',
        'Raleigh:NC:27601', 'Colorado Springs:CO:80901', 'Miami:FL:33101', 'Virginia Beach:VA:23451'
    ];
    
    street_num INTEGER;
    street_name TEXT;
    city_info TEXT[];
    selected_city TEXT;
BEGIN
    street_num := street_numbers[floor(random() * array_length(street_numbers, 1)) + 1];
    street_name := street_names[floor(random() * array_length(street_names, 1)) + 1];
    selected_city := us_cities[floor(random() * array_length(us_cities, 1)) + 1];
    city_info := string_to_array(selected_city, ':');
    
    street_address := street_num || ' ' || street_name;
    city := city_info[1];
    state := city_info[2];
    zip_code := city_info[3];
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- STEP 1: GUEST REGISTRATION ATTEMPTS (APP DOWNLOADS) - ENHANCED FOR 95%+ CONVERSION
-- =====================================================================================

-- Generate 3500 unique device downloads with OPTIMIZED SUCCESS RATES
INSERT INTO guest.registration_attempt (
    session_id, client_id, user_email, device_id, device_info, ip_address, 
    country_code, user_phone, registration_type, verification_document_type, 
    registration_started_on, registration_completed_on, status, platform, reference_id
)
SELECT 
    generate_session_id(),
    100 AS client_id,
    generate_healthcare_email(i),
    generate_device_id(),
    generate_device_info(),
    generate_us_ip(),
    'US',
    generate_us_phone(),
    5 AS registration_type,  -- ALL start as Guest registrations first
    1 AS verification_document_type, -- Driving license for future full registration
    
    -- Registration started times spread over last 3 months (recent users)
    NOW() - INTERVAL '1 day' * (random() * 90)::INTEGER - INTERVAL '1 hour' * (random() * 24)::INTEGER AS registration_started_on,
    
    -- ENHANCED: Guest registration completed times (99.8% complete guest registration)
    CASE 
        WHEN random() < 0.998 THEN  -- 99.8% complete guest registration successfully
            NOW() - INTERVAL '1 day' * (random() * 90)::INTEGER - INTERVAL '1 hour' * (random() * 24)::INTEGER + 
            INTERVAL '1 second' * (10 + random() * 50)::INTEGER  -- 10-60 seconds for guest registration
        ELSE NULL  -- 0.2% don't complete guest registration
    END AS registration_completed_on,
    
    -- ENHANCED: Guest registration status distribution for ultra-high conversion
    CASE 
        WHEN random() < 0.998 THEN 2  -- 99.8% Completed guest registration
        WHEN random() < 0.999 THEN 1  -- 0.1% In Progress
        WHEN random() < 0.9995 THEN 3 -- 0.05% Abandoned
        ELSE 5                        -- 0.05% Failed
    END AS status,
    
    CASE 
        WHEN random() < 0.65 THEN 'iOS'
        ELSE 'Android'
    END AS platform,
    
    floor(random() * 1000000)::BIGINT AS reference_id

FROM generate_series(1, 3500) AS i;

-- =====================================================================================
-- STEP 2: ENHANCED GUEST VERIFICATION ATTEMPTS (Phone SMS/Voice + Email)
-- =====================================================================================

-- Create phone and email verification attempts with VOICE CALLBACKS for guest registration
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, captcha_token, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT 
    ra.id AS registration_attempt_id,
    100 AS client_id,
    vt.verification_type,
    CASE 
        WHEN vt.verification_type IN (1, 2) THEN ra.user_phone  -- SMS and Voice
        WHEN vt.verification_type = 3 THEN ra.user_email  -- Email
    END AS entity_id,
    CASE 
        WHEN vt.verification_type IN (1, 2) THEN '+1'
        WHEN vt.verification_type = 3 THEN NULL
    END AS entity_prefix,
    vt.attempt_num,
    ra.registration_started_on + INTERVAL '1 second' * (vt.step_order * 10)::INTEGER AS started_at,
    
    -- OPTIMIZED: Completed time for guest verification (99% success rate)
    CASE 
        WHEN random() < 0.99 THEN  -- 99% success for SMS/Voice/Email in guest registration
            ra.registration_started_on + INTERVAL '1 second' * (vt.step_order * 10 + 5 + random() * 25)::INTEGER
        ELSE NULL
    END AS completed_at,
    
    -- Generate 6-digit OTP codes for SMS/Voice and Email
    lpad(floor(random() * 1000000)::TEXT, 6, '0') AS otp_code,
    
    -- Captcha tokens for some attempts (5% for guest registration)
    CASE 
        WHEN random() < 0.05 THEN 'captcha_' || substr(md5(random()::text), 1, 20)
        ELSE NULL
    END AS captcha_token,
    
    -- OPTIMIZED: Status based on completion (99% success for guest verification)
    CASE 
        WHEN random() < 0.99 THEN 2  -- Success
        WHEN random() < 0.5 THEN 1   -- In Progress
        ELSE 5  -- Failed
    END AS status,
    
    -- Captcha triggered (5% for guest registration)
    random() < 0.05 AS captcha_triggered,
    
    -- Rate limit triggered (2% for guest registration)
    random() < 0.02 AS rate_limit_triggered,
    
    -- Bypass code applied (1% for guest registration)
    random() < 0.01 AS bypass_code_applied

FROM guest.registration_attempt ra
CROSS JOIN (
    -- Step 1: SMS Verification (required for guest registration)
    SELECT 1 as verification_type, 1 as attempt_num, 1 as step_order  
    UNION ALL
    -- Step 1a: Voice Callback Verification (fallback for SMS failures)
    SELECT 2 as verification_type, 1 as attempt_num, 1 as step_order WHERE random() < 0.15  -- 15% get voice callbacks
    UNION ALL
    -- Step 2: Email Verification (required for guest registration)  
    SELECT 3 as verification_type, 1 as attempt_num, 2 as step_order
    
    -- Add retry attempts for failed verifications with voice callbacks
    UNION ALL
    SELECT 1 as verification_type, 2 as attempt_num, 1 as step_order WHERE random() < 0.05  -- 5% SMS retries
    UNION ALL
    SELECT 2 as verification_type, 2 as attempt_num, 1 as step_order WHERE random() < 0.08  -- 8% Voice callback retries
    UNION ALL
    SELECT 3 as verification_type, 2 as attempt_num, 2 as step_order WHERE random() < 0.03  -- 3% Email retries
    UNION ALL
    SELECT 2 as verification_type, 3 as attempt_num, 1 as step_order WHERE random() < 0.05  -- 5% additional voice retries
) vt
WHERE ra.client_id = 100 AND ra.registration_type = 5;  -- Only for guest registrations

-- =====================================================================================
-- STEP 3: FULL REGISTRATION ATTEMPTS - ENHANCED TIMING AND CONVERSION
-- =====================================================================================

-- Create a temporary table to store guest completion times for proper sequencing
CREATE TEMP TABLE guest_completion_times AS
SELECT 
    id,
    user_email,
    device_id,
    device_info,
    ip_address,
    country_code,
    user_phone,
    platform,
    registration_completed_on,
    -- Generate random delay between guest completion and full registration start (1 hour to 7 days)
    registration_completed_on + INTERVAL '1 hour' + INTERVAL '1 hour' * (random() * 167)::INTEGER as full_start_time
FROM guest.registration_attempt ra_guest
WHERE ra_guest.client_id = 100 
AND ra_guest.registration_type = 5  -- Guest registrations
AND ra_guest.status = 2  -- Only completed guest registrations
AND ra_guest.registration_completed_on IS NOT NULL
AND EXISTS (
    -- Only if both phone/voice and email verification were successful
    SELECT 1 FROM guest.verification_attempt va1
    WHERE va1.registration_attempt_id = ra_guest.id 
    AND va1.verification_type IN (1, 2) AND va1.status = 2
) AND EXISTS (
    SELECT 1 FROM guest.verification_attempt va2
    WHERE va2.registration_attempt_id = ra_guest.id 
    AND va2.verification_type = 3 AND va2.status = 2
)
AND random() < 0.96;  -- 96% of completed guest users proceed to full registration

-- Create full registration attempts AFTER guest registration completion with proper timing
INSERT INTO guest.registration_attempt (
    session_id, client_id, user_email, device_id, device_info, ip_address, 
    country_code, user_phone, registration_type, verification_document_type, 
    registration_started_on, registration_completed_on, status, platform, reference_id
)
SELECT 
    generate_session_id(),
    100 AS client_id,
    gct.user_email,
    gct.device_id,
    gct.device_info,
    gct.ip_address,
    gct.country_code,
    gct.user_phone,
    4 AS registration_type,  -- Full registration
    1 AS verification_document_type, -- Driving license
    
    -- Full registration starts AFTER guest registration completion with realistic delays
    gct.full_start_time AS registration_started_on,
    
    -- ENHANCED: Full registration completion (99.5% success rate, 30-90 seconds average)
    CASE 
        WHEN random() < 0.995 THEN  -- 99.5% complete full registration
            gct.full_start_time + INTERVAL '1 second' * (30 + random() * 60)::INTEGER  -- 30-90 seconds for full registration
        ELSE NULL  -- 0.5% don't complete full registration
    END AS registration_completed_on,
    
    -- ENHANCED: Full registration status distribution for ultra-high conversion
    CASE 
        WHEN random() < 0.995 THEN 2  -- 99.5% Completed
        WHEN random() < 0.997 THEN 1  -- 0.2% In Progress
        WHEN random() < 0.999 THEN 3  -- 0.2% Abandoned
        ELSE 5                        -- 0.1% Failed
    END AS status,
    
    gct.platform,
    floor(random() * 1000000)::BIGINT AS reference_id

FROM guest_completion_times gct;

-- ===================================================================================== 
-- STEP 4: ENHANCED FULL REGISTRATION VERIFICATION ATTEMPTS WITH ADDITIONAL DOCUMENTS
-- =====================================================================================

-- Create verification attempts for full registration with ALL document types and retries
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, captcha_token, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT 
    ra.id AS registration_attempt_id,
    100 AS client_id,
    vt.verification_type,
    'DOC_' || ra.id || '_' || vt.verification_type AS entity_id,
    'VER' AS entity_prefix,
    vt.attempt_num,
    ra.registration_started_on + INTERVAL '1 second' * (vt.step_order * 15)::INTEGER AS started_at,
    
    -- OPTIMIZED: Completion time for full registration verification steps
    CASE 
        WHEN random() < CASE 
            WHEN vt.verification_type = 4 THEN 0.98   -- 98% success for demographic
            WHEN vt.verification_type = 7 THEN 0.99   -- 99% success for license front (highest)
            WHEN vt.verification_type = 8 THEN 0.96   -- 96% success for license back
            WHEN vt.verification_type = 9 THEN 0.94   -- 94% success for SSN card
            WHEN vt.verification_type = 10 THEN 0.92  -- 92% success for insurance card
            WHEN vt.verification_type = 5 THEN 0.97   -- 97% success for selfie match
            ELSE 0.90
        END THEN
            ra.registration_started_on + INTERVAL '1 second' * (vt.step_order * 15 + 10 + random() * 30)::INTEGER
        ELSE NULL
    END AS completed_at,
    
    NULL AS otp_code,  -- No OTP for document verification
    
    -- Captcha tokens for document verification (15% trigger rate)
    CASE 
        WHEN random() < 0.15 THEN 'captcha_doc_' || substr(md5(random()::text), 1, 20)
        ELSE NULL
    END AS captcha_token,
    
    -- OPTIMIZED: Status based on verification type
    CASE 
        WHEN random() < CASE 
            WHEN vt.verification_type = 4 THEN 0.98   -- Demographic
            WHEN vt.verification_type = 7 THEN 0.99   -- License front (highest)
            WHEN vt.verification_type = 8 THEN 0.96   -- License back
            WHEN vt.verification_type = 9 THEN 0.94   -- SSN card
            WHEN vt.verification_type = 10 THEN 0.92  -- Insurance card
            WHEN vt.verification_type = 5 THEN 0.97   -- Selfie match
            ELSE 0.90
        END THEN 2  -- Success
        WHEN random() < 0.5 THEN 1  -- In Progress
        ELSE 5  -- Failed
    END AS status,
    
    -- Captcha triggered (15% for document verification)
    random() < 0.15 AS captcha_triggered,
    
    -- Rate limit triggered (5% for document verification)
    random() < 0.05 AS rate_limit_triggered,
    
    -- Bypass code applied (2% for document verification)
    random() < 0.02 AS bypass_code_applied

FROM guest.registration_attempt ra
CROSS JOIN (
    -- Step 1: Demographic Verification (required for full registration)
    SELECT 4 as verification_type, 1 as attempt_num, 1 as step_order
    UNION ALL
    -- Step 2: License Front (required for full registration)
    SELECT 7 as verification_type, 1 as attempt_num, 2 as step_order
    UNION ALL
    -- Step 3: License Back (required for full registration)  
    SELECT 8 as verification_type, 1 as attempt_num, 3 as step_order
    UNION ALL
    -- Step 4: SSN Card (required for 85% of full registrations)
    SELECT 9 as verification_type, 1 as attempt_num, 4 as step_order WHERE random() < 0.85
    UNION ALL
    -- Step 4a: Insurance Card (alternative to SSN for 25% of users, reduced from 1880)
    SELECT 10 as verification_type, 1 as attempt_num, 4 as step_order WHERE random() < 0.25
    UNION ALL
    -- Step 5: Selfie Match (final verification step)
    SELECT 5 as verification_type, 1 as attempt_num, 5 as step_order
    
    -- ENHANCED: Add multiple retry attempts for failed document verifications
    UNION ALL
    SELECT 4 as verification_type, 2 as attempt_num, 1 as step_order WHERE random() < 0.08   -- 8% demographic retries
    UNION ALL
    SELECT 7 as verification_type, 2 as attempt_num, 2 as step_order WHERE random() < 0.12   -- 12% license front retries
    UNION ALL
    SELECT 8 as verification_type, 2 as attempt_num, 3 as step_order WHERE random() < 0.12   -- 12% license back retries
    UNION ALL
    SELECT 9 as verification_type, 2 as attempt_num, 4 as step_order WHERE random() < 0.15   -- 15% SSN card retries
    UNION ALL
    SELECT 10 as verification_type, 2 as attempt_num, 4 as step_order WHERE random() < 0.10  -- 10% insurance card retries
    UNION ALL
    SELECT 5 as verification_type, 2 as attempt_num, 5 as step_order WHERE random() < 0.06   -- 6% selfie retries
    
    -- Additional third attempts for persistent failures
    UNION ALL
    SELECT 7 as verification_type, 3 as attempt_num, 2 as step_order WHERE random() < 0.05   -- 5% license front 3rd attempts
    UNION ALL
    SELECT 8 as verification_type, 3 as attempt_num, 3 as step_order WHERE random() < 0.05   -- 5% license back 3rd attempts
    UNION ALL
    SELECT 9 as verification_type, 3 as attempt_num, 4 as step_order WHERE random() < 0.08   -- 8% SSN card 3rd attempts
    UNION ALL
    SELECT 10 as verification_type, 3 as attempt_num, 4 as step_order WHERE random() < 0.04  -- 4% insurance card 3rd attempts
) vt
WHERE ra.client_id = 100 AND ra.registration_type = 4;  -- Only for full registrations

-- =====================================================================================
-- STEP 4a: ADD EMAIL VERIFICATION FOR FULL REGISTRATION USERS TO ENSURE CONSISTENCY
-- =====================================================================================

-- Add email verification attempts for full registration users to match guest registration
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, captcha_token, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT 
    ra.id AS registration_attempt_id,
    100 AS client_id,
    3 AS verification_type, -- Email verification
    ra.user_email AS entity_id,
    NULL AS entity_prefix,
    1 AS attempt_num,
    ra.registration_started_on + INTERVAL '5 seconds' AS started_at,
    ra.registration_started_on + INTERVAL '30 seconds' AS completed_at,
    lpad(floor(random() * 1000000)::TEXT, 6, '0') AS otp_code,
    NULL AS captcha_token,
    2 AS status, -- Success
    false AS captcha_triggered,
    false AS rate_limit_triggered,
    false AS bypass_code_applied
FROM guest.registration_attempt ra
WHERE ra.client_id = 100 AND ra.registration_type = 4 AND ra.status = 2;

-- =====================================================================================
-- ENHANCED IDENTITY VERIFICATION DATA WITH ALL MATCH TYPES
-- =====================================================================================

-- Generate comprehensive identity verification data with all verification types
INSERT INTO guest.identity_verification_data (
    identification_id, first_name, last_name, middle_name, dob, document_type,
    data_source, state, city, zip, zip_extension, address_line_1, address_line_2,
    gender, expiration_date, height, eye_color, issued_date, license_number,
    current_state, current_city, current_zip, current_zip_extension,
    current_address_line_1, current_address_line_2, details, ssn, attempt_number,
    insurance_card_id
)
SELECT
    ra.session_id,
    (SELECT first_name FROM (VALUES
        ('Alexander'), ('Sophia'), ('Benjamin'), ('Isabella'), ('Christopher'), ('Emma'), ('Daniel'), ('Olivia'),
        ('Ethan'), ('Ava'), ('Gabriel'), ('Mia'), ('Isaac'), ('Charlotte'), ('Jacob'), ('Abigail'),
        ('Liam'), ('Harper'), ('Lucas'), ('Evelyn'), ('Mason'), ('Ella'), ('Noah'), ('Scarlett'),
        ('Oliver'), ('Grace'), ('Sebastian'), ('Chloe'), ('William'), ('Victoria'), ('James'), ('Riley'),
        ('Jackson'), ('Aria'), ('Aiden'), ('Lily'), ('Carter'), ('Zoe'), ('Owen'), ('Penelope'),
        ('Samuel'), ('Layla'), ('Henry'), ('Nora'), ('Wyatt'), ('Hannah'), ('Caleb'), ('Addison'),
        ('Ryan'), ('Aubrey'), ('Nathan'), ('Ellie'), ('Jack'), ('Stella'), ('Leo'), ('Natalie'),
        ('David'), ('Zara'), ('Andrew'), ('Leah'), ('Michael'), ('Hazel'), ('Adam'), ('Violet'),
        ('Joshua'), ('Aurora'), ('Christopher'), ('Savannah'), ('Matthew'), ('Audrey'), ('Anthony'), ('Brooklyn'),
        ('Mark'), ('Bella'), ('Luke'), ('Claire'), ('Gabriel'), ('Skylar'), ('Isaac'), ('Lucy')
    ) AS names(first_name) ORDER BY random() LIMIT 1),

    (SELECT last_name FROM (VALUES
        ('Anderson'), ('Thomas'), ('Jackson'), ('White'), ('Harris'), ('Martin'), ('Thompson'), ('Garcia'),
        ('Martinez'), ('Robinson'), ('Clark'), ('Rodriguez'), ('Lewis'), ('Lee'), ('Walker'), ('Hall'),
        ('Allen'), ('Young'), ('Hernandez'), ('King'), ('Wright'), ('Lopez'), ('Hill'), ('Scott'),
        ('Green'), ('Adams'), ('Baker'), ('Gonzalez'), ('Nelson'), ('Carter'), ('Mitchell'), ('Perez'),
        ('Roberts'), ('Turner'), ('Phillips'), ('Campbell'), ('Parker'), ('Evans'), ('Edwards'), ('Collins'),
        ('Stewart'), ('Sanchez'), ('Morris'), ('Rogers'), ('Reed'), ('Cook'), ('Morgan'), ('Bell'),
        ('Murphy'), ('Bailey'), ('Rivera'), ('Cooper'), ('Richardson'), ('Cox'), ('Howard'), ('Ward'),
        ('Torres'), ('Peterson'), ('Gray'), ('Ramirez'), ('James'), ('Watson'), ('Brooks'), ('Kelly'),
        ('Sanders'), ('Price'), ('Bennett'), ('Wood'), ('Barnes'), ('Ross'), ('Henderson'), ('Coleman'),
        ('Jenkins'), ('Perry'), ('Powell'), ('Long'), ('Patterson'), ('Hughes'), ('Flores'), ('Washington'),
        ('Butler'), ('Simmons'), ('Foster'), ('Gonzales'), ('Bryant'), ('Alexander'), ('Russell'), ('Griffin')
    ) AS names(last_name) ORDER BY random() LIMIT 1),

    -- Middle name (60% have middle names)
    CASE WHEN random() < 0.6 THEN
        (SELECT middle_name FROM (VALUES ('A'), ('B'), ('C'), ('D'), ('E'), ('F'), ('G'), ('H'), ('J'), ('K'), ('L'), ('M'), ('N'), ('P'), ('R'), ('S'), ('T'), ('W')) AS names(middle_name) ORDER BY random() LIMIT 1)
    ELSE NULL END,

    -- Date of birth (ages 18-75)
    (CURRENT_DATE - INTERVAL '1 year' * (18 + random() * 57)::INTEGER)::DATE,
    1 AS document_type, -- Driving license
    1 AS data_source,   -- Manual entry

    -- Address data using our function
    addr.state,
    addr.city,
    addr.zip_code,
    CASE WHEN random() < 0.25 THEN lpad((floor(random() * 9999))::TEXT, 4, '0') ELSE NULL END AS zip_extension,
    addr.street_address,
    CASE WHEN random() < 0.35 THEN 'Apt ' || (floor(random() * 500) + 1)::TEXT 
         WHEN random() < 0.15 THEN 'Unit ' || (floor(random() * 100) + 1)::TEXT
         ELSE NULL END AS address_line_2,

    CASE WHEN random() < 0.52 THEN 'M' ELSE 'F' END AS gender,

    -- License expiration (1-5 years from now)
    (CURRENT_DATE + INTERVAL '1 year' * (1 + random() * 4)::INTEGER)::DATE,

    -- Height in inches (60-78 inches)
    60 + random() * 18 AS height,

    (SELECT eye_color FROM (VALUES ('BRO'), ('BLU'), ('GRN'), ('HAZ'), ('GRY'), ('AMB'), ('BLK')) AS colors(eye_color) ORDER BY random() LIMIT 1),

    -- Issued date (1-8 years ago)
    (CURRENT_DATE - INTERVAL '1 year' * (1 + random() * 7)::INTEGER)::DATE,

    -- Enhanced license number format: A123-456-78-901-0
    upper(chr(65 + floor(random() * 26)::INTEGER) || lpad(floor(random() * 1000)::TEXT, 3, '0') || '-' ||
          lpad(floor(random() * 1000)::TEXT, 3, '0') || '-' ||
          lpad(floor(random() * 100)::TEXT, 2, '0') || '-' ||
          lpad(floor(random() * 1000)::TEXT, 3, '0') || '-' ||
          floor(random() * 10)::TEXT),

    -- Current address (same as license address 85% of the time for better matching)
    CASE WHEN random() < 0.85 THEN addr.state ELSE
        (SELECT state FROM generate_us_address() ORDER BY random() LIMIT 1) END,
    CASE WHEN random() < 0.85 THEN addr.city ELSE
        (SELECT city FROM generate_us_address() ORDER BY random() LIMIT 1) END,
    CASE WHEN random() < 0.85 THEN addr.zip_code ELSE
        (SELECT zip_code FROM generate_us_address() ORDER BY random() LIMIT 1) END,
    CASE WHEN random() < 0.25 THEN lpad((floor(random() * 9999))::TEXT, 4, '0') ELSE NULL END AS current_zip_extension,
    CASE WHEN random() < 0.85 THEN addr.street_address ELSE
        (SELECT street_address FROM generate_us_address() ORDER BY random() LIMIT 1) END,
    CASE WHEN random() < 0.35 THEN 'Apt ' || (floor(random() * 500) + 1)::TEXT 
         WHEN random() < 0.15 THEN 'Unit ' || (floor(random() * 100) + 1)::TEXT
         ELSE NULL END AS current_address_line_2,

    ('{"verification_score": ' || (88 + random() * 12)::INTEGER || ', "confidence": ' || (92 + random() * 8)::INTEGER || 
     ', "document_quality": "' || (SELECT quality FROM (VALUES ('excellent'), ('good'), ('fair')) AS q(quality) ORDER BY random() LIMIT 1) || 
     '", "face_match_score": ' || (85 + random() * 15)::INTEGER || '}')::json AS details,

    -- SSN (format: XXX-XX-XXXX)
    lpad((100 + floor(random() * 665))::TEXT, 3, '0') || '-' ||  -- Valid SSN area numbers
    lpad((1 + floor(random() * 99))::TEXT, 2, '0') || '-' ||     -- Valid group numbers
    lpad((1 + floor(random() * 9999))::TEXT, 4, '0'),           -- Valid serial numbers

    1 AS attempt_number,

    -- Insurance card ID for REDUCED percentage (25% instead of previous higher amount)
    CASE WHEN random() < 0.25 THEN 'INS_' || upper(substr(md5(random()::text), 1, 12)) ELSE NULL END

FROM guest.registration_attempt ra
CROSS JOIN generate_us_address() addr
WHERE ra.client_id = 100 AND ra.status = 2  -- Only for completed registrations
AND EXISTS (
    SELECT 1 FROM guest.verification_attempt va
    WHERE va.registration_attempt_id = ra.id
    AND va.verification_type IN (7, 8, 9, 10)  -- Document verification (license, SSN, insurance)
    AND va.status = 2  -- Successful
)
ORDER BY random()
LIMIT 2800;  -- About 85% of successful registrations have identity data

-- =====================================================================================
-- ENHANCED GUEST USERS DATA
-- =====================================================================================

-- Create guest user accounts with enhanced data
INSERT INTO guest.guest_users (
    client_id, email, country_code, phone_number, password, created_on, updated_on,
    promoted_to_member, reference_member_id, language_preference, is_active
)
SELECT 
    100,
    ra.user_email,
    'US',
    ra.user_phone,
    '$2a$10$' || substr(md5(random()::text), 1, 53),  -- Encrypted password hash
    ra.registration_started_on,
    CASE 
        WHEN ra.registration_completed_on IS NOT NULL THEN ra.registration_completed_on
        ELSE ra.registration_started_on + INTERVAL '1 hour' * random()
    END,
    
    -- 35% of guest users get promoted to full members (increased)
    random() < 0.35,
    
    -- Reference member ID for promoted users
    CASE WHEN random() < 0.35 THEN floor(random() * 100000 + 10000)::BIGINT ELSE NULL END,
    
    CASE WHEN random() < 0.92 THEN 'en' ELSE 'es' END,  -- 92% English, 8% Spanish
    
    ra.status = 2  -- Active if registration completed

FROM guest.registration_attempt ra
WHERE ra.client_id = 100 
AND ra.registration_type = 5  -- Guest registrations only
AND ra.user_email IS NOT NULL;

-- =====================================================================================
-- ENHANCED GUEST REGISTRATION LOG WITH ALL MATCH TYPES AND VERIFICATION STATUSES
-- =====================================================================================

-- Create comprehensive registration logs with PROPER DISTRIBUTION for demographic metrics
INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    matched_members_details, ssn, matched_member_id
)
SELECT 
    ivd.identification_id,
    100,
    ivd.first_name,
    ivd.last_name,
    ivd.dob,
    ivd.gender,
    
    -- Weighted distribution for demographic verification metrics
    CASE 
        WHEN row_number() OVER (ORDER BY random()) <= 800 THEN 'UNIQUE_MATCH'                        -- Direct Match
        WHEN row_number() OVER (ORDER BY random()) <= 1000 THEN 'EXACT_NAME_DOB_GENDER_AND_ZIP_MATCH' -- Direct Match
        WHEN row_number() OVER (ORDER BY random()) <= 1200 THEN 'AUTO_PROMOTED'                      -- Automatic approval
        WHEN row_number() OVER (ORDER BY random()) <= 1350 THEN 'EXACT_NAME_AND_SSN_MATCH'           -- SSN Fallback
        WHEN row_number() OVER (ORDER BY random()) <= 1450 THEN 'SOFT_MATCH'                         -- Partial Match
        WHEN row_number() OVER (ORDER BY random()) <= 1500 THEN 'SENT_TO_CUSTOMER_SUPPORT'           -- Manual review
        WHEN row_number() OVER (ORDER BY random()) <= 1600 THEN 'MULTIPLE_MATCH'                     -- Multiple matches
        WHEN row_number() OVER (ORDER BY random()) <= 1650 THEN 'EXACT_NAME_AND_DOB_MATCH_WITH_ADDRESS_MISMATCH' -- Alternative verification
        ELSE 'NO_MATCH'                                                                               -- No Match (Holding)
    END,
    
    -- Actions matching the match types for proper metrics
    CASE 
        WHEN row_number() OVER (ORDER BY random()) <= 1000 THEN 'UNIQUE_MATCH'             -- For direct matches
        WHEN row_number() OVER (ORDER BY random()) <= 1200 THEN 'AUTO_PROMOTED'         -- For automatic approval
        WHEN row_number() OVER (ORDER BY random()) <= 1350 THEN 'EXACT_NAME_AND_SSN_MATCH'         -- For SSN fallback
        WHEN row_number() OVER (ORDER BY random()) <= 1450 THEN 'SOFT_MATCH'                -- For partial match
        WHEN row_number() OVER (ORDER BY random()) <= 1500 THEN 'SENT_TO_CUSTOMER_SUPPORT'           -- For manual review
        WHEN row_number() OVER (ORDER BY random()) <= 1600 THEN 'MULTIPLE_MATCH'            -- For multiple matches
        WHEN row_number() OVER (ORDER BY random()) <= 1650 THEN 'EXACT_NAME_AND_DOB_MATCH_WITH_ADDRESS_MISMATCH'     -- For alternative verification
        ELSE 'NO_MATCH'                                                                    -- For no match
    END,
    
    ('{"ip_address": "' || generate_us_ip() || '", "user_agent": "HealthApp/2.2.1", "verification_score": ' || 
    (88 + random() * 12)::INTEGER || ', "timestamp": "' || NOW()::TEXT || 
    '", "device_fingerprint": "' || substr(md5(random()::text), 1, 16) || 
    '", "geolocation": {"lat": ' || (25.0 + random() * 25.0) || ', "lng": ' || (-125.0 + random() * 58.0) || '}}')::json,
    
    gu.id,  -- Guest user reference
    
    -- Enhanced matched member details for various match scenarios
    CASE 
        WHEN random() < 0.15 THEN  -- 15% Direct matches
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (95 + random() * 5)::INTEGER || ', "match_fields": ["name", "dob", "ssn", "address"], "match_type": "direct"}]')::json
        WHEN random() < 0.25 THEN  -- 10% SSN fallback matches
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (88 + random() * 7)::INTEGER || ', "match_fields": ["ssn", "name"], "match_type": "ssn_fallback"}]')::json
        WHEN random() < 0.35 THEN  -- 10% Partial matches
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (75 + random() * 10)::INTEGER || ', "match_fields": ["name", "dob"], "match_type": "partial"}]')::json
        WHEN random() < 0.45 THEN  -- 10% Multiple matches
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (70 + random() * 15)::INTEGER || ', "match_fields": ["name"], "match_type": "multiple"}, ' ||
            '{"member_id": ' || (floor(random() * 100000) + 20000)::INTEGER || ', "confidence": ' || 
            (65 + random() * 20)::INTEGER || ', "match_fields": ["dob"], "match_type": "multiple"}]')::json
        WHEN random() < 0.65 THEN  -- 20% Automatic approval via license
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (90 + random() * 10)::INTEGER || ', "match_fields": ["license", "name", "dob"], "match_type": "license_approval"}]')::json
        ELSE NULL  -- 35% No matches (including no match holding, awaiting member report, etc.)
    END,
    
    ivd.ssn,
    
    -- Enhanced matched member ID distribution
    CASE 
        WHEN random() < 0.65 THEN floor(random() * 100000 + 10000)::BIGINT 
        ELSE NULL 
    END

FROM guest.identity_verification_data ivd
LEFT JOIN guest.guest_users gu ON ivd.identification_id LIKE 'ID_%'
WHERE random() < 0.95  -- 95% of identity verifications generate logs
ORDER BY random()
LIMIT 3500;

-- Add specific logs for Additional Verification Requests (ZIP and Address)
INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    matched_members_details, ssn, matched_member_id
)
SELECT 
    'ZIP_REQ_' || generate_series || '_' || floor(random() * 1000),
    100,
    (SELECT first_name FROM (VALUES ('John'), ('Jane'), ('Michael'), ('Sarah'), ('David'), ('Emma'), ('Chris'), ('Lisa')) AS names(first_name) ORDER BY random() LIMIT 1),
    (SELECT last_name FROM (VALUES ('Smith'), ('Johnson'), ('Brown'), ('Davis'), ('Wilson'), ('Taylor'), ('Anderson'), ('Thomas')) AS names(last_name) ORDER BY random() LIMIT 1),
    (CURRENT_DATE - INTERVAL '1 year' * (20 + random() * 50)::INTEGER)::DATE,
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    'MULTIPLE_MATCH',
    'Asked Current Zip',  -- This matches GuestToFullMatchActionType.CURRENT_ZIP_REQUIRED
    ('{"verification_type": "zip_request", "processing_time": ' || (45 + random() * 120)::INTEGER || 
    ', "ip_address": "' || generate_us_ip() || '"}')::json,
    NULL,
    NULL,
    lpad((100 + floor(random() * 665))::TEXT, 3, '0') || '-' ||
    lpad((1 + floor(random() * 99))::TEXT, 2, '0') || '-' ||
    lpad((1 + floor(random() * 9999))::TEXT, 4, '0'),
    floor(random() * 100000 + 10000)::BIGINT
FROM generate_series(1, 150);  -- 150 zip code requests

INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    matched_members_details, ssn, matched_member_id
)
SELECT 
    'ADDR_REQ_' || generate_series || '_' || floor(random() * 1000),
    100,
    (SELECT first_name FROM (VALUES ('Alex'), ('Maria'), ('James'), ('Anna'), ('Robert'), ('Linda'), ('Kevin'), ('Susan')) AS names(first_name) ORDER BY random() LIMIT 1),
    (SELECT last_name FROM (VALUES ('Garcia'), ('Miller'), ('Wilson'), ('Moore'), ('Taylor'), ('Clark'), ('Lewis'), ('Walker')) AS names(last_name) ORDER BY random() LIMIT 1),
    (CURRENT_DATE - INTERVAL '1 year' * (20 + random() * 50)::INTEGER)::DATE,
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    'EXACT_NAME_AND_DOB_MATCH_WITH_ADDRESS_MISMATCH',
    'Asked Current Address',  -- This matches GuestToFullMatchActionType.CURRENT_ADDRESS_REQUIRED
    ('{"verification_type": "address_request", "processing_time": ' || (60 + random() * 150)::INTEGER || 
    ', "ip_address": "' || generate_us_ip() || '"}')::json,
    NULL,
    NULL,
    lpad((100 + floor(random() * 665))::TEXT, 3, '0') || '-' ||
    lpad((1 + floor(random() * 99))::TEXT, 2, '0') || '-' ||
    lpad((1 + floor(random() * 9999))::TEXT, 4, '0'),
    floor(random() * 100000 + 10000)::BIGINT
FROM generate_series(1, 75);  -- 75 address requests

-- Add additional logs for various match types and journey progress
INSERT INTO guest.guest_registration_log (
    identification_id, client_id, first_name, last_name, dob, gender,
    match_type, action, additional_details, guest_user_reference_id,
    matched_members_details, ssn, matched_member_id
)
SELECT 
    'DIVERSE_' || generate_series || '_' || floor(random() * 1000),
    100,
    (SELECT first_name FROM (VALUES 
        ('Alexander'), ('Sophia'), ('Benjamin'), ('Isabella'), ('Christopher'), ('Emma'), ('Daniel'), ('Olivia'),
        ('Ethan'), ('Ava'), ('Gabriel'), ('Mia'), ('Isaac'), ('Charlotte'), ('Jacob'), ('Abigail'),
        ('Liam'), ('Harper'), ('Lucas'), ('Evelyn'), ('Mason'), ('Ella'), ('Noah'), ('Scarlett'),
        ('Oliver'), ('Grace'), ('Sebastian'), ('Chloe'), ('William'), ('Victoria'), ('Ryan'), ('Zoe')
    ) AS names(first_name) ORDER BY random() LIMIT 1),
    (SELECT last_name FROM (VALUES 
        ('Anderson'), ('Thomas'), ('Jackson'), ('White'), ('Harris'), ('Martin'), ('Thompson'), ('Garcia'),
        ('Martinez'), ('Robinson'), ('Clark'), ('Rodriguez'), ('Lewis'), ('Lee'), ('Walker'), ('Hall'),
        ('Allen'), ('Young'), ('Hernandez'), ('King'), ('Wright'), ('Lopez'), ('Hill'), ('Scott'),
        ('Green'), ('Adams'), ('Baker'), ('Gonzalez'), ('Nelson'), ('Carter'), ('Mitchell'), ('Perez')
    ) AS names(last_name) ORDER BY random() LIMIT 1),
    (CURRENT_DATE - INTERVAL '1 day' * (random() * 90)::INTEGER)::DATE,  -- Recent users (last 3 months)
    CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
    
    -- All match types for comprehensive journey progress
    CASE 
        WHEN generate_series <= 80 THEN 'UNIQUE_MATCH'                                    -- Direct Match
        WHEN generate_series <= 120 THEN 'EXACT_NAME_DOB_GENDER_AND_ZIP_MATCH'           -- Direct Match  
        WHEN generate_series <= 160 THEN 'AUTO_PROMOTED'                                  -- Automatic approval via license
        WHEN generate_series <= 200 THEN 'EXACT_NAME_AND_SSN_MATCH'                      -- SSN Fallback Match
        WHEN generate_series <= 240 THEN 'EXACT_NAME_AND_DOB_MATCH_WITH_ADDRESS_MISMATCH'-- Alternative verification
        WHEN generate_series <= 280 THEN 'SOFT_MATCH'                                    -- Partial Match
        WHEN generate_series <= 320 THEN 'SENT_TO_CUSTOMER_SUPPORT'                      -- Manual review needed
        WHEN generate_series <= 360 THEN 'MULTIPLE_MATCH'                                -- Multiple matches
        WHEN generate_series <= 400 THEN 'ACCEPTED_BY_CUSTOMER_SUPPORT'                  -- Accepted by support
        WHEN generate_series <= 440 THEN 'REJECTED_BY_CUSTOMER_SUPPORT'                  -- Rejected by support
        WHEN generate_series <= 480 THEN 'MEMBER_ALREADY_REGISTERED'                     -- Already registered
        WHEN generate_series <= 520 THEN 'MATCHED_FROM_MOBILE_DISABLED_TENANT'           -- Mobile disabled tenant
        WHEN generate_series <= 560 THEN 'MATCHED_FROM_WHITELABEL_TENANT'                -- Whitelabel tenant
        WHEN generate_series <= 600 THEN 'MATCH_WITH_MINOR'                              -- Minor match
        ELSE 'NO_MATCH'                                                                   -- No Match (Holding)
    END,
    
    -- Actions matching the requirements
    CASE 
        WHEN generate_series <= 200 THEN 'REGISTRATION_COMPLETED'                        -- Successful registrations
        WHEN generate_series <= 280 THEN 'AUTOMATIC_APPROVAL_GRANTED'                    -- Automatic approvals
        WHEN generate_series <= 320 THEN 'SENT_TO_CUSTOMER_SUPPORT'                      -- Manual review
        WHEN generate_series <= 360 THEN 'MULTIPLE_MATCH_DETECTED'                       -- Multiple matches
        WHEN generate_series <= 400 THEN 'PROMOTED_TO_MEMBER'                            -- Promoted
        WHEN generate_series <= 440 THEN 'MEMBER_NOTIFIED'                               -- Member notified
        WHEN generate_series <= 480 THEN 'OVERRIDE_EXISTING_REGISTRATION'                -- Override existing
        WHEN generate_series <= 520 THEN 'AWAITING_ACTIVATION_EMAIL_CONFIRMATION'        -- Awaiting activation
        WHEN generate_series <= 560 THEN 'IN_HOLDING_TABLE'                              -- Holding table
        WHEN generate_series <= 600 THEN 'MEMBER_NOT_ENROLLED'                           -- Not enrolled
        ELSE 'HOLDING_TABLE_ENTRY'                                                       -- Default holding
    END,
    
    ('{"verification_type": "enhanced_journey", "processing_time": ' || (15 + random() * 60)::INTEGER || 
    ', "ip_address": "' || generate_us_ip() || '", "timestamp": "' || (NOW() - INTERVAL '1 day' * (random() * 90)::INTEGER)::TEXT || '"}')::json,
    
    NULL, -- guest_user_reference_id
    
    -- Enhanced matched member details with proper confidence scores
    CASE 
        WHEN generate_series <= 200 THEN  -- Direct matches with high confidence
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (95 + random() * 5)::INTEGER || ', "match_fields": ["name", "dob", "address"], "match_type": "exact"}]')::json
        WHEN generate_series <= 280 THEN  -- License-based automatic approvals
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (92 + random() * 8)::INTEGER || ', "match_fields": ["license", "name", "dob"], "match_type": "license_verification"}]')::json
        WHEN generate_series <= 320 THEN  -- SSN fallback matches
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (88 + random() * 7)::INTEGER || ', "match_fields": ["ssn", "name"], "match_type": "ssn_fallback"}]')::json
        WHEN generate_series <= 360 THEN  -- Multiple matches
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (70 + random() * 15)::INTEGER || ', "match_fields": ["name"], "match_type": "multiple"}, ' ||
            '{"member_id": ' || (floor(random() * 100000) + 20000)::INTEGER || ', "confidence": ' || 
            (65 + random() * 20)::INTEGER || ', "match_fields": ["dob"], "match_type": "multiple"}]')::json
        WHEN generate_series <= 440 THEN  -- Partial matches
            ('[{"member_id": ' || (floor(random() * 100000) + 10000)::INTEGER || ', "confidence": ' || 
            (75 + random() * 10)::INTEGER || ', "match_fields": ["name", "dob"], "match_type": "partial"}]')::json
        ELSE NULL  -- No matches
    END,
    
    -- SSN for verification
    lpad((100 + floor(random() * 665))::TEXT, 3, '0') || '-' ||
    lpad((1 + floor(random() * 99))::TEXT, 2, '0') || '-' ||
    lpad((1 + floor(random() * 9999))::TEXT, 4, '0'),
    
    CASE WHEN generate_series <= 440 THEN floor(random() * 100000 + 10000)::BIGINT ELSE NULL END

FROM generate_series(1, 800);

-- =====================================================================================
-- ADD COMPREHENSIVE EDGE CASES AND REALISTIC VARIATIONS
-- =====================================================================================

-- Add multiple verification attempts for same registration (addressing user requirement)
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, captcha_token, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT 
    ra.id,
    100,
    attempts.verification_type,
    CASE 
        WHEN attempts.verification_type IN (1, 2) THEN ra.user_phone 
        WHEN attempts.verification_type = 3 THEN ra.user_email 
        ELSE 'DOC_' || ra.id || '_' || attempts.verification_type
    END,
    CASE WHEN attempts.verification_type IN (1, 2) THEN '+1' ELSE 'VER' END,
    attempts.attempt_number,
    ra.registration_started_on + INTERVAL '1 minute' * (attempts.attempt_number * 2),
    
    -- Some attempts succeed, some fail, some are still in progress
    CASE 
        WHEN attempts.success_rate > random() THEN 
            ra.registration_started_on + INTERVAL '1 minute' * (attempts.attempt_number * 2) + INTERVAL '30 seconds'
        ELSE NULL
    END,
    
    CASE WHEN attempts.verification_type IN (1, 2, 3) THEN lpad(floor(random() * 1000000)::TEXT, 6, '0') ELSE NULL END,
    CASE WHEN random() < 0.1 THEN 'multi_attempt_' || substr(md5(random()::text), 1, 15) ELSE NULL END,
    
    CASE 
        WHEN attempts.success_rate > random() THEN 2  -- Success
        WHEN random() < 0.3 THEN 1  -- In Progress
        ELSE 5  -- Failed
    END,
    
    random() < 0.1,
    random() < 0.05,
    false

FROM guest.registration_attempt ra
CROSS JOIN (
    -- Multiple attempts for phone verification (SMS)
    SELECT 1 as verification_type, 2 as attempt_number, 0.85 as success_rate
    UNION ALL
    SELECT 1 as verification_type, 3 as attempt_number, 0.70 as success_rate
    UNION ALL
    SELECT 1 as verification_type, 4 as attempt_number, 0.60 as success_rate
    
    -- Multiple attempts for voice callbacks
    UNION ALL
    SELECT 2 as verification_type, 2 as attempt_number, 0.80 as success_rate
    UNION ALL
    SELECT 2 as verification_type, 3 as attempt_number, 0.65 as success_rate
    
    -- Multiple attempts for email verification
    UNION ALL
    SELECT 3 as verification_type, 2 as attempt_number, 0.90 as success_rate
    UNION ALL
    SELECT 3 as verification_type, 3 as attempt_number, 0.75 as success_rate
    
    -- Multiple attempts for document verification
    UNION ALL
    SELECT 4 as verification_type, 2 as attempt_number, 0.88 as success_rate  -- Demographic
    UNION ALL
    SELECT 4 as verification_type, 3 as attempt_number, 0.75 as success_rate
    UNION ALL
    SELECT 7 as verification_type, 2 as attempt_number, 0.92 as success_rate  -- License front
    UNION ALL
    SELECT 7 as verification_type, 3 as attempt_number, 0.85 as success_rate
    UNION ALL
    SELECT 8 as verification_type, 2 as attempt_number, 0.89 as success_rate  -- License back
    UNION ALL
    SELECT 8 as verification_type, 3 as attempt_number, 0.80 as success_rate
    UNION ALL
    SELECT 9 as verification_type, 2 as attempt_number, 0.86 as success_rate  -- SSN
    UNION ALL
    SELECT 9 as verification_type, 3 as attempt_number, 0.78 as success_rate
    UNION ALL
    SELECT 10 as verification_type, 2 as attempt_number, 0.84 as success_rate -- Insurance
    UNION ALL
    SELECT 10 as verification_type, 3 as attempt_number, 0.72 as success_rate
) attempts
WHERE ra.client_id = 100 
AND random() < 0.35  -- 35% of registrations have multiple attempts
LIMIT 1200;

-- Add detailed failed verification attempts with specific error patterns and voice callbacks
INSERT INTO guest.verification_attempt (
    registration_attempt_id, client_id, verification_type, entity_id, entity_prefix,
    attempt_number, started_at, completed_at, otp_code, captcha_token, status,
    captcha_triggered, rate_limit_triggered, bypass_code_applied
)
SELECT 
    ra.id,
    100,
    variations.verification_type,
    CASE 
        WHEN variations.verification_type IN (1, 2) THEN ra.user_phone 
        WHEN variations.verification_type = 3 THEN ra.user_email 
        ELSE 'DOC_' || ra.id || '_' || variations.verification_type
    END,
    CASE WHEN variations.verification_type IN (1, 2) THEN '+1' ELSE 'VER' END,
    variations.attempt_number,
    ra.registration_started_on + INTERVAL '1 minute' * (variations.verification_type * 2),
    NULL,  -- Not completed
    CASE WHEN variations.verification_type IN (1, 2, 3) THEN lpad(floor(random() * 1000000)::TEXT, 6, '0') ELSE NULL END,
    CASE WHEN variations.captcha_triggered THEN 'captcha_failed_' || substr(md5(random()::text), 1, 15) ELSE NULL END,
    5,  -- Failed status
    variations.captcha_triggered,
    variations.rate_limit_triggered,
    false

FROM guest.registration_attempt ra
CROSS JOIN (
    -- Enhanced failure scenarios with voice callbacks
    SELECT 1 as verification_type, 3 as attempt_number, true as captcha_triggered, false as rate_limit_triggered  -- SMS retry with captcha
    UNION ALL
    SELECT 2 as verification_type, 2 as attempt_number, false as captcha_triggered, false as rate_limit_triggered -- Voice callback
    UNION ALL
    SELECT 2 as verification_type, 3 as attempt_number, true as captcha_triggered, false as rate_limit_triggered  -- Voice callback retry
    UNION ALL
    SELECT 3 as verification_type, 2 as attempt_number, false as captcha_triggered, true as rate_limit_triggered  -- Email with rate limit
    UNION ALL
    SELECT 7 as verification_type, 4 as attempt_number, true as captcha_triggered, true as rate_limit_triggered   -- License front multiple retries
    UNION ALL
    SELECT 8 as verification_type, 4 as attempt_number, true as captcha_triggered, false as rate_limit_triggered -- License back multiple retries
    UNION ALL
    SELECT 9 as verification_type, 3 as attempt_number, false as captcha_triggered, true as rate_limit_triggered -- SSN retry
    UNION ALL
    SELECT 10 as verification_type, 2 as attempt_number, true as captcha_triggered, false as rate_limit_triggered -- Insurance card retry
) variations
WHERE ra.client_id = 100 AND ra.status IN (1, 3, 5)  -- In progress/Failed/Abandoned registrations
AND random() < 0.25  -- Only 25% of problematic registrations have these detailed attempts
LIMIT 400;

-- Drop temporary table
DROP TABLE IF EXISTS guest_completion_times;

-- =====================================================================================
-- CLEAN UP TEMP FUNCTIONS
-- =====================================================================================

DROP FUNCTION IF EXISTS generate_us_phone();
DROP FUNCTION IF EXISTS generate_healthcare_email();
DROP FUNCTION IF EXISTS generate_device_id();
DROP FUNCTION IF EXISTS generate_session_id();
DROP FUNCTION IF EXISTS generate_us_ip();
DROP FUNCTION IF EXISTS generate_device_info();
DROP FUNCTION IF EXISTS generate_us_address();

-- Commit the transaction
COMMIT;

-- =====================================================================================
-- ENHANCED VERIFICATION QUERIES WITH DETAILED BREAKDOWN
-- =====================================================================================

-- Show comprehensive summary statistics
SELECT 
    'Total Registration Attempts' AS metric,
    COUNT(*) AS value
FROM guest.registration_attempt 
WHERE client_id = 100

UNION ALL

SELECT 
    'Unique Device IDs' AS metric,
    COUNT(DISTINCT device_id) AS value
FROM guest.registration_attempt 
WHERE client_id = 100

UNION ALL

SELECT 
    'Guest Registration Attempts' AS metric,
    COUNT(*) AS value
FROM guest.registration_attempt 
WHERE client_id = 100 AND registration_type = 5

UNION ALL

SELECT 
    'Guest Registrations Completed' AS metric,
    COUNT(*) AS value
FROM guest.registration_attempt 
WHERE client_id = 100 AND registration_type = 5 AND status = 2

UNION ALL

SELECT 
    'Full Registration Attempts' AS metric,
    COUNT(*) AS value
FROM guest.registration_attempt 
WHERE client_id = 100 AND registration_type = 4

UNION ALL

SELECT 
    'Full Registrations Completed' AS metric,
    COUNT(*) AS value
FROM guest.registration_attempt 
WHERE client_id = 100 AND registration_type = 4 AND status = 2

UNION ALL

SELECT 
    'Overall Conversion Rate %' AS metric,
    ROUND(
        (COUNT(*) FILTER (WHERE status = 2) * 100.0 / COUNT(*)), 2
    ) AS value
FROM guest.registration_attempt 
WHERE client_id = 100

UNION ALL

SELECT 
    'Average Completion Time (minutes)' AS metric,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (registration_completed_on - registration_started_on)) / 60.0), 2
    ) AS value
FROM guest.registration_attempt 
WHERE client_id = 100 
AND registration_completed_on IS NOT NULL

UNION ALL

SELECT 
    'Guest Avg Time (minutes)' AS metric,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (registration_completed_on - registration_started_on)) / 60.0), 2
    ) AS value
FROM guest.registration_attempt 
WHERE client_id = 100 
AND registration_type = 5
AND registration_completed_on IS NOT NULL

UNION ALL

SELECT 
    'Full Avg Time (minutes)' AS metric,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (registration_completed_on - registration_started_on)) / 60.0), 2
    ) AS value
FROM guest.registration_attempt 
WHERE client_id = 100 
AND registration_type = 4
AND registration_completed_on IS NOT NULL

UNION ALL

SELECT 
    'Total Verification Attempts' AS metric,
    COUNT(*) AS value
FROM guest.verification_attempt 
WHERE client_id = 100

UNION ALL

SELECT 
    'Voice Callback Attempts' AS metric,
    COUNT(*) AS value
FROM guest.verification_attempt 
WHERE client_id = 100 AND verification_type = 2

UNION ALL

SELECT 
    'Guest Users Created' AS metric,
    COUNT(*) AS value
FROM guest.guest_users 
WHERE client_id = 100

UNION ALL

SELECT 
    'Identity Verifications' AS metric,
    COUNT(*) AS value
FROM guest.identity_verification_data

UNION ALL

SELECT 
    'Insurance Card Verifications' AS metric,
    COUNT(*) AS value
FROM guest.identity_verification_data 
WHERE insurance_card_id IS NOT NULL

UNION ALL

SELECT 
    'Registration Logs' AS metric,
    COUNT(*) AS value
FROM guest.guest_registration_log 
WHERE client_id = 100;

-- Show enhanced verification type success rates including voice callbacks
SELECT 
    CASE verification_type
        WHEN 1 THEN 'SMS'
        WHEN 2 THEN 'Voice Callback'
        WHEN 3 THEN 'Email'
        WHEN 4 THEN 'Demographic'
        WHEN 5 THEN 'Selfie Match'
        WHEN 7 THEN 'License Front'
        WHEN 8 THEN 'License Back'
        WHEN 9 THEN 'SSN Card'
        WHEN 10 THEN 'Insurance Card'
        ELSE 'Other'
    END AS verification_type,
    COUNT(*) AS total_attempts,
    COUNT(*) FILTER (WHERE status = 2) AS successful_attempts,
    ROUND(COUNT(*) FILTER (WHERE status = 2) * 100.0 / COUNT(*), 2) AS success_rate_percent
FROM guest.verification_attempt 
WHERE client_id = 100
GROUP BY verification_type
ORDER BY verification_type;

-- Show comprehensive match type distribution
SELECT 
    match_type,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM guest.guest_registration_log 
WHERE client_id = 100 
AND match_type IN (
    'DIRECT_MATCH', 'AUTOMATIC_APPROVAL_VIA_LICENSE', 'SSN_FALLBACK_MATCH', 
    'ALTERNATIVE_VERIFICATION', 'PARTIAL_MATCH', 'NO_MATCH_HOLDING',
    'AWAITING_MEMBER_REPORT', 'ZIP_CODE_REQUEST', 'MULTIPLE_MATCHES', 
    'ADDRESS_REQUEST', 'ZIP_NOT_SUFFICIENT'
)
GROUP BY match_type
ORDER BY count DESC;

-- Show registration timing validation (guest before full)
SELECT 
    'Timing Validation' AS section,
    '' AS metric,
    '' AS value
UNION ALL
SELECT 
    '',
    'Guest-to-Full Proper Sequence %' AS metric,
    ROUND(
        (COUNT(*) FILTER (
            WHERE EXISTS (
                SELECT 1 FROM guest.registration_attempt ra_guest 
                WHERE ra_guest.user_email = ra_full.user_email 
                AND ra_guest.registration_type = 5 
                AND ra_guest.status = 2
                AND ra_guest.registration_completed_on < ra_full.registration_started_on
            )
        ) * 100.0 / COUNT(*)), 2
    )::TEXT AS value
FROM guest.registration_attempt ra_full
WHERE ra_full.client_id = 100 AND ra_full.registration_type = 4;
