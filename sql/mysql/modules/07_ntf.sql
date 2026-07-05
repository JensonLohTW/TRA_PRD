-- ============================================================================
-- 台鐵職工福利平台 — NTF 通知服務模組
-- 模組：07_ntf.sql
-- 說明：通知模板、模板版本、業務消息、收件人、渠道發送、站內信箱、Web Push、偏好與重試
-- 依賴：01_sys.sql、05_iam.sql
-- 設計原則：業務模組只產生通知意圖，不保存渠道發送細節；消息引用模板版本
-- ============================================================================

USE tra_welfare_test;

-- NTF-01: 通知模板主檔
CREATE TABLE IF NOT EXISTS ntf_template (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    template_code   VARCHAR(50)     NOT NULL COMMENT '模板代碼，業務唯一',
    template_name   VARCHAR(100)    NOT NULL COMMENT '模板名稱',
    template_type   VARCHAR(30)     NOT NULL COMMENT '類型：email/in_app/sms/web_push',
    category        VARCHAR(50)     DEFAULT NULL COMMENT '分類：approval/payment/expiry/alert/system',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_template_code (template_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知模板主檔';

-- NTF-02: 通知模板版本
CREATE TABLE IF NOT EXISTS ntf_template_version (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    template_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 ntf_template.id',
    version_no      INT             NOT NULL COMMENT '版本號（同一模板內遞增）',
    subject         VARCHAR(200)    DEFAULT NULL COMMENT '主旨／標題（支援變數）',
    body_template   TEXT            NOT NULL COMMENT '正文模板（支援變數）',
    content_type    VARCHAR(30)     NOT NULL DEFAULT 'text/plain' COMMENT '內容類型：text/plain/text/html',
    variables_json  JSON            DEFAULT NULL COMMENT '變數定義（結構版本 v1）',
    is_published    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已發佈',
    published_at    DATETIME(6)     DEFAULT NULL COMMENT '發佈時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_template_version (template_id, version_no),
    CONSTRAINT fk_template_version_template FOREIGN KEY (template_id) REFERENCES ntf_template(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Email、站內信、Web Push 模板版本';

-- NTF-03: 業務通知消息
CREATE TABLE IF NOT EXISTS ntf_message (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    message_code    VARCHAR(64)     NOT NULL COMMENT '業務冪等鍵（防止重複送件）',
    template_version_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 ntf_template_version.id',
    aggregate_type  VARCHAR(50)     DEFAULT NULL COMMENT '關聯聚合類型（如 ben_application）',
    aggregate_id    BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯聚合 ID',
    payload_json    JSON            DEFAULT NULL COMMENT '通知載荷（結構版本 v1，含模板變數值）',
    sender_type     VARCHAR(30)     NOT NULL DEFAULT 'system' COMMENT '發送者類型：system/user/workflow',
    sender_id       BIGINT UNSIGNED DEFAULT NULL COMMENT '發送者（iam_account.id）',
    priority        VARCHAR(10)     NOT NULL DEFAULT 'normal' COMMENT '優先級：high/normal/low',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_message_code (message_code),
    KEY idx_aggregate (aggregate_type, aggregate_id),
    KEY idx_created_at (created_at),
    CONSTRAINT fk_message_template_version FOREIGN KEY (template_version_id) REFERENCES ntf_template_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='一次業務通知消息';

-- NTF-04: 消息收件人
CREATE TABLE IF NOT EXISTS ntf_recipient (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    message_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 ntf_message.id',
    account_id      BIGINT UNSIGNED DEFAULT NULL COMMENT '收件帳號（iam_account.id，null 表示外部收件人）',
    recipient_name  VARCHAR(100)    DEFAULT NULL COMMENT '收件人姓名',
    recipient_address VARCHAR(255)  DEFAULT NULL COMMENT '收件地址（Email/手機號碼）',
    required_channels VARCHAR(100)  NOT NULL DEFAULT 'in_app' COMMENT '要求渠道（逗號分隔：email,in_app,sms,web_push）',
    is_processed    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已處理',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_message_id (message_id),
    KEY idx_account_id (account_id),
    CONSTRAINT fk_recipient_message FOREIGN KEY (message_id) REFERENCES ntf_message(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='收件帳號和送達要求';

-- NTF-05: 渠道發送記錄
CREATE TABLE IF NOT EXISTS ntf_delivery (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    recipient_id    BIGINT UNSIGNED NOT NULL COMMENT '關聯 ntf_recipient.id',
    channel         VARCHAR(30)     NOT NULL COMMENT '渠道：email/in_app/sms/web_push',
    delivery_status VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/sent/delivered/failed/bounced/read',
    attempt_count   INT             NOT NULL DEFAULT 0 COMMENT '嘗試次數',
    last_attempt_at DATETIME(6)     DEFAULT NULL COMMENT '最後嘗試時間（UTC）',
    error_message   TEXT            DEFAULT NULL COMMENT '錯誤訊息',
    provider_message_id VARCHAR(200) DEFAULT NULL COMMENT '外部提供方消息 ID',
    delivered_at    DATETIME(6)     DEFAULT NULL COMMENT '送達時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_recipient_id (recipient_id),
    KEY idx_delivery_status (delivery_status),
    KEY idx_channel (channel),
    CONSTRAINT fk_delivery_recipient FOREIGN KEY (recipient_id) REFERENCES ntf_recipient(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='每個渠道的發送嘗試與結果';

-- NTF-06: 站內通知／已讀
CREATE TABLE IF NOT EXISTS ntf_inbox (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    delivery_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 ntf_delivery.id',
    title           VARCHAR(200)    NOT NULL COMMENT '通知標題',
    body            TEXT            NOT NULL COMMENT '通知正文',
    is_read         TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已讀',
    read_at         DATETIME(6)     DEFAULT NULL COMMENT '讀取時間（UTC）',
    is_archived     TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已封存',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_is_read (is_read),
    KEY idx_created_at (created_at),
    CONSTRAINT fk_inbox_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='使用者站內通知和已讀狀態';

-- NTF-07: Web Push 推播訂閱
CREATE TABLE IF NOT EXISTS ntf_web_push_subscription (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    endpoint        VARCHAR(500)    NOT NULL COMMENT 'Push 端點 URL',
    p256dh_key      VARCHAR(200)    NOT NULL COMMENT 'P-256 DH 公鑰',
    auth_key        VARCHAR(100)    NOT NULL COMMENT 'Auth 密鑰',
    user_agent      VARCHAR(500)    DEFAULT NULL COMMENT '瀏覽器 User-Agent',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否有效',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_is_active (is_active),
    CONSTRAINT fk_push_subscription_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='瀏覽器推播訂閱';

-- NTF-08: 使用者通知偏好
CREATE TABLE IF NOT EXISTS ntf_user_preference (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    category        VARCHAR(50)     NOT NULL COMMENT '通知類別',
    channel         VARCHAR(30)     NOT NULL COMMENT '渠道：email/in_app/sms/web_push',
    is_enabled      TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_account_category_channel (account_id, category, channel),
    CONSTRAINT fk_preference_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='使用者渠道和類別偏好';

-- NTF-09: 失敗通知重送任務
CREATE TABLE IF NOT EXISTS ntf_retry_job (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    delivery_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 ntf_delivery.id',
    retry_status    VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/retrying/max_retries_reached/success',
    retry_count     INT             NOT NULL DEFAULT 0 COMMENT '已重試次數',
    max_retries     INT             NOT NULL DEFAULT 3 COMMENT '最大重試次數',
    next_retry_at   DATETIME(6)     DEFAULT NULL COMMENT '下次重試時間（UTC）',
    last_error      TEXT            DEFAULT NULL COMMENT '最後錯誤',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_delivery_id (delivery_id),
    KEY idx_retry_status (retry_status),
    CONSTRAINT fk_retry_delivery FOREIGN KEY (delivery_id) REFERENCES ntf_delivery(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='失敗通知重送任務';
