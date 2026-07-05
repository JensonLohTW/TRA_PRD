-- ============================================================================
-- 台鐵職工福利平台 — 最小化觸發器
-- 模組：18_triggers.sql
-- 說明：僅保留明確資料庫不變量價值的觸發器
-- 原則：不跨模組建立業務記錄、不發送通知、不呼叫外部服務
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- TRG-01: 阻止不可變歷史表被更新或刪除
-- ============================================================================

DROP TRIGGER IF EXISTS trg_ben_status_history_update_restrict;

DELIMITER //
CREATE TRIGGER trg_ben_status_history_update_restrict
    BEFORE UPDATE ON ben_application_status_history
    FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ben_application_status_history 僅可追加，不允許更新';
END //

DROP TRIGGER IF EXISTS trg_ben_status_history_delete_restrict //

CREATE TRIGGER trg_ben_status_history_delete_restrict
    BEFORE DELETE ON ben_application_status_history
    FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ben_application_status_history 僅可追加，不允許刪除';
END //

-- ============================================================================
-- TRG-02: 阻止最終財務文件被修改或刪除
-- ============================================================================

DROP TRIGGER IF EXISTS trg_voucher_final_update_restrict //

CREATE TRIGGER trg_voucher_final_update_restrict
    BEFORE UPDATE ON fin_voucher
    FOR EACH ROW
BEGIN
    IF OLD.voucher_status = 'final' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '最終傳票不可直接修改，請透過沖正處理';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_voucher_final_delete_restrict //

CREATE TRIGGER trg_voucher_final_delete_restrict
    BEFORE DELETE ON fin_voucher
    FOR EACH ROW
BEGIN
    IF OLD.voucher_status = 'final' OR OLD.voucher_status = 'reversed' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '最終或已沖正傳票不可刪除';
    END IF;
END //

-- ============================================================================
-- TRG-03: 阻止審計事件表被更新或刪除
-- ============================================================================

DROP TRIGGER IF EXISTS trg_audit_event_update_restrict //

CREATE TRIGGER trg_audit_event_update_restrict
    BEFORE UPDATE ON sec_audit_event
    FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sec_audit_event 僅可追加，不允許更新';
END //

DROP TRIGGER IF EXISTS trg_audit_event_delete_restrict //

CREATE TRIGGER trg_audit_event_delete_restrict
    BEFORE DELETE ON sec_audit_event
    FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sec_audit_event 僅可追加，不允許刪除';
END //

-- ============================================================================
-- TRG-04: 阻止 sec_audit_change 被更新或刪除
-- ============================================================================

DROP TRIGGER IF EXISTS trg_audit_change_update_restrict //

CREATE TRIGGER trg_audit_change_update_restrict
    BEFORE UPDATE ON sec_audit_change
    FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sec_audit_change 僅可追加，不允許更新';
END //

DROP TRIGGER IF EXISTS trg_audit_change_delete_restrict //

CREATE TRIGGER trg_audit_change_delete_restrict
    BEFORE DELETE ON sec_audit_change
    FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'sec_audit_change 僅可追加，不允許刪除';
END //

-- ============================================================================
-- TRG-05: 阻止送出或核准後申請被直接刪除
-- ============================================================================

DROP TRIGGER IF EXISTS trg_application_submitted_delete_restrict //

CREATE TRIGGER trg_application_submitted_delete_restrict
    BEFORE DELETE ON ben_application
    FOR EACH ROW
BEGIN
    IF OLD.current_status NOT IN ('draft', 'cancelled') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '已送件或已處理申請不可直接刪除，請使用作廢或封存流程';
    END IF;
END //

DELIMITER ;
