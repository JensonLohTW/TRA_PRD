-- ============================================================================
-- 台鐵職工福利平台 — PAY 發款、請款與禮金模組
-- 模組：11_payment.sql
-- 說明：請款／發款批次、批次明細、狀態歷史、禮金活動、預估、名冊、結算、
--       撥款指令、撥款結果、領款確認、異議、例外處理
-- 依賴：01_sys.sql、09_ben_application.sql、04_emp.sql
-- 設計原則：批號唯一、部分失敗不回滾成功款項、已完成批次不可直接修改
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- 1. 請款與發款批次
-- ============================================================================

-- PAY-01: 批次主檔
CREATE TABLE IF NOT EXISTS pay_batch (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    batch_no        VARCHAR(50)     NOT NULL COMMENT '批號，唯一',
    batch_type      VARCHAR(30)     NOT NULL COMMENT '批次類型：general_subsidy/gift/reimbursement/settlement',
    org_unit_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '請款單位（org_unit.id）',
    welfare_shop_id BIGINT UNSIGNED DEFAULT NULL COMMENT '福利社（org_unit.id）',
    currency_code   VARCHAR(3)      NOT NULL DEFAULT 'TWD' COMMENT '幣別',
    total_count     INT             NOT NULL DEFAULT 0 COMMENT '總筆數',
    total_amount    DECIMAL(14, 0)  NOT NULL DEFAULT 0 COMMENT '總額（可被明細重算）',
    batch_status    VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '狀態：draft/verified/submitted/approved/disbursing/partially_completed/completed/reconciled/closed',
    description     VARCHAR(500)    DEFAULT NULL COMMENT '批次說明',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    approved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '核准人（iam_account.id）',
    approved_at     DATETIME(6)     DEFAULT NULL COMMENT '核准時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_batch_no (batch_no),
    KEY idx_batch_status (batch_status, created_at),
    KEY idx_org_unit_id (org_unit_id),
    KEY idx_welfare_shop_id (welfare_shop_id),
    CONSTRAINT fk_batch_org FOREIGN KEY (org_unit_id) REFERENCES org_unit(id) ON DELETE SET NULL,
    CONSTRAINT fk_batch_welfare FOREIGN KEY (welfare_shop_id) REFERENCES org_unit(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='請款或發款批次主檔';

-- PAY-02: 批次明細
CREATE TABLE IF NOT EXISTS pay_batch_item (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    batch_id        BIGINT UNSIGNED NOT NULL COMMENT '關聯 pay_batch.id',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    item_status     VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '明細狀態：pending/paid/failed/skipped',
    amount          DECIMAL(12, 0)  NOT NULL COMMENT '該筆金額',
    remark          VARCHAR(500)    DEFAULT NULL COMMENT '備註',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_batch_application (batch_id, application_id),
    KEY idx_application_id (application_id),
    CONSTRAINT fk_batch_item_batch FOREIGN KEY (batch_id) REFERENCES pay_batch(id) ON DELETE RESTRICT,
    CONSTRAINT fk_batch_item_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='批次與已核准案件關係';

-- PAY-03: 批次狀態歷史
CREATE TABLE IF NOT EXISTS pay_batch_status_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    batch_id        BIGINT UNSIGNED NOT NULL COMMENT '關聯 pay_batch.id',
    from_status     VARCHAR(30)     DEFAULT NULL COMMENT '變更前狀態',
    to_status       VARCHAR(30)     NOT NULL COMMENT '變更後狀態',
    operator_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '操作者（iam_account.id）',
    reason          VARCHAR(500)    DEFAULT NULL COMMENT '原因',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_batch_id (batch_id),
    CONSTRAINT fk_batch_status_batch FOREIGN KEY (batch_id) REFERENCES pay_batch(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='批次狀態歷史';

-- ============================================================================
-- 2. 撥款
-- ============================================================================

-- PAY-04: 撥款指令
CREATE TABLE IF NOT EXISTS pay_disbursement (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    batch_item_id   BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 pay_batch_item.id（批次內撥款）',
    application_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '直接關聯案件（非批次撥款時）',
    disbursement_type VARCHAR(30)   NOT NULL COMMENT '撥款類型：bank_transfer/cash/check',
    amount          DECIMAL(12, 0)  NOT NULL COMMENT '撥款金額',
    currency_code   VARCHAR(3)      NOT NULL DEFAULT 'TWD' COMMENT '幣別',
    recipient_name  VARCHAR(100)    NOT NULL COMMENT '受款人姓名',
    recipient_id    VARCHAR(50)     DEFAULT NULL COMMENT '受款人帳號／ID',
    disbursement_status VARCHAR(30) NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/sent/confirmed/failed/reversed',
    requested_by    BIGINT UNSIGNED DEFAULT NULL COMMENT '申請人（iam_account.id）',
    approved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '核准人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_batch_item_id (batch_item_id),
    KEY idx_application_id (application_id),
    KEY idx_disbursement_status (disbursement_status),
    CONSTRAINT fk_disbursement_batch_item FOREIGN KEY (batch_item_id) REFERENCES pay_batch_item(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='單筆撥款或發放指令';

-- PAY-05: 撥款結果
CREATE TABLE IF NOT EXISTS pay_disbursement_result (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    disbursement_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 pay_disbursement.id',
    result_status   VARCHAR(30)     NOT NULL COMMENT '結果：success/fail/pending_confirm',
    bank_reference  VARCHAR(200)    DEFAULT NULL COMMENT '銀行回執編號',
    error_code      VARCHAR(50)     DEFAULT NULL COMMENT '錯誤代碼',
    error_message   TEXT            DEFAULT NULL COMMENT '錯誤訊息',
    raw_response    TEXT            DEFAULT NULL COMMENT '銀行原始回應（不含敏感資料）',
    processed_at    DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '處理時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_disbursement_id (disbursement_id),
    KEY idx_result_status (result_status),
    CONSTRAINT fk_result_disbursement FOREIGN KEY (disbursement_id) REFERENCES pay_disbursement(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='成功、失敗和銀行回執結果';

-- ============================================================================
-- 3. 禮金三階段
-- ============================================================================

-- PAY-06: 禮金活動
CREATE TABLE IF NOT EXISTS pay_gift_campaign (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    campaign_code   VARCHAR(50)     NOT NULL COMMENT '活動代碼，唯一',
    campaign_name   VARCHAR(100)    NOT NULL COMMENT '活動名稱',
    gift_type       VARCHAR(30)     NOT NULL COMMENT '禮金類型：festival/birthday/special',
    festival_code   VARCHAR(30)     DEFAULT NULL COMMENT '節慶代碼（三節：dragon_boat/mid_autumn/chinese_new_year）',
    campaign_year   VARCHAR(10)     NOT NULL COMMENT '年度（民國年）',
    campaign_status VARCHAR(30)     NOT NULL DEFAULT 'estimated' COMMENT '狀態：estimated/distributing/settling/reimbursement_submitted/reconciled/closed',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_campaign_code (campaign_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='三節、生日等禮金活動';

-- PAY-07: 禮金預估
CREATE TABLE IF NOT EXISTS pay_gift_estimate (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    campaign_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 pay_gift_campaign.id',
    estimate_type   VARCHAR(30)     NOT NULL DEFAULT 'initial' COMMENT '預估類型：initial/adjusted/final',
    estimated_count INT             NOT NULL COMMENT '預估人數',
    unit_price      DECIMAL(10, 0)  NOT NULL COMMENT '單價（新台幣元）',
    total_amount    DECIMAL(14, 0)  NOT NULL COMMENT '預估總額',
    calculation_basis VARCHAR(500)  DEFAULT NULL COMMENT '計算依據',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_campaign_id (campaign_id),
    CONSTRAINT fk_estimate_campaign FOREIGN KEY (campaign_id) REFERENCES pay_gift_campaign(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='預估人數、單價和金額';

-- PAY-08: 禮金名冊主檔
CREATE TABLE IF NOT EXISTS pay_gift_roster (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    campaign_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 pay_gift_campaign.id',
    roster_no       VARCHAR(50)     NOT NULL COMMENT '名冊編號，唯一',
    roster_type     VARCHAR(30)     NOT NULL DEFAULT 'distribution' COMMENT '名冊類型：distribution/settlement/reimbursement',
    total_count     INT             NOT NULL DEFAULT 0 COMMENT '總人數',
    total_amount    DECIMAL(14, 0)  NOT NULL DEFAULT 0 COMMENT '總金額',
    roster_status   VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '狀態：draft/confirmed/settled',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_roster_no (roster_no),
    KEY idx_campaign_id (campaign_id),
    CONSTRAINT fk_roster_campaign FOREIGN KEY (campaign_id) REFERENCES pay_gift_campaign(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='實體簽領或核定名冊主檔';

-- PAY-09: 禮金名冊明細
CREATE TABLE IF NOT EXISTS pay_gift_roster_item (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    roster_id       BIGINT UNSIGNED NOT NULL COMMENT '關聯 pay_gift_roster.id',
    employee_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 emp_employee.id（系統職工）',
    recipient_name  VARCHAR(100)    NOT NULL COMMENT '收款人姓名（快照）',
    amount          DECIMAL(12, 0)  NOT NULL COMMENT '金額',
    is_received     TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已領取',
    received_at     DATETIME(6)     DEFAULT NULL COMMENT '領取時間（UTC）',
    remark          VARCHAR(500)    DEFAULT NULL COMMENT '備註',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_roster_id (roster_id),
    KEY idx_employee_id (employee_id),
    CONSTRAINT fk_roster_item_roster FOREIGN KEY (roster_id) REFERENCES pay_gift_roster(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='禮金名冊人員與金額';

-- PAY-10: 禮金結算
CREATE TABLE IF NOT EXISTS pay_gift_settlement (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    campaign_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 pay_gift_campaign.id',
    actual_count    INT             NOT NULL COMMENT '實際人數',
    actual_amount   DECIMAL(14, 0)  NOT NULL COMMENT '實際總額',
    unclaimed_count INT             NOT NULL DEFAULT 0 COMMENT '未領人數',
    unclaimed_amount DECIMAL(14, 0) NOT NULL DEFAULT 0 COMMENT '未領金額',
    excess_amount   DECIMAL(14, 0)  NOT NULL DEFAULT 0 COMMENT '溢領歸還金額',
    difference_amount DECIMAL(14, 0) NOT NULL DEFAULT 0 COMMENT '差額',
    settlement_status VARCHAR(30)   NOT NULL DEFAULT 'draft' COMMENT '結算狀態：draft/confirmed/reconciled',
    settled_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '結算人（iam_account.id）',
    settled_at      DATETIME(6)     DEFAULT NULL COMMENT '結算時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_campaign_settlement (campaign_id),
    CONSTRAINT fk_settlement_campaign FOREIGN KEY (campaign_id) REFERENCES pay_gift_campaign(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='實際發放、差額和歸還結算';

-- ============================================================================
-- 4. 領款確認與異議
-- ============================================================================

-- PAY-11: 領款確認
CREATE TABLE IF NOT EXISTS pay_receipt_confirmation (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    disbursement_id BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 pay_disbursement.id',
    roster_item_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 pay_gift_roster_item.id（禮金）',
    application_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ben_application.id',
    confirm_type    VARCHAR(30)     NOT NULL COMMENT '確認類型：self/agent/shop_admin',
    confirm_status  VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/confirmed/disputed',
    recipient_name  VARCHAR(100)    NOT NULL COMMENT '實際收款人姓名',
    confirmed_by    BIGINT UNSIGNED DEFAULT NULL COMMENT '確認操作者（iam_account.id）',
    confirmed_at    DATETIME(6)     DEFAULT NULL COMMENT '確認時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_disbursement_id (disbursement_id),
    KEY idx_roster_item_id (roster_item_id),
    KEY idx_application_id (application_id),
    CONSTRAINT fk_receipt_disbursement FOREIGN KEY (disbursement_id) REFERENCES pay_disbursement(id) ON DELETE SET NULL,
    CONSTRAINT fk_receipt_roster_item FOREIGN KEY (roster_item_id) REFERENCES pay_gift_roster_item(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='職工已領款或社團已入賬確認';

-- PAY-12: 撥款異議
CREATE TABLE IF NOT EXISTS pay_dispute (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    disbursement_id BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 pay_disbursement.id',
    application_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ben_application.id',
    dispute_type    VARCHAR(30)     NOT NULL COMMENT '異議類型：not_received/amount_mismatch/duplicate/other',
    dispute_amount  DECIMAL(12, 0)  DEFAULT NULL COMMENT '異議金額',
    description     TEXT            NOT NULL COMMENT '異議描述',
    evidence_file_id BIGINT UNSIGNED DEFAULT NULL COMMENT '證據文件（file_object.id）',
    dispute_status  VARCHAR(30)     NOT NULL DEFAULT 'open' COMMENT '狀態：open/investigating/resolved/dismissed',
    resolution      TEXT            DEFAULT NULL COMMENT '處理結果',
    resolved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '處理人（iam_account.id）',
    resolved_at     DATETIME(6)     DEFAULT NULL COMMENT '處理時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_disbursement_id (disbursement_id),
    KEY idx_application_id (application_id),
    KEY idx_dispute_status (dispute_status),
    CONSTRAINT fk_dispute_disbursement FOREIGN KEY (disbursement_id) REFERENCES pay_disbursement(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='未領、金額不符等異議';

-- PAY-13: 例外處理
CREATE TABLE IF NOT EXISTS pay_exception (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    batch_id        BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 pay_batch.id',
    disbursement_id BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 pay_disbursement.id',
    exception_type  VARCHAR(30)     NOT NULL COMMENT '例外類型：batch_failure/partial_failure/reversal/timeout',
    exception_status VARCHAR(30)    NOT NULL DEFAULT 'open' COMMENT '狀態：open/processing/resolved',
    description     TEXT            NOT NULL COMMENT '描述',
    resolution      TEXT            DEFAULT NULL COMMENT '處理方式',
    resolved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '處理人（iam_account.id）',
    resolved_at     DATETIME(6)     DEFAULT NULL COMMENT '處理時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_batch_id (batch_id),
    KEY idx_disbursement_id (disbursement_id),
    KEY idx_exception_status (exception_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='批次或單筆異常處理';
