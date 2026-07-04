# 管理端 Sitemap

## 路由架構圖

```mermaid
flowchart TD
    Login["/admin/login 登入 (MFA)"]
    Dashboard["/admin 管理儀表板"]

    subgraph 補助業務
        Benefits["/admin/benefits 案件列表"]
        BenefitDetail["/admin/benefits/[id] 案件詳情"]
        ReviewTasks["/admin/review-tasks 待辦中心"]
        ReviewTaskDetail["/admin/review-tasks/[id] 待辦詳情"]
    end

    subgraph 撥款與財務
        Pool["/admin/payment/pool 待發款池"]
        Batches["/admin/payment/batches 發款批次"]
        BatchDetail["/admin/payment/batches/[id] 批次詳情"]
        Reimbursements["/admin/payment/reimbursements 報銷單"]
        Vouchers["/admin/payment/vouchers 傳票管理"]
        Acknowledgements["/admin/payment/acknowledgements 領款確認"]
        Disputes["/admin/payment/disputes 異議案件"]
    end

    subgraph 內容管理
        Announcements["/admin/announcements 公告管理"]
        AnnouncementEdit["/admin/announcements/[id] 公告編輯"]
        Merchants["/admin/merchants 商店管理"]
        MerchantDetail["/admin/merchants/[id] 商店編輯"]
    end

    subgraph 組織與權限
        Org["/admin/org 組織管理"]
        Roles["/admin/org/roles 角色管理"]
        Perms["/admin/org/permissions 權限管理"]
        Assignments["/admin/org/assignments 人員配置"]
    end

    subgraph 人員
        Employees["/admin/employees 人員列表"]
        EmployeeDetail["/admin/employees/[id] 員工詳情"]
        Import["/admin/employees/import 批次匯入"]
    end

    subgraph 設定
        BenSettings["/admin/benefit-settings 補助設定"]
        SystemDict["/admin/system/dict 字典"]
        SystemConfig["/admin/system/config 系統參數"]
        Files["/admin/system/files 檔案中心"]
        NotifTemplates["/admin/system/notification-templates 通知模板"]
        Ocr["/admin/ocr AI 辨識"]
        Reports["/admin/reports 統計報表"]
        Settings["/admin/settings 個人設定"]
    end

    Login --> Dashboard
    Dashboard --> Benefits & Pool & Announcements & Employees

    Benefits --> BenefitDetail
    BenefitDetail --> ReviewTasks

    ReviewTasks --> ReviewTaskDetail
    ReviewTaskDetail --> BenefitDetail

    Pool --> Batches
    Batches --> BatchDetail
    Batches --> Reimbursements
    Batches --> Vouchers
    Acknowledgements --> Disputes

    Announcements --> AnnouncementEdit
    Merchants --> MerchantDetail

    Org --> Roles & Perms & Assignments
    Employees --> EmployeeDetail
    Employees --> Import

    BenSettings --> SystemDict
    SystemDict --> SystemConfig
```

## 各頁面摘要

| 路由 | 標題 | 角色 |
|------|------|------|
| /admin/login | 管理端登入 | 未登入 |
| /admin | 管理儀表板 | 全域 |
| /admin/benefits | 案件列表 | 承辦人/主管/管理者 |
| /admin/benefits/[id] | 案件詳情 | 承辦人/主管/管理者 |
| /admin/review-tasks | 待辦中心 | 承辦人/主管 |
| /admin/review-tasks/[id] | 待辦詳情 | 承辦人/主管 |
| /admin/payment/pool | 待發款池 | 承辦人/財務 |
| /admin/payment/batches | 發款批次 | 承辦人/財務 |
| /admin/payment/batches/[id] | 批次詳情 | 承辦人/財務 |
| /admin/payment/reimbursements | 報銷單 | 財務 |
| /admin/payment/vouchers | 傳票管理 | 財務 |
| /admin/payment/acknowledgements | 領款確認 | 承辦人/財務 |
| /admin/payment/disputes | 異議案件 | 承辦人/財務 |
| /admin/announcements | 公告管理 | 承辦人/主管 |
| /admin/announcements/[id] | 公告編輯 | 承辦人 |
| /admin/merchants | 商店管理 | 承辦人 |
| /admin/merchants/[id] | 商店編輯 | 承辦人 |
| /admin/org | 組織管理 | 系統管理者 |
| /admin/org/roles | 角色管理 | 系統管理者 |
| /admin/org/permissions | 權限管理 | 系統管理者 |
| /admin/org/assignments | 人員配置 | 系統管理者 |
| /admin/employees | 人員列表 | 系統管理者/承辦人 |
| /admin/employees/[id] | 員工詳情 | 系統管理者/承辦人 |
| /admin/employees/import | 批次匯入 | 系統管理者 |
| /admin/benefit-settings | 補助設定 | 系統管理者 |
| /admin/system/dict | 字典管理 | 系統管理者 |
| /admin/system/config | 系統參數 | 系統管理者 |
| /admin/system/files | 檔案中心 | 系統管理者 |
| /admin/system/notification-templates | 通知模板 | 系統管理者 |
| /admin/ocr | AI 辨識管理 | 承辦人/系統管理者 |
| /admin/reports | 統計報表 | 承辦人/主管/管理者 |
| /admin/settings | 個人設定 | 全域 |
