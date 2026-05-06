-- InvoiceFlow: roles (profiles), invoice verification workflow, RLS, RPC.
-- Status values: pending | invoiced_awaiting_verification | double_verified
-- Legacy 'invoiced' rows are migrated to double_verified.

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('global_admin', 'ap_executive', 'ap_manager')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles (role);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Backfill profiles for existing users (default: executive; promote one admin via SQL below)
INSERT INTO public.profiles (id, role)
SELECT id, 'ap_executive' FROM auth.users
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE public.profiles IS 'App roles. First admin: UPDATE profiles SET role = ''global_admin'' WHERE id = ''<your-auth-user-uuid>'';';

-- New signups default to AP Executive
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, role) VALUES (NEW.id, 'ap_executive');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Invoices: verification audit columns + status migration
-- ---------------------------------------------------------------------------
ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES auth.users (id) ON DELETE SET NULL;

UPDATE public.invoices
SET
  status = 'double_verified',
  verified_at = COALESCE(verified_at, (invoice_date::text || 'T12:00:00Z')::timestamptz, created_at)
WHERE status = 'invoiced';

-- ---------------------------------------------------------------------------
-- Pending generation: block duplicate when any finalized row exists
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_pending_invoices()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := (timezone('utc', now()))::date;
  n_inserted int := 0;
BEGIN
  INSERT INTO public.invoices (consultant_id, billing_cycle_id, client_id, status, billing_rate)
  SELECT
    cbc.consultant_id,
    cbc.billing_cycle_id,
    bc.client_id,
    'pending',
    COALESCE(cbc.billing_rate, ccr.billing_rate)
  FROM public.consultant_billing_cycles cbc
  INNER JOIN public.billing_cycles bc ON bc.id = cbc.billing_cycle_id
  LEFT JOIN public.consultant_client_rates ccr
    ON ccr.consultant_id = cbc.consultant_id AND ccr.client_id = bc.client_id
  WHERE bc.end_date < v_today
    AND (cbc.start_date IS NULL OR bc.end_date >= cbc.start_date)
    AND (cbc.end_date IS NULL OR cbc.end_date >= bc.start_date)
    AND NOT EXISTS (
      SELECT 1 FROM public.invoices inv
      WHERE inv.consultant_id = cbc.consultant_id
        AND inv.billing_cycle_id = cbc.billing_cycle_id
        AND inv.status IN (
          'pending',
          'invoiced_awaiting_verification',
          'double_verified'
        )
    )
  ON CONFLICT (consultant_id, billing_cycle_id) DO NOTHING;

  GET DIAGNOSTICS n_inserted = ROW_COUNT;
  RETURN n_inserted;
END;
$$;

-- ---------------------------------------------------------------------------
-- RPC: Global Admin assigns roles (bypasses profiles RLS)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_profile_role(target_user_id UUID, new_role TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'global_admin'
  ) THEN
    RAISE EXCEPTION 'Only global_admin can set roles';
  END IF;
  IF new_role IS NULL OR new_role NOT IN ('global_admin', 'ap_executive', 'ap_manager') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  INSERT INTO public.profiles (id, role) VALUES (target_user_id, new_role)
  ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;
END;
$$;

REVOKE ALL ON FUNCTION public.set_profile_role(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_profile_role(UUID, TEXT) TO authenticated;

-- Used in RLS policies; must bypass profiles RLS (subquery on profiles would recurse).
CREATE OR REPLACE FUNCTION public.is_global_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'global_admin'
  );
$$;

REVOKE ALL ON FUNCTION public.is_global_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_global_admin() TO authenticated;

-- ---------------------------------------------------------------------------
-- RLS: profiles
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS "profiles_select_admin" ON public.profiles;
CREATE POLICY "profiles_select_admin" ON public.profiles
  FOR SELECT TO authenticated
  USING (public.is_global_admin());

-- ---------------------------------------------------------------------------
-- RLS: invoices (replace open policy)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "auth_all" ON public.invoices;

-- Must have a profile row to touch invoices
DROP POLICY IF EXISTS "invoices_select" ON public.invoices;
CREATE POLICY "invoices_select" ON public.invoices
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles pr WHERE pr.id = auth.uid()));

DROP POLICY IF EXISTS "invoices_insert" ON public.invoices;
CREATE POLICY "invoices_insert" ON public.invoices
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles pr WHERE pr.id = auth.uid()));

DROP POLICY IF EXISTS "invoices_update_admin" ON public.invoices;
CREATE POLICY "invoices_update_admin" ON public.invoices
  FOR UPDATE TO authenticated
  USING (public.is_global_admin())
  WITH CHECK (public.is_global_admin());

DROP POLICY IF EXISTS "invoices_update_pending_fields" ON public.invoices;
CREATE POLICY "invoices_update_pending_fields" ON public.invoices
  FOR UPDATE TO authenticated
  USING (
    status = 'pending'
    AND EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = auth.uid() AND pr.role IN ('ap_executive', 'ap_manager')
    )
  )
  WITH CHECK (status = 'pending');

DROP POLICY IF EXISTS "invoices_update_exec_mark" ON public.invoices;
CREATE POLICY "invoices_update_exec_mark" ON public.invoices
  FOR UPDATE TO authenticated
  USING (
    status = 'pending'
    AND EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = auth.uid() AND pr.role = 'ap_executive'
    )
  )
  WITH CHECK (status = 'invoiced_awaiting_verification');

DROP POLICY IF EXISTS "invoices_update_mgr_verify" ON public.invoices;
CREATE POLICY "invoices_update_mgr_verify" ON public.invoices
  FOR UPDATE TO authenticated
  USING (
    status = 'invoiced_awaiting_verification'
    AND EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = auth.uid() AND pr.role = 'ap_manager'
    )
  )
  WITH CHECK (status = 'double_verified');

DROP POLICY IF EXISTS "invoices_update_exec_undo_awaiting" ON public.invoices;
CREATE POLICY "invoices_update_exec_undo_awaiting" ON public.invoices
  FOR UPDATE TO authenticated
  USING (
    status = 'invoiced_awaiting_verification'
    AND EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = auth.uid() AND pr.role = 'ap_executive'
    )
  )
  WITH CHECK (status = 'pending');

DROP POLICY IF EXISTS "invoices_delete_pending" ON public.invoices;
CREATE POLICY "invoices_delete_pending" ON public.invoices
  FOR DELETE TO authenticated
  USING (
    status = 'pending'
    AND EXISTS (SELECT 1 FROM public.profiles pr WHERE pr.id = auth.uid())
  );

DROP POLICY IF EXISTS "invoices_delete_admin" ON public.invoices;
CREATE POLICY "invoices_delete_admin" ON public.invoices
  FOR DELETE TO authenticated
  USING (public.is_global_admin());

-- Admin policy covers verify, undo, and edits on double_verified rows.

GRANT SELECT ON public.profiles TO authenticated;
