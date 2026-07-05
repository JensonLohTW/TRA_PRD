-- ============================================================================
-- 台鐵職工福利平台 — 通用種子資料
-- 模組：20_seed_common.sql
-- 說明：狀態代碼、通知渠道、文件安全等級、審計嚴重等級、任務優先級、預設幣別、
--       時區、基礎權限代碼、編號規則框架（資料可重複執行，冪等）
-- 注意：正式補助目錄、組織、職工等業務種子資料由機關提供，不在本檔猜測
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- 輔助程序：安全插入字典（忽略重複）
-- ============================================================================
DELIMITER //

DROP PROCEDURE IF EXISTS sp_ensure_dict //

CREATE PROCEDURE sp_ensure_dict(p_dict_code VARCHAR(50), p_dict_name VARCHAR(100), p_description VARCHAR(500))
    MODIFIES SQL DATA
    COMMENT '冪等插入字典分類'
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM sys_dictionary WHERE dict_code = p_dict_code;
    IF v_count = 0 THEN
        INSERT INTO sys_dictionary (dict_code, dict_name, description) VALUES (p_dict_code, p_dict_name, p_description);
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_ensure_dict_item //

CREATE PROCEDURE sp_ensure_dict_item(
    p_dict_code VARCHAR(50), p_item_code VARCHAR(50), p_item_name VARCHAR(100),
    p_sort_order INT, p_parent_code VARCHAR(50)
)
    MODIFIES SQL DATA
    COMMENT '冪等插入字典項目'
BEGIN
    DECLARE v_dict_id BIGINT UNSIGNED;
    DECLARE v_parent_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_count INT;

    SELECT id INTO v_dict_id FROM sys_dictionary WHERE dict_code = p_dict_code;

    IF p_parent_code IS NOT NULL THEN
        SELECT id INTO v_parent_id FROM sys_dictionary_item
        WHERE dict_id = v_dict_id AND item_code = p_parent_code;
    END IF;

    SELECT COUNT(*) INTO v_count FROM sys_dictionary_item WHERE dict_id = v_dict_id AND item_code = p_item_code;
    IF v_count = 0 THEN
        INSERT INTO sys_dictionary_item (dict_id, item_code, item_name, sort_order, parent_item_id)
        VALUES (v_dict_id, p_item_code, p_item_name, p_sort_order, v_parent_id);
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_ensure_parameter //

CREATE PROCEDURE sp_ensure_parameter(
    p_param_key VARCHAR(100), p_param_value TEXT, p_value_type VARCHAR(30), p_scope_type VARCHAR(30), p_description VARCHAR(500)
)
    MODIFIES SQL DATA
    COMMENT '冪等插入系統參數'
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM sys_parameter WHERE param_key = p_param_key;
    IF v_count = 0 THEN
        INSERT INTO sys_parameter (param_key, param_value, value_type, scope_type, description)
        VALUES (p_param_key, p_param_value, p_value_type, p_scope_type, p_description);
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_ensure_number_rule //

CREATE PROCEDURE sp_ensure_number_rule(
    p_rule_code VARCHAR(50), p_rule_name VARCHAR(100), p_format_pattern VARCHAR(200),
    p_prefix VARCHAR(20), p_seq_padding INT, p_reset_frequency VARCHAR(30)
)
    MODIFIES SQL DATA
    COMMENT '冪等插入編號規則'
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM sys_number_rule WHERE rule_code = p_rule_code;
    IF v_count = 0 THEN
        INSERT INTO sys_number_rule (rule_code, rule_name, format_pattern, prefix, seq_padding, reset_frequency)
        VALUES (p_rule_code, p_rule_name, p_format_pattern, p_prefix, p_seq_padding, p_reset_frequency);
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_ensure_role //

CREATE PROCEDURE sp_ensure_role(
    p_role_code VARCHAR(50), p_role_name VARCHAR(100), p_role_type VARCHAR(30), p_description VARCHAR(500)
)
    MODIFIES SQL DATA
    COMMENT '冪等插入角色'
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM rbac_role WHERE role_code = p_role_code;
    IF v_count = 0 THEN
        INSERT INTO rbac_role (role_code, role_name, role_type, description)
        VALUES (p_role_code, p_role_name, p_role_type, p_description);
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_ensure_permission //

