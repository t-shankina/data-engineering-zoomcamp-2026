/* @bruin

# Docs:
# - Materialization: https://getbruin.com/docs/bruin/assets/materialization
# - Quality checks (built-ins): https://getbruin.com/docs/bruin/quality/available_checks
# - Custom checks: https://getbruin.com/docs/bruin/quality/custom

# TODO: Set the asset name (recommended: staging.trips).
name: staging.trips
# TODO: Set platform type.
# Docs: https://getbruin.com/docs/bruin/assets/sql
# suggested type: duckdb.sql
type: duckdb.sql

# TODO: Declare dependencies so `bruin run ... --downstream` and lineage work.
# Examples:
# depends:
#   - ingestion.trips
#   - ingestion.payment_lookup
depends:
  - ingestion.trips
  - ingestion.payment_lookup

# TODO: Choose time-based incremental processing if the dataset is naturally time-windowed.
# - This module expects you to use `time_interval` to reprocess only the requested window.
materialization:
  # What is materialization?
  # Materialization tells Bruin how to turn your SELECT query into a persisted dataset.
  # Docs: https://getbruin.com/docs/bruin/assets/materialization
  #
  # Materialization "type":
  # - table: persisted table
  # - view: persisted view (if the platform supports it)
  type: table
  # TODO: set a materialization strategy.
  # Docs: https://getbruin.com/docs/bruin/assets/materialization
  # suggested strategy: time_interval
  #
  # Incremental strategies (what does "incremental" mean?):
  # Incremental means you update only part of the destination instead of rebuilding everything every run.
  # In Bruin, this is controlled by `strategy` plus keys like `incremental_key` and `time_granularity`.
  #
  # Common strategies you can choose from (see docs for full list):
  # - create+replace (full rebuild)
  # - truncate+insert (full refresh without drop/create)
  # - append (insert new rows only)
  # - delete+insert (refresh partitions based on incremental_key values)
  # - merge (upsert based on primary key)
  # - time_interval (refresh rows within a time window)
  strategy: time_interval
  # TODO: set incremental_key to your event time column (DATE or TIMESTAMP).
  incremental_key: pickup_datetime
  # TODO: choose `date` vs `timestamp` based on the incremental_key type.
  time_granularity: timestamp

# TODO: Define output columns, mark primary keys, and add a few checks.
columns:
  - name: taxi_type
    type: string
    description: "Taxi service type (e.g., yellow, green)"
  - name: pickup_datetime
    type: timestamp
    description: "Trip pickup timestamp (NYC local time)"
    primary_key: true
    nullable: false
    checks:
      - name: not_null
  - name: dropoff_datetime
    type: timestamp
    description: "Trip dropoff timestamp (NYC local time)"
    nullable: false
    checks:
      - name: not_null
  - name: pickup_location_id
    type: integer
    description: "Pickup Taxi Zone location ID"
    primary_key: true
    nullable: false
    checks:
      - name: not_null
  - name: dropoff_location_id
    type: integer
    description: "Dropoff Taxi Zone location ID"
    primary_key: true
    nullable: false
    checks:
      - name: not_null
  - name: passenger_count
    type: integer
    description: "Number of passengers on the trip"
    checks:
      - name: non_negative
  - name: trip_distance
    type: float
    description: "Trip distance in miles"
    checks:
      - name: non_negative
  - name: payment_type
    type: integer
    description: "Raw payment type ID from source data"
  - name: payment_type_name
    type: string
    description: "Human-readable payment type name from lookup"
  - name: fare_amount
    type: float
    description: "Base fare amount in USD"
  - name: total_amount
    type: float
    description: "Total trip amount in USD"

@bruin */

-- Purpose of staging:
-- - Clean and normalize schema from ingestion
-- - Deduplicate records (important if ingestion uses append strategy)
-- - Enrich with lookup tables (JOINs)
-- - Filter invalid rows (null PKs, negative values, etc.)
--
-- Why filter by {{ start_datetime }} / {{ end_datetime }}?
-- When using `time_interval` strategy, Bruin:
--   1. DELETES rows where `incremental_key` falls within the run's time window
--   2. INSERTS the result of your query
-- Therefore, your query MUST filter to the same time window so only that subset is inserted.
-- If you don't filter, you'll insert ALL data but only delete the window's data = duplicates.

WITH base AS (
    SELECT
        taxi_type,
        extracted_at,
        COALESCE(tpep_pickup_datetime, lpep_pickup_datetime) AS pickup_datetime,
        COALESCE(tpep_dropoff_datetime, lpep_dropoff_datetime) AS dropoff_datetime,
        pu_location_id AS pickup_location_id,
        do_location_id AS dropoff_location_id,
        passenger_count,
        trip_distance,
        payment_type,
        fare_amount,
        total_amount
    FROM ingestion.trips
),
filtered AS (
    SELECT *
    FROM base
    WHERE pickup_datetime >= '{{ start_datetime }}'
      AND pickup_datetime < '{{ end_datetime }}'
),
deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                taxi_type,
                pickup_datetime,
                dropoff_datetime,
                pickup_location_id,
                dropoff_location_id,
                fare_amount,
                total_amount
            ORDER BY extracted_at DESC
        ) AS rn
    FROM filtered
),
joined AS (
    SELECT
        d.taxi_type,
        d.pickup_datetime,
        d.dropoff_datetime,
        d.pickup_location_id,
        d.dropoff_location_id,
        d.passenger_count,
        d.trip_distance,
        d.payment_type,
        pl.payment_type_name,
        d.fare_amount,
        d.total_amount
    FROM deduped d
    LEFT JOIN ingestion.payment_lookup pl
      ON d.payment_type = pl.payment_type_id
    WHERE d.rn = 1
)
SELECT *
FROM joined
