Project: Customer360 ETL / Capstone

Overview

This repository contains a small end-to-end data engineering project that ingests a CSV file into a Postgres-backed data warehouse, runs SQL scripts to build staging and DWH objects, and includes Airflow DAG(s) to orchestrate the pipeline. The core assets are a loader script, SQL schema, an example CSV, and simple Airflow configuration to run the pipeline locally or in containers.

Quickstart

1. Create a Python virtual environment and install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Provide Postgres connection environment variables (optional — defaults shown):

```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=customer360_db
export DB_USER=postgres
export DB_PASSWORD=4462
```

3. Start Postgres (one of):

- Use a local Postgres installation (recommended for development).
- Or start via Docker Compose (see `docker-compose.yaml`) with `docker compose up -d`.

4. Run the loader which applies the SQL schema and loads `activity_extract.csv`:

```bash
python3 postgresql.py
```

Repository Layout

- [postgresql.py](postgresql.py): Python loader that applies the SQL schema and loads CSV into staging and DWH.
- [Script-16.sql.sql](Script-16.sql.sql): SQL schema used to create `stg` and `dwh` objects.
- [activity_extract.csv](activity_extract.csv): Example source data file.
- [dags/](dags/): Airflow DAG definitions (e.g., `customer360_dag.py`).
- [docker-compose.yaml](docker-compose.yaml): Optional compose file for services used in development.
- [airflow/], [airflow-docker/], [config/]: Airflow-related configs, logs and containerized examples.

Design & Data Flow

1. Ingest: `activity_extract.csv` is placed in the project root.
2. Load: `postgresql.py` creates staging tables and loads CSV into the `stg` schema using an efficient COPY or bulk insert strategy.
3. Transform: SQL in `Script-16.sql.sql` creates DWH objects in `dwh` schema (views/tables) that transform and aggregate staging data.
4. Orchestration: Airflow DAG(s) under `dags/` wrap the above steps into scheduled or manual runs. Logs are in `logs/`.

Airflow

- To run Airflow locally you can use the included `airflow.cfg` and the `airflow/` folders. There are two example setups: a local-host setup and a `airflow-docker/` containerized setup.
- Example to run with Docker Compose (from repository root):

```bash
docker compose -f docker-compose.yaml up -d
# or for the dockerized airflow example
cd airflow-docker && docker compose up -d
```

- Start the webserver and scheduler (if using local install):

```bash
airflow db init
airflow users create --username admin --firstname Admin --lastname User --role Admin --email admin@example.com
airflow scheduler &
airflow webserver
```

- DAGs: See `dags/customer360_dag.py` for the pipeline flow. Trigger runs from the Airflow UI or run tasks manually with `airflow dags trigger`.

Configuration

Important environment variables (used by scripts and DAGs):

- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` — Postgres connection details.
- `AIRFLOW_HOME` — If running Airflow locally and you wish to set a custom home.

Files and Purpose

- `postgresql.py`: Connects to Postgres using SQLAlchemy, applies the SQL in `Script-16.sql.sql`, and loads `activity_extract.csv` into staging. It prefers `psql` COPY when available for speed, falling back to Python-based bulk inserts.
- `Script-16.sql.sql`: DDL and SQL used to build staging and DWH structures and any required helper functions.
- `dags/customer360_dag.py`: Airflow DAG describing ordering: clean staging, load CSV to staging, load to DWH, run SQL scripts.

Running the full pipeline (example)

1. Ensure Postgres is running and reachable via env vars.
2. Run:

```bash
python3 postgresql.py
```

Or trigger the Airflow DAG via the UI or:

```bash
airflow dags trigger customer360_etl_pipeline
```

Logging & Troubleshooting

- Airflow logs: `logs/dag_id=...` and `airflow/logs/` in this repository for local runs.
- If the loader fails during COPY, check permissions and CSV formatting; `postgresql.py` will emit helpful traceback and SQL error messages.

Testing

- Unit tests: none included by default. To add tests, create a `tests/` folder and use `pytest`.
- Manual validation: After pipeline runs, query `dwh` schema tables to confirm row counts and sample values.

Contributing

- Fork, create a branch, open a PR with a clear description of changes.
- If you add features (tests, CI, improved Docker Compose), update this README with run steps.

Notes

- The loader uses SQLAlchemy for query helpers while using a raw DBAPI connection for high-performance copy operations.
- Filenames and defaults are kept simple for a learning-focused capstone; treat credentials carefully and do not commit secrets.

If you'd like, I can also:

- Add a `Makefile` or convenience scripts to standardize common commands.
- Add a `tests/` skeleton and a CI workflow to run basic checks.
- Create a short architecture diagram (Mermaid) and include it in this README.

If you want me to commit this change, tell me and I'll show the diff and create a commit.
