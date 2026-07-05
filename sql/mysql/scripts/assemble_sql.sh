#!/usr/bin/env bash
# ============================================================================
# 台鐵職工福利平台 — 模組拼接腳本
# 功能：依固定清單拼接模組 SQL 至 all_in_one.sql
# 使用：bash sql/scripts/assemble_sql.sh
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/all_in_one.sql"

# 固定模組順序清單（不依賴目錄通配）
MODULES=(
    "modules/00_database.sql"
    "modules/01_sys.sql"
    "modules/02_file.sql"
    "modules/03_org.sql"
    "modules/04_emp.sql"
    "modules/05_iam.sql"
    "modules/06_rbac.sql"
    "modules/07_ntf.sql"
    "modules/08_ben_config.sql"
    "modules/09_ben_application.sql"
    "modules/10_workflow.sql"
    "modules/11_payment.sql"
    "modules/12_finance.sql"
    "modules/13_ai_ocr.sql"
    "modules/14_merchant.sql"
    "modules/15_announcement.sql"
    "modules/16_security_audit.sql"
    "modules/17_functions_procedures.sql"
    "modules/18_triggers.sql"
    "modules/19_views.sql"
    "modules/20_seed_common.sql"
    "modules/99_verify.sql"
)

echo "==> 檢查所有模組檔案存在..."
for mod in "${MODULES[@]}"; do
    if [ ! -f "${SCRIPT_DIR}/${mod}" ]; then
        echo "錯誤：遺失模組檔案 ${mod}"
        exit 1
    fi
    if [ ! -s "${SCRIPT_DIR}/${mod}" ]; then
        echo "錯誤：空檔案 ${mod}"
        exit 1
    fi
done

echo "==> 產生 ${OUTPUT_FILE}..."

cat > "${OUTPUT_FILE}" << HEADER
-- ============================================================================
-- 台鐵職工福利平台 — all-in-one 整合檔案
-- 模組：all_in_one.sql
-- 說明：依固定順序整合所有模組 DDL、種子、觸發器、視圖與驗證
-- 產生日期：$(date +%Y-%m-%d)
-- 規格版本：v1.0（docs/superpowers/specs/2026-07-03-tra-subsidy-database-design.md）
-- 執行方式：mysql --defaults-extra-file="\$MYSQL_CNF" < sql/all_in_one.sql
-- ============================================================================

HEADER

for mod in "${MODULES[@]}"; do
    echo "" >> "${OUTPUT_FILE}"
    echo "-- ============================================================================" >> "${OUTPUT_FILE}"
    echo "-- 來源：sql/${mod}" >> "${OUTPUT_FILE}"
    echo "-- ============================================================================" >> "${OUTPUT_FILE}"
    cat "${SCRIPT_DIR}/${mod}" >> "${OUTPUT_FILE}"
    echo "" >> "${OUTPUT_FILE}"
done

echo "==> 計算 SHA-256..."
shasum -a 256 "${OUTPUT_FILE}"

echo "==> 完成！"
