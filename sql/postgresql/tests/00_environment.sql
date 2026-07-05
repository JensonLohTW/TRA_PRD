-- ============================================================================
-- 台鐵職工福利平台 — PostgreSQL 環境檢查測試
-- 模組：00_environment.sql
-- 說明：驗證 PostgreSQL 版本、UTF8 編碼、特定擴展、UTC 技術時區
-- ============================================================================

SELECT 'ENV' AS module, 'PostgreSQL 版本 >= 15' AS check_item,
       CASE WHEN current_setting('server_version') LIKE '15%' OR current_setting('server_version') LIKE '16%' OR current_setting('server_version') LIKE '17%' THEN 'PASS' ELSE 'FAIL' END AS result,
       current_setting('server_version') AS actual_value;

SELECT 'ENV' AS module, 'UTF8 編碼可用' AS check_item,
       CASE WHEN current_setting('server_encoding') = 'UTF8' THEN 'PASS' ELSE 'FAIL' END AS result,
       current_setting('server_encoding') AS actual_value;

SELECT 'ENV' AS module, 'plpgsql 可用' AS check_item,
       CASE WHEN EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'plpgsql') THEN 'PASS' ELSE 'FAIL' END AS result,
       'plpgsql' AS actual_value;

SELECT 'ENV' AS module, 'UTC 技術時區' AS check_item,
       CASE WHEN current_setting('timezone') = 'UTC' THEN 'PASS' ELSE 'FAIL' END AS result,
       current_setting('timezone') AS actual_value;
