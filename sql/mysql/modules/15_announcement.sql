-- ============================================================================
-- 台鐵職工福利平台 — ANN 公告發佈模組
-- 模組：15_announcement.sql
-- 說明：公告分類、主檔、內容版本、附件、分眾規則、排程、審批橋接、發佈記錄、
--       觸及統計、地理規則
-- 依賴：01_sys.sql、02_file.sql、05_iam.sql、10_workflow.sql
-- 設計原則：公告正文版本化、發佈時固化受眾快照、撤回不刪除歷史
-- ============================================================================

USE tra_welfare_test;

-- ANN-01: 公告分類
CREATE TABLE IF NOT EXISTS ann_category (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    category_code   VARCHAR(30)     NOT NULL COMMENT '分類代碼，唯一',
    category_name   VARCHAR(100)    NOT NULL COMMENT '分類名稱',
    sort_order      INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ann_category_code (category_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='公告分類';

-- ANN-02: 公告主檔
CREATE TABLE IF NOT EXISTS ann_announcement (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    announcement_no VARCHAR(50)     NOT NULL COMMENT '公告編號，唯一',
    title           VARCHAR(200)    NOT NULL COMMENT '公告標題',
    category_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ann_category.id',
    priority        VARCHAR(10)     NOT NULL DEFAULT 'normal' COMMENT '優先級：urgent/high/normal/low',
    announcement_status VARCHAR(30) NOT NULL DEFAULT 'draft' COMMENT '狀態：draft/pending_approval/scheduled/published/withdrawn/expired',
    is_pinned       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否置頂',
    is_all_employees TINYINT(1)     NOT NULL DEFAULT 0 COMMENT '是否全員公告',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '建立人（iam_account.id）',
    published_by    BIGINT UNSIGNED DEFAULT NULL COMMENT '發佈人（iam_account.id）',
    published_at    DATETIME(6)     DEFAULT NULL COMMENT '正式發佈時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_announcement_no (announcement_no),
    KEY idx_category_id (category_id),
    KEY idx_announcement_status (announcement_status),
    KEY idx_published_at (published_at),
    KEY idx_is_pinned (is_pinned)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='公告主檔、狀態和優先級';

-- ANN-03: 公告內容版本
CREATE TABLE IF NOT EXISTS ann_content_version (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    announcement_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ann_announcement.id',
    version_no      INT             NOT NULL COMMENT '版本號',
    title           VARCHAR(200)    NOT NULL COMMENT '該版本標題',
    body            TEXT            NOT NULL COMMENT '正文',
    content_format  VARCHAR(30)     NOT NULL DEFAULT 'html' COMMENT '內容格式：html/markdown/plain_text',
    change_summary  VARCHAR(500)    DEFAULT NULL COMMENT '變更摘要',
    created_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '編輯者（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ann_content_version (announcement_id, version_no),
    CONSTRAINT fk_ann_content_announcement FOREIGN KEY (announcement_id) REFERENCES ann_announcement(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='標題、正文和內容版本';

-- ANN-04: 公告附件
CREATE TABLE IF NOT EXISTS ann_attachment (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    announcement_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ann_announcement.id',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 file_object.id',
    sort_order      INT             NOT NULL DEFAULT 0 COMMENT '排序',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_announcement_id (announcement_id),
    KEY idx_file_id (file_id),
    CONSTRAINT fk_ann_attachment_announcement FOREIGN KEY (announcement_id) REFERENCES ann_announcement(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ann_attachment_file FOREIGN KEY (file_id) REFERENCES file_object(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='公告附件';

-- ANN-05: 分眾規則
CREATE TABLE IF NOT EXISTS ann_audience_rule (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    announcement_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ann_announcement.id',
    criteria_json   JSON            NOT NULL COMMENT '分眾條件（結構版本 v1，組織、角色、區域或名單組合）',
    version_no      INT             NOT NULL DEFAULT 1 COMMENT '規則版本',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_announcement_id (announcement_id),
    CONSTRAINT fk_ann_audience_announcement FOREIGN KEY (announcement_id) REFERENCES ann_announcement(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='組織、角色、區域或名單分眾規則';

-- ANN-06: 排程設定
CREATE TABLE IF NOT EXISTS ann_schedule (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    announcement_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ann_announcement.id',
    schedule_type   VARCHAR(30)     NOT NULL DEFAULT 'immediate' COMMENT '類型：immediate/scheduled/periodic',
    start_at        DATETIME(6)     DEFAULT NULL COMMENT '開始時間（UTC）',
    end_at          DATETIME(6)     DEFAULT NULL COMMENT '結束時間（UTC）',
    cron_expression VARCHAR(100)    DEFAULT NULL COMMENT '週期 CRON（schedule_type=periodic 時）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否有效',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ann_schedule (announcement_id),
    CONSTRAINT fk_ann_schedule_announcement FOREIGN KEY (announcement_id) REFERENCES ann_announcement(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='立即、定時、週期和失效時間';

-- ANN-07: 公告審批橋接
CREATE TABLE IF NOT EXISTS ann_publish_workflow (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    announcement_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ann_announcement.id',
    wf_instance_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_instance.id',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ann_publish_wf (announcement_id, wf_instance_id),
    KEY idx_wf_instance_id (wf_instance_id),
    CONSTRAINT fk_ann_publish_wf_announcement FOREIGN KEY (announcement_id) REFERENCES ann_announcement(id) ON DELETE RESTRICT,
    CONSTRAINT fk_ann_publish_wf_instance FOREIGN KEY (wf_instance_id) REFERENCES wf_instance(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='公告與審批實例關聯';

-- ANN-08: 發佈記錄
CREATE TABLE IF NOT EXISTS ann_publish_record (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    announcement_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ann_announcement.id',
    record_type     VARCHAR(30)     NOT NULL COMMENT '記錄類型：publish/withdraw/republish',
    content_version_id BIGINT UNSIGNED DEFAULT NULL COMMENT '發佈時內容版本',
    audience_snapshot_json JSON    DEFAULT NULL COMMENT '發佈時受眾快照（結構版本 v1）',
    operated_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '操作者（iam_account.id）',
    operated_at     DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '操作時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_announcement_id (announcement_id),
    CONSTRAINT fk_ann_publish_record_announcement FOREIGN KEY (announcement_id) REFERENCES ann_announcement(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='每次正式發佈和撤回';

-- ANN-09: 觸及統計摘要
CREATE TABLE IF NOT EXISTS ann_reach_summary (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    announcement_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ann_announcement.id',
    total_recipients INT            NOT NULL DEFAULT 0 COMMENT '總收件人數',
    delivered_count INT             NOT NULL DEFAULT 0 COMMENT '送達數',
    read_count      INT             NOT NULL DEFAULT 0 COMMENT '已讀數',
    channel_json    JSON            DEFAULT NULL COMMENT '各渠道統計（結構版本 v1）',
    summary_date    DATE            NOT NULL COMMENT '統計日期',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ann_reach (announcement_id, summary_date),
    CONSTRAINT fk_ann_reach_announcement FOREIGN KEY (announcement_id) REFERENCES ann_announcement(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='觸及、已讀和渠道彙總';

-- ANN-10: 地理圍欄規則
CREATE TABLE IF NOT EXISTS ann_location_rule (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    announcement_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ann_announcement.id',
    latitude        DECIMAL(10, 7)  NOT NULL COMMENT '中心緯度',
    longitude       DECIMAL(10, 7)  NOT NULL COMMENT '中心經度',
    radius_meters   INT             NOT NULL COMMENT '半徑（公尺）',
    trigger_event   VARCHAR(30)     NOT NULL DEFAULT 'enter' COMMENT '觸發事件：enter/dwell',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_announcement_id (announcement_id),
    CONSTRAINT fk_ann_location_announcement FOREIGN KEY (announcement_id) REFERENCES ann_announcement(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='地理圍欄與觸發半徑';
