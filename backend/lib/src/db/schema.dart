/// PostgreSQL schema DDL for BankOS multitenant banking platform.
/// Every tenant-owned table enforces strict tenant_id scoping and foreign keys.
const List<String> bankOsMigrations = [
  '''
  CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY,
    slug VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    max_transaction_limit NUMERIC(18, 2) NOT NULL DEFAULT 10000000.00,
    transfer_fee_type VARCHAR(20) NOT NULL DEFAULT 'percentage'
      CHECK (transfer_fee_type IN ('fixed', 'percentage')),
    transfer_fee_value NUMERIC(18, 4) NOT NULL DEFAULT 1.0000,
    base_currency VARCHAR(10) NOT NULL DEFAULT 'COP',
    exchange_rates JSONB NOT NULL DEFAULT '{}'::jsonb,
    webhook_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    email VARCHAR(180) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('administrador', 'cliente')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, email)
  );
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_users_tenant_email
    ON users (tenant_id, email);
  ''',
  '''
  CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    account_number VARCHAR(40) NOT NULL,
    owner_user_id UUID NOT NULL REFERENCES users(id),
    balance NUMERIC(18, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    currency VARCHAR(10) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'activa'
      CHECK (status IN ('activa', 'inactiva', 'bloqueada')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deactivated_at TIMESTAMPTZ,
    UNIQUE (tenant_id, account_number)
  );
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_accounts_tenant_owner
    ON accounts (tenant_id, owner_user_id);
  ''',
  '''
  CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    initiated_by_user_id UUID NOT NULL REFERENCES users(id),
    type VARCHAR(20) NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'transfer')),
    source_account_id UUID REFERENCES accounts(id),
    source_account_number VARCHAR(40),
    destination_account_id UUID REFERENCES accounts(id),
    destination_account_number VARCHAR(40),
    original_amount NUMERIC(18, 2) NOT NULL,
    original_currency VARCHAR(10) NOT NULL,
    converted_amount NUMERIC(18, 2) NOT NULL,
    destination_currency VARCHAR(10) NOT NULL,
    exchange_rate NUMERIC(18, 8) NOT NULL DEFAULT 1.0,
    fee_amount NUMERIC(18, 2) NOT NULL DEFAULT 0.00,
    fee_currency VARCHAR(10) NOT NULL,
    total_debited NUMERIC(18, 2) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('SUCCESS', 'FAILED')),
    failure_reason TEXT,
    idempotency_key VARCHAR(128) NOT NULL,
    correlation_id VARCHAR(128) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_transactions_tenant_created
    ON transactions (tenant_id, created_at DESC);
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_transactions_tenant_type
    ON transactions (tenant_id, type, created_at DESC);
  ''',
  '''
  CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    actor_user_id UUID NOT NULL REFERENCES users(id),
    actor_email VARCHAR(180) NOT NULL,
    action VARCHAR(80) NOT NULL,
    entity_type VARCHAR(60) NOT NULL,
    entity_id VARCHAR(120) NOT NULL,
    previous_state JSONB,
    new_state JSONB,
    correlation_id VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_created
    ON audit_logs (tenant_id, created_at DESC);
  ''',
  '''
  CREATE OR REPLACE FUNCTION bankos_prevent_audit_mutation()
  RETURNS trigger AS \$\$
  BEGIN
    RAISE EXCEPTION 'audit_logs is immutable and append-only';
  END;
  \$\$ LANGUAGE plpgsql;
  ''',
  '''
  DO \$\$
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_logs_immutable'
    ) THEN
      CREATE TRIGGER trg_audit_logs_immutable
      BEFORE UPDATE OR DELETE ON audit_logs
      FOR EACH ROW EXECUTE FUNCTION bankos_prevent_audit_mutation();
    END IF;
  END
  \$\$;
  ''',
  '''
  CREATE TABLE IF NOT EXISTS idempotency_records (
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES users(id),
    idempotency_key VARCHAR(128) NOT NULL,
    status_code INT NOT NULL,
    response_body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (tenant_id, user_id, idempotency_key)
  );
  ''',
];
