-- ============================================================================
-- 台鐵職工福利平台 — RBAC 權限控制模組
-- 模組：06_rbac.sql
-- 說明：角色、權限、角色-權限關係、授權、資料範圍、業務範圍、代理、變更申請與歷史
-- 依賴：01_sys.sql、03_org.sql、04_emp.sql、05_iam.sql
-- 設計原則：可配置 RBAC、角色名稱不承載資料範圍、系統管理與業務審批權限分離
-- ============================================================================

USE tra_welfare_test;

-- RBAC-01: 角色
CREATE TABLE IF NOT EXISTS rbac_role (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    role_code       VARCHAR(50)     NOT NULL COMMENT '角色代碼，業務唯一',
    role_name       VARCHAR(100)    NOT NULL COMMENT '角色名稱',
    role_type       VARCHAR(30)     NOT NULL DEFAULT 'business' COMMENT '角色類型：system/business/audit',
    description     VARCHAR(500)    DEFAULT NULL COMMENT '說明',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_role_code (role_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='可配置角色';

-- RBAC-02: 權限
CREATE TABLE IF NOT EXISTS rbac_permission (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    permission_code VARCHAR(100)    NOT NULL COMMENT '權限代碼（如 ben_application:create, pay_batch:approve）',
    permission_name VARCHAR(100)    NOT NULL COMMENT '權限名稱',
    module_code     VARCHAR(30)     NOT NULL COMMENT '所屬模組',
    resource_type   VARCHAR(50)     DEFAULT NULL COMMENT '資源類型',
    action          VARCHAR(30)     NOT NULL COMMENT '動作：create/read/update/delete/approve/export',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_permission_code (permission_code),
    KEY idx_module_code (module_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='功能與動作權限';

-- RBAC-03: 角色-權限關係
CREATE TABLE IF NOT EXISTS rbac_role_permission (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    role_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 rbac_role.id',
    permission_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 rbac_permission.id',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_role_permission (role_id, permission_id),
    KEY idx_permission_id (permission_id),
    CONSTRAINT fk_role_perm_role FOREIGN KEY (role_id) REFERENCES rbac_role(id) ON DELETE RESTRICT,
    CONSTRAINT fk_role_perm_permission FOREIGN KEY (permission_id) REFERENCES rbac_permission(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色和權限關係';

-- RBAC-04: 角色授權
CREATE TABLE IF NOT EXISTS rbac_role_assignment (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '關聯 iam_account.id',
    role_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 rbac_role.id',
    effective_date  DATETIME(6)     NOT NULL COMMENT '生效時間（UTC）',
    expiration_date DATETIME(6)     DEFAULT NULL COMMENT '失效時間（UTC，null 表示無限期）',
    revoked_at      DATETIME(6)     DEFAULT NULL COMMENT '撤銷時間（UTC）',
    granted_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '授權者（iam_account.id）',
    grant_reason    VARCHAR(500)    DEFAULT NULL COMMENT '授權原因',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_role_id (role_id),
    KEY idx_effective_date (effective_date),
    CONSTRAINT fk_role_assign_account FOREIGN KEY (account_id) REFERENCES iam_account(id) ON DELETE RESTRICT,
    CONSTRAINT fk_role_assign_role FOREIGN KEY (role_id) REFERENCES rbac_role(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='帳號角色授權及有效期間';

-- RBAC-05: 資料範圍定義
CREATE TABLE IF NOT EXISTS rbac_data_scope (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    scope_code      VARCHAR(50)     NOT NULL COMMENT '範圍代碼，業務唯一',
    scope_name      VARCHAR(100)    NOT NULL COMMENT '範圍名稱',
    scope_type      VARCHAR(30)     NOT NULL COMMENT '範圍類型：all/org_tree/org/business_category/self/specified',
    description     VARCHAR(500)    DEFAULT NULL COMMENT '說明',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_scope_code (scope_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='全會、單位樹、指定單位、本人等範圍定義';

-- RBAC-06: 授權資料範圍
CREATE TABLE IF NOT EXISTS rbac_assignment_scope (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    assignment_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 rbac_role_assignment.id',
    data_scope_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 rbac_data_scope.id',
    scope_object_type VARCHAR(30)   DEFAULT NULL COMMENT '範圍對象類型：org_unit/welfare_shop/employee',
    scope_object_id BIGINT UNSIGNED DEFAULT NULL COMMENT '範圍對象 ID',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_assignment_scope_data (assignment_id, data_scope_id, scope_object_type, scope_object_id),
    KEY idx_data_scope_id (data_scope_id),
    KEY idx_scope_object (scope_object_type, scope_object_id),
    CONSTRAINT fk_assign_scope_assignment FOREIGN KEY (assignment_id) REFERENCES rbac_role_assignment(id) ON DELETE RESTRICT,
    CONSTRAINT fk_assign_scope_data FOREIGN KEY (data_scope_id) REFERENCES rbac_data_scope(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='某次角色授權的資料範圍';

-- RBAC-07: 業務範圍
CREATE TABLE IF NOT EXISTS rbac_business_scope (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    assignment_id   BIGINT UNSIGNED NOT NULL COMMENT '關聯 rbac_role_assignment.id',
    scope_type      VARCHAR(30)     NOT NULL COMMENT '範圍類型：benefit_program/benefit_type/payment_type',
    scope_id        BIGINT UNSIGNED NOT NULL COMMENT '範圍對象 ID',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_assignment_business (assignment_id, scope_type, scope_id),
    KEY idx_scope_type (scope_type, scope_id),
    CONSTRAINT fk_biz_scope_assignment FOREIGN KEY (assignment_id) REFERENCES rbac_role_assignment(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='某次授權可管理的補助或業務類別';

-- RBAC-08: 臨時職務／權限代理
CREATE TABLE IF NOT EXISTS rbac_delegation (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    delegator_id    BIGINT UNSIGNED NOT NULL COMMENT '委託人（iam_account.id）',
    delegate_id     BIGINT UNSIGNED NOT NULL COMMENT '代理人（iam_account.id）',
    delegation_type VARCHAR(30)     NOT NULL COMMENT '代理類型：role/specific_permission/full',
    role_id         BIGINT UNSIGNED DEFAULT NULL COMMENT '代理角色（delegation_type=role 時）',
    effective_date  DATETIME(6)     NOT NULL COMMENT '生效時間（UTC）',
    expiration_date DATETIME(6)     DEFAULT NULL COMMENT '失效時間（UTC）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否有效',
    reason          VARCHAR(500)    DEFAULT NULL COMMENT '代理原因',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_delegator_id (delegator_id),
    KEY idx_delegate_id (delegate_id),
    KEY idx_is_active (is_active, effective_date, expiration_date),
    CONSTRAINT fk_delegation_delegator FOREIGN KEY (delegator_id) REFERENCES iam_account(id) ON DELETE RESTRICT,
    CONSTRAINT fk_delegation_delegate FOREIGN KEY (delegate_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='臨時職務或權限代理';

-- RBAC-09: 高權限變更申請
CREATE TABLE IF NOT EXISTS rbac_change_request (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    request_no      VARCHAR(50)     NOT NULL COMMENT '變更申請編號，唯一',
    request_type    VARCHAR(30)     NOT NULL COMMENT '申請類型：grant_role/revoke_role/delegate/change_scope',
    target_account_id BIGINT UNSIGNED NOT NULL COMMENT '目標帳號（iam_account.id）',
    role_id         BIGINT UNSIGNED DEFAULT NULL COMMENT '相關角色',
    proposed_scope_json JSON       DEFAULT NULL COMMENT '提議範圍（結構版本 v1）',
    reason          TEXT            NOT NULL COMMENT '申請原因',
    request_status  VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/approved/rejected/cancelled',
    requested_by    BIGINT UNSIGNED NOT NULL COMMENT '申請人（iam_account.id）',
    approved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '核准人（iam_account.id）',
    approved_at     DATETIME(6)     DEFAULT NULL COMMENT '核准時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_rbac_request_no (request_no),
    KEY idx_target_account (target_account_id),
    KEY idx_request_status (request_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='高權限授權和回收申請';

-- RBAC-10: 權限變更歷史
CREATE TABLE IF NOT EXISTS rbac_change_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    change_request_id BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 rbac_change_request.id',
    change_type     VARCHAR(30)     NOT NULL COMMENT '變更類型：assignment/delegation/permission_update/scope_update',
    account_id      BIGINT UNSIGNED NOT NULL COMMENT '受影響帳號',
    before_json     JSON            DEFAULT NULL COMMENT '變更前（結構版本 v1）',
    after_json      JSON            NOT NULL COMMENT '變更後（結構版本 v1）',
    changed_by      BIGINT UNSIGNED NOT NULL COMMENT '操作者（iam_account.id）',
    change_reason   VARCHAR(500)    DEFAULT NULL COMMENT '變更原因',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_account_id (account_id),
    KEY idx_change_request_id (change_request_id),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='權限變更歷史';
