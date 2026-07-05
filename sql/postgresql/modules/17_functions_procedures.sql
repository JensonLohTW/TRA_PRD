-- ============================================================================
-- 台鐵職工福利平台 — 函數與儲存程序
-- 模組：17_functions_procedures.sql
-- 說明：交易安全編號產生、財務平衡驗證、批次對賬等資料庫內原子操作
-- 依賴：所有 DDL 模組
-- 設計原則：儲存程序不發送通知或呼叫外部服務
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- fn_format_roc_year: 民國年格式化輔助
-- 將西元年轉為民國年字串（如 2026 → 115）
-- ============================================================================
DROP FUNCTION IF EXISTS fn_format_roc_year;

CREATE FUNCTION fn_format_roc_year(p_year INT)
    RETURNS VARCHAR(10)
    DETERMINISTIC
    READS SQL DATA
   
BEGIN
    DECLARE v_roc_year INT;
    SET v_roc_year = p_year - 1911;
    RETURN CAST(v_roc_year AS CHAR);
END //

-- ============================================================================
-- sp_next_business_number: 交易安全取得下一個業務編號
-- 使用事務鎖保證併發唯一，支援 daily/monthly/yearly 流水重設
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_next_business_number //

CREATE PROCEDURE sp_next_business_number(
    IN p_rule_code VARCHAR(50),
    OUT p_business_no VARCHAR(100),
    OUT p_error_code VARCHAR(30)
)
    MODIFIES SQL DATA
   
main_proc:
BEGIN
    DECLARE v_rule_id BIGINT UNSIGNED;
    DECLARE v_prefix VARCHAR(20);
    DECLARE v_seq_min INT;
    DECLARE v_seq_max INT;
    DECLARE v_seq_padding INT;
    DECLARE v_reset_frequency VARCHAR(30);
    DECLARE v_format_pattern VARCHAR(200);
    DECLARE v_period_key VARCHAR(30);
    DECLARE v_current_seq INT;
    DECLARE v_next_seq INT;
    DECLARE v_now DATETIME(6);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_error_code = 'INTERNAL_ERROR';
        SET p_business_no = NULL;
    END;

    SET v_now = NOW(6);
    SET p_error_code = NULL;

    START TRANSACTION;

    SELECT id, prefix, seq_min, seq_max, seq_padding, reset_frequency, format_pattern
    INTO v_rule_id, v_prefix, v_seq_min, v_seq_max, v_seq_padding, v_reset_frequency, v_format_pattern
    FROM sys_number_rule
    WHERE rule_code = p_rule_code AND is_active = 1
    FOR UPDATE;

    IF v_rule_id IS NULL THEN
        SET p_error_code = 'RULE_NOT_FOUND';
        SET p_business_no = NULL;
        COMMIT;
        LEAVE main_proc;
    END IF;

    IF v_reset_frequency = 'daily' THEN
        SET v_period_key = DATE_FORMAT(v_now, '%Y%m%d');
    ELSEIF v_reset_frequency = 'monthly' THEN
        SET v_period_key = DATE_FORMAT(v_now, '%Y%m');
    ELSEIF v_reset_frequency = 'yearly' THEN
        SET v_period_key = DATE_FORMAT(v_now, '%Y');
    ELSE
        SET v_period_key = 'all';
    END IF;

    SELECT current_seq INTO v_current_seq
    FROM sys_number_sequence
    WHERE rule_id = v_rule_id AND period_key = v_period_key
    FOR UPDATE;

    IF v_current_seq IS NULL THEN
        SET v_next_seq = v_seq_min;
        INSERT INTO sys_number_sequence (rule_id, period_key, current_seq)
        VALUES (v_rule_id, v_period_key, v_next_seq);
    ELSE
        SET v_next_seq = v_current_seq + 1;
        IF v_next_seq > v_seq_max THEN
            SET p_error_code = 'SEQ_EXHAUSTED';
            SET p_business_no = NULL;
            COMMIT;
            LEAVE main_proc;
        END IF;
UPDATE sys_number_sequence
    SET current_seq = v_next_seq
    WHERE rule_id = v_rule_id AND period_key = v_period_key;
END IF;

    SET p_business_no = REPLACE(
        REPLACE(
            REPLACE(
                v_format_pattern,
                '{PREFIX}', COALESCE(v_prefix, '')
            ),
            '{YYYYMMDD}', DATE_FORMAT(v_now, '%Y%m%d')
        ),
        '{SEQ}',
        LPAD(v_next_seq, v_seq_padding, '0')
    );

    COMMIT;
END main_proc //

-- ============================================================================
-- sp_verify_financial_balance: 驗證傳票借貸平衡
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_verify_financial_balance //

CREATE PROCEDURE sp_verify_financial_balance(
    IN p_voucher_id BIGINT UNSIGNED,
    OUT p_is_balanced BOOLEAN,
    OUT p_total_debit DECIMAL(14),
    OUT p_total_credit DECIMAL(14),
    OUT p_error_message VARCHAR(500)
)
    READS SQL DATA
   