CREATE PROCEDURE sp_ensure_permission(
    p_permission_code VARCHAR(100), p_permission_name VARCHAR(100), p_module_code VARCHAR(30), p_resource_type VARCHAR(50), p_action VARCHAR(30)
)
    MODIFIES SQL DATA
    COMMENT '冪等插入權限'
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM rbac_permission WHERE permission_code = p_permission_code;
    IF v_count = 0 THEN
        INSERT INTO rbac_permission (permission_code, permission_name, module_code, resource_type, action)
        VALUES (p_permission_code, p_permission_name, p_module_code, p_resource_type, p_action);
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- 1. 申請狀態代碼
-- ============================================================================
CALL sp_ensure_dict('APPLICATION_STATUS', '申請狀態', '補助申請案件狀態代碼');
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'draft', '草稿', 1, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'submitted', '已送件', 2, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'waiting_physical_document', '等待紙本', 3, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'physical_document_received', '已收紙本', 4, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'under_review', '審核中', 5, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'supplement_required', '待補件', 6, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'resubmitted', '補件再審', 7, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'rejected', '退件', 8, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'approved', '已核准', 9, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'payment_pending', '待請款', 10, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'paid', '已撥款', 11, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'receipt_pending', '待領款確認', 12, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'closed', '已結案', 13, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'cancelled', '已作廢', 14, NULL);
CALL sp_ensure_dict_item('APPLICATION_STATUS', 'archived', '已封存', 15, NULL);

-- ============================================================================
-- 2. 審批任務狀態
-- ============================================================================
CALL sp_ensure_dict('TASK_STATUS', '審批任務狀態', '工作流審批任務狀態代碼');
CALL sp_ensure_dict_item('TASK_STATUS', 'ready', '待辦理', 1, NULL);
CALL sp_ensure_dict_item('TASK_STATUS', 'claimed', '已認領', 2, NULL);
CALL sp_ensure_dict_item('TASK_STATUS', 'approved', '已核准', 3, NULL);
CALL sp_ensure_dict_item('TASK_STATUS', 'returned', '退回', 4, NULL);
CALL sp_ensure_dict_item('TASK_STATUS', 'supplement_requested', '要求補件', 5, NULL);
CALL sp_ensure_dict_item('TASK_STATUS', 'rejected', '拒絕', 6, NULL);
CALL sp_ensure_dict_item('TASK_STATUS', 'delegated', '代理辦理', 7, NULL);
CALL sp_ensure_dict_item('TASK_STATUS', 'cancelled', '已取消', 8, NULL);
CALL sp_ensure_dict_item('TASK_STATUS', 'expired', '逾時', 9, NULL);

-- ============================================================================
-- 3. 批次狀態
-- ============================================================================
CALL sp_ensure_dict('BATCH_STATUS', '批次狀態', '請款／發款批次狀態代碼');
CALL sp_ensure_dict_item('BATCH_STATUS', 'draft', '草稿', 1, NULL);
CALL sp_ensure_dict_item('BATCH_STATUS', 'verified', '已確認', 2, NULL);
CALL sp_ensure_dict_item('BATCH_STATUS', 'submitted', '已送審', 3, NULL);
CALL sp_ensure_dict_item('BATCH_STATUS', 'approved', '已核准', 4, NULL);
CALL sp_ensure_dict_item('BATCH_STATUS', 'disbursing', '撥款中', 5, NULL);
CALL sp_ensure_dict_item('BATCH_STATUS', 'partially_completed', '部分完成', 6, NULL);
CALL sp_ensure_dict_item('BATCH_STATUS', 'completed', '已完成', 7, NULL);
CALL sp_ensure_dict_item('BATCH_STATUS', 'reconciled', '已對賬', 8, NULL);
CALL sp_ensure_dict_item('BATCH_STATUS', 'closed', '已結案', 9, NULL);

