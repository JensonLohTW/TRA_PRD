-- ============================================================================
-- 台鐵職工福利平台 — BEN-CFG 補助配置模組
-- 模組：08_ben_config.sql
-- 說明：補助目錄、政策版本、動態表單定義與版本、JSON 索引、應附文件規則、資格規則、
--       額度規則、數位切結、列印模板、會計映射、工作流映射
-- 依賴：01_sys.sql、02_file.sql、10_workflow.sql（workflow_mapping 外鍵）
-- 設計原則：已發佈版本不可覆蓋、歷史案件引用提交時版本
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- 1. 補助目錄與政策
-- ============================================================================

-- BEN-CFG-01: 補助大項目錄
CREATE TABLE IF NOT EXISTS ben_program (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    program_code    VARCHAR(30)     NOT NULL COMMENT '大項代碼，業務唯一',
    program_name    VARCHAR(100)    NOT NULL COMMENT '大項名稱',
    program_type    VARCHAR(30)     NOT NULL DEFAULT 'subsidy' COMMENT '類型：subsidy/gift/loan/other',
    sort_order      INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_program_code (program_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='補助大項目錄';

-- BEN-CFG-02: 具體補助類型
CREATE TABLE IF NOT EXISTS ben_type (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    type_code       VARCHAR(30)     NOT NULL COMMENT '類型代碼，業務唯一',
    type_name       VARCHAR(100)    NOT NULL COMMENT '類型名稱',
    program_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_program.id',
    sort_order      INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_type_code (type_code),
    KEY idx_program_id (program_id),
    CONSTRAINT fk_type_program FOREIGN KEY (program_id) REFERENCES ben_program(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='具體補助類型';

-- BEN-CFG-03: 補助政策版本
CREATE TABLE IF NOT EXISTS ben_policy_version (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    benefit_type_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_type.id',
    version_no      INT             NOT NULL COMMENT '版本號（同一類型內遞增）',
    policy_name     VARCHAR(200)    NOT NULL COMMENT '政策名稱',
    description     TEXT            DEFAULT NULL COMMENT '政策說明',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期（null 表示現行）',
    is_published    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已發佈（發佈後不可覆蓋）',
    published_at    DATETIME(6)     DEFAULT NULL COMMENT '發佈時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_type_version (benefit_type_id, version_no),
    KEY idx_effective_date (effective_date, expiration_date),
    CONSTRAINT fk_policy_type FOREIGN KEY (benefit_type_id) REFERENCES ben_type(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='某補助類型的政策版本';

-- ============================================================================
-- 2. 動態表單定義
-- ============================================================================

-- BEN-CFG-04: 動態表單邏輯名稱
CREATE TABLE IF NOT EXISTS ben_form_definition (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    form_code       VARCHAR(50)     NOT NULL COMMENT '表單代碼，業務唯一',
    form_name       VARCHAR(100)    NOT NULL COMMENT '表單名稱',
    benefit_type_id BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ben_type.id（null 表示通用表單）',
    description     TEXT            DEFAULT NULL COMMENT '說明',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_form_code (form_code),
    KEY idx_benefit_type_id (benefit_type_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='動態表單邏輯名稱';

-- BEN-CFG-05: 表單版本
CREATE TABLE IF NOT EXISTS ben_form_version (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    form_definition_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_form_definition.id',
    version_no      INT             NOT NULL COMMENT '版本號（同一表單內遞增）',
    schema_json     JSON            NOT NULL COMMENT 'JSON Schema（結構版本 v1，定義各補助彈性欄位）',
    ui_schema_json  JSON            DEFAULT NULL COMMENT 'UI Schema（結構版本 v1，控制項與顯示條件）',
    validation_json JSON            DEFAULT NULL COMMENT '驗證規則（結構版本 v1，條件必填與跨欄位規則）',
    schema_hash     VARCHAR(64)     NOT NULL COMMENT 'schema_json 的 SHA-256 摘要',
    is_published    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已發佈',
    published_at    DATETIME(6)     DEFAULT NULL COMMENT '發佈時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_form_version (form_definition_id, version_no),
    CONSTRAINT fk_form_version_definition FOREIGN KEY (form_definition_id) REFERENCES ben_form_definition(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='表單 JSON Schema、UI 和驗證版本';

-- BEN-CFG-06: JSON 索引定義
CREATE TABLE IF NOT EXISTS ben_form_index_definition (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    form_version_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_form_version.id',
    json_path       VARCHAR(200)    NOT NULL COMMENT 'JSON 路徑（如 $.applicantName）',
    target_type     VARCHAR(30)     NOT NULL COMMENT '目標資料型別：string/int/decimal/date',
    is_stable       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '路徑是否穩定（穩定路徑才建立生成列）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_form_path (form_version_id, json_path),
    CONSTRAINT fk_index_definition_form FOREIGN KEY (form_version_id) REFERENCES ben_form_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='聲明需要建立索引的穩定 JSON 路徑';

-- ============================================================================
-- 3. 規則與模板
-- ============================================================================

-- BEN-CFG-07: 應附文件規則
CREATE TABLE IF NOT EXISTS ben_required_document_rule (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    policy_version_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_policy_version.id',
    document_type_code  VARCHAR(50)     NOT NULL COMMENT '文件類型代碼',
    document_name       VARCHAR(100)    NOT NULL COMMENT '文件名稱',
    is_required         TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否必附',
    max_files           INT             NOT NULL DEFAULT 1 COMMENT '最多上傳件數',
    condition_json      JSON            DEFAULT NULL COMMENT '條件規則（結構版本 v1，何種情況需附）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_policy_version_id (policy_version_id),
    CONSTRAINT fk_document_rule_policy FOREIGN KEY (policy_version_id) REFERENCES ben_policy_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='必附文件類型和條件';

-- BEN-CFG-08: 資格規則
CREATE TABLE IF NOT EXISTS ben_eligibility_rule (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    policy_version_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_policy_version.id',
    rule_code           VARCHAR(50)     NOT NULL COMMENT '規則代碼',
    rule_name           VARCHAR(100)    NOT NULL COMMENT '規則名稱',
    rule_type           VARCHAR(30)     NOT NULL COMMENT '規則類型：tenure/contribution/age/relationship/residence',
    condition_json      JSON            NOT NULL COMMENT '條件定義（結構版本 v1）',
    error_message       VARCHAR(500)    DEFAULT NULL COMMENT '不滿足時提示訊息',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_policy_rule (policy_version_id, rule_code),
    CONSTRAINT fk_eligibility_rule_policy FOREIGN KEY (policy_version_id) REFERENCES ben_policy_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='資格規則版本';

-- BEN-CFG-09: 額度規則
CREATE TABLE IF NOT EXISTS ben_limit_rule (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    policy_version_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_policy_version.id',
    limit_type          VARCHAR(30)     NOT NULL COMMENT '限制類型：annual_amount/ annual_count / lifetime_amount / per_request_amount',
    limit_value         DECIMAL(12, 0)  NOT NULL COMMENT '限制值（金額或次數）',
    currency_code       VARCHAR(3)      NOT NULL DEFAULT 'TWD' COMMENT '幣別',
    condition_json      JSON            DEFAULT NULL COMMENT '適用條件（結構版本 v1）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_policy_version_id (policy_version_id),
    CONSTRAINT fk_limit_rule_policy FOREIGN KEY (policy_version_id) REFERENCES ben_policy_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='年度、次數和金額上限';

-- BEN-CFG-10: 數位切結模板
CREATE TABLE IF NOT EXISTS ben_declaration_template (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    policy_version_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_policy_version.id',
    version_no      INT             NOT NULL COMMENT '版本號',
    content         TEXT            NOT NULL COMMENT '切結內容文字',
    is_published    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已發佈',
    published_at    DATETIME(6)     DEFAULT NULL COMMENT '發佈時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_policy_declaration (policy_version_id, version_no),
    CONSTRAINT fk_declaration_policy FOREIGN KEY (policy_version_id) REFERENCES ben_policy_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='數位切結內容版本';

-- BEN-CFG-11: 正式申請書列印模板
CREATE TABLE IF NOT EXISTS ben_print_template (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    policy_version_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_policy_version.id',
    version_no      INT             NOT NULL COMMENT '版本號',
    template_file_key VARCHAR(128)  DEFAULT NULL COMMENT '模板檔案鍵（file_object.storage_key）',
    template_type   VARCHAR(30)     NOT NULL DEFAULT 'pdf' COMMENT '模板類型：pdf/docx/html',
    is_published    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已發佈',
    published_at    DATETIME(6)     DEFAULT NULL COMMENT '發佈時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_policy_print (policy_version_id, version_no),
    CONSTRAINT fk_print_policy FOREIGN KEY (policy_version_id) REFERENCES ben_policy_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='正式申請書模板版本';

-- ============================================================================
-- 4. 映射
-- ============================================================================

-- BEN-CFG-12: 補助類型與會計科目映射
CREATE TABLE IF NOT EXISTS ben_accounting_mapping (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    policy_version_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_policy_version.id',
    voucher_type        VARCHAR(30)     NOT NULL COMMENT '傳票類型：payment/receipt',
    debit_subject_code  VARCHAR(50)     DEFAULT NULL COMMENT '借方會計科目代碼',
    credit_subject_code VARCHAR(50)     DEFAULT NULL COMMENT '貸方會計科目代碼',
    is_active           TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_policy_version_id (policy_version_id),
    CONSTRAINT fk_accounting_mapping_policy FOREIGN KEY (policy_version_id) REFERENCES ben_policy_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='補助類型與會計科目、傳票類型映射';

-- BEN-CFG-13: 補助類型與工作流映射
CREATE TABLE IF NOT EXISTS ben_workflow_mapping (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    policy_version_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_policy_version.id',
    wf_template_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_template.id',
    min_amount          DECIMAL(12, 0)  DEFAULT NULL COMMENT '適用最低金額（含）',
    max_amount          DECIMAL(12, 0)  DEFAULT NULL COMMENT '適用最高金額（不含）',
    org_unit_id         BIGINT UNSIGNED DEFAULT NULL COMMENT '適用組織（null 表示全部）',
    is_active           TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_policy_version_id (policy_version_id),
    KEY idx_wf_template_id (wf_template_id),
    CONSTRAINT fk_workflow_mapping_policy FOREIGN KEY (policy_version_id) REFERENCES ben_policy_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='補助類型、金額級距和工作流版本映射';
