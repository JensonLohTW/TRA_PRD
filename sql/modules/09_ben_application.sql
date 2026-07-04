-- ============================================================================
-- 台鐵職工福利平台 — BEN-APP 補助申請模組
-- 模組：09_ben_application.sql
-- 說明：案件主檔、表單資料、申請快照、參與方、附件、切結、狀態歷史、驗證、
--       補件要求與補交、紙本檢查點、業務鎖、滿意度回饋、封存
-- 依賴：01_sys.sql、02_file.sql、04_emp.sql、05_iam.sql、08_ben_config.sql
-- 設計原則：申請人與填表人分列、提交時產生不可變快照、補件不覆蓋原始資料
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- 1. 申請核心
-- ============================================================================

-- BEN-APP-01: 案件主檔
CREATE TABLE IF NOT EXISTS ben_application (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_no      VARCHAR(50)     NOT NULL COMMENT '對外案件編號，唯一',
    benefit_program_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_program.id',
    benefit_type_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_type.id',
    policy_version_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_policy_version.id',
    form_version_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_form_version.id',
    applicant_employee_id BIGINT UNSIGNED NOT NULL COMMENT '實際申請人（emp_employee.id）',
    entered_by_account_id BIGINT UNSIGNED NOT NULL COMMENT '系統填表人（iam_account.id，代理時與申請人不同）',
    is_proxy_entry      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否為代理填報',
    org_unit_id         BIGINT UNSIGNED DEFAULT NULL COMMENT '申請人所屬單位（org_unit.id）',
    welfare_branch_id   BIGINT UNSIGNED DEFAULT NULL COMMENT '受理福利社（org_unit.id，type=welfare_shop）',
    requested_amount    DECIMAL(12, 0)  NOT NULL DEFAULT 0 COMMENT '申請金額（新台幣元）',
    approved_amount     DECIMAL(12, 0)  DEFAULT NULL COMMENT '核定金額（新台幣元）',
    currency_code       VARCHAR(3)      NOT NULL DEFAULT 'TWD' COMMENT '幣別',
    application_year    VARCHAR(10)     NOT NULL COMMENT '申請年度（民國年，如 114）',
    submitted_at        DATETIME(6)     DEFAULT NULL COMMENT '送件時間（UTC）',
    approved_at         DATETIME(6)     DEFAULT NULL COMMENT '核准時間（UTC）',
    closed_at           DATETIME(6)     DEFAULT NULL COMMENT '結案時間（UTC）',
    current_status      VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '當前狀態：draft/submitted/waiting_physical_document/...',
    current_stage       VARCHAR(30)     DEFAULT NULL COMMENT '當前階段：application/physical_check/approval/payment/closure',
    row_version         INT             NOT NULL DEFAULT 1 COMMENT '併發控制版本號（樂觀鎖）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_application_no (application_no),
    KEY idx_applicant (applicant_employee_id, submitted_at),
    KEY idx_type_year (benefit_type_id, application_year, current_status),
    KEY idx_welfare_status (welfare_branch_id, current_status, submitted_at),
    KEY idx_entered_by (entered_by_account_id, is_proxy_entry, submitted_at),
    KEY idx_current_status (current_status),
    CONSTRAINT fk_app_program FOREIGN KEY (benefit_program_id) REFERENCES ben_program(id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_type FOREIGN KEY (benefit_type_id) REFERENCES ben_type(id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_policy FOREIGN KEY (policy_version_id) REFERENCES ben_policy_version(id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_form FOREIGN KEY (form_version_id) REFERENCES ben_form_version(id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_employee FOREIGN KEY (applicant_employee_id) REFERENCES emp_employee(id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_entered_by FOREIGN KEY (entered_by_account_id) REFERENCES iam_account(id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_org FOREIGN KEY (org_unit_id) REFERENCES org_unit(id) ON DELETE SET NULL,
    CONSTRAINT fk_app_welfare FOREIGN KEY (welfare_branch_id) REFERENCES org_unit(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='案件主檔、編號、核心金額、狀態和當前階段';

-- BEN-APP-02: 表單提交資料
CREATE TABLE IF NOT EXISTS ben_application_form_data (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    form_version_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_form_version.id',
    schema_hash         VARCHAR(64)     NOT NULL COMMENT '提交時 schema_hash（用於驗證資料結構）',
    form_data_json      JSON            NOT NULL COMMENT '表單提交資料（結構版本 v1）',
    is_current          TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否為當前有效資料',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    KEY idx_is_current (is_current),
    CONSTRAINT fk_form_data_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT,
    CONSTRAINT fk_form_data_version FOREIGN KEY (form_version_id) REFERENCES ben_form_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='表單版本和提交資料 JSON';

-- BEN-APP-03: 申請快照（提交時固化）
CREATE TABLE IF NOT EXISTS ben_application_snapshot (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    snapshot_type       VARCHAR(30)     NOT NULL COMMENT '快照類型：submission/resubmission/batch_export',
    snapshot_json       JSON            NOT NULL COMMENT '快照內容（申請人、眷屬、組織、政策等）（結構版本 v1）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    KEY idx_snapshot_type (snapshot_type),
    CONSTRAINT fk_snapshot_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='申請人、填表人、眷屬、組織和政策快照';

-- BEN-APP-04: 案件參與方
CREATE TABLE IF NOT EXISTS ben_application_party (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    party_type      VARCHAR(30)     NOT NULL COMMENT '參與方類型：beneficiary/dependent/guardian/representative',
    employee_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 emp_employee.id（職工參與方）',
    dependent_id    BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 emp_dependent.id（眷屬參與方）',
    party_name      VARCHAR(100)    NOT NULL COMMENT '參與方姓名（快照）',
    party_detail_json JSON         DEFAULT NULL COMMENT '參與方詳細（結構版本 v1）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    KEY idx_party_type (party_type),
    CONSTRAINT fk_party_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='受益人、眷屬、社團等案件參與方';

-- ============================================================================
-- 2. 附件、切結與紙本檢查點
-- ============================================================================

-- BEN-APP-05: 案件附件
CREATE TABLE IF NOT EXISTS ben_application_attachment (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    document_type   VARCHAR(50)     NOT NULL COMMENT '文件類型（對應 ben_required_document_rule.document_type_code）',
    attachment_version INT         NOT NULL DEFAULT 1 COMMENT '附件版本',
    source          VARCHAR(30)     NOT NULL DEFAULT 'applicant' COMMENT '來源：applicant/agent/supplement/system',
    is_current      TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否為當前有效版本',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    KEY idx_file_id (file_id),
    KEY idx_document_type (document_type),
    CONSTRAINT fk_attachment_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT,
    CONSTRAINT fk_attachment_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='案件附件、檔案類型和版本';

-- BEN-APP-06: 數位切結同意
CREATE TABLE IF NOT EXISTS ben_application_declaration (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    declaration_template_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_declaration_template.id',
    agreed_by       BIGINT UNSIGNED DEFAULT NULL COMMENT '同意人（iam_account.id）',
    agreed_at       DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '同意時間（UTC）',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '同意時 IP',
    request_trace   VARCHAR(64)     DEFAULT NULL COMMENT '請求追蹤號',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    CONSTRAINT fk_declaration_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT,
    CONSTRAINT fk_declaration_template FOREIGN KEY (declaration_template_id) REFERENCES ben_declaration_template(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='數位切結模板版本及同意記錄';

-- BEN-APP-07: 紙本核章檢查點
CREATE TABLE IF NOT EXISTS ben_physical_checkpoint (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    checkpoint_type VARCHAR(30)     NOT NULL COMMENT '節點類型：print/ personnel_chop / welfare_shop_received / return_to_applicant',
    checkpoint_order INT            NOT NULL COMMENT '節點順序',
    is_completed    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已完成',
    completed_by    BIGINT UNSIGNED DEFAULT NULL COMMENT '完成操作者（iam_account.id）',
    completed_at    DATETIME(6)     DEFAULT NULL COMMENT '完成時間（UTC）',
    remark          VARCHAR(500)    DEFAULT NULL COMMENT '備註',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    KEY idx_checkpoint_type (checkpoint_type),
    CONSTRAINT fk_checkpoint_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='列印、人事核章、福利社收件等紙本節點';

-- BEN-APP-08: 業務鎖
CREATE TABLE IF NOT EXISTS ben_application_lock (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    lock_type       VARCHAR(30)     NOT NULL COMMENT '鎖類型：review/batch/archive/dispute',
    lock_source     VARCHAR(50)     NOT NULL COMMENT '鎖來源（如批次 ID、審核者）',
    locked_by       BIGINT UNSIGNED DEFAULT NULL COMMENT '鎖定操作者（iam_account.id）',
    locked_at       DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '鎖定時間（UTC）',
    unlocked_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '解鎖操作者',
    unlocked_at     DATETIME(6)     DEFAULT NULL COMMENT '解鎖時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    KEY idx_lock_type (lock_type),
    CONSTRAINT fk_lock_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='審核、批次或封存造成的業務鎖';

-- ============================================================================
-- 3. 狀態歷史、驗證、補件、回饋與封存
-- ============================================================================

-- BEN-APP-09: 案件狀態歷史
CREATE TABLE IF NOT EXISTS ben_application_status_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    from_status     VARCHAR(30)     DEFAULT NULL COMMENT '變更前狀態',
    to_status       VARCHAR(30)     NOT NULL COMMENT '變更後狀態',
    action_type     VARCHAR(30)     NOT NULL COMMENT '來源動作：submit/supplement/approve/return/reject/cancel/pay/close/archive',
    operator_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '操作者（iam_account.id）',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '來源 IP',
    request_trace   VARCHAR(64)     DEFAULT NULL COMMENT '請求追蹤號',
    remark          VARCHAR(500)    DEFAULT NULL COMMENT '備註',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    KEY idx_to_status (to_status),
    KEY idx_created_at (created_at),
    CONSTRAINT fk_status_history_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='每次案件狀態轉移';

-- BEN-APP-10: 驗證結果
CREATE TABLE IF NOT EXISTS ben_application_validation (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    validation_type     VARCHAR(30)     NOT NULL COMMENT '驗證類型：required_document/eligibility/limit/duplicate/form',
    rule_code           VARCHAR(50)     DEFAULT NULL COMMENT '規則代碼',
    rule_version_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '規則版本 ID',
    result_status       VARCHAR(30)     NOT NULL COMMENT '結果：pass/fail/warning',
    evidence_json       JSON            DEFAULT NULL COMMENT '證據（結構版本 v1）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    KEY idx_validation_type (validation_type),
    CONSTRAINT fk_validation_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='必填、資格、額度和重複檢查結果';

-- BEN-APP-11: 補件要求
CREATE TABLE IF NOT EXISTS ben_supplement_request (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    request_no      VARCHAR(50)     NOT NULL COMMENT '補件要求編號，唯一',
    reason          TEXT            NOT NULL COMMENT '補件原因',
    deadline_date   DATE            NOT NULL COMMENT '補件截止日期',
    requested_by    BIGINT UNSIGNED DEFAULT NULL COMMENT '要求者（iam_account.id）',
    request_status  VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/submitted/overdue/cancelled',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_supplement_request_no (request_no),
    KEY idx_application_id (application_id),
    KEY idx_request_status (request_status),
    CONSTRAINT fk_supplement_request_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='補件要求、期限和原因';

-- BEN-APP-12: 補件補交批次
CREATE TABLE IF NOT EXISTS ben_supplement_submission (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    supplement_request_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_supplement_request.id',
    submission_no       VARCHAR(50)     NOT NULL COMMENT '補交編號，唯一',
    submitted_by        BIGINT UNSIGNED DEFAULT NULL COMMENT '補交者（iam_account.id）',
    submitted_at        DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '補交時間（UTC）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_supplement_submission_no (submission_no),
    KEY idx_supplement_request_id (supplement_request_id),
    CONSTRAINT fk_supplement_submission_request FOREIGN KEY (supplement_request_id) REFERENCES ben_supplement_request(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='補件批次及補交資料';

-- BEN-APP-13: 服務回饋
CREATE TABLE IF NOT EXISTS ben_service_feedback (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    rating          TINYINT UNSIGNED NOT NULL COMMENT '星等評分（1-5）',
    comment         TEXT            DEFAULT NULL COMMENT '意見文字',
    submitted_by    BIGINT UNSIGNED DEFAULT NULL COMMENT '提交者（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_application_id (application_id),
    CONSTRAINT fk_feedback_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='領款後的星等與意見';

-- BEN-APP-14: 結案封存
CREATE TABLE IF NOT EXISTS ben_application_archive (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    archive_batch_no    VARCHAR(50)     NOT NULL COMMENT '封存批號',
    archive_checksum    VARCHAR(64)     DEFAULT NULL COMMENT '封存資料 SHA-256 摘要',
    archived_by         BIGINT UNSIGNED DEFAULT NULL COMMENT '封存操作者（iam_account.id）',
    archived_at         DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '封存時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_archive_application (application_id),
    KEY idx_archive_batch_no (archive_batch_no),
    CONSTRAINT fk_archive_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='結案封存批次和校驗摘要';
