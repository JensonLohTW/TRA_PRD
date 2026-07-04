#!/usr/bin/env bash
# ============================================================================
# 台鐵職工福利平台 — 驗證執行腳本
# 功能：依固定順序執行模組和測試，任一 FAIL 時返回非 0
# 使用：bash sql/scripts/verify_sql.sh
# 環境：MYSQL_CNF 指向 MySQL option file（不保存於倉庫）
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MYSQL_CNF="${MYSQL_CNF:-}"
TEST_DB="tra_welfare_test"

if [ -z "$MYSQL_CNF" ]; then
    echo "錯誤：請設定 MYSQL_CNF 環境變數，指向 MySQL option file"
    echo "使用：MYSQL_CNF=/path/to/my.cnf bash sql/scripts/verify_sql.sh"
    exit 1
fi

MYSQL_CMD="mysql --defaults-extra-file=\"${MYSQL_CNF}\""

echo "=========================================="
echo "台鐵職工福利平台 — 驗證執行腳本"
echo "日期：$(date +%Y-%m-%d)"
echo "資料庫：${TEST_DB}"
echo "=========================================="

# 模組執行順序
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

TOTAL_FAIL=0

echo ""
echo "==> 階段 1：執行資料庫初始化"
eval "${MYSQL_CMD}" < "${SCRIPT_DIR}/modules/00_database.sql" || { echo "FAIL：00_database.sql"; TOTAL_FAIL=$((TOTAL_FAIL + 1)); }

echo ""
echo "==> 階段 2：依序安裝模組"
for mod in "${MODULES[@]:1}"; do
    echo "   安裝 ${mod}..."
    if eval "${MYSQL_CMD} ${TEST_DB}" < "${SCRIPT_DIR}/${mod}"; then
        echo "   OK：${mod}"
    else
        echo "   FAIL：${mod}"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
done

echo ""
echo "==> 階段 3：執行全部測試"
TESTS=(
    "tests/00_environment.sql"
)

for test in "${TESTS[@]}"; do
    echo "   測試 ${test}..."
    if eval "${MYSQL_CMD} ${TEST_DB}" < "${SCRIPT_DIR}/${test}"; then
        echo "   OK：${test}"
    else
        echo "   FAIL：${test}"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
done

echo ""
echo "=========================================="
if [ "${TOTAL_FAIL}" -eq 0 ]; then
    echo "全部通過！失敗數：0"
else
    echo "失敗數：${TOTAL_FAIL}"
fi
echo "=========================================="

exit ${TOTAL_FAIL}
