# ══════════════════════════════════════════════════════════════════════
#  ~/.snow.zsh — Snowflake CLI productivity harness
#  source from .zshrc:
#    [[ -f ~/.snow.zsh ]] && source ~/.snow.zsh
#
#  Dependencies: jq, less
#  Optional:     bat (file preview fallback to cat if absent)
#
#  Usage:
#    export SNOW_REPO="$WORKSPACE/snowflake-queries"
#    [[ -f ~/.snow.zsh ]] && source ~/.snow.zsh
# ══════════════════════════════════════════════════════════════════════

SNOW_REPO="${SNOW_REPO:-$WORKSPACE/snowflake-queries}"
SNOW_INIT_SQL="${SNOW_INIT_SQL:-$HOME/.config/snow/init.sql}"
SNOW_PAGER_OPTS="${SNOW_PAGER_OPTS:--FX}"
SNOW_FORCE_JSON_EXT="${SNOW_FORCE_JSON_EXT:-0}"

# Pipe output through less with configurable options.
# Default omits -S so long lines wrap instead of horizontal scrolling.
_snow_page() {
  less ${=SNOW_PAGER_OPTS}
}

# Render JSON_EXT rows in a readable record-oriented format.
# Multiline values (for example DDL/JSON blobs) are printed as indented blocks.
_snow_render_json_ext() {
  local cols="${COLUMNS:-120}"
  jq -r '
    to_entries[] as $row |
    "__ROW__\($row.key + 1)",
    (
      $row.value
      | to_entries[]
      | .key as $k
      | .value as $v
      | if ($v | type) == "string" and ($v | test("\\n")) then
          "\($k):\n" + (($v | split("\n")) | map("  " + .) | join("\n"))
        else
          "\($k): \($v | tostring)"
        end
    ),
    ""
  ' | awk -v cols="$cols" '
    /^__ROW__/ {
      row = substr($0, 8)
      label = "[row " row "] "
      n = cols - length(label)
      if (n < 4) n = 4
      printf "%s", label
      for (i = 0; i < n; i++) printf "-"
      printf "\n"
      next
    }
    { print }
  '
}

# ── Query execution helpers ───────────────────────────────────────────
# Private: force JSON_EXT record rendering.
# Usage: _snow_exec_json <conn> [snow sql flags...]
_snow_exec_json() {
  local conn="$1"; shift
  snow sql -c "$conn" "$@" --format JSON_EXT | _snow_render_json_ext | _snow_page
}

