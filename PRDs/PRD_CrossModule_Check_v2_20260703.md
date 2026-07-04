# 跨模塊閉環檢查報告 v2

> 檢查日期：2026-07-03  
> 檢查範圍：26 份增強版子 PRD（M01–M26）  
> 參考標準：`PRD_全域規範_v2_20260703.md`（跨模塊契約）  
> 檢查人：GLM 5.2（自動化掃描）

---

## 1. 模塊完整性（26/26 ✅）

| 編號 | 文件路徑 | 存在 |
|------|---------|------|
| M01 | `PRD_M01_AUTH_Login_v2_20260703.md` | ✅ |
| M02 | `PRD_M02_AUTH_Activation_v2_20260703.md` | ✅ |
| M03 | `PRD_M03_ORG_Tree_v2_20260703.md` | ✅ |
| M04 | `PRD_M04_ORG_RBAC_v2_20260703.md` | ✅ |
| M05 | `PRD_M05_EMP_Master_v2_20260703.md` | ✅ |
| M06 | `PRD_M06_EMP_History_v2_20260703.md` | ✅ |
| M07 | `PRD_M07_SYS_Dict_v2_20260703.md` | ✅ |
| M08 | `PRD_M08_SYS_File_v2_20260703.md` | ✅ |
| M09 | `PRD_M09_SYS_Notification_v2_20260703.md` | ✅ |
| M10 | `PRD_M10_WF_Template_v2_20260703.md` | ✅ |
| M11 | `PRD_M11_WF_TaskCenter_v2_20260703.md` | ✅ |
| M12 | `PRD_M12_WF_Timeout_v2_20260703.md` | ✅ |
| M13 | `PRD_M13_BEN_Portal_v2_20260703.md` | ✅ |
| M14 | `PRD_M14_BEN_Admin_v2_20260703.md` | ✅ |
| M15 | `PRD_M15_BEN_Rules_v2_20260703.md` | ✅ |
| M16 | `PRD_M16_PAY_Pool_v2_20260703.md` | ✅ |
| M17 | `PRD_M17_PAY_Batch_v2_20260703.md` | ✅ |
| M18 | `PRD_M18_PAY_Confirm_v2_20260703.md` | ✅ |
| M19 | `PRD_M19_ANN_Draft_v2_20260703.md` | ✅ |
| M20 | `PRD_M20_ANN_Portal_v2_20260703.md` | ✅ |
| M21 | `PRD_M21_MCH_Shop_v2_20260703.md` | ✅ |
| M22 | `PRD_M22_MCH_Offer_v2_20260703.md` | ✅ |
| M23 | `PRD_M23_SEC_Audit_v2_20260703.md` | ✅ |
| M24 | `PRD_M24_SEC_Security_v2_20260703.md` | ✅ |
| M25 | `PRD_M25_INDEX_v2_20260703.md` | ✅ |
| M26 | `PRD_M26_AI_OCR_v2_20260703.md` | ✅ |

---

## 2. 跨模塊數據流斷點檢查

### 2.1 AUTH(M01-M02) → ORG(M03-M04) → EMP(M05-M06) 依賴關係

| 檢查項 | 狀態 | 說明 |
|--------|------|------|
| M01 登入後查詢 ORG 角色/權限 | ✅ | M01 §2.2 跨模塊序列圖：`AUTH->>ORG: 查詢角色/權限摘要` |
| M02 啟活時校驗 EMP 名冊 | ✅ | M02 §2.1：`B1[核對在職名冊] → C1[(employee 在職名冊)]` |
| M03 任職配置參照 EMP 員工 | ✅ | M03 §3.1：`employee_assignment → employee` |
| M04 RBAC 指派參照 EMP | ✅ | M04 §3.1：`account_role → employee` |
| M05 依賴 ORG 組織 | ✅ | M05 §3.2：`employee.org_unit_id FK` 但未明確指明 FK→org_node |
| M06 依賴 M05 | ✅ | M06 §1.4：明確標記`依賴：M05（EMP 員工主檔）` |

