import os
import re
import io
import logging
import subprocess
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd
import psycopg2
from psycopg2 import extras
from sqlalchemy import create_engine
import urllib.parse


# ============================================================
# CONFIGURATION
# ============================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "database": os.getenv("DB_NAME", "customer360_db"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "4462"),
}

_ENGINE = None


# ============================================================
# DATABASE CONNECTION
# ============================================================
def get_engine():
    global _ENGINE

    if _ENGINE is None:
        user = DB_CONFIG["user"]
        password = urllib.parse.quote_plus(str(DB_CONFIG["password"]))
        host = DB_CONFIG["host"]
        port = DB_CONFIG["port"]
        database = DB_CONFIG["database"]

        db_url = (
            f"postgresql+psycopg2://{user}:{password}"
            f"@{host}:{port}/{database}"
        )
        _ENGINE = create_engine(db_url)

    return _ENGINE


def get_connection():
    return get_engine().raw_connection()


def ensure_database_exists():
    db_name = DB_CONFIG["database"]

    admin_conn = psycopg2.connect(
        host=DB_CONFIG["host"],
        port=DB_CONFIG["port"],
        user=DB_CONFIG["user"],
        password=DB_CONFIG["password"],
        dbname="postgres",
    )

    admin_conn.autocommit = True
    cur = admin_conn.cursor()

    cur.execute(
        "SELECT 1 FROM pg_database WHERE datname = %s",
        (db_name,)
    )

    if cur.fetchone() is None:
        logging.info(f"Creating database: {db_name}")
        cur.execute(f'CREATE DATABASE "{db_name}"')

    cur.close()
    admin_conn.close()


def run_sql_script(sql_path):
    logging.info("============================================================")
    logging.info("STEP 1 - DATABASE / SCHEMA / TABLE CREATION")
    logging.info("============================================================")

    env = os.environ.copy()
    env["PGPASSWORD"] = DB_CONFIG["password"]

    cmd = [
        "psql",
        "-h", DB_CONFIG["host"],
        "-p", str(DB_CONFIG["port"]),
        "-U", DB_CONFIG["user"],
        "-d", DB_CONFIG["database"],
        "-f", str(sql_path),
    ]

    try:
        subprocess.run(cmd, check=True, env=env)
        logging.info("STEP 1 COMPLETE - all schemas and tables are ready.")
    except FileNotFoundError:
        raise RuntimeError(
            "psql was not found. Install PostgreSQL client tools or add "
            "the PostgreSQL bin directory to PATH."
        )


# ============================================================
# BRONZE: CSV -> RAW STAGING
# ============================================================
def load_csv_to_bronze(csv_filepath):
    logging.info("")
    logging.info("============================================================")
    logging.info("STEP 2 - BRONZE: CSV -> stg.stg_activity_extract")
    logging.info("============================================================")

    df_raw = pd.read_csv(csv_filepath, dtype=str)

    expected = [
        "client_number", "first_name", "last_name", "email",
        "mobile_number", "date_of_birth", "gender", "province",
        "city", "signup_date", "event_type", "event_date",
        "account_number", "product_type", "account_status",
        "credit_limit", "loan_amount", "account_balance",
        "channel", "interaction_type", "resolved_flag",
        "transaction_type", "amount"
    ]

    missing = [c for c in expected if c not in df_raw.columns]
    if missing:
        raise ValueError(f"CSV is missing columns: {missing}")

    df_raw = df_raw[expected].copy()

    conn = get_connection()
    cur = conn.cursor()

    cur.execute("SET search_path TO stg, public;")
    cur.execute("TRUNCATE TABLE stg.stg_activity_extract RESTART IDENTITY;")

    buffer = io.StringIO()
    df_raw.to_csv(buffer, index=False, header=False)
    buffer.seek(0)

    cur.copy_from(
        buffer,
        "stg_activity_extract",
        sep=",",
        columns=expected,
        null=""
    )

    conn.commit()
    cur.close()
    conn.close()

    logging.info(
        f"BRONZE COMPLETE - {len(df_raw):,} raw records loaded."
    )


# ============================================================
# CLEANING FUNCTIONS
# ============================================================
def clean_text(value):
    if pd.isna(value):
        return None

    value = str(value).strip()

    if value.lower() in ("", "nan", "none", "null"):
        return None

    return value


