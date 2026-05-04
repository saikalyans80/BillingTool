-- InvoiceFlow / BillingTool: full baseline schema for fresh Supabase projects.
-- Safe on empty DB. If tables already exist (manual SQL from invoicing-tool.html), IF NOT EXISTS skips creation.
-- Run order: this file, then 20260504120000_generate_pending_invoices.sql, then 20260504140000_timesheets_proof_url.sql.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.consultants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.clients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  contact TEXT,
  email TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.billing_cycles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
  cycle_type TEXT DEFAULT 'custom',
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  label TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.consultant_billing_cycles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  consultant_id UUID REFERENCES public.consultants(id) ON DELETE CASCADE,
  billing_cycle_id UUID REFERENCES public.billing_cycles(id) ON DELETE CASCADE,
  billing_rate NUMERIC(10,2),
  start_date DATE,
  end_date DATE,
  UNIQUE(consultant_id, billing_cycle_id)
);

CREATE TABLE IF NOT EXISTS public.consultant_client_rates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  consultant_id UUID REFERENCES public.consultants(id) ON DELETE CASCADE,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
  billing_rate NUMERIC(10,2),
  UNIQUE(consultant_id, client_id)
);

-- No UNIQUE on (consultant_id, billing_cycle_id) here — added in 20260504120000 for RPC ON CONFLICT.
CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  consultant_id UUID REFERENCES public.consultants(id) ON DELETE CASCADE,
  billing_cycle_id UUID REFERENCES public.billing_cycles(id) ON DELETE CASCADE,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending',
  billing_rate NUMERIC(10,2),
  hours NUMERIC(10,2),
  invoice_number TEXT,
  invoice_date DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.settings (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE TABLE IF NOT EXISTS public.timesheets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  consultant_id UUID REFERENCES public.consultants(id) ON DELETE CASCADE,
  billing_cycle_id UUID REFERENCES public.billing_cycles(id) ON DELETE CASCADE,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
  week_ending DATE NOT NULL,
  sat_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
  sun_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
  mon_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
  tue_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
  wed_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
  thu_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
  fri_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
  notes TEXT,
  proof_url TEXT,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(consultant_id, billing_cycle_id, week_ending)
);

-- ---------------------------------------------------------------------------
-- Upgrades for DBs created from older snippets (idempotent)
-- ---------------------------------------------------------------------------

ALTER TABLE public.consultant_billing_cycles
  ADD COLUMN IF NOT EXISTS start_date DATE,
  ADD COLUMN IF NOT EXISTS end_date DATE;

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS hours NUMERIC(10,2);

ALTER TABLE public.timesheets
  ADD COLUMN IF NOT EXISTS proof_url TEXT;

-- ---------------------------------------------------------------------------
-- Row Level Security (single-user: authenticated full access)
-- ---------------------------------------------------------------------------

ALTER TABLE public.consultants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultant_billing_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultant_client_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timesheets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth_all" ON public.consultants;
CREATE POLICY "auth_all" ON public.consultants FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all" ON public.clients;
CREATE POLICY "auth_all" ON public.clients FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all" ON public.billing_cycles;
CREATE POLICY "auth_all" ON public.billing_cycles FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all" ON public.consultant_billing_cycles;
CREATE POLICY "auth_all" ON public.consultant_billing_cycles FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all" ON public.consultant_client_rates;
CREATE POLICY "auth_all" ON public.consultant_client_rates FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all" ON public.invoices;
CREATE POLICY "auth_all" ON public.invoices FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all" ON public.settings;
CREATE POLICY "auth_all" ON public.settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all" ON public.timesheets;
CREATE POLICY "auth_all" ON public.timesheets FOR ALL TO authenticated USING (true) WITH CHECK (true);