BEGIN
    DECLARE v_line_count INT;

    SELECT COUNT(*),
           COALESCE(SUM(CASE WHEN direction = 'debit' THEN amount ELSE 0 END), 0),
           COALESCE(SUM(CASE WHEN direction = 'credit' THEN amount ELSE 0 END), 0)
    INTO v_line_count, p_total_debit, p_total_credit
    FROM fin_voucher_line
    WHERE voucher_id = p_voucher_id;

    IF v_line_count = 0 THEN
        SET p_is_balanced = 0;
        SET p_error_message = '傳票無分錄';
    ELSEIF p_total_debit != p_total_credit THEN
        SET p_is_balanced = 0;
        SET p_error_message = CONCAT('借貸不平衡：借方 ', p_total_debit, ' ≠ 貸方 ', p_total_credit);
    ELSE
        SET p_is_balanced = 1;
        SET p_error_message = NULL;
    END IF;
END //

-- ============================================================================
-- sp_reconcile_payment_batch: 批次、名冊、報銷單和傳票對賬
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_reconcile_payment_batch //

CREATE PROCEDURE sp_reconcile_payment_batch(
    IN p_batch_id BIGINT UNSIGNED,
    OUT p_run_id BIGINT UNSIGNED,
    OUT p_difference_count INT,
    OUT p_is_consistent BOOLEAN
)
    MODIFIES SQL DATA
   
BEGIN
    DECLARE v_batch_total DECIMAL(14);
    DECLARE v_batch_count INT;
    DECLARE v_claim_total DECIMAL(14);
    DECLARE v_roster_total DECIMAL(14);
    DECLARE v_voucher_total DECIMAL(14);
    DECLARE v_run_no VARCHAR(50);
    DECLARE v_now DATETIME(6);

    SET v_now = NOW(6);
    SET p_difference_count = 0;
    SET p_is_consistent = 1;

    INSERT INTO fin_reconciliation_run (
        run_no, reconciliation_type, source_batch_id, run_status, started_at
    ) VALUES (
        CONCAT('RECON-', DATE_FORMAT(v_now, '%Y%m%d%H%i%s'), '-', LPAD(FLOOR(RAND() * 1000), 4, '0')),
        'full', p_batch_id, 'running', v_now
    );
    SET p_run_id = LAST_INSERT_ID();

    UPDATE fin_reconciliation_run SET run_no = CONCAT('RECON', LPAD(p_run_id, 10, '0'))
    WHERE id = p_run_id;

    SELECT total_count, total_amount INTO v_batch_count, v_batch_total
    FROM pay_batch WHERE id = p_batch_id;

    SELECT COALESCE(SUM(total_amount), 0) INTO v_claim_total
    FROM fin_reimbursement_claim
    WHERE batch_id = p_batch_id;

    IF v_claim_total > 0 AND v_claim_total != v_batch_total THEN
        INSERT INTO fin_reconciliation_difference (reconciliation_run_id, object_type, object_id, field_name,
            expected_value, actual_value, difference_type, severity)
        VALUES (p_run_id, 'batch', p_batch_id, 'reimbursement_total',
            CAST(v_batch_total AS CHAR), CAST(v_claim_total AS CHAR), 'amount', 'high');
        SET p_difference_count = p_difference_count + 1;
        SET p_is_consistent = 0;
    END IF;

    SELECT COALESCE(SUM(total_amount), 0) INTO v_roster_total
    FROM fin_approval_roster
    WHERE source_batch_id = p_batch_id;

    IF v_roster_total > 0 AND v_roster_total != v_batch_total THEN
        INSERT INTO fin_reconciliation_difference (reconciliation_run_id, object_type, object_id, field_name,
            expected_value, actual_value, difference_type, severity)
        VALUES (p_run_id, 'batch', p_batch_id, 'roster_total',
            CAST(v_batch_total AS CHAR), CAST(v_roster_total AS CHAR), 'amount', 'high');
        SET p_difference_count = p_difference_count + 1;
        SET p_is_consistent = 0;
    END IF;

    SELECT COALESCE(SUM(v.total_debit), 0) INTO v_voucher_total
    FROM fin_voucher v
    INNER JOIN fin_voucher_source_link vsl ON v.id = vsl.voucher_id
    WHERE vsl.source_type = 'batch' AND vsl.source_id = p_batch_id;

    IF v_voucher_total > 0 AND v_voucher_total != v_batch_total THEN
        INSERT INTO fin_reconciliation_difference (reconciliation_run_id, object_type, object_id, field_name,
            expected_value, actual_value, difference_type, severity)
        VALUES (p_run_id, 'batch', p_batch_id, 'voucher_total',
            CAST(v_batch_total AS CHAR), CAST(v_voucher_total AS CHAR), 'amount', 'high');
        SET p_difference_count = p_difference_count + 1;
        SET p_is_consistent = 0;
    END IF;

    UPDATE fin_reconciliation_run
    SET run_status = 'completed', difference_count = p_difference_count, finished_at = NOW(6)
    WHERE id = p_run_id;
END //
