-- ============================================================================
-- 台鐵職工福利平台 — AI OCR 與異常預警模組
-- 模組：13_ai_ocr.sql
-- 說明：模型註冊、OCR 任務與嘗試、影像品質、辨識結果與欄位、人工修正、
--       異常規則與結果、重複特徵與比對、處理軌跡
-- 依賴：01_sys.sql、02_file.sql、09_ben_application.sql
-- 設計原則：OCR 僅輔助判斷、不具最終核定效力、人工修正不覆蓋原始結果
-- ============================================================================

USE tra_welfare_test;

-- AI-01: 模型註冊
CREATE TABLE IF NOT EXISTS ai_model_registry (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    model_code      VARCHAR(50)     NOT NULL COMMENT '模型代碼，唯一',
    model_name      VARCHAR(100)    NOT NULL COMMENT '模型名稱',
    model_version   VARCHAR(30)     NOT NULL COMMENT '模型版本號',
    model_type      VARCHAR(30)     NOT NULL COMMENT '類型：ocr/quality/classification/anomaly',
    provider        VARCHAR(50)     DEFAULT NULL COMMENT '提供方',
    config_json     JSON            DEFAULT NULL COMMENT '模型設定（結構版本 v1）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_model_code (model_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='OCR 或影像模型版本';

-- AI-02: OCR 任務
CREATE TABLE IF NOT EXISTS ai_ocr_job (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    application_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ben_application.id',
    model_id        BIGINT UNSIGNED NOT NULL COMMENT '關聯 ai_model_registry.id',
    job_status      VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/processing/completed/failed',
    priority        INT             NOT NULL DEFAULT 5 COMMENT '優先級（1-10，越低越優先）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_file_id (file_id),
    KEY idx_application_id (application_id),
    KEY idx_job_status (job_status),
    KEY idx_priority (priority),
    CONSTRAINT fk_ocr_job_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ocr_job_model FOREIGN KEY (model_id) REFERENCES ai_model_registry(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='一個附件的辨識任務';

-- AI-03: OCR 嘗試
CREATE TABLE IF NOT EXISTS ai_ocr_attempt (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    ocr_job_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 ai_ocr_job.id',
    attempt_no      INT             NOT NULL COMMENT '嘗試序號',
    attempt_status  VARCHAR(30)     NOT NULL DEFAULT 'processing' COMMENT '狀態：processing/completed/failed/timeout',
    duration_ms     INT             DEFAULT NULL COMMENT '耗時（毫秒）',
    error_message   TEXT            DEFAULT NULL COMMENT '錯誤資訊',
    processing_node VARCHAR(100)    DEFAULT NULL COMMENT '處理節點',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_ocr_job_id (ocr_job_id),
    CONSTRAINT fk_ocr_attempt_job FOREIGN KEY (ocr_job_id) REFERENCES ai_ocr_job(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='重試、耗時和錯誤資訊';

-- AI-04: 文件品質結果
CREATE TABLE IF NOT EXISTS ai_document_quality_result (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    ocr_job_id      BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ai_ocr_job.id',
    quality_status  VARCHAR(30)     NOT NULL COMMENT '品質狀態：pass/blurred/too_dark/too_bright/missing_corner/low_resolution',
    confidence_score DECIMAL(5, 2)  DEFAULT NULL COMMENT '信心度（0-100）',
    details_json    JSON            DEFAULT NULL COMMENT '詳細結果（結構版本 v1）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_file_id (file_id),
    KEY idx_quality_status (quality_status),
    CONSTRAINT fk_quality_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='模糊、過暗、缺角等品質結果';

-- AI-05: OCR 結果
CREATE TABLE IF NOT EXISTS ai_ocr_result (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    ocr_attempt_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ai_ocr_attempt.id',
    model_id        BIGINT UNSIGNED NOT NULL COMMENT '關聯 ai_model_registry.id',
    raw_result_json JSON            NOT NULL COMMENT '原始供應商回應（結構版本 v1）',
    overall_confidence DECIMAL(5, 2) DEFAULT NULL COMMENT '總體信心度（0-100）',
    processed_at    DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '處理時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_ocr_attempt_id (ocr_attempt_id),
    CONSTRAINT fk_ocr_result_attempt FOREIGN KEY (ocr_attempt_id) REFERENCES ai_ocr_attempt(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='OCR 總體結果、模型和原始結果 JSON';

-- AI-06: OCR 欄位
CREATE TABLE IF NOT EXISTS ai_ocr_field (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    ocr_result_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 ai_ocr_result.id',
    field_name      VARCHAR(100)    NOT NULL COMMENT '欄位名稱（如 applicant_name, amount, date）',
    field_value     TEXT            NOT NULL COMMENT '辨識值',
    confidence      DECIMAL(5, 2)   DEFAULT NULL COMMENT '信心度（0-100）',
    bounding_box_json JSON          DEFAULT NULL COMMENT '座標框（結構版本 v1）',
    field_type      VARCHAR(30)     DEFAULT NULL COMMENT '欄位型別：string/number/date/boolean',
    is_normalized   TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已正規化',
    normalized_value TEXT           DEFAULT NULL COMMENT '正規化後值',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_ocr_result_id (ocr_result_id),
    KEY idx_field_name (field_name),
    CONSTRAINT fk_ocr_field_result FOREIGN KEY (ocr_result_id) REFERENCES ai_ocr_result(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='正規化欄位、值、信心度和座標';

-- AI-07: 人工修正
CREATE TABLE IF NOT EXISTS ai_manual_correction (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    ocr_field_id    BIGINT UNSIGNED NOT NULL COMMENT '關聯 ai_ocr_field.id',
    original_value  TEXT            NOT NULL COMMENT '原始辨識值',
    corrected_value TEXT            NOT NULL COMMENT '人工修正值',
    corrected_by    BIGINT UNSIGNED DEFAULT NULL COMMENT '修正者（iam_account.id）',
    correction_reason VARCHAR(500)  DEFAULT NULL COMMENT '修正原因',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '來源 IP',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_ocr_field_id (ocr_field_id),
    KEY idx_corrected_by (corrected_by),
    CONSTRAINT fk_correction_field FOREIGN KEY (ocr_field_id) REFERENCES ai_ocr_field(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='使用者或審核人員對 OCR 值的修正';

-- AI-08: 異常規則
CREATE TABLE IF NOT EXISTS ai_anomaly_rule (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    rule_code       VARCHAR(50)     NOT NULL COMMENT '規則代碼，唯一',
    rule_name       VARCHAR(100)    NOT NULL COMMENT '規則名稱',
    rule_type       VARCHAR(30)     NOT NULL COMMENT '類型：duplicate/amount_range/date_range/academic_year/identity',
    severity        VARCHAR(30)     NOT NULL DEFAULT 'medium' COMMENT '嚴重等級：low/medium/high/critical',
    condition_json  JSON            NOT NULL COMMENT '條件定義（結構版本 v1）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    version_no      INT             NOT NULL DEFAULT 1 COMMENT '規則版本號',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_anomaly_rule_code (rule_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='金額、日期、學年和重複等規則';

-- AI-09: 異常結果
CREATE TABLE IF NOT EXISTS ai_anomaly_result (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ben_application.id',
    rule_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 ai_anomaly_rule.id',
    severity        VARCHAR(30)     NOT NULL COMMENT '嚴重等級',
    evidence_json   JSON            NOT NULL COMMENT '證據（結構版本 v1）',
    result_status   VARCHAR(30)     NOT NULL DEFAULT 'open' COMMENT '狀態：open/investigating/dismissed/confirmed',
    handled_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '處理人（iam_account.id）',
    handled_at      DATETIME(6)     DEFAULT NULL COMMENT '處理時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    KEY idx_rule_id (rule_id),
    KEY idx_result_status (result_status),
    CONSTRAINT fk_anomaly_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE SET NULL,
    CONSTRAINT fk_anomaly_rule FOREIGN KEY (rule_id) REFERENCES ai_anomaly_rule(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='案件異常與嚴重等級';

-- AI-10: 重複特徵摘要
CREATE TABLE IF NOT EXISTS ai_duplicate_fingerprint (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    fingerprint_hash VARCHAR(64)    NOT NULL COMMENT '不可逆特徵摘要',
    fingerprint_type VARCHAR(30)    NOT NULL COMMENT '特徵類型：file_checksum/name_birth/identity_hash/amount_date',
    source_object_type VARCHAR(50)  DEFAULT NULL COMMENT '來源對象類型',
    source_object_id BIGINT UNSIGNED DEFAULT NULL COMMENT '來源對象 ID',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_fingerprint_hash (fingerprint_hash),
    KEY idx_fingerprint_type (fingerprint_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='檔案或業務事件特徵摘要';

-- AI-11: 重複比對結果
CREATE TABLE IF NOT EXISTS ai_duplicate_match (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    source_application_id BIGINT UNSIGNED NOT NULL COMMENT '來源案件（ben_application.id）',
    candidate_application_id BIGINT UNSIGNED NOT NULL COMMENT '候選案件（ben_application.id）',
    match_score     DECIMAL(5, 2)   NOT NULL COMMENT '比對分數（0-100）',
    match_type      VARCHAR(30)     NOT NULL COMMENT '比對類型：exact/high/medium/low',
    evidence_json   JSON            DEFAULT NULL COMMENT '比對證據（結構版本 v1）',
    human_decision  VARCHAR(30)     DEFAULT NULL COMMENT '人工決定：confirmed/dismissed/pending',
    decided_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '決定者（iam_account.id）',
    decided_at      DATETIME(6)     DEFAULT NULL COMMENT '決定時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_source_application (source_application_id),
    KEY idx_candidate_application (candidate_application_id),
    KEY idx_match_score (match_score),
    CONSTRAINT fk_match_source FOREIGN KEY (source_application_id) REFERENCES ben_application(id) ON DELETE RESTRICT,
    CONSTRAINT fk_match_candidate FOREIGN KEY (candidate_application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='疑似重複案件比對結果';

-- AI-12: 處理軌跡
CREATE TABLE IF NOT EXISTS ai_processing_trace (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    ocr_job_id      BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ai_ocr_job.id',
    trace_stage     VARCHAR(30)     NOT NULL COMMENT '階段：queued/dispatched/processing/completed/failed',
    trace_detail    TEXT            DEFAULT NULL COMMENT '詳細',
    processing_node VARCHAR(100)    DEFAULT NULL COMMENT '處理節點',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_ocr_job_id (ocr_job_id),
    KEY idx_trace_stage (trace_stage)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任務階段和算力調度軌跡';
