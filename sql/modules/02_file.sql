-- ============================================================================
-- 台鐵職工福利平台 — FILE 檔案資源模組
-- 模組：02_file.sql
-- 說明：物件儲存元資料、分段上傳、惡意掃描、內容檢查、存取記錄與保存策略
-- 依賴：01_sys.sql
-- 設計原則：二進位檔案不存入 MySQL、無多態 target_type/target_id 業務關聯
-- ============================================================================

USE tra_welfare_test;

-- FILE-01: 檔案物件
CREATE TABLE IF NOT EXISTS file_object (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    storage_key         VARCHAR(255)    NOT NULL COMMENT '物件儲存鍵（UUID，唯一）',
    original_name       VARCHAR(255)    NOT NULL COMMENT '原始檔案名稱',
    mime_type           VARCHAR(100)    DEFAULT NULL COMMENT 'MIME 類型',
    file_size_bytes     BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '檔案大小（位元組）',
    page_count          INT             DEFAULT NULL COMMENT '頁數（PDF/圖片適用）',
    image_width         INT             DEFAULT NULL COMMENT '影像寬度（px）',
    image_height        INT             DEFAULT NULL COMMENT '影像高度（px）',
    checksum_sha256     VARCHAR(64)     DEFAULT NULL COMMENT 'SHA-256 校驗值（十六進位）',
    storage_provider    VARCHAR(50)     NOT NULL DEFAULT 'local' COMMENT '儲存提供者：local/s3/minio/gcs',
    encryption_status   VARCHAR(30)     NOT NULL DEFAULT 'none' COMMENT '加密狀態：none/aes256/kms',
    sensitivity_level   VARCHAR(30)     NOT NULL DEFAULT 'normal' COMMENT '敏感等級：normal/sensitive/high_sensitive',
    access_level        VARCHAR(30)     NOT NULL DEFAULT 'internal' COMMENT '存取等級：public/internal/restricted/audit_only',
    file_status         VARCHAR(30)     NOT NULL DEFAULT 'active' COMMENT '檔案狀態：active/archived/disabled/deleted',
    uploaded_by         BIGINT UNSIGNED DEFAULT NULL COMMENT '上傳者（iam_account.id）',
    module_code         VARCHAR(30)     DEFAULT NULL COMMENT '來源模組代碼',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_storage_key (storage_key),
    KEY idx_checksum (checksum_sha256),
    KEY idx_file_status (file_status),
    KEY idx_sensitivity (sensitivity_level),
    KEY idx_uploaded_by (uploaded_by),
    KEY idx_module_code (module_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='物件儲存鍵、檔名、類型、大小和校驗值（二進位不存入 MySQL）';

-- FILE-02: 分段上傳工作階段
CREATE TABLE IF NOT EXISTS file_upload_session (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    session_key     VARCHAR(64)     NOT NULL COMMENT '工作階段唯一鍵',
    original_name   VARCHAR(255)    NOT NULL COMMENT '原始檔案名稱',
    mime_type       VARCHAR(100)    DEFAULT NULL COMMENT 'MIME 類型',
    total_size      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '檔案總大小',
    chunk_size      INT             NOT NULL DEFAULT 5242880 COMMENT '分段大小（預設 5MB）',
    total_chunks    INT             NOT NULL DEFAULT 0 COMMENT '總分段數',
    received_chunks INT             NOT NULL DEFAULT 0 COMMENT '已接收分段數',
    session_status  VARCHAR(30)     NOT NULL DEFAULT 'initiated' COMMENT '狀態：initiated/uploading/completed/expired/failed',
    expires_at      DATETIME(6)     NOT NULL COMMENT '過期時間（UTC）',
    uploaded_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '上傳者（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_session_key (session_key),
    KEY idx_session_status (session_status),
    KEY idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='分段上傳工作階段與狀態';

-- FILE-03: 惡意軟體掃描結果
CREATE TABLE IF NOT EXISTS file_malware_scan (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    scanner_name    VARCHAR(50)     NOT NULL COMMENT '掃描引擎名稱',
    scan_status     VARCHAR(30)     NOT NULL COMMENT '掃描狀態：pending/clean/infected/error/timeout',
    threat_name     VARCHAR(200)    DEFAULT NULL COMMENT '威脅名稱',
    scan_details    TEXT            DEFAULT NULL COMMENT '掃描詳細資訊',
    scanned_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '掃描時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_file_id (file_id),
    KEY idx_scan_status (scan_status),
    CONSTRAINT fk_malware_scan_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='病毒或惡意檔案掃描結果';

-- FILE-04: 檔案內容檢查
CREATE TABLE IF NOT EXISTS file_content_inspection (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    inspection_type VARCHAR(50)     NOT NULL COMMENT '檢查類型：format/quality/page_count/dimension/dpi',
    result_status   VARCHAR(30)     NOT NULL COMMENT '結果：pass/fail/warning',
    result_value    VARCHAR(255)    DEFAULT NULL COMMENT '檢查結果值',
    inspection_json JSON            DEFAULT NULL COMMENT '檢查詳細（結構版本 v1）',
    inspected_at    DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '檢查時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_file_id (file_id),
    CONSTRAINT fk_content_inspection_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='檔案格式、頁數、影像品質等檢查';

-- FILE-05: 檔案存取記錄（僅可追加）
CREATE TABLE IF NOT EXISTS file_access_log (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    access_type     VARCHAR(30)     NOT NULL COMMENT '存取類型：download/preview/export/share',
    accessed_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '存取者（iam_account.id）',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '來源 IP',
    request_trace   VARCHAR(64)     DEFAULT NULL COMMENT '請求追蹤號',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '存取時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_file_id (file_id),
    KEY idx_accessed_by (accessed_by),
    KEY idx_created_at (created_at),
    CONSTRAINT fk_access_log_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='下載、預覽和授權存取記錄（僅可追加）';

-- FILE-06: 檔案保存策略
CREATE TABLE IF NOT EXISTS file_retention_policy (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    policy_code     VARCHAR(50)     NOT NULL COMMENT '策略代碼，業務唯一',
    policy_name     VARCHAR(100)    NOT NULL COMMENT '策略名稱',
    retention_days  INT             NOT NULL COMMENT '保存天數',
    archive_days    INT             DEFAULT NULL COMMENT '封存天數（到期前移入冷儲存）',
    destroy_after   TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '到期是否銷毀',
    applies_to      VARCHAR(50)     NOT NULL DEFAULT '*' COMMENT '適用敏感等級（* 表示全部）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_policy_code (policy_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='檔案保存、封存和銷毀策略';
