-- ============================================================================
-- 台鐵職工福利平台 — SYS 系統基礎模組
-- 模組：01_sys.sql
-- 說明：系統參數、字典、編號規則、排程任務、事件發件箱、資料導入與外部整合
-- 依賴：00_database.sql
-- ============================================================================

-- 前置檢查：確保目標資料庫存在
USE tra_welfare_test;

-- ============================================================================
-- 1. 系統參數與字典
-- ============================================================================

-- SYS-01: 系統參數
CREATE TABLE IF NOT EXISTS sys_parameter (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    param_key       VARCHAR(100)    NOT NULL COMMENT '參數鍵，業務唯一',
    param_value     TEXT            NOT NULL COMMENT '參數值',
    value_type      VARCHAR(30)     NOT NULL DEFAULT 'string' COMMENT '值型別：string/int/decimal/boolean/json',
    scope_type      VARCHAR(30)     NOT NULL DEFAULT 'global' COMMENT '生效範圍：global/org/module',
    scope_id        BIGINT UNSIGNED DEFAULT NULL COMMENT '範圍對象 ID（scope_type 為 org/module 時使用）',
    description     VARCHAR(500)    DEFAULT NULL COMMENT '說明',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_param_key (param_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系統參數及生效範圍';

-- SYS-02: 系統參數變更歷史
CREATE TABLE IF NOT EXISTS sys_parameter_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    parameter_id    BIGINT UNSIGNED NOT NULL COMMENT '關聯 sys_parameter.id',
    param_key       VARCHAR(100)    NOT NULL COMMENT '變更時參數鍵（保留歷史查詢用）',
    old_value       TEXT            DEFAULT NULL COMMENT '變更前值',
    new_value       TEXT            NOT NULL COMMENT '變更後值',
    changed_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '變更操作者（iam_account.id）',
    change_reason   VARCHAR(500)    DEFAULT NULL COMMENT '變更原因',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_parameter_id (parameter_id),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系統參數版本與變更歷史';

-- SYS-03: 字典分類
CREATE TABLE IF NOT EXISTS sys_dictionary (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    dict_code       VARCHAR(50)     NOT NULL COMMENT '字典分類代碼，業務唯一',
    dict_name       VARCHAR(100)    NOT NULL COMMENT '字典分類名稱',
    description     VARCHAR(500)    DEFAULT NULL COMMENT '說明',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_dict_code (dict_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='字典分類';

-- SYS-04: 字典項目
CREATE TABLE IF NOT EXISTS sys_dictionary_item (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    dict_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 sys_dictionary.id',
    item_code       VARCHAR(50)     NOT NULL COMMENT '項目代碼（同一字典內唯一）',
    item_name       VARCHAR(100)    NOT NULL COMMENT '項目顯示名稱',
    sort_order      INT             NOT NULL DEFAULT 0 COMMENT '排序',
    parent_item_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '父層項目（自我參照）',
    extra_json      JSON            DEFAULT NULL COMMENT '額外設定（結構版本 v1）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_dict_item (dict_id, item_code),
    KEY idx_parent_item (parent_item_id),
    CONSTRAINT fk_dict_item_dict FOREIGN KEY (dict_id) REFERENCES sys_dictionary(id) ON DELETE RESTRICT,
    CONSTRAINT fk_dict_item_parent FOREIGN KEY (parent_item_id) REFERENCES sys_dictionary_item(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='字典項目（狀態、類型和原因代碼）';

-- ============================================================================
-- 2. 編號規則與流水
-- ============================================================================

-- SYS-05: 編號規則定義
CREATE TABLE IF NOT EXISTS sys_number_rule (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    rule_code       VARCHAR(50)     NOT NULL COMMENT '規則代碼，業務唯一（如 CASE_NO, BATCH_NO, VOUCHER_NO）',
    rule_name       VARCHAR(100)    NOT NULL COMMENT '規則名稱',
    format_pattern  VARCHAR(200)    NOT NULL COMMENT '編號格式範本（如 {PREFIX}{YYYYMMDD}{SEQ:6}）',
    prefix          VARCHAR(20)     DEFAULT NULL COMMENT '固定前綴',
    seq_min         INT             NOT NULL DEFAULT 1 COMMENT '流水號起始值',
    seq_max         INT             NOT NULL DEFAULT 999999 COMMENT '流水號最大值',
    seq_padding     INT             NOT NULL DEFAULT 6 COMMENT '流水號補零位數',
    reset_frequency VARCHAR(30)     NOT NULL DEFAULT 'never' COMMENT '重設頻率：never/daily/monthly/yearly',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_rule_code (rule_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='案件號、批號、傳票號等編號規則';

-- SYS-06: 編號流水狀態（併發安全）
CREATE TABLE IF NOT EXISTS sys_number_sequence (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    rule_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 sys_number_rule.id',
    period_key      VARCHAR(30)     NOT NULL COMMENT '期間鍵（如 20260703, 202607）',
    current_seq     INT             NOT NULL DEFAULT 0 COMMENT '當前已用流水號',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_rule_period (rule_id, period_key),
    CONSTRAINT fk_seq_rule FOREIGN KEY (rule_id) REFERENCES sys_number_rule(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='併發安全的編號流水狀態';

-- ============================================================================
-- 3. 排程任務
-- ============================================================================

-- SYS-07: 排程任務定義
CREATE TABLE IF NOT EXISTS sys_job_definition (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    job_code        VARCHAR(50)     NOT NULL COMMENT '任務代碼，業務唯一',
    job_name        VARCHAR(100)    NOT NULL COMMENT '任務名稱',
    job_type        VARCHAR(30)     NOT NULL COMMENT '任務類型：notification/import/export/archive/sync',
    cron_expression VARCHAR(100)    DEFAULT NULL COMMENT 'CRON 排程表示式',
    max_retries     INT             NOT NULL DEFAULT 3 COMMENT '最大重試次數',
    timeout_seconds INT             NOT NULL DEFAULT 300 COMMENT '單次執行逾時秒數',
    config_json     JSON            DEFAULT NULL COMMENT '任務設定（結構版本 v1）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_job_code (job_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='排程任務定義';

-- SYS-08: 任務執行記錄
CREATE TABLE IF NOT EXISTS sys_job_run (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    job_id          BIGINT UNSIGNED NOT NULL COMMENT '關聯 sys_job_definition.id',
    run_status      VARCHAR(30)     NOT NULL COMMENT '執行狀態：running/completed/failed/timeout',
    started_at      DATETIME(6)     NOT NULL COMMENT '開始時間（UTC）',
    finished_at     DATETIME(6)     DEFAULT NULL COMMENT '結束時間（UTC）',
    result_summary  VARCHAR(500)    DEFAULT NULL COMMENT '結果摘要',
    error_message   TEXT            DEFAULT NULL COMMENT '錯誤訊息',
    retry_count     INT             NOT NULL DEFAULT 0 COMMENT '重試次數',
    triggered_by    VARCHAR(50)     NOT NULL DEFAULT 'scheduler' COMMENT '觸發方式：scheduler/manual/api',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_job_id (job_id),
    KEY idx_run_status (run_status),
    KEY idx_started_at (started_at),
    CONSTRAINT fk_job_run_definition FOREIGN KEY (job_id) REFERENCES sys_job_definition(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='每次任務執行結果';

-- ============================================================================
-- 4. 跨模組事件發件箱
-- ============================================================================

-- SYS-09: 事件發件箱
CREATE TABLE IF NOT EXISTS sys_outbox_event (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    event_id        VARCHAR(64)     NOT NULL COMMENT '全域唯一事件 ID（UUID），用於消費端冪等',
    aggregate_type  VARCHAR(50)     NOT NULL COMMENT '聚合類型（如 ben_application, pay_batch）',
    aggregate_id    BIGINT UNSIGNED NOT NULL COMMENT '聚合 ID',
    event_type      VARCHAR(100)    NOT NULL COMMENT '事件類型（如 ApplicationSubmitted, BatchApproved）',
    payload_json    JSON            NOT NULL COMMENT '事件載荷（結構版本 v1，不含敏感明文）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    published_at    DATETIME(6)     DEFAULT NULL COMMENT '發佈時間（UTC），null 表示未發佈',
    retry_count     INT             NOT NULL DEFAULT 0 COMMENT '發佈重試次數',
    last_error      TEXT            DEFAULT NULL COMMENT '最後錯誤訊息',
    PRIMARY KEY (id),
    UNIQUE KEY uk_event_id (event_id),
    KEY idx_aggregate (aggregate_type, aggregate_id),
    KEY idx_publish_status (published_at, retry_count),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='跨模組事件發件箱';

-- SYS-10: 事件消費冪等記錄
CREATE TABLE IF NOT EXISTS sys_event_consume_log (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    consumer_code   VARCHAR(50)     NOT NULL COMMENT '消費者代碼（如 ntf_sender, pay_batch_handler）',
    event_id        VARCHAR(64)     NOT NULL COMMENT '消費的事件 ID',
    consume_status  VARCHAR(30)     NOT NULL COMMENT '消費狀態：success/failed/ignored',
    error_message   TEXT            DEFAULT NULL COMMENT '錯誤訊息',
    consumed_at     DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '消費時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_consumer_event (consumer_code, event_id),
    KEY idx_consumed_at (consumed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='事件消費冪等記錄';

-- ============================================================================
-- 5. 資料導入
-- ============================================================================

-- SYS-11: 導入任務
CREATE TABLE IF NOT EXISTS sys_import_job (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    import_type     VARCHAR(50)     NOT NULL COMMENT '導入類型：org/employee/dependent/contribution/benefit',
    file_key        VARCHAR(128)    DEFAULT NULL COMMENT '來源檔案鍵（file_object.storage_key）',
    checksum        VARCHAR(128)    DEFAULT NULL COMMENT '原始檔案 SHA-256 摘要',
    total_rows      INT             NOT NULL DEFAULT 0 COMMENT '總筆數',
    success_rows    INT             NOT NULL DEFAULT 0 COMMENT '成功筆數',
    failed_rows     INT             NOT NULL DEFAULT 0 COMMENT '失敗筆數',
    import_status   VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '導入狀態：pending/validating/importing/completed/failed',
    started_at      DATETIME(6)     DEFAULT NULL COMMENT '開始時間（UTC）',
    finished_at     DATETIME(6)     DEFAULT NULL COMMENT '結束時間（UTC）',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_import_type (import_type),
    KEY idx_import_status (import_status),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='人員、組織、眷屬、扣繳等導入任務';

-- SYS-12: 導入行錯誤
CREATE TABLE IF NOT EXISTS sys_import_row_error (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    import_job_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 sys_import_job.id',
    row_index       INT             NOT NULL COMMENT '來源檔案行號',
    raw_value_json  JSON            NOT NULL COMMENT '原始值（結構版本 v1）',
    cleaned_value_json JSON         DEFAULT NULL COMMENT '清洗後值（結構版本 v1）',
    error_message   TEXT            NOT NULL COMMENT '錯誤描述',
    is_resolved     TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已修正',
    resolved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '修正者（iam_account.id）',
    resolved_at     DATETIME(6)     DEFAULT NULL COMMENT '修正時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_import_job_id (import_job_id),
    KEY idx_is_resolved (is_resolved),
    CONSTRAINT fk_import_error_job FOREIGN KEY (import_job_id) REFERENCES sys_import_job(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='導入行錯誤與修正資訊';

-- ============================================================================
-- 6. 外部整合
-- ============================================================================

-- SYS-13: 外部介接端點設定
CREATE TABLE IF NOT EXISTS sys_integration_endpoint (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    endpoint_code   VARCHAR(50)     NOT NULL COMMENT '端點代碼，業務唯一',
    endpoint_name   VARCHAR(100)    NOT NULL COMMENT '端點名稱',
    provider_type   VARCHAR(50)     NOT NULL COMMENT '提供方類型：microsoft_graph/ bank_api / sms_gateway / email_smtp',
    base_url        VARCHAR(500)    DEFAULT NULL COMMENT '基底 URL',
    auth_type       VARCHAR(30)     NOT NULL DEFAULT 'none' COMMENT '認證類型：none/api_key/oauth2/client_credential',
    secret_ref      VARCHAR(200)    DEFAULT NULL COMMENT '秘密引用鍵（不保存明文 secret）',
    timeout_seconds INT             NOT NULL DEFAULT 30 COMMENT '逾時秒數',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_endpoint_code (endpoint_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='外部介接端點配置，不保存明文密鑰';

-- SYS-14: 外部同步執行記錄
CREATE TABLE IF NOT EXISTS sys_integration_run (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    endpoint_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 sys_integration_endpoint.id',
    run_type        VARCHAR(50)     NOT NULL COMMENT '執行類型：sync/push/pull/query',
    run_status      VARCHAR(30)     NOT NULL COMMENT '執行狀態：running/completed/failed/partial',
    total_count     INT             NOT NULL DEFAULT 0 COMMENT '總筆數',
    success_count   INT             NOT NULL DEFAULT 0 COMMENT '成功筆數',
    failed_count    INT             NOT NULL DEFAULT 0 COMMENT '失敗筆數',
    started_at      DATETIME(6)     NOT NULL COMMENT '開始時間（UTC）',
    finished_at     DATETIME(6)     DEFAULT NULL COMMENT '結束時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_endpoint_id (endpoint_id),
    KEY idx_run_status (run_status),
    KEY idx_started_at (started_at),
    CONSTRAINT fk_integration_run_endpoint FOREIGN KEY (endpoint_id) REFERENCES sys_integration_endpoint(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='外部同步批次及處理統計';

-- SYS-15: 外部同步失敗記錄
CREATE TABLE IF NOT EXISTS sys_integration_error (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    integration_run_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 sys_integration_run.id',
    object_type     VARCHAR(50)     DEFAULT NULL COMMENT '對象類型',
    object_id       VARCHAR(100)    DEFAULT NULL COMMENT '對象外部 ID',
    error_type      VARCHAR(50)     NOT NULL COMMENT '錯誤類型：timeout/auth/validation/network/business',
    error_message   TEXT            NOT NULL COMMENT '錯誤訊息',
    raw_response    TEXT            DEFAULT NULL COMMENT '原始回應（不含敏感資料）',
    is_retryable    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否可重試',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_integration_run_id (integration_run_id),
    CONSTRAINT fk_integration_error_run FOREIGN KEY (integration_run_id) REFERENCES sys_integration_run(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='外部同步失敗記錄';
