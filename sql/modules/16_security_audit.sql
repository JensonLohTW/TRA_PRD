-- ============================================================================
-- 台鐵職工福利平台 — SEC 稽核與資安模組
-- 模組：16_security_audit.sql
-- 說明：全域審計事件、變更差異、哈希鏈檢查點、資料存取事件、冷歸檔、
--       安全告警與處置、掃描規則與任務、發現結果、合規文件、日誌匯出
-- 依賴：01_sys.sql、02_file.sql、05_iam.sql
-- 設計原則：審計日誌僅可追加、業務帳號不得更新或刪除、敏感值脫敏
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- 1. 審計核心
-- ============================================================================

-- SEC-01: 全域審計事件
CREATE TABLE IF NOT EXISTS sec_audit_event (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    event_time      DATETIME(6)     NOT NULL COMMENT '事件時間（UTC）',
    module_code     VARCHAR(30)     NOT NULL COMMENT '模組代碼',
    action_code     VARCHAR(50)     NOT NULL COMMENT '動作代碼（如 application.submit, batch.approve）',
    actor_account_id BIGINT UNSIGNED DEFAULT NULL COMMENT '操作者帳號（iam_account.id）',
    actor_name      VARCHAR(100)    DEFAULT NULL COMMENT '操作者姓名（快照）',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '來源 IP',
    request_trace   VARCHAR(64)     DEFAULT NULL COMMENT '請求追蹤號 / 冪等鍵',
    object_type     VARCHAR(50)     DEFAULT NULL COMMENT '操作對象類型',
    object_id       BIGINT UNSIGNED DEFAULT NULL COMMENT '操作對象 ID',
    object_identifier VARCHAR(200)  DEFAULT NULL COMMENT '操作對象業務標識（如案件編號）',
    result_status   VARCHAR(30)     NOT NULL COMMENT '結果：success/failure/partial/blocked',
    detail          TEXT            DEFAULT NULL COMMENT '事件詳細（不含密碼、OTP 等敏感值）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '記錄時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_event_time (event_time),
    KEY idx_module_action (module_code, action_code),
    KEY idx_actor (actor_account_id, event_time),
    KEY idx_object (object_type, object_id, event_time),
    KEY idx_request_trace (request_trace)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='全域關鍵操作事件（僅可追加，不含密碼、OTP、完整身份證號或完整銀行帳號）';

-- SEC-02: 審計變更差異
CREATE TABLE IF NOT EXISTS sec_audit_change (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    audit_event_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 sec_audit_event.id',
    before_json     JSON            DEFAULT NULL COMMENT '變更前（結構版本 v1）',
    after_json      JSON            NOT NULL COMMENT '變更後（結構版本 v1）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_audit_event_id (audit_event_id),
    CONSTRAINT fk_audit_change_event FOREIGN KEY (audit_event_id) REFERENCES sec_audit_event(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='結構化變更前後差異 JSON';

-- SEC-03: 審計哈希鏈檢查點
CREATE TABLE IF NOT EXISTS sec_audit_chain_checkpoint (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    checkpoint_time DATETIME(6)     NOT NULL COMMENT '檢查點時間（UTC）',
    last_event_id   BIGINT UNSIGNED NOT NULL COMMENT '檢查點涵蓋的最後事件 ID',
    chain_hash      VARCHAR(64)     NOT NULL COMMENT '哈希鏈累積摘要',
    checkpoint_type VARCHAR(30)     NOT NULL DEFAULT 'periodic' COMMENT '檢查點類型：periodic/manual/archive',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_chain_checkpoint (checkpoint_time, checkpoint_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='日誌哈希鏈或簽章檢查點';

-- SEC-04: 資料存取事件
CREATE TABLE IF NOT EXISTS sec_data_access_event (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    event_time      DATETIME(6)     NOT NULL COMMENT '存取時間（UTC）',
    actor_account_id BIGINT UNSIGNED DEFAULT NULL COMMENT '存取者（iam_account.id）',
    access_type     VARCHAR(30)     NOT NULL COMMENT '存取類型：query/view/export/download/print',
    data_category   VARCHAR(50)     NOT NULL COMMENT '資料類別：personal/sensitive/financial/audit',
    object_type     VARCHAR(50)     DEFAULT NULL COMMENT '對象類型',
    object_id       BIGINT UNSIGNED DEFAULT NULL COMMENT '對象 ID',
    filter_summary  VARCHAR(500)    DEFAULT NULL COMMENT '查詢條件摘要（不含敏感值）',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '來源 IP',
    request_trace   VARCHAR(64)     DEFAULT NULL COMMENT '請求追蹤號',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '記錄時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_event_time (event_time),
    KEY idx_actor (actor_account_id, event_time),
    KEY idx_access_type (access_type),
    KEY idx_data_category (data_category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='敏感資料查詢、下載和匯出';

-- ============================================================================
-- 2. 冷歸檔
-- ============================================================================

-- SEC-05: 審計冷歸檔
CREATE TABLE IF NOT EXISTS sec_audit_archive (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    archive_batch_no VARCHAR(50)    NOT NULL COMMENT '歸檔批號，唯一',
    archive_date    DATE            NOT NULL COMMENT '歸檔日期',
    start_event_id  BIGINT UNSIGNED NOT NULL COMMENT '歸檔起始事件 ID',
    end_event_id    BIGINT UNSIGNED NOT NULL COMMENT '歸檔結束事件 ID',
    total_events    INT             NOT NULL DEFAULT 0 COMMENT '歸檔事件數',
    archive_file_key VARCHAR(128)   DEFAULT NULL COMMENT '歸檔檔案鍵（file_object.storage_key）',
    archive_checksum VARCHAR(64)    DEFAULT NULL COMMENT '歸檔資料 SHA-256 摘要',
    digital_signature VARCHAR(256)  DEFAULT NULL COMMENT '數位簽章',
    archive_status  VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/processing/completed/verified',
    archived_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '歸檔操作者（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_archive_batch_no (archive_batch_no),
    KEY idx_archive_date (archive_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='冷歸檔檔案、校驗值和簽章';

-- ============================================================================
-- 3. 安全告警
-- ============================================================================

-- SEC-06: 安全告警
CREATE TABLE IF NOT EXISTS sec_security_alert (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    alert_type      VARCHAR(50)     NOT NULL COMMENT '告警類型：anomalous_login/unauthorized_access/brute_force/data_leak/scan_finding/business_risk',
    alert_severity  VARCHAR(30)     NOT NULL DEFAULT 'medium' COMMENT '嚴重等級：low/medium/high/critical',
    alert_title     VARCHAR(200)    NOT NULL COMMENT '告警標題',
    alert_detail    TEXT            DEFAULT NULL COMMENT '告警詳細',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '來源 IP',
    affected_account_id BIGINT UNSIGNED DEFAULT NULL COMMENT '受影響帳號',
    alert_status    VARCHAR(30)     NOT NULL DEFAULT 'open' COMMENT '狀態：open/acknowledged/investigating/resolved/dismissed',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_alert_type (alert_type),
    KEY idx_alert_severity (alert_severity),
    KEY idx_alert_status (alert_status),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='異常登入、越權、攻擊和業務風險告警';

-- SEC-07: 告警處置動作
CREATE TABLE IF NOT EXISTS sec_alert_action (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    alert_id        BIGINT UNSIGNED NOT NULL COMMENT '關聯 sec_security_alert.id',
    action_type     VARCHAR(30)     NOT NULL COMMENT '動作類型：acknowledge/assign/investigate/resolve/dismiss/escalate',
    action_detail   TEXT            DEFAULT NULL COMMENT '動作詳細',
    operator_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '操作者（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_alert_id (alert_id),
    KEY idx_action_type (action_type),
    CONSTRAINT fk_alert_action_alert FOREIGN KEY (alert_id) REFERENCES sec_security_alert(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='告警確認、指派、處置和關閉';

-- ============================================================================
-- 4. 安全掃描
-- ============================================================================

-- SEC-08: 掃描規則
CREATE TABLE IF NOT EXISTS sec_scan_rule (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    rule_code       VARCHAR(50)     NOT NULL COMMENT '規則代碼，唯一',
    rule_name       VARCHAR(100)    NOT NULL COMMENT '規則名稱',
    scan_type       VARCHAR(30)     NOT NULL COMMENT '掃描類型：vulnerability/malware/sensitive_data/config_review',
    schedule_cron   VARCHAR(100)    DEFAULT NULL COMMENT '排程 CRON',
    config_json     JSON            DEFAULT NULL COMMENT '規則設定（結構版本 v1）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_scan_rule_code (rule_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='離峰資料或安全掃描規則';

-- SEC-09: 掃描任務
CREATE TABLE IF NOT EXISTS sec_scan_job (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    scan_rule_id    BIGINT UNSIGNED NOT NULL COMMENT '關聯 sec_scan_rule.id',
    job_status      VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/running/completed/failed',
    total_findings  INT             NOT NULL DEFAULT 0 COMMENT '發現總數',
    critical_count  INT             NOT NULL DEFAULT 0,
    high_count      INT             NOT NULL DEFAULT 0,
    medium_count    INT             NOT NULL DEFAULT 0,
    low_count       INT             NOT NULL DEFAULT 0,
    triggered_by    VARCHAR(30)     NOT NULL DEFAULT 'scheduler' COMMENT '觸發方式：scheduler/manual',
    started_at      DATETIME(6)     DEFAULT NULL COMMENT '開始時間（UTC）',
    finished_at     DATETIME(6)     DEFAULT NULL COMMENT '結束時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_scan_rule_id (scan_rule_id),
    KEY idx_job_status (job_status),
    CONSTRAINT fk_scan_job_rule FOREIGN KEY (scan_rule_id) REFERENCES sec_scan_rule(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='自動或手動掃描任務';

-- SEC-10: 掃描發現
CREATE TABLE IF NOT EXISTS sec_scan_finding (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    scan_job_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 sec_scan_job.id',
    finding_type    VARCHAR(50)     NOT NULL COMMENT '發現類型',
    severity        VARCHAR(30)     NOT NULL COMMENT '嚴重等級：critical/high/medium/low/info',
    title           VARCHAR(200)    NOT NULL COMMENT '標題',
    description     TEXT            DEFAULT NULL COMMENT '描述',
    affected_resource VARCHAR(500)  DEFAULT NULL COMMENT '受影響資源',
    recommendation  TEXT            DEFAULT NULL COMMENT '建議',
    finding_status  VARCHAR(30)     NOT NULL DEFAULT 'open' COMMENT '狀態：open/in_progress/resolved/false_positive/accepted_risk',
    resolved_at     DATETIME(6)     DEFAULT NULL COMMENT '解決時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_scan_job_id (scan_job_id),
    KEY idx_severity (severity),
    KEY idx_finding_status (finding_status),
    CONSTRAINT fk_scan_finding_job FOREIGN KEY (scan_job_id) REFERENCES sec_scan_job(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='掃描發現和嚴重等級';

-- ============================================================================
-- 5. 合規與匯出
-- ============================================================================

-- SEC-11: 合規文件
CREATE TABLE IF NOT EXISTS sec_compliance_document (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    document_type   VARCHAR(30)     NOT NULL COMMENT '文件類型：penetration_test/vulnerability_scan/compliance_report/audit_report',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    document_title  VARCHAR(200)    NOT NULL COMMENT '文件標題',
    document_date   DATE            DEFAULT NULL COMMENT '文件日期',
    is_confidential TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否機密',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '上傳者（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_document_type (document_type),
    KEY idx_file_id (file_id),
    CONSTRAINT fk_compliance_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='弱掃、滲透測試和合規文件';

-- SEC-12: 日誌查詢匯出任務
CREATE TABLE IF NOT EXISTS sec_log_export_job (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    request_no      VARCHAR(50)     NOT NULL COMMENT '申請編號，唯一',
    export_scope_json JSON          NOT NULL COMMENT '匯出範圍（結構版本 v1，含時間範圍、模組、動作）',
    export_reason   TEXT            NOT NULL COMMENT '匯出原因',
    export_status   VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/processing/completed/expired',
    result_file_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '結果檔案（file_object.id）',
    expires_at      DATETIME(6)     DEFAULT NULL COMMENT '結果檔案過期時間（UTC）',
    requested_by    BIGINT UNSIGNED NOT NULL COMMENT '申請人（iam_account.id）',
    approved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '核准人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_log_export_request_no (request_no),
    KEY idx_export_status (export_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='日誌查詢與匯出任務';