# Private: auto-select output format.
# - Native Snowflake tabular output for narrow/simple results.
# - JSON_EXT record output for wide/complex results.
# Usage: _snow_exec_auto <conn> [snow sql flags...]
_snow_exec_auto() {
  local conn="$1"; shift
  local json
  json="$(snow sql -c "$conn" "$@" --format JSON_EXT 2>&1)"

  local wide
  wide=$(printf '%s' "$json" | jq -r '
    if type != "array" or length == 0 then "narrow"
    else
      (.[0] | to_entries) as $cells |
      ($cells | length) as $cols |
      ([ $cells[] | .value | tostring | length ] | max) as $maxlen |
      if $cols > 20 or $maxlen > 200 then "wide" else "narrow" end
    end
  ')

  if [[ "$wide" == "wide" ]]; then
    printf '%s' "$json" | _snow_render_json_ext | _snow_page
  else
    snow sql -c "$conn" "$@" | _snow_page
  fi
}

# Private: default execution entrypoint used by all functions.
# Default is smart auto mode; set SNOW_FORCE_JSON_EXT=1 to force JSON_EXT.
# Usage: _snow_auto_exec <conn> [snow sql flags...]
_snow_auto_exec() {
  local conn="$1"; shift
  if [[ "$SNOW_FORCE_JSON_EXT" == "1" ]]; then
    _snow_exec_json "$conn" "$@"
  else
    _snow_exec_auto "$conn" "$@"
  fi
}

# Run any snow-* helper once with forced JSON_EXT record output.
# Usage: snow-json snow-show-databases stg
#        snow-json snow-query stg "SHOW VIEWS IN ng_views"
snow-json() {
  [[ $# -gt 0 ]] || { echo "usage: snow-json <snow-function> [args...]"; return 1; }
  SNOW_FORCE_JSON_EXT=1 "$@"
}

# ── Connection & Control ──────────────────────────────────────────────

# Connect to a Snowflake account.
# Runs init.sql first (sets warehouse, database, schema, session params)
# then drops into the interactive REPL.
# Usage: snow-connect stg | snow-connect prd
snow-connect() {
  local conn="${1:?usage: snow-connect <stg|prd>}"
  [[ -f "$SNOW_INIT_SQL" ]] && snow sql -c "$conn" -f "$SNOW_INIT_SQL" 2>/dev/null
  snow sql -c "$conn"
}

# Switch warehouse within a Snowflake REPL session.
# Usage: snow-use-warehouse COMPUTE_WHS
snow-use-warehouse() {
  local warehouse="${1:?usage: snow-use-warehouse <warehouse_name>}"
  printf "USE WAREHOUSE %s;\n" "$warehouse"
}

# Switch database within a Snowflake REPL session.
# Usage: snow-use-database ANALYTICS_DB
snow-use-database() {
  local database="${1:?usage: snow-use-database <database_name>}"
  printf "USE DATABASE %s;\n" "$database"
}

# Switch role within a Snowflake REPL session.
# Usage: snow-use-role VIEWER
snow-use-role() {
  local role="${1:?usage: snow-use-role <role_name>}"
  printf "USE ROLE %s;\n" "$role"
}

# Switch schema within a Snowflake REPL session.
# Usage: snow-use-schema PUBLIC
snow-use-schema() {
  local schema="${1:?usage: snow-use-schema <schema_name>}"
  printf "USE SCHEMA %s;\n" "$schema"
}

# Execute an inline SQL query with a selected display mode.
# Modes:
#   default -> smart default mode (tabular or JSON_EXT)
#   auto    -> explicit smart mode
#   json    -> force JSON_EXT record rendering
_snow_query_exec() {
  local mode="${1:?mode}" conn="${2:?conn}" query="${3:?query}"
  case "$mode" in
    json) _snow_exec_json "$conn" -q "$query" ;;
    auto) _snow_exec_auto "$conn" -q "$query" ;;
    *)    _snow_auto_exec "$conn" -q "$query" ;;
  esac
}

# ── Query Execution ───────────────────────────────────────────────────

# Execute an inline query (smart tabular or JSON_EXT record output).
# Usage: snow-query stg "SELECT * FROM orders LIMIT 100"
snow-query() {
  local conn="${1:?usage: snow-query <conn> <query>}"
  local query="${2:?usage: snow-query <conn> <query>}"
  _snow_query_exec auto "$conn" "$query"
}

# Alias of snow-query for discoverability.
# Usage: snow-query-vertical stg "SELECT * FROM orders LIMIT 5"
snow-query-vertical() {
  local conn="${1:?usage: snow-query-vertical <conn> <query>}"
  local query="${2:?usage: snow-query-vertical <conn> <query>}"
  _snow_query_exec json "$conn" "$query"
}

# Auto mode: tabular for narrow/simple results, JSON_EXT records for wide results.
# Usage: snow-query-auto stg "SELECT * FROM orders LIMIT 20"
snow-query-auto() {
  local conn="${1:?usage: snow-query-auto <conn> <query>}"
  local query="${2:?usage: snow-query-auto <conn> <query>}"
  _snow_query_exec auto "$conn" "$query"
}

# Execute a .sql file (smart tabular or JSON_EXT record output).
# Usage: snow-run stg ~/sql/pipelines/orders_etl.sql
snow-run() {
  local conn="${1:?usage: snow-run <conn> <file>}"
  local file="${2:?usage: snow-run <conn> <file>}"
  _snow_auto_exec "$conn" -f "$file"
}

# Open nvim on a temp (or existing) file, confirm, then execute.
# Usage: snow-edit stg
#        snow-edit stg ~/sql/explore/check_orders.sql
snow-edit() {
  local conn="${1:?usage: snow-edit <conn> [file]}"
  local file="${2:-}"
  local tmpfile

  if [[ -n "$file" ]]; then
    tmpfile="$file"
  else
    mkdir -p "$SNOW_REPO/scratch"
    tmpfile="$(mktemp "$SNOW_REPO/scratch/XXXXXX.sql")"
  fi

  nvim "$tmpfile"
  [[ ! -s "$tmpfile" ]] && echo "empty file, skipping." && return 0

  echo "▶ execute $tmpfile against $conn? [y/N] "
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || return 0
  _snow_auto_exec "$conn" -f "$tmpfile"
}

