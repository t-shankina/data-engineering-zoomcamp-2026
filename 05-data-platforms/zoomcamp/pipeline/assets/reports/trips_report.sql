/* @bruin

# Docs:
# - SQL assets: https://getbruin.com/docs/bruin/assets/sql
# - Materialization: https://getbruin.com/docs/bruin/assets/materialization
# - Quality checks: https://getbruin.com/docs/bruin/quality/available_checks

# TODO: Set the asset name (recommended: reports.trips_report).
name: reports.trips_report

# TODO: Set platform type.
# Docs: https://getbruin.com/docs/bruin/assets/sql
# suggested type: duckdb.sql
type: duckdb.sql

# TODO: Declare dependency on the staging asset(s) this report reads from.
depends:
  - staging.trips

# TODO: Choose materialization strategy.
# For reports, `time_interval` is a good choice to rebuild only the relevant time window.
# Important: Use the same `incremental_key` as staging (e.g., pickup_datetime) for consistency.
materialization:
  type: table
  # suggested strategy: time_interval
  strategy: time_interval
  # TODO: set to your report's date column
  incremental_key: service_date
  # TODO: set to `date` or `timestamp`
  time_granularity: date

# TODO: Define report columns + primary key(s) at your chosen level of aggregation.
columns:
  - name: taxi_type
    type: string
    description: "Taxi service type (e.g., yellow, green)"
    primary_key: true
  - name: service_date
    type: date
    description: "Service date derived from pickup_datetime"
    primary_key: true
  - name: payment_type_name
    type: string
    description: "Human-readable payment type name"
    primary_key: true
  - name: trip_count
    type: BIGINT
    description: "Number of trips for the dimension combination"
    checks:
      - name: non_negative

@bruin */

-- Purpose of reports:
-- - Aggregate staging data for dashboards and analytics
-- Required Bruin concepts:
-- - Filter using `{{ start_datetime }}` / `{{ end_datetime }}` for incremental runs
-- - GROUP BY your dimension + date columns

WITH filtered AS (
    SELECT
        taxi_type,
        DATE_TRUNC('day', pickup_datetime) AS service_date,
        payment_type_name,
        COUNT(*) AS trip_count,
        SUM(fare_amount) AS total_fare_amount,
        SUM(total_amount) AS total_revenue_amount
    FROM staging.trips
    WHERE pickup_datetime >= '{{ start_datetime }}'
      AND pickup_datetime < '{{ end_datetime }}'
    GROUP BY
        taxi_type,
        service_date,
        payment_type_name
)
SELECT *
FROM filtered
