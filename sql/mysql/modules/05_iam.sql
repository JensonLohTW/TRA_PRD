-- ============================================================================
-- 台鐵職工福利平台 — IAM 身份認證模組
-- 模組：05_iam.sql
-- 說明：帳號、身份提供方、外部身份、密碼摘要、啟用挑戰、OTP、MFA、登入紀錄、會話、鎖定
-- 依賴：01_sys.sql、04_emp.sql
-- 設計原則：不保存 Microsoft Graph 密碼、OTP 只存摘要、密碼使用專用哈希演算法
-- ============================================================================

USE tra_welfare_test;

-- IAM-01: 身份提供方
CREATE TABLE IF NOT EXISTS iam_identity_provider (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    provider_code   VARCHAR(50)     NOT NULL COMMENT '提供方代碼，業務唯一',
    provider_name   VARCHAR(100)    NOT NULL COMMENT '提供方名稱',
    provider_type   VARCHAR(30)     NOT NULL COMMENT '類型：internal/microsoft_graph/ldap/oauth2',
    config_json     JSON            DEFAULT NULL COMMENT '設定（結構版本 v1，不保存明文 secret）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_provider_code (provider_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Microsoft、內部帳號等身份提供方';

-- IAM-02: 平台帳號
CREATE TABLE IF NOT EXISTS iam_account (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    username        VARCHAR(100)    NOT NULL COMMENT '登入帳號，唯一',
    employee_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 emp_employee.id（可空，支援未綁定帳號）',
    display_name    VARCHAR(100)    NOT NULL COMMENT '顯示名稱',
    email           VARCHAR(200)    DEFAULT NULL COMMENT 'Email',
    account_status  VARCHAR(30)     NOT NULL DEFAULT 'pending_activation' COMMENT '帳號狀態：pending_activation/active/suspended/locked/disabled',
    login_failures  INT             NOT NULL DEFAULT 0 COMMENT '連續登入失敗次數',
    last_login_at   DATETIME(6)     DEFAULT NULL COMMENT '最後登入時間（UTC）',
    last_login_ip   VARCHAR(45)     DEFAULT NULL COMMENT '最後登入 IP',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_username (username),
    KEY idx_employee_id (employee_id),
    KEY idx_account_status (account_status),
    KEY idx_email (email),
    CONSTRAINT fk_account_employee FOREIGN KEY (employee_id) REFERENCES emp_employee(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='平台帳號狀態、綁定職工和最後登入資訊';

-- IAM-03: 外部身份綁定
CREATE TABLE IF NOT EXISTS iam_external_identity (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    provider_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_identity_provider.id',
    subject         VARCHAR(200)    NOT NULL COMMENT '外部主體標識（如 Microsoft 的 objectId 或 email）',
    external_username VARCHAR(100)  DEFAULT NULL COMMENT '外部使用者名稱',
    is_primary      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否預設外部身份',
    last_sync_at    DATETIME(6)     DEFAULT NULL COMMENT '最後同步時間（UTC）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_provider_subject (provider_id, subject),
    KEY idx_account_id (account_id),
    CONSTRAINT fk_external_identity_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT,
    CONSTRAINT fk_external_identity_provider FOREIGN KEY (provider_id) REFERENCES iam_identity_provider(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='外部主體標識與平台帳號綁定';

-- IAM-04: 帳號密碼憑證
CREATE TABLE IF NOT EXISTS iam_password_credential (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    password_hash   VARCHAR(255)    NOT NULL COMMENT '密碼摘要',
    hash_algorithm  VARCHAR(30)     NOT NULL DEFAULT 'argon2id' COMMENT '哈希演算法：argon2id/bcrypt/pbkdf2',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_account_password (account_id),
    CONSTRAINT fk_password_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='內部帳號密碼摘要、演算法和更新時間';

-- IAM-05: 首次啟用挑戰
CREATE TABLE IF NOT EXISTS iam_activation_challenge (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    challenge_token VARCHAR(64)     NOT NULL COMMENT '挑戰令牌（摘要）',
    token_hash      VARCHAR(255)    NOT NULL COMMENT '令牌摘要（僅存摘要）',
    challenge_type  VARCHAR(30)     NOT NULL DEFAULT 'email' COMMENT '挑戰類型：email/sms/manual',
    expires_at      DATETIME(6)     NOT NULL COMMENT '過期時間（UTC）',
    is_used         TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已使用',
    used_at         DATETIME(6)     DEFAULT NULL COMMENT '使用時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_token_hash (token_hash),
    CONSTRAINT fk_activation_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='首次啟用挑戰和一次性狀態';

-- IAM-06: OTP 挑戰
CREATE TABLE IF NOT EXISTS iam_otp_challenge (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    otp_hash        VARCHAR(255)    NOT NULL COMMENT 'OTP 摘要（不存明文）',
    purpose         VARCHAR(30)     NOT NULL COMMENT '用途：login/activation/password_reset/mfa',
    expires_at      DATETIME(6)     NOT NULL COMMENT '過期時間（UTC）',
    max_attempts    INT             NOT NULL DEFAULT 5 COMMENT '最大嘗試次數',
    attempt_count   INT             NOT NULL DEFAULT 0 COMMENT '已嘗試次數',
    is_used         TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已使用',
    used_at         DATETIME(6)     DEFAULT NULL COMMENT '使用時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_purpose (purpose),
    CONSTRAINT fk_otp_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='OTP 摘要、用途、期限、失敗次數';

-- IAM-07: MFA 因子
CREATE TABLE IF NOT EXISTS iam_mfa_factor (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    factor_type     VARCHAR(30)     NOT NULL COMMENT '因子類型：totp/sms/email/backup_code',
    factor_key_hash VARCHAR(255)    DEFAULT NULL COMMENT '因子密鑰摘要',
    is_verified     TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已驗證',
    is_primary      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否為主要 MFA',
    verified_at     DATETIME(6)     DEFAULT NULL COMMENT '驗證時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    CONSTRAINT fk_mfa_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='管理端 MFA 因子登記';

-- IAM-08: 登入嘗試記錄
CREATE TABLE IF NOT EXISTS iam_login_attempt (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 iam_account.id（失敗可能為 null）',
    username        VARCHAR(100)    NOT NULL COMMENT '嘗試登入帳號',
    attempt_result  VARCHAR(30)     NOT NULL COMMENT '結果：success/failed_account_not_found/failed_wrong_password/failed_locked/failed_mfa/failed_otp/risk_blocked',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '來源 IP',
    user_agent      VARCHAR(500)    DEFAULT NULL COMMENT 'User-Agent',
    risk_score      INT             DEFAULT NULL COMMENT '風控分數（0-100）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_username (username),
    KEY idx_attempt_result (attempt_result),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='登入成功、失敗和風控結果';

-- IAM-09: 登入會話
CREATE TABLE IF NOT EXISTS iam_session (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    session_token   VARCHAR(255)    NOT NULL COMMENT '會話令牌（摘要）',
    refresh_token_hash VARCHAR(255) DEFAULT NULL COMMENT '刷新令牌摘要',
    device_info     VARCHAR(500)    DEFAULT NULL COMMENT '裝置資訊',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '建立時 IP',
    is_revoked      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已撤銷',
    revoked_at      DATETIME(6)     DEFAULT NULL COMMENT '撤銷時間（UTC）',
    idle_timeout_seconds INT        NOT NULL DEFAULT 1800 COMMENT '閒置逾時秒數',
    last_activity_at DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '最後活動時間（UTC）',
    expires_at      DATETIME(6)     NOT NULL COMMENT '過期時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_session_token (session_token),
    KEY idx_is_revoked (is_revoked),
    KEY idx_expires_at (expires_at),
    CONSTRAINT fk_session_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='登入會話、裝置和撤銷狀態';

-- IAM-10: 帳號鎖定記錄
CREATE TABLE IF NOT EXISTS iam_account_lock (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    lock_reason     VARCHAR(30)     NOT NULL COMMENT '鎖定原因：too_many_failures/admin_lock/security_alert/expired_password',
    lock_details    VARCHAR(500)    DEFAULT NULL COMMENT '鎖定詳細',
    locked_by       BIGINT UNSIGNED DEFAULT NULL COMMENT '鎖定操作者（系統或管理員）',
    locked_at       DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '鎖定時間（UTC）',
    unlock_at       DATETIME(6)     DEFAULT NULL COMMENT '自動解鎖時間（null 表示手動）',
    unlocked_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '解鎖操作者',
    unlocked_at     DATETIME(6)     DEFAULT NULL COMMENT '解鎖時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_locked_at (locked_at),
    CONSTRAINT fk_lock_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='鎖定原因、期限和解除記錄';

-- IAM-11: 密碼歷史（防止重複使用）
CREATE TABLE IF NOT EXISTS iam_password_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    password_hash   VARCHAR(255)    NOT NULL COMMENT '歷史密碼摘要',
    hash_algorithm  VARCHAR(30)     NOT NULL DEFAULT 'argon2id' COMMENT '哈希演算法',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_created_at (created_at),
    CONSTRAINT fk_password_history_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='防止重複使用的密碼摘要歷史';

-- IAM-12: 使用者同意記錄
CREATE TABLE IF NOT EXISTS iam_user_consent (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    consent_type    VARCHAR(50)     NOT NULL COMMENT '同意類型：privacy_policy/terms_of_service/data_sharing',
    consent_version VARCHAR(30)     NOT NULL COMMENT '同意版本',
    ip_address      VARCHAR(45)     DEFAULT NULL COMMENT '同意時 IP',
    request_trace   VARCHAR(64)     DEFAULT NULL COMMENT '請求追蹤號',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '同意時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_account_consent (account_id, consent_type, consent_version),
    KEY idx_consent_type (consent_type),
    CONSTRAINT fk_consent_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='使用者對隱私、系統條款等版本的同意';
