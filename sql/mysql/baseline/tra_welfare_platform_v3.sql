-- ============================================================================
-- 臺鐵職工福利平台 MySQL 8.0 完整初始化 Schema
-- 版本：v3.0-full
-- 日期：2026-03-26
-- 說明：依 PRD / 原始規劃報告 / 覆蓋度分析重新整理之完整初始化版本。
--       本檔不含 ALTER / Patch，直接輸出可初始化新資料庫的完整 Schema。
--       v3.0 重點補齊：BEN 實體核章與代理填發、PAY 報銷/異議/收執、AI 辨識留痕、
--       WF 事件流、ANN 地理圍欄、MCH 地圖座標、SEC 處置欄位與封存關聯。
-- 編碼：utf8mb4
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS tra_welfare_platform
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE tra_welfare_platform;


-- ============================================================================
-- 模塊 SYS：系統基礎設施
-- ============================================================================

-- SYS-01: 資料字典
CREATE TABLE IF NOT EXISTS sys_dictionary
(
    dictionary_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '字典主鍵',
    dict_type     VARCHAR(50)     NOT NULL COMMENT '字典類型',
    dict_code     VARCHAR(50)     NOT NULL COMMENT '字典值代碼',
    dict_name     VARCHAR(100)    NOT NULL COMMENT '字典值顯示名稱',
    dict_name_en  VARCHAR(100)             DEFAULT NULL COMMENT '英文名稱',
    sort_order    INT             NOT NULL DEFAULT 0 COMMENT '排序',
    parent_code   VARCHAR(50)              DEFAULT NULL COMMENT '父層代碼',
    extra_json    JSON                     DEFAULT NULL COMMENT '額外設定',
    is_active     TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by    BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by    BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (dictionary_id),
    UNIQUE KEY uk_dict_type_code (dict_type, dict_code),
    KEY idx_dict_type (dict_type)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '資料字典';

-- SYS-02: 系統參數配置
CREATE TABLE IF NOT EXISTS sys_config
(
    config_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '配置主鍵',
    config_key       VARCHAR(100)    NOT NULL COMMENT '參數鍵',
    config_value     TEXT            NOT NULL COMMENT '參數值',
    config_type      VARCHAR(50)     NOT NULL DEFAULT 'string' COMMENT '值類型：string/int/boolean/json',
    description_text VARCHAR(255)             DEFAULT NULL COMMENT '說明',
    is_editable      TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否可前台修改',
    is_deleted       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (config_id),
    UNIQUE KEY uk_config_key (config_key)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '系統參數配置';

-- SYS-03: 統一檔案資源
CREATE TABLE IF NOT EXISTS file_resource
(
    file_id             BIGINT UNSIGNED                        NOT NULL AUTO_INCREMENT COMMENT '檔案主鍵',
    file_key            VARCHAR(128)                           NOT NULL COMMENT '檔案唯一識別碼(UUID)',
    original_name       VARCHAR(255)                           NOT NULL COMMENT '原始檔名',
    stored_name         VARCHAR(255)                                    DEFAULT NULL COMMENT '儲存檔名',
    storage_path        VARCHAR(500)                           NOT NULL COMMENT '儲存路徑',
    storage_provider    VARCHAR(50)                            NOT NULL DEFAULT 'local' COMMENT '儲存提供者：local/s3/minio/gcs',
    mime_type           VARCHAR(100)                                    DEFAULT NULL COMMENT 'MIME 類型',
    file_size_bytes     BIGINT                                 NOT NULL DEFAULT 0 COMMENT '檔案大小(bytes)',
    checksum            VARCHAR(128)                                    DEFAULT NULL COMMENT '檔案雜湊值',
    sensitivity_level   VARCHAR(50)                                     DEFAULT 'normal' COMMENT '敏感等級：normal/sensitive/high_sensitive',
    file_status         ENUM ('uploaded', 'active', 'archived', 'disabled', 'deleted')
                                                             NOT NULL DEFAULT 'uploaded' COMMENT '檔案狀態',
    business_type       VARCHAR(50)                                     DEFAULT NULL COMMENT '關聯業務類型',
    business_id         BIGINT UNSIGNED                                 DEFAULT NULL COMMENT '關聯業務 ID',
    related_module_code VARCHAR(50)                                     DEFAULT NULL COMMENT '關聯模組代碼',
    revision            INT                                    NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    uploaded_by         BIGINT UNSIGNED                                 DEFAULT NULL COMMENT '上傳人',
    is_deleted          TINYINT(1)                             NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_at          DATETIME                               NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at          DATETIME                               NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (file_id),
    UNIQUE KEY uk_file_key (file_key),
    KEY idx_file_business (business_type, business_id),
    KEY idx_file_status (file_status),
    KEY idx_file_sensitive (sensitivity_level)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '統一檔案資源';

-- SYS-04: 統一通知中心
CREATE TABLE IF NOT EXISTS notification
(
    notification_id       BIGINT UNSIGNED                 NOT NULL AUTO_INCREMENT COMMENT '通知主鍵',
    recipient_employee_id BIGINT UNSIGNED                 NOT NULL COMMENT '收件人員工 ID',
    notification_type     VARCHAR(50)                     NOT NULL COMMENT '通知類型：workflow/alert/system/announcement',
    title                 VARCHAR(255)                    NOT NULL COMMENT '標題',
    content               TEXT                                     DEFAULT NULL COMMENT '內容',
    business_type         VARCHAR(50)                              DEFAULT NULL COMMENT '關聯業務類型',
    business_id           BIGINT UNSIGNED                          DEFAULT NULL COMMENT '關聯業務 ID',
    is_read               TINYINT(1)                      NOT NULL DEFAULT 0 COMMENT '是否已讀',
    read_at               DATETIME                                 DEFAULT NULL COMMENT '已讀時間',
    channel               ENUM ('portal', 'email', 'sms') NOT NULL DEFAULT 'portal' COMMENT '通知管道',
    is_deleted            TINYINT(1)                      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by            BIGINT UNSIGNED                          DEFAULT NULL COMMENT '建立人',
    created_at            DATETIME                        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at            DATETIME                        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (notification_id),
    KEY idx_notification_recipient (recipient_employee_id),
    KEY idx_notification_type (notification_type),
    KEY idx_notification_read (is_read),
    KEY idx_notification_business (business_type, business_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '統一通知中心';

-- SYS-05: 檔案引用關係
CREATE TABLE IF NOT EXISTS file_reference
(
    file_reference_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '引用關係主鍵',
    file_id             BIGINT UNSIGNED NOT NULL COMMENT '檔案 ID',
    target_type         VARCHAR(50)     NOT NULL COMMENT '目標類型',
    target_id           BIGINT UNSIGNED NOT NULL COMMENT '目標主鍵',
    reference_role      VARCHAR(50)     NOT NULL COMMENT '引用角色：main_attachment/voucher/receipt/contract_scan',
    is_active_reference TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否有效引用',
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (file_reference_id),
    KEY idx_file_reference_file (file_id),
    KEY idx_file_reference_target (target_type, target_id, reference_role),
    CONSTRAINT fk_file_reference_file FOREIGN KEY (file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '檔案引用關係';

-- SYS-06: 檔案下載紀錄
CREATE TABLE IF NOT EXISTS file_download_log
(
    file_download_log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '下載紀錄主鍵',
    file_id              BIGINT UNSIGNED NOT NULL COMMENT '檔案 ID',
    actor_employee_id    BIGINT UNSIGNED          DEFAULT NULL COMMENT '下載人',
    business_type        VARCHAR(50)              DEFAULT NULL COMMENT '業務類型',
    business_id          BIGINT UNSIGNED          DEFAULT NULL COMMENT '業務主鍵',
    source_ip            VARCHAR(64)              DEFAULT NULL COMMENT '來源 IP',
    user_agent           VARCHAR(500)             DEFAULT NULL COMMENT '瀏覽器資訊',
    downloaded_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '下載時間',
    PRIMARY KEY (file_download_log_id),
    KEY idx_file_download_file (file_id),
    KEY idx_file_download_actor (actor_employee_id),
    KEY idx_file_download_time (downloaded_at),
    CONSTRAINT fk_file_download_file FOREIGN KEY (file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '檔案下載紀錄';


-- ============================================================================
-- 模塊 ORG：組織與權限
-- ============================================================================

-- ORG-01: 組織層級字典
CREATE TABLE IF NOT EXISTS org_level_type
(
    level_type_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '層級類型主鍵',
    level_code    VARCHAR(50)     NOT NULL COMMENT '層級代碼',
    level_name    VARCHAR(100)    NOT NULL COMMENT '層級名稱',
    sort_order    INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active     TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by    BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by    BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (level_type_id),
    UNIQUE KEY uk_org_level_code (level_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '組織層級字典';

-- ORG-02: 組織樹節點
CREATE TABLE IF NOT EXISTS org_node
(
    node_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '組織節點主鍵',
    parent_node_id   BIGINT UNSIGNED          DEFAULT NULL COMMENT '上層節點 ID',
    level_type_id    BIGINT UNSIGNED          DEFAULT NULL COMMENT '層級類型 ID',
    node_code        VARCHAR(50)              DEFAULT NULL COMMENT '節點代碼',
    node_name        VARCHAR(100)    NOT NULL COMMENT '節點名稱',
    node_type        VARCHAR(50)     NOT NULL COMMENT '節點類型：committee/role/team/branch',
    description_text TEXT                     DEFAULT NULL COMMENT '節點說明',
    sort_order       INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active        TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (node_id),
    UNIQUE KEY uk_org_node_code (node_code),
    KEY idx_org_parent (parent_node_id),
    KEY idx_org_level_type (level_type_id),
    CONSTRAINT fk_org_parent FOREIGN KEY (parent_node_id) REFERENCES org_node (node_id),
    CONSTRAINT fk_org_level_type FOREIGN KEY (level_type_id) REFERENCES org_level_type (level_type_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '組織樹節點';

-- ORG-03: 角色字典
CREATE TABLE IF NOT EXISTS position_role
(
    role_id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '角色主鍵',
    role_code             VARCHAR(50)     NOT NULL COMMENT '角色代碼',
    role_name             VARCHAR(100)    NOT NULL COMMENT '角色名稱',
    permission_scope_type VARCHAR(50)     NOT NULL DEFAULT 'scoped' COMMENT '權限範圍類型：global/scoped',
    is_fixed_role         TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否固定編制角色',
    is_active             TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    sort_order            INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_deleted            TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by            BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by            BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (role_id),
    UNIQUE KEY uk_role_code (role_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '角色字典';

-- ORG-04: 功能權限定義（新增）
CREATE TABLE IF NOT EXISTS sys_permission
(
    permission_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '權限主鍵',
    permission_code  VARCHAR(100)    NOT NULL COMMENT '權限代碼，如 BEN:APPLICATION:CREATE',
    permission_name  VARCHAR(150)    NOT NULL COMMENT '權限名稱',
    module_code      VARCHAR(50)     NOT NULL COMMENT '所屬模塊代碼',
    action_type      VARCHAR(50)     NOT NULL COMMENT '動作：view/create/edit/delete/approve/export',
    resource_type    VARCHAR(100)             DEFAULT NULL COMMENT '資源類型',
    description_text VARCHAR(255)             DEFAULT NULL COMMENT '說明',
    sort_order       INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active        TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (permission_id),
    UNIQUE KEY uk_permission_code (permission_code),
    KEY idx_permission_module (module_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '功能權限定義';

-- ORG-05: 角色權限映射（新增）
CREATE TABLE IF NOT EXISTS role_permission
(
    role_permission_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '角色權限主鍵',
    role_id            BIGINT UNSIGNED NOT NULL COMMENT '角色 ID',
    permission_id      BIGINT UNSIGNED NOT NULL COMMENT '權限 ID',
    is_deleted         TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by         BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    created_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (role_permission_id),
    UNIQUE KEY uk_role_permission (role_id, permission_id),
    KEY idx_rp_permission (permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES position_role (role_id),
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES sys_permission (permission_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '角色權限映射';

-- ORG-06: 福利社/分處主檔
CREATE TABLE IF NOT EXISTS welfare_branch
(
    welfare_branch_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '福利社主鍵',
    branch_code       VARCHAR(50)     NOT NULL COMMENT '福利社代碼',
    branch_name       VARCHAR(100)    NOT NULL COMMENT '福利社名稱',
    region_code       VARCHAR(50)              DEFAULT NULL COMMENT '區域代碼',
    region_name       VARCHAR(100)             DEFAULT NULL COMMENT '區域名稱',
    contact_phone     VARCHAR(50)              DEFAULT NULL COMMENT '聯絡電話',
    address           VARCHAR(255)             DEFAULT NULL COMMENT '地址',
    is_active         TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted        TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by        BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by        BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (welfare_branch_id),
    UNIQUE KEY uk_welfare_branch_code (branch_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '福利社/分處主檔';


-- ============================================================================
-- 模塊 EMP：職工人員
-- ============================================================================

-- EMP-01: 員工主檔（重構：移除冗餘衍生欄位，補齊審計欄位）
CREATE TABLE IF NOT EXISTS employee
(
    employee_id                 BIGINT UNSIGNED                                  NOT NULL AUTO_INCREMENT COMMENT '員工主鍵',
    employee_no                 VARCHAR(50)                                      NOT NULL COMMENT '員工代號/員編',
    admin_no                    VARCHAR(50)                                               DEFAULT NULL COMMENT '後台管理識別碼',
    full_name                   VARCHAR(100)                                     NOT NULL COMMENT '員工姓名',
    english_name                VARCHAR(100)                                              DEFAULT NULL COMMENT '英文姓名',
    welfare_branch_id           BIGINT UNSIGNED                                           DEFAULT NULL COMMENT '所屬福利社/分處',
    employment_status           ENUM ('active', 'leave', 'retired', 'suspended') NOT NULL DEFAULT 'active' COMMENT '在職狀態',
    staff_type                  ENUM ('regular', 'contract', 'retired', 'admin') NOT NULL DEFAULT 'regular' COMMENT '人員類型',
    birth_date                  DATE                                                      DEFAULT NULL COMMENT '出生日期',
    identity_no_ciphertext      VARBINARY(512)                                            DEFAULT NULL COMMENT '身分證字號密文',
    identity_no_masked          VARCHAR(20)                                               DEFAULT NULL COMMENT '身分證遮罩值',
    identity_no_hash            CHAR(64)                                                  DEFAULT NULL COMMENT '身分證雜湊值',
    phone                       VARCHAR(50)                                               DEFAULT NULL COMMENT '聯絡電話',
    email                       VARCHAR(255)                                              DEFAULT NULL COMMENT '電子郵件',
    address                     VARCHAR(255)                                              DEFAULT NULL COMMENT '通訊地址',
    contact_profile_completed   TINYINT(1)                                       NOT NULL DEFAULT 0 COMMENT '聯絡資料是否補齊',
    hire_date                   DATE                                                      DEFAULT NULL COMMENT '入職日期',
    leave_date                  DATE                                                      DEFAULT NULL COMMENT '離職日期',
    payroll_deduction_status    VARCHAR(50)                                               DEFAULT NULL COMMENT '福利金扣繳狀態',
    payroll_last_deduction_date DATE                                                      DEFAULT NULL COMMENT '最近扣款日期',
    subsidy_eligibility_status  VARCHAR(50)                                               DEFAULT NULL COMMENT '補助申領資格狀態',
    note                        TEXT                                                      DEFAULT NULL COMMENT '備註',
    is_deleted                  TINYINT(1)                                       NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by                  BIGINT UNSIGNED                                           DEFAULT NULL COMMENT '建立人',
    updated_by                  BIGINT UNSIGNED                                           DEFAULT NULL COMMENT '更新人',
    created_at                  DATETIME                                         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at                  DATETIME                                         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (employee_id),
    UNIQUE KEY uk_employee_no (employee_no),
    UNIQUE KEY uk_admin_no (admin_no),
    UNIQUE KEY uk_employee_identity_hash (identity_no_hash),
    KEY idx_employee_branch (welfare_branch_id),
    KEY idx_employee_status (employment_status),
    CONSTRAINT fk_employee_branch FOREIGN KEY (welfare_branch_id) REFERENCES welfare_branch (welfare_branch_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '員工主檔';

-- EMP-02: 職工眷屬資料
CREATE TABLE IF NOT EXISTS employee_dependent
(
    dependent_id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '眷屬主鍵',
    employee_id                 BIGINT UNSIGNED NOT NULL COMMENT '員工 ID',
    relation_type               VARCHAR(50)     NOT NULL COMMENT '關係：spouse/child/parent/other',
    dependent_name              VARCHAR(100)    NOT NULL COMMENT '眷屬姓名',
    birth_date                  DATE                     DEFAULT NULL COMMENT '出生日期',
    school_name                 VARCHAR(255)             DEFAULT NULL COMMENT '就學/單位資訊',
    identity_no_ciphertext      VARBINARY(512)           DEFAULT NULL COMMENT '身分證字號密文',
    identity_no_masked          VARCHAR(20)              DEFAULT NULL COMMENT '身分證遮罩值',
    identity_no_hash            CHAR(64)                 DEFAULT NULL COMMENT '身分證雜湊值',
    is_eligible_for_subsidy     TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否符合補助資格',
    current_school_stage        VARCHAR(50)              DEFAULT NULL COMMENT '目前學制階段',
    current_academic_year_label VARCHAR(20)              DEFAULT NULL COMMENT '目前學年標記',
    status                      VARCHAR(50)     NOT NULL DEFAULT 'active' COMMENT '狀態',
    is_deleted                  TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by                  BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by                  BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at                  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at                  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (dependent_id),
    KEY idx_dependent_employee (employee_id),
    KEY idx_dependent_identity_hash (identity_no_hash),
    CONSTRAINT fk_dependent_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '職工眷屬資料';

-- EMP-03: 員工檔案變更日誌
CREATE TABLE IF NOT EXISTS employee_profile_change_log
(
    change_log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '變更日誌主鍵',
    employee_id   BIGINT UNSIGNED NOT NULL COMMENT '員工 ID',
    changed_by    BIGINT UNSIGNED          DEFAULT NULL COMMENT '操作人',
    change_type   VARCHAR(50)     NOT NULL COMMENT '變更類型：profile_update/dependent_update/import/status_change',
    field_name    VARCHAR(100)             DEFAULT NULL COMMENT '變更欄位',
    old_value     TEXT                     DEFAULT NULL COMMENT '舊值',
    new_value     TEXT                     DEFAULT NULL COMMENT '新值',
    change_note   TEXT                     DEFAULT NULL COMMENT '變更說明',
    changed_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '變更時間',
    PRIMARY KEY (change_log_id),
    KEY idx_profile_change_employee (employee_id),
    KEY idx_profile_change_time (changed_at),
    CONSTRAINT fk_profile_change_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id),
    CONSTRAINT fk_profile_change_actor FOREIGN KEY (changed_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '員工檔案變更日誌';


-- ============================================================================
-- 模塊 AUTH：認證與會話
-- ============================================================================

-- AUTH-01: 系統登入帳號
CREATE TABLE IF NOT EXISTS user_account
(
    account_id               BIGINT UNSIGNED                                             NOT NULL AUTO_INCREMENT COMMENT '帳號主鍵',
    employee_id              BIGINT UNSIGNED                                             NOT NULL COMMENT '對應員工',
    login_name               VARCHAR(150)                                                NOT NULL COMMENT '登入帳號',
    email                    VARCHAR(255)                                                         DEFAULT NULL COMMENT '登入信箱',
    password_hash            VARCHAR(255)                                                NOT NULL COMMENT '密碼雜湊',
    account_status           ENUM ('pending_activation', 'active', 'disabled', 'locked') NOT NULL DEFAULT 'active' COMMENT '帳號狀態',
    last_login_at            DATETIME                                                             DEFAULT NULL COMMENT '最後登入時間',
    last_password_changed_at DATETIME                                                             DEFAULT NULL COMMENT '最後修改密碼時間',
    failed_login_count       INT                                                         NOT NULL DEFAULT 0 COMMENT '連續登入失敗次數',
    locked_until             DATETIME                                                             DEFAULT NULL COMMENT '鎖定到期時間',
    is_deleted               TINYINT(1)                                                  NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by               BIGINT UNSIGNED                                                      DEFAULT NULL COMMENT '建立人',
    updated_by               BIGINT UNSIGNED                                                      DEFAULT NULL COMMENT '更新人',
    created_at               DATETIME                                                    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at               DATETIME                                                    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (account_id),
    UNIQUE KEY uk_login_name (login_name),
    KEY idx_account_employee (employee_id),
    CONSTRAINT fk_user_account_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '系統登入帳號';

-- AUTH-02: 使用者會話（新增）
CREATE TABLE IF NOT EXISTS user_session
(
    session_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '會話主鍵',
    account_id    BIGINT UNSIGNED NOT NULL COMMENT '帳號 ID',
    session_token VARCHAR(512)    NOT NULL COMMENT 'Session Token',
    refresh_token VARCHAR(512)             DEFAULT NULL COMMENT 'Refresh Token',
    device_info   VARCHAR(255)             DEFAULT NULL COMMENT '裝置資訊',
    source_ip     VARCHAR(64)              DEFAULT NULL COMMENT '來源 IP',
    expires_at    DATETIME        NOT NULL COMMENT '過期時間',
    is_revoked    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已撤銷',
    created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (session_id),
    UNIQUE KEY uk_session_token (session_token),
    KEY idx_session_account (account_id),
    KEY idx_session_expires (expires_at),
    CONSTRAINT fk_session_account FOREIGN KEY (account_id) REFERENCES user_account (account_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '使用者會話';

-- AUTH-03: 登入嘗試紀錄
CREATE TABLE IF NOT EXISTS login_attempt
(
    login_attempt_id BIGINT UNSIGNED                                        NOT NULL AUTO_INCREMENT COMMENT '登入紀錄主鍵',
    account_id       BIGINT UNSIGNED                                                 DEFAULT NULL COMMENT '對應帳號',
    login_name       VARCHAR(150)                                           NOT NULL COMMENT '嘗試登入帳號',
    login_result     ENUM ('success', 'failed', 'captcha_failed', 'locked') NOT NULL COMMENT '登入結果',
    captcha_passed   TINYINT(1)                                             NOT NULL DEFAULT 0 COMMENT '是否通過人機驗證',
    source_ip        VARCHAR(64)                                                     DEFAULT NULL COMMENT '來源 IP',
    user_agent       VARCHAR(500)                                                    DEFAULT NULL COMMENT '瀏覽器資訊',
    login_at         DATETIME                                               NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '登入時間',
    PRIMARY KEY (login_attempt_id),
    KEY idx_login_attempt_account (account_id),
    KEY idx_login_attempt_time (login_at),
    CONSTRAINT fk_login_attempt_account FOREIGN KEY (account_id) REFERENCES user_account (account_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '登入嘗試紀錄';

-- AUTH-04: 帳號啟活/註冊/重設密碼申請
CREATE TABLE IF NOT EXISTS account_activation_request
(
    activation_request_id BIGINT UNSIGNED                                                  NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    employee_id           BIGINT UNSIGNED                                                           DEFAULT NULL COMMENT '對應員工',
    employee_no           VARCHAR(50)                                                               DEFAULT NULL COMMENT '申請時填寫的員編',
    email                 VARCHAR(255)                                                              DEFAULT NULL COMMENT '申請時填寫的 Email',
    request_type          ENUM ('register', 'activate', 'reset_password')                  NOT NULL COMMENT '申請類型',
    request_status        ENUM ('pending', 'otp_sent', 'verified', 'approved', 'rejected', 'completed', 'expired')
                                                                                           NOT NULL DEFAULT 'pending' COMMENT '申請狀態',
    delivery_channel      ENUM ('email', 'portal')                                                   DEFAULT 'email' COMMENT '驗證送達管道',
    otp_code_hash         CHAR(64)                                                                  DEFAULT NULL COMMENT '六位 OTP 雜湊',
    otp_sent_at           DATETIME                                                                  DEFAULT NULL COMMENT 'OTP 發送時間',
    otp_expires_at        DATETIME                                                                  DEFAULT NULL COMMENT 'OTP 過期時間',
    otp_attempt_count     INT                                                              NOT NULL DEFAULT 0 COMMENT 'OTP 嘗試次數',
    verified_at           DATETIME                                                                  DEFAULT NULL COMMENT '驗證成功時間',
    used_at               DATETIME                                                                  DEFAULT NULL COMMENT '憑證使用時間',
    token                 VARCHAR(255)                                                              DEFAULT NULL COMMENT '延伸驗證 Token',
    token_expires_at      DATETIME                                                                  DEFAULT NULL COMMENT 'Token 過期時間',
    requested_at          DATETIME                                                         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申請時間',
    approved_at           DATETIME                                                                  DEFAULT NULL COMMENT '核准時間',
    approved_by           BIGINT UNSIGNED                                                           DEFAULT NULL COMMENT '核准人',
    note                  TEXT                                                                      DEFAULT NULL COMMENT '備註',
    is_deleted            TINYINT(1)                                                       NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_at            DATETIME                                                         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at            DATETIME                                                         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (activation_request_id),
    KEY idx_activation_employee (employee_id),
    KEY idx_activation_otp_expires (otp_expires_at),
    KEY idx_activation_token (token),
    CONSTRAINT fk_activation_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id),
    CONSTRAINT fk_activation_approver FOREIGN KEY (approved_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '帳號啟活/註冊/重設密碼申請';


-- ============================================================================
-- 模塊 ORG（續）：人員配置與責任範圍
-- ============================================================================

-- ORG-07: 人員角色與組織節點配置
CREATE TABLE IF NOT EXISTS employee_position_assignment
(
    assignment_id      BIGINT UNSIGNED                        NOT NULL AUTO_INCREMENT COMMENT '配置主鍵',
    employee_id        BIGINT UNSIGNED                        NOT NULL COMMENT '員工 ID',
    role_id            BIGINT UNSIGNED                        NOT NULL COMMENT '角色 ID',
    node_id            BIGINT UNSIGNED                        NOT NULL COMMENT '掛載組織節點 ID',
    assignment_status  ENUM ('active', 'inactive', 'expired') NOT NULL DEFAULT 'active' COMMENT '配置狀態',
    is_primary         TINYINT(1)                             NOT NULL DEFAULT 1 COMMENT '是否主職',
    effective_start_at DATETIME                                        DEFAULT NULL COMMENT '生效起始',
    effective_end_at   DATETIME                                        DEFAULT NULL COMMENT '生效結束',
    is_deleted         TINYINT(1)                             NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by         BIGINT UNSIGNED                                 DEFAULT NULL COMMENT '建立人',
    updated_by         BIGINT UNSIGNED                                 DEFAULT NULL COMMENT '更新人',
    created_at         DATETIME                               NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at         DATETIME                               NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (assignment_id),
    KEY idx_assignment_employee (employee_id),
    KEY idx_assignment_role (role_id),
    KEY idx_assignment_node (node_id),
    CONSTRAINT fk_assignment_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id),
    CONSTRAINT fk_assignment_role FOREIGN KEY (role_id) REFERENCES position_role (role_id),
    CONSTRAINT fk_assignment_node FOREIGN KEY (node_id) REFERENCES org_node (node_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '人員角色與組織節點配置';

-- ORG-08: 人員負責福利社範圍
CREATE TABLE IF NOT EXISTS employee_branch_responsibility
(
    responsibility_id  BIGINT UNSIGNED             NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    assignment_id      BIGINT UNSIGNED             NOT NULL COMMENT '配置 ID',
    welfare_branch_id  BIGINT UNSIGNED             NOT NULL COMMENT '負責福利社 ID',
    is_primary_contact TINYINT(1)                  NOT NULL DEFAULT 0 COMMENT '是否主要窗口',
    status             ENUM ('active', 'inactive') NOT NULL DEFAULT 'active' COMMENT '責任範圍狀態',
    is_deleted         TINYINT(1)                  NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by         BIGINT UNSIGNED                      DEFAULT NULL COMMENT '建立人',
    updated_by         BIGINT UNSIGNED                      DEFAULT NULL COMMENT '更新人',
    created_at         DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at         DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (responsibility_id),
    UNIQUE KEY uk_assignment_branch (assignment_id, welfare_branch_id),
    KEY idx_resp_branch (welfare_branch_id),
    CONSTRAINT fk_resp_assignment FOREIGN KEY (assignment_id) REFERENCES employee_position_assignment (assignment_id),
    CONSTRAINT fk_resp_branch FOREIGN KEY (welfare_branch_id) REFERENCES welfare_branch (welfare_branch_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '人員負責福利社範圍';


-- ============================================================================
-- 模塊 BEN：補助業務
-- ============================================================================

-- BEN-01: 補助/社團申請類型
CREATE TABLE IF NOT EXISTS application_type
(
    application_type_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    domain_code              VARCHAR(50)     NOT NULL COMMENT '領域：individual_subsidy/community_business',
    type_code                VARCHAR(50)     NOT NULL COMMENT '類型代碼',
    type_name                VARCHAR(100)    NOT NULL COMMENT '類型名稱',
    print_template_code      VARCHAR(50)              DEFAULT NULL COMMENT '列印模板代碼',
    requires_acknowledgement TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否需本人領款確認',
    requires_attachment      TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否需附件',
    max_amount               DECIMAL(12, 2)           DEFAULT NULL COMMENT '單次最高金額',
    annual_limit             INT                      DEFAULT NULL COMMENT '年度申請上限次數',
    is_active                TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    sort_order               INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_deleted               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by               BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by               BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (application_type_id),
    UNIQUE KEY uk_application_type (domain_code, type_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '補助/社團申請類型';

-- BEN-01A: 表單版本主檔
CREATE TABLE IF NOT EXISTS benefit_form_version
(
    benefit_form_version_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '表單版本主鍵',
    application_type_id     BIGINT UNSIGNED NOT NULL COMMENT '申請類型 ID',
    form_version            INT             NOT NULL COMMENT '表單版本',
    schema_code             VARCHAR(100)    NOT NULL COMMENT 'Schema 代碼',
    schema_json             JSON            NOT NULL COMMENT 'Schema 定義',
    effective_start_at      DATETIME                 DEFAULT NULL COMMENT '生效起始',
    effective_end_at        DATETIME                 DEFAULT NULL COMMENT '生效結束',
    is_active               TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_by              BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by              BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at              DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at              DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (benefit_form_version_id),
    UNIQUE KEY uk_benefit_form_version (application_type_id, form_version),
    CONSTRAINT fk_benefit_form_version_type FOREIGN KEY (application_type_id) REFERENCES application_type (application_type_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '補助表單版本主檔';

-- BEN-01B: 列印模板主檔
CREATE TABLE IF NOT EXISTS benefit_print_template
(
    benefit_print_template_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '列印模板主鍵',
    application_type_id       BIGINT UNSIGNED NOT NULL COMMENT '申請類型 ID',
    form_version              INT             NOT NULL COMMENT '表單版本',
    print_template_code       VARCHAR(100)    NOT NULL COMMENT '模板代碼',
    template_name             VARCHAR(150)    NOT NULL COMMENT '模板名稱',
    template_file_id          BIGINT UNSIGNED          DEFAULT NULL COMMENT '模板檔案 ID',
    is_active                 TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_by                BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by                BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at                DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at                DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (benefit_print_template_id),
    UNIQUE KEY uk_benefit_print_template (application_type_id, form_version, print_template_code),
    CONSTRAINT fk_benefit_print_template_type FOREIGN KEY (application_type_id) REFERENCES application_type (application_type_id),
    CONSTRAINT fk_benefit_print_template_file FOREIGN KEY (template_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '補助列印模板主檔';

-- BEN-01C: 年度上限規則
CREATE TABLE IF NOT EXISTS benefit_annual_limit_rule
(
    benefit_annual_limit_rule_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '年度上限規則主鍵',
    application_type_id          BIGINT UNSIGNED NOT NULL COMMENT '申請類型 ID',
    effective_year               INT             NOT NULL COMMENT '生效年度',
    limit_mode                   VARCHAR(50)     NOT NULL COMMENT '上限模式：count/amount/approval_count',
    limit_value                  DECIMAL(12, 2)  NOT NULL COMMENT '上限值',
    is_active                    TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_by                   BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by                   BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at                   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at                   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (benefit_annual_limit_rule_id),
    UNIQUE KEY uk_benefit_annual_limit_rule (application_type_id, effective_year, limit_mode),
    CONSTRAINT fk_benefit_annual_limit_rule_type FOREIGN KEY (application_type_id) REFERENCES application_type (application_type_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '補助年度上限規則';

-- BEN-02: 補助/社團申請主表
CREATE TABLE IF NOT EXISTS benefit_application
(
    application_id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    application_no             VARCHAR(50)     NOT NULL COMMENT '申請單號',
    applicant_employee_id      BIGINT UNSIGNED NOT NULL COMMENT '申請人',
    filler_employee_id         BIGINT UNSIGNED          DEFAULT NULL COMMENT '實際填寫人',
    application_type_id        BIGINT UNSIGNED NOT NULL COMMENT '申請類型',
    welfare_branch_id          BIGINT UNSIGNED          DEFAULT NULL COMMENT '承辦福利社',
    title                      VARCHAR(255)             DEFAULT NULL COMMENT '申請摘要',
    amount                     DECIMAL(12, 2)  NOT NULL DEFAULT 0.00 COMMENT '申請金額',
    status                     VARCHAR(50)     NOT NULL DEFAULT 'draft' COMMENT '主狀態（由 sys_dictionary: benefit_application_status 治理）',
    current_stage              VARCHAR(50)              DEFAULT NULL COMMENT '當前階段',
    physical_stamp_status      VARCHAR(50)     NOT NULL DEFAULT 'not_required' COMMENT '實體核章狀態',
    is_proxy_filed             TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否代理填發',
    proxy_label                VARCHAR(100)             DEFAULT NULL COMMENT '代理標籤',
    declaration_checked        TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否勾選數位切結',
    declaration_checked_at     DATETIME                 DEFAULT NULL COMMENT '切結勾選時間',
    form_version               INT             NOT NULL DEFAULT 1 COMMENT '表單版本',
    revision                   INT             NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    pdf_generated_at           DATETIME                 DEFAULT NULL COMMENT 'PDF 產製時間',
    pdf_printed_at             DATETIME                 DEFAULT NULL COMMENT 'PDF 列印時間',
    latest_validation_summary  VARCHAR(255)             DEFAULT NULL COMMENT '最近規則結果摘要',
    ai_recognition_status      VARCHAR(50)              DEFAULT NULL COMMENT 'AI 辨識狀態',
    ai_recognition_summary     VARCHAR(255)             DEFAULT NULL COMMENT 'AI 辨識摘要',
    pending_payment_flag       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已進待發款',
    returned_reason            TEXT                     DEFAULT NULL COMMENT '最近退回原因',
    rejected_reason            TEXT                     DEFAULT NULL COMMENT '最近駁回原因',
    submitted_at               DATETIME                 DEFAULT NULL COMMENT '送出時間',
    approved_at                DATETIME                 DEFAULT NULL COMMENT '核定時間',
    physical_stamp_received_at DATETIME                 DEFAULT NULL COMMENT '收到核章紙本時間',
    physical_stamp_received_by BIGINT UNSIGNED          DEFAULT NULL COMMENT '確認收到核章紙本者',
    closed_at                  DATETIME                 DEFAULT NULL COMMENT '結案時間',
    note                       TEXT                     DEFAULT NULL COMMENT '備註',
    is_deleted                 TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by                 BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by                 BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at                 DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at                 DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (application_id),
    UNIQUE KEY uk_application_no (application_no),
    KEY idx_application_applicant (applicant_employee_id),
    KEY idx_application_filler (filler_employee_id),
    KEY idx_application_type (application_type_id),
    KEY idx_application_branch (welfare_branch_id),
    KEY idx_application_status_time (status, created_at),
    KEY idx_application_created_type (application_type_id, created_at),
    KEY idx_application_branch_status (welfare_branch_id, status),
    CONSTRAINT fk_application_employee FOREIGN KEY (applicant_employee_id) REFERENCES employee (employee_id),
    CONSTRAINT fk_application_filler FOREIGN KEY (filler_employee_id) REFERENCES employee (employee_id),
    CONSTRAINT fk_application_type FOREIGN KEY (application_type_id) REFERENCES application_type (application_type_id),
    CONSTRAINT fk_application_branch FOREIGN KEY (welfare_branch_id) REFERENCES welfare_branch (welfare_branch_id),
    CONSTRAINT fk_application_stamp_receiver FOREIGN KEY (physical_stamp_received_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '補助/社團申請主表';

-- BEN-03: 申請表單快照
CREATE TABLE IF NOT EXISTS benefit_application_form
(
    application_form_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    application_id      BIGINT UNSIGNED NOT NULL COMMENT '申請 ID',
    form_version        INT             NOT NULL DEFAULT 1 COMMENT '表單版本',
    schema_code         VARCHAR(100)             DEFAULT NULL COMMENT '表單 Schema 代碼',
    print_template_code VARCHAR(50)              DEFAULT NULL COMMENT '列印模板代碼',
    form_payload_json   JSON            NOT NULL COMMENT '表單資料 JSON',
    printed_preview_url VARCHAR(500)             DEFAULT NULL COMMENT '列印預覽 URL',
    snapshot_version    INT             NOT NULL DEFAULT 1 COMMENT '快照版本',
    created_by          BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (application_form_id),
    KEY idx_form_application (application_id),
    KEY idx_form_application_version (application_id, form_version, snapshot_version),
    CONSTRAINT fk_form_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '申請表單快照';

-- BEN-04: 申請附件
CREATE TABLE IF NOT EXISTS benefit_application_attachment
(
    attachment_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '申請 ID',
    file_id         BIGINT UNSIGNED NOT NULL COMMENT '統一檔案 ID（正式來源）',
    attachment_type VARCHAR(50)     NOT NULL COMMENT '附件類型：certificate/receipt/invoice/photo/approval_doc',
    file_note       VARCHAR(255)             DEFAULT NULL COMMENT '附件備註',
    uploaded_by     BIGINT UNSIGNED          DEFAULT NULL COMMENT '上傳人',
    uploaded_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '上傳時間',
    is_deleted      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    PRIMARY KEY (attachment_id),
    KEY idx_attachment_application (application_id),
    KEY idx_attachment_file (file_id),
    CONSTRAINT fk_attachment_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_attachment_file FOREIGN KEY (file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '申請附件';

-- BEN-05: 送審前校驗結果
CREATE TABLE IF NOT EXISTS benefit_validation_result
(
    validation_result_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '校驗結果主鍵',
    application_id       BIGINT UNSIGNED NOT NULL COMMENT '申請 ID',
    validation_code      VARCHAR(50)     NOT NULL COMMENT '校驗代碼：eligibility/attachment/annual_limit/duplicate_check',
    validation_status    VARCHAR(50)     NOT NULL COMMENT '校驗結果：passed/failed/warning',
    validation_message   VARCHAR(500)             DEFAULT NULL COMMENT '校驗訊息',
    result_payload_json  JSON                     DEFAULT NULL COMMENT '結果明細 JSON',
    validated_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '校驗時間',
    PRIMARY KEY (validation_result_id),
    KEY idx_validation_application (application_id),
    KEY idx_validation_code_status (validation_code, validation_status),
    CONSTRAINT fk_validation_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '補助送審前校驗結果';

-- BEN-06: 實體核章檢核點
CREATE TABLE IF NOT EXISTS benefit_application_paper_checkpoint
(
    paper_checkpoint_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '紙本檢核主鍵',
    application_id      BIGINT UNSIGNED NOT NULL COMMENT '申請 ID',
    checkpoint_status   VARCHAR(50)     NOT NULL COMMENT '檢核狀態：printed/submitted_to_hr/stamped/received_by_branch/returned_to_applicant',
    verified_by         BIGINT UNSIGNED          DEFAULT NULL COMMENT '確認人',
    verified_at         DATETIME                 DEFAULT NULL COMMENT '確認時間',
    paper_file_id       BIGINT UNSIGNED          DEFAULT NULL COMMENT '紙本掃描檔案 ID',
    note                VARCHAR(255)             DEFAULT NULL COMMENT '備註',
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (paper_checkpoint_id),
    KEY idx_paper_checkpoint_application (application_id),
    KEY idx_paper_checkpoint_status (checkpoint_status),
    CONSTRAINT fk_paper_checkpoint_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_paper_checkpoint_verifier FOREIGN KEY (verified_by) REFERENCES employee (employee_id),
    CONSTRAINT fk_paper_checkpoint_file FOREIGN KEY (paper_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '補助實體核章檢核點';

-- PAY-00: 報銷單主表
CREATE TABLE IF NOT EXISTS reimbursement_sheet
(
    reimbursement_sheet_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '報銷單主鍵',
    sheet_no               VARCHAR(50)     NOT NULL COMMENT '報銷單號',
    sheet_type             VARCHAR(50)     NOT NULL DEFAULT 'application_reimbursement' COMMENT '報銷單類型',
    project_type           VARCHAR(50)              DEFAULT NULL COMMENT '專案類型：gift_project/regular',
    welfare_branch_id      BIGINT UNSIGNED NOT NULL COMMENT '福利社 ID',
    sheet_status           VARCHAR(50)     NOT NULL DEFAULT 'draft' COMMENT '報銷單狀態',
    total_count            INT             NOT NULL DEFAULT 0 COMMENT '總筆數',
    total_amount           DECIMAL(12, 2)  NOT NULL DEFAULT 0.00 COMMENT '總金額',
    summary_file_id        BIGINT UNSIGNED          DEFAULT NULL COMMENT '彙總總表檔案',
    detail_file_id         BIGINT UNSIGNED          DEFAULT NULL COMMENT '明細附件檔案',
    voucher_file_id        BIGINT UNSIGNED          DEFAULT NULL COMMENT '傳票檔案',
    revision               INT             NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    submitted_at           DATETIME                 DEFAULT NULL COMMENT '送審時間',
    approved_at            DATETIME                 DEFAULT NULL COMMENT '核准時間',
    archived_at            DATETIME                 DEFAULT NULL COMMENT '封存時間',
    created_by             BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by             BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (reimbursement_sheet_id),
    UNIQUE KEY uk_reimbursement_sheet_no (sheet_no),
    KEY idx_reimbursement_sheet_branch (welfare_branch_id),
    KEY idx_reimbursement_sheet_status (sheet_status),
    CONSTRAINT fk_reimbursement_sheet_branch FOREIGN KEY (welfare_branch_id) REFERENCES welfare_branch (welfare_branch_id),
    CONSTRAINT fk_reimbursement_sheet_summary_file FOREIGN KEY (summary_file_id) REFERENCES file_resource (file_id),
    CONSTRAINT fk_reimbursement_sheet_detail_file FOREIGN KEY (detail_file_id) REFERENCES file_resource (file_id),
    CONSTRAINT fk_reimbursement_sheet_voucher_file FOREIGN KEY (voucher_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '報銷單主表';

-- PAY-00A: 報銷單明細
CREATE TABLE IF NOT EXISTS reimbursement_sheet_item
(
    reimbursement_sheet_item_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '報銷單明細主鍵',
    reimbursement_sheet_id      BIGINT UNSIGNED NOT NULL COMMENT '報銷單 ID',
    application_id              BIGINT UNSIGNED          DEFAULT NULL COMMENT '關聯申請 ID',
    payment_batch_id            BIGINT UNSIGNED          DEFAULT NULL COMMENT '關聯發款批次 ID',
    item_label                  VARCHAR(255)    NOT NULL COMMENT '明細名稱',
    item_amount                 DECIMAL(12, 2)  NOT NULL DEFAULT 0.00 COMMENT '明細金額',
    sort_order                  INT             NOT NULL DEFAULT 0 COMMENT '排序',
    created_at                  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (reimbursement_sheet_item_id),
    KEY idx_reimbursement_sheet_item_sheet (reimbursement_sheet_id),
    CONSTRAINT fk_reimbursement_sheet_item_sheet FOREIGN KEY (reimbursement_sheet_id) REFERENCES reimbursement_sheet (reimbursement_sheet_id),
    CONSTRAINT fk_reimbursement_sheet_item_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '報銷單明細';


-- ============================================================================
-- 模塊 PAY：發款管理
-- ============================================================================

-- PAY-01: 發款/報銷批次
CREATE TABLE IF NOT EXISTS payment_batch
(
    payment_batch_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    batch_no              VARCHAR(50)     NOT NULL COMMENT '批次編號',
    batch_type            VARCHAR(50)     NOT NULL DEFAULT 'standard' COMMENT '批次類型：standard/reimbursement/gift_project',
    reimbursement_sheet_id BIGINT UNSIGNED         DEFAULT NULL COMMENT '關聯報銷單',
    welfare_branch_id     BIGINT UNSIGNED NOT NULL COMMENT '福利社 ID',
    item_count            INT             NOT NULL DEFAULT 0 COMMENT '申請數量',
    total_amount          DECIMAL(12, 2)  NOT NULL DEFAULT 0.00 COMMENT '總額',
    status                VARCHAR(50)     NOT NULL DEFAULT 'draft' COMMENT '批次狀態（由 sys_dictionary: payment_batch_status 治理）',
    current_stage         VARCHAR(50)              DEFAULT NULL COMMENT '當前階段',
    revision              INT             NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    submitted_at          DATETIME                 DEFAULT NULL COMMENT '送審時間',
    approved_at           DATETIME                 DEFAULT NULL COMMENT '核准時間',
    disbursed_at          DATETIME                 DEFAULT NULL COMMENT '撥款回填完成時間',
    archived_at           DATETIME                 DEFAULT NULL COMMENT '封存時間',
    voucher_no            VARCHAR(50)              DEFAULT NULL COMMENT '傳票號碼',
    voucher_file_id       BIGINT UNSIGNED          DEFAULT NULL COMMENT '傳票檔案 ID',
    is_deleted            TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by            BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by            BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (payment_batch_id),
    UNIQUE KEY uk_batch_no (batch_no),
    KEY idx_batch_branch (welfare_branch_id),
    KEY idx_batch_status (status),
    KEY idx_batch_reimbursement (reimbursement_sheet_id),
    KEY idx_batch_type_status (batch_type, status),
    CONSTRAINT fk_batch_reimbursement_sheet FOREIGN KEY (reimbursement_sheet_id) REFERENCES reimbursement_sheet (reimbursement_sheet_id),
    CONSTRAINT fk_batch_branch FOREIGN KEY (welfare_branch_id) REFERENCES welfare_branch (welfare_branch_id),
    CONSTRAINT fk_batch_voucher_file FOREIGN KEY (voucher_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '發款/報銷批次';

-- PAY-02: 發款批次明細
CREATE TABLE IF NOT EXISTS payment_batch_item
(
    payment_batch_item_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    payment_batch_id       BIGINT UNSIGNED NOT NULL COMMENT '批次 ID',
    application_id         BIGINT UNSIGNED NOT NULL COMMENT '申請 ID',
    application_no_snapshot VARCHAR(50)             DEFAULT NULL COMMENT '申請單號快照',
    applicant_employee_id  BIGINT UNSIGNED          DEFAULT NULL COMMENT '申請人快照關聯',
    amount                 DECIMAL(12, 2)  NOT NULL DEFAULT 0.00 COMMENT '撥款金額',
    status                 VARCHAR(50)     NOT NULL DEFAULT 'pending' COMMENT '明細狀態（由 sys_dictionary: payment_batch_item_status 治理）',
    acknowledgement_status VARCHAR(50)     NOT NULL DEFAULT 'pending' COMMENT '領款確認狀態快照',
    disbursed_at           DATETIME                 DEFAULT NULL COMMENT '明細撥款時間',
    note                   TEXT                     DEFAULT NULL COMMENT '備註',
    is_deleted             TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by             BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by             BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (payment_batch_item_id),
    UNIQUE KEY uk_batch_application (payment_batch_id, application_id),
    KEY idx_item_application (application_id),
    KEY idx_item_status (status),
    KEY idx_item_ack_status (acknowledgement_status),
    CONSTRAINT fk_item_batch FOREIGN KEY (payment_batch_id) REFERENCES payment_batch (payment_batch_id),
    CONSTRAINT fk_item_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_item_applicant FOREIGN KEY (applicant_employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '發款批次明細';

-- PAY-03: 領款確認紀錄
CREATE TABLE IF NOT EXISTS payment_acknowledgement
(
    acknowledgement_id     BIGINT UNSIGNED                           NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    payment_batch_item_id  BIGINT UNSIGNED                           NOT NULL COMMENT '對應明細',
    employee_id            BIGINT UNSIGNED                           NOT NULL COMMENT '確認人',
    acknowledgement_status ENUM ('pending', 'confirmed', 'disputed') NOT NULL DEFAULT 'pending' COMMENT '領款確認狀態',
    acknowledged_at        DATETIME                                           DEFAULT NULL COMMENT '確認時間',
    disputed_at            DATETIME                                           DEFAULT NULL COMMENT '異議提出時間',
    dispute_reason         TEXT                                               DEFAULT NULL COMMENT '異議原因',
    channel                ENUM ('portal', 'offline', 'admin_proxy') NOT NULL DEFAULT 'portal' COMMENT '確認管道',
    satisfaction_rating    TINYINT UNSIGNED                                   DEFAULT NULL COMMENT '服務滿意度 1-5',
    satisfaction_comment   VARCHAR(500)                                       DEFAULT NULL COMMENT '服務回饋',
    receipt_file_id        BIGINT UNSIGNED                                    DEFAULT NULL COMMENT '收執明細檔案 ID',
    revision               INT                                       NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    note                   TEXT                                               DEFAULT NULL COMMENT '備註',
    is_deleted             TINYINT(1)                                NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by             BIGINT UNSIGNED                                    DEFAULT NULL COMMENT '建立人',
    updated_by             BIGINT UNSIGNED                                    DEFAULT NULL COMMENT '更新人',
    created_at             DATETIME                                  NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at             DATETIME                                  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (acknowledgement_id),
    UNIQUE KEY uk_ack_item (payment_batch_item_id),
    CONSTRAINT fk_ack_item FOREIGN KEY (payment_batch_item_id) REFERENCES payment_batch_item (payment_batch_item_id),
    CONSTRAINT fk_ack_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id),
    CONSTRAINT fk_ack_receipt_file FOREIGN KEY (receipt_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '領款確認紀錄';

-- PAY-04: 領款異議案件
CREATE TABLE IF NOT EXISTS payment_dispute_case
(
    payment_dispute_case_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '異議案件主鍵',
    dispute_case_no         VARCHAR(50)     NOT NULL COMMENT '異議單號',
    payment_batch_item_id   BIGINT UNSIGNED NOT NULL COMMENT '對應批次明細',
    payment_batch_id        BIGINT UNSIGNED NOT NULL COMMENT '對應批次',
    application_id          BIGINT UNSIGNED NOT NULL COMMENT '對應申請',
    employee_id             BIGINT UNSIGNED NOT NULL COMMENT '提出異議職工',
    dispute_status          VARCHAR(50)     NOT NULL DEFAULT 'open' COMMENT '異議狀態',
    dispute_reason          TEXT            NOT NULL COMMENT '異議原因',
    latest_comment          VARCHAR(500)             DEFAULT NULL COMMENT '最近處理說明',
    resolved_at             DATETIME                 DEFAULT NULL COMMENT '解決時間',
    resolved_by             BIGINT UNSIGNED          DEFAULT NULL COMMENT '解決人',
    revision                INT             NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    created_by              BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by              BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at              DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at              DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (payment_dispute_case_id),
    UNIQUE KEY uk_payment_dispute_case_no (dispute_case_no),
    UNIQUE KEY uk_payment_dispute_batch_item (payment_batch_item_id),
    KEY idx_payment_dispute_status (dispute_status),
    KEY idx_payment_dispute_batch (payment_batch_id),
    CONSTRAINT fk_payment_dispute_item FOREIGN KEY (payment_batch_item_id) REFERENCES payment_batch_item (payment_batch_item_id),
    CONSTRAINT fk_payment_dispute_batch FOREIGN KEY (payment_batch_id) REFERENCES payment_batch (payment_batch_id),
    CONSTRAINT fk_payment_dispute_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_payment_dispute_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id),
    CONSTRAINT fk_payment_dispute_resolver FOREIGN KEY (resolved_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '領款異議案件';


-- ============================================================================
-- 模塊 WF：共用流程引擎
-- ============================================================================

-- WF-01: 流程模板（新增）
CREATE TABLE IF NOT EXISTS workflow_template
(
    template_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '模板主鍵',
    template_code    VARCHAR(50)     NOT NULL COMMENT '模板代碼',
    template_name    VARCHAR(100)    NOT NULL COMMENT '模板名稱',
    business_type    VARCHAR(50)     NOT NULL COMMENT '適用業務類型',
    step_count       INT             NOT NULL DEFAULT 0 COMMENT '節點數量',
    description_text TEXT                     DEFAULT NULL COMMENT '說明',
    version_no       INT             NOT NULL DEFAULT 1 COMMENT '模板版本',
    is_active        TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (template_id),
    UNIQUE KEY uk_template_code (template_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '流程模板';

-- WF-02: 流程模板節點（新增）
CREATE TABLE IF NOT EXISTS workflow_template_step
(
    template_step_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '模板節點主鍵',
    template_id      BIGINT UNSIGNED NOT NULL COMMENT '模板 ID',
    step_code        VARCHAR(50)     NOT NULL COMMENT '節點代碼',
    step_name        VARCHAR(100)    NOT NULL COMMENT '節點名稱',
    step_order       INT             NOT NULL COMMENT '節點順序',
    default_role_id  BIGINT UNSIGNED          DEFAULT NULL COMMENT '預設處理角色',
    timeout_hours    INT                      DEFAULT NULL COMMENT '超時時數',
    auto_action      VARCHAR(50)              DEFAULT 'none' COMMENT '超時動作：none/escalate/auto_approve',
    is_deleted       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (template_step_id),
    UNIQUE KEY uk_template_step (template_id, step_code),
    KEY idx_template_step_role (default_role_id),
    CONSTRAINT fk_tmpl_step_template FOREIGN KEY (template_id) REFERENCES workflow_template (template_id),
    CONSTRAINT fk_tmpl_step_role FOREIGN KEY (default_role_id) REFERENCES position_role (role_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '流程模板節點';

-- WF-03: 共用流程主表
CREATE TABLE IF NOT EXISTS workflow_instance
(
    workflow_instance_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '流程主鍵',
    template_id          BIGINT UNSIGNED          DEFAULT NULL COMMENT '來源模板 ID',
    business_type        VARCHAR(50)     NOT NULL COMMENT '業務類型',
    business_id          BIGINT UNSIGNED NOT NULL COMMENT '業務主鍵值',
    workflow_code        VARCHAR(50)              DEFAULT NULL COMMENT '流程代碼',
    workflow_status      VARCHAR(50)     NOT NULL DEFAULT 'draft' COMMENT '流程狀態（由 sys_dictionary: workflow_status 治理）',
    current_step_code    VARCHAR(50)              DEFAULT NULL COMMENT '當前節點代碼',
    revision             INT             NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    submitted_by         BIGINT UNSIGNED          DEFAULT NULL COMMENT '送審人',
    submitted_at         DATETIME                 DEFAULT NULL COMMENT '送審時間',
    closed_at            DATETIME                 DEFAULT NULL COMMENT '結案時間',
    is_deleted           TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by           BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by           BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (workflow_instance_id),
    KEY idx_workflow_business (business_type, business_id),
    KEY idx_workflow_status (workflow_status),
    KEY idx_workflow_template (template_id),
    CONSTRAINT fk_workflow_template FOREIGN KEY (template_id) REFERENCES workflow_template (template_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '共用流程主表';

-- WF-04: 共用流程節點
CREATE TABLE IF NOT EXISTS workflow_step
(
    workflow_step_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '節點主鍵',
    workflow_instance_id BIGINT UNSIGNED NOT NULL COMMENT '流程主表 ID',
    step_code            VARCHAR(50)     NOT NULL COMMENT '節點代碼',
    step_name            VARCHAR(100)    NOT NULL COMMENT '節點名稱',
    step_order           INT             NOT NULL COMMENT '節點順序',
    assignee_role_id     BIGINT UNSIGNED          DEFAULT NULL COMMENT '應處理角色',
    assignee_employee_id BIGINT UNSIGNED          DEFAULT NULL COMMENT '指定處理人',
    step_status          VARCHAR(50)     NOT NULL DEFAULT 'pending' COMMENT '節點狀態（由 sys_dictionary: workflow_step_status 治理）',
    started_at           DATETIME                 DEFAULT NULL COMMENT '開始時間',
    ended_at             DATETIME                 DEFAULT NULL COMMENT '結束時間',
    due_at               DATETIME                 DEFAULT NULL COMMENT '到期時間',
    note                 TEXT                     DEFAULT NULL COMMENT '備註',
    created_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (workflow_step_id),
    KEY idx_step_instance (workflow_instance_id),
    KEY idx_step_role (assignee_role_id),
    KEY idx_step_employee (assignee_employee_id),
    CONSTRAINT fk_step_instance FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instance (workflow_instance_id),
    CONSTRAINT fk_step_role FOREIGN KEY (assignee_role_id) REFERENCES position_role (role_id),
    CONSTRAINT fk_step_employee FOREIGN KEY (assignee_employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '共用流程節點';

-- WF-05: 共用流程操作紀錄
CREATE TABLE IF NOT EXISTS workflow_action_log
(
    workflow_action_log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    workflow_instance_id   BIGINT UNSIGNED NOT NULL COMMENT '流程主表 ID',
    workflow_step_id       BIGINT UNSIGNED          DEFAULT NULL COMMENT '流程節點 ID',
    action_type            VARCHAR(50)     NOT NULL COMMENT '操作：submit/approve/reject/return/cancel/confirm',
    action_by              BIGINT UNSIGNED          DEFAULT NULL COMMENT '操作人',
    action_note            TEXT                     DEFAULT NULL COMMENT '操作說明',
    action_at              DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作時間',
    PRIMARY KEY (workflow_action_log_id),
    KEY idx_action_instance (workflow_instance_id),
    KEY idx_action_step (workflow_step_id),
    CONSTRAINT fk_action_instance FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instance (workflow_instance_id),
    CONSTRAINT fk_action_step FOREIGN KEY (workflow_step_id) REFERENCES workflow_step (workflow_step_id),
    CONSTRAINT fk_action_employee FOREIGN KEY (action_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '共用流程操作紀錄';

-- WF-06: 共用待辦任務
CREATE TABLE IF NOT EXISTS review_task
(
    review_task_id       BIGINT UNSIGNED                       NOT NULL AUTO_INCREMENT COMMENT '待辦主鍵',
    business_type        VARCHAR(50)                           NOT NULL COMMENT '業務類型',
    business_id          BIGINT UNSIGNED                       NOT NULL COMMENT '業務主鍵值',
    workflow_instance_id BIGINT UNSIGNED                                DEFAULT NULL COMMENT '流程主表 ID',
    workflow_step_id     BIGINT UNSIGNED                                DEFAULT NULL COMMENT '流程節點 ID',
    assignee_employee_id BIGINT UNSIGNED                                DEFAULT NULL COMMENT '待辦指派人',
    assignee_role_id     BIGINT UNSIGNED                                DEFAULT NULL COMMENT '待辦指派角色',
    task_status          VARCHAR(50)                           NOT NULL DEFAULT 'pending' COMMENT '待辦狀態（由 sys_dictionary: review_task_status 治理）',
    urgency_level        ENUM ('normal', 'urgent', 'critical') NOT NULL DEFAULT 'normal' COMMENT '急迫程度',
    due_at               DATETIME                                       DEFAULT NULL COMMENT '到期時間',
    completed_at         DATETIME                                       DEFAULT NULL COMMENT '完成時間',
    is_deleted           TINYINT(1)                            NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_at           DATETIME                              NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at           DATETIME                              NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (review_task_id),
    KEY idx_task_assignee (assignee_employee_id),
    KEY idx_task_role (assignee_role_id),
    KEY idx_task_status (task_status),
    KEY idx_task_business (business_type, business_id),
    CONSTRAINT fk_task_instance FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instance (workflow_instance_id),
    CONSTRAINT fk_task_step FOREIGN KEY (workflow_step_id) REFERENCES workflow_step (workflow_step_id),
    CONSTRAINT fk_task_employee FOREIGN KEY (assignee_employee_id) REFERENCES employee (employee_id),
    CONSTRAINT fk_task_role FOREIGN KEY (assignee_role_id) REFERENCES position_role (role_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '共用待辦任務';

-- WF-07: 流程事件流
CREATE TABLE IF NOT EXISTS workflow_event
(
    workflow_event_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '流程事件主鍵',
    workflow_instance_id  BIGINT UNSIGNED NOT NULL COMMENT '流程實例 ID',
    workflow_step_id      BIGINT UNSIGNED          DEFAULT NULL COMMENT '流程節點 ID',
    review_task_id        BIGINT UNSIGNED          DEFAULT NULL COMMENT '待辦 ID',
    business_type         VARCHAR(50)     NOT NULL COMMENT '業務類型',
    business_id           BIGINT UNSIGNED NOT NULL COMMENT '業務主鍵',
    event_type            VARCHAR(50)     NOT NULL COMMENT '事件類型',
    event_status          VARCHAR(50)     NOT NULL DEFAULT 'created' COMMENT '事件狀態',
    payload_json          JSON                     DEFAULT NULL COMMENT '事件內容',
    created_by            BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    created_at            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (workflow_event_id),
    KEY idx_workflow_event_instance (workflow_instance_id, event_type),
    KEY idx_workflow_event_business (business_type, business_id),
    CONSTRAINT fk_workflow_event_instance FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instance (workflow_instance_id),
    CONSTRAINT fk_workflow_event_step FOREIGN KEY (workflow_step_id) REFERENCES workflow_step (workflow_step_id),
    CONSTRAINT fk_workflow_event_task FOREIGN KEY (review_task_id) REFERENCES review_task (review_task_id),
    CONSTRAINT fk_workflow_event_creator FOREIGN KEY (created_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '流程事件流';

-- WF-08: 流程超時掃描執行紀錄
CREATE TABLE IF NOT EXISTS workflow_timeout_scan_run
(
    workflow_timeout_scan_run_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '超時掃描主鍵',
    started_at                   DATETIME        NOT NULL COMMENT '開始時間',
    finished_at                  DATETIME                 DEFAULT NULL COMMENT '結束時間',
    scanned_task_count           INT             NOT NULL DEFAULT 0 COMMENT '掃描任務數',
    timeout_hit_count            INT             NOT NULL DEFAULT 0 COMMENT '超時命中數',
    event_created_count          INT             NOT NULL DEFAULT 0 COMMENT '事件建立數',
    notify_triggered_count       INT             NOT NULL DEFAULT 0 COMMENT '通知觸發數',
    failed_count                 INT             NOT NULL DEFAULT 0 COMMENT '失敗數',
    run_status                   VARCHAR(50)     NOT NULL DEFAULT 'running' COMMENT '執行狀態',
    summary_text                 VARCHAR(255)             DEFAULT NULL COMMENT '摘要',
    created_at                   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (workflow_timeout_scan_run_id),
    KEY idx_workflow_timeout_scan_started (started_at),
    KEY idx_workflow_timeout_scan_status (run_status)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '流程超時掃描執行紀錄';


-- ============================================================================
-- 模塊 MCH：特約商店
-- ============================================================================

-- MCH-01: 特約商店分類
CREATE TABLE IF NOT EXISTS merchant_category
(
    category_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    category_code VARCHAR(50)     NOT NULL COMMENT '分類代碼',
    category_name VARCHAR(100)    NOT NULL COMMENT '分類名稱',
    sort_order    INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active     TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by    BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by    BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (category_id),
    UNIQUE KEY uk_merchant_category_code (category_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '特約商店分類';

-- MCH-02: 特約商店主表
CREATE TABLE IF NOT EXISTS contract_merchant
(
    merchant_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    merchant_code    VARCHAR(50)              DEFAULT NULL COMMENT '商店代碼',
    merchant_name    VARCHAR(255)    NOT NULL COMMENT '商店名稱',
    category_id      BIGINT UNSIGNED          DEFAULT NULL COMMENT '分類 ID',
    merchant_type    VARCHAR(50)              DEFAULT NULL COMMENT '商店型態：chain/single/hotel/clinic',
    region_scope     VARCHAR(100)             DEFAULT NULL COMMENT '適用區域',
    store_scope_text VARCHAR(255)             DEFAULT NULL COMMENT '門市範圍描述',
    merchant_status  VARCHAR(50)     NOT NULL DEFAULT 'draft' COMMENT '商店狀態（由 sys_dictionary: merchant_status 治理）',
    is_deleted       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (merchant_id),
    KEY idx_merchant_category (category_id),
    KEY idx_merchant_status (merchant_status),
    CONSTRAINT fk_merchant_category FOREIGN KEY (category_id) REFERENCES merchant_category (category_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '特約商店主表';

-- MCH-03: 特約商店合約
CREATE TABLE IF NOT EXISTS merchant_contract
(
    contract_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    merchant_id          BIGINT UNSIGNED NOT NULL COMMENT '商店 ID',
    contract_version     INT             NOT NULL DEFAULT 1 COMMENT '合約版本',
    contract_start_at    DATETIME        NOT NULL COMMENT '合約起始',
    contract_end_at      DATETIME        NOT NULL COMMENT '合約結束',
    contract_status      VARCHAR(50)     NOT NULL DEFAULT 'draft' COMMENT '合約狀態（由 sys_dictionary: merchant_contract_status 治理）',
    benefit_summary      VARCHAR(255)             DEFAULT NULL COMMENT '優惠摘要',
    revision             INT             NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    review_note          TEXT                     DEFAULT NULL COMMENT '審核備註',
    signed_file_id       BIGINT UNSIGNED          DEFAULT NULL COMMENT '簽署合約檔案 ID',
    previous_contract_id BIGINT UNSIGNED          DEFAULT NULL COMMENT '前一版合約 ID',
    is_deleted           TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by           BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by           BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (contract_id),
    UNIQUE KEY uk_merchant_contract_version (merchant_id, contract_version),
    KEY idx_contract_merchant (merchant_id),
    KEY idx_contract_status (contract_status),
    KEY idx_contract_date_range (contract_start_at, contract_end_at),
    CONSTRAINT chk_contract_date_range CHECK (contract_end_at > contract_start_at),
    CONSTRAINT fk_contract_merchant FOREIGN KEY (merchant_id) REFERENCES contract_merchant (merchant_id),
    CONSTRAINT fk_contract_signed_file FOREIGN KEY (signed_file_id) REFERENCES file_resource (file_id),
    CONSTRAINT fk_contract_previous FOREIGN KEY (previous_contract_id) REFERENCES merchant_contract (contract_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '特約商店合約';

-- MCH-04: 商店優惠內容
CREATE TABLE IF NOT EXISTS merchant_benefit
(
    benefit_id      BIGINT UNSIGNED             NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    contract_id     BIGINT UNSIGNED             NOT NULL COMMENT '合約 ID',
    benefit_title   VARCHAR(255)                         DEFAULT NULL COMMENT '優惠標題',
    benefit_summary VARCHAR(255)                NOT NULL COMMENT '優惠摘要',
    benefit_detail  TEXT                                 DEFAULT NULL COMMENT '優惠詳細規則',
    discount_value  DECIMAL(8, 2)                        DEFAULT NULL COMMENT '折扣數值',
    status          ENUM ('active', 'inactive') NOT NULL DEFAULT 'active' COMMENT '狀態',
    is_deleted      TINYINT(1)                  NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by      BIGINT UNSIGNED                      DEFAULT NULL COMMENT '建立人',
    updated_by      BIGINT UNSIGNED                      DEFAULT NULL COMMENT '更新人',
    created_at      DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at      DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (benefit_id),
    KEY idx_benefit_contract (contract_id),
    CONSTRAINT fk_benefit_contract FOREIGN KEY (contract_id) REFERENCES merchant_contract (contract_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '商店優惠內容';

-- MCH-05: 商店適用對象規則
CREATE TABLE IF NOT EXISTS merchant_eligibility_rule
(
    rule_id         BIGINT UNSIGNED                                          NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    contract_id     BIGINT UNSIGNED                                          NOT NULL COMMENT '合約 ID',
    audience_type   ENUM ('employee', 'contract_staff', 'retired', 'family') NOT NULL COMMENT '適用對象',
    usage_rule_text TEXT                                                     NOT NULL COMMENT '使用規則說明',
    status          ENUM ('active', 'inactive')                              NOT NULL DEFAULT 'active' COMMENT '狀態',
    is_deleted      TINYINT(1)                                               NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by      BIGINT UNSIGNED                                                   DEFAULT NULL COMMENT '建立人',
    updated_by      BIGINT UNSIGNED                                                   DEFAULT NULL COMMENT '更新人',
    created_at      DATETIME                                                 NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at      DATETIME                                                 NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (rule_id),
    KEY idx_rule_contract (contract_id),
    CONSTRAINT fk_rule_contract FOREIGN KEY (contract_id) REFERENCES merchant_contract (contract_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '商店適用對象規則';

-- MCH-06: 商店聯絡據點
CREATE TABLE IF NOT EXISTS merchant_contact_point
(
    contact_point_id BIGINT UNSIGNED             NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    contract_id      BIGINT UNSIGNED             NOT NULL COMMENT '合約 ID',
    point_name       VARCHAR(255)                         DEFAULT NULL COMMENT '據點名稱',
    address_text     VARCHAR(255)                         DEFAULT NULL COMMENT '地址',
    latitude         DECIMAL(10, 7)                      DEFAULT NULL COMMENT '緯度',
    longitude        DECIMAL(10, 7)                      DEFAULT NULL COMMENT '經度',
    business_hours   VARCHAR(255)                        DEFAULT NULL COMMENT '營業時間',
    is_primary       TINYINT(1)                  NOT NULL DEFAULT 0 COMMENT '是否主要據點',
    contact_phone    VARCHAR(50)                          DEFAULT NULL COMMENT '電話',
    contact_email    VARCHAR(255)                         DEFAULT NULL COMMENT 'Email',
    status           ENUM ('active', 'inactive') NOT NULL DEFAULT 'active' COMMENT '狀態',
    is_deleted       TINYINT(1)                  NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED                      DEFAULT NULL COMMENT '建立人',
    updated_by       BIGINT UNSIGNED                      DEFAULT NULL COMMENT '更新人',
    created_at       DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at       DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (contact_point_id),
    KEY idx_contact_contract (contract_id),
    KEY idx_contact_geo (latitude, longitude),
    CONSTRAINT fk_contact_contract FOREIGN KEY (contract_id) REFERENCES merchant_contract (contract_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '商店聯絡據點';

-- MCH-07: 商店權益保障說明
CREATE TABLE IF NOT EXISTS merchant_protection_notice
(
    notice_id   BIGINT UNSIGNED             NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    contract_id BIGINT UNSIGNED             NOT NULL COMMENT '合約 ID',
    notice_text TEXT                        NOT NULL COMMENT '權益保障說明',
    status      ENUM ('active', 'inactive') NOT NULL DEFAULT 'active' COMMENT '狀態',
    is_deleted  TINYINT(1)                  NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by  BIGINT UNSIGNED                      DEFAULT NULL COMMENT '建立人',
    updated_by  BIGINT UNSIGNED                      DEFAULT NULL COMMENT '更新人',
    created_at  DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at  DATETIME                    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (notice_id),
    KEY idx_notice_contract (contract_id),
    CONSTRAINT fk_notice_contract FOREIGN KEY (contract_id) REFERENCES merchant_contract (contract_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '商店權益保障說明';


-- ============================================================================
-- 模塊 ANN：訊息公告
-- ============================================================================

-- ANN-01: 公告分類字典
CREATE TABLE IF NOT EXISTS announcement_category
(
    category_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    category_code VARCHAR(50)     NOT NULL COMMENT '分類代碼',
    category_name VARCHAR(100)    NOT NULL COMMENT '分類名稱',
    is_active     TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    sort_order    INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_deleted    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by    BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by    BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (category_id),
    UNIQUE KEY uk_announcement_category_code (category_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '公告分類字典';

-- ANN-02: 福利規章文件
CREATE TABLE IF NOT EXISTS policy_document
(
    policy_document_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    document_title       VARCHAR(255)    NOT NULL COMMENT '文件標題',
    version_no           VARCHAR(50)              DEFAULT NULL COMMENT '版本號',
    file_id              BIGINT UNSIGNED NOT NULL COMMENT '文件檔案 ID',
    uploader_employee_id BIGINT UNSIGNED          DEFAULT NULL COMMENT '上傳人',
    status               VARCHAR(50)     NOT NULL DEFAULT 'active' COMMENT '規章狀態（由 sys_dictionary: policy_document_status 治理）',
    is_deleted           TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by           BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by           BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (policy_document_id),
    KEY idx_policy_status (status),
    CONSTRAINT fk_policy_file FOREIGN KEY (file_id) REFERENCES file_resource (file_id),
    CONSTRAINT fk_policy_uploader FOREIGN KEY (uploader_employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '福利規章文件';

-- ANN-03: 平台公告主表
CREATE TABLE IF NOT EXISTS announcement
(
    announcement_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    title              VARCHAR(255)    NOT NULL COMMENT '公告標題',
    summary            VARCHAR(255)             DEFAULT NULL COMMENT '公告摘要',
    content            TEXT                     DEFAULT NULL COMMENT '公告內容',
    category_id        BIGINT UNSIGNED NOT NULL COMMENT '分類 ID',
    policy_document_id BIGINT UNSIGNED          DEFAULT NULL COMMENT '關聯規章文件 ID',
    status             VARCHAR(50)     NOT NULL DEFAULT 'draft' COMMENT '公告狀態（由 sys_dictionary: announcement_status 治理）',
    is_pinned          TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否置頂',
    publish_start_at   DATETIME                 DEFAULT NULL COMMENT '發布起始',
    publish_end_at     DATETIME                 DEFAULT NULL COMMENT '發布結束',
    revision           INT             NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    view_count         INT             NOT NULL DEFAULT 0 COMMENT '瀏覽次數快取',
    is_deleted         TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by         BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by         BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (announcement_id),
    KEY idx_announcement_category (category_id),
    KEY idx_announcement_status (status),
    KEY idx_announcement_publish (publish_start_at, publish_end_at),
    KEY idx_announcement_status_window (status, publish_start_at, publish_end_at),
    CONSTRAINT fk_announcement_category FOREIGN KEY (category_id) REFERENCES announcement_category (category_id),
    CONSTRAINT fk_announcement_policy FOREIGN KEY (policy_document_id) REFERENCES policy_document (policy_document_id),
    CONSTRAINT fk_announcement_creator FOREIGN KEY (created_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '平台公告主表';

-- ANN-04: 公告發布排程
CREATE TABLE IF NOT EXISTS announcement_schedule
(
    schedule_id     BIGINT UNSIGNED                      NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    announcement_id BIGINT UNSIGNED                      NOT NULL COMMENT '公告 ID',
    publish_mode    ENUM ('one_time', 'weekly', 'daily') NOT NULL COMMENT '發布模式',
    start_at        DATETIME                             NOT NULL COMMENT '開始時間',
    end_at          DATETIME                                      DEFAULT NULL COMMENT '結束時間',
    cron_expr       VARCHAR(100)                                  DEFAULT NULL COMMENT '排程表達式',
    duration_label  VARCHAR(100)                                  DEFAULT NULL COMMENT '持續期間描述',
    is_active       TINYINT(1)                           NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted      TINYINT(1)                           NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by      BIGINT UNSIGNED                               DEFAULT NULL COMMENT '建立人',
    created_at      DATETIME                             NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at      DATETIME                             NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (schedule_id),
    KEY idx_schedule_announcement (announcement_id),
    CONSTRAINT fk_schedule_announcement FOREIGN KEY (announcement_id) REFERENCES announcement (announcement_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '公告發布排程';

-- ANN-05: 公告投放範圍
CREATE TABLE IF NOT EXISTS announcement_audience_scope
(
    audience_scope_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    announcement_id   BIGINT UNSIGNED NOT NULL COMMENT '公告 ID',
    scope_type        VARCHAR(50)     NOT NULL COMMENT '範圍類型：region/branch/role/all',
    scope_value       VARCHAR(100)    NOT NULL COMMENT '範圍值',
    is_deleted        TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (audience_scope_id),
    KEY idx_scope_announcement (announcement_id),
    CONSTRAINT fk_scope_announcement FOREIGN KEY (announcement_id) REFERENCES announcement (announcement_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '公告投放範圍';

-- ANN-05A: 公告地理圍欄
CREATE TABLE IF NOT EXISTS announcement_geofence
(
    announcement_geofence_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '地理圍欄主鍵',
    announcement_id          BIGINT UNSIGNED NOT NULL COMMENT '公告 ID',
    fence_name               VARCHAR(100)    NOT NULL COMMENT '圍欄名稱',
    latitude                 DECIMAL(10, 7)  NOT NULL COMMENT '中心緯度',
    longitude                DECIMAL(10, 7)  NOT NULL COMMENT '中心經度',
    radius_meters            INT             NOT NULL COMMENT '半徑（公尺）',
    cooldown_minutes         INT             NOT NULL DEFAULT 60 COMMENT '重複觸發冷卻分鐘',
    is_active                TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_by               BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    created_at               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (announcement_geofence_id),
    KEY idx_announcement_geofence_announcement (announcement_id),
    KEY idx_announcement_geofence_active (is_active),
    CONSTRAINT fk_announcement_geofence_announcement FOREIGN KEY (announcement_id) REFERENCES announcement (announcement_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '公告地理圍欄';

-- ANN-06: 公告瀏覽紀錄
CREATE TABLE IF NOT EXISTS announcement_view_log
(
    announcement_view_log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    announcement_id          BIGINT UNSIGNED NOT NULL COMMENT '公告 ID',
    employee_id              BIGINT UNSIGNED          DEFAULT NULL COMMENT '瀏覽人',
    viewed_at                DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '瀏覽時間',
    source_page              VARCHAR(50)              DEFAULT NULL COMMENT '來源頁面',
    device_info              VARCHAR(255)             DEFAULT NULL COMMENT '裝置資訊',
    PRIMARY KEY (announcement_view_log_id),
    KEY idx_view_announcement (announcement_id),
    KEY idx_view_time (viewed_at),
    CONSTRAINT fk_view_announcement FOREIGN KEY (announcement_id) REFERENCES announcement (announcement_id),
    CONSTRAINT fk_view_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '公告瀏覽紀錄';


-- ============================================================================
-- 模塊 SEC：稽核資安
-- ============================================================================

-- SEC-01: 系統操作稽核日誌
CREATE TABLE IF NOT EXISTS system_audit_trail
(
    event_id            BIGINT UNSIGNED                                    NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    event_time          DATETIME                                           NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '事件時間',
    actor_employee_id   BIGINT UNSIGNED                                             DEFAULT NULL COMMENT '執行人',
    actor_name_snapshot VARCHAR(100)                                                DEFAULT NULL COMMENT '執行人名稱快照',
    action_code         VARCHAR(100)                                       NOT NULL COMMENT '動作代碼',
    target_type         VARCHAR(50)                                                 DEFAULT NULL COMMENT '目標類型',
    target_id           BIGINT UNSIGNED                                             DEFAULT NULL COMMENT '目標主鍵',
    target_key          VARCHAR(100)                                                DEFAULT NULL COMMENT '目標識別值',
    business_type       VARCHAR(50)                                                 DEFAULT NULL COMMENT '業務類型',
    business_id         BIGINT UNSIGNED                                             DEFAULT NULL COMMENT '業務主鍵',
    source_ip           VARCHAR(64)                                                 DEFAULT NULL COMMENT '來源 IP',
    result_code         ENUM ('success', 'warning', 'failed', 'blocked')            DEFAULT NULL COMMENT '執行結果',
    severity_level      ENUM ('info', 'low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'info' COMMENT '嚴重程度',
    rule_category       VARCHAR(50)                                                 DEFAULT NULL COMMENT '規則分類',
    archive_status      ENUM ('hot', 'archived')                           NOT NULL DEFAULT 'hot' COMMENT '封存狀態',
    detail_json         JSON                                                        DEFAULT NULL COMMENT '事件明細',
    created_at          DATETIME                                           NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (event_id),
    KEY idx_audit_time (event_time),
    KEY idx_audit_actor (actor_employee_id),
    KEY idx_audit_action (action_code),
    KEY idx_audit_severity (severity_level),
    KEY idx_audit_severity_time (severity_level, event_time),
    KEY idx_audit_action_time (action_code, event_time),
    KEY idx_audit_rule_category (rule_category),
    CONSTRAINT fk_audit_actor FOREIGN KEY (actor_employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '系統操作稽核日誌';

-- SEC-02: 稽核日誌封存包
CREATE TABLE IF NOT EXISTS audit_archive_bundle
(
    archive_bundle_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    archive_label     VARCHAR(100)    NOT NULL COMMENT '封存標籤（替代唯一日期約束）',
    archive_date      DATE            NOT NULL COMMENT '封存日期',
    record_count      INT             NOT NULL DEFAULT 0 COMMENT '事件筆數',
    package_size_mb   DECIMAL(12, 2)  NOT NULL DEFAULT 0.00 COMMENT '封存大小 MB',
    file_id           BIGINT UNSIGNED NOT NULL COMMENT '封存包檔案 ID',
    checksum          VARCHAR(128)             DEFAULT NULL COMMENT '檔案雜湊值',
    download_count    INT             NOT NULL DEFAULT 0 COMMENT '下載次數',
    storage_status    VARCHAR(50)     NOT NULL DEFAULT 'stored' COMMENT '儲存狀態：stored/archived/missing',
    is_deleted        TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by        BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    created_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (archive_bundle_id),
    UNIQUE KEY uk_archive_label (archive_label),
    KEY idx_archive_date (archive_date),
    CONSTRAINT fk_archive_bundle_file FOREIGN KEY (file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '稽核日誌封存包';

-- SEC-03: 自動化稽核規則
CREATE TABLE IF NOT EXISTS security_scan_rule
(
    scan_rule_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    rule_code        VARCHAR(50)     NOT NULL COMMENT '規則代碼',
    rule_name        VARCHAR(255)    NOT NULL COMMENT '規則名稱',
    rule_category    VARCHAR(50)     NOT NULL COMMENT '規則類別',
    target_scope     VARCHAR(100)             DEFAULT NULL COMMENT '目標範圍',
    rule_config_json JSON                     DEFAULT NULL COMMENT '規則設定 JSON',
    is_enabled       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    schedule_expr    VARCHAR(100)             DEFAULT NULL COMMENT '排程表達式',
    is_deleted       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (scan_rule_id),
    UNIQUE KEY uk_scan_rule_code (rule_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '自動化稽核規則';

-- SEC-04: 稽核規則通知對象（新增，替代原 notify_emails 欄位）
CREATE TABLE IF NOT EXISTS scan_rule_notify_target
(
    notify_target_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    scan_rule_id     BIGINT UNSIGNED NOT NULL COMMENT '規則 ID',
    channel          VARCHAR(50)     NOT NULL COMMENT '通知管道：email/system_message',
    target_value     VARCHAR(255)    NOT NULL COMMENT '對象值（Email 或員工 ID）',
    is_active        TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (notify_target_id),
    KEY idx_notify_rule (scan_rule_id),
    CONSTRAINT fk_notify_rule FOREIGN KEY (scan_rule_id) REFERENCES security_scan_rule (scan_rule_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '稽核規則通知對象';

-- SEC-05: 自動化稽核執行紀錄
CREATE TABLE IF NOT EXISTS security_scan_run
(
    scan_run_id     BIGINT UNSIGNED                                  NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    scan_rule_id    BIGINT UNSIGNED                                  NOT NULL COMMENT '規則 ID',
    run_started_at  DATETIME                                         NOT NULL COMMENT '開始時間',
    run_finished_at DATETIME                                                  DEFAULT NULL COMMENT '結束時間',
    run_status      ENUM ('running', 'success', 'failed', 'partial') NOT NULL DEFAULT 'running' COMMENT '執行狀態',
    findings_count  INT                                              NOT NULL DEFAULT 0 COMMENT '異常筆數',
    summary_text    VARCHAR(255)                                              DEFAULT NULL COMMENT '摘要',
    created_at      DATETIME                                         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (scan_run_id),
    KEY idx_run_rule (scan_rule_id),
    KEY idx_run_time (run_started_at),
    CONSTRAINT fk_run_rule FOREIGN KEY (scan_rule_id) REFERENCES security_scan_rule (scan_rule_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '自動化稽核執行紀錄';

-- SEC-06: 資安與稽核告警
CREATE TABLE IF NOT EXISTS security_alert
(
    alert_id                BIGINT UNSIGNED                            NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    scan_run_id             BIGINT UNSIGNED                                     DEFAULT NULL COMMENT '來源掃描批次 ID',
    audit_event_id          BIGINT UNSIGNED                                     DEFAULT NULL COMMENT '來源稽核事件 ID',
    severity_level          ENUM ('low', 'medium', 'high', 'critical') NOT NULL COMMENT '嚴重程度',
    alert_category          VARCHAR(50)                                NOT NULL COMMENT '告警類型',
    ref_code                VARCHAR(50)                                         DEFAULT NULL COMMENT '參考代碼',
    business_type           VARCHAR(50)                                         DEFAULT NULL COMMENT '關聯業務類型',
    business_id             BIGINT UNSIGNED                                     DEFAULT NULL COMMENT '關聯業務主鍵',
    alert_title             VARCHAR(255)                               NOT NULL COMMENT '告警標題',
    alert_message           TEXT                                       NOT NULL COMMENT '告警內容',
    detected_at             DATETIME                                   NOT NULL COMMENT '偵測時間',
    assigned_to             BIGINT UNSIGNED                                     DEFAULT NULL COMMENT '處理責任人',
    acknowledged_at         DATETIME                                            DEFAULT NULL COMMENT '已知悉時間',
    alert_status            VARCHAR(50)                                NOT NULL DEFAULT 'open' COMMENT '告警狀態（由 sys_dictionary: security_alert_status 治理）',
    latest_delivery_status  VARCHAR(50)                                         DEFAULT NULL COMMENT '最新送達狀態',
    resolution_note         TEXT                                                DEFAULT NULL COMMENT '處理說明',
    archive_bundle_id       BIGINT UNSIGNED                                     DEFAULT NULL COMMENT '封存批次 ID',
    revision                INT                                        NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    resolved_at             DATETIME                                            DEFAULT NULL COMMENT '解決時間',
    resolved_by             BIGINT UNSIGNED                                     DEFAULT NULL COMMENT '解決人',
    is_deleted              TINYINT(1)                                 NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_at              DATETIME                                   NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at              DATETIME                                   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (alert_id),
    KEY idx_alert_run (scan_run_id),
    KEY idx_alert_status (alert_status),
    KEY idx_alert_detected (detected_at),
    KEY idx_alert_severity (severity_level),
    KEY idx_alert_assigned_to (assigned_to),
    CONSTRAINT fk_alert_run FOREIGN KEY (scan_run_id) REFERENCES security_scan_run (scan_run_id),
    CONSTRAINT fk_alert_audit_event FOREIGN KEY (audit_event_id) REFERENCES system_audit_trail (event_id),
    CONSTRAINT fk_alert_assignee FOREIGN KEY (assigned_to) REFERENCES employee (employee_id),
    CONSTRAINT fk_alert_archive_bundle FOREIGN KEY (archive_bundle_id) REFERENCES audit_archive_bundle (archive_bundle_id),
    CONSTRAINT fk_alert_resolver FOREIGN KEY (resolved_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '資安與稽核告警';

-- SEC-07: 告警通知發送紀錄
CREATE TABLE IF NOT EXISTS security_alert_delivery
(
    delivery_id         BIGINT UNSIGNED                         NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    alert_id            BIGINT UNSIGNED                         NOT NULL COMMENT '告警 ID',
    delivery_channel    ENUM ('email', 'system_message', 'sms') NOT NULL COMMENT '通知管道',
    recipient           VARCHAR(255)                            NOT NULL COMMENT '收件人',
    delivery_status     ENUM ('pending', 'sent', 'failed')      NOT NULL DEFAULT 'pending' COMMENT '發送狀態',
    delivered_at        DATETIME                                         DEFAULT NULL COMMENT '發送時間',
    provider_message_id VARCHAR(100)                                     DEFAULT NULL COMMENT '外部服務訊息 ID',
    created_at          DATETIME                                NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (delivery_id),
    KEY idx_delivery_alert (alert_id),
    CONSTRAINT fk_delivery_alert FOREIGN KEY (alert_id) REFERENCES security_alert (alert_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '告警通知發送紀錄';

-- SEC-08: 資安文件庫
CREATE TABLE IF NOT EXISTS security_report_library
(
    report_id         BIGINT UNSIGNED                                         NOT NULL AUTO_INCREMENT COMMENT '主鍵',
    report_title      VARCHAR(255)                                            NOT NULL COMMENT '報告名稱',
    report_category   ENUM ('scan', 'pentest', 'compliance', 'audit_summary', 'archive_export')
                                                                      NOT NULL COMMENT '報告類型',
    report_date       DATE                                                    NOT NULL COMMENT '報告日期',
    time_range_start  DATETIME                                                         DEFAULT NULL COMMENT '報表起始時間',
    time_range_end    DATETIME                                                         DEFAULT NULL COMMENT '報表結束時間',
    risk_label        VARCHAR(50)                                                      DEFAULT NULL COMMENT '風險標籤：safe/medium_risk/high_risk',
    file_id           BIGINT UNSIGNED                                         NOT NULL COMMENT '報告檔案 ID',
    generated_by      BIGINT UNSIGNED                                                  DEFAULT NULL COMMENT '產出人',
    generated_at      DATETIME                                                NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '產出時間',
    revision          INT                                                     NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號',
    view_count        INT                                                     NOT NULL DEFAULT 0 COMMENT '檢視次數',
    is_deleted        TINYINT(1)                                              NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by        BIGINT UNSIGNED                                                  DEFAULT NULL COMMENT '建立人',
    updated_by        BIGINT UNSIGNED                                                  DEFAULT NULL COMMENT '更新人',
    created_at        DATETIME                                                NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at        DATETIME                                                NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (report_id),
    KEY idx_report_date (report_date),
    CONSTRAINT fk_report_file FOREIGN KEY (file_id) REFERENCES file_resource (file_id),
    CONSTRAINT fk_report_employee FOREIGN KEY (generated_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '資安文件庫';



-- ============================================================================
-- 模塊 ORG（擴充）：資料範圍治理
-- ============================================================================

CREATE TABLE IF NOT EXISTS role_data_scope
(
    role_data_scope_id BIGINT UNSIGNED                                                                                 NOT NULL AUTO_INCREMENT COMMENT '角色資料範圍主鍵',
    role_id            BIGINT UNSIGNED                                                                                 NOT NULL COMMENT '角色 ID',
    scope_type         ENUM ('all', 'region', 'welfare_branch', 'org_node', 'self_created', 'self_assigned', 'custom') NOT NULL COMMENT '範圍類型',
    ref_entity_type    ENUM ('region', 'welfare_branch', 'org_node', 'employee', 'custom')                                      DEFAULT NULL COMMENT '參照實體類型',
    ref_id             BIGINT UNSIGNED                                                                                          DEFAULT NULL COMMENT '參照 ID',
    ref_code           VARCHAR(100)                                                                                             DEFAULT NULL COMMENT '參照代碼',
    effect_mode        ENUM ('allow', 'deny')                                                                          NOT NULL DEFAULT 'allow' COMMENT '生效模式',
    priority           INT                                                                                             NOT NULL DEFAULT 100 COMMENT '優先級',
    note               VARCHAR(255)                                                                                             DEFAULT NULL COMMENT '備註',
    is_deleted         TINYINT(1)                                                                                      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by         BIGINT UNSIGNED                                                                                          DEFAULT NULL COMMENT '建立人',
    updated_by         BIGINT UNSIGNED                                                                                          DEFAULT NULL COMMENT '更新人',
    created_at         DATETIME                                                                                        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at         DATETIME                                                                                        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (role_data_scope_id),
    KEY idx_rds_role (role_id),
    KEY idx_rds_scope (scope_type, ref_entity_type, ref_id),
    CONSTRAINT fk_rds_role FOREIGN KEY (role_id) REFERENCES position_role (role_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '角色資料範圍';

CREATE TABLE IF NOT EXISTS employee_data_scope_override
(
    employee_data_scope_override_id BIGINT UNSIGNED                                                                                 NOT NULL AUTO_INCREMENT COMMENT '員工資料範圍覆寫主鍵',
    employee_id                     BIGINT UNSIGNED                                                                                 NOT NULL COMMENT '員工 ID',
    scope_type                      ENUM ('all', 'region', 'welfare_branch', 'org_node', 'self_created', 'self_assigned', 'custom') NOT NULL COMMENT '範圍類型',
    ref_entity_type                 ENUM ('region', 'welfare_branch', 'org_node', 'employee', 'custom')                                      DEFAULT NULL COMMENT '參照實體類型',
    ref_id                          BIGINT UNSIGNED                                                                                          DEFAULT NULL COMMENT '參照 ID',
    ref_code                        VARCHAR(100)                                                                                             DEFAULT NULL COMMENT '參照代碼',
    effect_mode                     ENUM ('allow', 'deny')                                                                          NOT NULL DEFAULT 'allow' COMMENT '生效模式',
    priority                        INT                                                                                             NOT NULL DEFAULT 100 COMMENT '優先級',
    note                            VARCHAR(255)                                                                                             DEFAULT NULL COMMENT '備註',
    is_deleted                      TINYINT(1)                                                                                      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by                      BIGINT UNSIGNED                                                                                          DEFAULT NULL COMMENT '建立人',
    updated_by                      BIGINT UNSIGNED                                                                                          DEFAULT NULL COMMENT '更新人',
    created_at                      DATETIME                                                                                        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at                      DATETIME                                                                                        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (employee_data_scope_override_id),
    KEY idx_edso_employee (employee_id),
    KEY idx_edso_scope (scope_type, ref_entity_type, ref_id),
    CONSTRAINT fk_edso_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '員工資料範圍覆寫';


-- ============================================================================
-- 模塊 AUTH（擴充）：身份來源與綁定
-- ============================================================================

CREATE TABLE IF NOT EXISTS auth_provider
(
    auth_provider_id BIGINT UNSIGNED                                  NOT NULL AUTO_INCREMENT COMMENT '身份提供者主鍵',
    provider_code    VARCHAR(50)                                      NOT NULL COMMENT '提供者代碼：local/outlook/azure_ad/ldap',
    provider_name    VARCHAR(100)                                     NOT NULL COMMENT '提供者名稱',
    protocol_type    ENUM ('local', 'oauth2', 'oidc', 'saml', 'ldap') NOT NULL DEFAULT 'local' COMMENT '協定類型',
    issuer           VARCHAR(255)                                              DEFAULT NULL COMMENT '簽發者/租戶資訊',
    config_json      JSON                                                      DEFAULT NULL COMMENT '連線設定 JSON',
    is_enabled       TINYINT(1)                                       NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted       TINYINT(1)                                       NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by       BIGINT UNSIGNED                                           DEFAULT NULL COMMENT '建立人',
    updated_by       BIGINT UNSIGNED                                           DEFAULT NULL COMMENT '更新人',
    created_at       DATETIME                                         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at       DATETIME                                         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (auth_provider_id),
    UNIQUE KEY uk_auth_provider_code (provider_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '身份提供者';

CREATE TABLE IF NOT EXISTS account_identity_binding
(
    account_identity_binding_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '帳號身份綁定主鍵',
    account_id                  BIGINT UNSIGNED NOT NULL COMMENT '帳號 ID',
    auth_provider_id            BIGINT UNSIGNED NOT NULL COMMENT '身份提供者 ID',
    external_subject            VARCHAR(255)    NOT NULL COMMENT '外部 subject / object id',
    external_login_name         VARCHAR(255)             DEFAULT NULL COMMENT '外部登入名',
    external_email              VARCHAR(255)             DEFAULT NULL COMMENT '外部電子郵件',
    is_primary                  TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否主要身份來源',
    last_synced_at              DATETIME                 DEFAULT NULL COMMENT '最後同步時間',
    is_deleted                  TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by                  BIGINT UNSIGNED          DEFAULT NULL COMMENT '建立人',
    updated_by                  BIGINT UNSIGNED          DEFAULT NULL COMMENT '更新人',
    created_at                  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at                  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (account_identity_binding_id),
    UNIQUE KEY uk_account_provider_subject (auth_provider_id, external_subject),
    KEY idx_aib_account (account_id),
    CONSTRAINT fk_aib_account FOREIGN KEY (account_id) REFERENCES user_account (account_id),
    CONSTRAINT fk_aib_provider FOREIGN KEY (auth_provider_id) REFERENCES auth_provider (auth_provider_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '帳號身份綁定';


-- ============================================================================
-- 模塊 SYS（擴充）：通知模板與外寄佇列
-- ============================================================================

CREATE TABLE IF NOT EXISTS notification_template
(
    notification_template_id BIGINT UNSIGNED                 NOT NULL AUTO_INCREMENT COMMENT '通知模板主鍵',
    template_code            VARCHAR(100)                    NOT NULL COMMENT '模板代碼',
    template_name            VARCHAR(150)                    NOT NULL COMMENT '模板名稱',
    channel                  ENUM ('portal', 'email', 'sms') NOT NULL COMMENT '通知管道',
    subject_template         VARCHAR(255)                             DEFAULT NULL COMMENT '主旨模板',
    body_template            TEXT                            NOT NULL COMMENT '內容模板',
    variable_schema_json     JSON                                     DEFAULT NULL COMMENT '模板變數 Schema',
    is_active                TINYINT(1)                      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    is_deleted               TINYINT(1)                      NOT NULL DEFAULT 0 COMMENT '軟刪除',
    created_by               BIGINT UNSIGNED                          DEFAULT NULL COMMENT '建立人',
    updated_by               BIGINT UNSIGNED                          DEFAULT NULL COMMENT '更新人',
    created_at               DATETIME                        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at               DATETIME                        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (notification_template_id),
    UNIQUE KEY uk_notification_template_code (template_code)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '通知模板';

CREATE TABLE IF NOT EXISTS notification_outbox
(
    notification_outbox_id   BIGINT UNSIGNED                                               NOT NULL AUTO_INCREMENT COMMENT '通知外寄主鍵',
    notification_template_id BIGINT UNSIGNED                                                        DEFAULT NULL COMMENT '模板 ID',
    recipient_employee_id    BIGINT UNSIGNED                                                        DEFAULT NULL COMMENT '收件人員工 ID',
    channel                  ENUM ('portal', 'email', 'sms')                               NOT NULL COMMENT '通知管道',
    recipient_target         VARCHAR(255)                                                  NOT NULL COMMENT '收件目標',
    subject_text             VARCHAR(255)                                                           DEFAULT NULL COMMENT '主旨',
    body_text                TEXT                                                          NOT NULL COMMENT '內容',
    business_type            VARCHAR(50)                                                            DEFAULT NULL COMMENT '關聯業務類型',
    business_id              BIGINT UNSIGNED                                                        DEFAULT NULL COMMENT '關聯業務 ID',
    send_status              ENUM ('pending', 'processing', 'sent', 'failed', 'cancelled') NOT NULL DEFAULT 'pending' COMMENT '發送狀態',
    retry_count              INT                                                           NOT NULL DEFAULT 0 COMMENT '重試次數',
    max_retry_count          INT                                                           NOT NULL DEFAULT 3 COMMENT '最大重試次數',
    scheduled_at             DATETIME                                                               DEFAULT NULL COMMENT '預計發送時間',
    sent_at                  DATETIME                                                               DEFAULT NULL COMMENT '發送時間',
    last_error_message       VARCHAR(500)                                                           DEFAULT NULL COMMENT '最後錯誤訊息',
    created_by               BIGINT UNSIGNED                                                        DEFAULT NULL COMMENT '建立人',
    created_at               DATETIME                                                      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at               DATETIME                                                      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (notification_outbox_id),
    KEY idx_outbox_status (send_status, scheduled_at),
    KEY idx_outbox_business (business_type, business_id),
    CONSTRAINT fk_outbox_template FOREIGN KEY (notification_template_id) REFERENCES notification_template (notification_template_id),
    CONSTRAINT fk_outbox_employee FOREIGN KEY (recipient_employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '通知外寄佇列';

CREATE TABLE IF NOT EXISTS notification_delivery_log
(
    notification_delivery_log_id BIGINT UNSIGNED                                                                  NOT NULL AUTO_INCREMENT COMMENT '通知送達紀錄主鍵',
    notification_outbox_id       BIGINT UNSIGNED                                                                  NOT NULL COMMENT '外寄佇列 ID',
    provider_name                VARCHAR(100)                                                                              DEFAULT NULL COMMENT '服務提供者',
    provider_message_id          VARCHAR(150)                                                                              DEFAULT NULL COMMENT '外部訊息 ID',
    delivery_status              ENUM ('accepted', 'sent', 'delivered', 'opened', 'clicked', 'bounced', 'failed') NOT NULL DEFAULT 'accepted' COMMENT '送達狀態',
    delivery_payload_json        JSON                                                                                      DEFAULT NULL COMMENT '回傳內容',
    logged_at                    DATETIME                                                                         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '紀錄時間',
    PRIMARY KEY (notification_delivery_log_id),
    KEY idx_ndl_outbox (notification_outbox_id),
    CONSTRAINT fk_ndl_outbox FOREIGN KEY (notification_outbox_id) REFERENCES notification_outbox (notification_outbox_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '通知送達紀錄';


-- ============================================================================
-- 模塊 EMP（擴充）：資格與扣繳歷史
-- ============================================================================

CREATE TABLE IF NOT EXISTS employee_payroll_deduction_history
(
    payroll_deduction_history_id BIGINT UNSIGNED                                                NOT NULL AUTO_INCREMENT COMMENT '福利金扣繳歷史主鍵',
    employee_id                  BIGINT UNSIGNED                                                NOT NULL COMMENT '員工 ID',
    deduction_status             ENUM ('eligible', 'deducted', 'paused', 'exempted', 'stopped') NOT NULL COMMENT '扣繳狀態',
    effective_date               DATE                                                           NOT NULL COMMENT '生效日期',
    end_date                     DATE                                                                    DEFAULT NULL COMMENT '結束日期',
    source_type                  ENUM ('manual', 'system_sync', 'import')                       NOT NULL DEFAULT 'manual' COMMENT '來源類型',
    source_reference             VARCHAR(100)                                                            DEFAULT NULL COMMENT '來源參照',
    note                         VARCHAR(255)                                                            DEFAULT NULL COMMENT '備註',
    created_by                   BIGINT UNSIGNED                                                         DEFAULT NULL COMMENT '建立人',
    created_at                   DATETIME                                                       NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (payroll_deduction_history_id),
    KEY idx_epdh_employee (employee_id, effective_date),
    CONSTRAINT chk_epdh_date_range CHECK (end_date IS NULL OR end_date > effective_date),
    CONSTRAINT fk_epdh_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '員工福利金扣繳歷史';

CREATE TABLE IF NOT EXISTS employee_subsidy_eligibility_history
(
    subsidy_eligibility_history_id BIGINT UNSIGNED                                           NOT NULL AUTO_INCREMENT COMMENT '補助資格歷史主鍵',
    employee_id                    BIGINT UNSIGNED                                           NOT NULL COMMENT '員工 ID',
    eligibility_status             ENUM ('eligible', 'ineligible', 'reviewing', 'suspended') NOT NULL COMMENT '資格狀態',
    effective_date                 DATE                                                      NOT NULL COMMENT '生效日期',
    end_date                       DATE                                                               DEFAULT NULL COMMENT '結束日期',
    reason_code                    VARCHAR(50)                                                        DEFAULT NULL COMMENT '原因代碼',
    reason_note                    VARCHAR(255)                                                       DEFAULT NULL COMMENT '原因說明',
    created_by                     BIGINT UNSIGNED                                                    DEFAULT NULL COMMENT '建立人',
    created_at                     DATETIME                                                  NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (subsidy_eligibility_history_id),
    KEY idx_esh_employee (employee_id, effective_date),
    CONSTRAINT chk_esh_date_range CHECK (end_date IS NULL OR end_date > effective_date),
    CONSTRAINT fk_esh_employee FOREIGN KEY (employee_id) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '員工補助資格歷史';


-- ============================================================================
-- 模塊 BEN（擴充）：補助 Typed Extension
-- ============================================================================

CREATE TABLE IF NOT EXISTS benefit_application_marriage
(
    application_id        BIGINT UNSIGNED NOT NULL COMMENT '申請 ID',
    spouse_name           VARCHAR(100)    NOT NULL COMMENT '配偶姓名',
    registration_date     DATE                     DEFAULT NULL COMMENT '登記日期',
    registration_location VARCHAR(255)             DEFAULT NULL COMMENT '登記地點',
    certificate_file_id   BIGINT UNSIGNED          DEFAULT NULL COMMENT '證明文件檔案 ID',
    marriage_grant_amount DECIMAL(12, 2)           DEFAULT NULL COMMENT '婚嫁補助金額',
    created_at            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (application_id),
    CONSTRAINT fk_bam_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_bam_certificate_file FOREIGN KEY (certificate_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '婚嫁補助結構化資料';

CREATE TABLE IF NOT EXISTS benefit_application_birth
(
    application_id      BIGINT UNSIGNED NOT NULL COMMENT '申請 ID',
    child_name          VARCHAR(100)             DEFAULT NULL COMMENT '子女姓名',
    child_birth_date    DATE                     DEFAULT NULL COMMENT '出生日期',
    relation_note       VARCHAR(100)             DEFAULT NULL COMMENT '關係說明',
    certificate_file_id BIGINT UNSIGNED          DEFAULT NULL COMMENT '證明文件檔案 ID',
    birth_grant_amount  DECIMAL(12, 2)           DEFAULT NULL COMMENT '生育/育兒補助金額',
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (application_id),
    CONSTRAINT fk_bab_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_bab_certificate_file FOREIGN KEY (certificate_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '生育/育兒補助結構化資料';

CREATE TABLE IF NOT EXISTS benefit_application_funeral
(
    application_id       BIGINT UNSIGNED                             NOT NULL COMMENT '申請 ID',
    deceased_name        VARCHAR(100)                                NOT NULL COMMENT '亡者姓名',
    relation_type        ENUM ('spouse', 'child', 'parent', 'other') NOT NULL COMMENT '與申請人關係',
    event_date           DATE                                                 DEFAULT NULL COMMENT '喪葬日期',
    certificate_file_id  BIGINT UNSIGNED                                      DEFAULT NULL COMMENT '證明文件檔案 ID',
    funeral_grant_amount DECIMAL(12, 2)                                       DEFAULT NULL COMMENT '喪葬補助金額',
    created_at           DATETIME                                    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at           DATETIME                                    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (application_id),
    CONSTRAINT fk_baf_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_baf_certificate_file FOREIGN KEY (certificate_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '喪葬補助結構化資料';

CREATE TABLE IF NOT EXISTS benefit_application_injury_disaster
(
    application_id       BIGINT UNSIGNED                                                              NOT NULL COMMENT '申請 ID',
    incident_type        ENUM ('occupational_injury', 'illness', 'disaster', 'condolence')          NOT NULL COMMENT '事件類型',
    subject_name         VARCHAR(100)                                                                          DEFAULT NULL COMMENT '受慰問/受災對象',
    incident_date        DATE                                                                                  DEFAULT NULL COMMENT '事件日期',
    certificate_file_id  BIGINT UNSIGNED                                                                       DEFAULT NULL COMMENT '證明文件檔案 ID',
    grant_amount         DECIMAL(12, 2)                                                                        DEFAULT NULL COMMENT '慰問/補助金額',
    created_at           DATETIME                                                                     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at           DATETIME                                                                     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (application_id),
    CONSTRAINT fk_baid_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_baid_certificate_file FOREIGN KEY (certificate_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '傷病/災害慰問補助結構化資料';

CREATE TABLE IF NOT EXISTS benefit_application_child_education
(
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '申請 ID',
    dependent_id    BIGINT UNSIGNED NOT NULL COMMENT '對應眷屬 ID',
    school_year     VARCHAR(20)     NOT NULL COMMENT '學年度',
    semester        VARCHAR(20)              DEFAULT NULL COMMENT '學期',
    school_name     VARCHAR(255)             DEFAULT NULL COMMENT '學校名稱快照',
    tuition_amount  DECIMAL(12, 2)           DEFAULT NULL COMMENT '學雜費金額',
    receipt_file_id BIGINT UNSIGNED          DEFAULT NULL COMMENT '收據檔案 ID',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (application_id),
    KEY idx_bace_dependent (dependent_id),
    CONSTRAINT fk_bace_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_bace_dependent FOREIGN KEY (dependent_id) REFERENCES employee_dependent (dependent_id),
    CONSTRAINT fk_bace_receipt_file FOREIGN KEY (receipt_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '子女教育補助結構化資料';

CREATE TABLE IF NOT EXISTS benefit_application_community_activity
(
    application_id     BIGINT UNSIGNED                                            NOT NULL COMMENT '申請 ID',
    applying_unit_name VARCHAR(255)                                               NOT NULL COMMENT '申請單位/社團名稱',
    contact_name       VARCHAR(100)                                               NOT NULL COMMENT '聯絡人',
    contact_phone      VARCHAR(50)                                                         DEFAULT NULL COMMENT '聯絡電話',
    contact_email      VARCHAR(255)                                                        DEFAULT NULL COMMENT '電子郵件',
    activity_item      ENUM ('literature', 'club', 'participation', 'club_setup') NOT NULL COMMENT '活動項目',
    application_count  INT                                                                 DEFAULT NULL COMMENT '申請次數',
    requested_amount   DECIMAL(12, 2)                                                      DEFAULT NULL COMMENT '申請金額',
    supporting_file_id BIGINT UNSIGNED                                                     DEFAULT NULL COMMENT '應備文件檔案 ID',
    created_at         DATETIME                                                   NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at         DATETIME                                                   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (application_id),
    CONSTRAINT fk_baca_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_baca_file FOREIGN KEY (supporting_file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '社團/活動補助結構化資料';


-- ============================================================================
-- 模塊 WF（擴充）：流程橋接
-- ============================================================================

CREATE TABLE IF NOT EXISTS benefit_application_workflow
(
    benefit_application_workflow_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '申請流程橋接主鍵',
    application_id                  BIGINT UNSIGNED NOT NULL COMMENT '申請 ID',
    workflow_instance_id            BIGINT UNSIGNED NOT NULL COMMENT '流程 ID',
    created_at                      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (benefit_application_workflow_id),
    UNIQUE KEY uk_benefit_application_workflow (application_id),
    UNIQUE KEY uk_benefit_workflow_instance (workflow_instance_id),
    CONSTRAINT fk_baw_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_baw_workflow FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instance (workflow_instance_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '補助申請流程橋接';

CREATE TABLE IF NOT EXISTS merchant_contract_workflow
(
    merchant_contract_workflow_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '商店合約流程橋接主鍵',
    contract_id                   BIGINT UNSIGNED NOT NULL COMMENT '合約 ID',
    workflow_instance_id          BIGINT UNSIGNED NOT NULL COMMENT '流程 ID',
    created_at                    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (merchant_contract_workflow_id),
    UNIQUE KEY uk_merchant_contract_workflow (contract_id),
    UNIQUE KEY uk_merchant_workflow_instance (workflow_instance_id),
    CONSTRAINT fk_mcw_contract FOREIGN KEY (contract_id) REFERENCES merchant_contract (contract_id),
    CONSTRAINT fk_mcw_workflow FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instance (workflow_instance_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '商店合約流程橋接';

CREATE TABLE IF NOT EXISTS announcement_workflow
(
    announcement_workflow_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '公告流程橋接主鍵',
    announcement_id          BIGINT UNSIGNED NOT NULL COMMENT '公告 ID',
    workflow_instance_id     BIGINT UNSIGNED NOT NULL COMMENT '流程 ID',
    created_at               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (announcement_workflow_id),
    UNIQUE KEY uk_announcement_workflow (announcement_id),
    UNIQUE KEY uk_announcement_workflow_instance (workflow_instance_id),
    CONSTRAINT fk_aw_announcement FOREIGN KEY (announcement_id) REFERENCES announcement (announcement_id),
    CONSTRAINT fk_aw_workflow FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instance (workflow_instance_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '公告流程橋接';

CREATE TABLE IF NOT EXISTS payment_batch_workflow
(
    payment_batch_workflow_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '發款批次流程橋接主鍵',
    payment_batch_id          BIGINT UNSIGNED NOT NULL COMMENT '批次 ID',
    workflow_instance_id      BIGINT UNSIGNED NOT NULL COMMENT '流程 ID',
    created_at                DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (payment_batch_workflow_id),
    UNIQUE KEY uk_payment_batch_workflow (payment_batch_id),
    UNIQUE KEY uk_payment_batch_workflow_instance (workflow_instance_id),
    CONSTRAINT fk_pbw_batch FOREIGN KEY (payment_batch_id) REFERENCES payment_batch (payment_batch_id),
    CONSTRAINT fk_pbw_workflow FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instance (workflow_instance_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = '發款批次流程橋接';


-- ============================================================================
-- 模塊 AI：影像辨識與智慧化輔助
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_document_recognition
(
    ai_document_recognition_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '辨識紀錄主鍵',
    file_id                    BIGINT UNSIGNED NOT NULL COMMENT '原始檔案 ID',
    document_type              VARCHAR(50)     NOT NULL COMMENT '文件類型',
    application_id             BIGINT UNSIGNED          DEFAULT NULL COMMENT '關聯申請 ID',
    recognition_status         VARCHAR(50)     NOT NULL DEFAULT 'pending' COMMENT '辨識狀態',
    confidence_score           DECIMAL(5, 4)            DEFAULT NULL COMMENT '整體信心度',
    recognized_fields_json     JSON                     DEFAULT NULL COMMENT '辨識欄位集合',
    corrected_fields_json      JSON                     DEFAULT NULL COMMENT '人工校正欄位集合',
    corrected_by               BIGINT UNSIGNED          DEFAULT NULL COMMENT '校正人',
    correction_note            VARCHAR(500)             DEFAULT NULL COMMENT '校正說明',
    model_version              VARCHAR(50)              DEFAULT NULL COMMENT '模型版本',
    started_at                 DATETIME                 DEFAULT NULL COMMENT '開始時間',
    completed_at               DATETIME                 DEFAULT NULL COMMENT '完成時間',
    created_at                 DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at                 DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (ai_document_recognition_id),
    KEY idx_ai_document_recognition_file (file_id),
    KEY idx_ai_document_recognition_application (application_id),
    KEY idx_ai_document_recognition_status (recognition_status),
    CONSTRAINT fk_ai_document_recognition_file FOREIGN KEY (file_id) REFERENCES file_resource (file_id),
    CONSTRAINT fk_ai_document_recognition_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_ai_document_recognition_corrector FOREIGN KEY (corrected_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = 'AI 文件辨識紀錄';

CREATE TABLE IF NOT EXISTS ai_image_quality_check
(
    ai_image_quality_check_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '品質檢測主鍵',
    file_id                   BIGINT UNSIGNED NOT NULL COMMENT '檔案 ID',
    resolution_score          DECIMAL(8, 2)            DEFAULT NULL COMMENT '解析度分數',
    blur_score                DECIMAL(8, 2)            DEFAULT NULL COMMENT '模糊度分數',
    skew_angle                DECIMAL(8, 2)            DEFAULT NULL COMMENT '傾斜角度',
    crop_completeness         DECIMAL(8, 2)            DEFAULT NULL COMMENT '裁切完整度',
    overall_quality           VARCHAR(50)     NOT NULL COMMENT '整體品質等級',
    check_message             VARCHAR(500)             DEFAULT NULL COMMENT '檢測訊息',
    checked_at                DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '檢測時間',
    PRIMARY KEY (ai_image_quality_check_id),
    KEY idx_ai_image_quality_check_file (file_id),
    CONSTRAINT fk_ai_image_quality_check_file FOREIGN KEY (file_id) REFERENCES file_resource (file_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = 'AI 影像品質檢測紀錄';

CREATE TABLE IF NOT EXISTS ai_duplicate_application_intercept
(
    ai_duplicate_application_intercept_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '重複申請攔截主鍵',
    application_id                        BIGINT UNSIGNED NOT NULL COMMENT '當前申請 ID',
    matched_application_id                BIGINT UNSIGNED          DEFAULT NULL COMMENT '命中申請 ID',
    match_type                            VARCHAR(50)     NOT NULL COMMENT '比對類型',
    intercept_result                      VARCHAR(50)     NOT NULL DEFAULT 'blocked' COMMENT '攔截結果',
    overridden_by                         BIGINT UNSIGNED          DEFAULT NULL COMMENT '放行人',
    overridden_at                         DATETIME                 DEFAULT NULL COMMENT '放行時間',
    created_at                            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (ai_duplicate_application_intercept_id),
    KEY idx_ai_duplicate_intercept_application (application_id),
    KEY idx_ai_duplicate_intercept_matched (matched_application_id),
    CONSTRAINT fk_ai_duplicate_intercept_application FOREIGN KEY (application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_ai_duplicate_intercept_matched FOREIGN KEY (matched_application_id) REFERENCES benefit_application (application_id),
    CONSTRAINT fk_ai_duplicate_intercept_overrider FOREIGN KEY (overridden_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = 'AI 重複申請攔截紀錄';

CREATE TABLE IF NOT EXISTS ai_voucher_generation
(
    ai_voucher_generation_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '傳票產製主鍵',
    payment_batch_id         BIGINT UNSIGNED NOT NULL COMMENT '發款批次 ID',
    voucher_template_code    VARCHAR(100)    NOT NULL COMMENT '傳票模板代碼',
    voucher_type             VARCHAR(50)     NOT NULL COMMENT '傳票類型',
    generated_file_id        BIGINT UNSIGNED          DEFAULT NULL COMMENT '產出檔案 ID',
    generation_status        VARCHAR(50)     NOT NULL DEFAULT 'pending' COMMENT '產製狀態',
    generated_by             BIGINT UNSIGNED          DEFAULT NULL COMMENT '觸發人',
    generated_at             DATETIME                 DEFAULT NULL COMMENT '產製完成時間',
    created_at               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    updated_at               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
    PRIMARY KEY (ai_voucher_generation_id),
    KEY idx_ai_voucher_generation_batch (payment_batch_id),
    KEY idx_ai_voucher_generation_status (generation_status),
    CONSTRAINT fk_ai_voucher_generation_batch FOREIGN KEY (payment_batch_id) REFERENCES payment_batch (payment_batch_id),
    CONSTRAINT fk_ai_voucher_generation_file FOREIGN KEY (generated_file_id) REFERENCES file_resource (file_id),
    CONSTRAINT fk_ai_voucher_generation_actor FOREIGN KEY (generated_by) REFERENCES employee (employee_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = 'AI 傳票產製紀錄';

CREATE TABLE IF NOT EXISTS ai_offpeak_scan_run
(
    ai_offpeak_scan_run_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '離峰掃描主鍵',
    scan_type              VARCHAR(50)     NOT NULL COMMENT '掃描類型',
    started_at             DATETIME        NOT NULL COMMENT '開始時間',
    finished_at            DATETIME                 DEFAULT NULL COMMENT '結束時間',
    hit_count              INT             NOT NULL DEFAULT 0 COMMENT '命中數',
    alert_count            INT             NOT NULL DEFAULT 0 COMMENT '告警數',
    linked_scan_run_id     BIGINT UNSIGNED          DEFAULT NULL COMMENT '關聯 SEC 掃描批次',
    scan_status            VARCHAR(50)     NOT NULL DEFAULT 'running' COMMENT '執行狀態',
    summary_text           VARCHAR(255)             DEFAULT NULL COMMENT '摘要',
    created_at             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
    PRIMARY KEY (ai_offpeak_scan_run_id),
    KEY idx_ai_offpeak_scan_type (scan_type),
    KEY idx_ai_offpeak_scan_started (started_at),
    CONSTRAINT fk_ai_offpeak_scan_linked_run FOREIGN KEY (linked_scan_run_id) REFERENCES security_scan_run (scan_run_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4 COMMENT = 'AI 離峰掃描紀錄';



-- ============================================================================
-- 基礎資料字典初始化（v3.0：業務流程狀態治理）
-- ============================================================================
INSERT INTO sys_dictionary (dict_type, dict_code, dict_name, sort_order, is_active)
VALUES ('benefit_application_status', 'draft', '草稿', 10, 1),
       ('benefit_application_status', 'submitted', '已送出', 20, 1),
       ('benefit_application_status', 'pending_physical_stamp', '待實體核章', 30, 1),
       ('benefit_application_status', 'reviewing', '審核中', 40, 1),
       ('benefit_application_status', 'approved', '已核准', 50, 1),
       ('benefit_application_status', 'pending_payment', '待發款', 60, 1),
       ('benefit_application_status', 'paid', '已發款', 70, 1),
       ('benefit_application_status', 'pending_acknowledgement', '待領款確認', 80, 1),
       ('benefit_application_status', 'closed', '已結案', 90, 1),
       ('benefit_application_status', 'returned', '已退回', 100, 1),
       ('benefit_application_status', 'rejected', '已駁回', 110, 1),
       ('benefit_application_status', 'cancelled', '已取消', 120, 1),

       ('physical_stamp_status', 'not_required', '不需核章', 10, 1),
       ('physical_stamp_status', 'pending_print', '待列印', 20, 1),
       ('physical_stamp_status', 'pending_hr_stamp', '待人事核章', 30, 1),
       ('physical_stamp_status', 'stamped', '已核章', 40, 1),
       ('physical_stamp_status', 'received_by_branch', '福利社已收件', 50, 1),
       ('physical_stamp_status', 'returned_to_applicant', '退回申請人', 60, 1),

       ('payment_batch_status', 'draft', '草稿', 10, 1),
       ('payment_batch_status', 'submitted', '已送審', 20, 1),
       ('payment_batch_status', 'reviewing', '審核中', 30, 1),
       ('payment_batch_status', 'returned', '已退回', 40, 1),
       ('payment_batch_status', 'approved_ready_to_disburse', '已核准待撥款', 50, 1),
       ('payment_batch_status', 'disbursed', '已撥款', 60, 1),
       ('payment_batch_status', 'archived', '已封存', 70, 1),
       ('payment_batch_status', 'rejected', '已駁回', 80, 1),
       ('payment_batch_status', 'cancelled', '已取消', 90, 1),

       ('payment_batch_item_status', 'pending', '待處理', 10, 1),
       ('payment_batch_item_status', 'approved', '已核准', 20, 1),
       ('payment_batch_item_status', 'disbursed', '已撥付', 30, 1),
       ('payment_batch_item_status', 'failed', '處理失敗', 40, 1),
       ('payment_batch_item_status', 'disputed', '已異議', 50, 1),
       ('payment_batch_item_status', 'cancelled', '已取消', 60, 1),

       ('reimbursement_sheet_status', 'draft', '草稿', 10, 1),
       ('reimbursement_sheet_status', 'submitted', '已送審', 20, 1),
       ('reimbursement_sheet_status', 'reviewing', '審核中', 30, 1),
       ('reimbursement_sheet_status', 'approved', '已核准', 40, 1),
       ('reimbursement_sheet_status', 'archived', '已封存', 50, 1),
       ('reimbursement_sheet_status', 'rejected', '已駁回', 60, 1),
       ('reimbursement_sheet_status', 'cancelled', '已取消', 70, 1),

       ('payment_dispute_status', 'open', '待處理', 10, 1),
       ('payment_dispute_status', 'processing', '處理中', 20, 1),
       ('payment_dispute_status', 'resolved', '已解決', 30, 1),
       ('payment_dispute_status', 'rejected', '已駁回', 40, 1),
       ('payment_dispute_status', 'closed', '已結案', 50, 1),

       ('workflow_status', 'draft', '草稿', 10, 1),
       ('workflow_status', 'submitted', '已送出', 20, 1),
       ('workflow_status', 'reviewing', '審核中', 30, 1),
       ('workflow_status', 'returned', '已退回', 40, 1),
       ('workflow_status', 'approved', '已核准', 50, 1),
       ('workflow_status', 'rejected', '已駁回', 60, 1),
       ('workflow_status', 'closed', '已結案', 70, 1),
       ('workflow_status', 'cancelled', '已取消', 80, 1),

       ('workflow_step_status', 'pending', '待處理', 10, 1),
       ('workflow_step_status', 'processing', '處理中', 20, 1),
       ('workflow_step_status', 'approved', '已核准', 30, 1),
       ('workflow_step_status', 'rejected', '已駁回', 40, 1),
       ('workflow_step_status', 'skipped', '已略過', 50, 1),
       ('workflow_step_status', 'returned', '已退回', 60, 1),
       ('workflow_step_status', 'cancelled', '已取消', 70, 1),

       ('review_task_status', 'pending', '待處理', 10, 1),
       ('review_task_status', 'processing', '處理中', 20, 1),
       ('review_task_status', 'completed', '已完成', 30, 1),
       ('review_task_status', 'cancelled', '已取消', 40, 1),

       ('workflow_event_status', 'created', '已建立', 10, 1),
       ('workflow_event_status', 'notified', '已通知', 20, 1),
       ('workflow_event_status', 'archived', '已封存', 30, 1),

       ('merchant_status', 'draft', '草稿', 10, 1),
       ('merchant_status', 'reviewing', '審核中', 20, 1),
       ('merchant_status', 'active', '啟用中', 30, 1),
       ('merchant_status', 'expired', '已到期', 40, 1),
       ('merchant_status', 'inactive', '停用', 50, 1),

       ('merchant_contract_status', 'draft', '草稿', 10, 1),
       ('merchant_contract_status', 'reviewing', '審核中', 20, 1),
       ('merchant_contract_status', 'active', '生效中', 30, 1),
       ('merchant_contract_status', 'expired', '已到期', 40, 1),
       ('merchant_contract_status', 'withdrawn', '已撤回', 50, 1),
       ('merchant_contract_status', 'cancelled', '已取消', 60, 1),

       ('announcement_status', 'draft', '草稿', 10, 1),
       ('announcement_status', 'reviewing', '審核中', 20, 1),
       ('announcement_status', 'scheduled', '排程中', 30, 1),
       ('announcement_status', 'published', '已發布', 40, 1),
       ('announcement_status', 'archived', '已封存', 50, 1),
       ('announcement_status', 'cancelled', '已取消', 60, 1),

       ('policy_document_status', 'active', '現行有效', 10, 1),
       ('policy_document_status', 'archived', '已封存', 20, 1),

       ('ai_recognition_status', 'pending', '待處理', 10, 1),
       ('ai_recognition_status', 'processing', '辨識中', 20, 1),
       ('ai_recognition_status', 'completed', '已完成', 30, 1),
       ('ai_recognition_status', 'warning', '需人工確認', 40, 1),
       ('ai_recognition_status', 'failed', '辨識失敗', 50, 1),

       ('security_alert_status', 'open', '待處理', 10, 1),
       ('security_alert_status', 'acknowledged', '已知悉', 20, 1),
       ('security_alert_status', 'resolved', '已解決', 30, 1),
       ('security_alert_status', 'ignored', '已忽略', 40, 1)
ON DUPLICATE KEY UPDATE dict_name  = VALUES(dict_name),
                        sort_order = VALUES(sort_order),
                        is_active  = VALUES(is_active),
                        updated_at = CURRENT_TIMESTAMP;

-- ============================================================================
-- Trigger：歷史期間不可重疊 / 合約期間不可重疊
-- ============================================================================
DELIMITER $$

CREATE TRIGGER trg_epdh_no_overlap_before_insert
    BEFORE INSERT
    ON employee_payroll_deduction_history
    FOR EACH ROW
BEGIN
    IF NEW.end_date IS NOT NULL AND NEW.end_date <= NEW.effective_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employee_payroll_deduction_history 日期區間無效';
    END IF;

    IF EXISTS (SELECT 1
               FROM employee_payroll_deduction_history t
               WHERE t.employee_id = NEW.employee_id
                 AND (
                   (NEW.end_date IS NULL AND (t.end_date IS NULL OR t.end_date > NEW.effective_date))
                       OR
                   (NEW.end_date IS NOT NULL AND COALESCE(t.end_date, DATE('9999-12-31')) > NEW.effective_date AND
                    NEW.end_date > t.effective_date)
                   )) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employee_payroll_deduction_history 不可出現重疊期間';
    END IF;
END$$

CREATE TRIGGER trg_epdh_no_overlap_before_update
    BEFORE UPDATE
    ON employee_payroll_deduction_history
    FOR EACH ROW
BEGIN
    IF NEW.end_date IS NOT NULL AND NEW.end_date <= NEW.effective_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employee_payroll_deduction_history 日期區間無效';
    END IF;

    IF EXISTS (SELECT 1
               FROM employee_payroll_deduction_history t
               WHERE t.employee_id = NEW.employee_id
                 AND t.payroll_deduction_history_id <> NEW.payroll_deduction_history_id
                 AND (
                   (NEW.end_date IS NULL AND (t.end_date IS NULL OR t.end_date > NEW.effective_date))
                       OR
                   (NEW.end_date IS NOT NULL AND COALESCE(t.end_date, DATE('9999-12-31')) > NEW.effective_date AND
                    NEW.end_date > t.effective_date)
                   )) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employee_payroll_deduction_history 不可出現重疊期間';
    END IF;
END$$

CREATE TRIGGER trg_esh_no_overlap_before_insert
    BEFORE INSERT
    ON employee_subsidy_eligibility_history
    FOR EACH ROW
BEGIN
    IF NEW.end_date IS NOT NULL AND NEW.end_date <= NEW.effective_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employee_subsidy_eligibility_history 日期區間無效';
    END IF;

    IF EXISTS (SELECT 1
               FROM employee_subsidy_eligibility_history t
               WHERE t.employee_id = NEW.employee_id
                 AND (
                   (NEW.end_date IS NULL AND (t.end_date IS NULL OR t.end_date > NEW.effective_date))
                       OR
                   (NEW.end_date IS NOT NULL AND COALESCE(t.end_date, DATE('9999-12-31')) > NEW.effective_date AND
                    NEW.end_date > t.effective_date)
                   )) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employee_subsidy_eligibility_history 不可出現重疊期間';
    END IF;
END$$

CREATE TRIGGER trg_esh_no_overlap_before_update
    BEFORE UPDATE
    ON employee_subsidy_eligibility_history
    FOR EACH ROW
BEGIN
    IF NEW.end_date IS NOT NULL AND NEW.end_date <= NEW.effective_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employee_subsidy_eligibility_history 日期區間無效';
    END IF;

    IF EXISTS (SELECT 1
               FROM employee_subsidy_eligibility_history t
               WHERE t.employee_id = NEW.employee_id
                 AND t.subsidy_eligibility_history_id <> NEW.subsidy_eligibility_history_id
                 AND (
                   (NEW.end_date IS NULL AND (t.end_date IS NULL OR t.end_date > NEW.effective_date))
                       OR
                   (NEW.end_date IS NOT NULL AND COALESCE(t.end_date, DATE('9999-12-31')) > NEW.effective_date AND
                    NEW.end_date > t.effective_date)
                   )) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employee_subsidy_eligibility_history 不可出現重疊期間';
    END IF;
END$$

CREATE TRIGGER trg_merchant_contract_no_overlap_before_insert
    BEFORE INSERT
    ON merchant_contract
    FOR EACH ROW
BEGIN
    IF NEW.contract_end_at <= NEW.contract_start_at THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'merchant_contract 合約日期區間無效';
    END IF;

    IF EXISTS (SELECT 1
               FROM merchant_contract t
               WHERE t.merchant_id = NEW.merchant_id
                 AND t.is_deleted = 0
                 AND COALESCE(t.contract_end_at, TIMESTAMP('9999-12-31 23:59:59')) > NEW.contract_start_at
                 AND NEW.contract_end_at > t.contract_start_at) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'merchant_contract 不可出現重疊合約期間';
    END IF;
END$$

CREATE TRIGGER trg_merchant_contract_no_overlap_before_update
    BEFORE UPDATE
    ON merchant_contract
    FOR EACH ROW
BEGIN
    IF NEW.contract_end_at <= NEW.contract_start_at THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'merchant_contract 合約日期區間無效';
    END IF;

    IF EXISTS (SELECT 1
               FROM merchant_contract t
               WHERE t.merchant_id = NEW.merchant_id
                 AND t.contract_id <> NEW.contract_id
                 AND t.is_deleted = 0
                 AND COALESCE(t.contract_end_at, TIMESTAMP('9999-12-31 23:59:59')) > NEW.contract_start_at
                 AND NEW.contract_end_at > t.contract_start_at) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'merchant_contract 不可出現重疊合約期間';
    END IF;
END$$

DELIMITER ;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- END OF SCHEMA
-- 共計 90 張表：
-- SYS(9) + ORG(10) + EMP(5) + AUTH(6) + BEN(15) + PAY(6) + WF(12) + MCH(7) + ANN(7) + SEC(8) + AI(5)
-- 說明：
-- 1. 本檔為完整初始化版，不含 ALTER / PATCH。
-- 2. 檔案治理已統一以 file_resource + file_reference + file_download_log 為正式來源。
-- 3. 流程治理採 workflow_* + workflow_event + 各業務 bridge table。
-- 4. BEN / PAY 已補齊代理填發、實體核章、報銷單、領款回饋與異議案件。
-- 5. AI / 地理圍欄 / 空間座標 / 資安處置欄位已納入初始化版。
-- ============================================================================