# Execute an inline query, display smart output, AND save query to a file.
# Usage: snow-save stg "SELECT ..." ~/sql/explore/check_orders.sql
snow-save() {
  local conn="${1:?usage: snow-save <conn> <query> <file>}"
  local query="${2:?usage: snow-save <conn> <query> <file>}"
  local file="${3:?usage: snow-save <conn> <query> <file>}"
  mkdir -p "$(dirname "$file")"
  echo "$query" > "$file"
  _snow_auto_exec "$conn" -q "$query"
  echo "→ saved to $file"
}

# Export query result to CSV file. Auto-names file if not specified.
# Usage: snow-export stg "SELECT * FROM orders" orders.csv
#        snow-export stg "SELECT * FROM orders"
snow-export() {
  local conn="${1:?usage: snow-export <conn> <query> [file]}"
  local query="${2:?usage: snow-export <conn> <query> [file]}"
  local file="${3:-$SNOW_REPO/exports/export_$(date +%Y%m%d_%H%M%S).csv}"
  mkdir -p "$(dirname "$file")"
  snow sql -c "$conn" -q "$query" --format CSV > "$file"
  echo "→ $file ($(wc -l < "$file" | tr -d ' ') rows)"
}

# ── Schema Discovery (SHOW commands) ──────────────────────────────────

# Run SHOW commands with optional scope.
# Usage:
#   _snow_show <conn> <OBJECT_PLURAL>
#   _snow_show <conn> <OBJECT_PLURAL> <SCOPE_KIND> <SCOPE_NAME>
_snow_show() {
  local conn="${1:?conn}" object="${2:?object}" scope_kind="${3:-}" scope_name="${4:-}"
  local q="SHOW $object"
  if [[ -n "$scope_name" ]]; then
    q="$q IN $scope_kind $scope_name"
  fi
  _snow_auto_exec "$conn" -q "$q;"
}

# List all databases in this account.  (\l equivalent)
snow-show-databases() {
  local conn="${1:?conn}"
  _snow_show "$conn" DATABASES
}

# List schemas in current or named database.  (\dn equivalent)
# Usage: snow-show-schemas stg
#        snow-show-schemas stg mydb
snow-show-schemas() {
  local conn="${1:?conn}" db="${2:-}"
  _snow_show "$conn" SCHEMAS DATABASE "$db"
}

# List stages in current or named schema.
# Usage: snow-show-stages stg
#        snow-show-stages stg mydb.public
snow-show-stages() {
  local conn="${1:?conn}" schema="${2:-}"
  _snow_show "$conn" STAGES SCHEMA "$schema"
}

# List pipes in current or named schema.
# Usage: snow-show-pipes stg
#        snow-show-pipes stg mydb.public
snow-show-pipes() {
  local conn="${1:?conn}" schema="${2:-}"
  _snow_show "$conn" PIPES SCHEMA "$schema"
}

# List tasks in current or named schema.
# Usage: snow-show-tasks stg
#        snow-show-tasks stg mydb.public
snow-show-tasks() {
  local conn="${1:?conn}" schema="${2:-}"
  _snow_show "$conn" TASKS SCHEMA "$schema"
}

# List streams in current or named schema.
# Usage: snow-show-streams stg
#        snow-show-streams stg mydb.public
snow-show-streams() {
  local conn="${1:?conn}" schema="${2:-}"
  _snow_show "$conn" STREAMS SCHEMA "$schema"
}

# List available roles in this account.
snow-show-roles() {
  local conn="${1:?conn}"
  _snow_show "$conn" ROLES
}

# List warehouses and their state.
snow-show-warehouses() {
  local conn="${1:?conn}"
  _snow_show "$conn" WAREHOUSES
}

# ── Table Operations ──────────────────────────────────────────────────