**⚠️ M05 問題**：M05 §3.2 ER 圖中 `employee` 表有 `org_unit_id FK`，但 **FK 目標表名寫為 `org_unit` 而非 M03 定義的 `org_node`**。全域規範中 M03 的組織節點表為 `org_node`。此為命名不一致。

> **修復建議**：M05 §3.2 `employee` 表的 `org_unit_id FK` 註釋改為 `FK→org_node`，或在 M03 中確認 `org_node` 是否可別名為 `org_unit`。建議統一名詞。

### 2.2 AUTH → WF(M10-M12) → BEN(M13-M15) 審批鏈

| 檢查項 | 狀態 | 說明 |
|--------|------|------|
| WF 模板引用 ORG 角色 | ✅ | M10 §3.2：`workflow_step.approver_role_code FK->role` |
| WF 待辦派發查 ORG 任職 | ✅ | M11 §2.3：`查 ORG 當前任職人` |
| BEN 送審調用 WF 建立流程 | ✅ | M13 §2.1：`Q[送審並取得案件編號]`；M13 §7.1 submit 響應含 workflow_instance_id |
| M14 核准後進待發款池 | ✅ | M14 §2.1：`L[進入待發款池]` |
| ANN 送審調用 WF | ✅ | M19 §2.2：`ANN->>WF: 建立流程實例` |
| MCH 送審調用 WF | ✅ | M21 §2.2：`MCH->>WF: 建立流程實例` |

**✅ 審批鏈一致，無斷點。**

### 2.3 BEN → PAY 核准入池銜接（狀態轉換：APPROVED → PENDING_PAYMENT）

| 檢查項 | 狀態 | 說明 |
|--------|------|------|
| M14 核准後進入待發款池 | ✅ | M14 §2.1：`K[核准] → L[進入待發款池]` |
| M14 §9.4 Outbox 通知 PAY | ✅ | `通知 PAY 待發款池事件透過 Outbox 投遞` |
| M16 入池規則檢查 | ✅ | M16 §2.2 入池規則引擎：先檢查案件狀態=approved |
| M13 狀態機含 approved_pending_payment | ✅ | M13 §6.2 狀態圖：`reviewing → approved_pending_payment` |
| 全域規範狀態機含 PENDING_PAYMENT | ✅ | 全域 §3.1：`APPROVED → PENDING_PAYMENT` |

**⚠️ 狀態機命名不一致**：全域規範 §3.1 主狀態機使用 `APPROVED → PENDING_PAYMENT`，但 M13 §6.2 狀態圖中使用節點名 `approved_pending_payment`（單詞不同）。`approved_pending_payment` 接近 M14 §3.2 的 `pending_payment_flag` 命名。建議統一使用 `approved_pending_payment` 作為 `benefit_application.status` 值。

### 2.4 PAY → FIN（傳票）金額追溯

| 檢查項 | 狀態 | 說明 |
|--------|------|------|
| M17 傳票設計 | ✅ | M17 §3.1 含 `voucher`、`voucher_line`、`voucher_application` 表 |
| M17 §9.2 金額對帳檢查 | ✅ | `傳票產製時比對 voucher_total = batch.total_amount` |
| M17 傳票版本管理 | ✅ | M17 §9.7：AI 初稿與最終版分開保存 |
| M26 AI 傳票產製 | ✅ | M26 §2.4 傳票自動產製流程 |
| M17 傳票校對 | ✅ | M17 §5.5 用例五：傳票校對與金額對帳 |

**✅ 金額追溯鏈完整。**

### 2.5 BEN/PAY/ANN/MCH → WF 流程模板引用

| 檢查項 | 狀態 | 說明 |
|--------|------|------|
| BEN 調用 WF | ✅ | M13 §7.1 submit 返回 `workflow_instance_id` |
| PAY 調用 WF | ✅ | M17 §7.2 submit 返回 `workflow_instance_id` |
| ANN 調用 WF | ✅ | M19 §7.2 submit 返回 `workflow_instance_id` |
| MCH 調用 WF | ✅ | M21 §7.2 submit 通過合約送審 |
| WF 匹配模板 | ✅ | M10 §2.2：`POST /api/v1/wf/templates/match` |

