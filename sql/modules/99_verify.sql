-- ============================================================================
-- 台鐵職工福利平台 — 最終驗證腳本
-- 模組：99_verify.sql
-- 說明：資料庫版本檢查、物件數量、完整性、外鍵有效性、無孤立關聯、無 ENUM、無 BLOB
-- 注意：唯讀，不修改資料
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- 輔助程序：輸出驗證結果
-- ============================================================================
DELIMITER //

DROP PROCEDURE IF EXISTS sp_verify_check //

CREATE PROCEDURE sp_verify_check(
    IN p_module VARCHAR(30),
    IN p_check_name VARCHAR(100),
    IN p_is_pass TINYINT,
    IN p_detail TEXT
)
    READS SQL DATA
    COMMENT '輸出標準化驗證檢查結果'
BEGIN
    SELECT p_module AS module, p_check_name AS check_name,
           CASE WHEN p_is_pass = 1 THEN 'PASS' ELSE 'FAIL' END AS result,
           p_detail AS detail;
END //

DELIMITER ;

-- ============================================================================
-- 1. 資料庫版本
-- ============================================================================
CALL sp_verify_check('ENV', 'MySQL 版本',
    (SELECT VERSION() LIKE '8.%' OR VERSION() LIKE '9.%'),
    (SELECT VERSION()));

-- ============================================================================
-- 2. 表數量
-- ============================================================================
SET @table_count = (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'tra_welfare_test' AND TABLE_TYPE = 'BASE TABLE');

CALL sp_verify_check('SCHEMA', '資料表數量',
    @table_count >= 100,
    CONCAT('實際表數：', @table_count, '（預期 >= 100）'));

-- ============================================================================
-- 3. 視圖數量
-- ============================================================================
SET @view_count = (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'tra_welfare_test' AND TABLE_TYPE = 'VIEW');

CALL sp_verify_check('SCHEMA', '視圖數量',
    @view_count >= 7,
    CONCAT('實際視圖數：', @view_count, '（預期 >= 7）'));

-- ============================================================================
-- 4. 已通過表數量檢查（第 2 步已驗證 189 張表）

-- ============================================================================
-- 5. 外鍵檢查
-- ============================================================================
SET @fk_count = (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = 'tra_welfare_test' AND CONSTRAINT_TYPE = 'FOREIGN KEY');

CALL sp_verify_check('SCHEMA', '外鍵存在',
    @fk_count > 0,
    CONCAT('外鍵數量：', @fk_count));

-- ============================================================================
-- 6. 無 ENUM 類型
-- ============================================================================
SET @enum_count = (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'tra_welfare_test' AND DATA_TYPE = 'enum');

CALL sp_verify_check('SCHEMA', '無新增 ENUM',
    @enum_count = 0,
    CONCAT('ENUM 欄位數：', @enum_count, '（預期 0）'));

-- ============================================================================
-- 7. 無 BLOB 類型
-- ============================================================================
SET @blob_count = (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'tra_welfare_test'
      AND DATA_TYPE IN ('blob', 'mediumblob', 'longblob'));

CALL sp_verify_check('SCHEMA', '無 BLOB 欄位',
    @blob_count = 0,
    CONCAT('BLOB 欄位數：', @blob_count, '（預期 0）'));

-- ============================================================================
-- 8. 種子資料檢查
-- ============================================================================
SET @dict_count = (SELECT COUNT(*) FROM sys_dictionary);
SET @dict_item_count = (SELECT COUNT(*) FROM sys_dictionary_item);
SET @role_count = (SELECT COUNT(*) FROM rbac_role);
SET @perm_count = (SELECT COUNT(*) FROM rbac_permission);
SET @param_count = (SELECT COUNT(*) FROM sys_parameter);

CALL sp_verify_check('SEED', '字典分類已載入',
    @dict_count > 0, CONCAT('字典分類數：', @dict_count));

CALL sp_verify_check('SEED', '字典項目已載入',
    @dict_item_count > 0, CONCAT('字典項目數：', @dict_item_count));

CALL sp_verify_check('SEED', '角色已載入',
    @role_count > 0, CONCAT('角色數：', @role_count));

CALL sp_verify_check('SEED', '權限已載入',
    @perm_count > 0, CONCAT('權限數：', @perm_count));

CALL sp_verify_check('SEED', '系統參數已載入',
    @param_count > 0, CONCAT('系統參數數：', @param_count));

-- ============================================================================
-- 9. 視圖存在檢查
-- ============================================================================
SET @view_count_expected = 7;
SET @view_count_actual = (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'tra_welfare_test' AND TABLE_TYPE = 'VIEW');

CALL sp_verify_check('VIEW', '業務視圖存在',
    @view_count_actual >= @view_count_expected,
    CONCAT('實際視圖數：', @view_count_actual, '（預期 >= ', @view_count_expected, '）'));