# List tables in current or named schema.  (\dt equivalent)
# Usage: snow-show-tables stg
#        snow-show-tables stg mydb.public
snow-show-tables() {
  local conn="${1:?conn}" schema="${2:-}"
  _snow_show "$conn" TABLES SCHEMA "$schema"
}

# List views in current or named schema.  (\dv equivalent)
# Usage: snow-show-views stg
#        snow-show-views stg mydb.public
snow-show-views() {
  local conn="${1:?conn}" schema="${2:-}"
  _snow_show "$conn" VIEWS SCHEMA "$schema"
}

# Describe a table — columns, types, nullability, defaults.  (\d+ equivalent)
# Usage: snow-describe-table stg mydb.public.orders
snow-describe-table() {
  local conn="${1:?conn}" table="${2:?table}"
  _snow_auto_exec "$conn" -q "DESCRIBE TABLE $table;"
}

# Get full DDL (CREATE TABLE statement) for a table.
# Usage: snow-get-ddl-table stg mydb.public.orders
snow-get-ddl-table() {
  local conn="${1:?conn}" table="${2:?table}"
  _snow_auto_exec "$conn" -q "SELECT GET_DDL('TABLE', '$table');"
}

# Describe table with row counts, bytes, clustering key.  (\dt+ equivalent)
# Usage: snow-describe-table-detail stg
#        snow-describe-table-detail stg mydb.public
snow-describe-table-detail() {
  local conn="${1:?conn}" schema="${2:-}"
  local q="SHOW TABLES${schema:+ IN SCHEMA $schema};"
  _snow_auto_exec "$conn" -q "$q"
}

# Sample rows from a table (default 100 rows).
# Usage: snow-sample-table stg mydb.public.orders
#        snow-sample-table stg mydb.public.orders 50
snow-sample-table() {
  local conn="${1:?conn}" table="${2:?table}" n="${3:-100}"
  _snow_auto_exec "$conn" -q "SELECT * FROM $table LIMIT $n;"
}

# Count rows in a table.
# Usage: snow-count-table stg mydb.public.orders
snow-count-table() {
  local conn="${1:?conn}" table="${2:?table}"
  _snow_auto_exec "$conn" -q "SELECT COUNT(*) AS row_count FROM $table;"
}

# List tables with clone lineage.
# Usage: snow-list-table-clones stg
snow-list-table-clones() {
  local conn="${1:?conn}"
  _snow_auto_exec "$conn" -q "
    SELECT table_schema, table_name, clone_group_id, created
    FROM   information_schema.tables
    WHERE  clone_group_id IS NOT NULL
    ORDER  BY clone_group_id, table_name;"
}

# ── Table Discovery ───────────────────────────────────────────────────

# Search tables by name pattern across all schemas in current database.
# Usage: snow-search-table-all stg orders
snow-search-table-all() {
  local conn="${1:?conn}" pattern="${2:?pattern}"
  _snow_auto_exec "$conn" -q "
    SELECT table_schema, table_name, table_type
    FROM   information_schema.tables
    WHERE  table_name ILIKE '%$pattern%'
    ORDER  BY table_schema, table_name;"
}

# Search tables by name pattern within a single schema.
# Usage: snow-search-table-in-schema stg mydb.public orders
snow-search-table-in-schema() {
  local conn="${1:?conn}" schema="${2:?schema}" pattern="${3:?pattern}"
  _snow_auto_exec "$conn" -q "
    SELECT table_schema, table_name, table_type, row_count
    FROM   information_schema.tables
    WHERE  table_schema = UPPER('${schema##*.}')
      AND  table_name ILIKE '%$pattern%'
    ORDER  BY table_name;"
}

# Search tables by name pattern across all schemas in current database.
# Usage: snow-search-table-in-database stg order
snow-search-table-in-database() {
  local conn="${1:?conn}" pattern="${2:?pattern}"
  _snow_auto_exec "$conn" -q "
    SELECT table_schema, table_name, table_type, row_count
    FROM   information_schema.tables
    WHERE  table_name ILIKE '%$pattern%'
    ORDER  BY table_schema, table_name;"
}

