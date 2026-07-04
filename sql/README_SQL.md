# 台鐵職工福利平台 — SQL 資料庫說明文件

## 環境需求

- MySQL 8.x（需支援 InnoDB、JSON、CTE、Window Functions）
- 測試用空白資料庫 `tra_welfare_test`

## 連接設定

使用 MySQL option file 保存憑證，**不將憑證寫入版本控制**：

```ini
# ~/.my_tra.cnf
[client]
host=127.0.0.1
port=3306
user=tra_app
password=your_password_here
```

執行時：

```bash
export MYSQL_CNF="$HOME/.my_tra.cnf"
```

## 檔案結構

```
sql/
├── modules/              # 可獨立安裝的模組 DDL
│   ├── 00_database.sql   # 資料庫初始化
│   ├── 01_sys.sql         # 系統基礎
│   ├── 02_file.sql        # 檔案資源
│   ├── 03_org.sql         # 組織架構
│   ├── 04_emp.sql         # 職工眷屬
│   ├── 05_iam.sql         # 身份認證
│   ├── 06_rbac.sql        # 權限控制
│   ├── 07_ntf.sql         # 通知服務
│   ├── 08_ben_config.sql  # 補助配置
│   ├── 09_ben_application.sql  # 補助申請
│   ├── 10_workflow.sql    # 工作流
│   ├── 11_payment.sql     # 發款禮金
│   ├── 12_finance.sql     # 財務文件
│   ├── 13_ai_ocr.sql      # OCR 與預警
│   ├── 14_merchant.sql    # 特約商店
│   ├── 15_announcement.sql # 公告發佈
│   ├── 16_security_audit.sql # 稽核資安
│   ├── 17_functions_procedures.sql # 函數與程序
│   ├── 18_triggers.sql    # 觸發器
│   ├── 19_views.sql       # 視圖
│   ├── 20_seed_common.sql # 通用種子
│   └── 99_verify.sql      # 最終驗證
├── tests/                # 模組契約測試
│   └── 00_environment.sql
├── scripts/              # 工具腳本
│   ├── assemble_sql.sh    # 拼接 all_in_one.sql
│   └── verify_sql.sh      # 執行驗證
├── baseline/             # 現有 v3 SQL 基線
│   └── tra_welfare_platform_v3.sql
├── all_in_one.sql        # 整合檔案（由 assemble_sql.sh 產生）
├── tra_welfare_platform.sql  # 保留現有正式檔案
└── README_SQL.md         # 本文件
```

## 執行順序

### 完整安裝

```bash
# 1. 初始化資料庫
mysql --defaults-extra-file="$MYSQL_CNF" < sql/modules/00_database.sql

# 2. 依序安裝模組
for mod in sql/modules/0*.sql sql/modules/1*.sql sql/modules/99_verify.sql; do
    mysql --defaults-extra-file="$MYSQL_CNF" tra_welfare_test < "$mod"
done
```

### 使用整合檔案

```bash
mysql --defaults-extra-file="$MYSQL_CNF" < sql/all_in_one.sql
```

### 使用驗證腳本

```bash
MYSQL_CNF="$HOME/.my_tra.cnf" bash sql/scripts/verify_sql.sh
```

## 重跑策略

- `00_database.sql`：冪等（CREATE DATABASE IF NOT EXISTS）
- 模組 DDL（01-16, 18）：冪等（CREATE TABLE IF NOT EXISTS）
- `17_functions_procedures.sql`：冪等（CREATE OR REPLACE）
- `19_views.sql`：冪等（CREATE OR REPLACE VIEW）
- `20_seed_common.sql`：冪等（使用 INSERT IGNORE 與條件檢查）
- `99_verify.sql`：唯讀，可重複執行

全部模組設計為可在同一資料庫安全重跑，不會產生重複表或重複種子。

## 憑證安全

- MYSQL_CNF 指向的 MySQL option file 不應保存在此專案目錄中
- 資料庫帳號僅授權測試庫所需最低權限
- 正式環境憑證由各機關依安全規範管理

## 模組依賴方向

```
SYS ─→ FILE
  ├──→ ORG ───→ EMP ─→ IAM ─→ RBAC ─→ NTF
  └──→ (其餘模組透過 SYS 的事件發件箱與編號服務)
```

模組間透過穩定外鍵和專用橋接表連接，不使用多態 target_type/target_id 通用關聯。