**✅ 一致。**

### 2.6 BEN/PAY/ANN/MCH → M09 通知投遞

| 檢查項 | 狀態 | 說明 |
|--------|------|------|
| BEN 送審通知 | ✅ | M13 §9.4 Outbox → M09 |
| PAY 撥款通知 | ✅ | M17 §9.5 Outbox → M09 |
| PAY 領款確認通知 | ✅ | M18 §9.5 Outbox → M09 |
| ANN 發布通知（可選） | ✅ | M19 §2.2：`ANN->>M09: 發布事件（可選通知）` |
| MCH 到期提醒通知 | ✅ | M21 §5.5 用例五：呼叫 M09 發送通知 |
| SEC 告警通知 | ✅ | M23 §2.1：`J[建立 security_alert] → K[觸發通知（M09）]` |

**✅ 一致。**

### 2.7 M13 → M08 文件上傳、M13 → M26 OCR 調用

| 檢查項 | 狀態 | 說明 |
|--------|------|------|
| M13 附件上傳走 M08 | ✅ | M13 §4.1 F05：`附件上傳，走 M08` |
| M13 觸發 AI OCR | ✅ | M13 §2.1：`D[上傳附件] → E[觸發 AI OCR 辨識]` |
| M13 OCR 非阻塞 | ✅ | M13 §8.3：`AI 辨識服務不可用時不阻塞主流程` |
| M26 OCR 任務調度 | ✅ | M26 §2.1 完整 OCR 主流程 |

**⚠️ M13 問題**：M13 §2.1 流程圖中 AI OCR 在「上傳附件」之後，但在「儲存草稿」之前。M26 §2.1 則顯示 OCR 為非同步任務。M13 流程圖中的位置是「上傳附件 → 觸發 AI OCR → 儲存草稿」，這暗示 OCR 是同步的。建議在 M13 §2.1 中將 OCR 步驟明確標記為非同步，或拆分為「觸發 AI OCR（非同步）」以與 M26 保持一致。

### 2.8 M13 → M15 規則校驗調用

| 檢查項 | 狀態 | 說明 |
|--------|------|------|
| M13 送審前調用 M15 | ✅ | M13 §2.1：`L[調用 M15 送審前校驗]` |
| M15 §2.1 規則引擎 | ✅ | 完整的三類校驗（資格、附件、年度上限） |
| M15 §8.3 降級策略 | ✅ | `EMP 服務不可用時規則校驗降級為 warn` |
| M15 §9.2 冪等性 | ✅ | validate API 支援 Idempotency-Key |

**✅ 一致。**

---

## 3. 狀態機一致性檢查

### 3.1 主狀態機（全域 §3.1 vs 各模塊）

| 全域狀態 | 全域 transitions | M13 BEN | M14 BEN Admin | M16 PAY Pool | 一致性 |
|----------|-----------------|---------|---------------|-------------|--------|
| DRAFT | → PENDING_REVIEW | `draft → submitted` | `draft/submitted` | N/A | ⚠️ 全域用 `DRAFT→PENDING_REVIEW`，M13 用 `draft→submitted` |
| PENDING_REVIEW | → SUPPLEMENT / APPROVED / REJECTED | `submitted → reviewing` / `reviewing → returned` | `submitted` | N/A | ⚠️ 全域有 `SUPPLEMENT` 但多數模塊未實現 `補充文件` 中間狀態 |
| APPROVED | → PENDING_PAYMENT | `approved_pending_payment` | ✅ | N/A | ✅ |
| PENDING_PAYMENT | → PAID | N/A | N/A | `pending_selectable → locked_in_batch` | ⚠️ M16 池狀態機與全域主狀態機不同語義層級 |
| PAID | → CONFIRMED / DISPUTED | `pending_acknowledgement → closed` | N/A | N/A | ⚠️ M18 細化爲 `pending→confirmed/disputed` |
| REJECTED | → [*] | `rejected → [*]` | ✅ | N/A | ✅ |
| CLOSED | → [*] | `closed → [*]` | N/A | N/A | ✅ |