# List all schemas with table count and owner.
# Usage: snow-list-all-schemas-with-count stg
snow-list-all-schemas-with-count() {
  local conn="${1:?conn}"
  _snow_auto_exec "$conn" -q "
    SELECT schema_name,
           owner,
           COUNT(*) FILTER (WHERE object_type = 'TABLE') AS table_count,
           COUNT(*) FILTER (WHERE object_type = 'VIEW')  AS view_count
    FROM   information_schema.information_schema_catalog_name
           JOIN information_schema.schemata USING (catalog_name)
           LEFT JOIN information_schema.objects ON objects.schema_name = schemata.schema_name
    GROUP  BY schema_name, owner
    ORDER  BY schema_name;"
}

# Search columns by name pattern across current database.
# Usage: snow-search-column stg customer_id
snow-search-column() {
  local conn="${1:?conn}" pattern="${2:?pattern}"
  _snow_auto_exec "$conn" -q "
    SELECT table_schema, table_name, column_name, data_type
    FROM   information_schema.columns
    WHERE  column_name ILIKE '%$pattern%'
    ORDER  BY table_schema, table_name, column_name;"
}

# ── Query History & Performance ───────────────────────────────────────

# List last N queries executed in this account.
# Usage: snow-list-query-history stg
#        snow-list-query-history stg 50
snow-list-query-history() {
  local conn="${1:?conn}" n="${2:-30}"
  _snow_auto_exec "$conn" -q "
    SELECT start_time,
           ROUND(execution_time/1000, 2) AS sec,
           rows_produced,
           warehouse_name,
           LEFT(query_text, 120)         AS query
    FROM   snowflake.account_usage.query_history
    ORDER  BY start_time DESC
    LIMIT  $n;"
}

# List top N queries by credit cost — for optimization work.
# Usage: snow-list-query-by-cost stg
#        snow-list-query-by-cost stg 30
snow-list-query-by-cost() {
  local conn="${1:?conn}" n="${2:-20}"
  _snow_auto_exec "$conn" -q "
    SELECT LEFT(query_text, 100)                  AS query,
           warehouse_name,
           ROUND(execution_time/1000, 2)           AS sec,
           ROUND(credits_used_cloud_services, 6)   AS credits,
           rows_produced,
           partitions_scanned,
           partitions_total
    FROM   snowflake.account_usage.query_history
    WHERE  credits_used_cloud_services > 0
    ORDER  BY credits_used_cloud_services DESC
    LIMIT  $n;"
}

# List recent failed queries — for pipeline debugging.
# Usage: snow-list-query-errors stg
#        snow-list-query-errors stg 50
snow-list-query-errors() {
  local conn="${1:?conn}" n="${2:-20}"
  _snow_auto_exec "$conn" -q "
    SELECT start_time,
           ROUND(execution_time/1000, 2) AS sec,
           error_code,
           error_message,
           LEFT(query_text, 120)         AS query
    FROM   snowflake.account_usage.query_history
    WHERE  error_code IS NOT NULL
    ORDER  BY start_time DESC
    LIMIT  $n;"
}

# List queries slower than N seconds — for performance investigation.
# Usage: snow-list-query-slow stg
#        snow-list-query-slow stg 60
snow-list-query-slow() {
  local conn="${1:?conn}" threshold="${2:-30}"
  _snow_auto_exec "$conn" -q "
    SELECT start_time,
           ROUND(execution_time/1000, 2) AS sec,
           warehouse_name,
           rows_produced,
           LEFT(query_text, 120)         AS query
    FROM   snowflake.account_usage.query_history
    WHERE  execution_time/1000 > $threshold
    ORDER  BY execution_time DESC
    LIMIT  20;"
}

# ── Ingestion & Pipelines ─────────────────────────────────────────────

# Get Snowpipe status for a named pipe.
# Usage: snow-get-pipe-status stg mydb.public.my_pipe
snow-get-pipe-status() {
  local conn="${1:?conn}" pipe="${2:?pipe}"
  _snow_auto_exec "$conn" -q "SELECT SYSTEM\$PIPE_STATUS('$pipe');"
}

# Get stream staleness and health information.
# Usage: snow-get-stream-status stg my_stream
snow-get-stream-status() {
  local conn="${1:?conn}" stream="${2:?stream}"
  _snow_auto_exec "$conn" -q "
    SELECT system_time,
           stale,
           stale_after,
           invalid_reason
    FROM   information_schema.streams
    WHERE  stream_name = UPPER('$stream');"
}

