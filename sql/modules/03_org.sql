-- ============================================================================
-- 台鐵職工福利平台 — ORG 組織架構模組
-- 模組：03_org.sql
-- 說明：組織單位、閉包表、歷史、職位、任職、任職業務範圍、組織變更與導入
-- 依賴：01_sys.sql
-- ============================================================================

USE tra_welfare_test;

-- ORG-01: 組織單位主檔
CREATE TABLE IF NOT EXISTS org_unit (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    unit_code       VARCHAR(30)     NOT NULL COMMENT '單位代碼，業務唯一',
    unit_name       VARCHAR(100)    NOT NULL COMMENT '單位名稱',
    unit_type       VARCHAR(30)     NOT NULL COMMENT '單位類型：headquarters/bureau/office/welfare_shop/department/section',
    parent_id       BIGINT UNSIGNED DEFAULT NULL COMMENT '上級單位 ID（自我參照）',
    manager_position_id BIGINT UNSIGNED DEFAULT NULL COMMENT '負責人職位 ID（引用 org_position）',
    contact_phone   VARCHAR(30)     DEFAULT NULL COMMENT '聯絡電話',
    contact_address VARCHAR(200)    DEFAULT NULL COMMENT '聯絡地址',
    sort_order      INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    effective_date  DATE            NOT NULL COMMENT '生效日期',
    expiration_date DATE            DEFAULT NULL COMMENT '失效日期（null 表示無限期）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_unit_code (unit_code),
    KEY idx_parent_id (parent_id),
    KEY idx_unit_type (unit_type),
    KEY idx_is_active (is_active, expiration_date),
    CONSTRAINT fk_org_unit_parent FOREIGN KEY (parent_id) REFERENCES org_unit(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='組織單位、福利社、組室和站段主檔';

-- ORG-02: 組織閉包表（祖先-後代關係）
CREATE TABLE IF NOT EXISTS org_unit_closure (
    ancestor_id     BIGINT UNSIGNED NOT NULL COMMENT '祖先節點 ID',
    descendant_id   BIGINT UNSIGNED NOT NULL COMMENT '後代節點 ID',
    depth           INT             NOT NULL COMMENT '距離（0 表示自身）',
    PRIMARY KEY (ancestor_id, descendant_id),
    KEY idx_descendant (descendant_id),
    KEY idx_depth (depth),
    CONSTRAINT fk_closure_ancestor FOREIGN KEY (ancestor_id) REFERENCES org_unit(id) ON DELETE RESTRICT,
    CONSTRAINT fk_closure_descendant FOREIGN KEY (descendant_id) REFERENCES org_unit(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='組織樹祖先與後代關係（加速全樹查詢）';

-- ORG-03: 組織單位歷史
CREATE TABLE IF NOT EXISTS org_unit_history (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    unit_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 org_unit.id',
    unit_code       VARCHAR(30)     NOT NULL COMMENT '變更時單位代碼',
    unit_name       VARCHAR(100)    NOT NULL COMMENT '變更時名稱',
    parent_id       BIGINT UNSIGNED DEFAULT NULL COMMENT '變更時上級 ID',
    is_active       TINYINT(1)      NOT NULL COMMENT '變更時啟用狀態',
    effective_date  DATE            NOT NULL COMMENT '變更生效日期',
    change_type     VARCHAR(30)     NOT NULL COMMENT '變更類型：create/rename/restructure/deactivate/reactivate',
    changed_by      BIGINT UNSIGNED DEFAULT NULL COMMENT '變更操作者（iam_account.id）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '記錄時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_unit_id (unit_id),
    KEY idx_unit_code (unit_code),
    KEY idx_effective_date (effective_date),
    CONSTRAINT fk_unit_history_unit FOREIGN KEY (unit_id) REFERENCES org_unit(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='名稱、層級、狀態和有效期間歷史';

-- ORG-04: 職位
CREATE TABLE IF NOT EXISTS org_position (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    position_code   VARCHAR(30)     NOT NULL COMMENT '職位代碼，業務唯一',
    position_name   VARCHAR(100)    NOT NULL COMMENT '職位名稱（如主委、總幹事、組長、主任、幹事）',
    org_unit_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '所屬組織（null 表示通用職位）',
    sort_order      INT             NOT NULL DEFAULT 0 COMMENT '排序',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_position_code (position_code),
    KEY idx_org_unit_id (org_unit_id),
    CONSTRAINT fk_position_org FOREIGN KEY (org_unit_id) REFERENCES org_unit(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='主委、總幹事、組長、主任、幹事等職位';

-- ORG-05: 組織變更申請
CREATE TABLE IF NOT EXISTS org_change_request (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    request_no      VARCHAR(50)     NOT NULL COMMENT '變更申請編號，唯一',
    change_type     VARCHAR(30)     NOT NULL COMMENT '變更類型：create/rename/restructure/deactivate',
    target_unit_id  BIGINT UNSIGNED DEFAULT NULL COMMENT '目標單位（新增時為 null）',
    proposed_name   VARCHAR(100)    DEFAULT NULL COMMENT '提議名稱',
    reason          TEXT            NOT NULL COMMENT '變更原因',
    request_status  VARCHAR(30)     NOT NULL DEFAULT 'draft' COMMENT '狀態：draft/pending/approved/rejected/cancelled',
    requested_by    BIGINT UNSIGNED NOT NULL COMMENT '申請人（iam_account.id，應用層保證 FK）',
    approved_by     BIGINT UNSIGNED DEFAULT NULL COMMENT '核准人（iam_account.id）',
    approved_at     DATETIME(6)     DEFAULT NULL COMMENT '核准時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_request_no (request_no),
    KEY idx_target_unit (target_unit_id),
    KEY idx_request_status (request_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='組織新增、更名、裁撤申請';

-- ORG-06: 組織變更影響分析
CREATE TABLE IF NOT EXISTS org_change_impact (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    change_request_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 org_change_request.id',
    impact_type     VARCHAR(30)     NOT NULL COMMENT '影響類型：workflow/assignment/benefit/contract',
    affected_object_type VARCHAR(50) NOT NULL COMMENT '受影響對象類型',
    affected_object_id  BIGINT UNSIGNED NOT NULL COMMENT '受影響對象 ID',
    impact_description TEXT        NOT NULL COMMENT '影響描述',
    is_resolved     TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已處理',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_change_request_id (change_request_id),
    CONSTRAINT fk_impact_change_request FOREIGN KEY (change_request_id) REFERENCES org_change_request(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='組織變更影響的流程、人員和待處理事項';

-- ORG-07: 組織變更與工作流關聯（不含 wf_instance 外鍵——由 WF 模組安裝後保證引用完整性）
CREATE TABLE IF NOT EXISTS org_change_approval_link (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    change_request_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 org_change_request.id',
    wf_instance_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_instance.id（應用層保證 FK）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_change_wf (change_request_id, wf_instance_id),
    KEY idx_wf_instance (wf_instance_id),
    CONSTRAINT fk_approval_link_change FOREIGN KEY (change_request_id) REFERENCES org_change_request(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='組織變更對應工作流';

-- ORG-08: 組織資料導入批次
CREATE TABLE IF NOT EXISTS org_import_batch (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    import_job_id   BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 sys_import_job.id',
    total_units     INT             NOT NULL DEFAULT 0 COMMENT '總單位數',
    created_units   INT             NOT NULL DEFAULT 0 COMMENT '新增單位數',
    updated_units   INT             NOT NULL DEFAULT 0 COMMENT '更新單位數',
    import_status   VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/importing/completed/failed',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_import_job_id (import_job_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='組織資料批次導入結果';