**⚠️ 三項不一致：**

1. **全域 §3.1 使用 `DRAFT → PENDING_REVIEW`，但 M13 §6.2 使用 `draft → submitted → reviewing`**。全域狀態機缺少 `submitted` 中間態。建議全域狀態機補充 `SUBMITTED` 狀態，或各模塊改用 `DRAFT → PENDING_REVIEW`。

2. **全域狀態機有 `SUPPLEMENT`（補件）狀態**，但 M13 中退回後直接回到 `submitted`，無單獨的補件狀態。BEN 業務邏輯是退回後修改重送，沒有獨立的「補充文件」階段。

3. **M16 PAY Pool 的狀態機**（`pending_selectable/locked_in_batch/abnormal`）是池狀態而非案件狀態，與全域主狀態機不衝突，但**需要在某處明確說明 PAY Pool 狀態與全域狀態的映射關係**。

### 3.2 禮金三階段狀態機一致性（M17）

| 檢查項 | 狀態 | 說明 |
|--------|------|------|
| M17 §2.2 三階段 | ✅ | `stage1_pending → stage1_done → stage2_pending → stage2_done → stage3_pending → stage3_done` |
| 三階段在 approved_ready_to_disburse 內 | ✅ | 嵌套狀態機，核准後才出現 |
| M17 §7.7 階段推進 API | ✅ | `POST /pay/batch/{batch_id}/stage/advance` |
| 跳階阻斷 | ✅ | `PAY-030：階段跳階不允許` |
| M18 不涉及禮金三階段 | ✅ | M18 獨立於三階段 |

**✅ 一致。**

---

## 4. 跨模塊契約檢查

### 4.1 審計日誌格式

全域規範 §3.3 定義審計格式：
```json
{
  "correlation_id": "UUID",
  "actor_id": "employee_id",
  "action_code": "BEN.APPROVE",
  "target_type": "benefit_application",
  "target_id": 12345,
  "old_status": "PENDING_REVIEW",
  "new_status": "APPROVED",
  "payload": { ... },
  "severity": "INFO|WARN|ERROR|CRITICAL",
  "role_snapshot": { "role": "reviewer", "org_unit_id": 10 },
  "masked_fields": ["applicant_id_number"]
}
```

| 模塊 | 審計日誌 | 格式一致 | 問題 |
|------|----------|---------|------|
| M01 | ✅ `system_audit_trail` + `login_attempt` | ✅ | 使用 `severity` 字段，但值為 `high`/`medium`（全域規範為 `INFO/WARN/ERROR/CRITICAL`） |
| M02 | ✅ `system_audit_trail` + `severity_level` | ⚠️ | 使用 `severity_level` 而非全域的 `severity` |
| M03 | ✅ `system_audit_trail` | ⚠️ | 使用 `severity_level` |
| M04 | ✅ `system_audit_trail` | ⚠️ | 使用 `severity_level` |
| M05 | ✅ `audit_event` | ✅ | 使用全域一致的 action_code 風格 `EMP.CREATE` |
| M06 | ✅ `audit_event` | ✅ | 使用 `EMP.ELIGIBILITY.CREATE` |
| M07 | ✅ `audit_event` | ✅ | 使用 `SYS.DICT_TYPE.CREATE` |
| M08 | ✅ `audit_event` | ✅ | 使用 `SYS.FILE.DOWNLOAD_SENSITIVE` |
| M09 | ✅ `audit_event` | ✅ | 使用 `SYS.NOTIFY.TEMPLATE.CREATE` |
| M10 | ✅ `audit_event` | ✅ | 使用 `WF.TEMPLATE.UPDATE` |
| M11 | ✅ `audit_event` | ✅ | 使用 `WF.TASK.APPROVE` |
| M12 | ✅ `audit_event` | ✅ | 使用 `WF.TIMEOUT.DETECTED` |
| M13 | ✅ `audit_event` | ✅ | 使用 `BEN.APPLICATION.SUBMIT` |
| M14 | ✅ `audit_event` | ✅ | 使用 `BEN.APPLICATION.APPROVE` |
| M15 | ✅ `audit_event` | ✅ | 使用 `BEN.VALIDATION.FAILED` |
| M16 | ✅ `audit_event` | ✅ | 使用 `PAY.POOL.ENTER` |
| M17 | ✅ `audit_event` | ✅ | 使用 `PAY.BATCH.CREATE` |
| M18 | ✅ `audit_event` | ✅ | 使用 `PAY.ACK.CONFIRM` |
| M19 | ✅ `audit_event` | ❓ | 未明確列出審計事件格式（僅文字描述） |
| M20 | ✅ `audit_event` | ✅ | 簡要描述 |
| M21 | ✅ `audit_event` | ✅ | 簡要描述 |
| M22 | ✅ `audit_event` | ✅ | 簡要描述 |
| M23 | ✅ `audit_event` | ✅ | 使用哈希鏈格式（比全域規範更嚴格） |
| M24 | ✅ `audit_event` | ✅ | 一致 |
| M25 | N/A | N/A | 索引文件 |
| M26 | ✅ `audit_event` | ✅ | 一致 |