# Get COPY INTO load history for a table.
# Usage: snow-get-copy-history stg orders
snow-get-copy-history() {
  local conn="${1:?conn}" table="${2:?table}"
  _snow_auto_exec "$conn" -q "
    SELECT file_name,
           last_load_time,
           row_count,
           row_parsed,
           error_count,
           status,
           first_error_message
    FROM   information_schema.load_history
    WHERE  table_name = UPPER('$table')
    ORDER  BY last_load_time DESC
    LIMIT  20;"
}

# ── Cost & Monitoring ──────────────────────────────────────────────────

# Get warehouse credit consumption — last 7 days.
# Usage: snow-get-warehouse-credits stg
snow-get-warehouse-credits() {
  local conn="${1:?conn}"
  _snow_auto_exec "$conn" -q "
    SELECT warehouse_name,
           ROUND(SUM(credits_used), 4)                AS total_credits,
           ROUND(SUM(credits_used_compute), 4)        AS compute_credits,
           ROUND(SUM(credits_used_cloud_services), 4) AS cloud_credits
    FROM   snowflake.account_usage.warehouse_metering_history
    WHERE  start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP)
    GROUP  BY 1
    ORDER  BY total_credits DESC;"
}

# ── Permissions ───────────────────────────────────────────────────────

# List grants on a table or object.
# Usage: snow-list-grants-on-object stg mydb.public.orders
snow-list-grants-on-object() {
  local conn="${1:?conn}" object="${2:?object}"
  _snow_auto_exec "$conn" -q "SHOW GRANTS ON TABLE $object;"
}

# List grants assigned to a role.
# Usage: snow-list-grants-to-role stg analyst
snow-list-grants-to-role() {
  local conn="${1:?conn}" role="${2:?role}"
  _snow_auto_exec "$conn" -q "SHOW GRANTS TO ROLE $role;"
}

# ── Tab completion ────────────────────────────────────────────────────
_snow_conn_complete() {
  local -a conns
  local toml="${SNOW_CONNECTIONS_TOML:-$HOME/.snowflake/connections.toml}"
  conns=("${(@f)$(grep -E '^\[.*\]' "$toml" 2>/dev/null | tr -d '[]')}")
  _describe 'connections' conns
}

compdef _snow_conn_complete \
  snow-connect snow-use-warehouse snow-use-database snow-use-role snow-use-schema \
  snow-query snow-query-vertical snow-query-auto \
  snow-run snow-edit snow-save snow-export \
  snow-show-databases snow-show-schemas snow-show-stages snow-show-pipes \
  snow-show-tasks snow-show-streams snow-show-roles snow-show-warehouses \
  snow-show-tables snow-show-views \
  snow-describe-table snow-get-ddl-table snow-describe-table-detail \
  snow-sample-table snow-count-table snow-list-table-clones \
  snow-search-table-all snow-search-table-in-schema snow-search-table-in-database \
  snow-list-all-schemas-with-count snow-search-column \
  snow-list-query-history snow-list-query-by-cost snow-list-query-errors snow-list-query-slow \
  snow-get-pipe-status snow-get-stream-status snow-get-copy-history \
  snow-get-warehouse-credits \
  snow-list-grants-on-object snow-list-grants-to-role

