"""@bruin

# TODO: Set the asset name (recommended pattern: schema.asset_name).
# - Convention in this module: use an `ingestion.` schema for raw ingestion tables.
name: ingestion.trips

# TODO: Set the asset type.
# Docs: https://getbruin.com/docs/bruin/assets/python
type: python

# TODO: Pick a Python image version (Bruin runs Python in isolated environments).
# Example: python:3.11
image: python:3.11

# TODO: Set the connection.
connection: duckdb-default

# TODO: Choose materialization (optional, but recommended).
# Bruin feature: Python materialization lets you return a DataFrame (or list[dict]) and Bruin loads it into your destination.
# This is usually the easiest way to build ingestion assets in Bruin.
# Alternative (advanced): you can skip Bruin Python materialization and write a "plain" Python asset that manually writes
# into DuckDB (or another destination) using your own client library and SQL. In that case:
# - you typically omit the `materialization:` block
# - you do NOT need a `materialize()` function; you just run Python code
# Docs: https://getbruin.com/docs/bruin/assets/python#materialization
materialization:
  # TODO: choose `table` or `view` (ingestion generally should be a table)
  type: table
  # TODO: pick a strategy.
  # suggested strategy: append
  strategy: append

# TODO: Define output columns (names + types) for metadata, lineage, and quality checks.
# Tip: mark stable identifiers as `primary_key: true` if you plan to use `merge` later.
# Docs: https://getbruin.com/docs/bruin/assets/columns
# columns:
#   - name: taxi_type
#     type: string
#     description: "Taxi service type (e.g., yellow, green)"
#   - name: extracted_at
#     type: timestamp
#     description: "UTC timestamp when data was fetched from the TLC endpoint"

@bruin"""

import json
import os
from datetime import date, datetime
from io import BytesIO

import pandas as pd
import requests
from dateutil.relativedelta import relativedelta


BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/"


def _month_range(start: date, end: date):
    """
    Generate the first day of each month between start and end dates (inclusive).
    """
    current = date(start.year, start.month, 1)
    last = date(end.year, end.month, 1)
    while current <= last:
        yield current
        current = current + relativedelta(months=1)


def materialize():
    """
    Ingest NYC Taxi trip data from the TLC public parquet files.

    Uses the Bruin-provided date window and pipeline variables:
    - BRUIN_START_DATE / BRUIN_END_DATE (YYYY-MM-DD)
    - BRUIN_VARS JSON env var, which includes `taxi_types` (e.g. ["yellow", "green"])

    For each taxi_type and month that overlaps the run window, this function:
    - Downloads the corresponding parquet file from the TLC endpoint
    - Loads it into a pandas DataFrame
    - Adds `taxi_type` and `extracted_at` columns
    - Concatenates all DataFrames and returns the result for Bruin materialization
    """
    start_str = os.environ["BRUIN_START_DATE"]
    end_str = os.environ["BRUIN_END_DATE"]

    start_date = datetime.strptime(start_str, "%Y-%m-%d").date()
    end_date = datetime.strptime(end_str, "%Y-%m-%d").date()

    vars_raw = os.environ.get("BRUIN_VARS", "{}")
    vars_dict = json.loads(vars_raw or "{}")
    taxi_types = vars_dict.get("taxi_types") or ["green"]

    frames = []
    extracted_at = datetime.utcnow()

    for taxi_type in taxi_types:
        for month_start in _month_range(start_date, end_date):
            year = month_start.year
            month = month_start.month
            filename = f"{taxi_type}_tripdata_{year}-{month:02d}.parquet"
            url = f"{BASE_URL}{filename}"

            response = requests.get(url, timeout=300)
            response.raise_for_status()

            df = pd.read_parquet(BytesIO(response.content))
            df["taxi_type"] = taxi_type
            df["extracted_at"] = extracted_at
            frames.append(df)

    if not frames:
        # No data for this run window; return an empty DataFrame with metadata columns.
        return pd.DataFrame(columns=["taxi_type", "extracted_at"])

    return pd.concat(frames, ignore_index=True)
