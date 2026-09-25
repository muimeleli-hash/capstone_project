-- ============================================================
-- 1. SCHEMAS
-- ============================================================
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dwh;

-- ============================================================
-- 2. BRONZE / RAW STAGING
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.stg_activity_extract (
    client_number      TEXT,
    first_name         TEXT,
    last_name          TEXT,
    email              TEXT,
    mobile_number      TEXT,
    date_of_birth      TEXT,
    gender             TEXT,
    province           TEXT,
    city               TEXT,
    signup_date        TEXT,
    event_type         TEXT,
    event_date         TEXT,
    account_number     TEXT,
    product_type       TEXT,
    account_status     TEXT,
    credit_limit       TEXT,
    loan_amount        TEXT,
    account_balance    TEXT,
    channel            TEXT,
    interaction_type   TEXT,
    resolved_flag      TEXT,
    transaction_type   TEXT,
    amount             TEXT,
    stg_loaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 3. SILVER / CLEAN STAGING DIMENSIONS
-- ============================================================

-- 3.1 Customer
CREATE TABLE IF NOT EXISTS stg.stg_dim_customer (
    customer_stg_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_number   VARCHAR(50),
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    email           VARCHAR(150),
    mobile_number   VARCHAR(50),
    date_of_birth   DATE,
    gender          VARCHAR(20),
    province        VARCHAR(100),
    city            VARCHAR(100),
    signup_date     DATE
);

-- 3.2 Account
CREATE TABLE IF NOT EXISTS stg.stg_dim_account (
    account_stg_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_number VARCHAR(50),
    client_number  VARCHAR(50),
    product_type   VARCHAR(100),
    account_status VARCHAR(50),
    credit_limit   NUMERIC(14,2),
    loan_amount    NUMERIC(14,2),
    account_balance NUMERIC(14,2)
);

-- 3.3 Event
CREATE TABLE IF NOT EXISTS stg.stg_dim_event (
    event_stg_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_type       VARCHAR(100),
    interaction_type VARCHAR(100)
);

-- 3.4 Channel
CREATE TABLE IF NOT EXISTS stg.stg_dim_channel (
    channel_stg_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    channel        VARCHAR(50)
);

-- 3.5 Transaction Type
CREATE TABLE IF NOT EXISTS stg.stg_dim_transaction_type (
    transaction_type_stg_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_type        VARCHAR(100)
);

-- 3.6 Date
CREATE TABLE IF NOT EXISTS stg.stg_dim_date (
    date_stg_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_date    DATE,
    year         INT,
    month        INT,
    month_name   VARCHAR(20),
    day          INT,
    day_of_week  INT,
    day_name     VARCHAR(20),
    quarter      INT
);

-- ============================================================
-- 4. SILVER / CLEAN STAGING FACT
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.stg_fact_activity (
    stg_fact_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_number     VARCHAR(50),
    account_number    VARCHAR(50),
    event_type        VARCHAR(100),
    interaction_type  VARCHAR(100),
    channel           VARCHAR(50),
    transaction_type  VARCHAR(100),
    event_date        TIMESTAMP,
    resolved_flag     VARCHAR(20),
    credit_limit      NUMERIC(14,2),
    loan_amount       NUMERIC(14,2),
    account_balance   NUMERIC(14,2),
    amount            NUMERIC(14,2)
);

-- ============================================================
-- 5. GOLD / DWH DIMENSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS dwh.dim_date (
    date_key      INT PRIMARY KEY,
    full_date     DATE NOT NULL UNIQUE,
    year          INT NOT NULL,
    month         INT NOT NULL,
    month_name    VARCHAR(20) NOT NULL,
    day           INT NOT NULL,
    day_of_week   INT NOT NULL,
    day_name      VARCHAR(20) NOT NULL,
    quarter       INT NOT NULL
);

CREATE TABLE IF NOT EXISTS dwh.dim_customer (
    customer_key   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_number  VARCHAR(50) UNIQUE NOT NULL,
    first_name     VARCHAR(100),
    last_name      VARCHAR(100),
    full_name      VARCHAR(200),
    email          VARCHAR(150),
    mobile_number  VARCHAR(50),
    date_of_birth  DATE,
    gender         VARCHAR(20),
    province       VARCHAR(100),
    city           VARCHAR(100),
    signup_date    DATE,
    dwh_inserted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dwh.dim_account (
    account_key     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_number  VARCHAR(50) UNIQUE NOT NULL,
    client_number   VARCHAR(50),
    product_type    VARCHAR(100),
    account_status  VARCHAR(50),
    credit_limit    NUMERIC(14,2),
    loan_amount     NUMERIC(14,2),
    account_balance NUMERIC(14,2),
    dwh_inserted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_account_customer
        FOREIGN KEY (client_number)
        REFERENCES dwh.dim_customer(client_number)
);

CREATE TABLE IF NOT EXISTS dwh.dim_event (
    event_key         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_type        VARCHAR(100) NOT NULL,
    interaction_type  VARCHAR(100),
    UNIQUE(event_type, interaction_type)
);

CREATE TABLE IF NOT EXISTS dwh.dim_channel (
    channel_key  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    channel_name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS dwh.dim_transaction_type (
    transaction_type_key INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_type     VARCHAR(100) UNIQUE NOT NULL
);

-- ============================================================
-- 6. GOLD / DWH FACT
-- ============================================================
CREATE TABLE IF NOT EXISTS dwh.fct_activity (
    activity_key INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    date_key INT REFERENCES dwh.dim_date(date_key),
    customer_key INT REFERENCES dwh.dim_customer(customer_key),
    account_key INT REFERENCES dwh.dim_account(account_key),
    event_key INT REFERENCES dwh.dim_event(event_key),
    channel_key INT REFERENCES dwh.dim_channel(channel_key),
    transaction_type_key INT REFERENCES dwh.dim_transaction_type(transaction_type_key),

    event_date TIMESTAMP,
    resolved_flag BOOLEAN,
    credit_limit NUMERIC(14,2),
    loan_amount NUMERIC(14,2),
    account_balance NUMERIC(14,2),
    amount NUMERIC(14,2),

    dwh_inserted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 7. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_dwh_activity_date
    ON dwh.fct_activity(date_key);

CREATE INDEX IF NOT EXISTS idx_dwh_activity_customer
    ON dwh.fct_activity(customer_key);

CREATE INDEX IF NOT EXISTS idx_dwh_activity_account
    ON dwh.fct_activity(account_key);

CREATE INDEX IF NOT EXISTS idx_dwh_activity_event
    ON dwh.fct_activity(event_key);

CREATE INDEX IF NOT EXISTS idx_dwh_activity_channel
    ON dwh.fct_activity(channel_key);

CREATE INDEX IF NOT EXISTS idx_dwh_activity_tx_type
    ON dwh.fct_activity(transaction_type_key);
