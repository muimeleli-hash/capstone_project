# Customer 360 Data Engineering Capstone

An end-to-end customer activity pipeline built with Python, PostgreSQL, SQL, and Apache Airflow. It ingests a CSV extract, standardizes customer and activity data, and builds a dimensional warehouse for customer, product, transaction, and CRM analysis.

## Pipeline

The pipeline uses a Bronze/Silver/Gold structure:

1. **Bronze:** Load the source CSV into `stg.stg_activity_extract` using PostgreSQL `COPY`.
2. **Silver:** Normalize text, email addresses, South African phone numbers, dates, numeric values, and resolution flags; remove duplicate records; populate cleaned staging dimensions and facts.
3. **Gold:** Load the `dwh` dimensions and `dwh.fct_activity` fact table.
4. **Validation:** Report row counts for the warehouse tables.

The Airflow DAG runs the same stages as separate tasks and is scheduled daily at 08:00 (Airflow's configured timezone). The DAG is defined in [`dags/customer360_dag.py`](dags/customer360_dag.py).

## Requirements

- Python 3.10 or newer
- PostgreSQL 15 or newer
- PostgreSQL client tools (`psql`) on `PATH`
- Docker and Docker Compose for the containerized setup

## Run Locally

Create an environment and install the Python dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Start PostgreSQL and create a database user with permission to create databases and schemas. Set the connection variables before running the pipeline:

```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=customer360_db
export DB_USER=postgres
export DB_PASSWORD='<your-local-postgres-password>'
```

Run the pipeline from the repository root:

```bash
python scripts/customer360.py
```

The loader looks for `activity_extract.csv` in the project root first, then `data/raw/activity_extract.csv`. It applies [`scripts/Script-16.sql.sql`](scripts/Script-16.sql.sql), which creates the `stg` and `dwh` schemas and their tables.

## Run with Docker Compose

From the repository root, start the development stack:

```bash
docker compose -f plugins/docker-compose.yaml up --build
```

The Airflow container installs `requirements.txt` at startup, migrates its metadata database, and starts Airflow. Open the UI at [http://localhost:8081](http://localhost:8081). The Compose file creates a local development admin account (`admin` / `admin`). PostgreSQL is published on host port `5433`; the containers connect to it on port `5432`. The DAG `customer360_etl_pipeline` is available in the UI and runs daily at 08:00, or can be triggered manually.

Stop the services with:

```bash
docker compose -f plugins/docker-compose.yaml down
```

To remove the database volume as well (this deletes the local database data), use `docker compose -f plugins/docker-compose.yaml down -v`.

## Analytics and Data Model

The SQL analysis is grouped under [`business_analytics/`](business_analytics/):

- Customer distribution, age, signup trends, and data quality
- Product distribution, balances, cross-sell, and credit utilization
- Transaction value, channel comparisons, active customers, and top customers
- CRM interaction volume, channel usage, and resolution rates
- Value tiers, lifecycle, and CRM-to-transaction analysis
- Retention and transaction anomaly analysis

The [`data modelling/`](data%20modelling/) directory contains the modelled extract and a star-schema diagram.

## Repository Guide

- [`scripts/customer360.py`](scripts/customer360.py): ETL, data cleaning, loading, and validation.
- [`scripts/Script-16.sql.sql`](scripts/Script-16.sql.sql): Staging and warehouse DDL.
- [`data/raw/activity_extract.csv`](data/raw/activity_extract.csv): Source activity extract used by the pipeline.
- [`dags/customer360_dag.py`](dags/customer360_dag.py): Scheduled Airflow orchestration.
- [`plugins/docker-compose.yaml`](plugins/docker-compose.yaml): Local PostgreSQL and Airflow stack.
- [`requirements.txt`](requirements.txt): Python dependencies.
- [`airflow-docker/`](airflow-docker/): Additional Airflow configuration files.

## Configuration and Data Safety

The loader reads `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD`. It has local-development defaults; set these variables explicitly outside a disposable local environment. The included Compose credentials and Airflow account are for local development only and must not be used on an exposed or production deployment.

The CSV extracts contain personal-data-shaped fields, including names, contact details, and dates of birth. Keep this repository private unless the data has been verified as synthetic or has been appropriately anonymized and approved for publication. Do not add real customer data, production credentials, or generated Airflow logs to a public repository.

## Validation

The repository does not currently include an automated test suite. Running `python scripts/customer360.py` performs the pipeline and prints warehouse row counts; you can also inspect the resulting dimensions and fact table directly in PostgreSQL.
