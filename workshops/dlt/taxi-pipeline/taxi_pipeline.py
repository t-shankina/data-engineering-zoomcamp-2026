"""dlt pipeline to ingest NYC Taxi data from the Zoomcamp REST API."""

import dlt
from dlt.sources.rest_api import rest_api_resources
from dlt.sources.rest_api.typing import RESTAPIConfig


@dlt.source
def taxi_pipeline_rest_api_source():
    """Define dlt resources for the NYC Taxi REST API."""
    config: RESTAPIConfig = {
        "client": {
            # Base URL of the Zoomcamp NYC Taxi API
            "base_url": "https://us-central1-dlthub-analytics.cloudfunctions.net/",
            # Explicit page-number pagination on the `page` query parameter:
            # - starts from page 1
            # - stops when an empty page is returned
            "paginator": {
                "type": "page_number",
                "base_page": 1,
                "page_param": "page",
                # API does not return a total; stop when an empty page is returned.
                "total_path": None,
                "stop_after_empty_page": True,
            },
            # No authentication required for this public demo API
        },
        "resources": [
            {
                # Logical resource/table name in your destination
                "name": "nyc_taxi_trips",
                "endpoint": {
                    # Full URL will be:
                    # https://us-central1-dlthub-analytics.cloudfunctions.net/data_engineering_zoomcamp_api
                    "path": "data_engineering_zoomcamp_api",
                    # Response is a list of JSON records at the root,
                    # so no special data_selector is needed.
                },
            },
        ],
        # You can add resource_defaults here later if you want things like
        # primary_key, write_disposition, etc.
    }

    # Create dlt resources from the REST API configuration
    return rest_api_resources(config)


# NOTE: The *pipeline* name is `taxi_pipeline` as requested.
pipeline = dlt.pipeline(
    pipeline_name="taxi_pipeline",
    destination="duckdb",
    dataset_name="nyc_taxi_data",
    # During development, keep refresh="drop_sources" so each run reloads cleanly.
    # Remove this once you're happy with the pipeline behavior.
    refresh="drop_sources",
    progress="log",
)


if __name__ == "__main__":
    load_info = pipeline.run(taxi_pipeline_rest_api_source())
    print(load_info)  # noqa: T201