-- ============================================================================
-- 4. 禮金狀態
-- ============================================================================
CALL sp_ensure_dict('GIFT_STATUS', '禮金狀態', '禮金三階段狀態代碼');
CALL sp_ensure_dict_item('GIFT_STATUS', 'estimated', '預估', 1, NULL);
CALL sp_ensure_dict_item('GIFT_STATUS', 'distributing', '發放中', 2, NULL);
CALL sp_ensure_dict_item('GIFT_STATUS', 'settling', '結算中', 3, NULL);
CALL sp_ensure_dict_item('GIFT_STATUS', 'reimbursement_submitted', '代請款送審', 4, NULL);
CALL sp_ensure_dict_item('GIFT_STATUS', 'reconciled', '已對賬', 5, NULL);
CALL sp_ensure_dict_item('GIFT_STATUS', 'closed', '已結案', 6, NULL);

-- ============================================================================
-- 5. 傳票狀態
-- ============================================================================
CALL sp_ensure_dict('VOUCHER_STATUS', '傳票狀態', '收支傳票狀態代碼');
CALL sp_ensure_dict_item('VOUCHER_STATUS', 'draft', '草稿', 1, NULL);
CALL sp_ensure_dict_item('VOUCHER_STATUS', 'reviewed', '已校對', 2, NULL);
CALL sp_ensure_dict_item('VOUCHER_STATUS', 'final', '最終稿', 3, NULL);
CALL sp_ensure_dict_item('VOUCHER_STATUS', 'reversed', '已沖正', 4, NULL);

-- ============================================================================
-- 6. 公告狀態
-- ============================================================================
CALL sp_ensure_dict('ANNOUNCEMENT_STATUS', '公告狀態', '公告發佈狀態代碼');
CALL sp_ensure_dict_item('ANNOUNCEMENT_STATUS', 'draft', '草稿', 1, NULL);
CALL sp_ensure_dict_item('ANNOUNCEMENT_STATUS', 'pending_approval', '待審批', 2, NULL);
CALL sp_ensure_dict_item('ANNOUNCEMENT_STATUS', 'scheduled', '已排程', 3, NULL);
CALL sp_ensure_dict_item('ANNOUNCEMENT_STATUS', 'published', '已發佈', 4, NULL);
CALL sp_ensure_dict_item('ANNOUNCEMENT_STATUS', 'withdrawn', '已撤回', 5, NULL);
CALL sp_ensure_dict_item('ANNOUNCEMENT_STATUS', 'expired', '已到期', 6, NULL);

-- ============================================================================
-- 7. 安全告警等級
-- ============================================================================
CALL sp_ensure_dict('ALERT_SEVERITY', '告警嚴重等級', '安全告警嚴重等級代碼');
CALL sp_ensure_dict_item('ALERT_SEVERITY', 'critical', '嚴重', 1, NULL);
CALL sp_ensure_dict_item('ALERT_SEVERITY', 'high', '高', 2, NULL);
CALL sp_ensure_dict_item('ALERT_SEVERITY', 'medium', '中', 3, NULL);
CALL sp_ensure_dict_item('ALERT_SEVERITY', 'low', '低', 4, NULL);

-- ============================================================================
-- 8. 通知渠道
-- ============================================================================
CALL sp_ensure_dict('NOTIFICATION_CHANNEL', '通知渠道', '通知發送渠道代碼');
CALL sp_ensure_dict_item('NOTIFICATION_CHANNEL', 'email', 'Email', 1, NULL);
CALL sp_ensure_dict_item('NOTIFICATION_CHANNEL', 'in_app', '站內信', 2, NULL);
CALL sp_ensure_dict_item('NOTIFICATION_CHANNEL', 'sms', '簡訊', 3, NULL);
CALL sp_ensure_dict_item('NOTIFICATION_CHANNEL', 'web_push', '瀏覽器推播', 4, NULL);

