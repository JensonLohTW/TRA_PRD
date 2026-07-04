# API 路由總覽

## 說明

本文件整理三大前端端口對應的後端 API 路由，依服務模組分類。

---

## 1. 認證服務（AUTH）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| POST | /api/v1/auth/otp | 取得 OTP 驗證碼 | PWA/管理/稽核 |
| POST | /api/v1/auth/login | 登入 | PWA/管理/稽核 |
| POST | /api/v1/auth/mfa | MFA 二次驗證 | 管理/稽核 |
| POST | /api/v1/auth/refresh | 刷新 Token | PWA/管理/稽核 |
| POST | /api/v1/auth/logout | 登出 | PWA/管理/稽核 |
| POST | /api/v1/auth/activate | 帳號啟用 | PWA |
| POST | /api/v1/auth/reset-password | 重設密碼 | PWA/管理/稽核 |
| POST | /api/v1/auth/forgot-password | 忘記密碼第一步 | PWA/管理/稽核 |

## 2. 員工服務（EMP）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/employees | 查詢員工列表 | 管理 |
| GET | /api/v1/employees/{id} | 查詢員工詳情 | PWA/管理 |
| PUT | /api/v1/employees/{id} | 更新員工資料 | PWA/管理 |
| GET | /api/v1/employees/{id}/dependents | 查詢眷屬列表 | PWA/管理 |
| POST | /api/v1/employees/{id}/dependents | 新增眷屬 | PWA/管理 |
| PUT | /api/v1/employees/dependents/{id} | 更新眷屬 | PWA/管理 |
| DELETE | /api/v1/employees/dependents/{id} | 刪除眷屬 | PWA/管理 |
| GET | /api/v1/employees/{id}/eligibility-history | 資格歷史 | 管理 |
| GET | /api/v1/employees/{id}/deduction-history | 扣繳歷史 | 管理 |
| POST | /api/v1/employees/import | 批次匯入 | 管理 |
| GET | /api/v1/employees/export | 匯出員工 | 管理 |

## 3. 組織服務（ORG）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/org/nodes | 組織樹 | 管理 |
| POST | /api/v1/org/nodes | 新增節點 | 管理 |
| PUT | /api/v1/org/nodes/{id} | 更新節點 | 管理 |
| DELETE | /api/v1/org/nodes/{id} | 刪除節點 | 管理 |
| GET | /api/v1/org/roles | 角色列表 | 管理 |
| POST | /api/v1/org/roles | 新增角色 | 管理 |
| PUT | /api/v1/org/roles/{id} | 更新角色+權限 | 管理 |
| GET | /api/v1/org/permissions | 權限列表 | 管理 |
| GET | /api/v1/org/assignments | 人員配置列表 | 管理 |
| POST | /api/v1/org/assignments | 新增配置 | 管理 |
| PUT | /api/v1/org/assignments/{id} | 更新配置 | 管理 |

## 4. 補助業務（BEN）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/ben/types | 補助類型列表 | PWA/管理 |
| GET | /api/v1/ben/types/{id}/form-version | 當前表單 schema | PWA |
| GET | /api/v1/ben/applications | 我的申請/案件列表 | PWA/管理 |
| POST | /api/v1/ben/applications | 建立申請草稿 | PWA |
| GET | /api/v1/ben/applications/{id} | 申請詳情（聚合） | PWA/管理 |
| PUT | /api/v1/ben/applications/{id} | 更新草稿 | PWA |
| POST | /api/v1/ben/applications/{id}/submit | 送審 | PWA |
| POST | /api/v1/ben/applications/{id}/approve | 核准 | 管理 |
| POST | /api/v1/ben/applications/{id}/return | 退回 | 管理 |
| POST | /api/v1/ben/applications/{id}/reject | 駁回 | 管理 |
| GET | /api/v1/ben/applications/{id}/pdf | 產製 PDF | PWA |
| POST | /api/v1/ben/applications/{id}/acknowledge | 領款確認 | PWA |
| GET | /api/v1/ben/applications/statistics | 統計摘要 | PWA/管理 |
| GET | /api/v1/ben/applications/export | 匯出案件 | 管理 |

## 5. 流程引擎（WF）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/wf/tasks | 待辦列表 | 管理 |
| GET | /api/v1/wf/tasks/{id} | 待辦詳情 | 管理 |
| GET | /api/v1/wf/instances/{id} | 流程實例 | 管理 |
| GET | /api/v1/wf/instances/{id}/steps | 流程節點 | 管理 |

## 6. 發款與撥款（PAY）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/pay/pool | 待發款池 | 管理 |
| POST | /api/v1/pay/batches | 建立批次 | 管理 |
| GET | /api/v1/pay/batches | 批次列表 | 管理 |
| GET | /api/v1/pay/batches/{id} | 批次詳情 | 管理 |
| POST | /api/v1/pay/batches/{id}/submit | 批次送審 | 管理 |
| POST | /api/v1/pay/batches/{id}/approve | 批次核准 | 管理 |
| POST | /api/v1/pay/batches/{id}/disburse | 撥款回填 | 管理 |
| POST | /api/v1/pay/batches/{id}/generate-voucher | 產製傳票 | 管理 |
| GET | /api/v1/pay/batches/{id}/export-roster | 匯出名冊 | 管理 |
| GET | /api/v1/pay/acknowledgements | 領款確認列表 | 管理 |
| GET | /api/v1/pay/disputes | 異議案件列表 | 管理 |
| GET | /api/v1/pay/disputes/{id} | 異議詳情 | 管理 |
| POST | /api/v1/pay/disputes/{id}/resolve | 解決異議 | 管理 |
| POST | /api/v1/pay/disputes/{id}/reject | 駁回異議 | 管理 |