def clean_email(value):
    value = clean_text(value)

    if value is None:
        return None

    value = value.lower()
    value = re.sub(r"\s+", "", value)

    return value


def clean_phone(value):
    value = clean_text(value)

    if value is None:
        return None

    digits = re.sub(r"[^\d]", "", value.split(".")[0])

    if len(digits) == 9:
        return f"+27{digits}"

    if len(digits) == 10 and digits.startswith("0"):
        return f"+27{digits[1:]}"

    if len(digits) >= 11 and digits.startswith("27"):
        return f"+{digits[:11]}"

    return f"+{digits}" if digits else None


def parse_date(value):
    value = clean_text(value)

    if value is None:
        return pd.NaT

    # Try common formats.
    for fmt in ("%m/%d/%y", "%m/%d/%Y", "%Y-%m-%d", "%d/%m/%Y"):
        dt = pd.to_datetime(value, format=fmt, errors="coerce")
        if pd.notnull(dt):
            if dt.year > datetime.now().year:
                dt = dt.replace(year=dt.year - 100)
            return dt

    return pd.to_datetime(value, errors="coerce")


def clean_staging_data(df):
    logging.info("")
    logging.info("============================================================")
    logging.info("STEP 3 - SILVER: CLEAN RAW DATA")
    logging.info("============================================================")

    df = df.copy()

    text_cols = [
        "client_number", "first_name", "last_name", "gender",
        "province", "city", "event_type", "account_number",
        "product_type", "account_status", "channel",
        "interaction_type", "transaction_type", "resolved_flag"
    ]

    for col in text_cols:
        df[col] = df[col].apply(clean_text)

    df["client_number"] = df["client_number"].str.upper()
    df["account_number"] = df["account_number"].str.upper()

    for col in ["first_name", "last_name", "province", "city"]:
        df[col] = df[col].apply(
            lambda x: x.title() if isinstance(x, str) else x
        )

    df["email"] = df["email"].apply(clean_email)
    df["mobile_number"] = df["mobile_number"].apply(clean_phone)

    df["gender"] = (
        df["gender"]
        .str.upper()
        .replace({
            "UNKNOWN": "U",
            "UNDEFINED": "U",
            "NONE": "U",
        })
        .fillna("U")
    )

    df["date_of_birth"] = df["date_of_birth"].apply(parse_date)
    df["signup_date"] = df["signup_date"].apply(parse_date)
    df["event_date"] = df["event_date"].apply(parse_date)

    for col in [
        "credit_limit",
        "loan_amount",
        "account_balance",
        "amount"
    ]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    df["resolved_flag"] = (
        df["resolved_flag"]
        .str.upper()
        .map({
            "TRUE": "TRUE",
            "1": "TRUE",
            "YES": "TRUE",
            "Y": "TRUE",
            "FALSE": "FALSE",
            "0": "FALSE",
            "NO": "FALSE",
            "N": "FALSE",
        })
        .fillna("FALSE")
    )

    # Remove exact duplicates.
    df = df.drop_duplicates().reset_index(drop=True)

    logging.info(
        f"SILVER CLEANING COMPLETE - {len(df):,} cleaned records."
    )

    return df


