-- ============================================================================
-- 台鐵職工福利平台 — 環境檢查測試
-- 模組：00_environment.sql
-- 說明：驗證 MySQL 版本、InnoDB、utf8mb4、嚴格 SQL 模式、UTC 技術時區
-- 執行前不要求任何 DDL 存在
-- ============================================================================

SELECT 'ENV' AS module, 'MySQL 版本 >= 8.0' AS check_item,
       CASE WHEN VERSION() LIKE '8.%' THEN 'PASS' ELSE 'FAIL' END AS result,
       VERSION() AS actual_value;

SELECT 'ENV' AS module, 'InnoDB 可用' AS check_item,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.ENGINES WHERE ENGINE = 'InnoDB' AND SUPPORT = 'YES' OR SUPPORT = 'DEFAULT')
            THEN 'PASS' ELSE 'FAIL' END AS result,
       (SELECT SUPPORT FROM information_schema.ENGINES WHERE ENGINE = 'InnoDB') AS actual_value;

SELECT 'ENV' AS module, 'utf8mb4 可用' AS check_item,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.CHARACTER_SETS WHERE CHARACTER_SET_NAME = 'utf8mb4')
            THEN 'PASS' ELSE 'FAIL' END AS result,
       'utf8mb4' AS actual_value;

SELECT 'ENV' AS module, '嚴格 SQL 模式' AS check_item,
       CASE WHEN @@SQL_MODE LIKE '%STRICT_TRANS_TABLES%' THEN 'PASS' ELSE 'FAIL' END AS result,
       @@SQL_MODE AS actual_value;

SELECT 'ENV' AS module, 'UTC 技術時區' AS check_item,
       CASE WHEN @@TIME_ZONE = '+00:00' OR @@TIME_ZONE = 'UTC' OR @@TIME_ZONE = 'SYSTEM' THEN 'PASS' ELSE 'FAIL' END AS result,
       @@TIME_ZONE AS actual_value;