-- ============================================================================
-- 9. 檔案安全等級
-- ============================================================================
CALL sp_ensure_dict('FILE_SENSITIVITY', '檔案安全等級', '檔案敏感等級代碼');
CALL sp_ensure_dict_item('FILE_SENSITIVITY', 'normal', '一般', 1, NULL);
CALL sp_ensure_dict_item('FILE_SENSITIVITY', 'sensitive', '敏感', 2, NULL);
CALL sp_ensure_dict_item('FILE_SENSITIVITY', 'high_sensitive', '高度敏感', 3, NULL);

-- ============================================================================
-- 10. 任務優先級
-- ============================================================================
CALL sp_ensure_dict('TASK_PRIORITY', '任務優先級', '任務優先級代碼');
CALL sp_ensure_dict_item('TASK_PRIORITY', 'urgent', '緊急', 1, NULL);
CALL sp_ensure_dict_item('TASK_PRIORITY', 'high', '高', 2, NULL);
CALL sp_ensure_dict_item('TASK_PRIORITY', 'normal', '普通', 3, NULL);
CALL sp_ensure_dict_item('TASK_PRIORITY', 'low', '低', 4, NULL);

-- ============================================================================
-- 11. 系統參數
-- ============================================================================
CALL sp_ensure_parameter('system.timezone', 'Asia/Taipei', 'string', 'global', '系統時區');
CALL sp_ensure_parameter('system.currency', 'TWD', 'string', 'global', '預設幣別');
CALL sp_ensure_parameter('system.roc_year_offset', '1911', 'int', 'global', '民國年偏移量（西元年減此值）');
CALL sp_ensure_parameter('iam.password.min_length', '8', 'int', 'global', '密碼最小長度');
CALL sp_ensure_parameter('iam.password.max_history', '5', 'int', 'global', '密碼歷史保留次數');
CALL sp_ensure_parameter('iam.login.max_failures', '5', 'int', 'global', '最大連續登入失敗次數');
CALL sp_ensure_parameter('iam.login.lock_minutes', '30', 'int', 'global', '鎖定時間（分鐘）');
CALL sp_ensure_parameter('iam.otp.expire_minutes', '10', 'int', 'global', 'OTP 有效期限（分鐘）');
CALL sp_ensure_parameter('iam.session.idle_timeout', '1800', 'int', 'global', '會話閒置逾時（秒）');
CALL sp_ensure_parameter('iam.session.max_duration', '28800', 'int', 'global', '會話最長持續時間（秒）');
CALL sp_ensure_parameter('system.supplement.default_deadline_days', '14', 'int', 'global', '補件預設截止天數');
CALL sp_ensure_parameter('audit.retention_days', '1095', 'int', 'global', '審計日誌保存天數（三年）');

-- ============================================================================
-- 12. 編號規則
-- ============================================================================
CALL sp_ensure_number_rule('CASE_NO', '案件編號', '{PREFIX}{YYYYMMDD}{SEQ}', 'TRA', 6, 'daily');
CALL sp_ensure_number_rule('BATCH_NO', '批次編號', '{PREFIX}{YYYYMMDD}{SEQ}', 'B', 6, 'daily');
CALL sp_ensure_number_rule('VOUCHER_NO', '傳票編號', '{PREFIX}{YYYYMMDD}{SEQ}', 'V', 6, 'daily');
CALL sp_ensure_number_rule('CLAIM_NO', '報銷單編號', '{PREFIX}{YYYYMMDD}{SEQ}', 'C', 6, 'daily');
CALL sp_ensure_number_rule('ROSTER_NO', '名冊編號', '{PREFIX}{YYYYMM}{SEQ}', 'R', 6, 'monthly');
CALL sp_ensure_number_rule('ANN_NO', '公告編號', '{PREFIX}{YYYYMMDD}{SEQ}', 'ANN', 6, 'daily');