# ============================================================
# SILVER: LOAD CLEANED DIMENSIONS
# ============================================================
def load_silver_dimensions(df):
    logging.info("")
    logging.info("============================================================")
    logging.info("STEP 4 - SILVER: CREATE / LOAD ALL STAGING DIMENSIONS")
    logging.info("============================================================")

    conn = get_connection()
    cur = conn.cursor()

    # Clear the silver layer so every pipeline run represents the
    # current cleaned source dataset.
    tables = [
        "stg.stg_dim_customer",
        "stg.stg_dim_account",
        "stg.stg_dim_event",
        "stg.stg_dim_channel",
        "stg.stg_dim_transaction_type",
        "stg.stg_dim_date",
        "stg.stg_fact_activity",
    ]

    for table in tables:
        cur.execute(f"TRUNCATE TABLE {table} RESTART IDENTITY CASCADE;")

    # ------------------------------------------------------------
    # 4.1 STG DIM CUSTOMER
    # ------------------------------------------------------------
    logging.info("  -> Loading stg.stg_dim_customer")

    customers = (
        df[
            [
                "client_number", "first_name", "last_name", "email",
                "mobile_number", "date_of_birth", "gender",
                "province", "city", "signup_date"
            ]
        ]
        .dropna(subset=["client_number"])
        .drop_duplicates(subset=["client_number"])
        .copy()
    )

    customer_records = []
    for _, r in customers.iterrows():
        customer_records.append((
            r["client_number"],
            r["first_name"],
            r["last_name"],
            r["email"],
            r["mobile_number"],
            r["date_of_birth"].date() if pd.notnull(r["date_of_birth"]) else None,
            r["gender"],
            r["province"],
            r["city"],
            r["signup_date"].date() if pd.notnull(r["signup_date"]) else None,
        ))

    extras.execute_values(
        cur,
        """
        INSERT INTO stg.stg_dim_customer (
            client_number, first_name, last_name, email,
            mobile_number, date_of_birth, gender, province,
            city, signup_date
        )
        VALUES %s
        """,
        customer_records
    )

    logging.info(f"     {len(customer_records):,} customer rows")

    # ------------------------------------------------------------
    # 4.2 STG DIM ACCOUNT
    # ------------------------------------------------------------
    logging.info("  -> Loading stg.stg_dim_account")

    accounts = (
        df[df["account_number"].notna()]
        .sort_values("event_date")
        .groupby("account_number", as_index=False)
        .agg(
            client_number=("client_number", "first"),
            product_type=("product_type", "first"),
            account_status=("account_status", "last"),
            credit_limit=("credit_limit", "max"),
            loan_amount=("loan_amount", "max"),
            account_balance=("account_balance", "last"),
        )
    )

    account_records = []
    for _, r in accounts.iterrows():
        account_records.append((
            r["account_number"],
            r["client_number"],
            r["product_type"],
            r["account_status"],
            float(r["credit_limit"]) if pd.notnull(r["credit_limit"]) else None,
            float(r["loan_amount"]) if pd.notnull(r["loan_amount"]) else None,
            float(r["account_balance"]) if pd.notnull(r["account_balance"]) else None,
        ))

    extras.execute_values(
        cur,
        """
        INSERT INTO stg.stg_dim_account (
            account_number, client_number, product_type,
            account_status, credit_limit, loan_amount,
            account_balance
        )
        VALUES %s
        """,
        account_records
    )

    logging.info(f"     {len(account_records):,} account rows")

    # ------------------------------------------------------------
    # 4.3 STG DIM EVENT
    # ------------------------------------------------------------
    logging.info("  -> Loading stg.stg_dim_event")

    events = (
        df[["event_type", "interaction_type"]]
        .dropna(subset=["event_type"])
        .drop_duplicates()
    )

    event_records = [
        (r["event_type"], r["interaction_type"])
        for _, r in events.iterrows()
    ]

    extras.execute_values(
        cur,
        """
        INSERT INTO stg.stg_dim_event (
            event_type, interaction_type
        )
        VALUES %s
        """,
        event_records
    )

    logging.info(f"     {len(event_records):,} event rows")

    # ------------------------------------------------------------
    # 4.4 STG DIM CHANNEL
    # ------------------------------------------------------------
    logging.info("  -> Loading stg.stg_dim_channel")

    channels = (
        df[["channel"]]
        .dropna()
        .drop_duplicates()
    )

    channel_records = [(r["channel"],) for _, r in channels.iterrows()]

    extras.execute_values(
        cur,
        """
        INSERT INTO stg.stg_dim_channel (channel)
        VALUES %s
        """,
        channel_records
    )

    logging.info(f"     {len(channel_records):,} channel rows")

    # ------------------------------------------------------------
    # 4.5 STG DIM TRANSACTION TYPE
    # ------------------------------------------------------------
    logging.info("  -> Loading stg.stg_dim_transaction_type")

    tx_types = (
        df[["transaction_type"]]
        .dropna()
        .drop_duplicates()
    )

    tx_type_records = [
        (r["transaction_type"],)
        for _, r in tx_types.iterrows()
    ]

    extras.execute_values(
        cur,
        """
        INSERT INTO stg.stg_dim_transaction_type (transaction_type)
        VALUES %s
        """,
        tx_type_records
    )

    logging.info(f"     {len(tx_type_records):,} transaction types")

    # ------------------------------------------------------------
    # 4.6 STG DIM DATE
    # ------------------------------------------------------------
    logging.info("  -> Loading stg.stg_dim_date")

    all_dates = pd.concat(
        [df["signup_date"], df["event_date"]]
    ).dropna()

    all_dates = pd.to_datetime(all_dates).dt.date.drop_duplicates()

    date_records = []

    for d in sorted(all_dates):
        dt = pd.Timestamp(d)

        date_records.append((
            d,
            int(dt.year),
            int(dt.month),
            dt.strftime("%B"),
            int(dt.day),
            int(dt.dayofweek + 1),
            dt.strftime("%A"),
            int(dt.quarter),
        ))

    extras.execute_values(
        cur,
        """
        INSERT INTO stg.stg_dim_date (
            full_date, year, month, month_name,
            day, day_of_week, day_name, quarter
        )
        VALUES %s
        """,
        date_records
    )

    logging.info(f"     {len(date_records):,} dates")

    # ------------------------------------------------------------
    # 4.7 STG FACT ACTIVITY
    # ------------------------------------------------------------
    logging.info("  -> Loading stg.stg_fact_activity")

    fact_records = []

    for _, r in df.iterrows():
        fact_records.append((
            r["client_number"],
            r["account_number"],
            r["event_type"],
            r["interaction_type"],
            r["channel"],
            r["transaction_type"],
            r["event_date"].to_pydatetime()
                if pd.notnull(r["event_date"]) else None,
            r["resolved_flag"],
            float(r["credit_limit"]) if pd.notnull(r["credit_limit"]) else None,
            float(r["loan_amount"]) if pd.notnull(r["loan_amount"]) else None,
            float(r["account_balance"]) if pd.notnull(r["account_balance"]) else None,
            float(r["amount"]) if pd.notnull(r["amount"]) else None,
        ))

    extras.execute_values(
        cur,
        """
        INSERT INTO stg.stg_fact_activity (
            client_number, account_number, event_type,
            interaction_type, channel, transaction_type,
            event_date, resolved_flag, credit_limit,
            loan_amount, account_balance, amount
        )
        VALUES %s
        """,
        fact_records
    )

    conn.commit()
    cur.close()
    conn.close()

    logging.info("STEP 4 COMPLETE - all Silver staging dimensions and fact loaded.")