**⚠️ 三項不一致：**

1. **審計事件表名不一致**：M01-M04 使用 `system_audit_trail`，M05-M26 使用 `audit_event`。全域規範 §3.3 寫為 `audit_event` 表。建議統一為 `audit_event`。

2. **severity 字段名不一致**：全域規範使用 `severity`，但 M01-M04 部分使用 `severity_level`（M02 §9.1 表格標題、M03 §9.1 表格標題）。建議統一為 `severity`。

3. **M01 審計字段值**：全域規範 severity 值為 `INFO|WARN|ERROR|CRITICAL`，但 M01 §9.1 表中使用 `info/low/medium/high`。建議統一。

### 4.2 Idempotency-Key 規範

全域規範 §3.2：所有變更型 API 支援 `Idempotency-Key` header，UUID v4，保留 24 小時。

| 模塊 | 支援 Idempotency-Key | 一致性 |
|------|---------------------|--------|
| M01 | ✅ login, mfa/verify | ✅ |
| M02 | ✅ activation/initiate, verify, password-reset, sso/bind | ✅ |
| M03 | ✅ /org/assignments | ✅ |
| M04 | ✅ /org/account-roles | ✅ |
| M05 | ✅ PUT employees, POST dependents | ✅ |
| M06 | ✅ POST eligibility, snapshot/rebuild | ✅ |
| M07 | ✅ PUT parameters | ✅ |
| M08 | ✅ 檔案狀態變更（上傳不支援冪等，合理） | ✅ |
| M09 | ✅ /notifications/emit | ✅ |
| M10 | ✅ /wf/instances | ✅ |
| M11 | ✅ /wf/tasks/{taskId}/actions | ✅ |
| M12 | N/A（排程自動操作） | ✅ （合理） |
| M13 | ✅ /ben/applications/{id}/submit | ✅ |
| M14 | ✅ 審批 API | ✅ |
| M15 | ✅ /ben/validations/validate | ✅ |
| M16 | ✅ pool/enter, lock, release | ✅ |
| M17 | ✅ batch create, submit, disburse | ✅ |
| M18 | ✅ confirm, dispute, action | ✅ |
| M19 | ✅ 送審 API | ✅ |
| M20 | N/A（前台唯讀） | ✅ （合理） |
| M21 | ✅ 送審 API | ✅ |
| M22 | N/A（前台唯讀+配置 API） | ⚠️ 配置 API（PUT benefit-rule）未提及 Idempotency-Key |
| M23 | ✅ correlation_id 去重（等價於 Idempotency-Key） | ✅ |
| M24 | ✅ 告警處置 API | ✅ |
| M25 | N/A | 索引文件 |
| M26 | ✅ duplicate-check 支援 Idempotency-Key | ✅ |

**⚠️ M22 配置 API 未明確支援 Idempotency-Key**：M22 §7.2 的 PUT benefit-rule、eligibility-rules、contact-points 等 API 未提及 Idempotency-Key。建議補充。

### 4.3 row_version 樂觀鎖

