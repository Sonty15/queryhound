#!/usr/bin/env bash
set -euo pipefail

FIXTURE_DIR="${1:-/tmp/queryhound-fixture-repo}"
MODE="${2:-clean}"   # clean | dirty | feature-branch

rm -rf "$FIXTURE_DIR"
mkdir -p "$FIXTURE_DIR/src"
cd "$FIXTURE_DIR"
git init -q -b main

cat > src/orders_raw.sql << 'SQL'
-- Raw literal SQL, as it would appear in a .sql file
SELECT id, customer_id, total, created_at
FROM orders
WHERE status = 'pending'
ORDER BY created_at DESC;
SQL

cat > src/orders_repository.py << 'PY'
def find_pending_orders_for_customer(customer_id):
    query = """
        SELECT id, customer_id, total, created_at
        FROM orders
        WHERE customer_id = %s AND status = 'pending'
    """
    return db.execute(query, (customer_id,))
PY

cat > src/unrelated.py << 'PY'
def unrelated_helper():
    return "nothing to do with orders"
PY

git add -A
git commit -q -m "Add fixture source files"

case "$MODE" in
  dirty)
    echo "-- uncommitted local edit" >> src/orders_raw.sql
    ;;
  feature-branch)
    git checkout -q -b feature/test-branch
    ;;
  clean) ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 1
    ;;
esac

echo "Fixture repo created at $FIXTURE_DIR (mode=$MODE) on branch: $(git branch --show-current)"
