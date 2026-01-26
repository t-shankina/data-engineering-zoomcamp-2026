#!/usr/bin/env python
# coding: utf-8

import click
import fsspec
import pyarrow.parquet as pq
from sqlalchemy import create_engine
from tqdm.auto import tqdm


@click.command()
@click.option('--pg-user', default='postgres', help='PostgreSQL user')
@click.option('--pg-pass', default='postgres', help='PostgreSQL password')
@click.option('--pg-host', default='postgres', help='PostgreSQL host')
@click.option('--pg-port', default=5432, type=int, help='PostgreSQL port')
@click.option('--pg-db', default='ny_taxi', help='PostgreSQL database name')
@click.option('--year', default=2025, type=int, help='Year of the data')
@click.option('--month', default=11, type=int, help='Month of the data')
@click.option('--target-table', default='green_tripdata_2025_11', help='Target table name')
@click.option('--batchsize', default=10000, type=int, help='Batch size for reading Parquet')
def run(pg_user, pg_pass, pg_host, pg_port, pg_db, year, month, target_table, batchsize):
    """Ingest NYC taxi data into PostgreSQL database."""
    prefix = 'https://d37ci6vzurychx.cloudfront.net/trip-data'
    url = f'{prefix}/green_tripdata_{year}-{month:02d}.parquet'

    engine = create_engine(f'postgresql://{pg_user}:{pg_pass}@{pg_host}:{pg_port}/{pg_db}')

    first = True
    with fsspec.open(url, mode='rb') as file:
        pf = pq.ParquetFile(file)

        with engine.begin() as conn:
            for batch in tqdm(pf.iter_batches(batch_size=batchsize)):
                batch_df = batch.to_pandas()

                if first:
                    batch_df.head(0).to_sql(
                        name=target_table,
                        con=conn,
                        if_exists='replace'
                    )
                    first = False
                
                batch_df.to_sql(
                    name=target_table,
                    con=conn,
                    if_exists='append'
                )


if __name__ == '__main__':
    run()