全域規範 §3.4：所有主數據表使用 `row_version`（bigint），UPDATE 時檢查。

| 模塊 | row_version | 一致性 |
|------|------------|--------|
| M01 | ✅ `user_account.row_version` | ✅ |
| M02 | ✅ `account_activation_request.row_version` | ✅ |
| M03 | ✅ `org_node.row_version`, `employee_assignment.row_version` | ✅ |
| M04 | ✅ `role.row_version` 等 | ✅ |
| M05 | ✅ `employee.row_version` | ✅ |
| M06 | ✅ `eligibility_history.row_version` 等 | ✅ |
| M07 | ✅ 所有表 | ✅ |
| M08 | ✅ `file_object.row_version` | ✅ |
| M09 | ✅ 所有通知表 | ✅ |
| M10 | ✅ `workflow_template.row_version` | ✅ |
| M11 | ✅ `review_task.row_version` | ✅ |
| M12 | N/A（追加寫為主） | ✅ （合理） |
| M13 | ✅ `benefit_application.row_version` | ✅ |
| M14 | ✅ 同 M13 | ✅ |
| M15 | ✅ `validation_result`（間接使用 application.row_version） | ✅ |
| M16 | ✅ `pending_payment_pool.row_version` | ✅ |
| M17 | ✅ `payment_batch.row_version` | ✅ |
| M18 | ✅ `payment_batch_item.row_version`, `dispute_case.row_version` | ✅ |
| M19 | ✅ `announcement.revision` | ⚠️ 字段名為 `revision` 而非 `row_version` |
| M20 | N/A（前台唯讀） | ✅ （合理） |
| M21 | ✅ `merchant.revision`, `merchant_contract.revision` | ⚠️ 字段名為 `revision` 而非 `row_version` |
| M22 | ✅ `revision` 在 benefit_rule 等表 | ⚠️ 字段名為 `revision` 而非 `row_version` |
| M23 | ✅ `security_rule.revision` | ⚠️ 字段名為 `revision` 而非 `row_version` |
| M24 | ✅ `security_alert.revision` | ⚠️ 字段名為 `revision` |
| M25 | N/A | 索引文件 |
| M26 | N/A（任務表追加寫為主） | ✅ （合理） |

**⚠️ 字段名不一致**：M01-M18 使用 `row_version`（符合全域規範），但 M19/M21/M22/M23/M24 使用 `revision` 作為樂觀鎖字段名。建議統一為 `row_version`。

### 4.4 Outbox 模式

全域規範 §3.5：業務操作與 Outbox 事件在同一資料庫事務中寫入。

| 模塊 | Outbox 模式 | 一致性 |
|------|------------|--------|
| M02 | ✅ OTP 發送使用 Outbox | ✅ |
| M04 | ✅ 快取失效事件使用 Outbox | ✅ |
| M05 | ✅ employee.created 事件使用 outbox_event | ✅ |
| M09 | ✅ 通知模塊自帶 Outbox（notification_outbox） | ✅ |
| M10 | ✅ 流程實例創建後通知使用 Outbox | ✅ |
| M11 | ✅ 審批動作後 Outbox | ✅ |
| M12 | ✅ 超時事件使用 Outbox | ✅ |
| M13 | ✅ 送審成功後通知使用 Outbox | ✅ |
| M14 | ✅ 審批完成後 Outbox 通知 PAY | ✅ |
| M16 | ✅ pool 操作使用 Outbox | ✅ |
| M17 | ✅ 回填完成後 Outbox | ✅ |
| M18 | ✅ 確認/異議事件使用 Outbox | ✅ |
| M26 | ✅ OCR 任務使用 Outbox/佇列 | ✅ |

**✅ Outbox 模式在所有相關模塊中一致。**

### 4.5 錯誤碼體系

全域規範 §3.6 定義各模塊錯誤碼範圍。

