-- ============================================================================
-- 台鐵職工福利平台 — FIN 財務文件模組
-- 模組：12_finance.sql
-- 說明：會計科目、文件模板與版本、報銷單、核定名冊、傳票、分錄、來源關係、
--       文件版本歷史、文件輸出、對賬任務與差異
-- 依賴：01_sys.sql、02_file.sql、11_payment.sql
-- 設計原則：所有金額使用 DECIMAL、初稿／校對稿／終稿不覆蓋、最終財務文件不可修改
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- 1. 會計基礎與模板
-- ============================================================================

-- FIN-01: 會計科目
CREATE TABLE IF NOT EXISTS fin_accounting_subject (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    subject_code    VARCHAR(50)     NOT NULL COMMENT '科目代碼，唯一',
    subject_name    VARCHAR(100)    NOT NULL COMMENT '科目名稱',
    subject_type    VARCHAR(30)     NOT NULL COMMENT '科目類別：asset/liability/equity/revenue/expense',
    parent_id       BIGINT UNSIGNED DEFAULT NULL COMMENT '上層科目（自我參照）',
    level           INT             NOT NULL DEFAULT 1 COMMENT '科目層級',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_subject_code (subject_code),
    KEY idx_parent_id (parent_id),
    CONSTRAINT fk_subject_parent FOREIGN KEY (parent_id) REFERENCES fin_accounting_subject(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='會計科目主檔';

-- FIN-02: 財務文件模板
CREATE TABLE IF NOT EXISTS fin_document_template (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    template_code   VARCHAR(50)     NOT NULL COMMENT '模板代碼，唯一',
    template_name   VARCHAR(100)    NOT NULL COMMENT '模板名稱',
    document_type   VARCHAR(30)     NOT NULL COMMENT '文件類型：voucher/reimbursement/roster',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_fin_template_code (template_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='傳票、報銷單和名冊模板';

-- FIN-03: 模板版本
CREATE TABLE IF NOT EXISTS fin_document_template_version (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    template_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 fin_document_template.id',
    version_no      INT             NOT NULL COMMENT '版本號',
    render_rule_json JSON           DEFAULT NULL COMMENT '渲染規則（結構版本 v1）',
    is_published    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已發佈（發佈後不可覆蓋）',
    published_at    DATETIME(6)     DEFAULT NULL COMMENT '發佈時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_fin_template_version (template_id, version_no),
    CONSTRAINT fk_fin_template_version_template FOREIGN KEY (template_id) REFERENCES fin_document_template(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='模板版本和渲染規則';

-- ============================================================================
-- 2. 報銷單與核定名冊
-- ============================================================================

-- FIN-04: 報銷單主檔
CREATE TABLE IF NOT EXISTS fin_reimbursement_claim (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    claim_no        VARCHAR(50)     NOT NULL COMMENT '報銷單編號，唯一',
    batch_id        BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 pay_batch.id',
    template_version_id BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 fin_document_template_version.id',
    org_unit_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '請款單位',
    total_amount    DECIMAL(14, 0)  NOT NULL DEFAULT 0 COMMENT '報銷總額',
    currency_code   VARCHAR(3)      NOT NULL DEFAULT 'TWD' COMMENT '幣別',
    claim_status    VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '狀態：draft/submitted/approved/rejected',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_claim_no (claim_no),
    KEY idx_batch_id (batch_id),
    KEY idx_claim_status (claim_status),
    CONSTRAINT fk_claim_batch FOREIGN KEY (batch_id) REFERENCES pay_batch(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='代請款報銷單主檔';

-- FIN-05: 報銷單明細
CREATE TABLE IF NOT EXISTS fin_reimbursement_item (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    claim_id        BIGINT UNSIGNED NOT NULL COMMENT '關聯 fin_reimbursement_claim.id',
    application_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ben_application.id',
    batch_item_id   BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 pay_batch_item.id',
    amount          DECIMAL(12, 0)  NOT NULL COMMENT '金額',
    description     VARCHAR(500)    DEFAULT NULL COMMENT '說明',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_claim_id (claim_id),
    KEY idx_application_id (application_id),
    KEY idx_batch_item_id (batch_item_id),
    CONSTRAINT fk_reimb_item_claim FOREIGN KEY (claim_id) REFERENCES fin_reimbursement_claim(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='報銷單案件明細';

-- FIN-06: 核定名冊主檔
CREATE TABLE IF NOT EXISTS fin_approval_roster (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    roster_no       VARCHAR(50)     NOT NULL COMMENT '名冊編號，唯一',
    source_batch_id BIGINT UNSIGNED DEFAULT NULL COMMENT '來源批次（pay_batch.id）',
    template_version_id BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 fin_document_template_version.id',
    total_count     INT             NOT NULL DEFAULT 0 COMMENT '總人數',
    total_amount    DECIMAL(14, 0)  NOT NULL DEFAULT 0 COMMENT '總金額',
    currency_code   VARCHAR(3)      NOT NULL DEFAULT 'TWD' COMMENT '幣別',
    roster_status   VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '狀態：draft/reviewed/confirmed',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_approval_roster_no (roster_no),
    KEY idx_source_batch_id (source_batch_id),
    CONSTRAINT fk_roster_batch FOREIGN KEY (source_batch_id) REFERENCES pay_batch(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='核定名冊主檔';

-- FIN-07: 核定名冊明細
CREATE TABLE IF NOT EXISTS fin_approval_roster_item (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    roster_id       BIGINT UNSIGNED NOT NULL COMMENT '關聯 fin_approval_roster.id',
    application_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ben_application.id',
    employee_no     VARCHAR(20)     NOT NULL COMMENT '員編（快照）',
    employee_name   VARCHAR(100)    NOT NULL COMMENT '姓名（快照）',
    benefit_type_name VARCHAR(100)  NOT NULL COMMENT '補助類型名稱（快照）',
    amount          DECIMAL(12, 0)  NOT NULL COMMENT '核定金額',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_roster_id (roster_id),
    KEY idx_application_id (application_id),
    CONSTRAINT fk_approval_roster_item_roster FOREIGN KEY (roster_id) REFERENCES fin_approval_roster(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='核定名冊人員與金額';

-- ============================================================================
-- 3. 傳票
-- ============================================================================

-- FIN-08: 傳票主檔
CREATE TABLE IF NOT EXISTS fin_voucher (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    voucher_no      VARCHAR(50)     NOT NULL COMMENT '傳票編號，唯一',
    voucher_type    VARCHAR(30)     NOT NULL COMMENT '傳票類型：payment/receipt/transfer/adjustment',
    voucher_date    DATE            NOT NULL COMMENT '傳票日期',
    template_version_id BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 fin_document_template_version.id',
    total_debit     DECIMAL(14, 0)  NOT NULL DEFAULT 0 COMMENT '借方總額',
    total_credit    DECIMAL(14, 0)  NOT NULL DEFAULT 0 COMMENT '貸方總額',
    currency_code   VARCHAR(3)      NOT NULL DEFAULT 'TWD' COMMENT '幣別',
    voucher_status  VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '狀態：draft/reviewed/final/reversed',
    description     VARCHAR(500)    DEFAULT NULL COMMENT '摘要',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_voucher_no (voucher_no),
    KEY idx_voucher_type (voucher_type),
    KEY idx_voucher_date (voucher_date),
    KEY idx_voucher_status (voucher_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='收入或支出傳票主檔';

-- FIN-09: 傳票分錄
CREATE TABLE IF NOT EXISTS fin_voucher_line (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    voucher_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 fin_voucher.id',
    line_order      INT             NOT NULL COMMENT '分錄順序',
    direction       VARCHAR(10)     NOT NULL COMMENT '方向：debit/credit',
    subject_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 fin_accounting_subject.id',
    amount          DECIMAL(14, 0)  NOT NULL COMMENT '金額',
    summary         VARCHAR(200)    DEFAULT NULL COMMENT '摘要',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_voucher_id (voucher_id),
    KEY idx_subject_id (subject_id),
    CONSTRAINT fk_voucher_line_voucher FOREIGN KEY (voucher_id) REFERENCES fin_voucher(id) ON DELETE RESTRICT,
    CONSTRAINT fk_voucher_line_subject FOREIGN KEY (subject_id) REFERENCES fin_accounting_subject(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='借貸方、科目和金額明細';

-- FIN-10: 傳票來源關係
CREATE TABLE IF NOT EXISTS fin_voucher_source_link (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    voucher_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 fin_voucher.id',
    source_type     VARCHAR(30)     NOT NULL COMMENT '來源類型：batch/gift_settlement/reimbursement/roster',
    source_id       BIGINT UNSIGNED NOT NULL COMMENT '來源對象 ID',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_voucher_id (voucher_id),
    KEY idx_source (source_type, source_id),
    CONSTRAINT fk_voucher_source_voucher FOREIGN KEY (voucher_id) REFERENCES fin_voucher(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='傳票與批次、案件、結算的來源關係';

-- ============================================================================
-- 4. 文件版本與輸出
-- ============================================================================

-- FIN-11: 文件版本歷史
CREATE TABLE IF NOT EXISTS fin_document_version (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    document_type   VARCHAR(30)     NOT NULL COMMENT '文件類型：voucher/reimbursement/roster',
    document_id     BIGINT UNSIGNED NOT NULL COMMENT '文件 ID',
    version_no      INT             NOT NULL COMMENT '版本號',
    version_label   VARCHAR(30)     NOT NULL COMMENT '版本標籤：draft/reviewed/final/corrected',
    content_json    JSON            DEFAULT NULL COMMENT '版本內容（結構版本 v1）',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_document_version (document_type, document_id, version_no),
    KEY idx_document (document_type, document_id),
    CONSTRAINT fk_doc_version_voucher FOREIGN KEY (document_id) REFERENCES fin_voucher(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='初稿、校對稿和確認稿';

-- FIN-12: 文件輸出
CREATE TABLE IF NOT EXISTS fin_document_output (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    document_version_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 fin_document_version.id',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    output_format   VARCHAR(30)     NOT NULL COMMENT '輸出格式：pdf/docx/xlsx/html',
    is_final        TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否為最終版本',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_document_version_id (document_version_id),
    KEY idx_file_id (file_id),
    CONSTRAINT fk_output_version FOREIGN KEY (document_version_id) REFERENCES fin_document_version(id) ON DELETE RESTRICT,
    CONSTRAINT fk_output_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='PDF、可編輯檔等輸出檔案';

-- ============================================================================
-- 5. 對賬
-- ============================================================================

-- FIN-13: 對賬任務
CREATE TABLE IF NOT EXISTS fin_reconciliation_run (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    run_no          VARCHAR(50)     NOT NULL COMMENT '對賬任務編號，唯一',
    reconciliation_type VARCHAR(30) NOT NULL COMMENT '對賬類型：batch_voucher/batch_roster/roster_voucher/full',
    source_batch_id BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 pay_batch.id',
    start_date      DATE            DEFAULT NULL COMMENT '對賬起日',
    end_date        DATE            DEFAULT NULL COMMENT '對賬迄日',
    run_status      VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/running/completed/failed',
    total_checked   INT             NOT NULL DEFAULT 0 COMMENT '檢查總筆數',
    difference_count INT            NOT NULL DEFAULT 0 COMMENT '差異筆數',
    run_by          BIGINT UNSIGNED DEFAULT NULL COMMENT '執行者（iam_account.id）',
    started_at      DATETIME(6)     DEFAULT NULL COMMENT '開始時間（UTC）',
    finished_at     DATETIME(6)     DEFAULT NULL COMMENT '結束時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_recon_run_no (run_no),
    KEY idx_source_batch_id (source_batch_id),
    KEY idx_run_status (run_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='傳票、名冊、批次和案件對賬任務';

-- FIN-14: 對賬差異
CREATE TABLE IF NOT EXISTS fin_reconciliation_difference (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    reconciliation_run_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 fin_reconciliation_run.id',
    object_type     VARCHAR(30)     NOT NULL COMMENT '對象類型：batch/reimbursement/roster/voucher',
    object_id       BIGINT UNSIGNED NOT NULL COMMENT '對象 ID',
    field_name      VARCHAR(50)     NOT NULL COMMENT '差異欄位',
    expected_value  VARCHAR(255)    NOT NULL COMMENT '預期值',
    actual_value    VARCHAR(255)    NOT NULL COMMENT '實際值',
    difference_type VARCHAR(30)     NOT NULL DEFAULT 'amount' COMMENT '差異類型：amount/count/missing/extra',
    severity        VARCHAR(30)     NOT NULL DEFAULT 'medium' COMMENT '嚴重程度：low/medium/high/critical',
    resolution_status VARCHAR(30)   NOT NULL DEFAULT 'unresolved' COMMENT '處理狀態：unresolved/investigating/resolved/dismissed',
    resolution      TEXT            DEFAULT NULL COMMENT '處理說明',
    resolved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '處理人（iam_account.id）',
    resolved_at     DATETIME(6)     DEFAULT NULL COMMENT '處理時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_reconciliation_run_id (reconciliation_run_id),
    KEY idx_resolution_status (resolution_status),
    CONSTRAINT fk_recon_diff_run FOREIGN KEY (reconciliation_run_id) REFERENCES fin_reconciliation_run(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='對賬差異和處理結果';
