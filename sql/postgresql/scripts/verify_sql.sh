#!/usr/bin/env bash
# ============================================================================
# 台鐵職工福利平台 — PostgreSQL 驗證執行腳本
# 功能：依固定順序執行模組和測試
# 使用：bash sql/postgresql/scripts/verify_sql.sh
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DB="${PGDATABASE:-tra_welfare_test}"

PSQL_OPTS="-d ${TEST_DB} -v ON_ERROR_STOP=1"

echo "=========================================="
echo "台鐵職工福利平台 — PostgreSQL 驗證"
echo "日期：$(date +%Y-%m-%d)"
echo "資料庫：${TEST_DB}"
echo "=========================================="

MODULES=(
    "modules/01_sys.sql" "modules/02_file.sql" "modules/03_org.sql"
    "modules/04_emp.sql" "modules/05_iam.sql" "modules/06_rbac.sql"
    "modules/07_ntf.sql" "modules/08_ben_config.sql" "modules/09_ben_application.sql"
    "modules/10_workflow.sql" "modules/11_payment.sql" "modules/12_finance.sql"
    "modules/13_ai_ocr.sql" "modules/14_merchant.sql" "modules/15_announcement.sql"
    "modules/16_security_audit.sql" "modules/17_functions_procedures.sql"
    "modules/18_triggers.sql" "modules/19_views.sql" "modules/20_seed_common.sql"
    "modules/99_verify.sql"
)

TOTAL_FAIL=0

echo "==> 階段 1：依序安裝模組"
for mod in "${MODULES[@]}"; do
    printf "   %-40s" "${mod}..."
    if psql ${PSQL_OPTS} -f "${SCRIPT_DIR}/${mod}" >/dev/null 2>&1; then
        echo "OK"
    else
        echo "FAIL"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
done

echo "==> 階段 2：執行測試"
for test in tests/*.sql; do
    printf "   %-40s" "${test}..."
    if psql ${PSQL_OPTS} -f "${SCRIPT_DIR}/${test}" >/dev/null 2>&1; then
        echo "OK"
    else
        echo "FAIL"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
done

echo ""
if [ "${TOTAL_FAIL}" -eq 0 ]; then
    echo "全部通過！"
else
    echo "失敗數：${TOTAL_FAIL}"
fi
exit ${TOTAL_FAIL}
