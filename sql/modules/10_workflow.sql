-- ============================================================================
-- 台鐵職工福利平台 — WF 工作流模組
-- 模組：10_workflow.sql
-- 說明：流程模板、模板版本、節點定義、轉移定義、路由規則、流程實例、任務、候選人、
--       審批動作、代理、逾時事件、快照、業務橋接表
-- 依賴：01_sys.sql、04_emp.sql、05_iam.sql、06_rbac.sql
-- 設計原則：模板版本發佈後不可修改、業務模組透過專用橋接表關聯、批次核准保留獨立動作
-- ============================================================================

USE tra_welfare_test;

-- ============================================================================
-- 1. 流程定義
-- ============================================================================

-- WF-01: 流程模板主檔
CREATE TABLE IF NOT EXISTS wf_template (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    template_code   VARCHAR(50)     NOT NULL COMMENT '模板代碼，業務唯一',
    template_name   VARCHAR(100)    NOT NULL COMMENT '模板名稱',
    description     TEXT            DEFAULT NULL COMMENT '說明',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_template_code (template_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='流程模板邏輯名稱';

-- WF-02: 流程模板版本
CREATE TABLE IF NOT EXISTS wf_template_version (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    template_id     BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_template.id',
    version_no      INT             NOT NULL COMMENT '版本號（同一模板內遞增）',
    version_name    VARCHAR(100)    DEFAULT NULL COMMENT '版本名稱',
    is_published    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已發佈（發佈後不可修改）',
    published_at    DATETIME(6)     DEFAULT NULL COMMENT '發佈時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_template_version (template_id, version_no),
    CONSTRAINT fk_wf_template_version_template FOREIGN KEY (template_id) REFERENCES wf_template(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='可發佈的流程版本';

-- WF-03: 節點定義
CREATE TABLE IF NOT EXISTS wf_node_definition (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    template_version_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_template_version.id',
    node_code           VARCHAR(50)     NOT NULL COMMENT '節點代碼（同一模板內唯一）',
    node_name           VARCHAR(100)    NOT NULL COMMENT '節點名稱',
    node_type           VARCHAR(30)     NOT NULL COMMENT '節點類型：start/approve/counter_sign/notify/condition/gateway/end',
    node_order          INT             NOT NULL COMMENT '節點順序',
    assignment_rule_json JSON           DEFAULT NULL COMMENT '指派規則（結構版本 v1，角色、職位和資料範圍組合）',
    timeout_hours       INT             DEFAULT NULL COMMENT '節點逾時時數（null 表示不逾時）',
    is_required         TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否必辦',
    config_json         JSON            DEFAULT NULL COMMENT '其他設定（結構版本 v1）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_template_node (template_version_id, node_code),
    KEY idx_node_order (template_version_id, node_order),
    CONSTRAINT fk_node_template_version FOREIGN KEY (template_version_id) REFERENCES wf_template_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='節點、節點類型和辦理規則';

-- WF-04: 轉移定義
CREATE TABLE IF NOT EXISTS wf_transition_definition (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    template_version_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_template_version.id',
    transition_code     VARCHAR(50)     NOT NULL COMMENT '轉移代碼（同一模板內唯一）',
    source_node_id      BIGINT UNSIGNED NOT NULL COMMENT '來源節點（wf_node_definition.id）',
    target_node_id      BIGINT UNSIGNED NOT NULL COMMENT '目標節點（wf_node_definition.id）',
    condition_json      JSON            DEFAULT NULL COMMENT '轉移條件（結構版本 v1）',
    sort_order          INT             NOT NULL DEFAULT 0 COMMENT '同來源節點的多轉移排序',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_template_transition (template_version_id, transition_code),
    KEY idx_source_node (source_node_id),
    KEY idx_target_node (target_node_id),
    CONSTRAINT fk_transition_template_version FOREIGN KEY (template_version_id) REFERENCES wf_template_version(id) ON DELETE RESTRICT,
    CONSTRAINT fk_transition_source FOREIGN KEY (source_node_id) REFERENCES wf_node_definition(id) ON DELETE RESTRICT,
    CONSTRAINT fk_transition_target FOREIGN KEY (target_node_id) REFERENCES wf_node_definition(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='節點轉移與條件';

-- WF-05: 路由規則
CREATE TABLE IF NOT EXISTS wf_route_rule (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    template_version_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_template_version.id',
    rule_code           VARCHAR(50)     NOT NULL COMMENT '規則代碼',
    condition_json      JSON            NOT NULL COMMENT '路由條件（結構版本 v1，金額、類別和組織條件組合）',
    target_node_id      BIGINT UNSIGNED NOT NULL COMMENT '符合時路由至節點',
    sort_order          INT             NOT NULL DEFAULT 0 COMMENT '規則優先順序',
    is_active           TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否啟用',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_template_rule (template_version_id, rule_code),
    KEY idx_target_node (target_node_id),
    CONSTRAINT fk_route_rule_template FOREIGN KEY (template_version_id) REFERENCES wf_template_version(id) ON DELETE RESTRICT,
    CONSTRAINT fk_route_rule_node FOREIGN KEY (target_node_id) REFERENCES wf_node_definition(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='金額、補助類別和組織路由條件';

-- ============================================================================
-- 2. 流程運行時
-- ============================================================================

-- WF-06: 流程實例
CREATE TABLE IF NOT EXISTS wf_instance (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    instance_no         VARCHAR(50)     NOT NULL COMMENT '實例編號，唯一',
    template_version_id BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_template_version.id',
    instance_status     VARCHAR(30)     NOT NULL DEFAULT 'running' COMMENT '狀態：running/completed/cancelled/timeout',
    current_node_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '當前節點（wf_node_definition.id）',
    started_by          BIGINT UNSIGNED DEFAULT NULL COMMENT '啟動者（iam_account.id）',
    started_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '啟動時間（UTC）',
    completed_at        DATETIME(6)     DEFAULT NULL COMMENT '完成時間（UTC）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_instance_no (instance_no),
    KEY idx_template_version_id (template_version_id),
    KEY idx_instance_status (instance_status),
    KEY idx_current_node (current_node_id),
    CONSTRAINT fk_instance_template_version FOREIGN KEY (template_version_id) REFERENCES wf_template_version(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='一次運行中的流程實例';

-- WF-07: 流程實例快照
CREATE TABLE IF NOT EXISTS wf_instance_snapshot (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    instance_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_instance.id',
    snapshot_json       JSON            NOT NULL COMMENT '啟動時流程定義快照（結構版本 v1）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_instance_snapshot (instance_id),
    CONSTRAINT fk_instance_snapshot_instance FOREIGN KEY (instance_id) REFERENCES wf_instance(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='啟動時的流程定義快照';

-- WF-08: 辦理任務
CREATE TABLE IF NOT EXISTS wf_task (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    instance_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_instance.id',
    node_id             BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_node_definition.id',
    task_code           VARCHAR(50)     NOT NULL COMMENT '任務代碼，唯一',
    assignee_account_id BIGINT UNSIGNED DEFAULT NULL COMMENT '辦理人（iam_account.id）',
    original_assignee_id BIGINT UNSIGNED DEFAULT NULL COMMENT '原辦理人（代理時記錄）',
    task_status         VARCHAR(30)     NOT NULL DEFAULT 'ready' COMMENT '狀態：ready/claimed/approved/returned/supplement_requested/rejected/delegated/cancelled/expired',
    due_at              DATETIME(6)     DEFAULT NULL COMMENT '到期時間（UTC）',
    completed_at        DATETIME(6)     DEFAULT NULL COMMENT '完成時間（UTC）',
    created_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    updated_at          DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_task_code (task_code),
    KEY idx_instance_id (instance_id),
    KEY idx_assignee (assignee_account_id, task_status, due_at),
    KEY idx_node_id (node_id),
    CONSTRAINT fk_task_instance FOREIGN KEY (instance_id) REFERENCES wf_instance(id) ON DELETE RESTRICT,
    CONSTRAINT fk_task_node FOREIGN KEY (node_id) REFERENCES wf_node_definition(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='當前及歷史辦理任務';

-- WF-09: 任務候選人
CREATE TABLE IF NOT EXISTS wf_task_candidate (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    task_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_task.id',
    candidate_type  VARCHAR(30)     NOT NULL COMMENT '候選類型：account/role/position/org_unit',
    candidate_id    BIGINT UNSIGNED NOT NULL COMMENT '候選對象 ID',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_task_candidate (task_id, candidate_type, candidate_id),
    CONSTRAINT fk_candidate_task FOREIGN KEY (task_id) REFERENCES wf_task(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='可認領任務的人員或角色';

-- WF-10: 審批動作記錄
CREATE TABLE IF NOT EXISTS wf_action_log (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    task_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_task.id',
    action_type     VARCHAR(30)     NOT NULL COMMENT '動作類型：approve/return/reject/supplement_request/delegate/comment',
    operator_id     BIGINT UNSIGNED DEFAULT NULL COMMENT '操作者（iam_account.id）',
    comment         TEXT            DEFAULT NULL COMMENT '意見',
    source_ip       VARCHAR(45)     DEFAULT NULL COMMENT '來源 IP',
    request_trace   VARCHAR(64)     DEFAULT NULL COMMENT '請求追蹤號',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_task_id (task_id),
    KEY idx_action_type (action_type),
    KEY idx_created_at (created_at),
    CONSTRAINT fk_action_log_task FOREIGN KEY (task_id) REFERENCES wf_task(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='核准、退回、補件和意見記錄（僅追加）';

-- WF-11: 審批代理關係
CREATE TABLE IF NOT EXISTS wf_delegation (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    task_id         BIGINT UNSIGNED DEFAULT NULL COMMENT '關聯 wf_task.id（特定任務代理，null 表示全局代理）',
    delegator_id    BIGINT UNSIGNED NOT NULL COMMENT '委託人（iam_account.id）',
    delegate_id     BIGINT UNSIGNED NOT NULL COMMENT '代理人（iam_account.id）',
    delegation_type VARCHAR(30)     NOT NULL COMMENT '代理類型：task_all/task_specific/role_based',
    effective_date  DATETIME(6)     NOT NULL COMMENT '生效時間（UTC）',
    expiration_date DATETIME(6)     DEFAULT NULL COMMENT '失效時間（UTC）',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否有效',
    reason          VARCHAR(500)    DEFAULT NULL COMMENT '代理原因',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_delegator_id (delegator_id),
    KEY idx_delegate_id (delegate_id),
    KEY idx_task_id (task_id),
    CONSTRAINT fk_wf_delegation_task FOREIGN KEY (task_id) REFERENCES wf_task(id) ON DELETE SET NULL,
    CONSTRAINT fk_wf_delegation_delegator FOREIGN KEY (delegator_id) REFERENCES iam_account(id) ON DELETE RESTRICT,
    CONSTRAINT fk_wf_delegation_delegate FOREIGN KEY (delegate_id) REFERENCES iam_account(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='審批代理關係';

-- WF-12: 逾時事件
CREATE TABLE IF NOT EXISTS wf_timeout_event (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    task_id         BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_task.id',
    event_type      VARCHAR(30)     NOT NULL COMMENT '事件類型：reminder/escalation/timeout',
    event_status    VARCHAR(30)     NOT NULL DEFAULT 'pending' COMMENT '狀態：pending/sent/resolved/ignored',
    triggered_at    DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '觸發時間（UTC）',
    resolved_at     DATETIME(6)     DEFAULT NULL COMMENT '處理時間（UTC）',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    KEY idx_task_id (task_id),
    KEY idx_event_status (event_status),
    CONSTRAINT fk_timeout_task FOREIGN KEY (task_id) REFERENCES wf_task(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='到期、提醒和升級記錄';

-- ============================================================================
-- 3. 業務橋接表
-- ============================================================================

-- WF-13: 申請與工作流關聯
CREATE TABLE IF NOT EXISTS ben_application_workflow (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '內部主鍵',
    application_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 ben_application.id',
    wf_instance_id  BIGINT UNSIGNED NOT NULL COMMENT '關聯 wf_instance.id',
    workflow_purpose VARCHAR(30)    NOT NULL COMMENT '用途：main_approval/supplement_review/special_approval',
    is_current      TINYINT(1)      NOT NULL DEFAULT 1 COMMENT '是否為當前有效關聯',
    created_at      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '建立時間（UTC）',
    PRIMARY KEY (id),
    UNIQUE KEY uk_application_wf (application_id, workflow_purpose),
    KEY idx_wf_instance_id (wf_instance_id),
    CONSTRAINT fk_app_wf_application FOREIGN KEY (application_id) REFERENCES ben_application(id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_wf_instance FOREIGN KEY (wf_instance_id) REFERENCES wf_instance(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='申請與工作流實例關聯';