-- ============================================================================
-- 13. 基礎角色
-- ============================================================================
CALL sp_ensure_role('system_admin', '系統管理員', 'system', '系統管理與技術設定');
CALL sp_ensure_role('auditor', '稽核人員', 'audit', '稽核與安全檢視');
CALL sp_ensure_role('ben_admin', '補助管理員', 'business', '補助設定與管理');
CALL sp_ensure_role('ben_reviewer', '補助審核員', 'business', '補助案件審批');
CALL sp_ensure_role('welfare_shop_admin', '福利社管理員', 'business', '福利社業務管理');
CALL sp_ensure_role('employee_self', '一般職工', 'business', '一般職工自助服務');
CALL sp_ensure_role('finance_admin', '財務管理員', 'business', '財務與傳票管理');

-- ============================================================================
-- 14. 基礎權限代碼
-- ============================================================================
CALL sp_ensure_permission('ben_application:create', '建立申請', 'BEN-APP', 'ben_application', 'create');
CALL sp_ensure_permission('ben_application:read_self', '查閱本人申請', 'BEN-APP', 'ben_application', 'read');
CALL sp_ensure_permission('ben_application:read_all', '查閱全部申請', 'BEN-APP', 'ben_application', 'read');
CALL sp_ensure_permission('ben_application:update', '更新申請', 'BEN-APP', 'ben_application', 'update');
CALL sp_ensure_permission('ben_application:approve', '核准申請', 'BEN-APP', 'ben_application', 'approve');
CALL sp_ensure_permission('ben_application:delete', '刪除申請', 'BEN-APP', 'ben_application', 'delete');
CALL sp_ensure_permission('ben_config:manage', '管理補助設定', 'BEN-CFG', 'ben_config', 'update');
CALL sp_ensure_permission('pay_batch:create', '建立批次', 'PAY', 'pay_batch', 'create');
CALL sp_ensure_permission('pay_batch:approve', '核准批次', 'PAY', 'pay_batch', 'approve');
CALL sp_ensure_permission('pay_batch:disburse', '執行撥款', 'PAY', 'pay_batch', 'update');
CALL sp_ensure_permission('fin_voucher:create', '建立傳票', 'FIN', 'fin_voucher', 'create');
CALL sp_ensure_permission('fin_voucher:finalize', '確認傳票終稿', 'FIN', 'fin_voucher', 'approve');
CALL sp_ensure_permission('fin_reconciliation:run', '執行財務對賬', 'FIN', 'fin_reconciliation', 'create');
CALL sp_ensure_permission('mch_merchant:manage', '管理商店資料', 'MCH', 'mch_merchant', 'update');
CALL sp_ensure_permission('ann_announcement:publish', '發佈公告', 'ANN', 'ann_announcement', 'approve');
CALL sp_ensure_permission('sec_audit:query', '查詢審計日誌', 'SEC', 'sec_audit', 'read');
CALL sp_ensure_permission('org_unit:manage', '管理組織架構', 'ORG', 'org_unit', 'update');
CALL sp_ensure_permission('iam_account:manage', '管理平台帳號', 'IAM', 'iam_account', 'update');
CALL sp_ensure_permission('rbac_role:assign', '指派角色', 'RBAC', 'rbac_role', 'update');

-- ============================================================================
-- 15. 資料範圍定義
-- ============================================================================
INSERT IGNORE INTO rbac_data_scope (scope_code, scope_name, scope_type, description)
VALUES ('all', '全部資料', 'all', '可存取系統中所有資料'),
       ('self', '本人資料', 'self', '僅可存取本人相關資料'),
       ('org_tree', '單位樹', 'org_tree', '可存取所屬單位及其下級單位資料'),
       ('assigned_org', '指定單位', 'org', '可存取指定單位資料'),
       ('assigned_welfare', '指定福利社', 'org', '可存取指定福利社資料');

-- ============================================================================
-- 16. 保留策略
-- ============================================================================
INSERT IGNORE INTO file_retention_policy (policy_code, policy_name, retention_days, archive_days, destroy_after, applies_to)
VALUES ('normal_doc', '一般文件', 365, 180, 0, 'normal'),
       ('sensitive_doc', '敏感文件', 1825, 365, 0, 'sensitive'),
       ('financial_doc', '財務文件', 3650, 730, 0, 'high_sensitive'),
       ('audit_log', '審計日誌', 1095, 365, 1, 'high_sensitive');
