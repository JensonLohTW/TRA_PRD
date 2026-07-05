-- ============================================================================
-- 台鐵職工福利平台 — 資料庫環境初始化
-- 模組：00_database.sql
-- 說明：建立資料庫、字元集、排序規則及連線層級安全設定
-- 技術棧：MySQL 8.x、InnoDB、utf8mb4
-- 執行方式：mysql --defaults-extra-file="$MYSQL_CNF" < sql/modules/00_database.sql
-- 注意：本檔不保存帳號、密碼或雲端連線資訊
-- ============================================================================

-- 全域約定：嚴格 SQL 模式、UTC 技術時區、utf8mb4
SET NAMES utf8mb4;
SET @OLD_SQL_MODE := @@SQL_MODE;
SET SQL_MODE = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET @OLD_TIME_ZONE := @@TIME_ZONE;
SET TIME_ZONE = '+00:00';
SET @OLD_FOREIGN_KEY_CHECKS := @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 1;

-- 建立測試資料庫（正式環境請另行建立）
CREATE DATABASE IF NOT EXISTS tra_welfare_test
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- 還原連線層級設定
SET SQL_MODE = @OLD_SQL_MODE;
SET TIME_ZONE = @OLD_TIME_ZONE;
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;