# ============================================================
# GOLD: LOAD DWH DIMENSIONS
# ============================================================
def load_dwh_dimensions():
    logging.info("")
    logging.info("============================================================")
    logging.info("STEP 5 - GOLD: LOAD ALL DWH DIMENSIONS")
    logging.info("============================================================")

    conn = get_connection()
    cur = conn.cursor()

    # -------------------------
    # DIM DATE
    # -------------------------
    logging.info("  -> DWH dim_date")

    cur.execute("""
        INSERT INTO dwh.dim_date (
            date_key, full_date, year, month, month_name,
            day, day_of_week, day_name, quarter
        )
        SELECT
            TO_CHAR(full_date, 'YYYYMMDD')::INT,
            full_date,
            year,
            month,
            month_name,
            day,
            day_of_week,
            day_name,
            quarter
        FROM stg.stg_dim_date
        ON CONFLICT (date_key) DO UPDATE SET
            full_date = EXCLUDED.full_date,
            year = EXCLUDED.year,
            month = EXCLUDED.month,
            month_name = EXCLUDED.month_name,
            day = EXCLUDED.day,
            day_of_week = EXCLUDED.day_of_week,
            day_name = EXCLUDED.day_name,
            quarter = EXCLUDED.quarter;
    """)

    # -------------------------
    # DIM CUSTOMER
    # -------------------------
    logging.info("  -> DWH dim_customer")

    cur.execute("""
        INSERT INTO dwh.dim_customer (
            client_number, first_name, last_name, full_name,
            email, mobile_number, date_of_birth, gender,
            province, city, signup_date
        )
        SELECT
            client_number,
            first_name,
            last_name,
            CONCAT_WS(' ', first_name, last_name),
            email,
            mobile_number,
            date_of_birth,
            gender,
            province,
            city,
            signup_date
        FROM stg.stg_dim_customer
        ON CONFLICT (client_number) DO UPDATE SET
            first_name = EXCLUDED.first_name,
            last_name = EXCLUDED.last_name,
            full_name = EXCLUDED.full_name,
            email = EXCLUDED.email,
            mobile_number = EXCLUDED.mobile_number,
            date_of_birth = EXCLUDED.date_of_birth,
            gender = EXCLUDED.gender,
            province = EXCLUDED.province,
            city = EXCLUDED.city,
            signup_date = EXCLUDED.signup_date;
    """)

    # -------------------------
    # DIM ACCOUNT
    # -------------------------
    logging.info("  -> DWH dim_account")

    cur.execute("""
        INSERT INTO dwh.dim_account (
            account_number, client_number, product_type,
            account_status, credit_limit, loan_amount,
            account_balance
        )
        SELECT
            account_number,
            client_number,
            product_type,
            account_status,
            credit_limit,
            loan_amount,
            account_balance
        FROM stg.stg_dim_account
        ON CONFLICT (account_number) DO UPDATE SET
            client_number = EXCLUDED.client_number,
            product_type = EXCLUDED.product_type,
            account_status = EXCLUDED.account_status,
            credit_limit = EXCLUDED.credit_limit,
            loan_amount = EXCLUDED.loan_amount,
            account_balance = EXCLUDED.account_balance;
    """)

    # -------------------------
    # DIM EVENT
    # -------------------------
    logging.info("  -> DWH dim_event")

    cur.execute("""
        INSERT INTO dwh.dim_event (
            event_type, interaction_type
        )
        SELECT event_type, interaction_type
        FROM stg.stg_dim_event
        ON CONFLICT (event_type, interaction_type) DO NOTHING;
    """)

    # -------------------------
    # DIM CHANNEL
    # -------------------------
    logging.info("  -> DWH dim_channel")

    cur.execute("""
        INSERT INTO dwh.dim_channel (channel_name)
        SELECT channel
        FROM stg.stg_dim_channel
        ON CONFLICT (channel_name) DO NOTHING;
    """)

    # -------------------------
    # DIM TRANSACTION TYPE
    # -------------------------
    logging.info("  -> DWH dim_transaction_type")

    cur.execute("""
        INSERT INTO dwh.dim_transaction_type (transaction_type)
        SELECT transaction_type
        FROM stg.stg_dim_transaction_type
        ON CONFLICT (transaction_type) DO NOTHING;
    """)

    conn.commit()
    cur.close()
    conn.close()

    logging.info("STEP 5 COMPLETE - all DWH dimensions loaded.")