| 模塊 | 錯誤碼前綴 | 使用範圍 | 一致性 |
|------|-----------|---------|--------|
| M01 | AUTH- | 001~021 | ✅ |
| M02 | AUTH- | 030~041 | ✅ |
| M03 | ORG- | 001~013 | ✅ |
| M04 | ORG- | 020~023 | ✅ |
| M05 | EMP- | 001~009 | ✅ |
| M06 | EMP- | 003, 008, 009 | ✅ |
| M07 | SYS- | 001~005 | ✅ |
| M08 | SYS- | 006~013 | ✅ |
| M09 | SYS- | 020~022 | ✅ |
| M10 | WF- | 001~011 | ✅ |
| M11 | WF- | 020~026 | ✅ |
| M12 | WF- | 030~032 | ✅ |
| M13 | BEN- | 001~008 | ✅ |
| M14 | BEN- | 010~014 | ✅ |
| M15 | BEN- | 020~025 | ✅ |
| M16 | PAY- | 001, 010~011, 020~021 | ✅ |
| M17 | PAY- | 020~027, 030 | ✅ |
| M18 | PAY- | 040~045, 050~053 | ✅ |
| M19 | ANN- | 001~004 | ✅ |
| M20 | ANN- | 020~022 | ✅ |
| M21 | MCH- | 001~005 | ✅ |
| M22 | MCH- | 020~023 | ✅ |
| M23 | SEC- | 001~005 | ✅ |
| M24 | SEC- | 020~024 | ✅ |
| M25 | N/A | N/A | N/A |
| M26 | AI- | 001~005 | ✅ |

**⚠️ M05 M06 錯誤碼範圍重疊**: M05 使用 EMP-001~007，M06 使用 EMP-003、EMP-008、EMP-009。EMP-003 被兩個模塊使用（M05 為「必填字段缺失」，M06 為「資格類型為空」）。建議 M06 使用 EMP-008~015 範圍，避免與 M05 的 EMP-003 衝突。

**⚠️ M01 全域錯誤碼**: M01 §7.1 引用了 `GBL-001`（500 系統錯誤），但全域規範 §3.6 中 GBL-001~099 定義為「全局通用錯誤」。需確認 GBL 系列是否真的在程式碼層級實現。

---

## 5. 角色權限一致性

### 5.1 六個角色在各模塊中的定義

| 模塊 | 一般職工 | 福利社承辦人 | 審核主管 | 財務人員 | 系統管理員 | 資安稽核人員 |
|------|---------|------------|---------|---------|-----------|------------|
| M01 | ✅ | ✅ (管理端) | ✅ (管理端) | ❌ | ✅ (系統管理者) | ✅ (資安稽核) |
| M02 | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ |
| M03 | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| M04 | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| M05 | ✅ (本人) | ✅ | ✅ | ❌ | ✅ | ✅ |
| M06 | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| M07 | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| M08 | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| M09 | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| M10 | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| M11 | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| M12 | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| M13 | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| M14 | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| M15 | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |
| M16 | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| M17 | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| M18 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| M19 | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| M20 | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| M21 | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |
| M22 | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| M23 | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| M24 | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| M25 | N/A | N/A | N/A | N/A | N/A | N/A |
| M26 | ✅ (間接) | ✅ (承辦人) | ❌ | ❌ | ✅ | ❌ |

**⚠️ 問題總結：**

1. **「財務人員」角色僅在 M17 出現**：M17 §1.3 定義了「財務人員」角色（傳票校對），但其他模塊（尤其是 M16 待發款池、M18 領款確認）中未提及此角色。需確認財務人員是否僅在 M17 中操作，如是則合理；否則需在其他 PAY 模塊中補充。

2. **模塊角色表格式不一致**：
   - M01-M06 使用標準表格
   - M07-M12、M19-M26 使用簡化列表或表格
   - M13-M18 使用更精簡的說明

3. **角色命名不一致**：
   - M01 將承辦人稱為「福利社承辦人（管理者）」，M03 改為「福利社承辦人」
   - M01 將系統管理員稱為「系統管理員（系統管理者）」，其他模塊為「系統管理員」
   - M01 將資安人員稱為「資安稽核人員」，M23-M24 也稱「資安稽核人員」—✅ 一致

---

## 6. 總計發現的問題清單

