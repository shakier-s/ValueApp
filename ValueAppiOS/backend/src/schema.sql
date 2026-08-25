CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS merchants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  attendant_code_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS deals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  detail TEXT NOT NULL,
  deal_type TEXT NOT NULL CHECK (deal_type IN ('Buy 1, Get 1 Free','Percentage Off','Fixed Amount Off')),
  value NUMERIC(10,2) NOT NULL CHECK (value >= 0),
  category TEXT NOT NULL,
  distance NUMERIC(8,2) NOT NULL DEFAULT 0,
  expiry TIMESTAMPTZ NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  redeemed INTEGER NOT NULL DEFAULT 0 CHECK (redeemed >= 0),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vouchers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id UUID NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
  shopper_id TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'Ready to use' CHECK (status IN ('Ready to use','Redeemed')),
  saved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  redeemed_at TIMESTAMPTZ,
  UNIQUE(deal_id, shopper_id)
);

CREATE INDEX IF NOT EXISTS deals_active_expiry_idx ON deals(is_active, expiry);
CREATE INDEX IF NOT EXISTS vouchers_shopper_idx ON vouchers(shopper_id, saved_at DESC);
