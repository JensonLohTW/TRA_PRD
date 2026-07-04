-- ============================================================================
-- 台鐵職工福利平台 — MCH 特約商店模組
-- 模組：14_merchant.sql
-- 說明：商店分類、主檔、分店、聯絡人、合約、合約文件、優惠、優惠媒體、
--       變更申請與工作流橋接、狀態歷史、到期提醒、推播偏好、地理圍欄事件、冷卻
-- 依賴：01_sys.sql、02_file.sql、10_workflow.sql
-- ============================================================================

USE tra_welfare_test;

-- MCH-01: 商店分類
CREATE TABLE IF NOT EXISTS mch_category (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    category_code   VARCHAR(30)     NOT NULL COMMENT '分類代碼，唯一',
    category_name   VARCHAR(100)    NOT NULL COMMENT '分類名稱',
    parent_id       BIGINT UNSIGNED DEFAULT NULL COMMENT '上層分類（自我參照）',
    sort_order      INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_category_code (category_code),
    KEY idx_parent_id (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='餐飲、住宿、購物、生活服務等類別';

-- MCH-02: 商店主檔
CREATE TABLE IF NOT EXISTS mch_merchant (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    merchant_code   VARCHAR(50)     NOT NULL COMMENT '商店代碼，唯一',
    merchant_name   VARCHAR(200)    NOT NULL COMMENT '商店名稱（正規化名稱用於查重）',
    unified_business_no VARCHAR(20) DEFAULT NULL COMMENT '統一編號',
    merchant_status VARCHAR(30)     NOT NULL DEFAULT 'active' COMMENT '狀態：active/suspended/disabled/pending_review',
    category_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 mch_category.id',
    description     TEXT            DEFAULT NULL COMMENT '簡介（不含內部備註）',
    phone           VARCHAR(30)     DEFAULT NULL COMMENT '公開聯絡電話',
    website         VARCHAR(500)    DEFAULT NULL COMMENT '官方網站',
    is_published    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已發佈至職工端',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_merchant_code (merchant_code),
    KEY idx_unified_business_no (unified_business_no),
    KEY idx_merchant_status (merchant_status),
    KEY idx_category_id (category_id),
    KEY idx_is_published (is_published)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商店或廠商主檔';

-- MCH-03: 分店
CREATE TABLE IF NOT EXISTS mch_branch (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    merchant_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_merchant.id',
    branch_name     VARCHAR(200)    NOT NULL COMMENT '分店名稱',
    address         VARCHAR(500)    DEFAULT NULL COMMENT '地址',
    latitude        DECIMAL(10, 7)  DEFAULT NULL COMMENT '緯度',
    longitude       DECIMAL(10, 7)  DEFAULT NULL COMMENT '經度',
    phone           VARCHAR(30)     DEFAULT NULL COMMENT '電話',
    business_hours  VARCHAR(200)    DEFAULT NULL COMMENT '營業時間',
    branch_status   VARCHAR(30)     NOT NULL DEFAULT 'active' COMMENT '狀態：active/suspended/closed',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_merchant_id (merchant_id),
    KEY idx_branch_status (branch_status),
    KEY idx_location (latitude, longitude),
    CONSTRAINT fk_branch_merchant FOREIGN KEY (merchant_id) REFERENCES mch_merchant(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='分店、地址、經緯度和營業狀態';

-- MCH-04: 內部聯絡窗口
CREATE TABLE IF NOT EXISTS mch_contact (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    merchant_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_merchant.id',
    contact_name    VARCHAR(100)    NOT NULL COMMENT '聯絡人姓名',
    phone           VARCHAR(30)     DEFAULT NULL COMMENT '電話',
    email           VARCHAR(200)    DEFAULT NULL COMMENT 'Email',
    position        VARCHAR(100)    DEFAULT NULL COMMENT '職稱',
    is_primary      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否主要聯絡人',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否有效',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_merchant_id (merchant_id),
    CONSTRAINT fk_contact_merchant FOREIGN KEY (merchant_id) REFERENCES mch_merchant(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='後臺聯絡窗口';

-- MCH-05: 合約
CREATE TABLE IF NOT EXISTS mch_contract (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    merchant_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_merchant.id',
    contract_no     VARCHAR(50)     NOT NULL COMMENT '合約編號，唯一',
    contract_name   VARCHAR(200)    NOT NULL COMMENT '合約名稱',
    contract_type   VARCHAR(30)     NOT NULL DEFAULT 'cooperation' COMMENT '合約類型：cooperation/lease/framework',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期',
    contract_status VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '狀態：draft/active/expired/terminated/renewed',
    internal_note   TEXT            DEFAULT NULL COMMENT '內部備註（不進入公開查詢）',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_contract_no (contract_no),
    KEY idx_merchant_id (merchant_id),
    KEY idx_contract_status (contract_status),
    KEY idx_effective_date (effective_date, expiration_date),
    CONSTRAINT fk_contract_merchant FOREIGN KEY (merchant_id) REFERENCES mch_merchant(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='合約期間、狀態和內部備註';

-- MCH-06: 合約文件
CREATE TABLE IF NOT EXISTS mch_contract_document (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    contract_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_contract.id',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    document_type   VARCHAR(30)     NOT NULL COMMENT '文件類型：contract_original/amendment/appendix',
    version_no      INT             NOT NULL DEFAULT 1 COMMENT '版本號',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_contract_id (contract_id),
    KEY idx_file_id (file_id),
    CONSTRAINT fk_contract_doc_contract FOREIGN KEY (contract_id) REFERENCES mch_contract(id) ON DELETE RESTRICT,
    CONSTRAINT fk_contract_doc_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='合約正本與文件關聯';

-- MCH-07: 優惠內容
CREATE TABLE IF NOT EXISTS mch_offer (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    merchant_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_merchant.id',
    branch_id       BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 mch_branch.id（null 表示全部分店）',
    offer_title     VARCHAR(200)    NOT NULL COMMENT '優惠標題',
    offer_type      VARCHAR(30)     NOT NULL DEFAULT 'discount' COMMENT '優惠類型：discount/coupon/gift/points',
    terms_json      JSON            DEFAULT NULL COMMENT '適用條件（結構版本 v1）',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期',
    publish_status  VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '發佈狀態：draft/published/expired/withdrawn',
    is_featured     TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否精選',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_merchant_id (merchant_id),
    KEY idx_branch_id (branch_id),
    KEY idx_publish_status (publish_status, effective_date, expiration_date),
    CONSTRAINT fk_offer_merchant FOREIGN KEY (merchant_id) REFERENCES mch_merchant(id) ON DELETE RESTRICT,
    CONSTRAINT fk_offer_branch FOREIGN KEY (branch_id) REFERENCES mch_branch(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='優惠內容、效期和發佈狀態';

-- MCH-08: 優惠媒體
CREATE TABLE IF NOT EXISTS mch_offer_media (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    offer_id        BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_offer.id',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    media_type      VARCHAR(30)     NOT NULL COMMENT '媒體類型：logo/storefront/promotion',
    sort_order      INT             NOT NULL DEFAULT 0 COMMENT '排序',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_offer_id (offer_id),
    KEY idx_file_id (file_id),
    CONSTRAINT fk_offer_media_offer FOREIGN KEY (offer_id) REFERENCES mch_offer(id) ON DELETE RESTRICT,
    CONSTRAINT fk_offer_media_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Logo、門面和宣傳圖片';

-- MCH-09: 商店異動申請
CREATE TABLE IF NOT EXISTS mch_change_request (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    merchant_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_merchant.id',
    change_type     VARCHAR(30)     NOT NULL COMMENT '異動類型：create/update/suspend/reactivate/terminate',
    proposed_json   JSON            NOT NULL COMMENT '提議變更內容（結構版本 v1）',
    reason          TEXT            NOT NULL COMMENT '原因',
    request_status  VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '狀態：draft/pending/approved/rejected/cancelled',
    requested_by    BIGINT UNSIGNED NOT NULL COMMENT '申請人（iam_account.id）',
    approved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '核准人（iam_account.id）',
    approved_at     DATETIME(6)     DEFAULT NULL COMMENT '核准時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_merchant_id (merchant_id),
    KEY idx_request_status (request_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='新增、修改、下架申請';

-- MCH-10: 商店異動-工作流橋接
CREATE TABLE IF NOT EXISTS mch_change_workflow (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    change_request_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_change_request.id',
    wf_instance_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_instance.id',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_mch_change_wf (change_request_id, wf_instance_id),
    KEY idx_wf_instance_id (wf_instance_id),
    CONSTRAINT fk_mch_change_wf_request FOREIGN KEY (change_request_id) REFERENCES mch_change_request(id) ON DELETE RESTRICT,
    CONSTRAINT fk_mch_change_wf_instance FOREIGN KEY (wf_instance_id) REFERENCES wf_instance(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商店異動與審批實例關聯';

-- MCH-11: 狀態歷史
CREATE TABLE IF NOT EXISTS mch_status_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    merchant_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_merchant.id',
    from_status     VARCHAR(30)     DEFAULT NULL COMMENT '變更前狀態',
    to_status       VARCHAR(30)     NOT NULL COMMENT '變更後狀態',
    change_reason   VARCHAR(500)    DEFAULT NULL COMMENT '變更原因',
    changed_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '操作者（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_merchant_id (merchant_id),
    CONSTRAINT fk_mch_status_merchant FOREIGN KEY (merchant_id) REFERENCES mch_merchant(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='上架、下架和鎖定歷史';

-- MCH-12: 到期提醒記錄
CREATE TABLE IF NOT EXISTS mch_expiry_reminder (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    contract_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 mch_contract.id',
    offer_id        BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 mch_offer.id',
    reminder_type   VARCHAR(30)     NOT NULL COMMENT '提醒類型：contract_expiry/offer_expiry',
    days_before     INT             NOT NULL COMMENT '提前天數（30/14/7）',
    reminder_key    VARCHAR(64)     NOT NULL COMMENT '去重鍵（防止重複發送）',
    is_sent         TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已發送',
    sent_at         DATETIME(6)     DEFAULT NULL COMMENT '發送時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_reminder_key (reminder_key),
    KEY idx_contract_id (contract_id),
    KEY idx_is_sent (is_sent)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='30、14、7 天提醒記錄';

-- MCH-13: 使用者推播偏好
CREATE TABLE IF NOT EXISTS mch_user_push_preference (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    max_distance_km DECIMAL(6, 1)   DEFAULT NULL COMMENT '最大推播距離（公里）',
    min_push_interval_minutes INT   NOT NULL DEFAULT 60 COMMENT '最小推播間隔（分鐘）',
    preferred_categories_json JSON  DEFAULT NULL COMMENT '偏好分類（結構版本 v1）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_push_pref_account (account_id),
    CONSTRAINT fk_push_pref_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='使用者距離和頻率偏好';

-- MCH-14: 地理圍欄事件
CREATE TABLE IF NOT EXISTS mch_geofence_event (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED DEFAULT NULL COMMENT '匿名化帳號（可為 null）',
    branch_id       BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_branch.id',
    event_type      VARCHAR(30)     NOT NULL COMMENT '事件類型：enter/dwell/exit',
    latitude        DECIMAL(10, 7)  NOT NULL COMMENT '事件緯度',
    longitude       DECIMAL(10, 7)  NOT NULL COMMENT '事件經度',
    accuracy_meters INT             DEFAULT NULL COMMENT '精度（公尺）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_branch_id (branch_id),
    KEY idx_created_at (created_at),
    CONSTRAINT fk_geofence_branch FOREIGN KEY (branch_id) REFERENCES mch_branch(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='進入地理圍欄的匿名化事件';

-- MCH-15: 推播冷卻
CREATE TABLE IF NOT EXISTS mch_push_cooldown (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    merchant_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 mch_merchant.id',
    last_pushed_at  DATETIME(6)     NOT NULL COMMENT '最後推播時間（UTC）',
    cooldown_minutes INT            NOT NULL DEFAULT 60 COMMENT '冷卻分鐘數',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_account_merchant (account_id, merchant_id),
    CONSTRAINT fk_cooldown_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT,
    CONSTRAINT fk_cooldown_merchant FOREIGN KEY (merchant_id) REFERENCES mch_merchant(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='使用者與單一商店的冷卻期限';