## 7. 檔案服務（FILE）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| POST | /api/v1/files/upload | 上傳檔案 | PWA/管理 |
| GET | /api/v1/files/{id} | 檔案資訊 | PWA/管理/稽核 |
| GET | /api/v1/files/{id}/download | 下載檔案 | PWA/管理/稽核 |
| GET | /api/v1/files/{id}/preview | 預覽檔案 | PWA/管理 |
| GET | /api/v1/files | 檔案列表（管理） | 管理 |
| GET | /api/v1/files/{id}/download-log | 下載紀錄 | 管理/稽核 |

## 8. 通知服務（NTF）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/notifications | 通知列表 | PWA |
| GET | /api/v1/notifications/unread-count | 未讀數 | PWA |
| PUT | /api/v1/notifications/{id}/read | 標記已讀 | PWA |
| PUT | /api/v1/notifications/read-all | 全部已讀 | PWA |
| GET | /api/v1/notification-templates | 模板列表 | 管理 |
| POST | /api/v1/notification-templates | 新增模板 | 管理 |
| PUT | /api/v1/notification-templates/{id} | 更新模板 | 管理 |

## 9. 公告服務（ANN）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/announcements | 公告列表 | PWA/管理 |
| GET | /api/v1/announcements/{id} | 公告詳情 | PWA/管理 |
| POST | /api/v1/announcements | 建立公告 | 管理 |
| PUT | /api/v1/announcements/{id} | 更新公告 | 管理 |
| POST | /api/v1/announcements/{id}/submit | 送審公告 | 管理 |
| POST | /api/v1/announcements/{id}/publish | 發布公告 | 管理 |
| GET | /api/v1/policy-documents | 規章文件列表 | PWA |

## 10. 特約商店（MCH）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/merchants | 商店列表 | PWA/管理 |
| GET | /api/v1/merchants/{id} | 商店詳情 | PWA/管理 |
| POST | /api/v1/merchants | 建立商店 | 管理 |
| PUT | /api/v1/merchants/{id} | 更新商店 | 管理 |
| GET | /api/v1/merchants/categories | 分類列表 | PWA/管理 |
| POST | /api/v1/merchants/{id}/contracts | 新增合約 | 管理 |
| PUT | /api/v1/merchants/contracts/{id} | 更新合約 | 管理 |
| POST | /api/v1/merchants/contracts/{id}/submit | 合約送審 | 管理 |

## 11. 字典與系統（SYS）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/sys/dict/{dictType} | 字典值列表 | 全域 |
| POST | /api/v1/sys/dict | 新增字典值 | 管理 |
| PUT | /api/v1/sys/dict/{id} | 更新字典值 | 管理 |
| GET | /api/v1/sys/config | 系統參數列表 | 管理 |
| PUT | /api/v1/sys/config/{key} | 更新系統參數 | 管理 |

## 12. AI OCR 服務（AI）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/ai/recognitions | 辨識結果列表 | 管理 |
| GET | /api/v1/ai/recognitions/{id} | 辨識詳情 | 管理 |
| PUT | /api/v1/ai/recognitions/{id}/correct | 人工校正 | 管理 |

## 13. 稽核與資安（SEC）

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/sec/audit-logs | 稽核日誌查詢 | 稽核 |
| GET | /api/v1/sec/audit-logs/{id} | 日誌詳情 | 稽核 |
| GET | /api/v1/sec/audit-logs/export | 匯出日誌 | 稽核 |
| GET | /api/v1/sec/alerts | 告警列表 | 稽核 |
| GET | /api/v1/sec/alerts/{id} | 告警詳情 | 稽核 |
| PUT | /api/v1/sec/alerts/{id}/assign | 分派告警 | 稽核 |
| PUT | /api/v1/sec/alerts/{id}/acknowledge | 已知悉 | 稽核 |
| PUT | /api/v1/sec/alerts/{id}/resolve | 結案告警 | 稽核 |
| GET | /api/v1/sec/rules | 掃描規則列表 | 稽核 |
| PUT | /api/v1/sec/rules/{id} | 更新規則 | 稽核 |
| GET | /api/v1/sec/scan-runs | 掃描紀錄 | 稽核 |
| GET | /api/v1/sec/archives | 封存包列表 | 稽核 |
| POST | /api/v1/sec/archives/generate | 產製封存包 | 稽核 |
| GET | /api/v1/sec/archives/{id}/download | 下載封存包 | 稽核 |
| GET | /api/v1/sec/reports | 資安報表 | 稽核 |
| POST | /api/v1/sec/reports/generate | 產製報表 | 稽核 |

## 14. 統計報表

| 方法 | 路徑 | 說明 | 使用端 |
|------|------|------|--------|
| GET | /api/v1/reports/dashboard | 儀表板統計 | 管理 |
| GET | /api/v1/reports/applications | 申請統計 | 管理 |
| GET | /api/v1/reports/payments | 撥款統計 | 管理 |
| GET | /api/v1/reports/export | 匯出報表 | 管理 |
