-- ============================================================================
-- 台鐵職工福利平台 — all-in-one 整合檔案
-- 模組：all_in_one.sql（由 assemble_sql.sh 產生）
-- 說明：依固定順序整合所有模組 DDL、種子、觸發器、視圖與驗證
-- 產生日期：2026-07-03
-- 規格版本：v1.0（docs/superpowers/specs/2026-07-03-tra-subsidy-database-design.md）
-- 模組清單：00_database, 01_sys, 02_file, 03_org, 04_emp, 05_iam, 06_rbac, 07_ntf,
--          08_ben_config, 09_ben_application, 10_workflow, 11_payment, 12_finance,
--          13_ai_ocr, 14_merchant, 15_announcement, 16_security_audit,
--          17_functions_procedures, 18_triggers, 19_views, 20_seed_common, 99_verify
-- 執行方式：mysql --defaults-extra-file="$MYSQL_CNF" < sql/all_in_one.sql
-- ============================================================================

-- ============================================================================
-- 來源：sql/modules/00_database.sql
-- ============================================================================
SET NAMES utf8mb4;
SET @OLD_SQL_MODE := @@SQL_MODE;
SET SQL_MODE = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET @OLD_TIME_ZONE := @@TIME_ZONE;
SET TIME_ZONE = '+00:00';
SET @OLD_FOREIGN_KEY_CHECKS := @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 1;

CREATE DATABASE IF NOT EXISTS tra_welfare_all_in_one
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE tra_welfare_all_in_one;

SET SQL_MODE = @OLD_SQL_MODE;
SET TIME_ZONE = @OLD_TIME_ZONE;
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;