| 編號 | 嚴重級別 | 模塊 | 問題描述 | 修復建議 |
|------|---------|------|---------|---------|
| 1 | 🔴 高 | M05 | `employee.org_unit_id FK` 指向 `org_unit` 而非 M03 的 `org_node` | 統一為 `org_node` |
| 2 | 🔴 高 | M01-M04 vs M05+ | 審計表名不一致：`system_audit_trail` vs `audit_event` | 統一為 `audit_event` |
| 3 | 🔴 高 | M01-M04 | 審計 severity 值：使用 `low/medium/high` 而非全域的 `INFO/WARN/ERROR/CRITICAL` | 統一為 `INFO/WARN/ERROR/CRITICAL` |
| 4 | 🔴 高 | M19/M21/M22/M23/M24 | 樂觀鎖字段名為 `revision` 而非 `row_version` | 統一為 `row_version` |
| 5 | 🟡 中 | 全域 | 全域狀態機 `DRAFT→PENDING_REVIEW` 與 M13 `draft→submitted→reviewing` 不一致 | 全域狀態機補充 SUBMITTED，或 M13 改用 PENDING_REVIEW |
| 6 | 🟡 中 | M02 | 審計日誌使用 `severity_level` 字段名（全域為 `severity`） | 統一為 `severity` |
| 7 | 🟡 中 | M13 | AI OCR 在流程圖中表現為同步（在儲存草稿之前），但 M26 定義為非同步 | M13 §2.1 流程圖中將 OCR 標為非同步 |
| 8 | 🟡 中 | M22 | PUT benefit-rule、eligibility-rules 等 API 未提及 Idempotency-Key | 補充 Idempotency-Key 支援 |
| 9 | 🟡 中 | M05/M06 | 錯誤碼 EMP-003 被兩個模塊共用 | M06 改用 EMP-008~015 |
| 10 | 🟡 中 | M13 §6.2 | 狀態節點名 `approved_pending_payment` 與全域的 `PENDING_PAYMENT` 不一致 | 建議統一命名風格 |
| 11 | 🟡 中 | M17 | 「財務人員」角色僅在 M17 中定義，其他 PAY 模塊未提及 | 確認財務人員範圍，必要時補充 |
| 12 | 🟢 低 | M13/M18 | M13 狀態機無 `disputed` 狀態，M18 的爭議狀態未反映在 BEN 狀態機中 | 補充 `disputed` 狀態在 M13 狀態機中的體現 |
| 13 | 🟢 低 | 全域 | 全域狀態機的 `SUPPLEMENT` 狀態在業務模塊中未實現 | 確認是否需要保留 SUPPLEMENT |
| 14 | 🟢 低 | M01 | GBL-001 全域錯誤碼被引用但未在任一模塊中正式定義 | 確認 GBL-xxx 是否需獨立文件 |

---

## 7. 總結

**模塊完整性**：✅ 26 個模塊全部存在

**嚴重問題（需立即修復）**：
- 審計表名、severity 字段名、樂觀鎖字段名不一致（問題 2/3/4）
- M05 FK 引用命名不一致（問題 1）

**中等問題（建議在 v2 發佈前修復）**：
- 主狀態機命名不一致（問題 5/10）
- 部分模塊缺少 Idempotency-Key（問題 8）
- 錯誤碼重疊（問題 9）
- AI OCR 同步/非同步語義不一致（問題 7）
- 角色定義範圍不一致（問題 11）

**低優先級**：
- 全域狀態機的 SUPPLEMENT 狀態未落地（問題 13）
- M13 狀態機缺少 dispute 路徑（問題 12）
- GBL 錯誤碼無獨立定義（問題 14）

**整體評估**：跨模塊契約的主體框架（審計日誌、冪等性、樂觀鎖、Outbox 模式、錯誤碼體系）在 26 個模塊中基本保持一致，不存在致命斷點。主要問題集中在字段命名一致性（`severity` vs `severity_level`、`row_version` vs `revision`、`system_audit_trail` vs `audit_event`）和狀態機命名風格。建議統一命名後即可解決大部分問題。