# ── Help ──────────────────────────────────────────────────────────────
snow-help() {
  cat <<'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ~/.snow.zsh — Snowflake CLI harness (refactored)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

── Connection & Control ─────────────────────────────────────
  snow-connect                  <conn>              connect, run init.sql first
  snow-use-warehouse            <warehouse>         switch warehouse in REPL
  snow-use-database             <database>          switch database in REPL
  snow-use-role                 <role>              switch role in REPL
  snow-use-schema               <schema>            switch schema in REPL

── Query Execution ──────────────────────────────────────────
  snow-query                    <conn> "sql"        smart (tabular or JSON_EXT)
  snow-query-vertical           <conn> "sql"        force JSON_EXT record output
  snow-query-auto               <conn> "sql"        auto (tabular or JSON_EXT)
  snow-run                      <conn> <file>       run .sql file (smart output)
  snow-edit                     <conn> [file]       nvim → confirm → execute
  snow-save                     <conn> "sql" <file> smart output + save query
  snow-export                   <conn> "sql" [file] export result to CSV
  snow-json                     <fn> [args...]      run any snow-* fn with JSON_EXT

── Schema Discovery (SHOW) ──────────────────────────────────
  snow-show-databases           <conn>              list all databases
  snow-show-schemas             <conn> [db]         list schemas in database
  snow-show-stages              <conn> [schema]     list stages
  snow-show-pipes               <conn> [schema]     list pipes
  snow-show-tasks               <conn> [schema]     list tasks
  snow-show-streams             <conn> [schema]     list streams
  snow-show-roles               <conn>              list available roles
  snow-show-warehouses          <conn>              list warehouses

── Table Operations ─────────────────────────────────────────
  snow-show-tables              <conn> [schema]     list tables in schema
  snow-show-views               <conn> [schema]     list views in schema
  snow-describe-table           <conn> <table>      describe table (columns, types)
  snow-get-ddl-table            <conn> <table>      full CREATE TABLE statement
  snow-describe-table-detail    <conn> [schema]     SHOW TABLES details (JSON_EXT)
  snow-sample-table             <conn> <table> [n]  SELECT * LIMIT n (default 100)
  snow-count-table              <conn> <table>      COUNT(*) on a table
  snow-list-table-clones        <conn>              tables with clone lineage

── Table Discovery ──────────────────────────────────────────
  snow-search-table-all         <conn> <pattern>    search tables by name (all schemas)
  snow-search-table-in-schema   <conn> <schema> <p> search tables in one schema
  snow-search-table-in-database <conn> <pattern>    search tables across schemas
  snow-list-all-schemas-with-count <conn>          list schemas with table/view counts
  snow-search-column            <conn> <pattern>    search columns by name

── Query History & Performance ────────────────────────────
  snow-list-query-history       <conn> [n]          last N queries (default 30)
  snow-list-query-by-cost       <conn> [n]          top N queries by credit cost
  snow-list-query-errors        <conn> [n]          recent failed queries
  snow-list-query-slow          <conn> [threshold]  queries slower than N sec (default 30)

── Ingestion & Pipelines ──────────────────────────────────
  snow-get-pipe-status          <conn> <pipe>       SYSTEM$PIPE_STATUS
  snow-get-stream-status        <conn> <stream>     stream staleness + health
  snow-get-copy-history         <conn> <table>      COPY INTO load history

── Cost & Monitoring ──────────────────────────────────────
  snow-get-warehouse-credits    <conn>              warehouse credits last 7d

── Permissions ────────────────────────────────────────────
  snow-list-grants-on-object    <conn> <object>     grants on a table/object
  snow-list-grants-to-role      <conn> <role>       grants assigned to a role

── Inside the REPL (after snow-connect) ───────────────────
  Use snow-use-* commands above to switch context, then:
  !edit                         open \$EDITOR for multi-line query
  !source <file>                run a local .sql file
  !queries                       list recent async queries
  !result <query_id>             fetch result of async query
  !abort  <query_id>             abort a running query
  SELECT ... ;>                  execute query asynchronously
  Tab                            autocomplete (built-in)
  exit / quit / Ctrl-D           leave REPL

── Env vars ────────────────────────────────────────────────
  SNOW_REPO                   sql repo path        (default: ~/sql)
  SNOW_INIT_SQL               session init file    (default: ~/.config/snow/init.sql)
  SNOW_CONNECTIONS_TOML       connections.toml     (default: ~/.snowflake/connections.toml)
  SNOW_FORCE_JSON_EXT         force JSON_EXT mode  (default: 0)

── Naming Convention ────────────────────────────────────────
All functions follow snow-{action}-{object} pattern for consistency:
  snow-show-*         SHOW commands (databases, tables, roles, etc.)
  snow-describe-*     DESCRIBE / column inspection
  snow-get-*          Retrieve data or status
  snow-list-*         List or search multiple items
  snow-search-*       Pattern-based search
  snow-use-*          Switch context (warehouse, database, role, schema)
  snow-*-table        Table-specific operations
  snow-*-query        Query history/analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}