# ============================================================
# GOLD: LOAD DWH FACT
# ============================================================
def load_dwh_fact():
    logging.info("")
    logging.info("============================================================")
    logging.info("STEP 6 - GOLD: LOAD DWH FACT ACTIVITY")
    logging.info("============================================================")

    conn = get_connection()
    cur = conn.cursor()

    # Rebuild fact for the current source extract.
    cur.execute("TRUNCATE TABLE dwh.fct_activity RESTART IDENTITY;")

    cur.execute("""
        INSERT INTO dwh.fct_activity (
            date_key,
            customer_key,
            account_key,
            event_key,
            channel_key,
            transaction_type_key,
            event_date,
            resolved_flag,
            credit_limit,
            loan_amount,
            account_balance,
            amount
        )
        SELECT
            TO_CHAR(s.event_date::DATE, 'YYYYMMDD')::INT AS date_key,
            c.customer_key,
            a.account_key,
            e.event_key,
            ch.channel_key,
            tt.transaction_type_key,
            s.event_date,
            CASE
                WHEN UPPER(COALESCE(s.resolved_flag, 'FALSE')) = 'TRUE'
                THEN TRUE
                ELSE FALSE
            END,
            s.credit_limit,
            s.loan_amount,
            s.account_balance,
            s.amount
        FROM stg.stg_fact_activity s

        LEFT JOIN dwh.dim_customer c
            ON c.client_number = s.client_number

        LEFT JOIN dwh.dim_account a
            ON a.account_number = s.account_number

        LEFT JOIN dwh.dim_event e
            ON e.event_type = s.event_type
           AND COALESCE(e.interaction_type, '') =
               COALESCE(s.interaction_type, '')

        LEFT JOIN dwh.dim_channel ch
            ON ch.channel_name = s.channel

        LEFT JOIN dwh.dim_transaction_type tt
            ON tt.transaction_type = s.transaction_type

        WHERE s.event_date IS NOT NULL;
    """)

    conn.commit()

    cur.execute("""
        SELECT COUNT(*) FROM dwh.fct_activity;
    """)
    fact_count = cur.fetchone()[0]

    cur.close()
    conn.close()

    logging.info(
        f"STEP 6 COMPLETE - {fact_count:,} fact records loaded."
    )


