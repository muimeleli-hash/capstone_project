"""
customer360_dag.py

Airflow DAG that runs the Customer360 ETL pipeline every day at 08:00.

Task chain:
    t1_run_sql_script   -> creates schema/tables if they don't exist
    t2_load_staging     -> loads activity_extract.csv into stg.stg_activity_extract
    t3_clean_staging    -> reads staging, cleans it, writes cleaned data to a
                            parquet file on the shared volume
    t4_load_dwh         -> reads the cleaned parquet and loads dims/facts

This file must live in the `dags/` folder that's mounted into the
Airflow container (see docker-compose.yaml).
"""

import sys
import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator

# ------------------------------------------------------------------
# Make the project root importable. In Docker we mount the whole repo at
# /opt/airflow, so the ETL module and source files live beside the DAG.
# ------------------------------------------------------------------
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

import customer360 as etl  # noqa: E402  (import after sys.path tweak)

# ------------------------------------------------------------------
# File paths used by the ETL script.
# ------------------------------------------------------------------
CSV_PATHS = [
    os.path.join(PROJECT_ROOT, "activity_extract.csv"),
    os.path.join(PROJECT_ROOT, "data", "raw", "activity_extract.csv"),
]
CSV_PATH = next((p for p in CSV_PATHS if os.path.exists(p)), None)
if CSV_PATH is None:
    raise FileNotFoundError(
        "CSV not found in project root or data/raw/."
    )
SQL_PATH = os.path.join(PROJECT_ROOT, "Script-16.sql.sql")
CLEAN_PARQUET_PATH = os.path.join(PROJECT_ROOT, "tmp", "clean_staging.parquet")


# ------------------------------------------------------------------
# Task functions - thin wrappers around your existing functions
# ------------------------------------------------------------------
def task_run_sql_script():
    etl.run_sql_script(SQL_PATH)


def task_load_csv_to_staging():
    if not os.path.exists(CSV_PATH):
        raise FileNotFoundError(f"CSV not found at {CSV_PATH}")
    etl.load_csv_to_bronze(CSV_PATH)


def task_clean_staging():
    conn = etl.get_connection()
    try:
        df_raw = etl.pd.read_sql(
            "SELECT * FROM stg.stg_activity_extract;",
            conn,
        )
    finally:
        conn.close()

    df_clean = etl.clean_staging_data(df_raw)
    os.makedirs(os.path.dirname(CLEAN_PARQUET_PATH), exist_ok=True)
    df_clean.to_parquet(CLEAN_PARQUET_PATH, index=False)


def task_load_to_dwh():
    df_clean = etl.pd.read_parquet(CLEAN_PARQUET_PATH)
    etl.load_silver_dimensions(df_clean)
    etl.load_dwh_dimensions()
    etl.load_dwh_fact()


# ------------------------------------------------------------------
# DAG definition
# ------------------------------------------------------------------
default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="customer360_etl_pipeline",
    description="Loads activity_extract.csv into staging, cleans it, then loads the DWH",
    default_args=default_args,
    start_date=datetime(2026, 1, 1),
    schedule="0 8 * * *",  # every day at 08:00
    catchup=False,
    tags=["customer360", "etl"],
) as dag:

    t1_run_sql = PythonOperator(
        task_id="run_sql_script",
        python_callable=task_run_sql_script,
    )

    t2_load_staging = PythonOperator(
        task_id="load_csv_to_staging",
        python_callable=task_load_csv_to_staging,
    )

    t3_clean_staging = PythonOperator(
        task_id="clean_staging",
        python_callable=task_clean_staging,
    )

    t4_load_dwh = PythonOperator(
        task_id="load_to_dwh",
        python_callable=task_load_to_dwh,
    )

    t1_run_sql >> t2_load_staging >> t3_clean_staging >> t4_load_dwh