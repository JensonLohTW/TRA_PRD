-- ============================================================================
-- 台鐵職工福利平台 — EMP 職工與眷屬模組
-- 模組：04_emp.sql
-- 說明：職工主檔、聯絡資料、地址、任職歷史、福利社歸屬、眷屬、教育、扣繳、資格快照、
--       任職記錄與業務範圍（因 FK 依賴 emp_employee，從 ORG 模組移入）
-- 依賴：01_sys.sql、03_org.sql
-- ============================================================================

USE tra_welfare_test;

-- EMP-01: 職工主檔
CREATE TABLE IF NOT EXISTS emp_employee (
    id                      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_no             VARCHAR(20)     NOT NULL COMMENT '員編（業務唯一，非主鍵）',
    id_card_hash            VARCHAR(64)     DEFAULT NULL COMMENT '身份證字號盲索引（HMAC，用於精確比對）',
    id_card_encrypted       TEXT            DEFAULT NULL COMMENT '身份證字號密文（應用層加密）',
    name                    VARCHAR(100)    NOT NULL COMMENT '姓名',
    name_romanized          VARCHAR(100)    DEFAULT NULL COMMENT '姓名羅馬拼音',
    gender                  VARCHAR(10)     DEFAULT NULL COMMENT '性別',
    birth_date              DATE            DEFAULT NULL COMMENT '出生日期',
    employment_status       VARCHAR(30)     NOT NULL DEFAULT 'active' COMMENT '在職狀態：active/suspended/resigned/retired/deceased',
    hire_date               DATE            DEFAULT NULL COMMENT '到職日期',
    resignation_date        DATE            DEFAULT NULL COMMENT '離職日期',
    primary_org_unit_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '主要歸屬單位（org_unit.id）',
    primary_welfare_shop_id BIGINT UNSIGNED DEFAULT NULL COMMENT '主要領款福利社（org_unit.id，type=welfare_shop）',
    bank_account_hash       VARCHAR(64)     DEFAULT NULL COMMENT '銀行帳號盲索引',
    bank_account_encrypted  TEXT            DEFAULT NULL COMMENT '銀行帳號密文（應用層加密）',
    is_active               TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '資料是否有效',
    created_at              DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at              DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_employee_no (employee_no),
    KEY idx_id_card_hash (id_card_hash),
    KEY idx_bank_account_hash (bank_account_hash),
    KEY idx_employment_status (employment_status),
    KEY idx_primary_org (primary_org_unit_id),
    KEY idx_primary_welfare (primary_welfare_shop_id),
    KEY idx_name (name),
    CONSTRAINT fk_employee_org FOREIGN KEY (primary_org_unit_id) REFERENCES org_unit(id) ON DELETE SET NULL,
    CONSTRAINT fk_employee_welfare FOREIGN KEY (primary_welfare_shop_id) REFERENCES org_unit(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='職工主檔、員編、在職狀態和主要歸屬';

-- EMP-02: 職工聯絡資料
CREATE TABLE IF NOT EXISTS emp_contact (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    contact_type    VARCHAR(30)     NOT NULL COMMENT '聯絡類型：phone/mobile/email/emergency_contact',
    contact_value   VARCHAR(200)    NOT NULL COMMENT '聯絡值',
    is_primary      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否主要聯絡方式',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_employee_id (employee_id),
    KEY idx_contact_type (contact_type),
    CONSTRAINT fk_contact_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='電話、Email 等聯絡資料';

-- EMP-03: 職工通訊地址
CREATE TABLE IF NOT EXISTS emp_address (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    address_type    VARCHAR(30)     NOT NULL DEFAULT 'residence' COMMENT '地址類型：residence/mailing/registered',
    address_line1   VARCHAR(200)    NOT NULL COMMENT '地址第一行',
    address_line2   VARCHAR(200)    DEFAULT NULL COMMENT '地址第二行',
    city            VARCHAR(100)    DEFAULT NULL COMMENT '城市',
    district        VARCHAR(100)    DEFAULT NULL COMMENT '區',
    postal_code     VARCHAR(10)     DEFAULT NULL COMMENT '郵遞區號',
    is_primary      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否預設地址',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_employee_id (employee_id),
    KEY idx_address_type (address_type),
    CONSTRAINT fk_address_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通訊地址及有效期間';

-- EMP-04: 任職歷史
CREATE TABLE IF NOT EXISTS emp_employment_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    org_unit_id     BIGINT UNSIGNED NOT NULL COMMENT '單位',
    job_title       VARCHAR(100)    DEFAULT NULL COMMENT '職稱',
    position_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 org_position.id',
    employment_type VARCHAR(30)     DEFAULT NULL COMMENT '任用類別',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期（null 表示現職）',
    change_reason   VARCHAR(200)    DEFAULT NULL COMMENT '變更原因',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_employee_id (employee_id),
    KEY idx_org_unit_id (org_unit_id),
    KEY idx_effective_date (effective_date),
    CONSTRAINT fk_emp_history_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT,
    CONSTRAINT fk_emp_history_org FOREIGN KEY (org_unit_id) REFERENCES org_unit(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='單位、職稱、到離職等歷史';

-- EMP-05: 福利社歸屬歷史
CREATE TABLE IF NOT EXISTS emp_welfare_branch_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    welfare_shop_id BIGINT UNSIGNED NOT NULL COMMENT '福利社（org_unit.id，type=welfare_shop）',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期',
    change_reason   VARCHAR(200)    DEFAULT NULL COMMENT '變更原因',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_employee_id (employee_id),
    KEY idx_welfare_shop_id (welfare_shop_id),
    KEY idx_effective_date (effective_date),
    CONSTRAINT fk_welfare_hist_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT,
    CONSTRAINT fk_welfare_hist_shop FOREIGN KEY (welfare_shop_id) REFERENCES org_unit(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='領款福利社歸屬歷史';

-- EMP-06: 眷屬主檔
CREATE TABLE IF NOT EXISTS emp_dependent (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    name            VARCHAR(100)    NOT NULL COMMENT '姓名',
    relationship    VARCHAR(30)     NOT NULL COMMENT '關係：spouse/child/parent/sibling/other',
    id_card_hash    VARCHAR(64)     DEFAULT NULL COMMENT '身份證字號盲索引',
    id_card_encrypted TEXT         DEFAULT NULL COMMENT '身份證字號密文',
    birth_date      DATE            DEFAULT NULL COMMENT '出生日期',
    gender          VARCHAR(10)     DEFAULT NULL COMMENT '性別',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否有效',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_employee_id (employee_id),
    KEY idx_relationship (relationship),
    CONSTRAINT fk_dependent_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='配偶、子女等眷屬主檔';

-- EMP-07: 子女教育資料
CREATE TABLE IF NOT EXISTS emp_dependent_education (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    dependent_id    BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_dependent.id',
    school_name     VARCHAR(200)    NOT NULL COMMENT '學校名稱',
    education_level VARCHAR(30)     NOT NULL COMMENT '學制：preschool/elementary/junior_high/senior_high/college/university/graduate',
    grade           VARCHAR(30)     DEFAULT NULL COMMENT '年級／學年',
    academic_year   VARCHAR(20)     NOT NULL COMMENT '學年度（如 114）',
    is_current      TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否為目前學籍',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_dependent_id (dependent_id),
    KEY idx_academic_year (academic_year),
    CONSTRAINT fk_edu_dependent FOREIGN KEY (dependent_id) REFERENCES emp_dependent(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='子女學校、學制和學年資料';

-- EMP-08: 福利金扣繳歷史
CREATE TABLE IF NOT EXISTS emp_contribution_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    contribution_year VARCHAR(10)   NOT NULL COMMENT '扣繳年度',
    contribution_month VARCHAR(10)  NOT NULL COMMENT '扣繳月份',
    amount          DECIMAL(12, 0)  NOT NULL COMMENT '扣繳金額（新台幣元）',
    deduction_status VARCHAR(30)    NOT NULL DEFAULT 'deducted' COMMENT '狀態：deducted/waived/stopped',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_employee_id (employee_id),
    KEY idx_contribution_year (contribution_year),
    UNIQUE KEY uk_employee_month (employee_id, contribution_year, contribution_month),
    CONSTRAINT fk_contribution_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='福利金扣繳期間和狀態';

-- EMP-09: 資格快照
CREATE TABLE IF NOT EXISTS emp_eligibility_snapshot (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    snapshot_date   DATE            NOT NULL COMMENT '快照日期',
    snapshot_type   VARCHAR(30)     NOT NULL COMMENT '快照類型：application/submission/benefit_check',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否有效',
    tenure_years    INT             DEFAULT NULL COMMENT '年資（年）',
    contribution_months INT         DEFAULT NULL COMMENT '扣繳月數',
    eligibility_json JSON           DEFAULT NULL COMMENT '資格計算詳細（結構版本 v1）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_employee_id (employee_id),
    KEY idx_snapshot_date (snapshot_date),
    KEY idx_snapshot_type (snapshot_type),
    CONSTRAINT fk_eligibility_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='指定時點的資格計算快照';

-- EMP-10: 資料變更差異
CREATE TABLE IF NOT EXISTS emp_profile_change (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    change_type     VARCHAR(30)     NOT NULL COMMENT '變更類型：personal/contact/address/dependent/employment',
    before_json     JSON            DEFAULT NULL COMMENT '變更前（結構版本 v1）',
    after_json      JSON            NOT NULL COMMENT '變更後（結構版本 v1）',
    changed_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '變更者（iam_account.id）',
    change_reason   VARCHAR(500)    DEFAULT NULL COMMENT '變更原因',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_employee_id (employee_id),
    KEY idx_change_type (change_type),
    KEY idx_created_at (created_at),
    CONSTRAINT fk_profile_change_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='職工資料修改前後差異';

-- EMP-11: 資料導入關聯
CREATE TABLE IF NOT EXISTS emp_data_import_link (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    import_job_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 sys_import_job.id',
    source_row      INT             DEFAULT NULL COMMENT '來源檔案行號',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_emp_import (employee_id, import_job_id),
    KEY idx_import_job_id (import_job_id),
    CONSTRAINT fk_import_link_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT,
    CONSTRAINT fk_import_link_job FOREIGN KEY (import_job_id) REFERENCES sys_import_job(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='職工資料與導入任務關聯';

-- ============================================================================
-- 任職記錄（原 ORG 模組，因 FK 依賴 emp_employee 移入此處）
-- ============================================================================

-- EMP-12: 任職記錄
CREATE TABLE IF NOT EXISTS org_assignment (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    employee_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 emp_employee.id',
    org_unit_id     BIGINT UNSIGNED NOT NULL COMMENT '任職單位（org_unit.id）',
    position_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 org_position.id',
    job_title       VARCHAR(100)    DEFAULT NULL COMMENT '職稱（自由文字）',
    is_primary      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否為主歸屬',
    is_manager      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否為管理職務',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期（null 表示現任）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_employee_id (employee_id),
    KEY idx_org_unit_id (org_unit_id),
    KEY idx_position_id (position_id),
    KEY idx_is_primary (is_primary),
    KEY idx_effective (effective_date, expiration_date),
    CONSTRAINT fk_assignment_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT,
    CONSTRAINT fk_assignment_org FOREIGN KEY (org_unit_id) REFERENCES org_unit(id) ON DELETE RESTRICT,
    CONSTRAINT fk_assignment_position FOREIGN KEY (position_id) REFERENCES org_position(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='職工任職和管理職務';

-- EMP-13: 任職業務範圍
CREATE TABLE IF NOT EXISTS org_assignment_scope (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    assignment_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 org_assignment.id',
    scope_type      VARCHAR(30)     NOT NULL COMMENT '範圍類型：business_category/org_unit/welfare_shop',
    scope_id        BIGINT UNSIGNED NOT NULL COMMENT '範圍對象 ID',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_assignment_scope (assignment_id, scope_type, scope_id),
    KEY idx_scope_type (scope_type, scope_id),
    CONSTRAINT fk_scope_assignment FOREIGN KEY (assignment_id) REFERENCES org_assignment(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任職對應的業務類別或管轄單位';