# ============================================================
# STEP 7: VALIDATE WHOLE PIPELINE
# ============================================================
def validate_pipeline():
    logging.info("")
    logging.info("============================================================")
    logging.info("STEP 7 - PIPELINE VALIDATION / RECORD COUNTS")
    logging.info("============================================================")

    conn = get_connection()

    queries = [
        ("BRONZE raw", "SELECT COUNT(*) FROM stg.stg_activity_extract"),
        ("SILVER customer", "SELECT COUNT(*) FROM stg.stg_dim_customer"),
        ("SILVER account", "SELECT COUNT(*) FROM stg.stg_dim_account"),
        ("SILVER event", "SELECT COUNT(*) FROM stg.stg_dim_event"),
        ("SILVER channel", "SELECT COUNT(*) FROM stg.stg_dim_channel"),
        ("SILVER transaction type", "SELECT COUNT(*) FROM stg.stg_dim_transaction_type"),
        ("SILVER date", "SELECT COUNT(*) FROM stg.stg_dim_date"),
        ("SILVER fact", "SELECT COUNT(*) FROM stg.stg_fact_activity"),
        ("GOLD dim_date", "SELECT COUNT(*) FROM dwh.dim_date"),
        ("GOLD dim_customer", "SELECT COUNT(*) FROM dwh.dim_customer"),
        ("GOLD dim_account", "SELECT COUNT(*) FROM dwh.dim_account"),
        ("GOLD dim_event", "SELECT COUNT(*) FROM dwh.dim_event"),
        ("GOLD dim_channel", "SELECT COUNT(*) FROM dwh.dim_channel"),
        ("GOLD dim_transaction_type", "SELECT COUNT(*) FROM dwh.dim_transaction_type"),
        ("GOLD fct_activity", "SELECT COUNT(*) FROM dwh.fct_activity"),
    ]

    for label, query in queries:
        result = pd.read_sql(query, conn).iloc[0, 0]
        logging.info(f"{label:<30} : {result:,}")

    conn.close()

    logging.info("STEP 7 COMPLETE - validation finished.")


# ============================================================
# MAIN PIPELINE
# ============================================================
if __name__ == "__main__":

    BASE_DIR = Path(__file__).resolve().parent

    csv_candidates = [
        BASE_DIR / "activity_extract.csv",
        BASE_DIR / "data" / "raw" / "activity_extract.csv",
    ]
    csv_file = next((p for p in csv_candidates if p.exists()), None)
    if csv_file is None:
        raise FileNotFoundError(
            "Could not find activity_extract.csv in the project root or "
            "data/raw/."
        )

    sql_file = BASE_DIR / "Script-16.sql.sql"

    logging.info("")
    logging.info("################################################################")
    logging.info("# CUSTOMER 360 END-TO-END MEDALLION DATA PIPELINE")
    logging.info("################################################################")
    logging.info("# CSV")
    logging.info("#   ↓")
    logging.info("# BRONZE - raw staging")
    logging.info("#   ↓")
    logging.info("# SILVER - clean raw data")
    logging.info("#   ↓")
    logging.info("# SILVER - staging dimensions")
    logging.info("#   ↓")
    logging.info("# SILVER - staging fact")
    logging.info("#   ↓")
    logging.info("# GOLD - DWH dimensions")
    logging.info("#   ↓")
    logging.info("# GOLD - DWH fact")
    logging.info("#   ↓")
    logging.info("# VALIDATION")
    logging.info("################################################################")

    ensure_database_exists()

    # STEP 1
    run_sql_script(sql_file)

    # STEP 2
    if not csv_file.exists():
        raise FileNotFoundError(
            f"Could not find activity_extract.csv at: {csv_file}"
        )

    load_csv_to_bronze(csv_file)

    # STEP 3
    conn = get_connection()
    df_raw = pd.read_sql(
        "SELECT * FROM stg.stg_activity_extract;",
        conn
    )
    conn.close()

    df_clean = clean_staging_data(df_raw)

    # STEP 4
    load_silver_dimensions(df_clean)

    # STEP 5
    load_dwh_dimensions()

    # STEP 6
    load_dwh_fact()

    # STEP 7
    validate_pipeline()

    logging.info("")
    logging.info("################################################################")
    logging.info("# PIPELINE FINISHED SUCCESSFULLY")
    logging.info("################################################################")
