-- Harbour Point Bank legacy database (PostgreSQL 16)
-- schema "core"      : accounts, ledger, transfers (reached by IIB over ODBC)
-- schema "mainframe" : customer master, played by the CoreStub flow over MQ

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mainframe;
SET search_path = core;

CREATE TABLE account (
    account_id            varchar(11) PRIMARY KEY,           -- upper case, e.g. HPB10000001
    cust_id               varchar(10) NOT NULL,
    product               char(3)     NOT NULL CHECK (product IN ('CUR','SAV')),
    sort_code             varchar(8)  NOT NULL,
    ledger_bal_minor      bigint      NOT NULL DEFAULT 0,    -- pence
    overdraft_limit_minor bigint      NOT NULL DEFAULT 0,    -- pence
    status                char(1)     NOT NULL CHECK (status IN ('A','F','C')),
    -- Ceiling on any balance. One seeded account sits just under it, so a credit
    -- to that account fails in the database and exercises the compensation path.
    CONSTRAINT ck_balance_ceiling CHECK (ledger_bal_minor <= 10000000000)
);

CREATE TABLE account_hold (
    hold_id      serial PRIMARY KEY,
    account_id   varchar(11) NOT NULL,
    amount_minor bigint      NOT NULL,
    expires_at   timestamptz NOT NULL
);

CREATE TABLE ledger_entry (                                  -- append only
    txn_id       bigserial PRIMARY KEY,
    account_id   varchar(11) NOT NULL,
    posted_at    timestamptz NOT NULL,
    amount_minor bigint      NOT NULL,                       -- signed pence
    narrative    varchar(100),
    transfer_id  varchar(12)
);
CREATE INDEX ix_ledger_paging ON ledger_entry (account_id, posted_at DESC, txn_id DESC);

CREATE SEQUENCE transfer_seq START 1;

CREATE TABLE transfer (
    transfer_id  varchar(12) PRIMARY KEY,                    -- TRF000000001
    client_ref   varchar(64) NOT NULL,
    from_account varchar(11) NOT NULL,
    to_account   varchar(11) NOT NULL,
    amount_minor bigint      NOT NULL,
    fee_minor    bigint      NOT NULL DEFAULT 0,
    value_date   date,
    status       varchar(12) NOT NULL CHECK (status IN ('ACCEPTED','COMPLETED','REJECTED','COMPENSATED')),
    reject_code  varchar(40),
    created_at   timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz
);

CREATE TABLE idempotency (
    channel_id  varchar(10) NOT NULL,
    client_ref  varchar(64) NOT NULL,
    transfer_id varchar(12) NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (channel_id, client_ref)
);

CREATE TABLE audit_log (
    audit_id       bigserial PRIMARY KEY,
    correlation_id varchar(64)  NOT NULL,
    operation      varchar(40),
    outcome        varchar(100),
    payload_hash   char(32),
    logged_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE bank_holiday (
    holiday_date date PRIMARY KEY,
    name         varchar(60) NOT NULL
);

-- Simulated mainframe customer master (CUSTREC source of truth)
CREATE TABLE mainframe.customer (
    cust_id    char(10) PRIMARY KEY,
    cust_name  varchar(40) NOT NULL,
    dob        char(8)     NOT NULL,        -- CCYYMMDD, 00000000 = unknown
    email      varchar(50) NOT NULL DEFAULT '',
    phone      varchar(15) NOT NULL DEFAULT '',
    addr1      varchar(25) NOT NULL DEFAULT '',
    addr2      varchar(25) NOT NULL DEFAULT '',
    addr3      varchar(25) NOT NULL DEFAULT '',
    addr4      varchar(25) NOT NULL DEFAULT '',
    kyc_status char(1)     NOT NULL CHECK (kyc_status IN ('V','P','R')),
    rel_value  numeric(13,2) NOT NULL DEFAULT 0
);
