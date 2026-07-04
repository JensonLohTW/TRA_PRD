# 稽核系統後台 Sitemap

## 路由架構圖

```mermaid
flowchart TD
    Login["/security/login 登入 (MFA)"]
    Dashboard["/security 資安儀表板"]

    subgraph 稽核日誌
        AuditLogs["/security/audit-logs 日誌查詢"]
        AuditDetail["/security/audit-logs/[id] 日誌詳情"]
    end

    subgraph 告警管理
        Alerts["/security/alerts 告警列表"]
        AlertDetail["/security/alerts/[id] 告警處置"]
    end

    subgraph 掃描規則
        Rules["/security/rules 掃描規則"]
        ScanRuns["/security/scan-runs 掃描紀錄"]
        ScanRunDetail["/security/scan-runs/[id] 掃描詳情"]
    end

    subgraph 封存與報表
        Archives["/security/archives 封存管理"]
        ArchiveDetail["/security/archives/[id] 封存詳情"]
        Reports["/security/reports 資安報表"]
        ReportDetail["/security/reports/[id] 報表詳情"]
    end

    Settings["/security/settings 資安設定"]

    Login --> Dashboard
    Dashboard --> AuditLogs & Alerts & Rules & Archives

    AuditLogs --> AuditDetail
    Alerts --> AlertDetail
    Rules --> ScanRuns
    ScanRuns --> ScanRunDetail
    Archives --> ArchiveDetail
    Reports --> ReportDetail
```

## 各頁面摘要

| 路由 | 標題 | 角色 |
|------|------|------|
| /security/login | 資安後台登入 | 未登入 |
| /security | 資安儀表板 | 稽核者/管理者 |
| /security/audit-logs | 稽核日誌查詢 | 稽核者 |
| /security/audit-logs/[id] | 日誌詳情 | 稽核者 |
| /security/alerts | 告警列表 | 稽核者 |
| /security/alerts/[id] | 告警處置 | 稽核者 |
| /security/rules | 掃描規則 | 稽核者/管理者 |
| /security/scan-runs | 掃描紀錄 | 稽核者 |
| /security/scan-runs/[id] | 掃描詳情 | 稽核者 |
| /security/archives | 封存管理 | 稽核者/管理者 |
| /security/archives/[id] | 封存包詳情 | 稽核者/管理者 |
| /security/reports | 資安報表 | 稽核者/管理者 |
| /security/reports/[id] | 報表詳情 | 稽核者/管理者 |
| /security/settings | 資安設定 | 系統管理者 |
